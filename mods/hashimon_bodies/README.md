# hashimon_bodies

Canonical **Creatura** body registry for Hashimon roster creatures.

## Dependencies

- `hashimon_core`, `creatura`, `animalia` (required)
- `hashimon_entities` optional at runtime (roster + blast/stats UI); loads after bodies via its `optional_depends`
- `draconis` (optional — enables `dragon_wyvern` skeleton)

## Bodies (MVP)

| ID | Mesh | Family |
|----|------|--------|
| `canine_wolf` | `animalia_wolf.b3d` | canine |
| `avian_bat` | `animalia_bat.b3d` | avian |
| `dragon_wyvern` | `draconis_jungle_wyvern.b3d` | dragon |

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
python3 scripts/validate_morphology.py
```

Expect **>= 50** unique morphology fingerprints from random DNAs.
