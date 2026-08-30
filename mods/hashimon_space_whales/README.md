# Hashimon Space Whales

**Solid voxel whales** in the **other_worlds** space layer (default **Y 5000–5999**).

Built from tinted walkable nodes (red / orange / pink) in a clear silhouette: elongated body, head, flukes, pectoral fins. They drift slowly and carry players on the back. Natural asteroids stay as scenery.

## Shape

| Part | Form |
|------|------|
| Body | Long ellipsoid, flattened top (walkable back) |
| Head | Narrower ellipsoid at the front |
| Tail | Horizontal flukes |
| Fins | Side pectorals mid-body |

Scale **6–16** (body length in nodes). Budget roughly **200–800** nodes.

```
/space_whale       # scale 10, ahead of where you look
/space_whale 8
/space_whale 14
```

Priv `hashimon_space_admin` (singleplayer has it).

## Requirements

- `default` (textures / sounds)
- `other_worlds` recommended (space layer)

No `mobs` / `dmobs`.

## Install

```bash
cd 3d-world && ./util/install-hashimon-mods.sh
```

```
load_mod_hashimon_space_whales = mods/hashimon_space_whales
```

Restart Luanti after updating.

## Test

1. `/teleport ~ 5200 ~`
2. Face open void / atmos → `/space_whale 10`
3. You should see body + tail flukes (not a random rock blob)
4. Land on the back and walk
5. Wait ~15–30 s: drifts 1 node at a time and carries you
