# hashimon_bodies_dmobs — licence and attribution

## What is in this mod

Lua that calls `hashimon_bodies.register_creatura_body()` with mesh filenames,
animation frame ranges and hitboxes. **No upstream code and no upstream assets.**

## What it references

Models and textures belonging to **dmobs**:

- **Models and textures: CC BY-SA 3.0**, created by D00Med except where the
  upstream `license.txt` lists another author
- dmobs' own *code* is LGPL 2.1+ and is **not used here**
- dmobs ships its own media; this mod copies none of it

## Why this matters for Hashimon

CC BY-SA 3.0 requires **attribution** and is **share-alike**: a derivative of
those assets must carry the same licence. Referencing them at runtime, as this
mod does, is not a derivative work of the assets. Editing or re-exporting one of
these meshes would be, and the result would have to stay CC BY-SA 3.0.

Removing this directory removes every construct, humanoid, flora and chelonian
body and changes nothing about DNA, species, the emission ledger, or the
protocol. `hashimon_core` selects by **family**; unregistered families are skipped.

## Attribution

dmobs models and textures © 2016 D00Med and contributors, CC BY-SA 3.0.
See the upstream `dmobs/license.txt` for the full per-asset list.
