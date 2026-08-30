-- A township system for Minetest servers.
-- The MIT License - 2024  Olivia May <oliviamay@tuta.com>

towny.flag_inherit(towny.town)

-- town class constructor
function towny.town.new(res, town_name, player)

	if not player then
		player = core.get_player_by_name(res.name)
	end
	local luanti_player_pos = player:get_pos()
	local towny_player_pos = towny.get_player_pos(player)

	-- 16 is mapblock size, round down player_pos to nearest multiple of 16 and
	-- -0.5 to align to mapblock boundary

	local town = {}
	town.members = {}
	town.trusted = {}
	town.invites = {}
	setmetatable(town, towny.town)

	town.perms = towny.default_perms

	if towny.settings.town_default_open then
		town.flags = towny.TOWN_OPEN
	else
		town.flags = 0
	end

	local town_array = towny.town_array
	town_array[#town_array + 1] = town
	town.index = #town_array

	local block = towny.block.new(towny_player_pos, town)
	block.flags = bit.bor(block.flags, towny.BLOCK_HOMEBLOCK)
	town.homeblock = block

	-- teleport pos
	town.pos = luanti_player_pos:copy()
	town.look_vertical = player:get_look_vertical()
	town.look_horizontal = player:get_look_horizontal()
	town.name = town_name

	town:add_resident(res)
	res.flags = bit.bor(res.flags, towny.RESIDENT_MAYOR)

	town:visualize(player:get_player_name())

	return town
end

function towny.town:add_resident(resident)
	self.members[resident.name] = resident
	resident.town = self
	local i
	local ta = towny.town_array
	for i = 1, #ta do
		ta[i].invites[resident.name] = nil
	end
end
function towny.town:remove_resident(resident)
	self.members[resident.name] = nil
	resident.town = nil
	resident:remove_flag(bit.bnot(towny.RESIDENT_ONLINE))
end

function towny.town:delete()
	towny.array_remove(towny.town_array, self.index)
	for _, res in pairs(self.members) do
		self:remove_resident(res)
	end
	local i
	for i = 1, #self do
		self[i]:delete(false)
	end
	self = nil
end

function towny.town:visualize(player_name)
	for i = 1, #self do
		self[i]:visualize(player_name)
	end
end

function towny.town:add_perms(perms)
	self.perms = bit.bor(self.perms, perms)
	for i = 1, #self do
		local block = self[i]
		if not block.owner then
			block:add_perms(perms)
		end
	end
end
function towny.town:remove_perms(perms)
	self.perms = bit.band(self.perms, bit.bnot(perms))
	for i = 1, #self do
		local block = self[i]
		if not block.owner then
			block:remove_perms(perms)
		end
	end
end

function towny.get_town_by_name(name)
	local town
	for i = 1, #towny.town_array do
		town = towny.town_array[i]
		if town.name == name then
			return town
		end
	end

	return nil
end

