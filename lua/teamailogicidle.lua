local math_lerp = math.lerp
local math_map_range = math.map_range
local math_max = math.max
local math_min = math.min
local mvec_dir = mvector3.direction
local tmp_vec = Vector3()

function TeamAILogicIdle.is_high_priority(unit_movement)
	if type(unit_movement._active_actions) ~= "table" then
		return false
	end

	for _, action in pairs(unit_movement._active_actions) do
		if type(action) == "table" and action._is_sabotaging_action then
			return true
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
	local unit, unit_movement, unit_base, unit_anim_data, unit_brain, intimidatable, escort
	local ai_visibility_slotmask = managers.slot:get_mask("AI_visibility")
	max_angle = max_angle or 90
	max_dis = use_default_shout_shape and 1200 or max_dis or 400
	for key, u_data in pairs(managers.enemy:all_civilians()) do
		unit = u_data.unit
		unit_movement = unit:movement()
		unit_base = unit:base()
		unit_anim_data = unit:anim_data()
		unit_brain = unit:brain()
		escort = tweak_data.character[unit_base._tweak_table].is_escort
		intimidatable = escort and (unit_anim_data.panic or unit_anim_data.standing_hesitant) or tweak_data.character[unit_base._tweak_table].intimidateable and not unit_base.unintimidateable and not unit_anim_data.unintimidateable
		if my_tracker.check_visibility(my_tracker, unit_movement:nav_tracker()) and not unit_movement:cool() and intimidatable and not unit_brain:is_tied() and not unit:unit_data().disable_shout and (not unit_anim_data.drop or (unit_brain._logic_data.internal_data.submission_meter or 0) < (unit_brain._logic_data.internal_data.submission_max or 0) * 0.25) then
			local u_head_pos = unit_movement:m_head_pos() + math.UP * 30
			local vec = u_head_pos - head_pos
			local dis = mvector3.normalize(vec)
			local angle = vec:angle(look_vec)
			if dis < (escort and 800 or max_dis) and angle < (use_default_shout_shape and math.max(8, math.lerp(90, 30, dis / 1200)) or max_angle) then
				local ray = World:raycast("ray", head_pos, u_head_pos, "slot_mask", ai_visibility_slotmask)
				if not ray then
					local inv_wgt = dis * dis * (1 - vec:dot(look_vec))
					if escort then
						return unit, inv_wgt, {{ unit = unit, key = key, inv_wgt = inv_wgt }}
					end
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

