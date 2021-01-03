Hooks:PreHook(CopLogicIdle, "on_intimidated", "on_intimidated_ub", function (data)
	if not managers.groupai:state():is_enemy_special(data.unit) then
		TeamAILogicIdle._intimidate_progress[data.unit:key()] = data.t
	end
end)
