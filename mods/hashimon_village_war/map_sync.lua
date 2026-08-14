-- Sync war villages to discovery_maps system markers and war-zone overlay helpers.

function hashimon_vwar.get_village_center(village_id)
	if not mg_villages or not mg_villages.all_villages then
		return nil
	end
	local v = mg_villages.all_villages[village_id]
	if not v then
		return nil
	end
	return {
		x = v.vx,
		y = (v.vh or 0) + 2,
		z = v.vz,
	}
end

function hashimon_vwar.get_village_bounds(village_id)
	if not mg_villages or not mg_villages.all_villages then
		return nil
	end
	local v = mg_villages.all_villages[village_id]
	if not v or not v.vs then
		return nil
	end
	local size = v.vs * 3
	return {
		min_x = v.vx - size,
		max_x = v.vx + size,
		min_z = v.vz - size,
		max_z = v.vz + size,
	}
end

function hashimon_vwar.tile_in_war_zone(tile_x, tile_z)
	if not hashimon_vwar.war_villages then
		return nil
	end

	local ts = (persistent_map and persistent_map.tile_size) or 128
	local world_x = tile_x * ts + ts / 2
	local world_z = tile_z * ts + ts / 2

	for village_id, _ in pairs(hashimon_vwar.war_villages) do
		local bounds = hashimon_vwar.get_village_bounds(village_id)
		if bounds
			and world_x >= bounds.min_x and world_x <= bounds.max_x
			and world_z >= bounds.min_z and world_z <= bounds.max_z then
			return village_id
		end
	end
	return nil
end

function hashimon_vwar.sync_war_map_markers()
	if not persistent_map or not persistent_map.upsert_system_marker then
		core.log("info", "[hashimon_village_war] discovery_maps not loaded — war map markers skipped")
		return
	end

	persistent_map.remove_all_system_markers("hashimon_vwar")

	for village_id, _ in pairs(hashimon_vwar.war_villages) do
		local pos = hashimon_vwar.get_village_center(village_id)
		local name = hashimon_vwar.village_display_name(village_id)
		if pos then
			persistent_map.upsert_system_marker(
				"hashimon_vwar",
				"vwar:" .. village_id,
				pos,
				"⚔ " .. name,
				6,
				{ village_id = village_id }
			)
		else
			core.log("warning", "[hashimon_village_war] War village not in mg_villages: " .. tostring(village_id))
		end
	end

	for _, player in ipairs(core.get_connected_players()) do
		if persistent_map.refresh_map_if_open then
			persistent_map.refresh_map_if_open(player:get_player_name())
		end
	end
end

function hashimon_vwar.war_entry_coords(entry)
	local center = hashimon_vwar.get_village_center(entry.id)
	if center then
		return math.floor(center.x + 0.5), math.floor(center.z + 0.5)
	end
	return nil, nil
end

function hashimon_vwar.resolve_war_map_target(player, param)
	local wars = hashimon_vwar.list_war_villages()
	if #wars == 0 then
		return nil, "no_wars"
	end

	param = (param or ""):match("^%s*(.-)%s*$") or ""
	if param == "" then
		local pos = player:get_pos()
		if not pos then
			return wars[1], nil
		end
		local nearest = wars[1]
		local nearest_dist = math.huge
		for _, entry in ipairs(wars) do
			local cx, cz = hashimon_vwar.war_entry_coords(entry)
			if cx and cz then
				local dx = cx - pos.x
				local dz = cz - pos.z
				local dist = dx * dx + dz * dz
				if dist < nearest_dist then
					nearest_dist = dist
					nearest = entry
				end
			end
		end
		return nearest, nil
	end

	local index = tonumber(param)
	if index and wars[index] then
		return wars[index], nil
	end

	local lower = param:lower()
	for _, entry in ipairs(wars) do
		if entry.name:lower():find(lower, 1, true) then
			return entry, nil
		end
	end

	return nil, "not_found"
end

function hashimon_vwar.show_war_on_map(player_name, entry)
	if not persistent_map or not persistent_map.center_map_on_coords then
		return false, "no_maps"
	end

	local cx, cz = hashimon_vwar.war_entry_coords(entry)
	if not cx or not cz then
		return false, "no_coords"
	end

	persistent_map.center_map_on_coords(player_name, cx, cz)
	persistent_map.show_map(player_name)
	return true, cx, cz
end

core.register_on_joinplayer(function(player)
	core.after(1, function()
		if persistent_map and persistent_map.refresh_map_if_open then
			persistent_map.refresh_map_if_open(player:get_player_name())
		end
	end)
end)
