local _chk_wants_to_take_cover_original = CopLogicAttack._chk_wants_to_take_cover
function CopLogicAttack._chk_wants_to_take_cover(data, ...)
	if not data.is_team_ai or not data.unit:movement()._should_stay then
		return _chk_wants_to_take_cover_original(data, ...)
	end
end
