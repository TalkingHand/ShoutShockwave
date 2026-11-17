-- ShoutShockwave core: loudness, effect ladder, applying effects to zombies, XP.
-- Shared so single player, the server and clients use the same numbers.
-- Design notes: _devnotes/ShoutShockwave/README.md

ShoutShockwave = ShoutShockwave or {}
local F = ShoutShockwave

F.MOD = "ShoutShockwave"
function F.log(...)
	local t = {}
	for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end
	print("[ShoutShockwave] " .. table.concat(t, " "))
end

------------------------------------------------------------------------
-- numbers (see devnotes "조정한 계산식")
------------------------------------------------------------------------
F.EFFECT_NAMES = { "stagger", "knockdown", "daze", "damage" } -- index = effect id
F.THRESHOLDS = { 16, 10, 7, 5 }   -- T1 (top unlocked effect) .. T4
F.SOFTCAP_FROM = 30
F.SOFTCAP_EXP = 0.35
F.SNEAK_FACTOR = 0.6
F.HEALTH_REF = 1.9
F.HEALTH_MIN, F.HEALTH_MAX = 0.7, 1.2
F.ENDURANCE_BASE = 0.04           -- per shout, x (1.3 - 0.06 * fitness)
F.SNEAK_ENDURANCE = 0.3
F.FATIGUE = { { 0.75, 1.0 }, { 0.5, 0.9 }, { 0.25, 0.8 }, { 0.1, 0.65 } } -- endurance above -> factor, else 0.5
F.FATIGUE_LAST = 0.5
F.XP_SHOUT, F.XP_SHOUT_MAXLEVEL = 5, 2
F.XP_EFFECT = { 2, 4, 6, 8 }      -- by highest effect on a zombie
F.XP_KILL = 5
F.XP_CAP = 30
F.XP_STR_KNOCK, F.XP_STR_CAP = 2, 10

------------------------------------------------------------------------
-- sandbox
------------------------------------------------------------------------
local function sandbox(name, default)
	local sv = SandboxVars and SandboxVars.ShoutShockwave
	if sv and sv[name] ~= nil then return sv[name] end
	return default
end
F.overrides = F.overrides or {} -- tests
function F.opt(name, default)
	if F.overrides[name] ~= nil then return F.overrides[name] end
	return sandbox(name, default)
end
function F.effectEnabled(e)
	if e == 1 then return F.opt("Stagger", true) end
	if e == 2 then return F.opt("Knockdown", true) end
	if e == 3 then return F.opt("Daze", true) end
	return F.opt("Damage", true)
end

------------------------------------------------------------------------
-- loudness
------------------------------------------------------------------------
local function voicePerk()
	return Perks and Perks.Shout
end

function F.voiceLevel(player)
	local p = voicePerk()
	if not p then return 0 end
	return player:getPerkLevel(p)
end

-- Same rules as vanilla IsoGameCharacter.Callout() (42.22.2): primary-hand megaphone tag -> 90 else 30,
-- sneaking -> 18 / 6; otherwise the first item with a ShoutType (primary, secondary, worn) multiplies.
function F.vanillaRadius(player)
	local primary = player:getPrimaryHandItem()
	local megaphone = primary ~= nil and primary:hasTag(ItemTag.MEGAPHONE)
	if player:isSneaking() then
		return megaphone and 18 or 6, nil, megaphone, true
	end
	local radius = megaphone and 90 or 30
	local shoutItem = nil
	local secondary = player:getSecondaryHandItem()
	if primary and primary:getShoutType() then
		shoutItem = primary
	elseif secondary and secondary:getShoutType() then
		shoutItem = secondary
	else
		local worn = player:getWornItems()
		if worn then
			for i = 0, worn:size() - 1 do
				local it = worn:get(i):getItem()
				if it and it:getShoutType() then shoutItem = it; break end
			end
		end
	end
	if shoutItem then radius = math.floor(radius * shoutItem:getShoutMultiplier()) end
	return radius, shoutItem, megaphone, false
end

function F.fatigueFactor(endurance)
	for _, row in ipairs(F.FATIGUE) do
		if endurance > row[1] then return row[2] end
	end
	return F.FATIGUE_LAST
end

function F.skillFactor(player)
	local str = player:getPerkLevel(Perks.Strength)
	local voice = F.voiceLevel(player)
	return (0.9 + 0.02 * str) * (0.8 + 0.06 * voice)
end

-- returns loudness R, vanilla radius, sneaking, shoutItem, megaphone
function F.loudness(player, endurance)
	local base, shoutItem, megaphone, sneaking = F.vanillaRadius(player)
	local R = base * F.skillFactor(player) * F.fatigueFactor(endurance)
	return R, base, sneaking, shoutItem, megaphone
end

