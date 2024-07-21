if not Network:is_server() then
	return
end

CarryData.ub_loot = {}

Hooks:PostHook(CarryData, "set_carry_id", "set_carry_id_ub", function (self, carry_id, is_init)
	if not is_init then
		CarryData.ub_loot[self._unit:key()] = self._unit
	end
end)

Hooks:PreHook(CarryData, "destroy", "destroy_ub", function (self)
	CarryData.ub_loot[self._unit:key()] = nil
end)

Hooks:PostHook(CarryData, "link_to", "link_to_ub", function (self)
	if self._linked_to then
		CarryData.ub_loot[self._unit:key()] = nil
	end
end)

Hooks:PostHook(CarryData, "unlink", "unlink_ub", function (self)
	CarryData.ub_loot[self._unit:key()] = self._unit
end)

Hooks:PostHook(CarryData, "set_latest_peer_id", "set_latest_peer_id_ub", function (self, peer_id)
	CarryData.ub_loot[self._unit:key()] = peer_id and self._unit or nil
end)

Hooks:PostHook(CarryData, "set_zipline_unit", "set_zipline_unit_ub", function (self, zipline_unit)
	CarryData.ub_loot[self._unit:key()] = not zipline_unit and self._unit or nil
end)
