-- Stop moving towards revive target if a dangerous special is close to the bot
local upd_advance_original = CopLogicTravel.upd_advance
function CopLogicTravel.upd_advance(data, ...)
	if data.objective and data.objective.type == "revive" then
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
	end

	return upd_advance_original(data, ...)
end
