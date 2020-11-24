UsefulBots = UsefulBots or {
  no_crouch = true,
  dominate_enemies = 1,       -- 1 = yes, 2 = assist only, 3 = no
  use_melee = true,
  mark_specials = true,
  announce_low_hp = true,
  attack_turrets = true,
  targeting_improvement = true,
  targeting_priority = {
    base_priority = 1,        -- 1 = by weapon stats, 2 = by distance
    critical = 2,             -- sabotaging enemies, taser tasing, cloaker charging
    marked = 1,               -- marked enemies
    damaged = 1.5,            -- enemies that damaged the bot
    domination = 2,           -- enemies that are in domination progress or valid targets
    enemies = {               -- multipliers for specific enemy types
      tank_medic = 2,
      medic = 3,
      spooc = 4,
      taser = 2,
      sniper = 3
    }
  }
}

-- no crouch
if RequiredScript == "lib/tweak_data/charactertweakdata" then

  local init_original = CharacterTweakData.init
  function CharacterTweakData:init(...)
    local result = init_original(self, ...)
    for k, v in pairs(self) do
      if type(v) == "table" then
        if v.access == "teamAI1" and UsefulBots.no_crouch then
          v.allowed_poses = { stand = true }
        elseif v.priority_shout and not UsefulBots.targeting_priority.enemies[k] then
          UsefulBots.targeting_priority.enemies[k] = 1
        end
      end
    end
    return result
  end

end

-- fully count bots for balancing multiplier
if RequiredScript == "lib/managers/group_ai_states/groupaistatebase" then

  function GroupAIStateBase:_get_balancing_multiplier(balance_multipliers)
    local nr_crim = 0
    for _, u_data in pairs(self:all_char_criminals()) do
      if not u_data.status then
        nr_crim = nr_crim + 1
      end
    end
    nr_crim = math.clamp(nr_crim, 1, CriminalsManager.MAX_NR_CRIMINALS)
    return balance_multipliers[nr_crim]
  end

end

-- add basic upgrades to make domination work
if RequiredScript == "lib/units/player_team/teamaibase" then

  Hooks:PostHook(TeamAIBase, "post_init", "post_init_ub", function (self)
    self._upgrades = self._upgrades or {}
    self._upgrade_levels = self._upgrade_levels or {}
    self._temporary_upgrades = self._temporary_upgrades or {}
    self._temporary_upgrades_map = self._temporary_upgrades_map or {}
    if Network:is_server() then
      self:set_upgrade_value("player", "intimidate_enemies", 1)
      self:set_upgrade_value("player", "empowered_intimidation_mul", 1)
      self:set_upgrade_value("player", "intimidation_multiplier", 1)
    end
  end)
  TeamAIBase.set_upgrade_value = HuskPlayerBase.set_upgrade_value
  TeamAIBase.upgrade_value = HuskPlayerBase.upgrade_value
  TeamAIBase.upgrade_level = HuskPlayerBase.upgrade_level

end

-- adjust slotmask to allow attacking turrets
if RequiredScript == "lib/units/player_team/teamaibrain" then

  Hooks:PostHook(TeamAIBrain, "_reset_logic_data", "_reset_logic_data_ub", function (self)
    if UsefulBots.attack_turrets then
      self._logic_data.enemy_slotmask = self._logic_data.enemy_slotmask + World:make_slot_mask(25)
    end
  end)

end

-- announce low health
if RequiredScript == "lib/units/player_team/teamaidamage" then

  Hooks:PostHook(TeamAIDamage, "_apply_damage", "_apply_damage_ub", function (self)
    local t = TimerManager:game():time()
    if UsefulBots.announce_low_hp and (not self._said_hurt_t or self._said_hurt_t + 10 < t) and self._health_ratio < 0.3 and not self:need_revive() and not self._unit:sound():speaking() then
      self._said_hurt_t = t
      self._unit:sound():say("g80x_plu", true, true)
    end
  end)

end

