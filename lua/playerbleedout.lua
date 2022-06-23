-- Stop bots from dropping light bags when going to revive a player
local on_rescue_SO_administered_original = PlayerBleedOut.on_rescue_SO_administered
function PlayerBleedOut:on_rescue_SO_administered(revive_SO_data, receiver_unit, ...)
	local movement = receiver_unit:movement()
	local bag = movement._carry_unit
	local can_run = bag and movement:carry_tweak() and movement:carry_tweak().can_run

	on_rescue_SO_administered_original(self, revive_SO_data, receiver_unit, ...)

	if bag and can_run and not movement:carrying_bag() then
		bag:carry_data():link_to(receiver_unit, false)
		movement:set_carrying_bag(bag)
	end
end
