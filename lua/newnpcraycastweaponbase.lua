-- Remove criminal slotmask from Team AI so they can shoot through each other
Hooks:PostHook(NewNPCRaycastWeaponBase, "setup", "setup_ub", function (self)
	if self._setup.user_unit and self._setup.user_unit:in_slot(16) then
		self._bullet_slotmask = self._bullet_slotmask - World:make_slot_mask(16)
	end
end)
