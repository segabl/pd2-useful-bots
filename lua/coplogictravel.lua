-- Stop moving towards revive target if a dangerous special is close to the bot
local upd_advance_original = CopLogicTravel.upd_advance
function CopLogicTravel.upd_advance(data, ...)
	local objective = data.objective
	local revive_unit = objective and objective.follow_unit
	if not objective or objective.type ~= "revive" or not alive(revive_unit) or mvector3.distance_sq(data.m_pos, revive_unit:position()) > 250000 then
		return upd_advance_original(data, ...)
	end

	local timer = math.huge
	if revive_unit:base().is_local_player then
		timer = revive_unit:character_damage()._downed_timer or timer
	elseif revive_unit:interaction().get_waypoint_time then
		timer = revive_unit:interaction():get_waypoint_time() or timer
	end

	if timer < 5 then
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
