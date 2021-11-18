local _create_seat_SO_original = VehicleDrivingExt._create_seat_SO
function VehicleDrivingExt:_create_seat_SO(...)
	-- Dont enter vehicles that are slower than the bot
	if not UsefulBots.settings.block_slow_vehicles or self._tweak_data.max_speed * (1000 / 60) > tweak_data.character.russian.move_speed.stand.run.cbt.fwd then
		return _create_seat_SO_original(self, ...)
	end
end
