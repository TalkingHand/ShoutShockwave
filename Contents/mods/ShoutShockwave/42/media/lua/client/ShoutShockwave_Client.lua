-- ShoutShockwave client: takes over IsoPlayer:Callout() calls from Lua (Q key, emote wheel, vehicle
-- passenger, d-pad), sets the loudness from Strength / Voice / fatigue, spends endurance,
-- resolves effects (single player) or reports the shout to the server (multiplayer),
-- and draws the effect.
require "ShoutShockwave/Core"
require "ISUI/ISUIElement"
local F = ShoutShockwave

------------------------------------------------------------------------
-- options (per client)
------------------------------------------------------------------------
local DEFAULTS = { ring = true, dust = true }
local options
if PZAPI and PZAPI.ModOptions then
	options = PZAPI.ModOptions:create("ShoutShockwave", getText("IGUI_ShoutShockwave_Title"))
	options:addTickBox("ring", getText("IGUI_ShoutShockwave_Ring"), DEFAULTS.ring, getText("IGUI_ShoutShockwave_Ring_tooltip"))
	options:addTickBox("dust", getText("IGUI_ShoutShockwave_Dust"), DEFAULTS.dust, getText("IGUI_ShoutShockwave_Dust_tooltip"))
end
function F.visual(id)
	if F.overrides["fx_" .. id] ~= nil then return F.overrides["fx_" .. id] end
	local o = options and options:getOption(id)
	if o and o.getValue then return o:getValue() end
	return DEFAULTS[id]
end

------------------------------------------------------------------------
-- effects drawing
------------------------------------------------------------------------
local TEX = {}
local function tex(prefix, n)
	if not TEX[prefix] then
		TEX[prefix] = {}
		for i = 0, n - 1 do
			TEX[prefix][i] = getTexture(string.format("media/textures/ShoutShockwave/%s_%02d.png", prefix, i))
		end
	end
	return TEX[prefix]
end

local active = {}   -- running visual effects

-- effect clock: real ms by default; a capture script can set F.clock to a game-tick clock so
-- screenshots (which stall the game) do not skip animation frames
function F.now()
	if F.clock then return F.clock() end
	return getTimestampMs()
end

ShoutShockwaveOverlay = ISUIElement:derive("ShoutShockwaveOverlay")
function ShoutShockwaveOverlay:new()
	local o = ISUIElement.new(self, 0, 0, 0, 0)
	o.anchorLeft, o.anchorTop = true, true
	return o
end

local function frameOf(e, now, n)
	local t = (now - e.start) / e.dur
	if t < 0 then t = 0 end
	local i = math.floor(t * n)
	if i >= n then return nil end
	return i
end

