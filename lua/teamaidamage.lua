-- announce low health
Hooks:PostHook(TeamAIDamage, "_apply_damage", "_apply_damage_ub", function (self)
	local t = TimerManager:game():time()
	if UsefulBots.settings.announce_low_hp and (not self._said_hurt_t or self._said_hurt_t + 10 < t) and self._health_ratio < 0.3 and not self:need_revive() and not self._unit:sound():speaking() then
		self._said_hurt_t = t
		self._unit:sound():say("g80x_plu", true, true)
	end
end)

-- mark taser when tased
local damage_tase_original = TeamAIDamage.damage_tase
function TeamAIDamage:damage_tase(attack_data, ...)
	local result = damage_tase_original(self, attack_data, ...)

	if result and attack_data then
		local attacker = attack_data.attacker_unit
		if alive(attacker) and attacker:base() and attacker:base().has_tag and attacker:base():has_tag("taser") then
			attacker:contour():add("mark_enemy", true)
			local priority_shout = attacker:base():char_tweak().priority_shout
			if priority_shout then
				self._unit:sound():say(priority_shout .. "x_any", true)
			end
		end
	end

	return result
end

-- fix for bots losing their i-frames in rare cases
local damage_bullet_original = TeamAIDamage.damage_bullet
function TeamAIDamage:damage_bullet(...)
	local result = damage_bullet_original(self, ...)

	if result then
		-- _chk_dmg_too_soon uses managers.player:player_timer():time() so use it here too
		self._next_allowed_dmg_t = managers.player:player_timer():time() + self._dmg_interval
	end

	return result
end