-- main bot logic
if RequiredScript == "lib/units/player_team/logics/teamailogicbase" then

  Hooks:PostHook(TeamAILogicBase, "_set_attention_obj", "_set_attention_obj_ub", function (data, new_attention, new_reaction)
    local my_data = data.internal_data
    -- early abort
    if data.cool or not new_attention or not new_reaction or my_data.acting or data.unit:anim_data().reload or my_data._turning_to_intimidate then
      return
    end
    -- melee
    if new_reaction == AIAttentionObject.REACT_MELEE and (not my_data._melee_t or my_data._melee_t + 5 < data.t) then
      TeamAILogicIdle.do_melee(data, new_attention)
      my_data._melee_t = data.t
      return
    end
    -- intimidate
    local key = new_attention.unit:key()
    local intimidate = TeamAILogicIdle._intimidate_progress[key]
    local too_early = intimidate and data.t < intimidate + 1 or my_data._new_intimidate_t and data.t < my_data._new_intimidate_t + 2
    if not too_early and new_reaction == AIAttentionObject.REACT_ARREST then
      TeamAILogicIdle.intimidate_cop(data, new_attention.unit)
      TeamAILogicIdle._intimidate_progress[key] = data.t
      my_data._new_intimidate_t = data.t
      return
    end
    -- mark
    if UsefulBots.mark_specials and new_attention.char_tweak and new_attention.char_tweak.priority_shout and (not TeamAILogicAssault._mark_special_t or TeamAILogicAssault._mark_special_t + 8 < data.t) and (not new_attention.unit:contour()._contour_list or not new_attention.unit:contour():has_id("mark_enemy")) then
      TeamAILogicAssault.mark_enemy(data, data.unit, new_attention.unit, true, true)
      return
    end
    -- civ intimidate
    if (not my_data._new_intimidate_t or my_data._new_intimidate_t + 2 < data.t) then
      TeamAILogicIdle.intimidate_civilians(data, data.unit, true, true)
      my_data._new_intimidate_t = data.t
    end
  end)

end

