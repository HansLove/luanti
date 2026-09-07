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

24 fps. Inicio fijo, presupuesto ~30, hueco 10 (igual que cuerpos). stand/walk/sit
no se mueven. Clips 81–310: movilidad por Hashimon en hombro / impacto.

| Clip | Frames | Tipo | Uso |
|------|--------|------|-----|
| stand (idle) | 0–31 | ciclo | `player_api` |
| walk | 41–70 | ciclo | `player_api` |
| sit | 71–80 | ciclo corto | `player_api` (arte apuntaba 71–90) |
| run | 81–110 | ciclo | trote / sprint en suelo |
| fly | 121–150 | ciclo | vuelo de crucero |
| float | 161–190 | ciclo | hover en el sitio |
| takeoff | 201–230 | once | despegue |
| land | 241–270 | once | aterrizaje |
| impact_yeet | 281–310 | once | salir disparado por impacto alto |

Reserva / sockets: **311–390**. `player_api` solo usa stand/walk/sit/mine/lay;
los demás quedan registrados para override cuando un baby en hombro otorgue poder.

Source: `Documents/Blender/bob.glb` →

```
scripts/glb_for_luanti.py bob.glb out.glb --fps 24 --yaw 180 --expect-frames 310
```

(Usa `--expect-frames 390` si la pista ya cubre sockets más allá de 310.
Sin `--yaw 180` Bob mira a la cámara en 3ª persona.)

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
