local function send(name, msg)
	core.chat_send_player(name, "[VWar] " .. msg)
end

local function village_at_player(player)
	local pos = player:get_pos()
	if not pos then
		return nil
	end
	return mg_villages.get_town_id_at_pos(pos), pos
end

local function format_war_entry(entry)
	local cx, cz = hashimon_vwar.war_entry_coords(entry)
	if cx and cz then
		return string.format("  - %s — X=%d Z=%d (at war)", entry.name, cx, cz)
	end
	return "  - " .. entry.name .. " (at war, coords unknown)"
end

core.register_chatcommand("vwar", {
	params = "<declare|peace|exception|status|map>",
	description = "Village war: declare/peace war zones, personal exception, status, map",
	func = function(name, param)
		if not mg_villages or not mg_villages.get_town_id_at_pos then
			return false, "mg_villages is not loaded."
		end

		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end

		local cmd, rest = param:match("^(%S*)%s*(.*)$")
		cmd = cmd ~= "" and cmd or "status"
		rest = rest or ""

		if cmd == "declare" then
			local village_id = village_at_player(player)
			if not village_id then
				return false, "You are not inside a village. Stand in the village area first."
			end
			local ok, result = hashimon_vwar.declare_war(village_id)
			if not ok then
				return false, "Could not declare war."
			end
			send(name, "War declared on " .. result .. ". All players may build and destroy here.")
			if persistent_map and persistent_map.show_map then
				send(name, "War zone marked on /map — use /vwar map to center the map.")
			end
			return true, "War declared."
		end

		if cmd == "peace" then
			if rest == "all" then
				hashimon_vwar.end_all_wars()
				send(name, "All village wars ended. Protection restored.")
				return true, "Peace restored everywhere."
			end
			local village_id = village_at_player(player)
			if not village_id then
				return false, "You are not inside a village."
			end
			local ok, err = hashimon_vwar.end_war(village_id)
			if not ok then
				if err == "not_at_war" then
					return false, hashimon_vwar.village_display_name(village_id) .. " is not at war."
				end
				return false, "Could not end war."
			end
			send(name, "Peace restored in " .. hashimon_vwar.village_display_name(village_id) .. ".")
			return true, "Peace declared."
		end

		if cmd == "exception" then
			local enabled = hashimon_vwar.toggle_player_exception_mode(name)
			if enabled then
				send(name, "Exception mode ON — you may edit any village (others still blocked unless war).")
			else
				send(name, "Exception mode OFF — normal village protection applies to you.")
			end
			return true, enabled and "Exception ON" or "Exception OFF"
		end

		if cmd == "status" then
			local wars = hashimon_vwar.list_war_villages()
			if #wars == 0 then
				send(name, "No villages at war.")
			else
				send(name, #wars .. " village(s) at war:")
				for i, entry in ipairs(wars) do
					send(name, format_war_entry(entry))
					send(name, "    (/vwar map " .. i .. " to show on map)")
				end
			end
			local ex = hashimon_vwar.player_exception_mode(name)
			send(name, "Your exception mode: " .. (ex and "ON" or "OFF"))
			local village_id = village_at_player(player)
			if village_id then
				local at_war = hashimon_vwar.is_village_at_war(village_id)
				send(name, "Current village: " .. hashimon_vwar.village_display_name(village_id)
					.. (at_war and " (at war)" or " (protected)"))
			end
			return true, "Status sent to chat."
		end

		if cmd == "map" then
			if not persistent_map or not persistent_map.show_map then
				return false, "discovery_maps is not loaded. Enable discovery_maps for war map markers."
			end
			local entry, err = hashimon_vwar.resolve_war_map_target(player, rest)
			if not entry then
				if err == "no_wars" then
					return false, "No villages at war."
				end
				return false, "War village not found. Use /vwar status for names and indexes."
			end
			local ok, cx, cz = hashimon_vwar.show_war_on_map(name, entry)
			if not ok then
				if cx == "no_coords" then
					return false, "Could not locate " .. entry.name .. " on the map."
				end
				return false, "Could not open map."
			end
			send(name, string.format(
				"Map centered on ⚔ %s (X=%d Z=%d). Red overlay = hostile territory.",
				entry.name, cx, cz
			))
			return true, "Map opened."
		end

		return false, "Use: declare, peace, peace all, exception, status, map"
	end,
})
