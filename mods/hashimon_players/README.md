# hashimon_players

Native player avatars for Hashimon. **Bob** replaces Minetest Game Sam on join
via `player_api.set_model`.

## Enable

Content tab → enable **hashimon_players**, or in `world.mt`:

```
load_mod_hashimon_players = true
```

Depends: `player_api`, `hashimon_core`.

## Bob clips (`hashimon_bob.glb`)

| Clip | Frames |
|------|--------|
| stand (idle) | 0–31 |
| walk | 41–70 |
| sit | 71–80 (art aimed 71–90; re-export when sit is extended) |

Track may extend past 80 (e.g. to 390); player_api only uses the clips above.

Source: `Documents/Blender/bob.glb` →
`scripts/glb_for_luanti.py --fps 24 --expect-frames 390 --yaw 180`
(Luanti third-person expects the mesh facing −Z; without `--yaw 180` Bob looks at the camera.)

## Commands

```
/hashimon avatar          # show current
/hashimon avatar bob      # apply Bob
```

## Skins (importante)

Sam usa un atlas `character.png` (UV estilo Steve). **Bob no.** Su textura es
`hashimon_bob.png` pintada para su propio UV.

El mod `3d_armor` intentaba mezclar capas Sam (`skin` + armadura) sobre la malla
de Bob — eso se veía como un cuerpo “embutido” sin el color de Bob. Hashimon
bloquea ese override mientras el avatar nativo está activo.

Skins futuras de Bob = texturas completas alternativas del mismo UV, no skins
de la tienda Sam/i3.
