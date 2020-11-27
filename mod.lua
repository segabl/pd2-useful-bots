UsefulBots = UsefulBots or {
  no_crouch = true,
  dominate_enemies = 1,       -- 1 = yes, 2 = assist only, 3 = no
  use_melee = true,
  mark_specials = true,
  announce_low_hp = true,
  targeting_improvement = true,
  targeting_priority = {
    base_priority = 1,        -- 1 = by weapon stats, 2 = by distance
    critical = 2,             -- sabotaging enemies, taser tasing, cloaker charging
    marked = 1,               -- marked enemies
    damaged = 1.5,            -- enemies that damaged the bot
    domination = 2,           -- enemies that are in domination progress or valid targets
    enemies = {               -- multipliers for specific enemy types
      medic = 3,
      phalanx_minion = 1,
      phalanx_vip = 1,
      shield = 1,
      sniper = 3,
      spooc = 4,
      tank = 1,
      tank_hw = 1,
      tank_medic = 2,
      tank_mini = 1,
      taser = 2,
      turret = 1
    }
  }
}

if not AutoMenuBuilder then
  dofile(ModPath .. "req/automenubuilder.lua")
  AutoMenuBuilder:load_settings(UsefulBots, "useful_bots")
end

if RequiredScript == "lib/managers/menumanager" then

  Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenusUsefulBots", function(menu_manager, nodes)
    managers.localization:add_localized_strings({
      menu_useful_bots_assist_only = "Only assist",
      menu_useful_bots_weapon_stats = "By weapon stats",
      menu_useful_bots_distance = "By target distance"
    })
    AutoMenuBuilder:create_menu_from_table(nodes, UsefulBots, "useful_bots", "blt_options", {
      targeting_priority = { 0, 5, 0.25 },
      dominate_enemies = { "dialog_yes", "menu_useful_bots_assist_only", "dialog_no" },
      base_priority = { "menu_useful_bots_weapon_stats", "menu_useful_bots_distance" }
    }, {
      base_priority = 100,
      enemies = -10
    })
  end)

end

-- no crouch
if RequiredScript == "lib/tweak_data/charactertweakdata" then

  local init_original = CharacterTweakData.init
  function CharacterTweakData:init(...)
    local result = init_original(self, ...)
    for k, v in pairs(self) do
      if type(v) == "table" then
        if v.access == "teamAI1" and UsefulBots.no_crouch then
          v.allowed_poses = { stand = true }
        end
      end
    end
    return result
  end

end

