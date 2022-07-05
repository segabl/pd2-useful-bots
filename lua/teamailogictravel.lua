-- Make bots actually use inspire, not only if you are in their detected attention objects
local check_inspire_original = TeamAILogicTravel.check_inspire
function TeamAILogicTravel.check_inspire(data, attention, ...)
	if data.objective and data.objective.action and data.objective.action.variant == "untie" then
		return
	end

	attention = attention or { unit = data.objective.follow_unit }

	if UsefulBots.settings.save_inspire and data.unit:character_damage():health_ratio() > 0.35 then
		local timer = 0
		if attention.unit:base().is_local_player then
			timer = attention.unit:character_damage()._downed_timer or timer
		elseif attention.unit:interaction().get_waypoint_time then
			timer = attention.unit:interaction():get_waypoint_time() or timer
		end

		local path_ratio = 1
		if attention.unit:movement():nav_tracker():nav_segment() == data.unit:movement():nav_tracker():nav_segment() then
			path_ratio = 1
		elseif data.internal_data.coarse_path and data.internal_data.coarse_path_index then
			path_ratio = math.max(data.internal_data.coarse_path_index, 1) / #data.internal_data.coarse_path
		end

		if timer * path_ratio > 10 then
			return
		end
	end

	return check_inspire_original(data, attention, ...)
end
