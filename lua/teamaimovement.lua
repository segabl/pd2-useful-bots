function TeamAIMovement:switch_weapon(selection)
	self._ext_anim.equip = true
	self._switch_weapon_selection = selection
	self:destroy_magazine_in_hand()
	local res = self:play_redirect("switch_weapon_enter")
	if res then
		self._machine:set_speed(res, 1.5)
	end
end

function TeamAIMovement:anim_clbk_switch_weapon()
	self._ext_anim.equip = nil
	self._ext_inventory:equip_selection(self._switch_weapon_selection)
	local res = self:play_redirect("switch_weapon_exit")
	if res then
		self._machine:set_speed(res, 1.5)
	end
end
