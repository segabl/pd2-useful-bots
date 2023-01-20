-- Stop moving towards revive target if a dangerous special is close to the bot
local upd_advance_original = CopLogicTravel.upd_advance
function CopLogicTravel.upd_advance(data, ...)
	local objective = data.objective
	local revive_unit = objective and objective.follow_unit
	if not objective or objective.type ~= "revive" or not alive(revive_unit) or mvector3.distance_sq(data.m_pos, revive_unit:position()) > 250000 then
		return upd_advance_original(data, ...)
	end

	if data.unit:character_damage():health_ratio() < 0.5 then
		return upd_advance_original(data, ...)
	end

	local timer = math.huge
	if revive_unit:base().is_local_player then
		timer = revive_unit:character_damage()._downed_timer or timer
	elseif revive_unit:interaction().get_waypoint_time then
		timer = revive_unit:interaction():get_waypoint_time() or timer
	end

	if timer < 10 then
		return upd_advance_original(data, ...)
	end

	local focus_enemy = data.attention_obj
	if focus_enemy and focus_enemy.verified and focus_enemy.dis < 1000 and focus_enemy.unit:base() and focus_enemy.unit:base().has_tag then
		if focus_enemy.unit:base():has_tag("spooc") or focus_enemy.unit:base():has_tag("taser") then
			if data.internal_data.advancing then
				data.unit:brain():action_request({
					body_part = 2,
					type = "idle"
				})
			end
			return
		end
	end

	return upd_advance_original(data, ...)
end

-- Sanity checks
local _chk_stop_for_follow_unit_original = CopLogicTravel._chk_stop_for_follow_unit
function CopLogicTravel._chk_stop_for_follow_unit(data, ...)
	if data.objective and alive(data.objective.follow_unit) then
		return _chk_stop_for_follow_unit_original(data, ...)
	end
end

local _on_destination_reached_original = CopLogicTravel._on_destination_reached
function CopLogicTravel._on_destination_reached(data, ...)
	if data.objective then
		return _on_destination_reached_original(data, ...)
	end
end

if Iter and Iter.settings and Iter.settings.streamline_path then
	return
end

-- Make bots and jokers follow more directly
local _get_exact_move_pos_original = CopLogicTravel._get_exact_move_pos
function CopLogicTravel._get_exact_move_pos(data, nav_index, ...)
	local my_data = data.internal_data
	local coarse_path = my_data.coarse_path
	if nav_index >= #coarse_path or data.team.id ~= "criminal1" and data.team.id ~= "converted_enemy" then
		return _get_exact_move_pos_original(data, nav_index, ...)
	end

	if my_data.moving_to_cover then
		managers.navigation:release_cover(my_data.moving_to_cover[1])
		my_data.moving_to_cover = nil
	end

	local doors = managers.navigation:find_segment_doors(coarse_path[nav_index][1], function (seg) return seg == coarse_path[nav_index + 1][1] end)
	local door = table.random(doors)
	return door and door.center or _get_exact_move_pos_original(data, nav_index, ...)
end
