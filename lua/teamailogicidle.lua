local math_min = math.min
local math_max = math.max
local math_lerp = math.lerp
local mvec_set = mvector3.set
local mvec_sub = mvector3.subtract
local mvec_norm = mvector3.normalize
local tmp_vec = Vector3()

TeamAILogicIdle._intimidate_resist = {}
TeamAILogicIdle._intimidate_progress = {}

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
			if dis < (escort and 500 or max_dis) and angle < (use_default_shout_shape and math.max(8, math.lerp(90, 30, dis / 1200)) or max_angle) then
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
	if data._next_intimidate_t and data.t < data._next_intimidate_t then
		return
	end

	data._next_intimidate_t = data.t + 2

	local best_civ, highest_wgt, intimidateable_civilians = TeamAILogicIdle._find_intimidateable_civilians(criminal, true)

	local plural = false
	if #intimidateable_civilians > 1 then
		plural = true
	elseif #intimidateable_civilians <= 0 then
		return
	end

	local is_escort = tweak_data.character[best_civ:base()._tweak_table].is_escort
	local sound_name = is_escort and "f40_any" or (best_civ:anim_data().drop and "f03a_" or "f02x_") .. (plural and "plu" or "sin")
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
	if distance > tweak_data.player.long_dis_interaction.intimidate_range_enemies then
		-- too far away
		return false
	end
	if unit_anim.hands_back or unit_anim.surrender then
		-- unit is already surrendering
		return true
	end
	if UsefulBots.settings.dominate_enemies > 1 then
		-- unit is not surrendering and we only allow domination assists
		return false
	end
	if not managers.groupai:state():has_room_for_police_hostage() then
		-- no room for police hostage
		return false
	end
	local health_min, health_max
	for k, _ in pairs(unit_tweak.surrender.reasons and unit_tweak.surrender.reasons.health or {}) do
		health_min = (not health_min or k < health_min) and k or health_min
		health_max = (not health_max or k > health_max) and k or health_max
	end
	local is_hurt = health_min and health_max and unit_damage:health_ratio() < health_min + (health_max - health_min) / 2
	if not is_hurt then
		-- not vulnerable
		return false
	end
	local resist = TeamAILogicIdle._intimidate_resist[unit:key()]
	if resist and resist > 1 then
		-- resisted too often
		return false
	end
	local num = 0
	local max = 1 + table.count(managers.groupai:state():all_char_criminals(), function (u_data) return u_data == "dead" end) * 2
	local m_pos = data.unit:movement():m_pos()
	local dist_sq = tweak_data.player.long_dis_interaction.intimidate_range_enemies * tweak_data.player.long_dis_interaction.intimidate_range_enemies * 4
	local u_damage, u_movement
	for _, v in pairs(data.detected_attention_objects) do
		u_damage = v.unit and v.unit.character_damage and v.unit:character_damage()
		u_movement = v.unit and v.unit.movement and v.unit:movement()
		if v.verified and v.unit ~= unit and u_damage and not u_damage:dead() and u_movement and mvector3.distance_sq(u_movement:m_pos(), m_pos) < dist_sq then
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
	local new_action = {
		type = "act",
		variant = (anim.hands_back or anim.surrender) and "arrest" or "gesture_stop",
		body_part = 3,
		align_sync = true
	}
	data.unit:brain():action_request(new_action)
	target:brain():on_intimidated(tweak_data.player.long_dis_interaction.intimidate_strength, data.unit)

	local objective = target:brain():objective()
	if not objective or objective.type ~= "surrender" then
		TeamAILogicIdle._intimidate_resist[target:key()] = (TeamAILogicIdle._intimidate_resist[target:key()] or 0) + 1
	end
end

local _get_priority_attention_original = TeamAILogicIdle._get_priority_attention
function TeamAILogicIdle._get_priority_attention(data, attention_objects, reaction_func, ...)
	local ub_priority = UsefulBots.settings.targeting_priority
	if ub_priority.base_priority > 2 then
		return _get_priority_attention_original(data, attention_objects, reaction_func, ...)
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
			local att_base = att_unit.base and att_unit:base()
			local att_tweak_name = att_base and att_base._tweak_table
			local att_tweak = attention_data.char_tweak or att_tweak_name and tweak_data.character[att_tweak_name] or {}
			local att_brain = att_unit.brain and att_unit:brain()
			local att_anim = att_unit.anim_data and att_unit:anim_data() or {}
			local att_movement = att_unit.movement and att_unit:movement()
			local att_damage = att_unit.character_damage and att_unit:character_damage()

			local has_alerted = attention_data.alert_t and data.t - attention_data.alert_t < 3
			local has_damaged = attention_data.dmg_t and data.t - attention_data.dmg_t < 2
			local been_marked = attention_data.mark_t and data.t - attention_data.mark_t < 10
			local is_tied = att_anim.hands_tied
			local is_dead = not att_damage or att_damage:dead()
			local is_special = attention_data.is_very_dangerous or att_tweak.priority_shout
			local is_turret = att_base and att_base.sentry_gun
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
			if att_unit:in_slot(data.enemy_slotmask) and not is_tied and not is_dead and attention_data.verified then
				valid_target = true

				local high_priority = TeamAILogicIdle.is_high_priority(att_unit, att_movement, att_brain)
				local should_intimidate = not high_priority and TeamAILogicIdle.is_valid_intimidation_target(att_unit, att_tweak, att_anim, att_damage, data, distance)
				local marked_contour = is_special and att_unit.contour and att_unit:contour():find_id_match("^mark_enemy")
				local marked_by_player = marked_contour and (marked_contour ~= "mark_enemy" or not been_marked)

				-- check for reaction changes
				reaction = should_intimidate and REACT_ARREST or (high_priority or is_special or has_damaged or been_marked) and math_max(REACT_SHOOT, reaction) or reaction

				-- get target priority multipliers
				target_priority = target_priority * (should_intimidate and ub_priority.domination or 1) * (high_priority and ub_priority.critical or 1) * (has_damaged and ub_priority.damaged or 1) * (marked_by_player and ub_priority.marked or 1) * (is_turret and ub_priority.enemies.turret or 1) * (ub_priority.enemies[att_tweak_name] or 1)

				-- give a slight boost to priority if this is our current target (to avoid switching targets too much if the other one is still alive and visible)
				if data.attention_obj == attention_data then
					target_priority = target_priority * 1.1
				end

				-- reduce priority if we would hit a shield
				if TeamAILogicIdle._ignore_shield(data.unit, attention_data) then
					target_priority = target_priority * 0.01
				end

				-- reduce reaction and priority if someone is trying to intimidate, but we are not
				if not should_intimidate and TeamAILogicIdle._intimidate_progress[u_key] and TeamAILogicIdle._intimidate_progress[u_key] + 2 > data.t then
					reaction = math_min(REACT_AIM, reaction)
					target_priority = target_priority * 0.01
				end

				-- prefer shooting enemies the player is not aiming at
				if ub_priority.player_aim ~= 1 and follow_look_vec then
					mvec_set(tmp_vec, att_movement:m_head_pos())
					mvec_sub(tmp_vec, follow_head_pos)
					mvec_norm(tmp_vec)
					target_priority = target_priority * math_lerp(ub_priority.player_aim, 1, math_max(0, follow_look_vec:dot(tmp_vec)))
				end

				-- ;)
				if att_base._shiny_effect and reaction >= REACT_SHOOT then
					target_priority = target_priority * 0.01
					reaction = REACT_AIM
				end
			elseif has_alerted and not is_dead then
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
	return best_target, best_target and 3 / math_max(best_target_priority, 0.1), best_target_reaction
end
