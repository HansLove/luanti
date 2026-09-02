# hashimon_bodies

Canonical **Creatura** body registry for Hashimon roster creatures.

## Dependencies

- `hashimon_core`, `creatura`, `animalia` (required)
- `hashimon_entities` optional at runtime (roster + blast/stats UI); loads after bodies via its `optional_depends`
- `draconis` (optional — enables `dragon_wyvern` skeleton)

## Bodies

11 bodies across 8 families. All meshes come from the MIT stack
(Animalia + Draconis) and ship with real walk/run/fly clips.

| ID | Mesh | Family | Texture variants | Notes |
|----|------|--------|------------------|-------|
| `canine_wolf` | `animalia_wolf.b3d` | canine | 4 | |
| `canine_fox` | `animalia_fox.b3d` | canine | 1 | walk/run share one clip |
| `feline_cat` | `animalia_cat.b3d` | feline | 9 | widest texture variation |
| `ursine_bear` | `animalia_bear.b3d` | ursine | 1 | heavy silhouette |
| `equine_horse` | `animalia_horse.b3d` | equine | 6 | `capabilities.mount = true`, `mount_view` |
| `rodent_rat` | `animalia_rat.b3d` | rodent | 3 | smallest walker |
| `avian_bat` | `animalia_bat.b3d` | avian | 3 | |
| `avian_owl` | `animalia_owl.b3d` | avian | 1 | flight-only, no walk clip |
| `avian_songbird` | `animalia_bird.b3d` | avian | 3 | walk + fly |
| `amphibian_frog` | `animalia_dart_frog.b3d` | amphibian | 3 | has swim clip |
| `dragon_wyvern` | `draconis_jungle_wyvern.b3d` | dragon | 4 | needs `draconis` |

`equine_horse` (and `dragon_fire` / `dragon_ice` in the extra pack) declare
`capabilities.mount = true` and a **`mount_view`** table consumed by
[`mount.lua`](../hashimon_entities/mount.lua) when stage ≥ 10:

| Field | Role |
|-------|------|
| `bone` | Attach bone — prefer `Socket.Mount` (child of `Torso`) when rigged; see `docs/SKELETON_STANDARD_V1.md` §3a |
| `seat` / `rot` | `set_attach` offset (Luanti units ×10); keep `{0,0,0}` when the socket *is* the seat |
| `eye_first` / `eye_third` | Camera offsets via `set_eye_offset` (first person unclamped; third Z clamped to ±5) |
| `hide_rider` | Shrink Sam to 0.001 — only for huge MIT flyers that still clip; own bodies keep Sam visible |
| `forced_visible` | Pass `true` to `set_attach` so the rider mesh appears in first person |
| `rider_scale` | Multiply Sam `visual_size` while mounted (e.g. `0.65` on tall air mounts) |
| `suggest_camera` | `"third"` hints Ark-style third person on mount (C stays free); alias: `prefer_camera` |

Own rideables (`bloom_adult_air`, `beacon_adult_air`) declare `bones.mount_socket`
and a calibrated `mount_view`. Bodies without `mount_view` get collisionbox-derived
defaults (height × 8 for first-person lift). Live tune while mounted:
`/hashimon eyes <y> [z]`, `/hashimon eyes3 <y> [z]`, `/hashimon seat <x> <y> <z>`,
and `/hashimon rot <x> <y> <z>`.

The rider uses Sam's `sit` animation + `player_api.player_attached`.

### Not yet covered

`arachnid`, `mollusk`, `humanoid` and `construct` archetypes have no faithful
skeleton in the MIT stack and currently map to the nearest available silhouette
(see `ARCHETYPE_BODY_POOLS` in [`morphology.lua`](../hashimon_core/morphology.lua)).
Real bodies for them need either the **dmobs** tier (golem, orc, wasp — models are
**CC BY-SA 3.0**, a licence decision, unlike the MIT mods above) or new assets.
No snake/serpent mesh exists in any installed mod.

## Spawn chain

Roster spawn order ([`entities.lua`](../hashimon_entities/entities.lua)):

1. Premium GLB (`hashimon_media/` registry)
2. **Morphology** (`hashimon.spawn_morph_creature`)
3. Voxel procedural body
4. Sprite fallback

## Enable in Hashiworld

```bash
ln -sfn "$(pwd)/3d-world/mods/hashimon_bodies" \
  "$HOME/Library/Application Support/minetest/mods/hashimon_bodies"
```

Add to `world.mt`: `load_mod_hashimon_bodies = true`

Then `/hashimon sync` — creatures without premium GLB spawn as animated Creatura mobs.

## Validation

```bash
luajit scripts/validate_morphology.lua
```

Loads the real `morphology.lua` + `dna_compiler.lua` and asserts every Genesis
species resolves to **more than one body**. Current result: 11 distinct bodies
across 8 families, ~4 bodies per Genesis species at roughly uniform odds.

> The old `validate_morphology.py` was a Python reimplementation that pinned one
> skeleton per species, so it reported PASS while every creature rendered as the
> same wolf. It is now a thin runner for the Lua check — don't reintroduce a mirror.
