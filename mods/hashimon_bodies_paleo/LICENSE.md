# hashimon_bodies_paleo — licence and attribution

## What is in this mod

Lua that calls `hashimon_bodies.register_creatura_body()` with mesh filenames,
animation frame ranges and hitboxes. **No upstream code and no upstream assets.**

## What it references

Meshes and textures belonging to **paleotest**, licensed **GPL-3.0**.

- Upstream: the `paleotest` mod, © its authors, GPL-3.0
- paleotest ships its own models and textures; this mod copies none of them
- Luanti resolves media globally across loaded mods, so `paleotest_*.b3d` names
  resolve only on a world that already has paleotest installed

## Why this matters for Hashimon

GPL-3.0 is copyleft. A distribution that **bundles** paleotest's assets must be
GPL-3.0 compatible as a whole. This mod is arranged so that never happens by
accident: the assets stay in paleotest, and this mod is an optional adapter.

Removing this directory removes every prehistoric body and changes nothing about
DNA, species, the emission ledger, or the protocol. `hashimon_core` has no
knowledge that these bodies exist — it selects by **family**, and unregistered
families are skipped.

## Attribution

Prehistoric creature models and textures © the paleotest authors, GPL-3.0.
