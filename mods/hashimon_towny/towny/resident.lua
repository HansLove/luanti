-- A township system for Minetest servers.
-- The MIT License - 2024  Olivia May <oliviamay@tuta.com>

towny.flag_inherit(towny.resident)

-- resident class constructor
function towny.resident.new(name)

	local resident = {}
	setmetatable(resident, towny.resident)
	towny.resident.__index = towny.resident

	resident.name = name
	resident.nickname = "" -- can be changed later by player
	resident.flags = 0
	resident.perms = towny.resident_default_perms

	towny.residents[resident.name] = resident

	return resident
end

function towny.resident:delete()
	towny.residents[self.name] = nil
	local i
	for i = 1, #self do
		self[i]:set_owner(nil)
	end
	if self.town then
		if self:has_flag(towny.RESIDENT_MAYOR) then
			-- TODO: give mayorship to another member instead of deleting the town
			self.town:delete()
		else
			self.town:remove_resident(self)
		end
	end

	self = nil
end

-- get name to be displayed in town screen, etc.
function towny.resident:get_display_name()
	if self.nickname:len() > 0 then
		local name = {}
		name[#name + 1] = self.nickname
		name[#name + 1] = " ("
		name[#name + 1] = self.name
		name[#name + 1] = ")"

		return table.concat(name)
	else
		return self.name
	end
end

function towny.resident:add_plot(block)
	self[#self + 1] = block
end
function towny.resident:remove_plot(block)
	local i
	for i = 1, #self do
		if self[i] == block then
			table.remove(self, i)
			break;
		end
	end
end

function towny.resident:add_perms(perms)
	self.perms = bit.bor(self.perms, perms)
	local i
	for i = 1, #self do
		self[i]:add_perms(perms)
	end
end
function towny.resident:remove_perms(perms)
	self.perms = bit.band(self.perms, bit.bnot(perms))
	local i
	for i = 1, #self do
		self[i]:remove_perms(perms)
	end
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local res = towny.residents[name]
	if not res then
		res = towny.resident.new(name)
	end
	res:add_flag(towny.RESIDENT_ONLINE)

	local i
	local ta = towny.town_array
	for i = 1, #ta do
		if ta[i].invites[res.name] then
			core.chat_send_player(res.name, "You have town invites! Type '/resident invite list'.")
			break
		end
	end
end)
core.register_on_leaveplayer(function(player)
	local res = towny.residents[player:get_player_name()]
	if res then
		res:remove_flag(towny.RESIDENT_ONLINE)
	end
end)
core.register_on_mods_loaded(function ()
	for _, res in pairs(towny.residents) do
		res:remove_flag(towny.RESIDENT_ONLINE)
	end
end)

