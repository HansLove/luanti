# Blender sources

The `.blend` files that the models in `../models/` are built from.

They live here, **not** in `models/`, because Luanti scans mod media directories
and ships what it finds to every client. `.blend` is not on the engine's media
allowlist (`src/server.cpp`) so it would be ignored, but a stray `.glb` there
gets downloaded by everyone whether or not any entity references it.

Re-export after editing:

```bash
python3 scripts/export_blend_to_glb.py \
  3d-world/mods/hashimon_entities/blender_sources/hashimon_super_bear.blend \
  3d-world/mods/hashimon_entities/models/hashimon_super_bear.glb \
  --range 1:50 --close-loop
```
