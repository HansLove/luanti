-- Pushes dynamic (world-dir) creature media to clients and resolves a
-- creature's dna to { mesh, textures } for hashimon_entities to render.
--
-- Packaged media (see registry.lua) needs no push: it was already inside a
-- loaded mod directory at the startup media scan, so every client already has
-- it by filename. Dynamic media lives in <worldpath>/hashimon_media/ instead,
-- which the startup scan never covers (only builtin + game + mod dirs are
-- scanned), so each file has to be handed to clients explicitly here.

hashimon = hashimon or {}

local pushed_files = {} -- filename -> true, once dynamic_add_media has run for it

local function push_dynamic_file(filename)
	if pushed_files[filename] then
		return
	end
	local filepath = hashimon.world_media_dir() .. "/" .. filename
	local f = io.open(filepath, "rb")
	if not f then
		core.log("warning", "[hashimon_core] Dynamic media file missing on disk: " .. filepath)
		return
	end
	f:close()

	-- nil callback = registered at startup / mod-load time, per core.dynamic_add_media docs.
	local accepted = core.dynamic_add_media({ filepath = filepath }, nil)
	if accepted then
		pushed_files[filename] = true
	else
		core.log("warning", "[hashimon_core] dynamic_add_media rejected: " .. filename)
	end
end

--- Push every currently-registered dynamic (world-dir) entry to clients.
--- Idempotent: already-pushed filenames are skipped.
function hashimon.sync_dynamic_media()
	local pushed = 0
	for _, entry in pairs(hashimon.media_registry) do
		if entry.source == "dynamic" then
			if not pushed_files[entry.mesh] then
				push_dynamic_file(entry.mesh)
				pushed = pushed + 1
			end
			for _, tex in ipairs(entry.textures) do
				if not pushed_files[tex] then
					push_dynamic_file(tex)
					pushed = pushed + 1
				end
			end
		end
	end
	return pushed
end

--- Re-scan the world manifest and push any newly-added dynamic files.
--- This is the extension point a future automated pipeline (or an admin
--- dropping files by hand) calls into: write hashimon_media/hashimons.json
--- + the referenced files, then call this (or /hashimon media reload).
function hashimon.reload_media()
	hashimon.reload_media_registry()
	return hashimon.sync_dynamic_media()
end

--- Register or update a single creature's media at runtime and push it if new.
--- dna: 64-hex creature DNA. entry: { mesh = "file.glb", textures = {"file.png", ...} }
function hashimon.register_media(dna, entry)
	if type(dna) ~= "string" or type(entry) ~= "table" or type(entry.mesh) ~= "string" then
		return false, "invalid_entry"
	end
	hashimon.media_registry[dna] = {
		mesh = entry.mesh,
		textures = type(entry.textures) == "table" and entry.textures or {},
		source = "dynamic",
	}
	push_dynamic_file(entry.mesh)
	for _, tex in ipairs(hashimon.media_registry[dna].textures) do
		push_dynamic_file(tex)
	end
	return true
end

--- Look up custom 3D media for a creature. Returns nil if none is registered,
--- in which case the caller should fall back to the sprite/colorize visual —
--- a Hashimon must never render as nothing.
function hashimon.resolve_creature_media(creature)
	if not creature or not creature.dna then
		return nil
	end
	local entry = hashimon.media_registry[creature.dna]
	if not entry then
		return nil
	end
	return { mesh = entry.mesh, textures = entry.textures }
end

-- Push whatever the world manifest already lists at startup.
hashimon.sync_dynamic_media()
