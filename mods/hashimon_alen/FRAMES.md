# Hoja de animación de Alen Gregory

Qué animar en Blender, en qué rango exacto, y por qué ese rango.

## La regla que hay que tener presente

El cargador glTF de Luanti guarda el **timestamp en segundos** como número de
frame (`irr/src/CGLTFMeshFileLoader.cpp:657`; documentado en `doc/lua_api.md:437`).
Los frames de Blender no se usan tal cual. Tú animas en frames, `body.lua` declara
frames, y la división por `FPS = 24` ocurre en un solo sitio.

Consecuencia: **el export tiene que seguir siendo a 24 fps.** Si cambias los fps
del proyecto de Blender, cambia `hashimon_alen.FPS` en `body.lua` y nada más.

## Rangos

Hay 10 frames de hueco entre clip y clip a propósito: la mezcla (`blend`) de
Luanti interpola hacia el frame destino, y sin margen sangra el final de un clip
sobre el principio del siguiente.

| Clip | Frames Blender | Dur. | Cicla | Qué es |
|---|---|---|---|---|
| `walk` | 41 – 70 | 1.25 s | sí | ✅ ya está |
| `run` | 81 – 110 | 1.25 s | sí | ✅ ya está |
| `fly` | 121 – 150 | 1.25 s | sí | ✅ ya está |
| `idle` | 161 – 220 | 2.50 s | sí | Respiración, cola, parpadeo. Largo a propósito: es lo que más se ve. |
| `hover` | 231 – 260 | 1.25 s | sí | Aleteo sostenido sin avanzar. Lo usa al encarar antes de escupir. |
| `fly_fast` | 271 – 300 | 1.25 s | sí | Alas plegadas, cuerpo estirado. Se reproduce a 1.9×. |
| `hurt` | 311 – 325 | 0.63 s | no | Sacudida corta. Corto es mejor: interrumpe lo que esté haciendo. |
| `breath` | 336 – 365 | 1.25 s | no | Cuello atrás y escupir. El fuego sale a mitad del clip. |
| `roar` | 376 – 405 | 1.25 s | no | Telegrafía. Se dispara **antes** del primer aliento contra alguien. |
| `takeoff` | 416 – 435 | 0.83 s | no | Despegue desde el suelo. |
| `land` | 446 – 465 | 0.83 s | no | Aterrizaje y plegado de alas. |
| `death` | 476 – 535 | 2.50 s | **no** | La caída. Debe terminar en pose de suelo — no cicla y se queda en el último frame. |
| `jump_charge` | 546 – 565 | 0.83 s | no | Carga del salto de bloque. Al terminar, desaparece. |

Los que ciclan **tienen que verse idénticos en el primer y el último frame**: Luanti
no interpola de vuelta al inicio en un bucle, así que una diferencia ahí se ve como
un tirón cada vuelta.

## Cómo activarlos

Los clips que faltan están declarados en `body.lua` con `have = false`. El juego ya
funciona: cada estado cae a una alternativa. Cuando animes uno en su rango, pon
`have = true` y el estado se enciende solo.

Dentro del juego, `/alen frames` lista qué falta y qué está tirando de alternativa,
y `/alen anim <estado>` reproduce cualquiera para revisarlo.

## Alternativas mientras tanto

Los estados **cíclicos** siempre aceptan alternativa — para eso es la cadena:

- `idle` → `walk` **congelado en su primer frame** (una pose quieta, no un paseo)
- `hover` → `fly` a 0.45×
- `fly_fast` → `fly` a 1.9×
- `run` → `walk`

Los **de un solo disparo** por defecto **no** aceptan alternativa: se saltan. Un
golpe o un despegue sin su beat propio no aporta nada y encima bloquearía el
estado base mientras dura. Las tres excepciones están marcadas `fallback = true`
porque ahí sí vale la pena: `death`→`hurt`, `breath`↔`roar`, `jump_charge`→`roar`.

## Prioridades

Un `once` en curso bloquea el estado base y sólo lo interrumpe otro `once` de
prioridad igual o mayor:

```
death 9  >  hurt 5  >  jump_charge 4  >  breath/roar 3  >  takeoff/land 2
```

Es por lo que un dragón al que golpean acusa el golpe en vez de volver a aletear a
media sacudida, y por lo que la muerte gana siempre.
