if not Network:is_server() then
	return
end

-- Fix assistance SO so bots return to their hold position when done
function PlayerTased:_register_revive_SO()
	if self._SO_id or not managers.navigation:is_data_ready() then
		return
	end

	self._SO_id = "PlayerTased_assistance"
	managers.groupai:state():add_special_objective(self._SO_id, UsefulBots:get_assist_SO(self._unit))
end

Hooks:PostHook(PlayerTased, "exit", "exit_ub", function (self)
	UsefulBots:stop_assist_objective(self._unit)
	self._SO_id = nil
end)
