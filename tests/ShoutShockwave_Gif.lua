-- ShoutShockwave workshop GIF capture (pzt TEST_FILES only, not shipped).
-- Max shout (megaphone, Strength 10, Voice 10) in a shopping street, zoomed out, with a crowd of
-- zombies closing in. Saves numbered full screenshots (UI included, other UI hidden):
-- Zomboid/Screenshots/sfxgif_<FFF>.png
-- Run: PZT_STEPS="lua SFXGif.start();wait 60;lua SFXGif.poll()" pzt live

SFXGif = SFXGif or {}
local G = SFXGif

local function log(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	print("[SFXGif] " .. table.concat(parts, " "))
end
local function p() return getPlayer() end
local function yield() coroutine.yield() end
local function waitTicks(n) for _ = 1, n do yield() end end

G.CENTER = { 10625, 10150 }  -- Muldraugh, shops around a parking lot (search starts here)
G.SEARCH = 40
G.ZOOM = 2.5
G.ZOMBIES = 70
G.EVERY = 4                  -- ticks between frames (60 fps game -> 15 fps GIF)
G.BEFORE, G.AFTER = 14, 52   -- frames before / after the shout

local function setLevel(perk, n)
	p():setPerkLevelDebug(perk, n)
	pcall(function() p():getXp():setXPToLevel(perk, n) end)
end

local function place(x, y)
	local pl = p()
	pl:setX(x); pl:setY(y); pl:setZ(0)
	pl:setLastX(x); pl:setLastY(y); pl:setLastZ(0)
	pcall(function() pl:setCurrentSquareFromPosition() end)
end

local function windowsNear(cell, x, y, r)
	local n = 0
	for dx = -r, r do
		for dy = -r, r do
			for z = 0, 1 do
				local sq = cell:getGridSquare(x + dx, y + dy, z)
				local w = sq and sq:getWindow()
				if w and not w:isDestroyed() and not w:isBarricaded() then n = n + 1 end
			end
		end
	end
	return n
end

-- open street square: outside, free, and every square within 3 tiles is outside too
local function openStreet(cell, x, y)
	for dx = -3, 3 do
		for dy = -3, 3 do
			local sq = cell:getGridSquare(x + dx, y + dy, 0)
			if not sq or not sq:isOutside() then return false end
		end
	end
	local sq = cell:getGridSquare(x, y, 0)
	return sq:isFree(false)
end

local function windowCentroid(cell, x, y, r)
	local sx, sy, n = 0, 0, 0
	for dx = -r, r do
		for dy = -r, r do
			local sq = cell:getGridSquare(x + dx, y + dy, 0)
			local w = sq and sq:getWindow()
			if w and not w:isDestroyed() then sx, sy, n = sx + x + dx, sy + y + dy, n + 1 end
		end
	end
	if n == 0 then return nil end
	return sx / n, sy / n
end

local function bestSpot()
	local cell = getCell()
	local best, bx, by = -1, nil, nil
	for x = G.CENTER[1] - G.SEARCH, G.CENTER[1] + G.SEARCH, 2 do
		for y = G.CENTER[2] - G.SEARCH, G.CENTER[2] + G.SEARCH, 2 do
			if openStreet(cell, x, y) then
				local n = windowsNear(cell, x, y, 12)
				if n > best then best, bx, by = n, x, y end
			end
		end
	end
	return bx, by, best
end

local function hideOtherUI()
	pcall(function() local c = UIManager.getDebugConsole(); if c then c:setVisible(false) end end)
	if ISUIHandler and ISUIHandler.setVisibleAllUI then
		ISUIHandler.allUIVisible = false
		ISUIHandler.setVisibleAllUI(false)
	end
	ShoutShockwave.ensureOverlay()
	ShoutShockwave.overlay:setVisible(true)
end

local function showUI()
	if ISUIHandler and ISUIHandler.setVisibleAllUI then
		ISUIHandler.allUIVisible = true
		ISUIHandler.setVisibleAllUI(true)
	end
end

local function spawnCrowd(cx, cy)
	local list = getCell():getZombieList()
	for i = list:size() - 1, 0, -1 do
		local z = list:get(i)
		if z then z:removeFromSquare(); z:removeFromWorld() end
	end
	local n = 0
	for i = 1, G.ZOMBIES do
		local a = ZombRandFloat(0, 6.283)
		local d = ZombRandFloat(3, 16)
		local x, y = math.floor(cx + math.cos(a) * d), math.floor(cy + math.sin(a) * d)
		local sq = getCell():getGridSquare(x, y, 0)
		if sq and sq:isFree(false) then
			local l = addZombiesInOutfit(x, y, 0, 1, nil, 50)
			if l and l:size() > 0 then
				l:get(0):setUseless(true)   -- stand still until the shot; no target while he is invisible
				n = n + 1
			end
		end
	end
	return n
end

G.tick = 0
local function run()
	ShoutShockwave.clock = function() return G.tick * 1000 / 60 end
	local pl = p()
	pl:setGodMod(true)
	pl:setInvisible(true)          -- zombies ignore him while everything is set up
	if pl.setGhostMode then pl:setGhostMode(false) end
	pl:setZombiesDontAttack(true)
	pl:setCanSeeAll(true)          -- no black outside the vision cone when zoomed out
	setLevel(Perks.Strength, 10)
	setLevel(Perks.Shout, 10)
	setLevel(Perks.Fitness, 10)
	getGameTime():setTimeOfDay(13)

	place(G.CENTER[1] + 0.5, G.CENTER[2] + 0.5)
	waitTicks(400)
	local x, y, n
	if G.SPOT then x, y, n = G.SPOT[1], G.SPOT[2], -1 else x, y, n = bestSpot() end
	log("best spot", x, y, "windows", n)
	if not x then log("FAIL no spot"); return end
	place(x + 0.5, y + 0.5)
	waitTicks(300)
	local wx, wy = nil, nil
	if G.FACE ~= false then wx, wy = windowCentroid(getCell(), x, y, 12) end
	if wx then pl:faceLocation(wx, wy) end

	pl:getInventory():clear()
	local mega = pl:getInventory():AddItem("Base.Bullhorn")
	pl:setPrimaryHandItem(mega)
	pl:getStats():set(CharacterStat.ENDURANCE, 1.0)

	for _ = 1, 10 do
		local z = getCore():getZoom(0)
		if math.abs(z - G.ZOOM) < 0.01 then break end
		getCore():doZoomScroll(0, z < G.ZOOM and 1 or -1)
		waitTicks(15)
	end
	waitTicks(60)
	log("zoom", getCore():getZoom(0))
	hideOtherUI()
	-- the black area outside the view cone is VisibilityPolygon2, drawn only while this is on
	getDebugOptions():setBoolean("FBORenderChunk.RenderVisionPolygon", false)
	getDebugOptions():setBoolean("FBORenderChunk.NoLighting", true)   -- unseen squares are drawn dark through their light info

	local spawned = spawnCrowd(x + 0.5, y + 0.5)
	log("zombies", spawned)
	waitTicks(30)

	-- ready check: the shout breaks windows for good, so shoot only when everything is set
	local problems = {}
	if getDebugOptions():getBoolean("FBORenderChunk.RenderVisionPolygon") then problems[#problems + 1] = "vision polygon still on" end
	local intact = windowsNear(getCell(), x, y, 12)
	if intact < 8 then problems[#problems + 1] = "intact windows " .. intact end
	if spawned < 40 then problems[#problems + 1] = "zombies " .. spawned end
	if pl:getPerkLevel(Perks.Shout) < 10 or pl:getPerkLevel(Perks.Strength) < 10 then problems[#problems + 1] = "levels" end
	local held = pl:getPrimaryHandItem()
	if not held or held:getType() ~= "Bullhorn" then problems[#problems + 1] = "no megaphone" end
	if math.abs(getCore():getZoom(0) - G.ZOOM) > 0.01 then problems[#problems + 1] = "zoom " .. getCore():getZoom(0) end
	if #problems > 0 then
		log("FAIL not ready, no shout:", table.concat(problems, ", "))
		getDebugOptions():setBoolean("FBORenderChunk.RenderVisionPolygon", true)
		showUI()
		return
	end
	log("ready: intact windows", intact, "zombies", spawned)
	G.pl, G.wx, G.wy = pl, wx, wy
	waitTicks(20)
	Core.getInstance():TakeFullScreenshot((G.PREFIX or "sfxgif") .. "_precheck.png")
	log("PRECHECK shot taken, waiting for SFXGif.shoot()")
end

-- second part, run only after the precheck picture was checked
local function shoot()
	local pl, wx, wy = G.pl, G.wx, G.wy
	PZTestUnprotect = true        -- harness keeps him invisible otherwise
	pl:setInvisible(false)         -- now let them come
	local list = getCell():getZombieList()
	for i = 0, list:size() - 1 do local z = list:get(i); z:setUseless(false); z:setTarget(pl) end
	waitTicks(150)

	local f = 0
	for i = 1, G.BEFORE + G.AFTER do
		if wx then pl:faceLocation(wx, wy) end
		if i == G.BEFORE + 1 then
			pl:getStats():set(CharacterStat.ENDURANCE, 1.0)
			pl:setCanShout(true)
			pl:Callout(true)
			log("shout R", ShoutShockwave.lastShout and ShoutShockwave.lastShout.R, "windows", ShoutShockwave.lastWindows, "hits", ShoutShockwave.lastResults and #ShoutShockwave.lastResults)
		end
		Core.getInstance():TakeFullScreenshot(string.format("%s_%03d.png", G.PREFIX or "sfxgif", f))
		f = f + 1
		waitTicks(G.EVERY)
	end
	G.frames = f
	PZTestUnprotect = nil
	pl:setInvisible(true)
	log("shot done, client kept running")
end

function G.shoot()
	G.done = false
	G.co = coroutine.create(function() shoot(); G.done = true end)
	log("shoot")
end

function G.start()
	G.done = false
	G.co = coroutine.create(function() run(); G.done = true end)
	log("start")
end

function G.poll()
	if G.done then
		log("DONE frames=" .. tostring(G.frames))
		if PZTest and PZTest.log then PZTest.log("SFXGif done frames=" .. tostring(G.frames)) end
	else
		PZTest.step("wait 60")
		PZTest.step("lua SFXGif.poll()")
	end
end

local function onTick()
	G.tick = (G.tick or 0) + 1
	if not G.co then return end
	if coroutine.status(G.co) == "dead" then G.co = nil; return end
	local ok, err = coroutine.resume(G.co)
	if not ok then
		log("FAIL coroutine", tostring(err))
		if PZTest and PZTest.fail then PZTest.fail("SFXGif " .. tostring(err)) end
		G.co = nil
		G.done = true
	end
end
Events.OnTick.Add(onTick)
