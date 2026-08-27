# Hidden sponsor QR groves (ICQR-inspired)

Place scannable QR patterns in Hashiworld, camouflaged by perimeter trees. Players discover them organically, fly above, and scan with a phone camera — like [ICQR Magic Tree](https://tree.icqr.com/).

## Quick start

### 1. Bake a schematic (outside the game)

```bash
cd 3d-world/util
npm install
node bake-qr-tree.mjs --id aarontolentino --url "https://aarontolentino.com/"
```

Outputs:

- `mods/hashimon_qr_tree/schematics/sponsor_<id>.mts`
- `mods/hashimon_qr_tree/schematics/sponsor_<id>.json`
- `mods/hashimon_qr_tree/schematics/sponsor_<id>_topdown.txt` (ASCII preview)

### 2. Configure sponsor placement

Edit [`sponsors.lua`](sponsors.lua):

```lua
{
  id = "aarontolentino",
  url = "https://aarontolentino.com/",
  label = "Patrocinador demo",
  pos = { x = 1200, y = 0, z = -800 },  -- y=0 → surface at place time
  schematic = "sponsor_aarontolentino.mts",
},
```

### 3. Install mod

```bash
cd 3d-world
./util/install-hashimon-mods.sh
```

Enable **hashimon_qr_tree** in your world’s Content tab. Fully restart Luanti.

### 4. Place in-world (admin)

```
/qr_tree list
/qr_tree place aarontolentino
/qr_tree align aarontolentino
```

`/qr_tree align` teleports you 32 nodes above the QR center with look pitch −90° (ICQR “tap to flatten” substitute).

Scan with your phone camera against the screen, or take an F12 screenshot and scan that.

### 5. Re-place after re-bake

If you change `--module-size` or the URL, regenerate the schematic and replace the in-world grove:

```
/qr_tree remove aarontolentino
/qr_tree place aarontolentino
/qr_tree align aarontolentino
```

## QR size (voxel limits)

Luanti nodes are **1 m**. The smallest possible QR uses **1 node per QR module** (`--module-size 1`). Larger values multiply the footprint linearly.

For `https://aarontolentino.com/` (ECC H, quiet zone 4, 33×33 data modules):

| `--module-size` | Footprint (side) | Use case |
|-----------------|------------------|----------|
| **1** (default) | **41 m** | Most compact; still scannable with `/qr_tree align` |
| 2 | 82 m | Easier phone scan from higher altitude |
| 4 | 164 m | **QR Island** — landmark / data-island aesthetic |

Formula: `footprint = (qr_modules + 2 × quiet_zone) × module_size`

Shorter URLs + lower ECC (e.g. L) can shrink the matrix further; the bake script picks version automatically. Default stays **ECC H** for tolerance near perimeter trees.

## Commands

| Command | Description |
|---------|-------------|
| `/qr_tree list` | Sponsors and placement status |
| `/qr_tree place <id>` | Place one sponsor grove |
| `/qr_tree place all` | Place all configured sponsors |
| `/qr_tree align <id>` | Top-down scan view for admin testing |
| `/qr_tree remove <id>` | Remove QR pads and restore grass |

Requires privilege `hashimon_qr_admin` (granted to singleplayer by default).

## Design notes

- **QR matrix** uses `hashimon_qr_tree:dark` / `hashimon_qr_tree:light` nodes (high contrast).
- **Perimeter trees** (`default:tree`) sit outside the quiet zone — lateral camouflage only; nothing over the QR modules.
- **Hidden by default** — no map markers; marketing is discovery-based.
- **ECC level H** — tolerates minor edge occlusion from nearby leaves.

## Bake options

```
--module-size 1     Nodes per QR module (default 1; use 4 for QR Island ~164 m)
--quiet-zone 4      Quiet margin in modules (default 4)
--out-dir PATH      Output directory
```

**QR Island:** bake with `--module-size 4` for a large scannable landmark (same URL, 16× the area of the default compact grove).

## Validation

After baking, verify the schematic:

```bash
node validate-qr-tree.mjs --id aarontolentino
```

Confirms the `.mts` round-trips and the top-down pattern encodes the configured URL.

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `hashimon_qr_tree.auto_place` | `false` | Place all sponsors on server start |

## Adding sponsors

1. Bake schematic with a new `--id` and `--url`.
2. Add entry to `sponsors.lua`.
3. Restart server (or `/qr_tree place <id>`).

Landing pages and discount codes live outside this mod — only the URL is encoded in the QR.
