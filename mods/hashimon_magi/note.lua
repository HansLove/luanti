-- The object itself: one cubic node, one MAGI, and the metadata that travels with it.

hashimon_magi = hashimon_magi or {}

hashimon_magi.NOTE = "hashimon_magi:magi"

-- Item/node metadata keys. The same five fields exist on the ItemStack while the
-- MAGI is carried and on the node meta while it is placed in the world, so a MAGI
-- can be set down on a table and picked back up without losing its identity.
local FIELDS = { "serial", "sats", "epoch", "nonce", "seal" }
local PREFIX = "magi_"

local function fkey(name)
	return PREFIX .. name
end

--- Read a token out of any MetaDataRef (item meta or node meta). Returns nil when
--- the object carries no serial at all — a blank cube, not a MAGI.
local function token_from_meta(meta)
	local serial = meta:get_string(fkey("serial"))
	if serial == "" then
		return nil
	end
	return {
		serial = serial,
		sats = tonumber(meta:get_string(fkey("sats"))) or 0,
		epoch = tonumber(meta:get_string(fkey("epoch"))) or 0,
		nonce = meta:get_string(fkey("nonce")),
		seal = meta:get_string(fkey("seal")),
	}
end

function hashimon_magi.token_from_stack(stack)
	if stack:get_name() ~= hashimon_magi.NOTE then
		return nil
	end
	return token_from_meta(stack:get_meta())
end

local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

--- What the player sees in the tooltip. The serial's first 8 hex digits are enough
--- to talk about a specific note in chat without pasting a uuid.
local function describe(token, verified)
	local short = token.serial:sub(1, 8)
	local mark = verified and "sealed" or "unverified"
	return string.format("MAGI #%s\n%s sats backing  |  epoch %d\n%s",
		short, commas(token.sats), token.epoch, mark)
end

local function write_meta(meta, token, verified)
	for _, name in ipairs(FIELDS) do
		meta:set_string(fkey(name), tostring(token[name]))
	end
	meta:set_string("description", describe(token, verified))
	meta:set_string("short_description", "MAGI #" .. token.serial:sub(1, 8))
end

--- Stamp a (freshly rotated) token onto an ItemStack. Returns the stack so callers
--- can inline it into inv:set_stack.
function hashimon_magi.write_token(stack, token, verified)
	write_meta(stack:get_meta(), token, verified ~= false)
	return stack
end

--- Build a brand-new MAGI item for a token handed back by /withdraw.
function hashimon_magi.new_note(token)
	return hashimon_magi.write_token(ItemStack(hashimon_magi.NOTE), token, true)
end

--- Locate a note by serial anywhere in a player's inventory. Custody replies arrive
--- asynchronously, by which time the player may have moved the stack — so nothing
--- is ever addressed by list/index across the round trip, only by serial.
function hashimon_magi.find_stack(player, serial)
	local inv = player:get_inventory()
	for listname, list in pairs(inv:get_lists()) do
		for index, stack in ipairs(list) do
			if stack:get_name() == hashimon_magi.NOTE then
				local token = hashimon_magi.token_from_stack(stack)
				if token and token.serial == serial then
					return inv, listname, index, stack
				end
			end
		end
	end
	return nil
end

--- Every MAGI a player is carrying, as { token = ..., serial = ... } entries.
function hashimon_magi.carried(player)
	local out = {}
	local inv = player:get_inventory()
	local blanks = {}
	for listname, list in pairs(inv:get_lists()) do
		for index, stack in ipairs(list) do
			if stack:get_name() == hashimon_magi.NOTE then
				local token = hashimon_magi.token_from_stack(stack)
				if token then
					out[#out + 1] = token
				else
					blanks[#blanks + 1] = { listname = listname, index = index }
				end
			end
		end
	end
	return out, blanks
end

core.register_node(hashimon_magi.NOTE, {
	description = "MAGI",
	short_description = "MAGI",
	tiles = {
		"hashimon_magi_cube_top.png",
		"hashimon_magi_cube_top.png",
		"hashimon_magi_cube_side.png",
	},
	drawtype = "normal",
	paramtype = "light",
	light_source = 5,
	is_ground_content = false,
	-- One MAGI per stack, always. Stacking would merge two ItemStacks into one set
	-- of metadata and silently erase a serial — the item is a discrete object, and
	-- the engine has to treat it as one.
	stack_max = 1,
	groups = { cracky = 3, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1 },
	sounds = {},

	-- Carried -> placed. The token moves to node meta; the custody check that follows
	-- writes the rotated nonce straight back to the node.
	after_place_node = function(pos, placer, itemstack)
		local token = hashimon_magi.token_from_stack(itemstack)
		local meta = core.get_meta(pos)
		if not token then
			meta:set_string("infotext", "MAGI (blank — not in the ledger)")
			return
		end
		write_meta(meta, token, true)
		meta:set_string("infotext", "MAGI #" .. token.serial:sub(1, 8))
		if placer and placer:is_player() then
			hashimon_magi.check_placed(pos, placer:get_player_name())
		end
	end,

	-- Placed -> carried. Without this the node would drop a blank cube and the MAGI
	-- would be destroyed by its own owner digging it up.
	preserve_metadata = function(_pos, _oldnode, oldmeta, drops)
		local drop = drops[1]
		if not drop or drop:get_name() ~= hashimon_magi.NOTE then
			return
		end
		local token = {}
		for _, name in ipairs(FIELDS) do
			token[name] = oldmeta[fkey(name)] or ""
		end
		if token.serial == "" then
			return
		end
		token.sats = tonumber(token.sats) or 0
		token.epoch = tonumber(token.epoch) or 0
		hashimon_magi.write_token(drop, token, true)
	end,

	-- Right-click in the air with a MAGI in hand: ask the ledger about this one note.
	-- Deliberately not `on_use` (left click), which would stop the item digging and
	-- interfere with punching creatures.
	on_secondary_use = function(itemstack, user)
		if user and user:is_player() then
			hashimon_magi.inspect(user, itemstack)
		end
		return itemstack
	end,
})
