-- Remove criminal slotmask from players and Team AI so they can shoot through each other
local function check_remove_criminal_slot(weap_base)
	if not alive(weap_base._setup.user_unit) then
		return
	end
	if weap_base._setup.user_unit:in_slot(16) or weap_base._setup.user_unit:in_slot(5) or weap_base._setup.user_unit:in_slot(2) then
		weap_base._bullet_slotmask = weap_base._bullet_slotmask - World:make_slot_mask(16)
	end
end

Hooks:PostHook(NPCRaycastWeaponBase, "setup", "setup_ub", check_remove_criminal_slot)
Hooks:PostHook(NewRaycastWeaponBase, "setup", "setup_ub", check_remove_criminal_slot)
Hooks:PostHook(NewNPCRaycastWeaponBase, "setup", "setup_ub", check_remove_criminal_slot)
