-- The customs check: where the ledger's verdict meets the player's inventory.
--
-- Nothing in here destroys an item on a network failure. Only an explicit verdict
-- from the ledger removes a MAGI; "we could not ask" leaves the note in place and
-- marked unverified, so an API outage can never confiscate a player's money.

hashimon_magi = hashimon_magi or {}

local BATCH = 32
local DEFAULT_SWEEP_INTERVAL = 180

-- Verdicts that mean "this object is not a MAGI". Anything else is a transport
-- problem and is handled as such.
local DESTROY = {
	stale = "its custody nonce was already retired — this is a duplicate copy. Total supply is unchanged.",
	forged = "its seal does not verify — the metadata was fabricated or edited.",
	unknown = "the ledger has no such note.",
	retired = "the note has been retired from circulation.",
}

local function say(player_name, msg)
	core.chat_send_player(player_name, "[MAGI] " .. msg)
end

local function short(serial)
	return tostring(serial):sub(1, 8)
end

local function sweep_interval()
	local raw = tonumber(core.settings:get("hashimon_magi.sweep_interval"))
	if raw == nil then
		return DEFAULT_SWEEP_INTERVAL
	end
	return raw
end

--- Apply one batch of verdicts to what the player is actually holding right now.
local function apply_results(player_name, results)
	local player = core.get_player_by_name(player_name)
	if not player or not results then
		return 0, 0
	end
	local rotated, destroyed = 0, 0
	for _, result in ipairs(results) do
		local inv, listname, index, stack = hashimon_magi.find_stack(player, result.serial)
		if inv then
			if result.verdict == "ok" and result.token then
				inv:set_stack(listname, index, hashimon_magi.write_token(stack, result.token, true))
				rotated = rotated + 1
			elseif DESTROY[result.verdict] then
				inv:set_stack(listname, index, ItemStack(""))
				destroyed = destroyed + 1
				say(player_name, string.format("MAGI #%s destroyed: %s", short(result.serial), DESTROY[result.verdict]))
				core.log("action", string.format("[hashimon_magi] %s lost MAGI %s (%s)",
					player_name, result.serial, result.verdict))
			end
		end
	end
	return rotated, destroyed
end

hashimon_magi.apply_results = apply_results

--- A cube with no serial was never issued (creative give, /giveme). It is not
--- evidence of cheating, just not money — remove it quietly.
local function drop_blanks(player, blanks)
	if #blanks == 0 then
		return
	end
	local inv = player:get_inventory()
	for _, at in ipairs(blanks) do
		inv:set_stack(at.listname, at.index, ItemStack(""))
	end
end

