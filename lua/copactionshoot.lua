-- CopActionHurt._upd_bleedout can potentially call this function with a wrong additional parameter before the time, strip that if that's the case
local _get_unit_shoot_pos_original = CopActionShoot._get_unit_shoot_pos
function CopActionShoot:_get_unit_shoot_pos(t_or_garbage, ...)
	if type(t_or_garbage) ~= "number" then
		return _get_unit_shoot_pos_original(self, ...)
	end
	return _get_unit_shoot_pos_original(self, t_or_garbage, ...)
end
