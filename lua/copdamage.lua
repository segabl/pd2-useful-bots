Hooks:PreHook(CopDamage, "die", "die_ub", function (self, attack_data)
	if UsefulBots.settings.ammo_drops >= 1 then
		return
	end

	if self._pickup ~= "ammo" or not alive(attack_data.attacker_unit) then
		return
	end

	if not managers.groupai:state():is_unit_team_AI(attack_data.attacker_unit) then
		return
	end

	if math.random() >= math.max(0, UsefulBots.settings.ammo_drops) then
		self._pickup = nil
	end
end)
