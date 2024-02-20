-- Stop bots from dropping light bags when going to revive a player
local on_rescue_SO_administered_original = PlayerBleedOut.on_rescue_SO_administered
function PlayerBleedOut:on_rescue_SO_administered(revive_SO_data, receiver_unit, ...)
	local movement = receiver_unit:movement()
	local bag = movement._carry_unit
	local move_speed_modifier = bag and movement:carry_tweak() and movement:carry_tweak().move_speed_modifier or 1

	on_rescue_SO_administered_original(self, revive_SO_data, receiver_unit, ...)

	if bag and move_speed_modifier > 0.75 and not movement:carrying_bag() then
		bag:carry_data():link_to(receiver_unit, false)
		movement:set_carrying_bag(bag)
	end
end
