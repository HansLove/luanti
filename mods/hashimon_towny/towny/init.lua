-- A township system for Minetest servers.
-- The MIT License - 2019  Evert "Diamond" Prants <evert@lunasqu.ee>
-- The MIT License - 2024  Olivia May <oliviamay@tuta.com>

-- TODO: Economy

-- `towny` namespace
towny = {
	modpath = core.get_modpath(core.get_current_modname()),

	-- settings

	-- min distance in mapblocks from homeblock (16x16x16 nodes)
	settings = {
		town_distance = tonumber(core.settings:get('towny_distance')) or 8,
		-- must be invited to towns / nations
		town_default_open = core.settings:get_bool('towny_town_default_open', false),
		vertical_towns =
			core.settings:get_bool('towny_vertical_towns', false),
		autosave_interval =
			tonumber(core.settings:get(
			'towny_autosave_interval')) or 30,
		town_block_size = tonumber(core.settings:get('towny_town_block_size')) or 16,
		tick = tonumber(core.settings:get('towny_tick')) or 0.5,
		max_townblocks = tonumber(core.settings:get('towny_max_townblocks')) or 64,
		max_townblocks_high = tonumber(core.settings:get('towny_max_townblocks_high')) or 1024,
		max_outposts = tonumber(core.settings:get('towny_max_outposts')) or 1,
	},

	-- permission bit flags
	-- groups are who can do things in a towny block,
	-- types are what they can do
	-- bit flags are assigned later

	-- [group id, ex: `1`] = group name, ex: `"trusted"`
	registered_groups = {},
	-- [type id, ex: `1`] = type name, ex: `"place"`
	registered_types = {},
	-- 2 dimensional array that stores perms.
	-- perm_array[group id][type id] = permission bit flag
	perm_array = {},

	all_group_perms_array = {},
	all_type_perms_array = {},

	-- all perms bit flags, initialized later
	ALL_PERMS = 0,

	-- bit flags, key = name, value = flag
	registered_resident_flags = {},
	registered_block_flags = {},
	registered_town_flags = {},

	-- claimblock class, always owned by a town. blocks
	-- can only belong to 1 town. they can be unowned, but can only have 1
	-- owner
	block = {
		perms = 0, -- stores perm bit flags
		index = 0, -- index in town's `block_array`
		name = "",
		town = nil, -- town, pointer to owner town
		blockpos = {}, -- vector, block position
		pos_min = {}, -- vector, min pos
		owner = nil, -- resident who owns the block. all blocks start unowned
		trusted = {}, -- key = resident name, value = resident
		flags = 0, -- flags bit mask
	},

	-- TODO: nations (in separate mod)

	-- Town class, can be nationless, can only belong to 1 nation
	town = {
		-- [1] [2] [3]... block array, towns keep track of blocks
		index = 0, -- index in `towny.town_array`
		name = "",
		members = {}, -- resident table, key = name
		pos = {}, -- vector, for spawning (teleporting)
		look_vertical = 0, -- for spawning
		look_horizontal = 0,
		trusted = {}, -- key = resident name, value = resident
		perms = 0, -- default perms for new blocks
		invites = {}, -- resident, invites to towns
		flags = 0, -- flags bit mask
		homeblock = nil -- block, town homeblock
	},

	-- resident class, can be townless, residents can only belong to 1
	-- town and only 1 nation, but can own multiple blocks
	resident = {
		-- [1] [2] [3]... plot array, array of owned blocks
		nickname = "", -- changeable name
		name = "", -- luanti name ex. 'singleplayer'
		town = nil, -- town, resident town
		flags = 0, -- resident flags, ex: mayor
		perms = 0, -- resident default perms when given a plot
	},

	-- array of all current towns
	town_array = {},
	-- key = resident name, value = data
	residents = {},

	storage = core.get_mod_storage(),

	-- `true` if data is modified and should be saved to drive
	dirty = false,
}

towny.block.__index = towny.block
towny.town.__index = towny.town
towny.resident.__index = towny.resident

-- i = key order, [i] = key
towny.registered_resident_flags._order = {}
towny.registered_block_flags._order = {}
towny.registered_town_flags._order = {}

function towny.array_remove(array, index)
	table.remove(array, index)
	local i
	for i = index, #array do
		array[i].index = array[i].index - 1
	end
end

