-- A township system for Minetest servers.
-- The MIT License - 2024  Olivia May <oliviamay@tuta.com>

towny.flag_inherit(towny.block)

local bs = towny.settings.town_block_size

local has_flag = towny.has_flag
local has_any_flags = towny.has_any_flags

function towny.get_blockpos(pos)
	return vector.new(math.floor((pos.x + 0.5)/ bs),
		math.floor((pos.y + 0.5)/ bs),
		math.floor((pos.z + 0.5)/ bs))
end

function towny.get_distance(pos1, pos2)
	local pos = pos2:subtract(pos1)
	return math.sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z)
end

-- block class constructor
function towny.block.new(pos, town)

	local block = {}
	block.trusted = {}
	setmetatable(block, towny.block)

	town[#town + 1] = block
	block.index = #town

	-- + 0.5 because edges of nodes sometimes get floored to the block
	-- behind it
	block.blockpos = towny.get_blockpos(pos)
	block.pos_min = vector.new(block.blockpos.x * bs,
		block.blockpos.y * bs,
		block.blockpos.z * bs)

	block.town = town

	block.perms = town.perms

	return block
end

-- block class destructor
function towny.block:delete(array_remove)
	if array_remove == nil then
		array_remove = true
	end

	if array_remove then
		towny.array_remove(self.town, self.index)
	end
	self:set_owner(nil)
	self = nil
end

-- Visualize a block
function towny.block:visualize(player_name)

	local i
	local bs_1 = bs - 1
	local size = 10
	local expirationtime = 10

	-- corners

	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(1, 0, 0)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(0, 0, 1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(1, bs_1, 0)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(0, bs_1, 1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})

	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(bs_1 - 1, 0, 0)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(bs_1, 0, 1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(bs_1 - 1, bs_1, 0)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(bs_1, bs_1, 1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})

	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(1, 0, bs_1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(0, 0, bs_1 -1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(1, bs_1, bs_1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(0, bs_1, bs_1 - 1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})

	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(bs_1 - 1, 0, bs_1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(bs_1, 0, bs_1 -1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(bs_1 - 1, bs_1, bs_1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})
	core.add_particle({
		pos = vector.add(
			self.pos_min,
			vector.new(bs_1, bs_1, bs_1 - 1)
		),
		expirationtime = expirationtime,
		size = size,
		texture = "towny_block_visual.png",
		playername = player_name,
	})

	-- sides

	for i = 0, bs_1 do
		core.add_particle({
			pos = vector.add(
				self.pos_min,
				vector.new(0, i, 0)
			),
			expirationtime = expirationtime,
			size = size,
			texture = "towny_block_visual.png",
			playername = player_name,
		})
		core.add_particle({
			pos = vector.add(
				vector.new(self.pos_min.x + bs_1, self.pos_min.y, self.pos_min.z),
				vector.new(0, i, 0)
			),
			expirationtime = expirationtime,
			size = size,
			texture = "towny_block_visual.png",
			playername = player_name,
		})
		core.add_particle({
			pos = vector.add(
				vector.new(self.pos_min.x + bs_1, self.pos_min.y, self.pos_min.z + bs_1),
				vector.new(0, i, 0)
			),
			expirationtime = expirationtime,
			size = size,
			texture = "towny_block_visual.png",
			playername = player_name,
		})
		core.add_particle({
			pos = vector.add(
				vector.new(self.pos_min.x, self.pos_min.y, self.pos_min.z + bs_1),
				vector.new(0, i, 0)
			),
			expirationtime = expirationtime,
			size = size,
			texture = "towny_block_visual.png",
			playername = player_name,
		})
	end
end

function towny.block:add_perms(perms)
	self.perms = bit.bor(self.perms, perms)
end
function towny.block:remove_perms(perms)
	self.perms = bit.band(self.perms, bit.bnot(perms))
end

-- `resident` can be nil
function towny.block:set_owner(resident)
	if self.owner then
		self.owner:remove_plot(self)
	end
	if resident then
		self.perms = resident.perms
		resident:add_plot(self)
	else
		self.perms = self.town.perms
	end

	self.owner = resident
	local trusted = self.trusted
	for k, _ in pairs(trusted) do
		trusted[k] = nil
	end
end

-- has owner, mayor or admin access
function towny.block:has_access(resident)
	return (self.owner == resident or (self.town.members[resident.name]
		and resident:has_any_flags(towny.RESIDENT_MAYOR + towny.RESIDENT_COMAYOR))
		or core.check_player_privs(resident.name, "townyadmin"))
end

-- Test to see if a position is in a block, return block
function towny.get_block_by_pos(pos)

	local block
	local town

	for i = 1, #towny.town_array do
		town = towny.town_array[i]

		for j = 1, #town do
			block = town[j]
			-- `- 0.5` because we're checking the edge of the node
			if pos.x >= block.pos_min.x - 0.5 and
				pos.x <= block.pos_min.x + bs - 0.5 and
				pos.y >= block.pos_min.y - 0.5 and
				pos.y <= block.pos_min.y + bs - 0.5 and
				pos.z >= block.pos_min.z - 0.5 and
				pos.z <= block.pos_min.z + bs - 0.5 then

				return block
			end
		end
	end

	return nil
end

function towny.get_townblock_by_pos(pos, town)
	local block
	for i = 1, #town do
		block = town[i]
		-- `- 0.5` because we're checking the edge of the node
		if pos.x >= block.pos_min.x - 0.5 and
			pos.x <= block.pos_min.x + bs - 0.5 and
			pos.y >= block.pos_min.y - 0.5 and
			pos.y <= block.pos_min.y + bs - 0.5 and
			pos.z >= block.pos_min.z - 0.5 and
			pos.z <= block.pos_min.z + bs - 0.5 then

			return block
		end
	end

	return nil
end

-- Checks if there is a block above or below where `pos` is.
-- Returns the first found block, or nil
function towny.exists_block_at_x_z(pos)
	local i
	for i = 1, #towny.town_array do
		town = towny.town_array[i]

		for j = 1, #town do
			block = town[j]
			if pos.x >= block.pos_min.x - 0.5 and
				pos.x <= block.pos_min.x + bs - 0.5 and
				pos.z >= block.pos_min.z - 0.5 and
				pos.z <= block.pos_min.z + bs - 0.5 then

				return block
			end
		end
	end

	return nil
end

function towny.pos_borders_townblock(pos, town)
	local blockpos = towny.get_blockpos(pos)
	for j = 1, #town do
		block = town[j]
		local diff = blockpos:subtract(block.blockpos)
		if math.abs(diff.x) + math.abs(diff.y) + math.abs(diff.z) == 1 then
			return block
		end
	end

	return nil
end

function towny.neighboring_townblocks_have_flag(town, block, flag, negative)
	if not negative then
		negative = false
	end
	function n(bool)
		if negative then
			return not bool
		end
		return bool
	end

	local p = block.pos_min
	local bs = towny.settings.town_block_size
	local vnew = vector.new
	local getb = towny.get_townblock_by_pos
	local b

	b = getb(vnew(p.x + bs, p.y, p.z), town)
	if b and n(b:has_flag(flag)) then return true end
	b = getb(vnew(p.x - bs, p.y, p.z), town)
	if b and n(b:has_flag(flag)) then return true end
	b = getb(vnew(p.x, p.y + bs, p.z), town)
	if b and n(b:has_flag(flag)) then return true end
	b = getb(vnew(p.x, p.y - bs, p.z), town)
	if b and n(b:has_flag(flag)) then return true end
	b = getb(vnew(p.x, p.y, p.z + bs), town)
	if b and n(b:has_flag(flag)) then return true end
	b = getb(vnew(p.x, p.y, p.z - bs), town)
	if b and n(b:has_flag(flag)) then return true end

	return false
end

core.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	-- Copied from pvp_toggle mod
    -- Check if both player and hitter are valid and are players
    if not player or not hitter or not player:is_player() or not hitter:is_player() then
        return
    end

	local pos = towny.get_player_pos(player)
	local block = towny.get_block_by_pos(pos)

	if block and not block:has_flag(towny.BLOCK_PVP) then
		core.chat_send_player(hitter:get_player_name(), "You can't PVP here!")
		return true
	end
end)

local flags = towny.RESIDENT_MAYOR + towny.RESIDENT_COMAYOR
function towny.is_protection_violation(block, player, permtype)
	local name = player:get_player_name()
	local resident = towny.residents[name]
	local is_trusted = false
	local is_member = false
	local perm_array = towny.perm_array

	if block:has_access(resident) then
		return false
	end

	local trusted
	if next(block.trusted) then
		trusted = block.trusted
	else
		trusted = block.town.trusted
	end
	if trusted[name] then
		is_trusted = true
		if has_flag(block.perms, perm_array[towny.PERM_GROUP_TRUSTED][permtype]) then
			return false
		end
	end

	if block.town.members[name] then
		is_member = true
		if has_flag(block.perms, perm_array[towny.PERM_GROUP_RESIDENT][permtype]) then
			return false
		end
	end

	-- TODO: more groups
	if not (is_trusted or is_member) then
		if has_flag(block.perms, perm_array[towny.PERM_GROUP_OUTSIDER][permtype]) then
			return false
		end
	end

	return true
end

local is_violation = towny.is_protection_violation

-- copied from builtin/game/item.lua, luanti 5.11.0
-- Returns a logging function. For empty names, does not log.
local function make_log(name)
	return name ~= "" and core.log or function() end
end

local function log_violation(name, node_name, pos, typename)
	local log = make_log(name)
	log("action", name .. " tried to " .. typename .. " " .. node_name
		.. " without towny permission at position " .. pos:to_string())
	core.chat_send_player(name, "You can't " .. typename .. " here!")
end

-- register_on_mods_loaded
local townyfunc = function()
	for itemname, itemdef in pairs(core.registered_items) do
	local skip_food = false
	if itemdef.groups then
		for gname, _ in pairs(itemdef.groups) do
			if string.find(gname, "^food") then
				skip_food = true
				break
			end
		end
	end
	if skip_food then
		-- food items are exempt from towny placement hooks
	else
	local old_on_place = itemdef.on_place
	local old_on_dig = itemdef.on_dig
	local old_on_rightclick = itemdef.on_rightclick
	local old_on_punch = itemdef.on_punch
	local old_allow_metadata_inventory_move = itemdef.allow_metadata_inventory_move
	local old_allow_metadata_inventory_put = itemdef.allow_metadata_inventory_put
	local old_allow_metadata_inventory_take = itemdef.allow_metadata_inventory_take
	local old_on_use = itemdef.on_use
	-- this function seems to be rarely defined to do something
	local old_on_secondary_use = itemdef.on_secondary_use

	local override = {}

	local place_type = 0
	local place_typename = ""

	local is_node = itemdef.drawtype

	-- if item is node
	if is_node then
		place_type = towny.PERM_TYPE_PLACE
		place_typename = "place"
	-- if item is tool
	else
		place_type = towny.PERM_TYPE_USE
		place_typename = "use"
	end

	if old_on_place then
	override.on_place = function(itemstack, placer, pointed_thing)
		if placer then
		if pointed_thing.type == "node" then
		local pos = core.get_pointed_thing_position(pointed_thing, true)
		local block = towny.get_block_by_pos(pos)
		if block then
			if is_violation(block, placer, place_type) then

			-- copied from builtin/game/item.lua, luanti 5.11.0
			-- Call on_rightclick if the pointed node defines it
			if pointed_thing.type == "node" and placer and
					not placer:get_player_control().sneak then
				local n = core.get_node(pointed_thing.under)
				local nn = n.name
				if core.registered_nodes[nn] and core.registered_nodes[nn].on_rightclick then
					return core.registered_nodes[nn].on_rightclick(pointed_thing.under, n,
							placer, itemstack, pointed_thing) or itemstack, nil
				end
			end

			log_violation(placer:get_player_name(),
				itemstack:get_definition().name, pos, place_typename)
			return nil
			end
		end
		end
		end

		return old_on_place(itemstack, placer, pointed_thing)
	end
	end

	if old_on_dig then
	override.on_dig = function(pos, node, digger)
		if digger then
		local block = towny.get_block_by_pos(pos)
		if block then
			if is_violation(block, digger, towny.PERM_TYPE_DIG) then
				log_violation(digger:get_player_name(),
					node.name, pos, "dig")
				return false
			end
		end
		end

		return old_on_dig(pos, node, digger)
	end
	end

	if old_on_rightclick then
	override.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if clicker then
		-- pointed_thing can be nil according to api?
		if pointed_thing ~= nil and pointed_thing.type == "node" then

		local block = towny.get_block_by_pos(pos)
		if block then
			if is_violation(block, clicker, towny.PERM_TYPE_SWITCH) then
				log_violation(clicker:get_player_name(),
					node.name, pos, "switch")
				return nil
			end
		end
		end
		end

		return old_on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	end
	end

	if old_on_punch then
	override.on_punch = function(pos, node, puncher, pointed_thing)
		if puncher then
		-- pointed_thing can be nil according to api?
		if pointed_thing ~= nil and pointed_thing.type == "node" then

		local block = towny.get_block_by_pos(pos)
		if block then
			if is_violation(block, puncher, towny.PERM_TYPE_SWITCH) then
				log_violation(puncher:get_player_name(),
					node.name, pos, "switch")
				return nil
			end
		end
		end
		end

		return old_on_punch(pos, node, puncher, pointed_thing)
	end
	end

	if old_allow_metadata_inventory_move then
		override.allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
			if player then
			local node = core.get_node(pos)
			local block = towny.get_block_by_pos(pos)
			if block then
				if is_violation(block, player, towny.PERM_TYPE_SWITCH) then
					log_violation(player:get_player_name(),
						node.name, pos, "switch")
					return 0
				end
			end
			end

			return old_allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
		end
	end
	if old_allow_metadata_inventory_put then
		override.allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if player then
			local node = core.get_node(pos)
			local block = towny.get_block_by_pos(pos)
			if block then
				if is_violation(block, player, towny.PERM_TYPE_SWITCH) then
					log_violation(player:get_player_name(),
						node.name, pos, "switch")
					return 0
				end
			end
			end

			return old_allow_metadata_inventory_put(pos, listname, index, stack, player)
		end
	end
	if old_allow_metadata_inventory_take then
		override.allow_metadata_inventory_take = function(pos, listname, index, stack, player)
			if player then
			local node = core.get_node(pos)
			local block = towny.get_block_by_pos(pos)
			if block then
				if is_violation(block, player, towny.PERM_TYPE_SWITCH) then
					log_violation(player:get_player_name(),
						node.name, pos, "switch")
					return 0
				end
			end
			end

			return old_allow_metadata_inventory_take(pos, listname, index, stack, player)
		end
	end

	if old_on_use then
	override.on_use = function(itemstack, user, pointed_thing)
		if user then
		if pointed_thing.type == "node" then
		local pos = core.get_pointed_thing_position(pointed_thing, false)
		local block = towny.get_block_by_pos(pos)
		if block then
			if is_violation(block, user, towny.PERM_TYPE_USE) then
				log_violation(user:get_player_name(),
					itemstack:get_definition().name, pos, "use")
				return nil
			end
		end
		end
		end

		return old_on_use(itemstack, user, pointed_thing)
	end
	end
	if old_on_secondary_use then
	override.on_secondary_use = function(itemstack, user, pointed_thing)
		if user then
		if pointed_thing.type == "node" then
		local pos = core.get_pointed_thing_position(pointed_thing, false)
		local block = towny.get_block_by_pos(pos)
		if block then
			if is_violation(block, user, towny.PERM_TYPE_USE) then
				log_violation(user:get_player_name(),
					itemstack:get_definition().name, pos, "use")
				return nil
			end
		end
		end
		end

		return old_on_secondary_use(itemstack, user, pointed_thing)
	end
	end

	if is_node then
		local old_on_blast = itemdef.on_blast
		local return_func
		if old_on_blast then
			return_func = old_on_blast
		else
			return_func = function(pos, intensity)
				core.remove_node(pos)
				return core.get_node_drops(itemdef.name, "")
			end
		end
		override.on_blast = function(pos, intensity)
			local block = towny.get_block_by_pos(pos)
			if block then
				if not block:has_flag(towny.BLOCK_EXPLOSIONS) then
					return nil
				end
			end

			return return_func(pos, intensity)
		end
	end

	core.override_item(itemname, override)

	end -- not skip_food
	end

	-- entities only take damage in pvp blocks, or if the puncher has access to
	-- the block
	for entityname, entitydef in pairs(core.registered_entities) do
		if entityname ~= "__builtin:item" then
		local old_on_punch = entitydef.on_punch

		if old_on_punch then
			entitydef.on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
				local block = towny.get_block_by_pos(self.object:get_pos())
				if block and puncher and puncher:is_player() then
					local res = towny.residents[puncher:get_player_name()]

					if not block:has_access(res) then
						if not block:has_flag(towny.BLOCK_PVP) then
							core.chat_send_player(res.name, "You can't PVE here!")
							return true
						end
					end
				end

				return old_on_punch(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
			end
		end

		end -- entityname ~= __builtin:item
	end

	local abms = core.registered_abms
	for i = 1, #abms do
		local abmdef = abms[i]
		if abmdef.label == "Ignite flame" then
			abmdef.action = function(pos)
				local p = core.find_node_near(pos, 1, {"air"})
				if not p then return end
				local block = towny.get_block_by_pos(p)
				if block and not block:has_flag(towny.BLOCK_FIRESPREAD) then
					return
				end

				core.set_node(p, {name = "fire:basic_flame"})
			end
		end
		if abmdef.label == "Remove flammable nodes" then
			abmdef.action = function(pos)
				local p = core.find_node_near(pos, 1, {"group:flammable"})
				if not p then return end
				local block = towny.get_block_by_pos(p)
				if block and not block:has_flag(towny.BLOCK_FIRESPREAD) then
					return
				end

				-- copied from mod `fire` init.lua
				local flammable_node = core.get_node(p)
				local def = core.registered_nodes[flammable_node.name]
				if def.on_burn then
					def.on_burn(p)
				else
					core.remove_node(p)
					core.check_for_falling(p)
				end
			end
		end
		if abmdef.label and string.find(abmdef.label, " spawning") then
			local old_action = abmdef.action
			abmdef.action = function(pos)
				local block = towny.get_block_by_pos(pos)
				if block and not block:has_flag(towny.BLOCK_MOBSPAWNS) then
					return
				end

				old_action(pos)
			end
		end
	end
end

-- load towny's func before tnt mod
table.insert(core.registered_on_mods_loaded, 1, townyfunc)
