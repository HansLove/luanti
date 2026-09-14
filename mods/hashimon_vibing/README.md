# hashimon_vibing — Vibing towers

A town plants **one** Vibing tower inside its own claim to tap the yield of that
coordinate (docs/VIBING_V1.md §3). The mod pushes a projection of every tower to
the API so the website can draw it on the map with the tier its coordinate yields.
It only *reads* Towny and pushes a projection — it never edits Towny.

## The tower's 3D model

```
models/hashimon_vibing_spire.glb     stripped geometry (~85KB — no embedded images)
textures/hashimon_vibing_spire.jpg   base-color albedo (512px)
tools/asset/                         original Meshy export (NOT shipped to clients)
```

Luanti ships `models/` and `textures/` to every client on mod load. Never put the
raw Meshy `.glb` (multi-MB with embedded JPEGs) in `models/` — that was the lag.

### Update from a new Meshy export

```bash
python3 tools/install_model.py /path/to/new_model.glb
```

That parks the source under `tools/asset/`, extracts + boosts the albedo, and runs
`scripts/glb_for_luanti.py --keep-times` so the client mesh stays light.

Restart Luanti after changing `init.lua` (node defs only load at startup).

### Tuning

`visual_scale` in `init.lua` (currently **80**): mesh height ≈ 1.0 glTF unit →
`altura_nodos ≈ visual_scale / 10` (~8 nodes). Raise/lower and restart.
