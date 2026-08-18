-- Engine minimap configuration (V / Shift+V)

local HINT_META = "discovery_maps:minimap_hint"

minetest.register_on_joinplayer(function(player)
	if not player.set_minimap_modes then
		return
	end

	player:set_minimap_modes({
		{ type = "surface", label = "Surface", size = 256 },
		{ type = "radar", label = "Radar", size = 192 },
	}, 1)

	local meta = player:get_meta()
	if meta:get_string(HINT_META) ~= "1" then
		meta:set_string(HINT_META, "1")
		minetest.chat_send_player(player:get_player_name(),
			"[Map] Minimap: V = cycle Surface/Radar, Shift+V = rotate. /map for full map, /markers to manage waypoints.")
	end
end)

minetest.log("action", "[persistent_map] Engine minimap modes configured")
