if not Network:is_server() then
	return
end

-- queued actions are not initialized for some reason
Hooks:PostHook(TeamAIMovement, "init", "init_ub", function (self)
	self._queued_actions = {}
end)

local action_request_original = TeamAIMovement.action_request
function TeamAIMovement:action_request(action_desc, ...)
	if not self:can_request_actions() then
		return
	end

	-- Wait a bit before ending shoot action
	if action_desc.body_part == 3 then
		local active_action = self._active_actions[3]
		if active_action and active_action:type() == "shoot" and action_desc.type == "idle" and not action_desc.skip_wait then
			local t = TimerManager:game():time()
			if not self._switch_upper_body_to_idle_t then
				self._switch_upper_body_to_idle_t = t + (self._ext_brain:objective() and self._ext_brain:objective().type == "defend_area" and 6 or 3)
				return
			elseif self._switch_upper_body_to_idle_t > t then
				return
			end
		end

		self._switch_upper_body_to_idle_t = nil
	end

	return action_request_original(self, action_desc, ...)
end

if Keepers then
	return
end

TeamAIMovement.chk_action_forbidden = CopMovement.chk_action_forbidden

Hooks:PostHook(TeamAIMovement, "set_should_stay", "set_should_stay_ub", function (self, should_stay, pos)
	if should_stay and pos then
		self._should_stay_pos = mvector3.copy(pos)
	end
	self._ext_brain:set_objective(managers.groupai:state():_determine_objective_for_criminal_AI(self._unit))
end)