-- use the players head, not their feet.
function towny.get_player_pos(player)
	local luanti_pos = player:get_pos()
	local pos = luanti_pos:copy()
        pos.y = pos.y + 1.5
        return pos
end

-- flag helper functions

function towny.has_flag(bit_mask, flag)
	return bit.band(bit_mask, flag) == flag
end
function towny.has_any_flags(bit_mask, flags)
	return bit.band(bit_mask, flags) > 0
end

local function add_flag(self, flag)
	self.flags = bit.bor(self.flags, flag)
end
local function remove_flag(self, flag)
	self.flags = bit.band(self.flags, bit.bnot(flag))
end
local function toggle_flag(self, flag)
	self.flags = bit.bxor(self.flags, flag)
end
local function has_flag(self, flag)
	return towny.has_flag(self.flags, flag)
end
local function has_any_flags(self, flags)
	return towny.has_any_flags(self.flags, flags)
end

-- inherit flag functions for a class `class`
function towny.flag_inherit(class)
	class.add_flag = add_flag
	class.remove_flag = remove_flag
	class.toggle_flag = toggle_flag
	class.has_flag = has_flag
	class.has_any_flags = has_any_flags
end


local perm_def = {NAME = "", name = ""}
local rts = towny.registered_types
local rgs = towny.registered_groups

local function add_type(name)
	rts[#rts + 1] = name
end
local function add_group(name)
	rgs[#rgs + 1] = name
end

towny.flag_values = {}
local fv = towny.flag_values

-- hidden: bool,
-- if this flag gets registered in towny.registered_*class*_flags
function towny.register_flag(class, name, hidden)
	if not fv[class] then
		fv[class] = 1
	end
	local value = fv[class]

	if not hidden then
		local rcfs = towny[table.concat({"registered_", class, "_flags"})]
		rcfs[name] = value
		rcfs._order[#rcfs._order + 1] = name
	end

	fv[class] = bit.lshift(fv[class], 1)
	towny[table.concat({class:upper(), "_", name:upper()})] = value
end

-- Order for groups and flags must be maintained for backwards compatibility

add_group("trusted")
add_group("resident")
-- these do nothing right now
add_group("nation")
add_group("ally")
--
add_group("outsider")

add_type("place")
add_type("dig")
add_type("switch")
add_type("use")
add_type("buy")

towny.register_flag("resident", "mayor", true)
towny.register_flag("resident", "comayor")
towny.register_flag("resident", "online", true)

towny.register_flag("block", "homeblock", true)
towny.register_flag("block", "forsale", true)
towny.register_flag("block", "explosions")
towny.register_flag("block", "pvp")
towny.register_flag("block", "outpost", true)
towny.register_flag("block", "firespread")
towny.register_flag("block", "mobspawns")

towny.register_flag("town", "open")
towny.register_flag("town", "explosions")
towny.register_flag("town", "pvp")
towny.register_flag("town", "firespread")
towny.register_flag("town", "mobspawns")

-- initialize groups and types
local bit_flag = 1
local perm_array = towny.perm_array
local i
local j
local all_perms = 0
local agpa = towny.all_group_perms_array
local atpa = towny.all_type_perms_array

for i = 1, #rgs do
	agpa[i] = 0
end
for i = 1, #rts do
	atpa[i] = 0
end

for i = 1, #rgs do
	perm_array[i] = {}

	towny["PERM_GROUP_" .. rgs[i]:upper()] = i

	for j = 1, #rts do
		towny["PERM_TYPE_" .. rts[j]:upper()] = j

		perm_array[i][j] = bit_flag
		all_perms = all_perms + bit_flag
		agpa[i] = agpa[i] + bit_flag
		atpa[j] = atpa[j] + bit_flag

		bit_flag = bit.lshift(bit_flag, 1)
	end
end
towny.ALL_PERMS = all_perms

towny.default_perms =
	towny.all_group_perms_array[towny.PERM_GROUP_TRUSTED] +
	towny.all_group_perms_array[towny.PERM_GROUP_RESIDENT]

towny.resident_default_perms =
	towny.all_group_perms_array[towny.PERM_GROUP_TRUSTED]

dofile(towny.modpath .. "/storage.lua")
dofile(towny.modpath .. "/resident.lua")
dofile(towny.modpath .. "/block.lua")
dofile(towny.modpath .. "/town.lua")
dofile(towny.modpath .. "/commands.lua")
dofile(towny.modpath .. "/hud.lua")