function F.enduranceCost(player)
	local fit = player:getPerkLevel(Perks.Fitness)
	local c = F.ENDURANCE_BASE * (1.3 - 0.06 * fit) * F.opt("EnduranceMultiplier", 1.0)
	if player:isSneaking() then c = c * F.SNEAK_ENDURANCE end
	return c
end

function F.effectRadius(R)
	if R <= F.SOFTCAP_FROM then return R end
	return F.SOFTCAP_FROM * (R / F.SOFTCAP_FROM) ^ F.SOFTCAP_EXP
end

------------------------------------------------------------------------
-- ladder
------------------------------------------------------------------------
function F.unlockedCount(voiceLevel)
	if voiceLevel >= 8 then return 4 end
	if voiceLevel >= 6 then return 3 end
	if voiceLevel >= 4 then return 2 end
	if voiceLevel >= 2 then return 1 end
	return 0
end

-- threshold of effect e (1..4) when k effects are unlocked; nil if locked
function F.threshold(e, k)
	if e > k then return nil end
	return F.THRESHOLDS[k - e + 1]
end

-- highest effect for intensity I (0 = none)
function F.highestEffect(I, k)
	for e = k, 1, -1 do
		if I >= F.threshold(e, k) then return e end
	end
	return 0
end

function F.healthFactor(zombie)
	local h = zombie:getHealth()
	if h <= 0 then return F.HEALTH_MAX end
	local f = math.sqrt(F.HEALTH_REF / h)
	if f < F.HEALTH_MIN then f = F.HEALTH_MIN end
	if f > F.HEALTH_MAX then f = F.HEALTH_MAX end
	return f
end

