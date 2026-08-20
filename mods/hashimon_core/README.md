# hashimon_core — media pipeline

How a 3D asset becomes a creature standing in the world.

This documents the wiring verified end to end on 2026-08-20 with a Meshy export
(`osito-metal.glb`) rendering on a local server. It covers the Luanti side only:
getting a finished `.glb` into the world. Producing that `.glb` from a text prompt
is HashimonServer's job and is not implemented yet.

## The two manifests

`registry.lua` builds `hashimon.media_registry` (a `dna -> { mesh, textures }` map)
by merging two sources. Which one a file belongs in decides whether it needs an
explicit push to clients.

| Source | Path | Indexed when | Needs `dynamic_add_media` |
|---|---|---|---|
| packaged | `mods/<mod>/hashimons.json` | server startup | No |
| dynamic | `<worldpath>/hashimon_media/hashimons.json` | on reload | Yes |

Luanti's startup media scan covers builtin, the game, and mod directories — never
the world directory. So a packaged entry only has to *name* its files and every
client already has them; a dynamic entry has to hand each file to clients
explicitly, which is what `media.lua` does.

On a dna collision, dynamic wins: a hot-dropped model overrides whatever shipped
with the last deploy. The list of mods scanned as packaged sources is
`hashimon.PACKAGED_MEDIA_MODS` in `registry.lua`.

Manifest format is the same for both:

```json
{
  "<64-hex dna>": {
    "mesh": "osito_v1.glb",
    "textures": ["osito_v1.jpg"]
  }
}
```

## Getting an asset in

### 1. Extract the embedded texture

**This step is mandatory, not an optimization.** Luanti does not support glTF
embedded images (`doc/lua_api.md:420-432`) — a `.glb` with its texture inside the
binary buffer renders untextured. The texture has to become a separate file listed
in `textures`.

Meshy embeds by default. Pulling it out needs no external tooling — the buffer
view is readable with the Python standard library:

```python
import struct, json

path = "osito-metal.glb"
with open(path, "rb") as f:
    f.read(12)                                    # glTF header
    length, _ = struct.unpack("<II", f.read(8))
    gltf = json.loads(f.read(length))             # JSON chunk
    length, _ = struct.unpack("<II", f.read(8))
    binary = f.read(length)                       # BIN chunk

image = gltf["images"][0]
view = gltf["bufferViews"][image["bufferView"]]
start = view.get("byteOffset", 0)
data = binary[start:start + view["byteLength"]]

print(image["mimeType"], len(data))               # e.g. image/jpeg 3298440
with open("osito_v1.jpg", "wb") as f:
    f.write(data)
```

The same script is worth running to read `accessors[POSITION].min/max` — that
bounding box is what tells you the scale the model will need (see below).

### 2. Drop the files in

```
<worldpath>/hashimon_media/
  osito_v1.glb
  osito_v1.jpg
  hashimons.json
```

Name files with a version suffix. `dynamic_add_media` refuses to register the same
filename twice (`doc/lua_api.md:7826-7850`), and with `ephemeral = false` the API
forbids modifying a file after registering it. Iterating on a model means
`osito_v1.glb` → `osito_v2.glb`, never overwriting in place. The client cache is
keyed by content SHA1 (`src/client/clientmedia.cpp:27-39`), so this is a
server-side restriction, not a stale-cache problem.

### 3. Reload

```
/hashimon media reload
```

Re-reads both manifests and pushes anything new to connected clients. No restart.
Mods can also register a single entry at runtime with
`hashimon.register_media(dna, { mesh = ..., textures = { ... } })`, which is the
entry point an automated pipeline would call.

### 4. Spawn

`hashimon_entities` resolves media through `hashimon.resolve_creature_media(creature)`,
keyed on `creature.dna`. The render chain in `entities.lua` tries three tiers so a
Hashimon never appears as nothing:

1. custom 3D media (this pipeline)
2. procedural voxel body (DNA-derived colour and proportions)
3. sprite + colorize

