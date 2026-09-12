# hashimon_vibing — Vibing towers

A town plants **one** Vibing tower inside its own claim to tap the yield of that
coordinate (docs/VIBING_V1.md §3). The mod pushes a projection of every tower to
the API so the website can draw it on the map with the tier its coordinate yields.
It only *reads* Towny and pushes a projection — it never edits Towny.

## The tower's 3D model — how the asset reaches Luanti (the deploy process)

The tower renders a real 3D asset (a Meshy "Arcane Energy Spire") as a **mesh
node**. The model and its texture live in this mod:

```
models/hashimon_vibing_spire.glb     glTF geometry (Luanti reads this directly)
textures/hashimon_vibing_spire.jpg   base-color texture (the tile the node paints with)
```

**Luanti ships a mod's `models/` and `textures/` to every client automatically when
the mod loads.** So there is no separate runtime upload: once these two files are
committed, deploying the mod *is* how the spire reaches Luanti. `init.lua` already
references these exact filenames.

### To update the model from a new export

Drop the new `.glb` anywhere and run the installer — it copies the geometry in and
extracts the base-color image (Luanti cannot read a glTF's embedded images, and it
drops metallic/roughness + normal maps, so only the albedo is pulled out and, on
macOS, downscaled):

```bash
python3 tools/install_model.py /path/to/new_model.glb
git add models/ textures/
```

Stdlib only (plus optional `sips` on macOS). The filenames are fixed, so a new
export needs no Lua change.

### The deploy checklist (from Cursor)

1. Run `tools/install_model.py` if the asset changed; commit `models/` + `textures/`.
2. Deploy the repo so the server has this mod (it is loaded by path — see the
   world's `world.mt`: `load_mod_hashimon_vibing = mods/hashimon_vibing`).
3. **Restart the Luanti server.** `core.register_node` runs at load time and Luanti
   has **no hot reload for mod code**, so the node's new mesh drawtype only takes
   effect on a restart. (Media files themselves do reload, but the node *definition*
   does not.) Clients then download the model on their next join.

### Tuning the look

`visual_scale` (currently `18`) and how deep the spire roots into the ground are
the only **by-eye** values — glTF is 10 mesh units = 1 node and the model is centered,
so a tall scale roots the base a little underground (fitting for an energy-tap
derrick). Adjust `visual_scale` in `init.lua` and restart to change it permanently.
If it renders untextured, the tile filename in `tiles` does not match the file in
`textures/`; if it renders flat/wrong-colored, that look lived in the PBR maps Luanti
discards and has to be baked into the base-color texture instead.
