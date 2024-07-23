if not Network:is_server() then
	return
end

local valid_carry_operations = {
	secure = true,
	secure_silent = true
}

local valid_instigators = {
	loot = true,
	unique_loot = true
}

local function get_loot_secure_elements(current, recursion_depth, found_elements)
	recursion_depth = recursion_depth or 10
	found_elements = found_elements or {}
	for _, params in pairs(current._values.on_executed) do
		local element = current:get_mission_element(params.id)
		local element_class = getmetatable(element)
		if element_class == ElementCarry and valid_carry_operations[element._values.operation] then
			found_elements[element] = element
		end
		if recursion_depth > 0 then
			get_loot_secure_elements(element, recursion_depth - 1, found_elements)
		end
	end
	return found_elements
end

Hooks:PostHook(ElementAreaTrigger, "on_script_activated", "on_script_activated_ub", function (self)
	if valid_instigators[self._values.instigator] then
		self._loot_secure_elements = get_loot_secure_elements(self)
	end
end)

Hooks:PreHook(ElementAreaTrigger, "on_executed", "on_executed_ub", function (self, instigator)
	local throw_params = self:ub_can_secure_loot(instigator) and instigator:carry_data()._ub_throw_params
	if not throw_params or throw_params.expire_t < TimerManager:game():time() then
		return
	end

	local peer = managers.network:session():peer(instigator:carry_data():latest_peer_id())
	local peer_unit = peer and peer:unit()
	if not alive(peer_unit) then
		return
	end

	local u_key = peer_unit:key()
	local carry_type_tweak = instigator:carry_data():carry_type_tweak()
	local carry_throw_multiplier = carry_type_tweak and carry_type_tweak.throw_distance_multiplier or 1
	for _, v in pairs(managers.groupai:state():all_AI_criminals()) do
		local logic_data = v.unit:brain()._logic_data
		logic_data.secure_bag_data[u_key] = logic_data.secure_bag_data[u_key] or {}
		logic_data.secure_bag_data[u_key][self] = logic_data.secure_bag_data[u_key][self] or {}
		logic_data.secure_bag_data[u_key][self][carry_throw_multiplier] = throw_params
	end
end)

function ElementAreaTrigger:ub_can_secure_loot(unit)
	if Monkeepers or not UsefulBots.settings.secure_loot or not self._values.enabled or not self._loot_secure_elements or not self:is_instigator_valid(unit) then
		return
	end

	local carry_data = alive(unit) and unit:carry_data()
	if not carry_data then
		return
	end

	local carry_id = carry_data:carry_id()
	for element in pairs(self._loot_secure_elements) do
		if element._values.enabled and (not element._values.type_filter or element._values.type_filter == "none" or carry_id == element._values.type_filter) then
			return true
		end
	end
end
