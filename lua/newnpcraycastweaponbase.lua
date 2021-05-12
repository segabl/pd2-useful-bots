-- Remove criminal slotmask from players and Team AI so they can shoot through each other
local function check_remove_slots(weap_base, hostages)
	if not alive(weap_base._setup.user_unit) then
		return
	end
	if weap_base._setup.user_unit:in_slot(16) or weap_base._setup.user_unit:in_slot(5) or weap_base._setup.user_unit:in_slot(2) then
		weap_base._bullet_slotmask = weap_base._bullet_slotmask - (hostages and World:make_slot_mask(16, 22) or World:make_slot_mask(16))
	end
end

Hooks:PostHook(NewRaycastWeaponBase, "setup", "setup_ub", function (self) check_remove_slots(self) end)
Hooks:PostHook(NPCRaycastWeaponBase, "setup", "setup_ub", function (self) check_remove_slots(self, UsefulBots.settings.save_hostages) end)
Hooks:PostHook(NewNPCRaycastWeaponBase, "setup", "setup_ub", function (self) check_remove_slots(self, UsefulBots.settings.save_hostages) end)
