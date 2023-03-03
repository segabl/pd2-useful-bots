if not Network:is_server() then
	return
end

-- Make bots aware of tasers starting a tase action
Hooks:PostHook(CopActionTase, "init", "init_ub", function (self)
	self._is_sabotaging_action = true
	UsefulBots:force_attention(self._unit)
end)
