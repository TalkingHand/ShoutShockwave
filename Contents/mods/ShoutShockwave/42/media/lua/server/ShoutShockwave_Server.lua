-- ShoutShockwave server side (multiplayer only). A client reports a shout; the server works out which
-- zombies are hit using its own copy of the player (skills, hands) and zombie positions,
-- applies effects to the zombies it simulates, and tells every client the rest
-- (the owning client applies them; everyone draws the effect).
require "ShoutShockwave/Core"
local F = ShoutShockwave

local lastShout = {}
local MIN_GAP_MS = 200

local function onClientCommand(module, command, player, args)
	if module ~= F.MOD or command ~= "shout" or not player then return end
	local now = getTimestampMs()
	local key = player:getOnlineID()
	if lastShout[key] and now - lastShout[key] < MIN_GAP_MS then return end
	lastShout[key] = now
	if player:getVehicle() then return end

	local endurance = tonumber(args and args.endurance) or 1
	if endurance < 0 then endurance = 0 elseif endurance > 1 then endurance = 1 end
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
end
Events.OnClientCommand.Add(onClientCommand)
