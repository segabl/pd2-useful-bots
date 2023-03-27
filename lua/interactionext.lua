if not Network:is_server() then
	return
end

-- Stop bots revive objective if someone else starts reviving
Hooks:PostHook(ReviveInteractionExt, "_at_interact_start", "_at_interact_start_ub", function (self, player)
	self._block_revive_SO = (self._block_revive_SO or 0) + 1

	local reviving_bot = UsefulBots:get_reviving_unit(self._unit)
	if not reviving_bot or player == reviving_bot then
		return
	end

	reviving_bot:brain():set_objective(nil)

	if UsefulBots.settings.defend_reviving then
		local objective = UsefulBots:get_assist_objective(self._unit)
		objective.in_place = objective.nav_seg == reviving_bot:movement():nav_tracker():nav_segment()
		reviving_bot:brain():set_objective(objective)
	end
end)

Hooks:PostHook(ReviveInteractionExt, "_at_interact_interupt", "_at_interact_interupt_ub", function (self)
	if self._block_revive_SO then
		if self._block_revive_SO > 1 then
			self._block_revive_SO = self._block_revive_SO - 1
		else
			self._block_revive_SO = nil
		end
	end
end)

Hooks:PostHook(ReviveInteractionExt, "remove_interact", "remove_interact_ub", function (self)
	UsefulBots:stop_assist_objective(self._unit)
	self._block_revive_SO = nil
end)
