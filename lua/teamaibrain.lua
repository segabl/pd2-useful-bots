-- adjust slotmask to allow attacking turrets
Hooks:PostHook(TeamAIBrain, "_reset_logic_data", "_reset_logic_data_ub", function (self)
	self._logic_data.is_team_ai = true
	if UsefulBots.settings.targeting_priority.enemies.turret > 0 then
		self._logic_data.enemy_slotmask = self._logic_data.enemy_slotmask + World:make_slot_mask(25)
	end
end)
