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


## Defensa del dueño + cubo elemental

Dos piezas nuevas, un mismo modelo de agro:
[`defense.lua`](defense.lua) (comportamiento) y
[`element_cube.lua`](element_cube.lua) (proyectil).

### Defensa (estilo lobo de Minecraft)

Cuando al dueño **le pegan**, todos sus Hashimons spawneados toman al agresor
como objetivo durante `GUARD.memory` segundos: dejan de seguir, se acercan,
muerden a corta distancia y —si ya crecieron— lanzan cubos elementales desde
lejos. También agro al golpear directamente a un Hashimon, y *ofensivo*: a
quien golpea su dueño, lo golpea la manada.

Sueltan el objetivo cuando muere, sale del radio de agro, o la correa al dueño
se estira demasiado (los guardianes vuelven a casa, no se van de viaje).

Funciona en las cuatro capas de render: sprite y cuerpo voxel usan
`hashimon.step_guard` (velocidad directa); los cuerpos de morfología Creatura
guardan por utilidad con sus animaciones reales de walk/run/melee —
[`hashimon_bodies/guard.lua`](../hashimon_bodies/guard.lua), score **0.8**, por
encima de `tamed_stay` (0.5) y `follow_owner` (0.4): un Hashimon al que mandas
quedarse quieto defiende igual.

```
/hashimon guard            # estado
/hashimon guard off        # tus Hashimons quedan pasivos
/hashimon guard on         # vuelven a defender (default)
/hashimon guard server off # apaga la defensa en todo el servidor (priv server)
```

**Límite conocido:** el agro ofensivo sólo se dispara cuando el dueño golpea a
un **jugador** u otro Hashimon. Luanti no tiene callback global de golpe a
entidad, así que golpear a un mob cualquiera no llama a la manada.

### Cubo elemental (montado)

Montado, **clic izquierdo** lanza un cubo del elemento de la montura, con
enfriamiento `hashimon.CUBE_COOLDOWN` (1.2s). `/hashimon fire` hace lo mismo, y
sin montura lo lanza el Hashimon más cercano.

No es el `blast_orb` de [`attack.lua`](attack.lua): ése llama a `tnt.boom` y se
come el terreno. El cubo **sólo hace daño** — nunca toca un nodo, así que se
puede disparar dentro del pueblo.

| Elemento | Color | Opacidad | Daño base | Velocidad | Efecto extra |
|----------|-------|----------|-----------|-----------|--------------|
| fuego | `#F97316` | opaco | 6 | 22 | quema 3 ticks (2 dmg) |
| agua | `#3B82F6` | translúcido (140) | 4 | 24 | empuje fuerte + lento 0.72 / 2.5s |
| hielo | `#BAE6FD` | translúcido (170) | 5 | 26 | lento 0.45 / 3s |
| tierra | `#92400E` | opaco | 7 | 16 | — |
| eléctrico | `#EAB308` | 205 | 5 | 30 | aturde (0.3) 1.2s |
| aire | `#67E8F9` | translúcido (110) | 3 | 28 | empuje 11 + elevación |
| resto (pixel, onda, astro…) | color del tipo | 205 | 4 | 22 | — |

Daño escalado por ★ (×1 → ×2.4 como techo). Los efectos de lento/aturdir sólo
se aplican a **jugadores** (vía `physics_override`) y se omiten si la víctima va
montada, para no pelear con la física de la montura.

### Tunables (`hashimon.GUARD.*`)

| Constante | Default | Rol |
|-----------|---------|-----|
| `memory` | 12 | Segundos que el guardián recuerda al objetivo |
| `aggro_radius` | 20 | Distancia a la que suelta al objetivo |
| `leash` | 26 | Distancia máxima al dueño antes de volver |
| `melee_range` | 2.6 | Alcance del mordisco |
| `melee_damage` | 4 | Daño base del mordisco (antes de ★) |
| `melee_interval` | 1.0 | Segundos entre mordiscos |
| `approach_speed` | 6.5 | Nodos/s al cerrar distancia |
| `ranged_min_range` | 6 | Distancia mínima para lanzar cubos |
| `ranged_cooldown` | 2.5 | Segundos entre cubos del guardián |
| `ranged_stage_min` | 3 | ★ mínima para atacar a distancia |
| `guard_stage_min` | 1 | ★ mínima para pelear (un huevo no pelea) |
