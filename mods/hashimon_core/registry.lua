-- Media registry: dna -> { mesh, textures }, merged from two sources.
--
-- Packaged  — bundled with a mod (rsync'd on deploy), known at server startup.
--             Luanti auto-ships every file inside a loaded mod's directory as
--             part of its normal startup media scan, so a packaged entry only
--             needs to name its files — no dynamic_add_media call required.
-- Dynamic   — dropped into <worldpath>/hashimon_media/ after the server is
--             already running. The startup scan only covers builtin, the game
--             and mod directories (never the world directory), so these files
--             must be pushed explicitly via core.dynamic_add_media (see media.lua).
--
-- On dna collision, dynamic overrides packaged: a hot-dropped model always
-- wins over whatever shipped with the last deploy.
--
-- Reading either manifest never needs secure.trusted_mods: read-only access to
-- every mod directory, and read/write access to the world directory (outside
-- worldmods/ and game/), is always allowed even under secure.enable_security
-- (verified against src/script/cpp_api/s_security.cpp, checkPathWithGamedef).

hashimon = hashimon or {}

hashimon.media_registry = hashimon.media_registry or {}

-- Mods whose bundled hashimons.json is treated as a packaged media source.
-- hashimon_entities is the default; extend this list if other mods ship
-- their own creature packs (e.g. a per-creature Meshy mod).
hashimon.PACKAGED_MEDIA_MODS = hashimon.PACKAGED_MEDIA_MODS or { "hashimon_entities" }

local function read_json_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local raw = f:read("*a")
	f:close()
	if not raw or raw == "" then
		return nil
	end
	local ok, parsed = pcall(core.parse_json, raw)
	if not ok or type(parsed) ~= "table" then
		core.log("warning", "[hashimon_core] Could not parse manifest: " .. path)
		return nil
	end
	return parsed
end

function hashimon.world_media_dir()
	return core.get_worldpath() .. "/hashimon_media"
end

function hashimon.world_manifest_path()
	return hashimon.world_media_dir() .. "/hashimons.json"
end

local function merge_manifest(into, manifest, source)
	if not manifest then
		return 0
	end
	local n = 0
	for dna, entry in pairs(manifest) do
		if type(entry) == "table" and type(entry.mesh) == "string" then
			into[dna] = {
				mesh = entry.mesh,
				textures = type(entry.textures) == "table" and entry.textures or {},
				source = source,
			}
			n = n + 1
		end
	end
	return n
end

--- Rebuild hashimon.media_registry from scratch: packaged manifests first,
--- then the world manifest (which wins on collision). Safe to call any time.
function hashimon.reload_media_registry()
	local registry = {}
	local packaged_count = 0

	for _, modname in ipairs(hashimon.PACKAGED_MEDIA_MODS) do
		local modpath = core.get_modpath(modname)
		if modpath then
			packaged_count = packaged_count
				+ merge_manifest(registry, read_json_file(modpath .. "/hashimons.json"), "packaged")
		end
	end

	local dynamic_count = merge_manifest(
		registry,
		read_json_file(hashimon.world_manifest_path()),
		"dynamic"
	)

	hashimon.media_registry = registry
	core.log("action", string.format(
		"[hashimon_core] Media registry loaded: %d packaged, %d dynamic (%d total)",
		packaged_count, dynamic_count, packaged_count + dynamic_count
	))
	return registry
end

-- Initial load at mod startup.
hashimon.reload_media_registry()
