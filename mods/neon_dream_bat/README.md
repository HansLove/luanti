# Neon Dream Bat (Meshy → Hashiworld)

Custom GLB import test for **local Hashiworld**. Proves that figures you author/export can spawn as mesh entities in Luanti.

## Quick start

1. Mod is at `3d-world/mods/neon_dream_bat/` (symlinked into `~/Library/Application Support/minetest/mods/`).
2. Hashiworld `world.mt` has `load_mod_neon_dream_bat = true`.
3. Fully quit Luanti (Cmd+Q) and reopen Hashiworld.
4. In chat: **`/spawn_neon_dream_bat`**
5. Punch the entity to remove it.

Optional: creative item **Neon Dream Bat (Meshy test)** places the same entity.

## Model info

| Field | Value |
|-------|--------|
| Source | `Meshy_AI_Neon_Dream_Bat_0814184525_texture.glb` |
| File | `neon_dream_bat.glb` (~59 MB) |
| Meshes | 1 |
| Embedded textures | yes |
| Skins / animations | **0** (static mesh only) |
| Vertices / faces | ~2.0M / ~2.0M |

**Warning:** This export is heavy. First spawn may hitch while the client loads the GLB. For production companions, retopo / bake to a much smaller mesh.

## Success criteria (this phase)

- Entity appears in front of you with the Meshy mesh/materials.
- No dependency on Animalia wolf / Creatura for this test.
- Hashimon roster companion is **unchanged**.

## Next: walk animation

This GLB has **no** `skins` and **no** `animations[]`. Idle spin in `on_step` is cosmetic only.

To play a real walk clip:

1. Export a **skinned** GLB that includes an animation track (e.g. `walk`), or a single continuous frame range.
2. Inspect clips (Blender / `gltf-transform` / parse GLB JSON `animations`).
3. In `on_activate`, call Luanti animation like the engine test spider:

```lua
on_activate = function(self)
	-- Example frame range — replace with your clip's start/end
	self.object:set_animation({ x = 0, y = 40 }, 30)
end
```

Reference: `3d-world/games/devtest/mods/gltf/init.lua` → `gltf:spider_animated`.

4. Only after walk looks correct, consider swapping `hashimon_entities` companion mesh away from `animalia_wolf.b3d`.

## Re-import another Meshy model

```bash
cd /path/to/Hashimon
python3 scripts/convert_mesh.py "/path/to/model.glb" ./3d-world/mods my_model_name
ln -sfn "$(pwd)/3d-world/mods/my_model_name" \
  "$HOME/Library/Application Support/minetest/mods/my_model_name"
# then enable load_mod_my_model_name in world.mt
```
