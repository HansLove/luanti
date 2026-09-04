# hashimon_entities

Roster creatures, mount mobility, blast orbs, and related gameplay.

## Impact flight POC

[`impact_flight.lua`](impact_flight.lua) recreates a controlled “DBZ yeet”: one
velocity impulse, then a stone/dirt tunnel with TNT FX and braking.

### In-game control

**Shift + E** (sneak + aux1 / “Special”). Rising edge, 2s cooldown.
Disabled while mounted (aux1 is used for mount mobility).

Luanti server mods **cannot** bind arbitrary keys such as `P` — only the
control bits (`sneak`, `aux1`, `jump`, `zoom`, …). Remap **Special / aux1**
in Settings → Controls if E conflicts.

```
/hashimon yeet keyoff    # disable keybind
/hashimon yeet keyon     # enable again (default on)
/hashimon yeet 100       # QA launch at custom speed (server priv)
/hashimon yeet stop
```

### QA (requires `server` priv)

```
/hashimon yeet           # launch at default speed (40)
/hashimon yeet 80        # harder launch
/hashimon yeet enable    # also launch on punch
/hashimon yeet disable   # punch launch off (default)
```

### Tunables (`hashimon.*`)

| Constant | Default | Role |
|----------|---------|------|
| `IMPACT_LAUNCH_SPEED` | 40 | Default yeet speed (keybind + command) |
| `IMPACT_KEY_COOLDOWN` | 2.0 | Seconds between keybind launches |
| `impact_keybind_enabled` | true | Shift+E bind |
| `IMPACT_MIN_SPEED_FOR_BOOM` | 8 | Below this (and no residual), end flight |
| `IMPACT_BRAKE_PER_NODE` | 0.92 | Per solid node cleared (compounded) |
| `IMPACT_BRAKE_FLOOR` | 0.35 | Min velocity keep after one dig step |
| `IMPACT_BOOM_COOLDOWN` | 0.12 | Seconds between TNT FX |
| `IMPACT_MAX_FLIGHT_T` | 12 | Base max seconds (+ speed×0.02) |
| `IMPACT_MAX_RADIUS` | 3 | Tunnel cross-section cap |
| `IMPACT_MAX_TUNNEL` | 18 | Nodes bored along path per step |
| `impact_flight_enabled` | false | Punch → yeet |

High yeets (100–200) bore a **tunnel** ahead (`remove_node` on dirt and stone),
with optional `tnt.boom` for FX. Look-ahead scales with speed so you are not
stopped inside stone before dig runs. Protected nodes still hard-stop.

Creative-safe: flyer gets temporary `immortal` armor; TNT uses `damage_radius = 0`.

Battle suits / survival gates are **not** in this POC — validate feel first.

## Phase II evolve ritual

[`evolve_ritual.lua`](evolve_ritual.lua) — local morph via crystal ritual:
★11 titan, ★6 adult, or ★1 baby. Orbit radius **0.85**.

### In-game control (hold — beta)

Luanti **cannot** read raw letter keys on the server. Beta uses strafe + sneak
(hold ≥1s). **Z (zoom)** and **Space (jump)** stay free. Shift+E remains yeet.

| Hold ≥1s | Effect | Mnemonic |
|----------|--------|----------|
| **Shift + D** | ritual → ★11 titan | D = derecha / grande |
| **Shift + A** | ritual → ★1 baby | A = achicar |

```
/hashimon evolve titan    # ★11
/hashimon evolve baby     # ★1
/hashimon evolve ritual   # ★6 adult
/hashimon ritualkit       # optional Ascender/Baby tools
/hashimon evolve 11 1     # instant ★ bump, no VFX (server priv)
```

~1.6s mese crystal + orbiting shards → soft burst → respawn in place.
Cooldown 3s. Hotbar tools are **optional** (`/hashimon ritualkit`); not given on join.

Not saved to the API — `/hashimon sync` reverts. Skips if already at that stage,
mounted, or mid-impact yeet.

## Baby carry (on Bob / Sam)

[`baby_carry.lua`](baby_carry.lua) — baby ★1 attaches to the **player**.
With **Bob** ([`hashimon_players`](../hashimon_players/)): sockets
`Socket.Carry.Shoulder.R`, `.Head`, `.Neck`, `.Back` at seat `{0,0,0}`.
Sam fallback uses Arm/Head offsets if Bob is not loaded.

### Control

| Action | Effect |
|--------|--------|
| **Right-click** owned baby (≤8 nodes) | Toggle carry / drop |
| `/hashimon carry` | Toggle nearest baby |
| `/hashimon carry next` / `prev` | Cycle slot while carrying |
| `/hashimon carry off` | Drop |
| **Shift+Z** (sneak+zoom) | Carry next — only while carrying |
| **Shift+Space** (sneak+jump) | Carry off — only while carrying |
| `/hashimon avatar bob` | Apply Bob player mesh |

`guardian_baby` defaults to **shoulder_r** via `carry_view`.
`bloom_baby_air`: **head** / **shoulder_r**; scale ~0.9.
`beacon_baby_air`: **neck** (`perch_neck`); **visual_size_base = 2.76** (1:1 Bob); carry scale **1.0**.
`beacon_baby_water`: **shoulder** (no perch); hitbox.h **0.70**; scale ~0.9.
Bob carry slots use **rot.y = 180** so baby faces with Bob (`/hashimon carry rot` to calibrate).

Enable **hashimon_players** in Content so join replaces Sam with Bob.

