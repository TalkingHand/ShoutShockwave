-- ShoutShockwave in-game test (pzt TEST_FILES only, not shipped). One client, every scenario.
-- SFXTest.start() runs the scenarios as a coroutine on OnTick; SFXTest.poll() re-queues itself until done.
-- Results: "[SFXTest] PASS/FAIL/INFO" lines; failures also "[PZTest] FAIL". No error() (debugger freezes).

SFXTest = SFXTest or {}
local T = SFXTest
local F = function() return ShoutShockwave end

local function log(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	print("[SFXTest] " .. table.concat(parts, " "))
end

local function check(ok, label, extra)
	if ok then T.pass = T.pass + 1 else T.fail = T.fail + 1 end
	log(ok and "PASS" or "FAIL", T.scenario or "", label, extra ~= nil and tostring(extra) or "")
	if not ok and PZTest and PZTest.fail then PZTest.fail("SFXTest " .. tostring(T.scenario) .. " " .. label .. " " .. tostring(extra or "")) end
	return ok
end

local function p() return getPlayer() end
local function yield() coroutine.yield() end
local function waitTicks(n) for _ = 1, n do yield() end end
local function near(a, b, eps) return a and b and math.abs(a - b) <= (eps or 0.01) end

-- protected test character, re-set every frame while the test runs
local function protect(on)
	local pl = p()
	if not pl then return end
	pl:setGodMod(on and not T.noGod) -- god mode resets endurance every frame
	pl:setInvisible(on)
	pl:setZombiesDontAttack(on)
	if pl.setGhostMode then pl:setGhostMode(on) end
end

local function setLevel(perk, n)
	local pl = p()
	pl:setPerkLevelDebug(perk, n)
	pcall(function() pl:getXp():setXPToLevel(perk, n) end)
end

local function setEndurance(v) p():getStats():set(CharacterStat.ENDURANCE, v) end
local function endurance() return p():getStats():get(CharacterStat.ENDURANCE) end

local function clearZombies()
	local list = getCell():getZombieList()
	for i = list:size() - 1, 0, -1 do
		local z = list:get(i)
		if z then z:removeFromSquare(); z:removeFromWorld() end
	end
end

local function spawnZombie(dx, dy, health)
	local pl = p()
	local list = addZombiesInOutfit(math.floor(pl:getX()) + dx, math.floor(pl:getY()) + dy, math.floor(pl:getZ()), 1, nil, 50)
	if not list or list:size() == 0 then return nil end
	local z = list:get(0)
	z:setX(math.floor(pl:getX()) + dx + 0.5); z:setY(math.floor(pl:getY()) + dy + 0.5)
	z:setLastX(z:getX()); z:setLastY(z:getY())
	if health then z:setHealth(health) end
	return z
end

local function hands(primary, secondary)
	local pl = p()
	pl:getInventory():clear()
	pl:setPrimaryHandItem(nil); pl:setSecondaryHandItem(nil)
	if primary then local it = pl:getInventory():AddItem(primary); pl:setPrimaryHandItem(it) end
	if secondary then local it = pl:getInventory():AddItem(secondary); pl:setSecondaryHandItem(it) end
end

local function centre()
	local pl = p()
	local x, y = math.floor(pl:getX()) + 0.5, math.floor(pl:getY()) + 0.5
	pl:setX(x); pl:setY(y); pl:setLastX(x); pl:setLastY(y)
end

local function voiceXP() return p():getXp():getXP(Perks.Shout) end

-- shout through the hooked IsoPlayer:Callout like the Q key does
local function shout()
	p():setCanShout(true)
	p():Callout(true)
end

local function reset(voice, str, fit)
	F().overrides = {}
	hands(nil, nil)
	p():setSneaking(false)
	clearZombies()
	setLevel(Perks.Shout, voice or 0)
	setLevel(Perks.Strength, str or 5)
	setLevel(Perks.Fitness, fit or 5)
	setEndurance(1.0)
	centre()
end

------------------------------------------------------------------ scenarios

local function sInstall()
	T.scenario = "install"
	check(F() ~= nil and F().installed, "Callout hook installed")
	check(Perks.Shout ~= nil, "Perks.Shout exists")
	if Perks.Shout then
		local okP, parent = pcall(function() return Perks.Shout:getParent() end)
		check(okP and parent == Perks.PhysicalCategory, "Voice under PhysicalCategory", tostring(parent))
		local okN, name = pcall(function() return Perks.Shout:getName() end)
		log("INFO", "Voice perk name:", tostring(name))
		check(okN and name ~= nil and name ~= "IGUI_perks_Shout", "Voice perk translated", tostring(name))
	end
end

local function sRadius()
	T.scenario = "vanillaRadius"
	local pl = p()
	reset(0)
	check(F().vanillaRadius(pl) == 30, "bare voice 30", F().vanillaRadius(pl))
	hands(nil, "Base.Whistle")
	check(F().vanillaRadius(pl) == 60, "whistle in secondary 60", F().vanillaRadius(pl))
	hands("Base.Bullhorn", nil)
	check(F().vanillaRadius(pl) == 90, "megaphone 90", F().vanillaRadius(pl))
	hands("Base.Bullhorn", "Base.Whistle")
	check(F().vanillaRadius(pl) == 180, "megaphone + whistle 180", F().vanillaRadius(pl))
	hands(nil, nil)
	pl:setSneaking(true)
	check(F().vanillaRadius(pl) == 6, "sneaking 6", F().vanillaRadius(pl))
	pl:setSneaking(false)
end

local function sMath()
	T.scenario = "math"
	local f = F()
	check(near(f.effectRadius(30), 30), "softcap keeps 30")
	check(near(f.effectRadius(90), 43.9, 0.2), "softcap 90 -> ~44", f.effectRadius(90))
	check(near(f.effectRadius(180), 56.1, 0.3), "softcap 180 -> ~56", f.effectRadius(180))
	check(f.fatigueFactor(1.0) == 1.0 and f.fatigueFactor(0.6) == 0.9 and f.fatigueFactor(0.3) == 0.8
		and f.fatigueFactor(0.2) == 0.65 and f.fatigueFactor(0.05) == 0.5, "fatigue factors")
	check(f.unlockedCount(1) == 0 and f.unlockedCount(2) == 1 and f.unlockedCount(5) == 2
		and f.unlockedCount(7) == 3 and f.unlockedCount(10) == 4, "unlock ladder")
	check(f.threshold(1, 1) == 16 and f.threshold(2, 2) == 16 and f.threshold(1, 2) == 10
		and f.threshold(4, 4) == 16 and f.threshold(1, 4) == 5, "thresholds move down")
	check(f.highestEffect(12, 4) == 3 and f.highestEffect(4, 4) == 0 and f.highestEffect(20, 1) == 1, "highest effect")
end

-- the user's rule: the newest unlocked effect always lands on an adjacent tough zombie
local function sTough()
	T.scenario = "tough"
	local pl = p()
	reset(0, 10)
	local z = spawnZombie(1, 0, 3.8)
	yield()
	local r0 = F().evaluate({ x = pl:getX(), y = pl:getY(), z = pl:getZ(), R = F().loudness(pl, 1.0), sneaking = false, voice = 0 })
	check(#r0 == 0, "voice 0: no effect even with strength 10", #r0)
	reset(2, 0)
	z = spawnZombie(1, 0, 3.8)
	yield()
	local r2 = F().evaluate({ x = pl:getX(), y = pl:getY(), z = pl:getZ(), R = F().loudness(pl, 1.0), sneaking = false, voice = 2 })
	check(#r2 == 1 and r2[1].effect == 1, "voice 2 str 0: tough adjacent staggers", r2[1] and r2[1].effect)
	reset(8, 0)
	z = spawnZombie(1, 0, 3.8)
	yield()
	local r8 = F().evaluate({ x = pl:getX(), y = pl:getY(), z = pl:getZ(), R = F().loudness(pl, 1.0), sneaking = false, voice = 8 })
	check(#r8 == 1 and r8[1].effect == 4, "voice 8 str 0: tough adjacent takes damage", r8[1] and r8[1].effect)
	clearZombies()
end

local function sLine()
	T.scenario = "line"
	local pl = p()
	reset(8, 5, 5)
	local zs = {}
	for _, d in ipairs({ 1, 3, 4, 6, 8 }) do zs[d] = spawnZombie(d, 0, 1.95) end
	waitTicks(2)
	local shoutT = { x = pl:getX(), y = pl:getY(), z = pl:getZ(), R = F().loudness(pl, 1.0), sneaking = false, voice = 8 }
	log("INFO", "R", shoutT.R, "R'", F().effectRadius(shoutT.R))
	local byZ = {}
	for _, r in ipairs(F().evaluate(shoutT)) do byZ[r.zombie] = r.effect end
	check(byZ[zs[1]] == 4, "d=1 damage", byZ[zs[1]])
	check(byZ[zs[3]] == 3, "d=3 daze", byZ[zs[3]])
	check(byZ[zs[4]] == 2, "d=4 knockdown", byZ[zs[4]])
	check(byZ[zs[6]] == 1, "d=6 stagger", byZ[zs[6]])
	check(byZ[zs[8]] == nil, "d=8 nothing", byZ[zs[8]])

	local e0, xp0 = endurance(), voiceXP()
	shout()
	local spent = e0 - endurance()
	check(near(spent, 0.135 * 0.6, 0.002), "endurance cost 0.081 at shout 8, fitness 5", spent)
	check(zs[1]:isDead() or zs[1]:getHealth() < 1.95 - 0.7, "d=1 hurt", zs[1]:getHealth())
	check(zs[3]:isUseless(), "d=3 dazed (useless)")
	waitTicks(20)
	log("INFO", "states", zs[3]:getCurrentStateName(), zs[4]:getCurrentStateName(), zs[6]:getCurrentStateName(), zs[8]:getCurrentStateName())
	check(zs[4]:isKnockedDown() or zs[4]:isOnFloor() or tostring(zs[4]:getCurrentStateName()):find("Stagger") ~= nil, "d=4 knocked down", zs[4]:getCurrentStateName())
	check(tostring(zs[6]:getCurrentStateName()):find("Stagger") ~= nil or zs[6]:isStaggerBack(), "d=6 staggered", zs[6]:getCurrentStateName())
	check(not zs[8]:isKnockedDown() and not zs[8]:isStaggerBack() and not zs[8]:isUseless(), "d=8 untouched")
	local gained = voiceXP() - xp0
	log("INFO", "voice xp gained", gained)
	check(gained > 0 and gained <= 30 * (T.xpMul or 1) + 0.5, "effect xp capped at 30", gained)
	-- daze wears off (1.5 - 4 s)
	local t0 = getTimestampMs()
	while zs[3]:isUseless() and getTimestampMs() - t0 < 6000 do yield() end
	check(not zs[3]:isUseless(), "daze wears off", getTimestampMs() - t0)
	clearZombies()
end

local function sXP()
	T.scenario = "xp"
	reset(0)
	local x0 = voiceXP()
	shout()
	local g = voiceXP() - x0
	T.xpMul = g / 5
	log("INFO", "xp multiplier from sandbox/game", T.xpMul)
	check(g > 0, "voice 0: shout gives XP (5 x multiplier)", g)
	reset(2)
	x0 = voiceXP()
	shout()
	check(near(voiceXP() - x0, 0, 0.01), "voice 2: shout alone gives 0", voiceXP() - x0)
end

local function sQuiet()
	T.scenario = "quiet"
	local pl = p()
	reset(0, 0)
	setEndurance(0.05)
	shout()
	local s = F().lastShout
	check(s ~= nil and s.R < 30, "tired weak shout is quieter than vanilla", s and s.R)
	check(near(s and s.R or 0, 30 * 0.9 * 0.8 * 0.5, 0.01), "R = 30 x 0.9 x 0.8 x 0.5", s and s.R)
	check(endurance() == 0 or endurance() < 0.05, "endurance spent", endurance())
end

local function sToggles()
	T.scenario = "toggles"
	reset(8, 5)
	F().overrides.Damage = false
	local z = spawnZombie(1, 0, 1.95)
	waitTicks(2)
	shout()
	check(near(z:getHealth(), 1.95, 0.001), "damage off: health unchanged", z:getHealth())
	clearZombies()
end

local function sKill()
	T.scenario = "kill"
	reset(10, 10)
	hands("Base.Bullhorn", nil)
	F().overrides.DamageMultiplier = 3
	local z = spawnZombie(1, 0, 1.95)
	waitTicks(2)
	shout()
	waitTicks(10)
	check(z:isDead(), "megaphone voice 10 kills an adjacent zombie", z:getHealth())
	hands(nil, nil)
	clearZombies()
end

local function sSneak()
	T.scenario = "sneak"
	local pl = p()
	reset(10, 10)
	pl:setSneaking(true)
	local z1 = spawnZombie(1, 0, 1.95)
	local z2 = spawnZombie(3, 0, 1.95)
	waitTicks(2)
	local e0 = endurance()
	local s = { x = pl:getX(), y = pl:getY(), z = pl:getZ(), R = F().loudness(pl, 1.0), sneaking = true, voice = 10 }
	local by = {}
	for _, r in ipairs(F().evaluate(s)) do by[r.zombie] = r.effect end
	check(by[z1] == 1, "whisper voice 10: adjacent only staggers", by[z1])
	check(by[z2] == nil, "whisper voice 10: d=3 nothing", by[z2])
	shout()
	check(near(e0 - endurance(), 0.135 * (1.3 - 0.06 * 5) * (1 - 0.05 * 10) * 0.3, 0.002), "whisper costs x0.3", e0 - endurance())
	pl:setSneaking(false)
	clearZombies()
end

local function sVisual()
	T.scenario = "visual"
	reset(8, 5)
	local z = spawnZombie(4, 0, 1.95)
	waitTicks(2)
	shout()
	check(ShoutShockwaveOverlay ~= nil, "overlay class")
	waitTicks(30)
	log("INFO", "visual shout done (overlay draws in UI; pzt shots hide UI)")
	clearZombies()
end

local function sStages()
	T.scenario = "stages"
	local pl = p()
	local want = { [0] = 0.3, [2] = 0.45, [4] = 0.6, [6] = 0.8, [8] = 1.0 }
	local lastR = 0
	for _, v in ipairs({ 0, 2, 4, 6, 8 }) do
		reset(v, 5)
		F().lastRing, F().lastRumble = nil, nil
		shout()
		local ring = F().lastRing
		check(ring and near(ring.alpha, want[v]), "voice " .. v .. " ring alpha", ring and ring.alpha)
		check(ring and ring.r > lastR, "voice " .. v .. " ring grows", ring and ring.r)
		lastR = ring and ring.r or lastR
		if v < 4 then
			check(F().lastRumble == nil, "voice " .. v .. " no rumble", F().lastRumble)
		else
			check(F().lastRumble ~= nil and F().lastRumble > 0, "voice " .. v .. " rumble plays", F().lastRumble)
		end
		yield()
	end
	reset(4, 5)
	local s4 = { R = F().loudness(pl, 1.0), voice = 4, sneaking = false }
	check(near(F().rumbleVolume(s4), F().effectRadius(s4.R) / 65, 0.001), "voice 4 rumble = R'/65", F().rumbleVolume(s4))
	check(near(F().rumbleVolume({ R = 1000, voice = 10 }), 1.0), "loudest rumble = 1.0 (2x sample)")
	check(F().rumbleVolume({ R = 1000, voice = 3 }) == 0, "voice 3 rumble 0 even when loud")
	reset(8, 5)
	shout()
	local ok, playing = pcall(function() return p():getEmitter():isPlaying("ShoutShockwave_Rumble") end)
	check(ok and playing, "ShoutShockwave_Rumble sound script plays", tostring(playing))
end

local function findWindow(radius)
	local pl = p()
	local cx, cy, cz = math.floor(pl:getX()), math.floor(pl:getY()), math.floor(pl:getZ())
	local best, bd = nil, 1e9
	for x = cx - radius, cx + radius do
		for y = cy - radius, cy + radius do
			local sq = getCell():getGridSquare(x, y, cz)
			local w = sq and sq:getWindow()
			if w and not w:isDestroyed() and not w:isBarricaded() and not w:IsOpen() and not w:isInvincible() then
				local d = math.abs(x - cx) + math.abs(y - cy)
				if d < bd then best, bd = { w = w, x = x, y = y, z = cz }, d end
			end
		end
	end
	return best
end

local function standNear(win, dx, dy)
	local pl = p()
	local x, y = win.x + dx + 0.5, win.y + dy + 0.5
	pl:setX(x); pl:setY(y); pl:setLastX(x); pl:setLastY(y)
end

local function sWindows()
	T.scenario = "windows"
	local f = F()
	check(f.windowChance(1.4) == 0 and near(f.windowChance(2), 0.5) and f.windowChance(2.5) == 1, "window chance 0 / 50% / 100%")
	local home = { p():getX(), p():getY() }
	reset(7, 5)
	local win = findWindow(40)
	if not check(win ~= nil, "a window near the test spot") then return end
	log("INFO", "window at", win.x, win.y, win.z)
	standNear(win, 2, 0)
	waitTicks(5)
	shout()
	check(not win.w:isDestroyed(), "voice 7: window stays", F().lastWindows)
	setLevel(Perks.Shout, 8)
	setEndurance(1.0)
	shout()
	check(win.w:isDestroyed(), "voice 8 at 2 tiles: window breaks", F().lastWindows)
	F().overrides.WindowRange = 2
	check(near(f.windowChance(1), 0.5), "WindowRange 2 doubles the distance (50% at half the strength)")
	F().overrides.WindowRange = nil
	log("INFO", "windows broken by voice 8 shout:", F().lastWindows)
	F().overrides.Windows = false
	local win2 = findWindow(40)
	if win2 then
		standNear(win2, 2, 0)
		waitTicks(5)
		shout()
		check(not win2.w:isDestroyed(), "windows option off: window stays")
	end
	F().overrides = {}
	p():setX(home[1]); p():setY(home[2]); p():setLastX(home[1]); p():setLastY(home[2])
	waitTicks(5)
end

local function sDust()
	T.scenario = "dust"
	local f = F()
	check(f.dustScale(7) == 0 and near(f.dustScale(8), 0.7) and near(f.dustScale(9), 0.85) and near(f.dustScale(10), 1.0), "dust scale 0 / 0.7 / 0.85 / 1.0")
	for _, c in ipairs({ { 7, nil }, { 8, 0.7 }, { 10, 1.0 } }) do
		reset(c[1], 5)
		spawnZombie(2, 0, 1.95)
		waitTicks(2)
		shout()
		if c[2] then
			check(F().lastDust ~= nil and near(F().lastDust, c[2]), "voice " .. c[1] .. " dust on knocked zombie", F().lastDust)
		else
			check(F().lastDust == nil, "voice " .. c[1] .. " no dust", F().lastDust)
		end
		clearZombies()
	end
end

-- endurance cost = 0.135 x (1.3 - 0.06 fitness) x (1 - 0.05 shout); Shout 0, Fitness 5: tired on the 2nd shout
local function tiredLevel() return p():getMoodles():getMoodleLevel(MoodleType.ENDURANCE) end

local function waitTired(maxTicks)
	for _ = 1, maxTicks do
		if tiredLevel() >= 1 then return true end
		yield()
	end
	return tiredLevel() >= 1
end

local function sEndurance()
	T.scenario = "endurance"
	local pl = p()
	T.noGod = true
	pl:setGodMod(false)
	waitTicks(2)
	for _, c in ipairs({ { 0, 0, 0.1755 }, { 0, 5, 0.135 }, { 0, 10, 0.0945 }, { 5, 5, 0.10125 }, { 10, 5, 0.0675 }, { 10, 10, 0.04725 } }) do
		reset(c[1], 5, c[2])
		check(near(F().enduranceCost(pl), c[3], 0.0001), "cost at shout " .. c[1] .. " fitness " .. c[2], F().enduranceCost(pl))
	end
	reset(0, 5, 5)
	F().overrides.EnduranceMultiplier = 2
	check(near(F().enduranceCost(pl), 0.27, 0.0001), "sandbox multiplier 2", F().enduranceCost(pl))
	F().overrides.EnduranceMultiplier = 0
	check(F().enduranceCost(pl) == 0, "sandbox multiplier 0 is free", F().enduranceCost(pl))
	F().overrides.EnduranceMultiplier = nil

	-- real moodle: rested, one shout stays fine, the second one tires
	reset(0, 5, 5)
	waitTicks(120)
	setEndurance(1.0)
	waitTicks(60)
	check(tiredLevel() == 0, "rested: no tired moodle", tiredLevel())
	setEndurance(1.0)
	shout()
	check(near(1 - endurance(), 0.135, 0.003), "first shout costs 0.135", endurance())
	waitTicks(120)
	check(tiredLevel() == 0, "one shout: not tired yet", tiredLevel())
	shout()
	log("INFO", "endurance after two shouts", endurance())
	check(endurance() < 0.75, "two shouts: below the tired line", endurance())
	check(waitTired(600), "two shouts: tired moodle shows", tiredLevel())

	-- runs out on the 8th shout and can still shout at 0
	reset(0, 5, 5)
	setEndurance(1.0)
	for _ = 1, 7 do shout() end
	check(endurance() > 0, "seven shouts: some endurance left", endurance())
	shout()
	check(endurance() == 0, "eight shouts: endurance 0", endurance())
	F().lastShout = nil
	shout()
	check(F().lastShout ~= nil and near(F().lastShout.R, 30 * 1.0 * 0.8 * 0.5, 0.01), "shout at 0 still works at half loudness", F().lastShout and F().lastShout.R)

	T.noGod = false
	setEndurance(1.0)
end

------------------------------------------------------------------ driver

local function safe(fn, name)
	local ok, err = pcall(fn)
	if not ok then T.scenario = name; check(false, "ran", err) end
end

local function run()
	T.pass, T.fail = 0, 0
	safe(sInstall, "install")
	safe(sRadius, "vanillaRadius")
	safe(sMath, "math")
	sTough()
	sXP()
	sLine()
	sQuiet()
	sToggles()
	sKill()
	sSneak()
	sVisual()
	sStages()
	sWindows()
	sDust()
	sEndurance()
	reset(0, 5, 5)
	p():getInventory():clear()
end

-- only what the endurance change touches: hook installed, cost in the shout paths, the new scenario
function T.startChanged()
	T.pass, T.fail = 0, 0
	T.done = false
	T.co = coroutine.create(function()
		safe(sInstall, "install")
		sLine()
		sQuiet()
		sSneak()
		sEndurance()
		reset(0, 5, 5)
		p():getInventory():clear()
		T.done = true
	end)
	log("start changed scenarios")
end

function T.start()
	T.done = false
	T.co = coroutine.create(function()
		run()
		T.done = true
	end)
	log("start")
end

function T.poll()
	if T.done then
		protect(false)
		log("RESULT pass=" .. tostring(T.pass) .. " fail=" .. tostring(T.fail))
		if PZTest and PZTest.log then PZTest.log("SFXTest done pass=" .. T.pass .. " fail=" .. T.fail) end
	else
		PZTest.step("wait 60")
		PZTest.step("lua SFXTest.poll()")
	end
end

local function onTick()
	if not T.co then return end
	protect(true)
	if coroutine.status(T.co) == "dead" then T.co = nil; return end
	local ok, err = coroutine.resume(T.co)
	if not ok then
		T.fail = (T.fail or 0) + 1
		log("FAIL coroutine", tostring(err))
		if PZTest and PZTest.fail then PZTest.fail("SFXTest coroutine " .. tostring(err)) end
		T.co = nil
		T.done = true
	end
end
Events.OnTick.Add(onTick)

-- picture check: max shout next to a building, then "shot" from the step list
function T.demoWindows()
	T.pass, T.fail = T.pass or 0, T.fail or 0
	reset(10, 10)
	local win = findWindow(60)
	if not win then log("INFO demo: no window"); return end
	standNear(win, 3, 1)
	hands("Base.Bullhorn", nil)
	T.demoWin = win
end
function T.demoShout()
	shout()
	log("INFO", "demo windows broken:", F().lastWindows, "at", T.demoWin and T.demoWin.x, T.demoWin and T.demoWin.y)
end

-- rerun only the windows scenario (pzt live, same client)
function T.windowsOnly()
	T.pass, T.fail = 0, 0
	T.done = false
	T.co = coroutine.create(function() sWindows(); T.done = true end)
	log("start windowsOnly")
end
