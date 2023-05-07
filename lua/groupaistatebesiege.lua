local on_defend_travel_end_original = GroupAIStateBesiege.on_defend_travel_end
function GroupAIStateBesiege:on_defend_travel_end(unit, ...)
	if not self:is_unit_team_AI(unit) then
		return on_defend_travel_end_original(self, unit, ...)
	end
end