-- fully count bots for balancing multiplier
if RequiredScript == "lib/managers/group_ai_states/groupaistatebase" then

  function GroupAIStateBase:_get_balancing_multiplier(balance_multipliers)
    return balance_multipliers[math.clamp(table.count(self:all_char_criminals(), function (u_data) return not u_data.status end), 1, #balance_multipliers)]
  end

end

-- add basic upgrades to make domination work
if RequiredScript == "lib/units/player_team/teamaibase" then

  TeamAIBase.set_upgrade_value = HuskPlayerBase.set_upgrade_value
  TeamAIBase.upgrade_value = HuskPlayerBase.upgrade_value
  TeamAIBase.upgrade_level = HuskPlayerBase.upgrade_level

  Hooks:PostHook(TeamAIBase, "init", "init_ub", function (self)
    self._upgrades = self._upgrades or {}
    self._upgrade_levels = self._upgrade_levels or {}
    self._temporary_upgrades = self._temporary_upgrades or {}
    self._temporary_upgrades_map = self._temporary_upgrades_map or {}
    self:set_upgrade_value("player", "intimidate_enemies", 1)
  end)

end

-- adjust slotmask to allow attacking turrets
if RequiredScript == "lib/units/player_team/teamaibrain" then

  Hooks:PostHook(TeamAIBrain, "_reset_logic_data", "_reset_logic_data_ub", function (self)
    if UsefulBots.targeting_priority.enemies.turret > 0 then
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
    if data.cool or my_data.acting or data.unit:anim_data().reload or my_data._turning_to_intimidate or data.unit:character_damage():is_downed() then
      return
    end
    if new_attention and new_attention.verified and new_attention.unit.character_damage and not new_attention.unit:character_damage():dead() then
      -- melee
      if new_reaction == AIAttentionObject.REACT_MELEE and (not my_data._melee_t or my_data._melee_t + 5 < data.t) then
        TeamAILogicIdle.do_melee(data, new_attention)
        my_data._melee_t = data.t
        return
      end
      -- intimidate
      if new_reaction == AIAttentionObject.REACT_ARREST and (not my_data._new_intimidate_t or my_data._new_intimidate_t + 2 < data.t) then
        local key = new_attention.unit:key()
        local intimidate = TeamAILogicIdle._intimidate_progress[key]
        if intimidate and data.t < intimidate + 1 then
          TeamAILogicIdle.intimidate_cop(data, new_attention.unit)
          TeamAILogicIdle._intimidate_progress[key] = data.t
          my_data._new_intimidate_t = data.t
          return
        end
      end
      -- mark
      if UsefulBots.mark_specials and new_attention.char_tweak and new_attention.char_tweak.priority_shout and (not TeamAILogicAssault._mark_special_t or TeamAILogicAssault._mark_special_t + 8 < data.t) and (not new_attention.unit:contour()._contour_list or not new_attention.unit:contour():has_id("mark_enemy")) then
        TeamAILogicAssault.mark_enemy(data, data.unit, new_attention.unit, true, true)
        TeamAILogicAssault._mark_special_t = data.t
        return
      end
    end
    -- civ intimidate
    if not my_data._new_intimidate_t or my_data._new_intimidate_t + 2 < data.t then
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
  function TeamAILogicIdle.is_high_priority(unit, unit_movement, unit_brain)
    if not unit_movement or not unit_brain then
      return false
    end
    local data = unit_brain._logic_data and unit_brain._logic_data.internal_data
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
    local unit, unit_movement, unit_base, unit_anim_data, unit_brain, intimidatable
    local ai_visibility_slotmask = managers.slot:get_mask("AI_visibility")
    for key, u_data in pairs(managers.enemy:all_civilians()) do
      unit = u_data.unit
      unit_movement = unit:movement()
      unit_base = unit:base()
      unit_anim_data = unit:anim_data()
      unit_brain = unit:brain()
      intimidatable = tweak_data.character[unit_base._tweak_table].is_escort and (unit_anim_data.panic or unit_anim_data.standing_hesitant) or tweak_data.character[unit_base._tweak_table].intimidateable and not unit_base.unintimidateable and not unit_anim_data.unintimidateable
      if my_tracker.check_visibility(my_tracker, unit_movement:nav_tracker()) and not unit_movement:cool() and intimidatable and not unit_brain:is_tied() and not unit:unit_data().disable_shout and (not unit_anim_data.drop or (unit_brain._logic_data.internal_data.submission_meter or 0) < (unit_brain._logic_data.internal_data.submission_max or 0) * 0.25) then
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
    if alive(primary_target) and primary_target:unit_data().disable_shout or criminal:movement():chk_action_forbidden("action") then
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
      return best_civ
    end

    local plural = false
    if #intimidateable_civilians > 1 then
      plural = true
    elseif #intimidateable_civilians <= 0 then
      return
    end

    local is_escort = tweak_data.character[best_civ:base()._tweak_table].is_escort
    local sound_name = is_escort and "f40_any" or (best_civ:anim_data().drop and "f03a_" or "f02x_") .. (plural and "plu" or "sin")
    criminal:sound():say(sound_name, true)
    local new_action = {
      align_sync = true,
      body_part = 3,
      type = "act",
      variant = is_escort and "cmd_point" or best_civ:anim_data().move and "gesture_stop" or "arrest"
    }
    if criminal:brain():action_request(new_action) then
      data.internal_data.gesture_arrest = true
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
    if UsefulBots.dominate_enemies > 2 then
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
    local num = 0
    local max = 1 + table.count(managers.groupai:state():all_char_criminals(), function (u_data) return u_data == "dead" end) * 2
    local m_pos = data.unit:movement():m_pos()
    local dist_sq = tweak_data.player.long_dis_interaction.intimidate_range_enemies * tweak_data.player.long_dis_interaction.intimidate_range_enemies * 4
    for _, v in pairs(data.detected_attention_objects) do
      if v.verified and v.unit ~= unit and v.unit.character_damage and not v.unit:character_damage():dead() and mvector3.distance_sq(v.unit:movement():m_pos(), m_pos) < dist_sq then
        num = num + 1
        if num > max then
          -- too many detected attention objects
          return false
        end
      end
    end
    return true
  end

  function TeamAILogicIdle.intimidate_cop(data, target)
    if not alive(target) or target:unit_data().disable_shout or data.unit:movement():chk_action_forbidden("action") then
      return
    end
    local anim = target:anim_data()
    data.unit:sound():say(anim.hands_back and "l03x_sin" or anim.surrender and "l02x_sin" or "l01x_sin", true)
    local new_action = {
      type = "act",
      variant = (anim.hands_back or anim.surrender) and "arrest" or "gesture_stop",
      body_part = 3,
      align_sync = true
    }
    if data.unit:brain():action_request(new_action) then
      data.internal_data.gesture_arrest = true
    end
    target:brain():on_intimidated(tweak_data.player.long_dis_interaction.intimidate_strength, data.unit)
    local objective = target:brain():objective()
    if not objective or objective.type ~= "surrender" then
      TeamAILogicIdle._intimidate_resist[target:key()] = (TeamAILogicIdle._intimidate_resist[target:key()] or 0) + 1
    end
  end

  function TeamAILogicIdle.do_melee(data, att_obj)
    if not att_obj or data.unit:movement():chk_action_forbidden("action") then
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
          body = enemy_unit:body("b_spine1"),
          position = my_pos
        },
        attack_dir = my_pos - enemy_unit:movement():m_pos()
      })
    end
  end

  local math_min = math.min
  local math_max = math.max
  local _get_priority_attention_original = TeamAILogicIdle._get_priority_attention
  function TeamAILogicIdle._get_priority_attention(data, attention_objects, reaction_func, ...)
    data.internal_data._intimidate_t = data.t + 10 -- hacky way to stop the vanilla civ intimidate code
    TeamAILogicAssault._mark_special_chk_t = data.t + 10  -- hacky way to stop the vanilla special mark code

    if not UsefulBots.targeting_improvement then
      return _get_priority_attention_original(data, attention_objects, reaction_func, ...)
    end

    reaction_func = reaction_func or TeamAILogicBase._chk_reaction_to_attention_object
    local best_target, best_target_priority, best_target_reaction, best_priority_mul = nil, 0, nil, 0
    local REACT_SHOOT = data.cool and AIAttentionObject.REACT_SURPRISED or AIAttentionObject.REACT_SHOOT
    local REACT_MELEE = AIAttentionObject.REACT_MELEE
    local REACT_ARREST = AIAttentionObject.REACT_ARREST
    local REACT_AIM = AIAttentionObject.REACT_AIM
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
        local has_alerted = alert_dt < 5
        local has_damaged = dmg_dt < 2
        local been_marked = mark_dt < 10
        local is_tied = att_anim.hands_tied
        local is_dead = not att_damage or att_damage:dead()
        local is_special = attention_data.is_very_dangerous or att_tweak.priority_shout
        local is_turret = att_unit.base and att_unit:base().sentry_gun
        -- use the dmg multiplier of the given distance as priority
        local valid_target = false
        local target_priority
        local priority_mul = 1
        if ub_priority.base_priority == 1 then
          local falloff_data = (TeamAIActionShoot or CopActionShoot)._get_shoot_falloff(nil, distance, w_usage.FALLOFF)
          target_priority = falloff_data.dmg_mul * falloff_data.acc[2]
        else
          target_priority = 100 / math_max(1, distance)
        end

        -- fine tune target priority
        if att_unit:in_slot(data.enemy_slotmask) and not is_tied and not is_dead and attention_data.verified then
          valid_target = true

          local high_priority = TeamAILogicIdle.is_high_priority(att_unit, att_movement, att_brain)
          local should_intimidate = not high_priority and TeamAILogicIdle.is_valid_intimidation_target(att_unit, att_tweak, att_anim, att_damage, data, distance)

          -- check for reaction changes
          reaction = should_intimidate and REACT_ARREST or (high_priority or is_special or has_damaged or been_marked) and math_max(REACT_SHOOT, reaction) or reaction

          -- get target priority multipliers
          priority_mul = (should_intimidate and ub_priority.domination or 1) * (high_priority and ub_priority.critical or 1) * (has_damaged and ub_priority.damaged or 1) * (been_marked and ub_priority.marked or 1) * (is_turret and ub_priority.enemies.turret or 1) * (ub_priority.enemies[att_tweak_name] or 1)

          -- melee reaction if distance is short enough
          if UsefulBots.use_melee and distance < 150 and reaction >= REACT_SHOOT and not att_tweak.immune_to_knock_down and att_tweak_name ~= "spooc" then
            reaction = REACT_MELEE
          end

          -- reduce priority if we would hit a shield
          if reaction ~= REACT_MELEE and TeamAILogicIdle._ignore_shield(data.unit, attention_data) then
            priority_mul = 0.1
          end
        elseif has_alerted then
          valid_target = true
          reaction = math_min(reaction, REACT_AIM)
          priority_mul = 0.1
        end

        target_priority = target_priority * priority_mul
        if valid_target and target_priority > best_target_priority then
          best_target = attention_data
          best_target_priority = target_priority
          best_target_reaction = reaction
          best_priority_mul = priority_mul
        end
      end
    end
    return best_target, 5 / math_max(best_priority_mul, 0.1), best_target_reaction
  end

end

if RequiredScript == "lib/units/player_team/logics/teamailogicassault" then

  function TeamAILogicAssault.mark_enemy(data, criminal, to_mark, play_sound, play_action)
    if criminal:movement():chk_action_forbidden("action") then
      return
    end
    criminal:sound():say(to_mark:base():char_tweak().priority_shout .. "x_any", true)
    managers.network:session():send_to_peers_synched("play_distance_interact_redirect", data.unit, "cmd_point")
    data.unit:movement():play_redirect("cmd_point")
    to_mark:contour():add("mark_enemy", true)
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
