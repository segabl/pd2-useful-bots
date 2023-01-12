if Keepers or not Network:is_server() then
	return
end

TeamAIMovement.chk_action_forbidden = CopMovement.chk_action_forbidden

Hooks:PreHook(TeamAIMovement, "set_should_stay", "set_should_stay_ub", function (self, should_stay, pos)
	if should_stay and pos then
		self._should_stay_objective = {
			type = "defend_area",
			pos = mvector3.copy(pos),
			nav_seg = managers.navigation:get_nav_seg_from_pos(pos)
		}
		self._ext_brain:set_objective(self._should_stay_objective)
	elseif not should_stay and self._should_stay then
		self._ext_brain:set_objective(nil)
	end
end)
