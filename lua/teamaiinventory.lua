-- Save weapon usage tweak data for easy access
Hooks:PostHook(TeamAIInventory, "add_unit", "add_unit_ub", function (self, new_unit)
	local w_tweak = new_unit:base():weapon_tweak_data()
	self._available_w_usage_tweak = self._available_w_usage_tweak or {}
	self._available_w_usage_tweak[self._latest_addition] = tweak_data.character[self._unit:base()._tweak_table].weapon[w_tweak.usage]
end)
