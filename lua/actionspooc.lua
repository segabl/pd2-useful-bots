if not Network:is_server() then
	return
end

-- make bots aware of cloaker attacks
Hooks:PostHook(ActionSpooc, "init", "init_ub", function (self)
	UsefulBots:force_attention(self._unit)
end)