function ShoutShockwaveOverlay:prerender() end
function ShoutShockwaveOverlay:render()
	local now = F.now()
	local keep = {}
	for _, e in ipairs(active) do
		if e.kind == "ring" then
			local frames = tex("R2_ring_soft", 10)
			local i = frameOf(e, now, 10)
			if i then
				local cx = isoToScreenX(0, e.x, e.y, e.z)
				local cy = isoToScreenY(0, e.x, e.y, e.z)
				local a = e.r / math.sqrt(2)
				local hw = math.abs(isoToScreenX(0, e.x + a, e.y - a, e.z) - cx) / 0.95
				local t = frames[i]
				if t and hw > 2 then self:drawTextureScaled(t, cx - hw, cy - hw / 2, hw * 2, hw, e.alpha or 1, 1, 1, 1) end
				keep[#keep + 1] = e
			end
		elseif e.kind == "puff" then
			local frames = tex("P1_dust_puff", 8)
			local i = frameOf(e, now, 8)
			if i then
				local x, y, z = e.x, e.y, e.z
				if e.zombie and not e.zombie:isDead() then x, y, z = e.zombie:getX(), e.zombie:getY(), e.zombie:getZ() end
				local zoom = getCore():getZoom(0)
				local s = F.DUST_SIZE * e.scale / zoom
				local cx = isoToScreenX(0, x, y, z + 0.35)
				local cy = isoToScreenY(0, x, y, z + 0.35)
				local t = frames[i]
				if t then self:drawTextureScaled(t, cx - s / 2, cy - s / 2, s, s, e.scale, 1, 1, 1) end
				keep[#keep + 1] = e
			end
		end
	end
	active = keep
end

local overlay
local function ensureOverlay()
	if overlay then return end
	overlay = ShoutShockwaveOverlay:new()
	overlay:initialise()
	overlay:addToUIManager()
	overlay:backMost()
	F.overlay = overlay
end
F.ensureOverlay = ensureOverlay

local function lowestRange(shout)
	local k = F.unlockedCount(shout.voice)
	local Rp = F.effectRadius(shout.R) * (shout.sneaking and F.SNEAK_FACTOR or 1)
	local t = k > 0 and F.threshold(1, k) or F.THRESHOLDS[1]
	local r = Rp / t
	if r > 16 then r = 16 end
	return r
end

-- ring strength by Voice unlock stage (0 = Voice 0-1 ... 4 = Voice 8+); size already grows with
-- the effect reach. Stage 4 = the preview video (alpha 1).
F.RING_ALPHA = { [0] = 0.3, 0.45, 0.6, 0.8, 1.0 }

-- rumble: silent below Voice 4, then volume follows the shout's effect loudness R'; the file is
-- twice the S5 sample (+6 dB), so volume 1.0 = 2x the sample at the loudest shout (R' 65).
F.RUMBLE_FROM_VOICE = 4
F.RUMBLE_FULL_AT = 65
function F.rumbleVolume(shout)
	if (shout.voice or 0) < F.RUMBLE_FROM_VOICE then return 0 end
	local v = F.effectRadius(shout.R) * (shout.sneaking and F.SNEAK_FACTOR or 1) / F.RUMBLE_FULL_AT
	if v > 1 then v = 1 end
	return v
end

-- dust on knocked-down zombies: from Voice 8, size and opacity 0.7 at Voice 8 -> 1.0 at Voice 10
-- (1.0 = the preview video: 140 px at zoom 1)
F.DUST_FROM_VOICE = 8
F.DUST_SIZE = 140
function F.dustScale(voice)
	voice = voice or 0
	if voice < F.DUST_FROM_VOICE then return 0 end
	local s = 0.7 + 0.15 * (voice - F.DUST_FROM_VOICE)
	if s > 1 then s = 1 end
	return s
end

local function playRumble(source, shout)
	local v = F.rumbleVolume(shout)
	if v <= 0 or not source then return end
	local emitter = source:getEmitter()
	if not emitter then return end
	local id = emitter:playSound("ShoutShockwave_Rumble")
	if id and id ~= 0 then emitter:setVolume(id, v) end
	F.lastRumble = v
end

-- shout: { x, y, z, R, sneaking, voice, source }; hits: list of { zombie?, effect }
-- ring + rumble at the shouter; dust on zombies knocked down (Voice 8+)
-- mode: "self" (my shout: ring, rumble, dust if hits known), "selfHits" (server results for my
--       shout: dust), "other" (someone else's shout: ring, rumble, dust)
function F.playVisuals(shout, hits, mode)
	ensureOverlay()
	local now = F.now()
	local dust = F.dustScale(shout.voice)
	F.lastDust = nil
	if dust > 0 and F.visual("dust") and (mode ~= "self" or hits) then
		for _, h in ipairs(hits or {}) do
			if h.effect >= 2 and h.zombie then
				active[#active + 1] = { kind = "puff", zombie = h.zombie, x = h.zombie:getX(), y = h.zombie:getY(), z = h.zombie:getZ(), scale = dust, start = now + 120, dur = 500 }
				F.lastDust = dust
			end
		end
	end
	if mode == "self" or mode == "other" then
		local r = lowestRange(shout)
		if F.visual("ring") then
			local alpha = F.RING_ALPHA[F.unlockedCount(shout.voice or 0)] or 1
			F.lastRing = { alpha = alpha, r = r }
			active[#active + 1] = { kind = "ring", x = shout.x, y = shout.y, z = shout.z, r = r, alpha = alpha, start = now, dur = 450 }
		end
		playRumble(shout.source, shout)
	end
end

------------------------------------------------------------------------
-- the shout itself
------------------------------------------------------------------------
local function isMP() return isClient() end

-- vanilla Callout() body (42.22.2) for the case where the shout is quieter than vanilla.
-- Lua cannot set IsoGameCharacter.callOut, so tamed animals don't come to this quieter shout.
local function luaShout(player, doAnim, R, sneaking, shoutItem, megaphone)
	local text = ""
	if sneaking then
		local n = ZombRand(3) + 1
		text = getText("IGUI_PlayerText_Callout" .. n .. "Sneak")
		if n == 3 then
			player:transmitPlayerVoiceSound(megaphone and "WhisperMegaphoneHey" or "WhisperHey")
		else
			player:transmitPlayerVoiceSound(megaphone and "WhisperMegaphonePsst" or "WhisperPsst")
		end
	elseif shoutItem then
		player:playSound(shoutItem:getShoutType())
	else
		text = getText("IGUI_PlayerText_Callout" .. (ZombRand(3) + 1) .. "New")
		player:transmitPlayerVoiceSound(megaphone and "ShoutMegaphoneHey" or "ShoutHey")
	end
	local r = math.max(1, math.floor(R))
	addSound(player, math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()), r, r)
	player:SayShout(text)
	if doAnim then player:playEmote("shout") end
end

-- returns true when handled
function F.onCallout(player, vanilla, ...)
	local nargs = select("#", ...)
	local doAnim = nargs >= 1 and (...) or false
	if not player:isLocalPlayer() or getCore():isTutorial() or player:getVehicle() then return false end
	if nargs >= 1 and not player:isCanShout() then return false end

	local stats = player:getStats()
	local endurance = stats:get(CharacterStat.ENDURANCE)
	local R, base, sneaking, shoutItem, megaphone = F.loudness(player, endurance)
	if R >= base then
		vanilla(player, ...)
		if R > base then
			local r = math.floor(R)
			addSound(player, math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()), r, r)
		end
	else
		luaShout(player, doAnim, R, sneaking, shoutItem, megaphone)
	end
	local e = endurance - F.enduranceCost(player)
	stats:set(CharacterStat.ENDURANCE, e > 0 and e or 0)

	local shout = { x = player:getX(), y = player:getY(), z = player:getZ(), R = R, sneaking = sneaking, voice = F.voiceLevel(player), source = player }
	F.lastShout = shout
	if isMP() then
		sendClientCommand(player, F.MOD, "shout", { endurance = endurance })
		F.playVisuals(shout, nil, "self")
	else
		local results = F.resolve(player, shout, function() return true end)
		F.lastResults = results
		F.playVisuals(shout, results, "self")
	end
	return true
end

local function install()
	if F.installed then return end
	local cmt = __classmetatables and __classmetatables[IsoPlayer.class]
	local mt = cmt and cmt.__index
	if not mt or not mt.Callout then
		F.log("could not hook IsoPlayer:Callout")
		return
	end
	local vanilla = mt.Callout
	F.vanillaCallout = vanilla
	mt.Callout = function(player, ...)
		local ok, handled = pcall(F.onCallout, player, vanilla, ...)
		if not ok then
			F.log("error:", handled)
			return vanilla(player, ...)
		end
		if not handled then return vanilla(player, ...) end
	end
	F.installed = true
	F.log("installed")
end
Events.OnGameStart.Add(install)

------------------------------------------------------------------------
-- multiplayer: results from the server
------------------------------------------------------------------------
local function findZombie(id)
	local cell = getCell()
	if not cell then return nil end
	local list = cell:getZombieList()
	for i = 0, list:size() - 1 do
		local z = list:get(i)
		if z:getOnlineID() == id then return z end
	end
	return nil
end

local function onServerCommand(module, command, args)
	if module ~= F.MOD or command ~= "fx" or not args then return end
	local shooter = getPlayerByOnlineID(args.shooter)
	local own = shooter ~= nil and shooter:isLocalPlayer()
	if shooter and args.remote then
		for _, r in pairs(args.remote) do
			local z = findZombie(r.id)
			if z and z:isLocal() then F.applyToZombie(z, shooter, r) end
		end
	end
	local hits = {}
	for _, h in pairs(args.hits or {}) do
		hits[#hits + 1] = { zombie = findZombie(h.id), effect = h.effect }
	end
	local shout = { x = args.x, y = args.y, z = args.z, R = args.R, sneaking = args.sneaking, voice = args.voice, source = shooter }
	F.playVisuals(shout, hits, own and "selfHits" or "other")
end
Events.OnServerCommand.Add(onServerCommand)