if RequiredScript == "lib/units/player_team/logics/teamailogicidle" then

  TeamAILogicIdle._intimidate_resist = {}
  TeamAILogicIdle._intimidate_progress = {}
  TeamAILogicIdle._MAX_RESISTS = 1
  TeamAILogicIdle._MAX_INTIMIDATION_TIME = 2

  -- check if unit is sabotaging device
  function TeamAILogicIdle.is_high_priority(unit, unit_movement, unit_damage, unit_brain)
    if not managers.enemy:is_enemy(unit) or not unit_movement or not unit_damage or unit_damage:dead() or not unit_brain then
      return false
    end
    local data = att_brain and att_brain._logic_data and att_brain._logic_data.internal_data
    if data and (data.tasing or data.spooc_attack) then
      return true
    end
    local anim = unit:anim_data() or {}
    if anim.hands_back or anim.surrender or anim.hands_tied then
      return false
    end
    for _, action in ipairs(unit_movement._active_actions or {}) do
      if type(action) == "table" and action:type() == "act" and action._action_desc.variant then
        local variant = action._action_desc.variant
        if variant:find("untie") or variant:find("^e_so_") or variant:find("^sabotage_") then
          return true
        end
      end
    end
    return false
  end

  function TeamAILogicIdle._find_intimidateable_civilians(criminal, use_default_shout_shape, max_angle, max_dis)
    local head_pos = criminal:movement():m_head_pos()
    local look_vec = criminal:movement():m_rot():y()
    local intimidateable_civilians = {}
    local best_civ, best_civ_wgt
    local highest_wgt = 1
    local my_tracker = criminal:movement():nav_tracker()
    local unit, unit_movement, unit_base, unit_anim_data, unit_brain
    local ai_visibility_slotmask = managers.slot:get_mask("AI_visibility")
    for key, u_data in pairs(managers.enemy:all_civilians()) do
      unit = u_data.unit
      unit_movement = unit:movement()
      unit_base = unit:base()
      unit_anim_data = unit:anim_data()
      unit_brain = unit:brain()
      if my_tracker.check_visibility(my_tracker, unit_movement:nav_tracker()) and not unit_movement:cool() and tweak_data.character[unit_base._tweak_table].intimidateable and not unit_base.unintimidateable and not unit_anim_data.unintimidateable and not unit_brain:is_tied() and not unit:unit_data().disable_shout and (not unit_brain._logic_data.internal_data.submission_meter or unit_brain._logic_data.internal_data.submission_meter < unit_brain._logic_data.internal_data.submission_max * 0.6) then
        local u_head_pos = unit_movement:m_head_pos() + math.UP * 30
        local vec = u_head_pos - head_pos
        local dis = mvector3.normalize(vec)
        local angle = vec:angle(look_vec)
        if dis < (max_dis or 400) and angle < (max_angle or 90) then
          local ray = World:raycast("ray", head_pos, u_head_pos, "slot_mask", ai_visibility_slotmask)
          if not ray then
            local inv_wgt = dis * dis * (1 - vec:dot(look_vec))
            table.insert(intimidateable_civilians, {
              unit = unit,
              key = key,
              inv_wgt = inv_wgt
            })
            if not best_civ_wgt or best_civ_wgt > inv_wgt then
              best_civ_wgt = inv_wgt
              best_civ = unit
            end
            if highest_wgt < inv_wgt then
              highest_wgt = inv_wgt
            end
          end
        end
      end
    end
    return best_civ, highest_wgt, intimidateable_civilians
  end

  function TeamAILogicIdle.intimidate_civilians(data, criminal, play_sound, play_action, primary_target)
    if alive(primary_target) and primary_target:unit_data().disable_shout then
      return
    end

    if primary_target and not alive(primary_target) then
      primary_target = nil
    end

    local can_turn = not data.unit:movement():chk_action_forbidden("turn")
    local best_civ, highest_wgt, intimidateable_civilians = TeamAILogicIdle._find_intimidateable_civilians(criminal, true, can_turn and 180 or 90, 1200)

    if best_civ and can_turn and CopLogicAttack._chk_request_action_turn_to_enemy(data, data.internal_data, data.m_pos, best_civ:movement():m_pos()) then
      data.internal_data._turning_to_intimidate = true
      data.internal_data._primary_intimidation_target = best_civ
      return
    end

    local plural = false
    if #intimidateable_civilians > 1 then
      plural = true
    elseif #intimidateable_civilians <= 0 then
      return
    end

    local sound_name = (best_civ:anim_data().drop and "f03a_" or "f02x_") .. (plural and "plu" or "sin")
    if play_sound then
      criminal:sound():say(sound_name, true)
    end

    if play_action and not criminal:movement():chk_action_forbidden("action") then
      local new_action = {
        align_sync = true,
        body_part = 3,
        type = "act",
        variant = best_civ:anim_data().move and "gesture_stop" or "arrest"
      }
      if criminal:brain():action_request(new_action) then
        data.internal_data.gesture_arrest = true
      end
    end

    local intimidated_primary_target = false
    for _, civ in ipairs(intimidateable_civilians) do
      local amount = civ.inv_wgt / highest_wgt
      if best_civ == civ.unit then
        amount = 1
      end
      if primary_target == civ.unit then
        intimidated_primary_target = true
        amount = 1
      end
      civ.unit:brain():on_intimidated(amount, criminal)
    end

    if not intimidated_primary_target and primary_target then
      primary_target:brain():on_intimidated(1, criminal)
    end

    if not primary_target and best_civ and best_civ:unit_data().disable_shout then
      return false
    end

    return primary_target or best_civ
  end

  -- check if attention_object is a valid intimidation target
  function TeamAILogicIdle.is_valid_intimidation_target(unit, unit_tweak, unit_anim, unit_damage, data, distance)
    if UsefulBots.dominate_enemies > 2 or not unit_tweak or not unit_damage or unit_damage:dead() or not managers.enemy:is_enemy(unit) then
      return false
    end
    if not unit_tweak.surrender or unit_tweak.surrender == tweak_data.character.presets.surrender.special or unit_anim.hands_tied then
      -- unit can't surrender
      return false
    end
    if distance > tweak_data.player.long_dis_interaction.intimidate_range_enemies then
      -- too far away
      return false
    end
    if unit_anim.hands_back or unit_anim.surrender then
      -- unit is already surrendering
      return true
    end
    if UsefulBots.dominate_enemies > 1 then
      -- unit is not surrendering and we only allow domination assists
      return false
    end
    if not managers.groupai:state():has_room_for_police_hostage() then
      -- no room for police hostage
      return false
    end
    local health_min
    for k, _ in pairs(unit_tweak.surrender.reasons and unit_tweak.surrender.reasons.health or {}) do
      health_min = (not health_min or k < health_min) and k or health_min
    end
    local is_hurt = health_min and unit_damage:health_ratio() < health_min
    if not is_hurt then
      -- not vulnerable
      return false
    end
    local resist = TeamAILogicIdle._intimidate_resist[unit:key()]
    if resist and resist > TeamAILogicIdle._MAX_RESISTS then
      -- resisted too often
      return false
    end
    local all_players_dead = table.size(managers.groupai:state():all_player_criminals()) == 0
    return all_players_dead or not TeamAILogicIdle.is_enemy_near(unit, data, 600)
  end

  -- check if there are enemies close to the unit
  function TeamAILogicIdle.is_enemy_near(unit, data, distance)
    local unit_movement = unit:movement()
    local dist_sq = distance * distance
    for _, v in pairs(data.detected_attention_objects) do
      if v.verified and v.unit ~= unit and managers.enemy:is_enemy(v.unit) and mvector3.distance_sq(v.unit:movement():m_pos(), unit_movement:m_pos()) < dist_sq then
        return true
      end
    end
    return false
  end

  function TeamAILogicIdle.intimidate_cop(data, target)
    if not alive(target) or target:unit_data().disable_shout then
      return
    end
    local anim = target:anim_data()
    data.unit:sound():say(anim.hands_back and "l03x_sin" or anim.surrender and "l02x_sin" or "l01x_sin", true)
    if not data.unit:movement():chk_action_forbidden("action") then
      local new_action = {
        type = "act",
        variant = (anim.hands_back or anim.surrender) and "arrest" or "gesture_stop",
        body_part = 3,
        align_sync = true
      }
      if data.unit:brain():action_request(new_action) then
        data.internal_data.gesture_arrest = true
      end
    end

    local success
    if target:brain():interaction_voice() then
      target:brain():set_objective(target:brain()._logic_data.objective.followup_objective)
    else
      success = target:brain()._current_logic.on_intimidated(target:brain()._logic_data, tweak_data.player.long_dis_interaction.intimidate_strength, data.unit)
    end

    if not success then
      TeamAILogicIdle._intimidate_resist[target:key()] = (TeamAILogicIdle._intimidate_resist[target:key()] or 0) + 1
    end
    return success
  end

  function TeamAILogicIdle.do_melee(data, att_obj)
    if not att_obj then
      return
    end
    local enemy_unit = att_obj.unit
    if not alive(enemy_unit) or not enemy_unit:character_damage()._call_listeners then
      return
    end
    if data.unit:movement():play_redirect("melee") then
      managers.network:session():send_to_peers("play_distance_interact_redirect", data.unit, "melee")
      local my_pos = data.unit:movement():m_pos()
      local is_shield = enemy_unit:base()._tweak_table == "shield"
      enemy_unit:character_damage():_call_listeners({
        variant = "melee",
        damage = is_shield and 0 or data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].melee_dmg or 3,
        attacker_unit = data.unit,
        result = {
          type = is_shield and "shield_knock" or "knock_down",
          variant = "melee"
        },
        col_ray = {
          body = enemy_unit:body("body"),
          position = my_pos
        },
        attack_dir = my_pos - enemy_unit:movement():m_pos()
      })
    end
  end

  local math_max = math.max
  local _get_priority_attention_original = TeamAILogicIdle._get_priority_attention
  function TeamAILogicIdle._get_priority_attention(data, attention_objects, reaction_func, ...)
    data.internal_data._intimidate_t = data.t -- hacky way to stop the vanilla civ intimidate code
    TeamAILogicAssault._mark_special_chk_t = data.t  -- hacky way to stop the vanilla special mark code

    if not UsefulBots.targeting_improvement then
      return _get_priority_attention_original(data, attention_objects, reaction_func, ...)
    end

    reaction_func = reaction_func or TeamAILogicBase._chk_reaction_to_attention_object
    local best_target, best_target_priority, best_target_reaction
    local REACT_SHOOT = data.cool and AIAttentionObject.REACT_SURPRISED or AIAttentionObject.REACT_SHOOT
    local REACT_MELEE = AIAttentionObject.REACT_MELEE
    local REACT_ARREST = AIAttentionObject.REACT_ARREST
    local w_tweak = data.unit:inventory():equipped_unit():base():weapon_tweak_data()
    local w_usage = w_tweak and data.char_tweak.weapon[w_tweak.usage]
    local ub_priority = UsefulBots.targeting_priority

    for u_key, attention_data in pairs(attention_objects) do
      local att_unit = attention_data.unit
      if not attention_data.identified then
      elseif attention_data.pause_expire_t then
        if data.t > attention_data.pause_expire_t then
          attention_data.pause_expire_t = nil
        end
      elseif attention_data.stare_expire_t and data.t > attention_data.stare_expire_t then
        if attention_data.settings.pause then
          attention_data.stare_expire_t = nil
          attention_data.pause_expire_t = data.t + math.lerp(attention_data.settings.pause[1], attention_data.settings.pause[2], math.random())
        end
      elseif alive(att_unit) then
        local distance = mvector3.distance(data.m_pos, attention_data.m_pos)
        local reaction = reaction_func(data, attention_data, not CopLogicAttack._can_move(data)) or AIAttentionObject.REACT_CHECK
        attention_data.aimed_at = TeamAILogicIdle.chk_am_i_aimed_at(data, attention_data, attention_data.aimed_at and 0.95 or 0.985)
        -- attention unit data
        local att_tweak_name = att_unit.base and att_unit:base()._tweak_table
        local att_tweak = attention_data.char_tweak or att_tweak_name and tweak_data.character[att_tweak_name] or {}
        local att_brain = att_unit.brain and att_unit:brain()
        local att_anim = att_unit.anim_data and att_unit:anim_data() or {}
        local att_movement = att_unit.movement and att_unit:movement()
        local att_damage = att_unit.character_damage and att_unit:character_damage()

        local alert_dt = attention_data.alert_t and data.t - attention_data.alert_t or 10000
        local dmg_dt = attention_data.dmg_t and data.t - attention_data.dmg_t or 10000
        local mark_dt = attention_data.mark_t and data.t - attention_data.mark_t or 10000
        if data.attention_obj and data.attention_obj.u_key == u_key then
          alert_dt = alert_dt * 0.8
          dmg_dt = dmg_dt * 0.8
          mark_dt = mark_dt * 0.8
          distance = distance * 0.8
        end
        local has_damaged = dmg_dt < 2
        local been_marked = mark_dt < 10
        local is_tied = att_anim.hands_tied
        local is_dead = not att_damage or att_damage._dead
        local is_special = attention_data.is_very_dangerous or att_tweak.priority_shout
        -- use the dmg multiplier of the given distance as priority
        local target_priority
        if ub_priority.base_priority == 1 then
          local falloff_data = (TeamAIActionShoot or CopActionShoot)._get_shoot_falloff(nil, distance, w_usage.FALLOFF)
          target_priority = falloff_data.dmg_mul * falloff_data.acc[2]
        else
          target_priority = 4000 / math_max(1, distance)
        end

        -- fine tune target priority
        if att_unit:in_slot(data.enemy_slotmask) and not is_tied and not is_dead and attention_data.verified then

          local high_priority = TeamAILogicIdle.is_high_priority(att_unit, att_movement, att_damage, att_brain)
          local should_intimidate = not high_priority and TeamAILogicIdle.is_valid_intimidation_target(att_unit, att_tweak, att_anim, att_damage, data, distance)

          -- check for reaction changes
          reaction = should_intimidate and REACT_ARREST or (high_priority or is_special or has_damaged or been_marked) and math_max(REACT_SHOOT, reaction) or reaction

          -- get target priority multipliers
          target_priority = target_priority * (should_intimidate and ub_priority.domination or 1) * (high_priority and ub_priority.critical or 1) * (has_damaged and ub_priority.damaged or 1) * (been_marked and ub_priority.marked or 1) * (ub_priority.enemies[att_tweak_name] or 1)

          -- melee reaction if distance is short enough
          if UsefulBots.use_melee and distance < 150 and reaction >= REACT_SHOOT and not att_tweak.immune_to_knock_down and att_tweak_name ~= "spooc" then
            reaction = REACT_MELEE
          end

          -- reduce priority of shields if we can't hit them
          if attention_data.is_shield then
            local can_attack = not TeamAILogicIdle._ignore_shield(data.unit, attention_data) or reaction == REACT_MELEE
            target_priority = can_attack and target_priority or target_priority * 0.1
          end

          -- if reaction is not combat, reduce priority
          if reaction ~= REACT_ARREST and reaction < REACT_SHOOT then
            target_priority = target_priority * 0.01
          end

          if not best_target or target_priority > best_target_priority then
            best_target = attention_data
            best_target_priority = target_priority
            best_target_reaction = reaction
          end
        end
      end
    end
    return best_target, best_target_priority and math_max(1, math.floor(best_target_priority / 500)), best_target_reaction, best_selection_index
  end

