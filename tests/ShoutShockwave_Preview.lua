-- ShoutShockwave effect preview (pzt TEST_FILES only, not shipped). Plays every effect candidate from
-- _devnotes/ShoutShockwave/README.md in order and saves numbered full screenshots (UI included) with a
-- label, so the frames can be made into one video for the user to pick from.
-- Run: PZT_STEPS="lua SFXPreview.start();wait 60;lua SFXPreview.poll()" pzt live
-- Frames: Zomboid/Screenshots/sfxpv_<NN>_<id>_<FF>.png

SFXPreview = SFXPreview or {}
local PV = SFXPreview

local function log(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	print("[SFXPreview] " .. table.concat(parts, " "))
end

local function p() return getPlayer() end
local function yield() coroutine.yield() end
local function waitTicks(n) for _ = 1, n do yield() end end

local function protect(on)
	local pl = p()
	if not pl then return end
	pl:setGodMod(on)
	pl:setInvisible(on)
	pl:setZombiesDontAttack(on)
	if pl.setGhostMode then pl:setGhostMode(on) end
end

------------------------------------------------------------------ drawing

local TEX = {}
local function frames(id, n)
	if not TEX[id] then
		TEX[id] = {}
		for i = 0, n - 1 do
			TEX[id][i] = getTexture(string.format("media/textures/ShoutShockwave_pv/%s_%02d.png", id, i))
		end
	end
	return TEX[id]
end

local function frameAt(t, n)
	local i = math.floor(t * (n - 1) + 0.5)
	if i < 0 then i = 0 elseif i > n - 1 then i = n - 1 end
	return i
end

SFXPVOverlay = ISUIElement:derive("SFXPVOverlay")
function SFXPVOverlay:new()
	local o = ISUIElement.new(self, 0, 0, 0, 0)
	return o
end
function SFXPVOverlay:prerender() end

local function drawGround(self, id, n, t, x, y, z, rTiles)
	local tx = frames(id, n)[frameAt(t, n)]
	if not tx then return end
	local cx, cy = isoToScreenX(0, x, y, z), isoToScreenY(0, x, y, z)
	local a = rTiles / math.sqrt(2)
	local hw = math.abs(isoToScreenX(0, x + a, y - a, z) - cx) / 0.95
	self:drawTextureScaled(tx, cx - hw, cy - hw / 2, hw * 2, hw, 1, 1, 1, 1)
end

function SFXPVOverlay:render()
	local s = PV.show
	if not s then return end
	local pl = p()
	local x, y, z = pl:getX(), pl:getY(), pl:getZ()
	local t = PV.t or 0
	for _, part in ipairs(s.parts or {}) do
		if part.ground then
			drawGround(self, part.ground, part.n, t, x, y, z, part.r)
		elseif part.puff then
			local zoom = getCore():getZoom(0)
			local sz = 140 / zoom
			for _, zb in ipairs(PV.zombies) do
				local tx = frames(part.puff, part.n)[frameAt(t, part.n)]
				local zx, zy = isoToScreenX(0, zb:getX(), zb:getY(), zb:getZ() + 0.35), isoToScreenY(0, zb:getX(), zb:getY(), zb:getZ() + 0.35)
				if tx then self:drawTextureScaled(tx, zx - sz / 2, zy - sz / 2, sz, sz, 1, 1, 1, 1) end
			end
		elseif part.screen then
			local tx = frames(part.screen, part.n)[frameAt(t, part.n)]
			if tx then self:drawTextureScaled(tx, 0, 0, getCore():getScreenWidth(), getCore():getScreenHeight(), part.alpha or 0.6, 1, 1, 1) end
		elseif part.glow then
			local tx = frames(part.glow, part.n)[frameAt(t, part.n)]
			local zoom = getCore():getZoom(0)
			local sz = 256 / zoom
			local cx, cy = isoToScreenX(0, x, y, z + 0.5), isoToScreenY(0, x, y, z + 0.5)
			if tx then self:drawTextureScaled(tx, cx - sz / 2, cy - sz / 2, sz, sz, 1, 1, 1, 1) end
		end
	end
	-- label
	local w = getCore():getScreenWidth()
	self:drawRect(0, 0, w, 44, 0.6, 0, 0, 0)
	self:drawTextCentre(string.format("%d. %s", s.no, s.label), w / 2, 8, 1, 1, 1, 1, UIFont.Large)
end

------------------------------------------------------------------ candidates (README order)

local N = 10
local ITEMS = {
	{ id = "R1", label = "R1 thin white ring", parts = { { ground = "R1_ring_thin", n = N, r = 6 } } },
	{ id = "R2", label = "R2 soft thick ring", parts = { { ground = "R2_ring_soft", n = N, r = 6 } } },
	{ id = "R3", label = "R3 double ring", parts = { { ground = "R3_ring_double", n = N, r = 6 } } },
	{ id = "R4", label = "R4 dust ring", parts = { { ground = "R4_ring_dust", n = N, r = 6 } } },
	{ id = "R5", label = "R5 forward cone (toward lower right)", parts = { { ground = "R5_cone_push", n = N, r = 6 } } },
	{ id = "C1", label = "C1 ground cracks (charged shout)", parts = { { ground = "C1_ground_crack", n = N, r = 4 } } },
	{ id = "P1", label = "P1 dust on knocked-down zombies", parts = { { puff = "P1_dust_puff", n = 8 } }, n = 8 },
	{ id = "F1", label = "F1 white screen-edge flash", parts = { { screen = "F1_edge_white", n = 8, alpha = 0.6 } }, n = 8 },
	{ id = "F2", label = "F2 amber screen-edge flash", parts = { { screen = "F2_edge_amber", n = 8, alpha = 0.6 } }, n = 8 },
	{ id = "F3", label = "F3 soft glow on character", parts = { { glow = "F3_center_glow", n = 8 } }, n = 8 },
	{ id = "L1", label = "L1 light white r5 (night)", light = { 1.0, 0.95, 0.85, 5 } },
	{ id = "L2", label = "L2 light white r10 (night)", light = { 1.0, 0.95, 0.85, 10 } },
	{ id = "L3", label = "L3 light orange r5 (night)", light = { 1.0, 0.6, 0.25, 5 } },
	{ id = "L4", label = "L4 light orange r10 (night)", light = { 1.0, 0.6, 0.25, 10 } },
	{ id = "K1", label = "K1 shake: one bump", shake = { mag = 12, frames = 6, single = true } },
	{ id = "K2", label = "K2 shake: 0.3 s", shake = { mag = 8, frames = 10 } },
	{ id = "K3", label = "K3 shake: 0.6 s", shake = { mag = 8, frames = 18 } },
	{ id = "E1", label = "E1 emote: shout (vanilla)", emote = "shout" },
	{ id = "E2", label = "E2 emote: insult", emote = "insult" },
	{ id = "E3", label = "E3 emote: signalfire", emote = "signalfire" },
	{ id = "X1", label = "X1 combo normal: R1 + dust + light + bump", combo = "normal" },
	{ id = "X2", label = "X2 combo charged: R1 + cracks + white flash + dust + light + shake (night)", combo = "charged" },
}

------------------------------------------------------------------ driver

local shotNo = 0
local function shot(item, f)
	local name = string.format("sfxpv_%02d_%s_%02d.png", item.no, item.id, f)
	Core.getInstance():TakeFullScreenshot(name)
	shotNo = shotNo + 1
end

local function hold(item, f)
	waitTicks(3)
	shot(item, f)
	waitTicks(3)
end

local function setNight(on)
	getGameTime():setTimeOfDay(on and 23 or 13)
end

local function spawnZombies()
	local pl = p()
	PV.zombies = {}
	local list = getCell():getZombieList()
	for i = list:size() - 1, 0, -1 do
		local z = list:get(i)
		if z then z:removeFromSquare(); z:removeFromWorld() end
	end
	for _, d in ipairs({ { 3, 1 }, { -2, 3 }, { 4, -3 } }) do
		local l = addZombiesInOutfit(math.floor(pl:getX()) + d[1], math.floor(pl:getY()) + d[2], math.floor(pl:getZ()), 1, nil, 50)
		if l and l:size() > 0 then
			local z = l:get(0)
			z:setUseless(true)
			PV.zombies[#PV.zombies + 1] = z
		end
	end
end

local function playParts(item, n)
	for f = 0, n - 1 do
		PV.t = f / (n - 1)
		hold(item, f)
	end
end

local function playLight(item)
	local L = item.light
	local pl = p()
	local light = nil
	for f = 0, 5 do
		if f == 1 then
			light = getCell():addLamppost(math.floor(pl:getX()), math.floor(pl:getY()), math.floor(pl:getZ()), L[1], L[2], L[3], L[4])
		elseif f == 4 and light then
			getCell():removeLamppost(light); light = nil
		end
		hold(item, f)
	end
	if light then getCell():removeLamppost(light) end
end

local function playShake(item, s)
	local f = 0
	for i = 0, s.frames - 1 do
		local decay = 1 - i / s.frames
		if s.single then
			if i == 0 then IsoCamera.setOffX(IsoCamera.getOffX() + s.mag); IsoCamera.setOffY(IsoCamera.getOffY() - s.mag / 2) end
		else
			IsoCamera.setOffX(IsoCamera.getOffX() + ZombRandFloat(-s.mag, s.mag) * decay)
			IsoCamera.setOffY(IsoCamera.getOffY() + ZombRandFloat(-s.mag, s.mag) * decay)
		end
		yield()
		shot(item, f); f = f + 1
		yield()
	end
end

local function playEmote(item)
	p():playEmote(item.emote)
	for f = 0, 15 do
		waitTicks(6)
		shot(item, f)
	end
	waitTicks(30)
end

local function playCombo(item)
	local charged = item.combo == "charged"
	if charged then setNight(true); waitTicks(900) end
	local pl = p()
	item.parts = { { ground = "R1_ring_thin", n = N, r = charged and 9 or 5 }, { puff = "P1_dust_puff", n = 8 } }
	if charged then
		table.insert(item.parts, 1, { ground = "C1_ground_crack", n = N, r = 4 })
		item.parts[#item.parts + 1] = { screen = "F1_edge_white", n = 8, alpha = 0.6 }
	end
	PV.show = item
	pl:playEmote("shout")
	local light = getCell():addLamppost(math.floor(pl:getX()), math.floor(pl:getY()), math.floor(pl:getZ()), 1.0, 0.95, 0.85, charged and 10 or 5)
	for f = 0, 11 do
		PV.t = f / 11
		if f == 0 then IsoCamera.setOffX(IsoCamera.getOffX() + (charged and 10 or 8)) end
		if charged and f < 6 then IsoCamera.setOffY(IsoCamera.getOffY() + ZombRandFloat(-8, 8)) end
		if f == 3 and light then getCell():removeLamppost(light); light = nil end
		yield(); shot(item, f); yield()
	end
	if light then getCell():removeLamppost(light) end
	if charged then setNight(false) end
end

local function run()
	local pl = p()
	local x, y = math.floor(pl:getX()) + 0.5, math.floor(pl:getY()) + 0.5
	pl:setX(x); pl:setY(y); pl:setLastX(x); pl:setLastY(y)
	pl:getInventory():clear()
	pl:setPrimaryHandItem(nil); pl:setSecondaryHandItem(nil)
	setNight(false)
	spawnZombies()
	waitTicks(60)
	for i, item in ipairs(ITEMS) do
		item.no = i
		log("item", i, item.id)
		if item.light then
			if not PV.night then setNight(true); PV.night = true; waitTicks(900) end
			PV.show = item; waitTicks(20)
			playLight(item)
			if not (ITEMS[i + 1] and ITEMS[i + 1].light) then setNight(false); PV.night = false; waitTicks(600) end
		elseif item.shake then
			PV.show = item; playShake(item, item.shake)
		elseif item.emote then
			PV.show = item; playEmote(item)
		elseif item.combo then
			playCombo(item)
		else
			PV.show = item
			playParts(item, item.n or N)
		end
		PV.show = nil
		waitTicks(20)
	end
	log("shots", shotNo)
end

function PV.start()
	PV.done = false
	pcall(function() local c = UIManager.getDebugConsole(); if c then c:setVisible(false) end end)
	if not PV.overlay then
		PV.overlay = SFXPVOverlay:new()
		PV.overlay:initialise()
		PV.overlay:addToUIManager()
	end
	PV.co = coroutine.create(function() run(); PV.done = true end)
	log("start")
end

function PV.poll()
	if PV.done then
		protect(false)
		log("DONE shots=" .. shotNo)
		if PZTest and PZTest.log then PZTest.log("SFXPreview done shots=" .. shotNo) end
	else
		PZTest.step("wait 60")
		PZTest.step("lua SFXPreview.poll()")
	end
end

local function onTick()
	if not PV.co then return end
	protect(true)
	if coroutine.status(PV.co) == "dead" then PV.co = nil; return end
	local ok, err = coroutine.resume(PV.co)
	if not ok then
		log("FAIL coroutine", tostring(err))
		if PZTest and PZTest.fail then PZTest.fail("SFXPreview " .. tostring(err)) end
		PV.co = nil
		PV.done = true
	end
end
Events.OnTick.Add(onTick)
