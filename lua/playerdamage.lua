if not Network:is_server() then
	return
end

-- Stop bots revive objective if someone else starts reviving
Hooks:PostHook(PlayerDamage, "pause_downed_timer", "pause_downed_timer_ub", function(self, timer, peer_id)
	if not peer_id then
		return
	end

	local reviving_bot = UsefulBots:get_reviving_unit(self._unit)
	if not reviving_bot then
		return
	end

	local internal_data = reviving_bot:brain()._logic_data.internal_data
	local revive_complete_clbk_id = internal_data and internal_data.revive_complete_clbk_id
	local revive_complete_t = revive_complete_clbk_id and managers.enemy:get_delayed_clbk_exec_t(revive_complete_clbk_id)
	if revive_complete_t and revive_complete_t - TimerManager:game():time() < 2 then
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
