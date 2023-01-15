if not Network:is_server() then
	return
end

-- Fix assistance SO so bots return to their hold position when done
function HuskPlayerMovement:set_need_assistance(need_assistance)
	if self._need_assistance == need_assistance then
		return
	end

	self._need_assistance = need_assistance

	if need_assistance and not self._assist_SO_id then
		self._assist_SO_id = "PlayerHusk_assistance" .. tostring(self._unit:key())
		managers.groupai:state():add_special_objective(self._assist_SO_id, UsefulBots:get_assist_SO(self._unit))
	elseif not need_assistance and self._assist_SO_id then
		UsefulBots:stop_assist_SO(self._unit)
		managers.groupai:state():remove_special_objective(self._assist_SO_id)
		self._assist_SO_id = nil
	end
end
