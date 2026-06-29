Hooks:PostHook(CopBrain, "on_intimidated", "on_intimidated_ub", function(self)
	self._logic_data._next_intimidate_t = self._logic_data.t + tweak_data.player.movement_state.interaction_delay
end)
