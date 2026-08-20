---
name: add-hashimon
description: Add a 3D model (.glb/.gltf, typically from Meshy) into a local Luanti world as a spawnable Hashimon creature, for development and testing without the HashimonServer API. Use this whenever the user wants to get a 3D asset into the game manually — "agrega este hashimon", "mete este modelo al juego", "quiero ver este glb en Luanti", "add this model as a creature", "spawn this asset", "probar este modelo 3D" — or hands over a .glb file in the context of this repo. Also use it when a model already in the world renders wrong (untextured, invisible, microscopic, huge), since the causes are the same handful of engine constraints this skill covers.
---

# Add a Hashimon manually

Gets a finished 3D asset into a running local world so it can be looked at. This
is the development shortcut around the real pipeline: no API, no Meshy job, no
HashimonServer — just a file on disk becoming a creature standing in front of you.

Read `mods/hashimon_core/README.md` for the full pipeline and the engine
constraints behind it. This skill is the operational path.

## What the asset has to be

Ask for a `.glb` or `.gltf` file path. Everything else is derived from it. Before
copying anything, run the preparation script — it reports the problems that
otherwise fail silently at render time:

```bash
python3 .claude/skills/add-hashimon/scripts/prepare_asset.py \
  <model.glb> <worldpath>/hashimon_media [--height 1.2] [--slug name]
```

It extracts embedded textures to separate files, copies the mesh under a
versioned name, computes the `visual_size` the model needs, warns about material
features Luanti drops, and prints a ready-to-paste manifest entry. Standard
library only — no pip or npm needed.

Three things make an asset unusable, and the script flags all of them:

- **Over ~16MB** — Luanti will not load it. Reduce polycount or texture size.
- **No texture at all** — nothing to render the surface with.
- **A look that lives in a metalness or roughness map** — Luanti keeps base color
  only, so that appearance is simply gone. A model reads correctly only when its
  look is painted into the base color texture.

`doubleSided` and embedded images produce warnings rather than blockers: the
script splits the images out for you, and `doubleSided` only shows up as backface
artifacts on thin geometry.

## Wiring it in

The world's media directory is `<worldpath>/hashimon_media/` — for the usual dev
world, `worlds/hashidev/hashimon_media/`. It holds the model files plus a
`hashimons.json` keyed by dna:

```json
{
  "<64-hex dna>": {
    "mesh": "osito_metal_v1.glb",
    "textures": ["osito_metal_v1.jpg"],
    "visual_size": 16.3
  }
}
```

Merge the script's entry into that file rather than replacing it, so previously
added creatures survive. The script derives a dna from the slug so repeat runs on
the same model stay stable, but any 64-hex string works for testing.

Never overwrite a model file that is already registered. `dynamic_add_media`
refuses the same filename twice, so iterating means `_v1` → `_v2`; the script
picks the next free version automatically.

## Making it appear

The spawn commands live in a world-local mod, because they must never ship to
production. If `worlds/<world>/worldmods/hashimon_devtest/` does not exist, copy
it from this skill's `assets/hashimon_devtest/`. It is gitignored along with the
rest of `worlds/`, so a fresh clone will not have it.

Start the server and connect (two terminals, or connect from an installed client):

```fish
./bin/luanti --server --world worlds/hashidev --gameid devtest --port 30000
./bin/luanti --go --address 127.0.0.1 --port 30000 --name diego
```

**Log in as the name set in `minetest.conf`'s `name =` field** — currently
`diego`. That player is the server admin and therefore has the `server` privilege
the spawn commands require. Any other name connects as a guest and the commands
refuse to run. If they are rejected anyway, `/grantme all` fixes it.

Then, in the client's chat:

```
/hashimon media reload      picks up the new manifest and pushes files to clients
/hashlist                   shows what is registered and at what size
/hashadd osito              spawns it, using the manifest's visual_size
/hashadd osito 20           spawns it at an explicit size instead
/hashsize 12                re-scales every test creature already spawned
```

`/hashadd` takes either the 64-hex dna or any fragment of the mesh filename, so
tell the user the short name — nobody should retype a hash to look at a model.

## When it renders wrong

Almost every failure is one of four things, and the symptom identifies which:

**Untextured or default-looking surface** — the texture is still embedded in the
`.glb`, or `textures` in the manifest does not name the extracted file. Luanti
does not read glTF embedded images at all.

**Microscopic or gigantic** — glTF renders at a fixed 10 mesh units per node, so
`visual_size` has to compensate for however the model was exported. Fix it live
with `/hashsize` and write the number that works back into the manifest; no
restart needed, `set_properties` applies immediately.

**Nothing appears and the command reports no media** — the manifest was not
reloaded, or the dna does not match. Run `/hashimon media reload` and check the
server log for `Media registry loaded: N packaged, M dynamic`.

**The model appears but looks flat or wrong-colored** — its look depended on PBR
maps that Luanti discards. Nothing to fix on the Luanti side; the asset needs its
appearance baked into the base color texture.

Changing the worldmod's own Lua does require restarting the server — Luanti has
no hot reload for mod code. Media and entity properties are the parts that are
hot.

## After it works

Report the numbers that were actually settled: the dna, the filenames written,
and the `visual_size` that looked right. That last one is the only value a person
had to judge by eye, so it is the one worth writing down.
