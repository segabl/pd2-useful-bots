-- Allow projectiles shot by players to go through bots
Hooks:PostHook(ProjectileBase, "set_thrower_unit", "set_thrower_unit_ub", function (self)
	local criminals_slot = managers.slot:get_mask("criminals")
	if self._slot_mask and self._thrower_unit:in_slot(criminals_slot) then
		self._slot_mask = self._slot_mask - criminals_slot
	end
end)
