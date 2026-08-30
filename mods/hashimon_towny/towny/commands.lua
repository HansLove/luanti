-- A township system for Minetest servers.
-- The MIT License - 2019  Evert "Diamond" Prants <evert@lunasqu.ee>
-- The MIT License - 2024  Olivia May <oliviamay@tuta.com>

-- Privileges

core.register_privilege("towny", {
	description = "Has access to towny mod features.",
})

core.register_privilege("townyadmin", {
	description = "Can administrate other people's towns",
	give_to_singleplayer = false,
	give_to_admin = true,
})

core.register_privilege("towny_blocks_high_limit", {
	description = "Can have even bigger towns.",
	give_to_singleplayer = true,
	give_to_admin = false,
})

core.register_privilege("towny_blocks_no_limit", {
	description = "Can have unlimited sized towns.",
	give_to_singleplayer = false,
})

local has_flag = towny.has_flag
local has_any_flags = towny.has_any_flags

-- get array of parameter strings `pa`
local function get_param_array(str)
	local pa = {}
	local index
	local i = 1

	while true do
		-- find index of ' ' space character, stop when no match
		index = string.find(str, ' ', i, true)
		if index then
			pa[#pa + 1] = string.sub(str, i, index - 1)
			i = index + 1
		else
			pa[#pa + 1] = string.sub(str, i)
			break
		end
	end

	return pa
end

local function process_group(group_id, pa, obj)
	local group = towny.perm_array[group_id]
	local rts = towny.registered_types
	local all_group_perms = towny.all_group_perms_array[group_id]

	if pa[4] == "on" then
		obj:add_perms(all_group_perms)
		return true
	end
	if pa[4] == "off" then
		obj:remove_perms(all_group_perms)
		return true
	end

	for i = 1, #rts do
		if pa[4] == rts[i] then
			if pa[5] == "on" then
				obj:add_perms(group[i])
				return true
			end
			if pa[5] == "off" then
				obj:remove_perms(group[i])
				return true
			end
		end
	end

	return false
end

local function process_type(type_id, pa, obj)
	local perm_array = towny.perm_array
	local rgs = towny.registered_groups
	local all_type_perms = towny.all_type_perms_array[type_id]

	if pa[4] == "on" then
		obj:add_perms(all_type_perms)
		return true
	end
	if pa[4] == "off" then
		obj:remove_perms(all_type_perms)
		return true
	end

	for i = 1, #rgs do
		if pa[4] == rgs[i] then
			if pa[5] == "on" then
				obj:add_perms(perm_array[i][type_id])
				return true
			end
			if pa[5] == "off" then
				obj:remove_perms(perm_array[i][type_id])
				return true
			end
		end
	end

	return false
end

local function process_perms(pa, obj)
	local rgs = towny.registered_groups
	local rts = towny.registered_types

	if pa[3] == "on" then
		obj:add_perms(towny.ALL_PERMS)
		return true
	end
	if pa[3] == "off" then
		obj:remove_perms(towny.ALL_PERMS)
		return true
	end

	local i
	for i = 1, #rgs do
		if pa[3] == rgs[i] then
			if process_group(i, pa, obj) then
				return true
			end
		end
	end
	for i = 1, #rts do
		if pa[3] == rts[i] then
			if process_type(i, pa, obj) then
				return true
			end
		end
	end

	return false
end

local function first_to_upper(str)
    return (str:gsub("^%l", string.upper))
end

local function create_perms_str(perms)
	local str = {}

	for i = 1, #towny.registered_types do
		str[#str + 1] = first_to_upper(towny.registered_types[i])
		-- imitate tabs
		for k = 1, 16 - towny.registered_types[i]:len() do
			str[#str + 1] = " "
		end
		for j = 1, #towny.registered_groups do
			if has_flag(perms, towny.perm_array[j][i]) then
				str[#str + 1] = towny.registered_groups[j]:sub(1, 1)
			else
				str[#str + 1] = "-"
			end
		end
		str[#str + 1] = "\n"
	end
	return table.concat(str)
end

local function create_flags_str(registered_flags, obj)
	local str = {}
	local i
	for i = 1, #registered_flags._order do
		fname = registered_flags._order[i]
		fvalue = registered_flags[fname]
		local flag_str = {}
		flag_str[#flag_str + 1] = first_to_upper(fname)
		flag_str[#flag_str + 1] = ": "
		if has_flag(obj.flags, fvalue) then
			flag_str[#flag_str + 1] = "true"
		else
			flag_str[#flag_str + 1] = "false"
		end
		str[#str + 1] = table.concat(flag_str)
	end

	return table.concat(str, ", ")
end

local function create_town_info_str(town)
	local str = {}

	local mayor_str = ""
	local mayor_name = ""
	local comayors_str = {}
	local members_str = {}
	local trusted_str = {}

	str[#str + 1] = "-- Town --\n\n"
	str[#str + 1] = town.name
	str[#str + 1] = "\n"

	str[#str + 1] = create_flags_str(towny.registered_town_flags, town)
	str[#str + 1] = "\n"

	for _, res in pairs(town.members) do
		local display_name = res:get_display_name()
		mayor_name = res.name
		members_str[#members_str + 1] = display_name

		if has_flag(res.flags, towny.RESIDENT_MAYOR) then
			mayor_str = display_name
		end
		if has_flag(res.flags, towny.RESIDENT_COMAYOR) then
			comayors_str[#comayors_str + 1] = display_name
		end
	end

	for name, _ in pairs(town.trusted) do
		trusted_str[#trusted_str + 1] = name
	end

	str[#str + 1] = "Mayor: "
	str[#str + 1] = mayor_str
	str[#str + 1] = "\n"
	str[#str + 1] = "Comayor(s): ["
	str[#str + 1] = table.concat(comayors_str, " ")
	str[#str + 1] = "]\n"
	str[#str + 1] = "Location: "
	str[#str + 1] = town.pos:to_string()
	str[#str + 1] = "\n"
	str[#str + 1] = "Members: ["
	str[#str + 1] = table.concat(members_str, " ")
	str[#str + 1] = "]\n"
	str[#str + 1] = "Trusted: ["
	str[#str + 1] = table.concat(trusted_str, " ")
	str[#str + 1] = "]\n"
	str[#str + 1] = "Claimblocks: "
	str[#str + 1] = #town
	str[#str + 1] = "/"
	if core.check_player_privs(mayor_name, "towny_blocks_no_limit") then
		str[#str + 1] = "∞"
	elseif core.check_player_privs(mayor_name, "towny_blocks_high_limit") then
		str[#str + 1] = towny.settings.max_townblocks_high
	else
		str[#str + 1] = towny.settings.max_townblocks
	end
	str[#str + 1] = "\n"
	str[#str + 1] = "Outposts: "
	local outpost_count = 0
	for i = 1, #town do
		if town[i]:has_flag(towny.BLOCK_OUTPOST) then
			outpost_count = outpost_count + 1
		end
	end
	str[#str + 1] = outpost_count
	str[#str + 1] = "/"
	if core.check_player_privs(mayor_name, "towny_blocks_no_limit") then
		str[#str + 1] = "∞"
	else
		str[#str + 1] = towny.settings.max_outposts
	end
	str[#str + 1] = "\n"

	return table.concat(str)
end

local function create_resident_info_str(resident)
	local str = {}

	str[#str + 1] = "-- Resident --\n\n"
	if resident:has_flag(towny.RESIDENT_ONLINE) then
		str[#str + 1] = "(online) "
	end
	str[#str + 1] = resident:get_display_name()
	str[#str + 1] = "\n"
	str[#str + 1] = "Name: "
	str[#str + 1] = resident.name
	str[#str + 1] = "\n"
	if resident.nickname ~= "" then
		str[#str + 1] = "Nickname: "
		str[#str + 1] = resident.nickname
		str[#str + 1] = "\n"
	end
	str[#str + 1] = "Town: "
	if resident.town then
		str[#str + 1] = resident.town.name
	else
		str[#str + 1] = "(none)"
	end
	str[#str + 1] = "\n"
	str[#str + 1] = "Plots: "
	str[#str + 1] = #resident
	str[#str + 1] = "\n"

	return table.concat(str)
end

local function is_invalid_input(str)
	if str:len() > 64 then
		return true
	end

	return false
end

function towny.chat_send_town(town, message)
	for name, _ in pairs(town.members) do
		core.chat_send_player(name, message)
	end
end

local function get_registered_names_params_str(registered_names)
	local str = {}
	local i
	for i = 1, #registered_names do
		str[#str + 1] = registered_names[i]
	end

	return table.concat(str, " | ")
end

local perm_params_str = nil
local function get_perm_params_str()
	if not perm_params_str then
		local types_params_str = get_registered_names_params_str(towny.registered_types)
		local groups_params_str = get_registered_names_params_str(towny.registered_groups)
		perm_params_str = table.concat({"(on | off) | ((",
				types_params_str,
				" (on | off) | (",
				groups_params_str,
				" on | off)) | ((",
				groups_params_str,
				" (on | off) | (",
				types_params_str,
				" on | off))"})
	end

	return perm_params_str
end

local function get_registered_flags_params_str(registered_names)
	local str = {}
	local name
	local i
	for i = 1, #registered_names._order do
		str[#str + 1] = registered_names._order[i]
	end

	return table.concat(str, " | ")
end

-- Commands

core.register_chatcommand("townyadmin", {
	params = "[delete || unclaim || (town (new <town_name>) | (<town name> delete | spawn | (rename <town name>) | (claim above | below | outpost) (set (perm <perms>) | spawn | homeblock) | (toggle "
	.. get_registered_flags_params_str(towny.registered_town_flags) ..
	"))) || (plot (set (perm <perms>)) | (toggle "
	.. get_registered_flags_params_str(towny.registered_block_flags) ..
	")) || (resident <name> delete)]",
	description = "Advanced settings for towny admins.",
	privs = {townyadmin = true},
	func =

function (player_name, params)

	towny.dirty = true

	local player = core.get_player_by_name(player_name)
	if not player then return false, "Can't run command on behalf of offline player." end

	local player_pos = towny.get_player_pos(player)

	local pa = get_param_array(params)

	if pa[1]:len() == 0 then
		-- TODO: more towny info
		local str = {}
		str[#str + 1] = "Lua memory usage: "
		str[#str + 1] = collectgarbage("count")
		str[#str + 1] = "kb"
		return true, table.concat(str)

	elseif pa[1] == "delete" then

		-- 'delete I WANT TO DELETE ALL TOWNY DATA' is 8 words
		if #pa > 7 then
			if pa[2] == "I" and
				pa[3] == "WANT" and
				pa[4] == "TO" and
				pa[5] == "DELETE" and
				pa[6] == "ALL" and
				pa[7] == "TOWNY" and
				pa[8] == "DATA" then

				towny.delete_all_data()
				return true, "Deleted all towny data..."
			end
		end

		return false, "WARNING: This will PERMANENTLY DELETE ALL TOWNY DATA for this server! The data would be wiped and the server would shut down. Please run this command again with 'I WANT TO DELETE ALL TOWNY DATA' without the ' quotes in all caps typed after it."

	elseif pa[1] == "town" then
		if pa[2] then
			if pa[2] == "new" then
				if towny.get_block_by_pos(player_pos) then

					return false, "There's already a town here!"
				end

				if is_invalid_input(pa[3]) then
					return false, "Invalid name."
				end

				if towny.get_town_by_name(pa[3]) then
					return false, table.concat({"There's already a town named '", pa[2], "'."})
				end

				if not towny.settings.vertical_towns then
					local block = towny.exists_block_at_x_z(player_pos)
					if block then
						if resident.town ~= block.town then
							return false, "There is already a town above or below here."
						end
					end
				end

				local res = towny.residents["townyadmin"]
				if not res then
					res = towny.resident.new("townyadmin")
				end

				towny.town.new(res, pa[3], player)

				return true, "Town successfully founded."
			end

			local town = towny.get_town_by_name(pa[2])
			if not town then
				return false, table.concat({"There is no town named '", pa[2], "'."})
			end

			if pa[3] == "delete" then
				town:delete()
				return true, "Town deleted."

			elseif pa[3] == "rename" then
				if not pa[4] then
					return false, "Name cannot be blank."
				end

				if is_invalid_input(pa[4]) then
					return false, "Invalid name."
				end

				if towny.get_town_by_name(pa[4]) then
					return false, "There is already a town with this name."
				end
				town.name = pa[4]
				return true, "Town renamed."

			elseif pa[3] == "spawn" then
				player:set_pos(town.pos)
				player:set_look_vertical(town.look_vertical)
				player:set_look_horizontal(town.look_horizontal)
				return true

			elseif pa[3] == "claim" then
				local pos = player_pos:copy()

				if pa[4] == "above" then
					pos.y = pos.y + towny.settings.town_block_size
				elseif pa[4] == "below" then
					pos.y = pos.y - towny.settings.town_block_size
				end
				local is_outpost = pa[4] == "outpost"

				if towny.get_block_by_pos(pos) then

					return false, "This area is already claimed!"
				end

				if not towny.settings.vertical_towns then
					local block = towny.exists_block_at_x_z(pos)
					if block then
						if town ~= block.town then
							return false, "There is already a town above or below here."
						end
					end
				end

				if not is_outpost and not towny.pos_borders_townblock(pos, town) then
					return false, "You are too far away. Try '/townyadmin town <town> claim outpost'."
				end

				local block = towny.block.new(pos, town)

				if is_outpost or towny.neighboring_townblocks_have_flag(town, block, towny.BLOCK_OUTPOST) then
					-- if the outpost connects to the main town,
					-- it is no longer an outpost
					if towny.neighboring_townblocks_have_flag(town, block, towny.BLOCK_OUTPOST, true) then
						-- TODO: better way to clear outpost flags
						-- Maybe don't clear other disconnected outposts
						for i = 1, #town do
							town[i]:remove_flag(towny.BLOCK_OUTPOST)
						end
					else
						block:add_flag(towny.BLOCK_OUTPOST)
					end
				end

				block:visualize(player_name)

				return true, "Block claimed."

			elseif pa[3] == "set" then
				if pa[4] == "perm" then
					local perm_pa = {}
					-- start array at 'set' instead of 'town'
					for i = 1, #pa - 2 do
						perm_pa[i] = pa[i + 2]
					end
					if process_perms(perm_pa, town) then
						return true
					end

				elseif pa[4] == "spawn" then
					local pos = player:get_pos():copy()
					local block = towny.get_block_by_pos(pos)
					if not block or not has_flag(block.flags, towny.BLOCK_HOMEBLOCK) then
						return false, "You can't set the town spawn outside the homeblock."
					end
					if block.town ~= town then
						return false, table.concat({"This block is not part of ", town.name, "!"})
					end

					town.pos = pos
					town.look_vertical = player:get_look_vertical()
					town.look_horizontal = player:get_look_horizontal()
					return true, "Set spawn."

				elseif pa[4] == "homeblock" then

					local pos = player:get_pos():copy()
					local block = towny.get_block_by_pos(pos)
					if not block then
						return false, "There is no block here."
					end
					if block.town ~= town then
						return false, table.concat({"This block is not part of ", town.name, "!"})
					end

					for i = 1, #town do
						if has_flag(town[i].flags, towny.BLOCK_HOMEBLOCK) then
							town[i]:remove_flag(towny.BLOCK_HOMEBLOCK)
							break
						end
					end

					block:add_flag(towny.BLOCK_HOMEBLOCK)
					town.homeblock = block
					town.pos = pos
					town.look_vertical = player:get_look_vertical()
					town.look_horizontal = player:get_look_horizontal()
					return true, "Set homeblock."
				end

			elseif pa[3] == "toggle" then
				if pa[4] then
					if pa[4] == "_order" then
						return false
					end
					local flag = towny.registered_town_flags[pa[4]]
					if flag then
						local blockflag = towny.registered_block_flags[pa[4]]
						if blockflag then
							local i
							for i = 1, #town do
								town[i]:toggle_flag(blockflag)
							end
						end
						town:toggle_flag(flag)
						return true
					end
				end
			end
		end

	elseif pa[1] == "plot" then
		local block = towny.get_block_by_pos(player_pos)
		if not block then
			return false, "There is no block here."
		end

		if pa[2] == "toggle" then
			if pa[3] then
				if pa[3] == "_order" then
					return false
				end
				local flag = towny.registered_block_flags[pa[3]]
				if flag then
					block:toggle_flag(flag)
					return true
				end
			end
		elseif pa[2] == "set" then
			if pa[3] == "perm" then
				local perm_pa = {}
				-- start array at 'set' instead of 'plot'
				for i = 1, #pa - 1 do
					perm_pa[i] = pa[i + 1]
				end
				if process_perms(perm_pa, block) then
					return true
				end
			end
		end

	elseif pa[1] == "resident" then
		if pa[2] then
			res = towny.residents[pa[2]]
			if not res then
				return false, table.concat({"There is no player named '", pa[2], "'."})
			end

			if pa[3] == "delete" then
				core.kick_player(res.name, "An admin deleted your resident data.", true)
				res:delete()
				return true, "Resident data deleted."
			end
		end

	elseif pa[1] == "unclaim" then
		local block = towny.get_block_by_pos(player_pos)
		if has_flag(block.flags, towny.BLOCK_HOMEBLOCK) then
			return false, "You can not unclaim the homeblock."
		end

		block:delete()
		return true, "Block unclaimed."
	end

	return false
end})

core.register_chatcommand("towny", {
	params = "[universe]",
	description = "View towny statistics.",
	privs = {towny = true},
	func =

function (player_name, params)

	towny.dirty = true

	local player = core.get_player_by_name(player_name)
	if not player then return false, "Can't run command on behalf of offline player." end

	local pa = get_param_array(params)

	if pa[1]:len() == 0 then
		-- TODO: towny info
		return true, "towny"

	-- TODO: "map"
	-- TODO: "v"

	elseif pa[1] == "universe" then
		local str = {}
		local i = 0
		local j = 0
		local ta = towny.town_array
		local block_count = 0
		local plot_count = 0
		local resident_count = 0

		str[#str + 1] = "-- Towny Universe --\n\n"
		str[#str + 1] = "Town count: "
		str[#str + 1] = #ta
		str[#str + 1] = "\n"
		str[#str + 1] = "Block count: "
		for i = 1, #ta do
			local ba = ta[i]
			for j = 1, #ba do
				block_count = block_count + 1
				if ba[j].owner then
					plot_count = plot_count + 1
				end
			end
		end
		str[#str + 1] = block_count
		str[#str + 1] = "\n"
		str[#str + 1] = "Plot count: "
		str[#str + 1] = plot_count
		str[#str + 1] = "\n"
		str[#str + 1] = "Resident count: "
		for _, _ in pairs(towny.residents) do
			resident_count = resident_count + 1
		end
		str[#str + 1] = resident_count
		str[#str + 1] = "\n"

		return true, table.concat(str)
	end

	return false
end})

core.register_chatcommand("town", {
	params = table.concat({"[<town> || (show [<town>]) || here || spawn || list || (claim [above | below]) || (unclaim [above | below]) || perm || (new <town name>) || delete || (rank add | remove <name> ",
		get_registered_flags_params_str(towny.registered_resident_flags),
		") || (set (perm <perms>) | (mayor <name>) | spawn | homeblock | (name <town name>)) || (toggle ",
		get_registered_flags_params_str(towny.registered_town_flags),
		") || (invite <name> | sent | (revoke <name>)) || leave || (kick <name>) || (trust (add <name>) | (remove <name> | all))]"}),
	description = "Town commands. View other's towns, manage your town, or make your own town.",
	privs = {towny = true},
	func =

function (player_name, params)

	towny.dirty = true

	local player = core.get_player_by_name(player_name)
	if not player then
		return false, "Can't run command on behalf of offline player."
	end

	local player_pos = towny.get_player_pos(player)

	local pa = get_param_array(params)
	local resident = towny.residents[player_name]

	if pa[1]:len() == 0 then
		local town = resident.town
		if not town then
			return false, "You are not currently in a town."
		end

		local block = towny.get_townblock_by_pos(player_pos, town)

		return true, create_town_info_str(town)

	elseif pa[1] == "help" then
		-- TODO: help
		return true, "help" --print_help(pr2)

	elseif pa[1] == "show" then
		local town
		if pa[2] then
			town = towny.get_town_by_name(pa[2])
			if town then
				town:visualize(resident.name)
				return true
			else
				return true, table.concat({"There is no town named '", pa[2], "'."})
			end
		end

		if not resident.town then
			return false, "You have no town to show."
		end
		resident.town:visualize(resident.name)
		return true

	elseif pa[1] == "list" then
		local str = {}
		local ta = towny.town_array
		for i = 1, #ta do
			str[#str + 1] = ta[i].name
		end
		return true, table.concat(str, ", ")

	elseif pa[1] == "claim" then
		local town = resident.town
		if not town then
			return false, "You don't have a town!"
		end

		if not has_any_flags(resident.flags, towny.RESIDENT_MAYOR + towny.RESIDENT_COMAYOR) then
			return false, "Only mayors can claim blocks."
		end

		if not core.check_player_privs(player_name, "towny_blocks_no_limit") then
			local at_limit = false

			if core.check_player_privs(player_name, "towny_blocks_high_limit") then
				if #town >= towny.settings.max_townblocks_high then
					at_limit = true
				end
			else
				if #town >= towny.settings.max_townblocks then
					at_limit = true
				end
			end

			if at_limit then
				return false, "You can't claim any more blocks!"
			end
		end

		local pos = player_pos:copy()

		if pa[2] == "above" then
			pos.y = pos.y + towny.settings.town_block_size
		elseif pa[2] == "below" then
			pos.y = pos.y - towny.settings.town_block_size
		end

		if towny.get_block_by_pos(pos) then

			return false, "This area is already claimed!"
		end

		if not towny.settings.vertical_towns then
		local block = towny.exists_block_at_x_z(pos)
		if block then
			if town ~= block.town then
				return false, "There is already a town above or below here."
			end
		end
		end

		local is_outpost = pa[2] == "outpost"

		-- check if the new block would border the town
		if not is_outpost and not towny.pos_borders_townblock(pos, town) then
			return false, "You are too far away from your town. Try '/town claim outpost'."
		end
		if is_outpost and towny.pos_borders_townblock(pos, town) then
			return false, "You don't need to make an outpost right next to your town!"
		end

		if is_outpost and not core.check_player_privs(player, "towny_blocks_no_limit") then
			local outpost_count = 0
			for i = 1, #town do
				if town[i]:has_flag(towny.BLOCK_OUTPOST) then
					outpost_count = outpost_count + 1
				end
				if outpost_count >= towny.settings.max_outposts then
					return false, "You can't claim any more outposts."
				end
			end
		end

		local block = towny.block.new(pos, town)
		if is_outpost or towny.neighboring_townblocks_have_flag(town, block, towny.BLOCK_OUTPOST) then
			-- if the outpost connects to the main town,
			-- it is no longer an outpost
			if towny.neighboring_townblocks_have_flag(town, block, towny.BLOCK_OUTPOST, true) then
				-- TODO: better way to clear outpost flags
				-- Maybe don't clear other disconnected outposts
				for i = 1, #town do
					town[i]:remove_flag(towny.BLOCK_OUTPOST)
				end
			else
				block:add_flag(towny.BLOCK_OUTPOST)
			end
		end

		block:visualize(player_name)

		return true, table.concat({"Successfully claimed block ", block.blockpos:to_string(), "."})

	elseif pa[1] == "unclaim" then
		if not resident.town then
			return false, "You don't have a town!"
		end

		if not has_any_flags(resident.flags, towny.RESIDENT_MAYOR + towny.RESIDENT_COMAYOR) then
			return false, "Only mayors can unclaim blocks."
		end

		local pos = player_pos:copy()

		if pa[2] == "above" then
			pos.y = pos.y + towny.settings.town_block_size
		elseif pa[2] == "below" then
			pos.y = pos.y - towny.settings.town_block_size
		end

		local block = towny.get_block_by_pos(pos)

		if not block then
			return false, "This area is not claimed."
		end

		if block.town ~= resident.town then
			return false, "You cannot unclaim another town's block!"
		end

		if has_flag(block.flags, towny.BLOCK_HOMEBLOCK) then
			return false, "You can not unclaim your homeblock! Try /town delete or move your homeblock."
		end

		local str = table.concat({"Unclaimed block ", block.blockpos:to_string(), "."})

		block:delete()

		return true, str

	elseif pa[1] == "new" then
		if pa[2] then
			if resident.town then
				return false, "You're already in a town!"
			end

			if towny.get_block_by_pos(player_pos) then

				return false, "There's already a town here!"
			end

			if is_invalid_input(pa[2]) then
				return false, "Invalid name."
			end

			if towny.get_town_by_name(pa[2]) then
				return false, table.concat({"There's already a town named '", pa[2], "'."})
			end


			local ta = towny.town_array
			for i = 1, #ta do
				local homeblock_pos = ta[i].homeblock.blockpos
				if towny.get_distance(homeblock_pos, towny.get_blockpos(player_pos)) <= towny.settings.town_distance then
					return false, "You are too close to another town's homeblock."
				end
			end

			if not towny.settings.vertical_towns then
			local block = towny.exists_block_at_x_z(player_pos)
			if block then
				if resident.town ~= block.town then
					return false, "There is already a town above or below here."
				end
			end
			end

			local town = towny.town.new(resident, pa[2])

			core.chat_send_all(("%s has started a new town called '%s'!"):format(player_name,
				town.name))

			return true, "Your town has successfully been founded!"
		end

	elseif pa[1] == "delete" then

		local town = resident.town
		if not town then
			return false, "You don't have a town!"
		end

		if not has_flag(resident.flags, towny.RESIDENT_MAYOR) then
			return false, "Only mayors can delete their town."
		end

		if pa[2] == "yes" then
			core.chat_send_all(("The town of %s has fallen!"):format(town.name))
			resident.town:delete()

			return true, "You have successfully deleted your town."
		end

		return false, "Warning: this will permanently delete your town. Everything protected will be wilderness. Please run again with 'yes' after the command to confirm."

	elseif pa[1] == "set" then
		local town = resident.town
		if not town then
			return false, "You don't have a town!"
		end

		if not (town.members[player_name] and has_any_flags(resident.flags, towny.RESIDENT_MAYOR + towny.RESIDENT_COMAYOR)) then
			return false, "You don't own this town."
		end

		if pa[2] == "perm" then
			if process_perms(pa, town) then
				return true
			end
		end
		if pa[2] == "mayor" then
			if has_flag(resident.flags, towny.RESIDENT_COMAYOR) then
				return false, "You can't change the mayor as a comayor!"
			end
			if pa[3] then
				local new_mayor = towny.residents[pa[3]]
				if new_mayor then
					if not resident.town.members[pa[3]] then
						return false, pa[3] .. " is not a member of your town."
					end
					resident:remove_flag(towny.RESIDENT_MAYOR)
					new_mayor:add_flag(towny.RESIDENT_MAYOR)
					return true
				else
					return false, table.concat({"There is no player named '", pa[3], "'."})
				end
			else
				return true
			end
		end
		if pa[2] == "spawn" then
			local pos = player:get_pos():copy()
			local block = towny.get_block_by_pos(pos)
			if not block or not has_flag(block.flags, towny.BLOCK_HOMEBLOCK) then
				return false, "You can't set your town spawn outside your homeblock."
			end
			if block.town ~= resident.town then
				return false, "This isn't your town!"
			end

			town.pos = pos
			town.look_vertical = player:get_look_vertical()
			town.look_horizontal = player:get_look_horizontal()
			return true
		end
		if pa[2] == "homeblock" then

			local pos = player:get_pos():copy()
			local block = towny.get_block_by_pos(pos)
			if not block then
				return false, "There is no block here."
			end
			if block.town ~= resident.town then
				return false, "This isn't your town!"
			end

			local town = block.town

			for i = 1, #town do
				if has_flag(town[i].flags, towny.BLOCK_HOMEBLOCK) then
					town[i]:remove_flag(towny.BLOCK_HOMEBLOCK)
					break
				end
			end

			block:add_flag(towny.BLOCK_HOMEBLOCK)
			town.homeblock = block
			town.pos = pos
			town.look_vertical = player:get_look_vertical()
			town.look_horizontal = player:get_look_horizontal()
			return true
		end
		if pa[2] == "name" then
			if pa[3] then
				if is_invalid_input(pa[3]) then
					return false, "Invalid name."
				end

				if towny.get_town_by_name(pa[3]) then
					return false, "There is already a town with this name."
				end
				town.name = pa[3]
				return true
			else
				return false, "Name cannot be blank."
			end
		end

	elseif pa[1] == "perm" then
		local town
		if pa[2] then
			town = towny.get_town_by_name(pa[2])
			if not town then
				return false, table.concat({"There is no town named '", pa[2], "'."})
			end
		else
			town = resident.town
		end

		if not town then
			return false, "You don't have a town!"
		end
		return true, "Town Permissions for " .. town.name .. ":\n" .. create_perms_str(town.perms)

	elseif pa[1] == "toggle" then
		town = resident.town
		if not town then
			return false, "You don't have a town!"
		end

		if not (town.members[player_name] and has_any_flags(resident.flags, towny.RESIDENT_MAYOR + towny.RESIDENT_COMAYOR)) then
			return false, "You don't own this town."
		end

		if pa[2] then
			if pa[2] == "_order" then
				return false
			end
			local flag = towny.registered_town_flags[pa[2]]
			if flag then
				local blockflag = towny.registered_block_flags[pa[2]]
				if blockflag then
					local i
					for i = 1, #town do
						town[i]:toggle_flag(blockflag)
					end
				end
				town:toggle_flag(flag)
				return true
			end
		end

	elseif pa[1] == "invite" then
		town = resident.town
		if not town then
			return false, "You don't have a town!"
		end

		if pa[2] == "sent" then
			local str = {}
			for _, res in pairs(town.invites) do
				str[#str + 1] = table.concat({"Resident ", res.name})
			end
			if #str == 0 then
				str = {"You sent no invites."}
			end

			return true, table.concat(str, ", ")
		end

		if pa[2] == "revoke" then
			if pa[3] then
				if pa[3] == "all" then
					for name, _ in pairs(town.invites) do
						town.invites[name] = nil
						core.chat_send_player(name, "The town of " .. town.name .. " revoked your invite.")
					end
					return true, "Revoked all invites."
				end

				if town.invites[pa[3]] then
					town.invites[pa[3]] = nil
					core.chat_send_player(pa[3], "The town of " .. town.name .. " revoked your invite.")
					return true, table.concat({"Invite to ", pa[3], " revoked."})
				else
					return false, "You did not invite this player or this player does not exist."
				end
			else
				return false
			end
		end

		if not pa[2] then
			return false
		end

		local invited_res = towny.residents[pa[2]]
		if invited_res then
			if invited_res.town then
				return false, invited_res.name .. " is already in a town!"
			end
			if town.invites[invited_res.name] then
				return false, table.concat({"You have already invited ", invited_res.name, "!"})
			end

			town.invites[invited_res.name] = invited_res
			if invited_res:has_flag(towny.RESIDENT_ONLINE) then
				core.chat_send_player(invited_res.name, "You are invited to the town of " .. town.name .. ". Type '/resident invite accept | deny " .. town.name .. "'.")
			end
			return true, table.concat({"Sent invite to ", invited_res.name, "."})
		else
			return false, table.concat({"There is no player named '", pa[2], "'."})
		end

	elseif pa[1] == "leave" then
		local town = resident.town
		if not town then
			return false, "You don't have a town!"
		end

		if has_flag(resident.flags, towny.RESIDENT_MAYOR) then
			return false, "The mayor can't leave their town, try giving the mayorship to another player or deleting the town."
		end

		-- keep owned blocks
		local str = table.concat({"You have left the town of ", town.name, "."})
		town:remove_resident(resident)
		return true, str

	elseif pa[1] == "kick" then
		local town = resident.town

		if not has_any_flags(resident.flags, towny.RESIDENT_MAYOR + towny.RESIDENT_COMAYOR) then
			return false, "Only mayors can kick residents."
		end

		if pa[2] then
			local member = town.members[pa[2]]
			if member then
				town:remove_resident(member)
				return true, table.concat({"Kicked " .. member.name, " from the town."})
			else
				return false, table.concat({"There is no player named '", pa[2], "'."})
			end
		end

	elseif pa[1] == "rank" then
		local town = resident.town

		if not town then
			return false, "You don't have a town!"
		end

		if not has_any_flags(resident.flags, towny.RESIDENT_MAYOR + towny.RESIDENT_COMAYOR) then
			return false, "Only mayors or comayors can set ranks!"
		end

		-- pa[2] is "add" or "remove"
		if pa[3] then
			if pa[3] == resident.name and has_flag(resident.flags, towny.RESIDENT_MAYOR) then
				return false, "You are the mayor. There's no need to rank yourself!"
			end

			local res = town.members[pa[3]]

			if not res then
				return false, pa[3] .. " is not in your town."
			end

			if pa[4] then
				if pa[4] == "_order" then
					return false
				end
				local flag = towny.registered_resident_flags[pa[4]]
				if flag then
				if pa[2] == "add" then
					res:add_flag(flag)
					return true
				elseif pa[2] == "remove" then
					res:remove_flag(flag)
					return true
				end
				end
			end
		end

	elseif pa[1] == "here" then
		local block = towny.get_block_by_pos(player_pos)
		if block then
			return true, create_town_info_str(block.town)
		else
			return true, "There is no town here."
		end

	elseif pa[1] == "spawn" then
		local town = resident.town
		if not town then
			return false, "You don't have a town!"
		end

		player:set_pos(town.pos)
		player:set_look_vertical(town.look_vertical)
		player:set_look_horizontal(town.look_horizontal)
		return true

	elseif pa[1] == "trust" then
		local town = resident.town
		if not town then
			return false, "You don't have a town!"
		end
		if not (town.members[player_name] and has_any_flags(resident.flags, towny.RESIDENT_MAYOR + towny.RESIDENT_COMAYOR)) then
			return false, "You don't own this town."
		end

		if pa[2] == "add" then
			if pa[3] then
				local res = towny.residents[pa[3]]
				if res then
					town.trusted[res.name] = res
					return true
				else
					return false, table.concat({"There is no player named '", pa[3], "'."})
				end
			end
		end
		if pa[2] == "remove" then
			if pa[3] then
				if pa[3] == "all" then
					for name, _ in pairs(town.trusted) do
						town.trusted[name] = nil
					end
					return true, "Removed all players from trusted list."
				end

				local res = town.trusted[pa[3]]
				if res then
					town.trusted[res.name] = nil
					return true
				else
					return false, table.concat({"'", pa[3], "' is not on the trusted list."})
				end
			end
		end
	else
		-- always have this code last
		local town = towny.get_town_by_name(pa[1])
		if town then
			return true, create_town_info_str(town)
		else
			return false, table.concat({"There's no town named '", pa[1], "'."})
		end
	end

	return false
end})

local no_block_str = "There is no block here."

core.register_chatcommand("plot", {
	params = "[perm || show || (forsale | fs) || (notforsale | nfs) || claim || unclaim || evict || (trust (add <name>) | (remove <name> | all)) || (set (perm <perms>) | (owner [<name>]) | (name [<blockname>])) || (toggle "
	..get_registered_flags_params_str(towny.registered_block_flags)..
	")]",
	description = "Manage your town blocks and plots.",
	privs = {towny = true},
	func =

function (player_name, params)

	towny.dirty = true

	local player = core.get_player_by_name(player_name)
	if not player then
		return false, "Can't run command on behalf of offline player."
	end

	local player_pos = towny.get_player_pos(player)

	local pa = get_param_array(params)
	local resident = towny.residents[player_name]
	local block = towny.get_block_by_pos(player_pos)

	if pa[1]:len() == 0 then
		if not block then return false, no_block_str end

		local str = {}
		str[#str + 1] = "-- Block --\n\n"
		str[#str + 1] = block.name
		str[#str + 1] = "\n"
		str[#str + 1] = create_flags_str(towny.registered_block_flags, block)
		str[#str + 1] = "\n"
		str[#str + 1] = "Owner: "
		if block.owner then
			str[#str + 1] = block.owner:get_display_name()
		end
		str[#str + 1] = "\n"
		str[#str + 1] = "Trusted Players: ["
		local trusted_str = {}
		for name, _ in pairs(block.trusted) do
			trusted_str[#trusted_str + 1] = name
		end
		str[#str + 1] = table.concat(trusted_str, " ")
		str[#str + 1] = "]\n"

		return true, table.concat(str)

	elseif pa[1] == "trust" then
		if not block then return false, no_block_str end
		if not block:has_access(resident) then
			return false, "You don't own this block or this town."
		end

		if pa[2] == "add" then
			if pa[3] then
				local res = towny.residents[pa[3]]
				if res then
					block.trusted[res.name] = res
					return true
				else
					return false, table.concat({"There is no player named '", pa[3], "'."})
				end
			end
		end
		if pa[2] == "remove" then
			if pa[3] then
				if pa[3] == "all" then
					for name, _ in pairs(block.trusted) do
						block.trusted[name] = nil
					end
					return true, "Removed all players from trusted list."
				end

				local res = block.trusted[pa[3]]
				if res then
					block.trusted[res.name] = nil
					return true
				else
					return false, table.concat({"'", pa[3], "' is not on the trusted list."})
				end
			end
		end

	elseif pa[1] == "set" then
		if not block then return false, no_block_str end

		if not block:has_access(resident) then
			return false, "You don't own this block or this town."
		end

		if pa[2] == "perm" then
			if process_perms(pa, block) then
				return true
			end
		end
		if pa[2] == "owner" then
			if pa[3] then
				local res = towny.residents[pa[3]]
				if not res then
					return false, table.concat({"There is no player named '", pa[3], "'."})
				end

				if res == block.owner then
					return false, res:get_display_name() .. " already owns this plot."
				end

				block:set_owner(res)
				return true
			else
				block:set_owner(nil)
				return true
			end
		end
		if pa[2] == "name" then
			if pa[3] then
				if is_invalid_input(pa[3]) then
					return false, "Invalid name."
				end

				block.name = pa[3]
			else
				block.name = ""
			end
			return true
		end

	elseif pa[1] == "toggle" then
		if not block then return false, no_block_str end

		if not block:has_access(resident) then
			return false, "You don't own this block or this town."
		end

		if pa[2] then
			if pa[2] == "_order" then
				return false
			end
			local flag = towny.registered_block_flags[pa[2]]
			if flag then
				block:toggle_flag(flag)
				return true
			end
		end

	elseif pa[1] == "perm" then
		if not block then return false, no_block_str end
		return true, "Block Permissions:\n" .. create_perms_str(block.perms)

	elseif pa[1] == "show" then
		if not block then return false, no_block_str end

		block:visualize(player_name)
		return true

	elseif pa[1] == "forsale" or pa[1] == "fs" then
		if not block then return false, no_block_str end
		if not block:has_access(resident) then
			return false, "You don't own this block or this town."
		end
		if block.owner and block.owner ~= resident then
			return false, "You can't set someone else's plot for sale. Try '/plot evict' first."
		end

		block:add_flag(towny.BLOCK_FORSALE)
		return true

	elseif pa[1] == "notforsale" or pa[1] == "nfs" then
		if not block then return false, no_block_str end
		if not block:has_access(resident) then
			return false, "You don't own this block or this town."
		end
		if block.owner and block.owner ~= resident then
			return false, "You can't set someone else's plot for sale. Try '/plot evict' first."
		end

		block:remove_flag(towny.BLOCK_FORSALE)
		return true

	elseif pa[1] == "claim" then
		if not block then return false, no_block_str end
		if not has_flag(block.flags, towny.BLOCK_FORSALE) then
			return false, "This plot is not for sale!"
		end
		if towny.is_protection_violation(block, player, towny.PERM_TYPE_BUY) then
			return false, "You aren't allowed to buy this plot."
		end
		if block.owner == resident then
			return false, "You can't buy your own plot from yourself!"
		end

		-- TODO: economy
		block:remove_flag(towny.BLOCK_FORSALE)
		block:set_owner(resident)
		return true

	elseif pa[1] == "unclaim" then
		if not block then return false, no_block_str end
		if block.owner ~= resident then
			return false, "You don't own this plot."
		end
		block:set_owner(nil)
		return true

	elseif pa[1] == "evict" then
		if not block then return false, no_block_str end

		if not (block.town.members[player_name] and has_any_flags(resident.flags, towny.RESIDENT_MAYOR + towny.RESIDENT_COMAYOR)) then
			return false, "You don't own this town."
		end
		if not block.owner then
			return false, "This plot is unowned."
		end

		block:set_owner(nil)
		return true
	end

	return false
end})

core.register_chatcommand("resident", {
	params = "[(list [online]) || perm || (invite (accept <town name>) | (deny <town name>) | list) || (join <town name>) || (set (nickname [<name>]) | (perm <perms>))]",
	description = "Resident commands.",
	privs = {towny = true},
	func =

function (player_name, params)

	towny.dirty = true

	local player = core.get_player_by_name(player_name)
	if not player then
		return false, "Can't run command on behalf of offline player."
	end

	local player_pos = towny.get_player_pos(player)

	local pa = get_param_array(params)
	local resident = towny.residents[player_name]

	if pa[1]:len() == 0 then
		return true, create_resident_info_str(resident)

	elseif pa[1] == "list" then
		local str = {}
		if pa[2] == "online" then
			for name, res in pairs(towny.residents) do
				if res:has_flag(towny.RESIDENT_ONLINE) then
					str[#str + 1] = name
				end
			end
		else
			for name, _ in pairs(towny.residents) do
				str[#str + 1] = name
			end
		end

		return true, table.concat(str, ", ")

	elseif pa[1] == "perm" then
		return true, "Resident Permissions:\n" .. create_perms_str(resident.perms)

	elseif pa[1] == "invite" then
		if resident.town then
			return false, "You're already in a town!"
		end
		if pa[2] == "accept" then
			if pa[3] then
				local town = towny.get_town_by_name(pa[3])
				if town then
					if not town.invites[player_name] then
						return false, "You were not invited to this town."
					end

					town:add_resident(resident)
					town.invites[player_name] = nil
					towny.chat_send_town(town, resident.name .. " has joined the town!")
					return true, table.concat({"You have joined the town of ", town.name, "!"})
				else
					return false, table.concat({"There is no town named '", pa[3], "'."})
				end
			end
		end
		if pa[2] == "deny" then
			if pa[3] then
				if pa[3] == "all" then
					local i
					local ta = towny.town_array
					for i = 1, #ta do
					if ta[i].invites[player_name] then
						ta[i].invites[player_name] = nil
						towny.chat_send_town(ta[i], resident.name .. " denied the invite to join " .. ta[i].name .. ".")
					end
					end
					return true, "Denied all invites."
				end

				local town = towny.get_town_by_name(pa[3])
				if town then
					if not town.invites[player_name] then
						return false, "You were not invited to this town."
					end

					town.invites[player_name] = nil
					towny.chat_send_town(town, resident.name .. " denied the invite to join " .. town.name .. ".")
					return true, "You have denied the invite."
				else
					return false, table.concat({"There is no town named '", pa[3], "'."})
				end
			end
		end
		if pa[2] == "list" then
			local str = {}
			for i = 1, #towny.town_array do
				local town = towny.town_array[i]
				if town.invites[player_name] then
					str[#str + 1] = table.concat({"The town of ", town.name})
				end
			end
			if #str == 0 then
				str = {"You have no invites."}
			end
			return true, table.concat(str, ", ")
		end

	elseif pa[1] == "join" then
		if resident.town then
			return false, "You're already in a town!"
		end
		local town = towny.get_town_by_name(pa[2])
		if town then
			if has_flag(town.flags, towny.TOWN_OPEN) then
				town:add_resident(resident)
				towny.chat_send_town(town, resident.name .. " has joined the town!")
				return true, table.concat({"You have joined the town of ", town.name, "!"})
			else
				return false, "You have to be invited to this town."
			end
		else
			return false, table.concat({"There is no town named '", pa[2], "'."})
		end

	elseif pa[1] == "set" then
		if pa[2] == "nickname" then
			if pa[3] then
				if is_invalid_input(pa[3]) then
					return false, "Invalid name."
				end

				resident.nickname = pa[3]
			else
				resident.nickname = ""
			end
			return true
		elseif pa[2] == "perm" then
			if process_perms(pa, resident) then
				return true
			end
		end
	else
		-- always have this code last
		local res = towny.residents[pa[1]]
		if res then
			return true, create_resident_info_str(res)
		else
			return false, table.concat({"There's no resident named '", pa[1], "'."})
		end
	end


	return false
end})

local perms_str = "This command doesn't do anything, see /help perms. Use the parameters as a guide to set perms. Replace <perms> in other commands with the parameters."

core.register_chatcommand("perms", {
	params = get_perm_params_str(),
	description = perms_str,
	privs = {towny = true},
	func =

function (player_name, params)
	return true, perms_str
end})

