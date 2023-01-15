if not Network:is_server() then
	return
end

-- Make bots aware of tasers starting a tase action
Hooks:PostHook(CopActionTase, "init", "init_ub", function (self)
	UsefulBots:force_attention(self._unit)
end)
