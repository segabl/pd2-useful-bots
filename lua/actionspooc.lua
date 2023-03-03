if not Network:is_server() then
	return
end

-- make bots aware of cloaker attacks
Hooks:PostHook(ActionSpooc, "init", "init_ub", function (self)
	self._is_sabotaging_action = true
	UsefulBots:force_attention(self._unit)
end)
