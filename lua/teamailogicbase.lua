local tmp_vec = Vector3()

Hooks:PostHook(TeamAILogicBase, "_set_attention_obj", "_set_attention_obj_ub", function (data, att, react)
	if not att or not att.verified or not react then
		return
	end

	-- early abort
	if data.cool or data.internal_data.acting or data.objective and data.objective.type == "revive" then
		return
	end

	if data.unit:movement():chk_action_forbidden("action") or data.unit:anim_data().reload or data.unit:character_damage():is_downed() then
		return
	end

	if not alive(att.unit) or not att.unit:character_damage() or att.unit:character_damage():dead() then
		return
	end

	-- only do intimidation/marking if we are actually looking in that direction
	mvector3.set(tmp_vec, att.unit:movement():m_head_pos())
	mvector3.subtract(tmp_vec, data.unit:movement():m_head_pos())
	if tmp_vec:angle(data.unit:movement():m_rot():y()) > 50 then
		return
	end

	-- intimidate
	if react == AIAttentionObject.REACT_ARREST and (not data._next_intimidate_t or data._next_intimidate_t < data.t) then
		local act_action = att.unit:movement():_get_latest_act_action()
		if not act_action or not act_action._enter_t or act_action._enter_t + 1 < data.t then
			TeamAILogicIdle.intimidate_cop(data, att.unit)
			data._next_intimidate_t = data.t + tweak_data.player.movement_state.interaction_delay
			return
		end
	end

	-- mark
	if UsefulBots.settings.mark_specials and (not data._next_mark_t or data._next_mark_t < data.t) then
		if att.char_tweak and att.char_tweak.priority_shout and not att.unit:contour():find_id_match("^mark_enemy") then
			if att.unit:character_damage():health_ratio() > 0.6 and att.dis <= tweak_data.player.long_dis_interaction.highlight_range then
				if not TeamAILogicIdle.is_high_priority(att.unit:movement()) then
					if not World:raycast("ray", data.m_pos, att.m_pos, "slot_mask", data.visibility_slotmask, "report") then
						TeamAILogicAssault.mark_enemy(data, data.unit, att.unit)
						att.mark_t = data.t
						data._next_mark_t = data.t + 16
						return
					end
				end
			end
		end
	end
end)

Hooks:PostHook(TeamAILogicBase, "on_new_objective", "on_new_objective_ub", function (data)
	local objective = data.objective
	if not objective then
		return
	end

	if objective.type == "follow" then
		data._latest_follow_unit = objective.follow_unit
	end

	if objective.type == "revive" or objective.assist_unit then
		objective.no_idle_delay = true
		data.brain:action_request({
			body_part = 3,
			type = "idle"
		})
	end
end)

function TeamAILogicBase.force_attention(data, my_data, unit)
	if data.cool then
		return
	end

	local logic_supports_shooting = data.name == "assault" or data.name == "travel"
	if not logic_supports_shooting and not data.logic.is_available_for_assignment(data) then
		return
	end

	local att_obj_data = TeamAILogicBase.identify_attention_obj_instant(data, unit:key())
	if not att_obj_data then
		return
	end

	TeamAILogicBase._upd_attention_obj_detection(data, AIAttentionObject.REACT_SHOOT, nil)

	local new_attention = TeamAILogicIdle._get_priority_attention(data, data.detected_attention_objects, nil)
	if not new_attention or new_attention.u_key ~= att_obj_data.u_key then
		return
	end

	local is_new = data.attention_obj ~= new_attention
	TeamAILogicBase._set_attention_obj(data, new_attention, AIAttentionObject.REACT_SHOOT)

	if not logic_supports_shooting then
		if data.objective and data.objective.type == "act" then
			data.objective_failed_clbk(data.unit, data.objective)
		end
		TeamAILogicBase._exit(data.unit, "assault")
	end

	if is_new then
		CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, new_attention.m_pos)
	end
	TeamAILogicAssault._upd_aim(data, my_data)
end

-- This function is disabled in vanilla but is not part of other logics so it might crash in other logics when called with data.logic._upd_sneak_spotting
function TeamAILogicBase._upd_sneak_spotting() end

function TeamAILogicBase.chk_should_turn() end

-- Wait before switching to idle
function TeamAILogicBase._get_logic_state_from_reaction(data, reaction)
	local state = (not reaction or reaction <= AIAttentionObject.REACT_SCARED) and "idle" or "assault"

	if state == "assault" then
		data.last_assault_state_t = data.t
	elseif data.last_assault_state_t and data.t < data.last_assault_state_t + (data.objective and data.objective.type == "defend_area" and 10 or 5) then
		state = "assault"
	end

	return state
end

