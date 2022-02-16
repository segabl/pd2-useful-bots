Hooks:PreHook(CopDamage, "die", "die_ub", function (self, attack_data)
	if not UsefulBots.settings.ammo_drops and self._pickup == "ammo" and alive(attack_data.attacker_unit) and managers.groupai:state():is_unit_team_AI(attack_data.attacker_unit) then
		self._pickup = nil
	end
end)
