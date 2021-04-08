local tmp_vec = Vector3()
Hooks:PostHook(TeamAILogicBase, "_set_attention_obj", "_set_attention_obj_ub", function (data, att, react)
	if not att or not att.verified or not react then
		return
	end
	-- early abort
	if data.cool or data.internal_data.acting then
		return
	end
	local movement = data.unit:movement()
	if movement:chk_action_forbidden("action") or data.unit:anim_data().reload or data.unit:character_damage():is_downed() then
		return
	end
	if not alive(att.unit) or not att.unit.character_damage or att.unit:character_damage():dead() then
		return
	end
	mvector3.set(tmp_vec, att.unit:movement():m_head_pos())
	mvector3.subtract(tmp_vec, movement:m_head_pos())
	if tmp_vec:angle(movement:m_rot():y()) > 50 then
		return
	end
	-- intimidate
	if react == AIAttentionObject.REACT_ARREST and (not data._next_intimidate_t or data._next_intimidate_t < data.t) then
		local key = att.unit:key()
		local intimidate = TeamAILogicIdle._intimidate_progress[key]
		if not intimidate or intimidate + 1 < data.t then
			TeamAILogicIdle.intimidate_cop(data, att.unit)
			TeamAILogicIdle._intimidate_progress[key] = data.t
			data._next_intimidate_t = data.t + 2
			return
		end
	end
	-- mark
	if UsefulBots.settings.mark_specials and (not data._next_mark_t or data._next_mark_t < data.t) then
		if att.char_tweak and att.char_tweak.priority_shout and not att.unit:contour():find_id_match("^mark_enemy") then
			if att.unit:character_damage():health_ratio() > 0.5 then
				TeamAILogicAssault.mark_enemy(data, data.unit, att.unit)
				att.mark_t = data.t
				data._next_mark_t = data.t + 16
				return
			end
		end
	end
	-- switch weapon
	if data._preferred_selection_index ~= data.unit:inventory():equipped_selection() and (not data._next_weapon_switch_t or data._next_weapon_switch_t < data.t) then
		if HuskPlayerMovement._can_play_weapon_switch_anim(movement) then
			data._next_weapon_switch_t = data.t + 8
			movement:switch_weapon(data._preferred_selection_index)
		end
	end
end)

Hooks:PostHook(TeamAILogicBase, "on_new_objective", "on_new_objective_ub", function (data)
	if data.objective and data.objective.follow_unit then
		data._latest_follow_unit = data.objective.follow_unit
	end
end)
