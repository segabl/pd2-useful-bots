-- Stop moving towards revive target if a dangerous special is close to the bot
local upd_advance_original = CopLogicTravel.upd_advance
function CopLogicTravel.upd_advance(data, ...)
	if not data.is_team_ai then
		return upd_advance_original(data, ...)
	end

	local revive_unit = data.objective and data.objective.type == "revive" and data.objective.follow_unit
	if not alive(revive_unit) or mvector3.distance_sq(data.m_pos, revive_unit:position()) > 250000 then
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

	local my_data = data.internal_data
	local focus_enemy = data.attention_obj
	if focus_enemy and focus_enemy.verified and focus_enemy.dis < 1000 and focus_enemy.unit:base() and focus_enemy.unit:base().has_tag then
		if focus_enemy.unit:base():has_tag("spooc") or focus_enemy.unit:base():has_tag("taser") then
			if my_data.advancing then
				data.unit:brain():action_request({
					body_part = 2,
					type = "idle"
				})
			end

			if not my_data.turning then
				CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, focus_enemy.m_pos)
			end
			TeamAILogicAssault._upd_aim(data, my_data)

			data.unit:movement():set_allow_fire(true)

			return
		end
	end

	return upd_advance_original(data, ...)
end

-- Sanity checks
local _chk_stop_for_follow_unit_original = CopLogicTravel._chk_stop_for_follow_unit
function CopLogicTravel._chk_stop_for_follow_unit(data, my_data, ...)
	if data.objective and alive(data.objective.follow_unit) and my_data.coarse_path_index and my_data.coarse_path and my_data.coarse_path[my_data.coarse_path_index + 1] then
		return _chk_stop_for_follow_unit_original(data, my_data, ...)
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

-- Go straight to target without stops in between
local _begin_coarse_pathing_original = CopLogicTravel._begin_coarse_pathing
function CopLogicTravel._begin_coarse_pathing(data, my_data, ...)
	if not data.is_team_ai then
		return _begin_coarse_pathing_original(data, my_data, ...)
	end

	local nav_seg, pos
	if alive(data.objective.follow_unit) then
		local follow_tracker = data.objective.follow_unit:movement():nav_tracker()
		nav_seg = follow_tracker:nav_segment()
		pos = follow_tracker:field_position()
	else
		nav_seg = data.objective.nav_seg or data.objective.area and data.objective.area.pos_nav_seg
		pos = managers.navigation._nav_segments[nav_seg].pos
	end

	my_data.coarse_path_index = 1
	my_data.coarse_path = {
		{
			data.unit:movement():nav_tracker():nav_segment(),
			mvector3.copy(data.m_pos)
		},
		{
			nav_seg,
			pos
		}
	}
end

local _get_allowed_travel_nav_segs_original = CopLogicTravel._get_allowed_travel_nav_segs
function CopLogicTravel._get_allowed_travel_nav_segs(data, my_data, ...)
	if not data.is_team_ai then
		return _get_allowed_travel_nav_segs_original(data, my_data, ...)
	end
end
