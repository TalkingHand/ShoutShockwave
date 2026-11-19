-- ShoutShockwave server side (multiplayer only). A client reports a shout; the server spends the
-- endurance on its own copy of the player (the server owns player stats and sends them to the
-- client every second, so the client's own subtraction alone snaps back), works out which
-- zombies are hit using its copy of the player (skills, hands, endurance) and zombie positions,
-- applies effects to the zombies it simulates, and tells every client the rest
-- (the owning client applies them; everyone draws the effect).
require "ShoutShockwave/Core"
local F = ShoutShockwave

local lastShout = {}
local MIN_GAP_MS = 200

-- exposed for the single-player test (sendServerCommand does nothing outside a server)
function F.serverShout(player, args)
	if not player or player:getVehicle() then return end
	local key = player:getOnlineID()

	-- the client already shouted (sound, text), so the cost is paid even when the flood guard
	-- below drops the effects
	local endurance, after = F.spendEndurance(player)
	sendServerCommand(player, F.MOD, "endurance", { id = key, value = after })

	local now = getTimestampMs()
	if lastShout[key] and now - lastShout[key] < MIN_GAP_MS then return end
	lastShout[key] = now

	local R = F.loudness(player, endurance)
	local shout = {
		x = player:getX(), y = player:getY(), z = player:getZ(),
		R = R, sneaking = player:isSneaking(), voice = F.voiceLevel(player),
	}
	local results, remote = F.resolve(player, shout, function(z) return z:getOwner() == nil end)

	local hits, rem = {}, {}
	for _, r in ipairs(results) do hits[#hits + 1] = { id = r.id, effect = r.effect } end
	for _, r in ipairs(remote) do
		rem[#rem + 1] = { id = r.id, effect = r.effect, damage = r.damage, dazeMs = r.dazeMs }
	end
	sendServerCommand(F.MOD, "fx", {
		shooter = key, x = shout.x, y = shout.y, z = shout.z,
		R = R, sneaking = shout.sneaking, voice = shout.voice,
		hits = hits, remote = rem,
	})
	return shout, results
end

local function onClientCommand(module, command, player, args)
	if module ~= F.MOD or command ~= "shout" or not player then return end
	F.serverShout(player, args)
end
Events.OnClientCommand.Add(onClientCommand)