function TeamAILogicBase._check_deliver_bag(data)
	if Monkeepers or not UsefulBots.settings.secure_loot then
		return
	end

	local objective = data.objective
	if not objective then
		return
	end

	local carry_unit = data.unit:movement()._carry_unit
	if objective.loot_secure_trigger then
		if not alive(carry_unit) or not objective.loot_secure_trigger:ub_can_secure_loot(carry_unit) then
			data.brain:set_objective(nil)
			return true
		end
	elseif objective.pickup_carry_unit then
		if alive(carry_unit) or not alive(objective.pickup_carry_unit) or objective.pickup_carry_unit:carry_data():is_linked_to_unit() then
			data.brain:set_objective(nil)
			return true
		end
	end

	if objective.type ~= "follow" then
		return
	end

	if not carry_unit then
		return TeamAILogicBase._check_pickup_bag(data)
	end

	local secure_bag_data = data.secure_bag_data[objective.follow_unit:key()]
	if not secure_bag_data then
		return
	end

	local secure_info
	local closest_area_trigger
	local closest_area_trigger_dis_sq = math.huge
	local carry_type_tweak = carry_unit:carry_data():carry_type_tweak()
	local carry_throw_multiplier = carry_type_tweak and carry_type_tweak.throw_distance_multiplier or 1
	for area_trigger, area_trigger_data in pairs(secure_bag_data) do
		secure_info = area_trigger_data[carry_throw_multiplier] or area_trigger_data[next(area_trigger_data)]
		local dis_sq = area_trigger:ub_can_secure_loot(carry_unit) and TeamAILogicBase:_check_bag_dis(data, secure_info.pos, 1000)
		if dis_sq and dis_sq < closest_area_trigger_dis_sq then
			closest_area_trigger = area_trigger
			break
		end
	end

	if not closest_area_trigger then
		return
	end

	data.brain:set_objective({
		type = "free",
		loot_secure_trigger = closest_area_trigger,
		path_ahead = true,
		haste = "run",
		pose = "stand",
		pos = secure_info.pos,
		rot = Rotation:look_at(secure_info.dir:with_z(0), math.UP),
		nav_seg = managers.navigation:get_nav_seg_from_pos(secure_info.pos, true),
		followup_objective = {
			type = "act",
			in_place = true,
			action_duration = 0.5,
			action = {
				type = "stand",
				body_part = 1
			},
			complete_clbk = function(unit)
				carry_unit = unit:movement()._carry_unit
				if alive(carry_unit) then
					unit:movement():throw_bag()
					carry_unit:carry_data():set_position_and_throw(secure_info.bag_pos, secure_info.dir, 100)
					carry_unit:carry_data():set_latest_peer_id(nil)
				end
			end
		}
	})

	return true
end

function TeamAILogicBase._check_pickup_bag(data)
	if data._next_bag_check_t and data._next_bag_check_t > data.t then
		return
	end

	data._next_bag_check_t = data.t + 1

	local secure_bag_data = data.secure_bag_data[data.objective.follow_unit:key()]
	if not secure_bag_data then
		return
	end

	local blocked = {}
	for _, v in pairs(managers.groupai:state():all_AI_criminals()) do
		local other_objective = v.unit:brain():objective()
		if other_objective and other_objective.pickup_carry_unit then
			blocked[other_objective.pickup_carry_unit:key()] = true
		end
	end

	local closest_bag
	local closest_bag_dis_sq = math.huge
	for u_key, unit in pairs(CarryData.ub_loot) do
		if not blocked[u_key] and unit:sampled_velocity():length() == 0 then
			for area_trigger in pairs(secure_bag_data) do
				local dis_sq = area_trigger:ub_can_secure_loot(unit) and TeamAILogicBase:_check_bag_dis(data, unit:position(), 1000)
				if dis_sq and dis_sq < closest_bag_dis_sq then
					closest_bag_dis_sq = dis_sq
					closest_bag = unit
				end
			end
		end
	end

	if not closest_bag then
		return
	end

	local tracker = managers.navigation:create_nav_tracker(closest_bag:position(), false)
	local pos = tracker:field_position()
	local nav_seg = tracker:nav_segment()
	managers.navigation:destroy_nav_tracker(tracker)

	data.brain:set_objective({
		type = "free",
		pickup_carry_unit = closest_bag,
		path_ahead = true,
		haste = "run",
		pose = "stand",
		pos = pos,
		nav_seg = nav_seg,
		followup_objective = {
			type = "act",
			in_place = true,
			action_duration = 1,
			action = {
				type = "act",
				variant = "untie",
				body_part = 1
			},
			complete_clbk = function(unit)
				if alive(closest_bag) and not closest_bag:carry_data():is_linked_to_unit() and not unit:movement()._carry_unit then
					unit:movement():set_carrying_bag(closest_bag)
					closest_bag:carry_data():link_to(unit)
				end
			end
		}
	})

	return true
end

function TeamAILogicBase:_check_bag_dis(data, pos, max_dis)
	local max_dis_sq = max_dis ^ 2
	local dis_sq = mvector3.distance_sq(data.m_pos, pos)
	if math.abs(data.m_pos.z - pos.z) < 200 and dis_sq < max_dis_sq then
		return dis_sq
	end

	local follow_pos = alive(data._latest_follow_unit) and data._latest_follow_unit:movement():m_newest_pos()
	if follow_pos and math.abs(follow_pos.z - pos.z) < 200  and mvector3.distance_sq(follow_pos, pos) < max_dis_sq then
		return dis_sq
	end
end