function TeamAILogicIdle.intimidate_civilians(data, criminal)
	if data.unit:movement():chk_action_forbidden("action") then
		return
	end

	if data._next_intimidate_t and data.t < data._next_intimidate_t then
		return
	end

	data._next_intimidate_t = data.t + 2

	local best_civ, highest_wgt, intimidateable_civilians = TeamAILogicIdle._find_intimidateable_civilians(criminal, true)
	if #intimidateable_civilians <= 0 then
		return
	end

	local is_escort = tweak_data.character[best_civ:base()._tweak_table].is_escort
	local sound_name = is_escort and "f40_any" or (best_civ:anim_data().drop and "f03a_" or "f02x_") .. (#intimidateable_civilians > 1 and "plu" or "sin")
	criminal:sound():say(sound_name, true)
	criminal:brain():action_request({
		align_sync = true,
		body_part = 3,
		type = "act",
		variant = is_escort and "cmd_point" or best_civ:anim_data().move and "gesture_stop" or "arrest"
	})
	for _, civ in ipairs(intimidateable_civilians) do
		local amount = civ.inv_wgt / highest_wgt
		if best_civ == civ.unit then
			amount = 1
		end
		civ.unit:brain():on_intimidated(amount, criminal)
	end
end

function TeamAILogicIdle.is_valid_intimidation_target(unit, unit_tweak, unit_anim, unit_damage, data, distance)
	if UsefulBots.settings.dominate_enemies > 2 then
		return false
	end
	if unit:unit_data().disable_shout then
		return false
	end
	if not unit_tweak.surrender or unit_tweak.surrender == tweak_data.character.presets.surrender.special or unit_anim.hands_tied then
		-- unit can't surrender
		return false
	end
	local surrender_window = unit:brain()._logic_data.surrender_window
	if surrender_window and TimerManager:game():time() > surrender_window.window_expire_t then
		-- unit will not surrender
		return false
	end
	if distance > tweak_data.player.long_dis_interaction.intimidate_range_enemies then
		-- unit is too far away
		return false
	end
	if unit_anim.hands_back or unit_anim.surrender then
		-- unit is already surrendering
		return true
	end
	if not managers.groupai:state():has_room_for_police_hostage() then
		-- no room for police hostage
		return false
	end
	if surrender_window then
		-- intimidation attempt was started
		return true
	end
	if UsefulBots.settings.dominate_enemies > 1 then
		-- unit is not surrendering and we only allow domination assists
		return false
	end
	local health_max = 0
	for k, _ in pairs(unit_tweak.surrender.reasons and unit_tweak.surrender.reasons.health or {}) do
		health_max = k > health_max and k or health_max
	end
	if unit_damage:health_ratio() > health_max / 2 then
		-- not vulnerable
		return false
	end
	local num = 0
	local max = 4 + table.count(managers.groupai:state():all_char_criminals(), function (u_data) return u_data == "dead" end) * 2
	local dis = tweak_data.player.long_dis_interaction.intimidate_range_enemies
	for _, v in pairs(data.detected_attention_objects) do
		local u_damage = v.unit and v.unit.character_damage and v.unit:character_damage()
		if v.verified and v.unit ~= unit and v.dis < dis and u_damage and not u_damage:dead() then
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
	local anim = target:anim_data()
	data.unit:sound():say(anim.hands_back and "l03x_sin" or anim.surrender and "l02x_sin" or "l01x_sin", true)
	data.unit:brain():action_request({
		type = "act",
		variant = (anim.hands_back or anim.surrender) and "arrest" or "gesture_stop",
		body_part = 3,
		align_sync = true
	})
	target:brain():on_intimidated(tweak_data.player.long_dis_interaction.intimidate_strength, data.unit)
end

local _get_priority_attention_original = TeamAILogicIdle._get_priority_attention
function TeamAILogicIdle._get_priority_attention(data, attention_objects, reaction_func, ...)
	local ub_priority = UsefulBots.settings.targeting_priority
	if ub_priority.base_priority > 2 then
		local target, slot, reaction = _get_priority_attention_original(data, attention_objects, reaction_func, ...)
		return target, (slot or 30), reaction
	end

	reaction_func = reaction_func or TeamAILogicBase._chk_reaction_to_attention_object
	local best_target, best_target_priority, best_target_reaction = nil, 0, nil
	local REACT_SHOOT = data.cool and AIAttentionObject.REACT_SURPRISED or AIAttentionObject.REACT_SHOOT
	local REACT_ARREST = AIAttentionObject.REACT_ARREST
	local REACT_AIM = AIAttentionObject.REACT_AIM
	local w_unit = data.unit:inventory():equipped_unit()
	local w_tweak = alive(w_unit) and w_unit:base():weapon_tweak_data()
	local w_usage = w_tweak and data.char_tweak.weapon[w_tweak.usage]
	local follow_movement = alive(data._latest_follow_unit) and data._latest_follow_unit:movement()
	local follow_head_pos = follow_movement and follow_movement:m_head_pos()
	local follow_look_vec = follow_movement and follow_movement:m_head_rot():y()
	local my_team = data.unit:movement():team()
	local not_assisting = data.name ~= "travel" or not data.objective or data.objective.type ~= "revive" and not data.objective.assist_unit
	local visibility_slotmask = data.visibility_slotmask

	for _, attention_data in pairs(attention_objects) do
		local att_unit = attention_data.unit
		if not attention_data.identified or not alive(att_unit) then
			-- Skip
		elseif attention_data.pause_expire_t then
			if data.t > attention_data.pause_expire_t then
				attention_data.pause_expire_t = nil
			end
		elseif attention_data.stare_expire_t and data.t > attention_data.stare_expire_t then
			if attention_data.settings.pause then
				attention_data.stare_expire_t = nil
				attention_data.pause_expire_t = data.t + math.rand(attention_data.settings.pause[1], attention_data.settings.pause[2])
			end
		else
			-- attention unit data
			local att_base = att_unit:base()
			local att_damage = att_unit:character_damage()
			local att_movement = att_unit:movement()
			if att_base and att_damage and not att_damage:dead() and att_movement and att_movement.team and my_team.foes[att_movement:team().id] then
				local att_tweak_name = att_base._tweak_table
				local att_tweak = attention_data.char_tweak or att_tweak_name and tweak_data.character[att_tweak_name] or {}
				local att_anim = att_unit.anim_data and att_unit:anim_data() or {}

				local distance = attention_data.dis
				local reaction = reaction_func(data, attention_data, not CopLogicAttack._can_move(data)) or AIAttentionObject.REACT_CHECK
				attention_data.aimed_at = TeamAILogicIdle.chk_am_i_aimed_at(data, attention_data, attention_data.aimed_at and 0.95 or 0.985)

				local has_alerted = attention_data.alert_t and data.t - attention_data.alert_t < 3
				local has_damaged = attention_data.dmg_t and data.t - attention_data.dmg_t < 3
				local been_marked = attention_data.mark_t and data.t - attention_data.mark_t < 10
				local is_tied = att_anim.hands_tied
				local is_special = attention_data.is_very_dangerous or att_tweak.priority_shout
				local high_priority = TeamAILogicIdle.is_high_priority(att_movement)
				-- use the dmg multiplier of the given distance as priority
				local valid_target = false
				local target_priority
				if ub_priority.base_priority == 1 and w_usage then
					local falloff_data = (TeamAIActionShoot or CopActionShoot)._get_shoot_falloff(nil, distance, w_usage.FALLOFF)
					target_priority = (falloff_data.dmg_mul / w_usage.FALLOFF[1].dmg_mul) * falloff_data.acc[2]
				else
					target_priority = math_max(0, 1 - distance / 3000)
				end

				-- fine tune target priority
				if att_unit:in_slot(data.enemy_slotmask) and not is_tied and attention_data.verified then
					local should_intimidate = not high_priority and TeamAILogicIdle.is_valid_intimidation_target(att_unit, att_tweak, att_anim, att_damage, data, distance)
					local marked_contour = att_unit:contour() and att_unit:contour():find_id_match("^mark_enemy")
					local marked_by_player = marked_contour and (marked_contour ~= "mark_enemy" or not been_marked)

					-- check for reaction changes
					reaction = should_intimidate and REACT_ARREST or (high_priority or is_special or has_damaged or marked_contour) and math_max(REACT_SHOOT, reaction) or reaction

					-- get target priority multipliers
					target_priority = target_priority * (should_intimidate and ub_priority.domination or 1) * (high_priority and ub_priority.critical or 1) * (marked_by_player and ub_priority.marked or 1) * (att_base.sentry_gun and ub_priority.enemies.turret or 1) * (ub_priority.enemies[att_tweak_name] or 1)

					-- if we have a revive objective and target priority isn't high, ignore the enemy
					valid_target = not_assisting or target_priority >= 1

					if valid_target then
						-- give a slight boost to priority if this is our current target (to avoid switching targets too much if the other one is still alive and visible)
						if data.attention_obj == attention_data then
							target_priority = target_priority * 1.25
						end

						-- slightly boost priority of enemies that damaged us
						if has_damaged then
							target_priority = target_priority * 1.1
						end

						-- reduce priority if we would hit a shield
						if TeamAILogicIdle._ignore_shield(data.unit, attention_data) then
							target_priority = target_priority * 0.01
						end

						-- reduce reaction and priority if someone is trying to intimidate, but we are not
						local logic_data = att_unit:brain()._logic_data
						if not should_intimidate and logic_data and logic_data.surrender_window and logic_data.surrender_window.window_expire_t > data.t then
							reaction = math_min(REACT_AIM, reaction)
							target_priority = target_priority * 0.01
						end

						-- prefer shooting enemies the player is not aiming at
						if ub_priority.player_aim ~= 1 and follow_look_vec then
							local att_head_pos = att_movement:m_head_pos()
							if not World:raycast("ray", follow_head_pos, att_head_pos, "slot_mask", visibility_slotmask, "ray_type", "ai_vision", "report") then
								mvec_dir(tmp_vec, follow_head_pos, att_head_pos)
								target_priority = target_priority * math_lerp(ub_priority.player_aim, 1, math_max(0, follow_look_vec:dot(tmp_vec)))
								target_priority = target_priority * math_map_range(follow_look_vec:dot(tmp_vec), -1, 1, ub_priority.player_aim, 1)
							end
						end

						-- ;)
						if att_base._shiny_effect and reaction >= REACT_SHOOT and not ub_priority.enemies[att_tweak_name] then
							target_priority = target_priority * 0.01
							reaction = REACT_AIM
						end
					end
				elseif has_alerted and not_assisting and distance < 2000 or high_priority then
					valid_target = true
					reaction = math_min(reaction, REACT_AIM)
					target_priority = target_priority * 0.01
				end

				if valid_target and target_priority > best_target_priority then
					best_target = attention_data
					best_target_priority = target_priority
					best_target_reaction = reaction
				end
			end
		end
	end
	return best_target, 3 / math_max(best_target_priority, 0.1), best_target_reaction