end

if RequiredScript == "lib/units/player_team/logics/teamailogicassault" then

  function TeamAILogicAssault.mark_enemy(data, criminal, to_mark, play_sound, play_action)
    criminal:sound():say(to_mark:base():char_tweak().priority_shout .. "x_any", true)
    if not criminal:movement():chk_action_forbidden("action") then
      managers.network:session():send_to_peers_synched("play_distance_interact_redirect", data.unit, "cmd_point")
      data.unit:movement():play_redirect("cmd_point")
    end
    to_mark:contour():add("mark_enemy", true)
    TeamAILogicAssault._mark_special_t = data.t
  end

end

if RequiredScript == "lib/units/enemies/cop/logics/coplogicidle" then

  Hooks:PreHook(CopLogicIdle, "on_intimidated", "on_intimidated_ub", function (data)
    if not managers.groupai:state():is_enemy_special(data.unit) then
      TeamAILogicIdle._intimidate_progress[data.unit:key()] = data.t
    end
  end)

end

if RequiredScript == "lib/units/weapons/newnpcraycastweaponbase" then

  -- Remove criminal slotmask from Team AI so they can shoot through each other
  Hooks:PostHook(NewNPCRaycastWeaponBase, "setup", "setup_ub", function (self)
    if self._setup.user_unit and self._setup.user_unit:in_slot(16) then
      self._bullet_slotmask = self._bullet_slotmask - World:make_slot_mask(16)
    end
  end)

end

if RequiredScript == "lib/managers/menumanager" then

  dofile(ModPath .. "automenubuilder.lua")

  Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenusUsefulBots", function(menu_manager, nodes)
    managers.localization:add_localized_strings({
      menu_useful_bots_assist_only = "Only assist",
      menu_useful_bots_weapon_stats = "By weapon stats",
      menu_useful_bots_distance = "By target distance"
    })
    AutoMenuBuilder:load_settings(UsefulBots, "useful_bots")
    AutoMenuBuilder:create_menu_from_table(nodes, UsefulBots, "useful_bots", "blt_options", {
      targeting_priority = { 0, 5, 0.25 },
      dominate_enemies = { "dialog_yes", "menu_useful_bots_assist_only", "dialog_no" },
      base_priority = { "menu_useful_bots_weapon_stats", "menu_useful_bots_distance" }
    }, {
      enabled = 100,
      base_priority = 99,
      enemies = -10
    })
  end)

end