-- Dev-only spawning, bypassing the API.
--
-- The normal path builds a roster from GET /hashimons, so testing a model
-- offline needs a way to spawn an arbitrary dna. This lives in the world's
-- worldmods/ rather than the repo's mods/ because it must never ship.

local DEFAULT_VISUAL_SIZE = 15

local function read_manifest()
	local file = io.open(core.get_worldpath() .. "/hashimon_media/hashimons.json", "r")
	if not file then
		return nil
	end
	local raw = file:read("*a")
	file:close()
	local ok, parsed = pcall(core.parse_json, raw)
	if ok and type(parsed) == "table" then
		return parsed
	end
	return nil
end

--- Resolve what the player typed into a dna and a size.
--- A 64-hex dna is the real key, but nobody should have to retype one, so a
--- fragment of the mesh filename ("osito") resolves too. visual_size comes from
--- the manifest because registry.lua keeps only mesh/textures; once the
--- production registry carries it, read it from there instead.
local function resolve(query)
	local manifest = read_manifest()
	if not manifest then
		return query, nil
	end

	if manifest[query] then
		return query, tonumber(manifest[query].visual_size)
	end

	local needle = query:lower()
	for dna, entry in pairs(manifest) do
		if type(entry.mesh) == "string" and entry.mesh:lower():find(needle, 1, true) then
			return dna, tonumber(entry.visual_size)
		end
	end
	return query, nil
end

local function spawn(player_name, dna, size)
	local player = core.get_player_by_name(player_name)
	if not player then
		return false, "Player not online"
	end

	local media = hashimon.resolve_creature_media({ dna = dna })
	if not media then
		return false, "No media matches '" .. dna:sub(1, 16) ..
			"' — check hashimon_media/hashimons.json, then /hashimon media reload"
	end

	local pos = player:get_pos()
	pos.y = pos.y + 1
	local obj = core.add_entity(pos, "hashimon_entities:creature")
	if not obj then
		return false, "add_entity failed"
	end

	local entity = obj:get_luaentity()
	if not entity then
		return false, "entity spawned without a luaentity"
	end
	entity:setup({ dna = dna, speciesKey = "s001", stage = 1, name = "Test" }, player_name)
	obj:set_properties({ visual_size = { x = size, y = size, z = size } })

	return true, string.format("Spawned %s at visual_size %.1f", media.mesh, size)
end

core.register_chatcommand("hashadd", {
	description = "Spawn a creature from the media registry by name or dna (dev)",
	params = "<name|dna> [visual_size]",
	privs = { server = true },
	func = function(name, param)
		local query, size_str = param:match("^(%S+)%s*(%S*)$")
		if not query then
			return false, "Usage: /hashadd <name|dna> [visual_size]"
		end
		local dna, manifest_size = resolve(query)
		return spawn(name, dna, tonumber(size_str) or manifest_size or DEFAULT_VISUAL_SIZE)
	end,
})

core.register_chatcommand("hashlist", {
	description = "List every creature registered in the media manifest (dev)",
	privs = { server = true },
	func = function()
		local manifest = read_manifest()
		if not manifest then
			return false, "No manifest at hashimon_media/hashimons.json"
		end
		local lines = {}
		for dna, entry in pairs(manifest) do
			table.insert(lines, string.format("  %s  (%s, size %s)",
				entry.mesh or "?", dna:sub(1, 8), tostring(entry.visual_size or "default")))
		end
		if #lines == 0 then
			return true, "Manifest is empty"
		end
		table.sort(lines)
		return true, "Registered creatures:\n" .. table.concat(lines, "\n")
	end,
})

-- Rescaling live beats respawning while hunting for the right number:
-- set_properties applies immediately, no restart and no re-download.
core.register_chatcommand("hashsize", {
	description = "Re-scale every test creature nearby (dev)",
	params = "<visual_size>",
	privs = { server = true },
	func = function(name, param)
		local size = tonumber(param)
		if not size then
			return false, "Usage: /hashsize <number>"
		end
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not online"
		end

		local scaled = 0
		for _, obj in ipairs(core.get_objects_inside_radius(player:get_pos(), 50)) do
			local entity = obj:get_luaentity()
			if entity and entity.name == "hashimon_entities:creature" then
				obj:set_properties({ visual_size = { x = size, y = size, z = size } })
				scaled = scaled + 1
			end
		end
		return true, "Rescaled " .. scaled .. " creature(s) to " .. size
	end,
})

core.log("action", "[hashimon_devtest] /hashadd, /hashlist and /hashsize registered")
