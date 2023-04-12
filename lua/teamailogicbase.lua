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

	local u_key = unit:key()
	local att_obj_data = data.detected_attention_objects[u_key]
	if not att_obj_data then
		TeamAILogicIdle.damage_clbk(data, {attacker_unit = unit, result = {}})

		att_obj_data = data.detected_attention_objects[u_key]
		if not att_obj_data then
			return
		end
	end

	local from, to = data.unit:movement():m_head_pos(), att_obj_data.handler:get_detection_m_pos()
	local ray = World:raycast("ray", from, to, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")
	att_obj_data.verified = not ray or ray.unit == unit
	att_obj_data.pause_expire_t = nil
	att_obj_data.stare_expire_t = nil

	local new_attention, _, new_reaction = TeamAILogicIdle._get_priority_attention(data, data.detected_attention_objects, nil)
	if not new_attention or new_reaction < AIAttentionObject.REACT_SHOOT then
		new_attention = att_obj_data
		new_reaction = att_obj_data.verified and AIAttentionObject.REACT_SHOOT or AIAttentionObject.REACT_AIM
	elseif new_attention ~= att_obj_data then
		return
	end

	local is_new = data.attention_obj ~= new_attention
	data.attention_obj = new_attention
	data.attention_obj.reaction = new_reaction

	if new_attention.dis > (new_attention.verified and 4000 or 400) then
		return
	end

	if data.name ~= "assault" and data.name ~= "travel" then
		if not data.logic.is_available_for_assignment(data) then
			return
		end

		if data.objective and data.objective.type == "act" then
			data.objective_failed_clbk(data.unit, data.objective)
		end

		CopLogicBase._exit(data.unit, "assault")

		if data.name ~= "assault" then
			return
		end
	end

	if is_new then
		CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, new_attention.m_pos)
	end
	TeamAILogicAssault._upd_aim(data, my_data)
end

-- This function is disabled in vanilla but is not part of other logics so it might crash in other logics when called with data.logic._upd_sneak_spotting
function TeamAILogicBase._upd_sneak_spotting() end

function TeamAILogicBase.chk_should_turn() end