--- Verify every MAGI a player carries. `callback(ok, err, rotated, destroyed)`.
function hashimon_magi.sweep(player_name, event, callback)
	local player = core.get_player_by_name(player_name)
	if not player then
		if callback then callback(false, "offline") end
		return
	end
	local tokens, blanks = hashimon_magi.carried(player)
	drop_blanks(player, blanks)
	if #tokens == 0 then
		if callback then callback(true, nil, 0, 0) end
		return
	end

	-- One request per batch; results are matched back by serial, never by position.
	local chunks = {}
	for i = 1, #tokens, BATCH do
		local chunk = {}
		for j = i, math.min(i + BATCH - 1, #tokens) do
			chunk[#chunk + 1] = tokens[j]
		end
		chunks[#chunks + 1] = chunk
	end

	local pending = #chunks
	local total_rotated, total_destroyed = 0, 0
	local failure
	for _, chunk in ipairs(chunks) do
		hashimon_magi.api_custody(player_name, event or "check", chunk, function(ok, err, body)
			if ok and body then
				local rotated, destroyed = apply_results(player_name, body.results)
				total_rotated = total_rotated + rotated
				total_destroyed = total_destroyed + destroyed
			else
				failure = failure or err
			end
			pending = pending - 1
			if pending == 0 and callback then
				callback(failure == nil, failure, total_rotated, total_destroyed)
			end
		end)
	end
end

-- Coalesce the bursts: picking up a handful of notes fires one sweep, not five.
local sweep_pending = {}

function hashimon_magi.request_sweep(player_name, event)
	if sweep_pending[player_name] then
		return
	end
	sweep_pending[player_name] = true
	core.after(1.0, function()
		sweep_pending[player_name] = nil
		hashimon_magi.sweep(player_name, event)
	end)
end

--- A MAGI just placed in the world. Same check, but the rotated token has to land
--- on the node's metadata rather than in an inventory.
function hashimon_magi.check_placed(pos, player_name)
	local meta = core.get_meta(pos)
	local token = {
		serial = meta:get_string("magi_serial"),
		sats = tonumber(meta:get_string("magi_sats")) or 0,
		epoch = tonumber(meta:get_string("magi_epoch")) or 0,
		nonce = meta:get_string("magi_nonce"),
		seal = meta:get_string("magi_seal"),
	}
	if token.serial == "" then
		return
	end
	hashimon_magi.api_custody(player_name, "place", { token }, function(ok, err, body)
		if not ok or not body or not body.results or not body.results[1] then
			core.log("warning", "[hashimon_magi] place check failed: " .. tostring(err))
			return
		end
		local result = body.results[1]
		-- The node may already be gone (dug, or the chunk unloaded) — re-read before
		-- writing, and never resurrect a position that no longer holds a MAGI.
		if core.get_node(pos).name ~= hashimon_magi.NOTE then
			return
		end
		if result.verdict == "ok" and result.token then
			local node_meta = core.get_meta(pos)
			node_meta:set_string("magi_serial", result.token.serial)
			node_meta:set_string("magi_sats", tostring(result.token.sats))
			node_meta:set_string("magi_epoch", tostring(result.token.epoch))
			node_meta:set_string("magi_nonce", result.token.nonce)
			node_meta:set_string("magi_seal", result.token.seal)
		elseif DESTROY[result.verdict] then
			core.remove_node(pos)
			say(player_name, string.format("MAGI #%s destroyed: %s", short(result.serial), DESTROY[result.verdict]))
		end
	end)
end

--- Right-click inspection of a single note: a verdict the player asked for.
function hashimon_magi.inspect(player, stack)
	local token = hashimon_magi.token_from_stack(stack)
	local player_name = player:get_player_name()
	if not token then
		say(player_name, "This cube carries no serial — it was never issued.")
		return
	end
	say(player_name, string.format("Checking MAGI #%s ...", short(token.serial)))
	hashimon_magi.api_custody(player_name, "inspect", { token }, function(ok, err, body)
		if not ok or not body or not body.results or not body.results[1] then
			say(player_name, "Could not reach the ledger (" .. tostring(err) .. "). The note is unchanged, but unverified.")
			return
		end
		local result = body.results[1]
		apply_results(player_name, body.results)
		if result.verdict == "ok" then
			say(player_name, string.format("MAGI #%s is genuine: %d sats backing, epoch %d. Custody rotated.",
				short(token.serial), token.sats, token.epoch))
		end
	end)
end

-- Joining is the one moment every note a player owns is guaranteed to pass through
-- the check, including notes that were duplicated while they were offline.
core.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	core.after(2.0, function()
		hashimon_magi.sweep(player_name, "join")
	end)
end)

-- Picking one up is a change of custody: verify it in the new hands.
core.register_on_item_pickup(function(itemstack, picker)
	if itemstack:get_name() == hashimon_magi.NOTE and picker and picker:is_player() then
		hashimon_magi.request_sweep(picker:get_player_name(), "pickup")
	end
	return nil
end)

-- The periodic sweep. Its real job is duplication *latency*: without it a cloned
-- note that never changes hands could sit unchallenged indefinitely.
local elapsed = 0
core.register_globalstep(function(dtime)
	local interval = sweep_interval()
	if interval <= 0 then
		return
	end
	elapsed = elapsed + dtime
	if elapsed < interval then
		return
	end
	elapsed = 0
	for _, player in ipairs(core.get_connected_players()) do
		hashimon_magi.request_sweep(player:get_player_name(), "sweep")
	end
end)

-- Shared with commands.lua: the verdicts that justify taking an item away.
hashimon_magi.DESTROY_REASONS = DESTROY
hashimon_magi.say = say
hashimon_magi.short_serial = short
