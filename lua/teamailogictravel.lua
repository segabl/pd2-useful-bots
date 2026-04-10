-- Don't carry over "firing" variable, it has a chance to stopp bots from shooting
Hooks:PostHook(TeamAILogicTravel, "enter", "enter_ub", function (data)
	data.internal_data.firing = nil
end)

-- Make bots actually use inspire, not only if you are in their detected attention objects
local check_inspire_original = TeamAILogicTravel.check_inspire
function TeamAILogicTravel.check_inspire(data, attention, ...)
	if data.objective and data.objective.action and data.objective.action.variant == "untie" then
		return
	end

	attention = attention or { unit = data.objective.follow_unit }

	local is_ai = managers.groupai:state():is_unit_team_AI(attention.unit)
	if (UsefulBots.settings.save_inspire or is_ai) and data.unit:character_damage():health_ratio() > 0.4 then
		local timer = 0
		if attention.unit:base().is_local_player then
			timer = attention.unit:character_damage()._downed_timer or timer
		elseif attention.unit:interaction().get_waypoint_time then
			timer = attention.unit:interaction():get_waypoint_time() or timer
		end

		local ratio = 1
		local my_data = data.internal_data
		if my_data.advancing and my_data.coarse_path and #my_data.coarse_path <= 2 and my_data.advancing._simplified_path then
			if not my_data._simplified_path_length then
				my_data._simplified_path_length = #my_data.advancing._simplified_path
			else
				ratio = 1 - #my_data.advancing._simplified_path / my_data._simplified_path_length
			end
		elseif my_data.advancing and my_data.coarse_path and my_data.coarse_path_index then
			ratio = math.max(my_data.coarse_path_index, 1) / #my_data.coarse_path
		end

		if timer * ratio > (is_ai and 2 or 8) then
			return
		end
	end

	return check_inspire_original(data, attention, ...)
end

local update_original = TeamAILogicTravel.update
function TeamAILogicTravel.update(data, ...)
	if TeamAILogicBase._check_deliver_bag(data) then
		return
	end
	if data.objective then
		return update_original(data, ...)
	end
	return CopLogicTravel.upd_advance(data)
end

if Iter and Iter.settings and Iter.settings.streamline_path or restoration then
	return
end

-- Update pathing when walking action is finished
Hooks:PostHook(TeamAILogicTravel, "action_complete_clbk", "action_complete_clbk_ub", function (data, action)
	local my_data = data.internal_data
	if action:type() == "walk" and my_data.coarse_path and my_data.coarse_path_index < #my_data.coarse_path then
		TeamAILogicTravel.update(data)
	end
end)
