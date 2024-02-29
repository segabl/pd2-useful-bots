-- Adapted from LIES
Hooks:PostHook(SentryGunBase, "activate_as_module", "activate_as_module_ub", function (self)
	if self._unit:brain()._attention_handler then
		self._unit:brain()._attention_handler:set_team(self._unit:movement():team())
	end
end)