end

-- Stop bots from dropping light bags when going to revive a player and stop them immediately on being told to hold position
local on_long_dis_interacted_original = TeamAILogicIdle.on_long_dis_interacted
function TeamAILogicIdle.on_long_dis_interacted(data, other_unit, secondary, ...)
	if data.brain._current_logic_name == "disabled" or data.objective and data.objective.type == "revive" then
		return
	end

	local movement = data.unit:movement()

	if not Keepers and secondary then
		if UsefulBots.settings.stop_at_player then
			local tracker = other_unit:movement():nav_tracker()
			movement:set_should_stay(true, tracker:lost() and tracker:field_position() or tracker:position())
		else
			movement:set_should_stay(true, data.m_pos)
		end
		return
	end

	local bag = movement._carry_unit
	local can_run = bag and movement:carry_tweak() and movement:carry_tweak().can_run

	on_long_dis_interacted_original(data, other_unit, secondary, ...)

	local objective_type = data.objective and data.objective.type
	if objective_type == "revive" and bag and can_run and not movement:carrying_bag() then
		bag:carry_data():link_to(data.unit, false)
		movement:set_carrying_bag(bag)
	end
end

function TeamAILogicIdle._check_objective_pos(data)
	if data.path_fail_t and data.t - data.path_fail_t < 6 then
		return
	end

	local objective = data.objective
	if not objective or objective.type ~= "defend_area" or not objective.in_place then
		return
	end

	if objective.pos then
		if math.abs(data.m_pos.x - objective.pos.x) < 10 and math.abs(data.m_pos.y - objective.pos.y) < 10 then
			return
		end
	elseif objective.nav_seg == data.unit:movement():nav_tracker():nav_segment() then
		return
	end

	objective.in_place = false
	objective.path_data = nil
	TeamAILogicBase._exit(data.unit, "travel")
end

if not Keepers then
	Hooks:PostHook(TeamAILogicIdle, "action_complete_clbk", "action_complete_clbk_ub", TeamAILogicIdle._check_objective_pos)
end