------------------------------------------------------------------------
-- evaluate a shout: who gets what. Runs where zombie positions are known
-- (single player, or the server in multiplayer).
------------------------------------------------------------------------
-- shout = { x, y, z, R, sneaking, voice }
function F.evaluate(shout)
	local k = F.unlockedCount(shout.voice)
	local out = {}
	if k == 0 then return out end
	local Rp = F.effectRadius(shout.R)
	local sneak = shout.sneaking and F.SNEAK_FACTOR or 1.0
	local lowest = F.threshold(1, k)
	local maxRange = Rp * sneak * F.HEALTH_MAX / lowest
	local cell = getCell()
	if not cell then return out end
	local list = cell:getZombieList()
	for i = 0, list:size() - 1 do
		local z = list:get(i)
		if z and not z:isDead() and math.abs(z:getZ() - shout.z) < 1 then
			local dx, dy = z:getX() - shout.x, z:getY() - shout.y
			local d = math.sqrt(dx * dx + dy * dy)
			if d <= maxRange then
				local I = Rp / math.max(d, 1) * sneak * F.healthFactor(z)
				local e = F.highestEffect(I, k)
				if e > 0 then
					local r = { zombie = z, id = z:getOnlineID(), effect = e, I = I, k = k, d = d }
					if e >= 4 then
						local ratio = I / F.threshold(4, k)
						r.damage = (0.2 + (ratio - 1)) * (0.8 + ZombRandFloat(0, 0.4)) * F.opt("DamageMultiplier", 1.0)
					end
					if e >= 3 then
						local t3 = F.threshold(3, k)
						local s = (I / t3 - 1) / 2
						if s < 0 then s = 0 elseif s > 1 then s = 1 end
						r.dazeMs = math.floor(1500 + 2500 * s)
					end
					out[#out + 1] = r
				end
			end
		end
	end
	return out
end

------------------------------------------------------------------------
-- apply to one zombie. Call only where that zombie is simulated
-- (single player; server for server-owned zombies; the owning client).
------------------------------------------------------------------------
F.dazed = F.dazed or {} -- zombie -> until ms

local function staggerOnly(z, player)
	z:setStaggerBack(true)
	z:setHitReaction("")
	z:setPlayerAttackPosition(player:isBehind(z) and "BEHIND" or nil)
	z:setHitForce(0.6)
	z:reportEvent("wasHit")
end

-- r = { effect, damage, dazeMs }; returns true if the zombie died
function F.applyToZombie(z, player, r)
	if not z or z:isDead() then return false end
	local e = r.effect
	local down = z:isOnFloor() or z:isKnockedDown()
	if e >= 4 and r.damage and r.damage > 0 and F.effectEnabled(4) then
		local hp = z:getHealth() - r.damage
		if hp <= 0 then
			z:Kill(player)
			return true
		end
		z:setHealth(hp)
	end
	if e >= 3 and r.dazeMs and F.effectEnabled(3) then
		z:setTarget(nil)
		z:setUseless(true)
		F.dazed[z] = getTimestampMs() + r.dazeMs
	end
	if not down then
		if e >= 2 and F.effectEnabled(2) then
			z:knockDown(player:isBehind(z))
		elseif e >= 1 and F.effectEnabled(1) then
			staggerOnly(z, player)
		end
	end
	return false
end

local function dazeTick()
	local now = getTimestampMs()
	for z, untilMs in pairs(F.dazed) do
		if now >= untilMs or z:isDead() then
			if not z:isDead() then z:setUseless(false) end
			F.dazed[z] = nil
		end
	end
end
Events.OnTick.Add(dazeTick)

------------------------------------------------------------------------
-- XP (single player or server; addXp does nothing on a MP client)
------------------------------------------------------------------------
-- results: list of { effect, killed }
function F.giveXP(player, results, voiceBefore)
	if not Perks or not Perks.Shout then return end
	local xp = 0
	if voiceBefore < F.XP_SHOUT_MAXLEVEL then xp = xp + F.XP_SHOUT end
	local fx, str = 0, 0
	for _, r in ipairs(results) do
		local e = r.effect or 0
		if e > 0 then fx = fx + F.XP_EFFECT[e] end
		if r.killed then fx = fx + F.XP_KILL end
		if e >= 2 then str = str + F.XP_STR_KNOCK end
	end
	if fx > F.XP_CAP then fx = F.XP_CAP end
	if str > F.XP_STR_CAP then str = F.XP_STR_CAP end
	xp = xp + fx
	if xp > 0 then addXp(player, Perks.Shout, xp) end
	if str > 0 then addXp(player, Perks.Strength, str) end
	return xp, str
end

------------------------------------------------------------------------
-- windows: from Voice 8 (the damage stage) a shout breaks building windows nearby.
-- Window intensity I = R' / distance (x sneak factor); break chance 0 below 0.75 Tw, 50% at Tw,
-- 100% from 1.25 Tw. Floors from one below to two above count, a floor = WINDOW_FLOOR_TILES tiles. Only IsoWindow (building windows): vehicle windows are vehicle parts and
-- are never touched. Barricaded, open, already broken and invincible windows are skipped.
------------------------------------------------------------------------
F.WINDOW_FROM_VOICE = 8
F.WINDOW_T = 2   -- 11-18: three times the range of the first try (6)
F.WINDOW_FLOOR_TILES = 3   -- one floor up/down counts as this many tiles

-- sandbox WindowRange multiplies the distances (threshold divided by it)
function F.windowT()
	local m = F.opt("WindowRange", 1.0)
	if not m or m <= 0 then m = 1.0 end
	return F.WINDOW_T / m
end

function F.windowChance(I)
	local T = F.windowT()
	local c = (I - 0.75 * T) / (0.5 * T)
	if c < 0 then return 0 elseif c > 1 then return 1 end
	return c
end

-- returns the number of windows broken
function F.breakWindows(shout)
	if (shout.voice or 0) < F.WINDOW_FROM_VOICE or not F.opt("Windows", true) then return 0 end
	local cell = getCell()
	if not cell then return 0 end
	local Rp = F.effectRadius(shout.R) * (shout.sneaking and F.SNEAK_FACTOR or 1)
	local reach = Rp / (0.75 * F.windowT())
	local r = math.ceil(reach)
	local cx, cy, cz = math.floor(shout.x), math.floor(shout.y), math.floor(shout.z)
	local seen, broken = {}, 0
	for z = cz - 1, cz + 2 do
	local dzt = (z - cz) * F.WINDOW_FLOOR_TILES
	for x = cx - r, cx + r do
		for y = cy - r, cy + r do
			local sq = z >= 0 and cell:getGridSquare(x, y, z) or nil
			local w = sq and sq:getWindow()
			if w and not seen[w] then
				seen[w] = true
				if not w:isDestroyed() and not w:isBarricaded() and not w:IsOpen() and not w:isInvincible() then
					local dx, dy = x + 0.5 - shout.x, y + 0.5 - shout.y
					local d = math.sqrt(dx * dx + dy * dy + dzt * dzt)
					local p = F.windowChance(Rp / math.max(d, 1))
					if p > 0 and (p >= 1 or ZombRandFloat(0, 1) < p) then
						w:smashWindow()
						broken = broken + 1
					end
				end
			end
		end
	end
	end
	return broken
end

------------------------------------------------------------------------
-- authority-side resolution of a shout (single player / server)
------------------------------------------------------------------------
-- isOwnedHere(z): true if this machine simulates z
function F.resolve(player, shout, isOwnedHere)
	local results = F.evaluate(shout)
	local remote = {}
	for _, r in ipairs(results) do
		if isOwnedHere(r.zombie) then
			r.killed = F.applyToZombie(r.zombie, player, r)
		else
			remote[#remote + 1] = r
		end
	end
	F.giveXP(player, results, shout.voice)
	F.lastWindows = F.breakWindows(shout)
	return results, remote
end
