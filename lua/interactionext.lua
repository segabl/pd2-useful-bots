if not Network:is_server() then
	return
end

-- Stop bots revive objective if someone else starts reviving
Hooks:PreHook(ReviveInteractionExt, "_at_interact_start", "_at_interact_start_ub", function (self, player)
	self._reviving_unit = player
end)

Hooks:PreHook(ReviveInteractionExt, "_at_interact_interupt", "_at_interact_interupt_ub", function (self, player)
	if self._reviving_unit == player then
		self._reviving_unit = nil
	end
end)

Hooks:PreHook(ReviveInteractionExt, "remove_interact", "remove_interact_ub", function (self)
	UsefulBots:stop_assist_objective(self._unit)
	self._reviving_unit = nil
	self._block_revive_SO = nil
end)

Hooks:PostHook(ReviveInteractionExt, "set_waypoint_paused", "set_waypoint_paused_ub", function (self, paused)
	if paused then
		self._block_revive_SO = self._block_revive_SO and self._block_revive_SO + 1 or 1
	else
		self._block_revive_SO =  self._block_revive_SO and self._block_revive_SO > 1 and self._block_revive_SO - 1 or nil
		return
	end

	local reviving_bot = UsefulBots:get_reviving_unit(self._unit)
	if not reviving_bot or self._reviving_unit == reviving_bot then
		return
	end

	reviving_bot:brain():set_objective(nil)
	reviving_bot:movement():action_request({
		body_part = 4,
		type = "stand"
	})

	if UsefulBots.settings.defend_reviving then
		reviving_bot:brain():set_objective(UsefulBots:get_assist_objective(self._unit, reviving_bot))
	else
		reviving_bot:brain():set_objective(managers.groupai:state():_determine_objective_for_criminal_AI(reviving_bot))
	end
end)
