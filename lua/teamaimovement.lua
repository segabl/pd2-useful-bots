if Keepers or not Network:is_server() then
	return
end

TeamAIMovement.chk_action_forbidden = CopMovement.chk_action_forbidden

Hooks:PostHook(TeamAIMovement, "set_should_stay", "set_should_stay_ub", function (self, should_stay, pos)
	if should_stay and pos then
		self._should_stay_pos = mvector3.copy(pos)
	end
	self._ext_brain:set_objective(managers.groupai:state():_determine_objective_for_criminal_AI(self._unit))
end)
