-- make bots aware of cloaker attacks
local _chk_request_action_spooc_attack_original = SpoocLogicAttack._chk_request_action_spooc_attack
function SpoocLogicAttack._chk_request_action_spooc_attack(data, ...)
	local result = _chk_request_action_spooc_attack_original(data, ...)

	if result then
		for _, c_data in pairs(managers.groupai:state():all_AI_criminals()) do
			local brain = c_data.unit:brain()
			local logic = brain._current_logic
			local logic_data = brain._logic_data
			local internal_logic_data = logic_data.internal_data

			if internal_logic_data.detection_task_key then
				logic.damage_clbk(logic_data, {
					attacker_unit = data.unit,
					result = {}
				})
				CopLogicBase.unqueue_task(internal_logic_data, internal_logic_data.detection_task_key)
				logic._upd_enemy_detection(logic_data)
			end
		end
	end

	return result
end
