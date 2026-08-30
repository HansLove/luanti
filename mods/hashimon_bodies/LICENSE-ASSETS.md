# hashimon_bodies — referenced asset licences

This pack is the **MIT tier**: every mesh it references comes from a
permissively licensed mod, so it carries no copyleft or attribution obligation
onto Hashimon.

| Upstream mod | Licence | Bodies referenced |
|---|---|---|
| Animalia | MIT | canine, feline, ursine, equine, rodent, avian, amphibian, livestock, cervid |
| Draconis | MIT | dragon |
| marinaramobs | MIT | aquatic |
| xocean | MIT | aquatic |

No assets are copied here — those mods ship their own media and Luanti resolves
it globally. `bodies_mit_extra.lua` is generated from those mods' own
definitions (mesh names, frame ranges, hitboxes).

The GPL-3.0 and CC BY-SA 3.0 bodies live in separate optional mods on purpose:
`hashimon_bodies_paleo` and `hashimon_bodies_dmobs`. Keep it that way.

## Cuerpos propios (redistribuidos)

A diferencia del resto de este pack, que sólo **referencia** mallas que otro mod
instaló, estos archivos se distribuyen con el juego. Son autoría propia de
Hashimon y no arrastran ninguna obligación aguas arriba.

| Cuerpo | Archivos | Origen |
|---|---|---|
| `dragon_hatchling` | `models/hashimon_dragon_hatchling.glb`, `textures/hashimon_dragon_hatchling.png` | Autoría propia. Malla base generada con Meshy a partir de una imagen de concepto propia; riggeada y animada a mano. |

Todo `.glb` pasa por `scripts/glb_for_luanti.py` antes de entrar aquí.