A creature whose dna has a manifest entry takes tier 1 automatically. Nothing else
needs changing.

## Engine constraints that shape all of this

Verified against `doc/lua_api.md` in this repo.

**Scale is fixed at 10 mesh units = 1 node** for glTF (`doc/lua_api.md:10082`,
`10906`). This is an engine convention, not a property of the export — a model
whose bounding box is ~1.0 unit renders 0.1 nodes tall, so it needs
`visual_size` ≈ 15 to stand about 1.5 nodes. Correct it with `visual_size`, never
by rescaling the asset.

> Known gap: `hashimon.visual_size_for_creature()` in `entities.lua` returns ~0.6
> for stage 1, calibrated for sprites. Any Meshy GLB rendered through it comes out
> microscopic. The manifest should carry its own scale factor and `setup()` should
> prefer it when media is present.

**PBR is flattened to base color only** (`doc/lua_api.md:427`). Metalness and
roughness maps are ignored, and `doubleSided` does not work. A model reads
correctly in Luanti only when its look is painted into the base color texture — a
`metallicFactor` of 0.0 is a good sign, a metalness map is not.

**Media files cap around 16MB** (`doc/lua_api.md:383`), and every dynamic push
costs file size × connected players.

**Animations are optional.** A model with no tracks needs no `set_animation` call;
it renders in its bind pose. Only call it when the asset actually carries tracks.

## Iteration loop

There is no Lua hot reload in Luanti. Changing mod code requires restarting the
server — in singleplayer, leaving to the menu and re-entering the world.

What *is* hot: `dynamic_add_media` (new media) and `obj:set_properties()` (mesh,
textures, `visual_size` on a live entity). Calibrating scale therefore never needs
a restart.

## Local test setup

The dev world lives under `worlds/`, which is gitignored — recreate it as needed.

```fish
./bin/luanti --server --world worlds/hashidev --gameid devtest --port 30000
./bin/luanti --go --address 127.0.0.1 --port 30000 --name diego
```

`hashimon_core` degrades cleanly with no API running: it logs the HTTP failure and
continues, and the media registry works fully offline since it reads JSON from
disk. Only `session.lua` needs the API.

Spawning without the API needs a command that takes an arbitrary dna, since the
normal path builds its roster from `GET /hashimons`. A world-local mod at
`worlds/<world>/worldmods/hashimon_devtest/` keeps it out of the deployable mods:

```lua
core.register_chatcommand("osito", {
	description = "Spawn the test GLB creature at a given visual_size",
	params = "[size] [dna]",
	privs = { server = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not online"
		end

		local size_str, dna = param:match("^(%S*)%s*(%S*)$")
		local size = tonumber(size_str) or 15
		if dna == "" then
			dna = "0000000000000000000000000000000000000000000000000000000000000001"
		end

		local media = hashimon.resolve_creature_media({ dna = dna })
		if not media then
			return false, "No media registered for dna " .. dna:sub(1, 8)
		end

		local pos = player:get_pos()
		pos.y = pos.y + 1
		local obj = core.add_entity(pos, "hashimon_entities:creature")
		if not obj then
			return false, "add_entity failed"
		end
		obj:get_luaentity():setup(
			{ dna = dna, speciesKey = "s001", stage = 1, name = "Osito" }, name)
		obj:set_properties({ visual_size = { x = size, y = size, z = size } })

		return true, string.format("Spawned %s at visual_size %.1f", media.mesh, size)
	end,
})
```

Pair it with an `/osito_size <n>` that walks
`core.get_objects_inside_radius()` calling `set_properties` — rescaling live beats
respawning while finding the right number.

## Not automated yet

Everything above starts from a finished `.glb` sitting on disk. The generation
half — prompt → Meshy task → poll or webhook → download → strip embedded images
and resize → write manifest → notify the server — belongs to HashimonServer and
does not exist. The texture-separation step in particular is load-bearing: a
pipeline that assumes `.glb` "already contains everything" produces creatures that
render untextured, and fails silently.
