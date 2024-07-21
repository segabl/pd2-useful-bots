if not Network:is_server() then
	return
end

Hooks:PostHook(PlayerManager, "sync_carry_data", "sync_carry_data_ub", function (self, unit, carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, position, dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer_id)
	if alive(zipline_unit) or not peer_id or peer_id == 0 then
		return
	end

	local throw_distance_multiplier = self:upgrade_value_by_level("carry", "throw_distance_multiplier", throw_distance_multiplier_upgrade_level, 1)
	throw_distance_multiplier = throw_distance_multiplier * tweak_data.carry.types[tweak_data.carry[carry_id].type].throw_distance_multiplier

	if managers.mutators:is_mutator_active(MutatorPiggyRevenge) then
		local mutator = managers.mutators:get_mutator(MutatorPiggyRevenge)
		if mutator.get_bag_throw_multiplier then
			throw_distance_multiplier = throw_distance_multiplier * mutator:get_bag_throw_multiplier(carry_id)
		end
	end

	unit:carry_data()._ub_throw_params = {
		expire_t = TimerManager:game():time() + 3,
		bag_pos = unit:position(),
		pos = mvector3.copy(managers.network:session():peer(peer_id):unit():movement():m_newest_pos()),
		dir = dir * 600 * throw_distance_multiplier
	}
end)
