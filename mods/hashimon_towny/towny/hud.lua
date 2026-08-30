-- A township system for Minetest servers.
-- The MIT License - 2024  Olivia May <oliviamay@tuta.com>

-- code originally from 'areas' mod by ShadowNinja
-- This is inspired by the landrush mod by Bremaweb
local S = core.get_translator("towny")
towny.hud = {}
towny.hud.refresh = 0

core.register_globalstep(function(dtime)
	towny.hud.refresh = towny.hud.refresh + dtime
	if towny.hud.refresh > towny.settings["tick"] then
		towny.hud.refresh = 0
	else
		return
	end

	for _, player in pairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local pos = vector.round(player:get_pos())
		pos = vector.apply(pos, function(p)
			return math.max(math.min(p, 2147483), -2147483)
		end)
		local block_string = ""

		local block = towny.get_block_by_pos(pos)

		local str = {}

		-- strings go in order:
		-- pvp, block name, block owner, forsale, town name
		if block then
			if block:has_flag(towny.BLOCK_PVP) then
				str[#str + 1] = "[PVP]"
			end
			if block.name ~= "" then
				str[#str + 1] = block.name
			else
				str[#str + 1] = "~"
			end
			if block.owner then
				str[#str + 1] = table.concat({"[", block.owner:get_display_name(), "]"})
			else
				str[#str + 1] = "~"
			end
			if towny.has_flag(block.flags, towny.BLOCK_FORSALE) then
				str[#str + 1] = "[For Sale]"
			end
			str[#str + 1] = "(" .. block.town.name .. ")"
		else
			str[#str + 1] = "[PVP]"
			str[#str + 1] = "(Wilderness)"
		end

		block_string = table.concat(str, " ")

		local hud = towny.hud[name]
		if not hud then
			hud = {}
			towny.hud[name] = hud
			hud.townyId = player:hud_add({
				[core.features.hud_def_type_field and "type" or "hud_elem_type"] = "text", -- compatible with older versions
				name = "towny",
				number = 0xFFFFFF,
				position = {x=0, y=1},
				offset = {x=8, y=-8},
				text = block_string,
				scale = {x=200, y=60},
				alignment = {x=1, y=-1},
			})
			hud.old_string = block_string
			return
		elseif hud.old_string ~= block_string then
			player:hud_change(hud.townyId, "text", block_string)
			hud.old_string = block_string
		end
	end
end)

core.register_on_leaveplayer(function(player)
	towny.hud[player:get_player_name()] = nil
end)
