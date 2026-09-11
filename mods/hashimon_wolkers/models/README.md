# Assets de wolker — contrato para Blender

Tres piezas de lego cubren toda la población. **Nada más se autoriza por wolker:** el
servidor manda `model` en el padrón y el mundo carga esa pieza, así que un asset nuevo
sirve a miles de habitantes y ninguno necesita el suyo.

| Archivo | Quién es | Cuándo aparece |
|---|---|---|
| `wolker_pos.glb` + `wolker_pos.png` | Signo **positivo** — hombre | Adulto con `sign = +1` |
| `wolker_neg.glb` + `wolker_neg.png` | Signo **negativo** — mujer | Adulto con `sign = −1` |
| `wolker_small.glb` + `wolker_small.png` | Cría, de cualquier signo | Menos de 30 días de vida |

El signo sale del hash del wolker (byte 3), no de una elección: mitad y mitad, sin que el
jugador pueda inclinar la balanza. La cría **conserva su signo** aunque comparta cuerpo —
al cumplir 30 días cambia sola al modelo adulto que le toca, sin recargar nada.

Los `.png` van en `../textures/`, no aquí.

---

## 1. Lo que no es negociable

**Un solo esqueleto para las tres piezas.** Es lo que hace que esto sea lego: una animación
nueva vale para hombre, mujer y cría a la vez. Si la cría tiene su propia jerarquía de
huesos, cada animación futura cuesta el triple.

Huesos mínimos, con los nombres del [estándar de esqueleto](../../../docs/SKELETON_STANDARD_V1.md):

```
Root
└── Torso
    ├── Head
    ├── Arm.L   Arm.R
    └── Leg.L   Leg.R
```

Sockets (huesos sin geometría ni peso, sólo puntos de montaje). No hacen falta para la
primera entrega, pero si están, el mod podrá colgar herramientas de oficio y cascos de
milicia sin volver a tocar el modelo:

```
Socket.Head    → cascos, sombreros de oficio
Socket.Hand.R  → azada, martillo, lanza
Socket.Back    → fardos, leña, sacos de croquetas
```

## 2. Medidas y orientación

- **Escala:** 1 nodo de Luanti = 1 metro. Adulto ≈ **1.75 m**, cría ≈ **1.0 m**.
  Las cajas de colisión del mod ya asumen esas alturas ([`../entity.lua`](../entity.lua)).
- **Origen:** entre los pies, en el suelo (Y = 0). Un origen en la cadera hace que el
  wolker floté o se hunda medio cuerpo.
- **Orientación:** el modelo mira hacia **+Z** con Y arriba (aplica transformaciones antes
  de exportar: rotación y escala congeladas).
  ⚠️ *Lo único a verificar en la primera importación:* si sale caminando de espaldas, se
  arregla con `automatic_face_movement_dir` en `entity.lua` (hoy `90.0`) — un número, no un
  reexport.
- **Presupuesto:** ≤ 1.500 triángulos por pieza. Puede haber veinte a la vista a la vez.
- **Material:** **uno solo** por pieza, una textura, sin PBR ni nodos. Luanti la aplica como
  `textures = { "wolker_pos.png" }`. Textura 64×64 o 128×128, PNG.

## 3. Animaciones — el contrato de fotogramas

Una sola línea de tiempo por modelo, con los rangos exactos. El mod los lee de
`hashimon_wolkers.ANIM` en [`../entity.lua`](../entity.lua) y **no los adivina**:

| Estado | Fotogramas | Qué se ve |
|---|---|---|
| `stand` | **0 – 40** (entregado: 1 – 30) | quieto, respirando |
| `walk` | **41 – 80** (entregado: 41 – 70) | caminar en bucle (se reproduce a 24 fps) |
| `work` | **81 – 120** | agacharse/golpear: labrar, martillear |
| `panic` | **121 – 160** | correr asustado, brazos arriba |
| `sleep` | **161 – 200** | tumbado, en bucle |

Los rangos son **inclusivos** y todos en bucle. Si una pieza llega sin alguno, el wolker se
queda quieto en ese estado pero sigue vivo y funcionando — nada peta por una animación que
falta, así que se puede entregar `stand` + `walk` primero y el resto después.

**Entrega actual (2026-09-10):** las tres piezas traen `stand` 1–30 y `walk` 41–70
(arrancan en el mismo sitio del contrato; el presupuesto usado es 30 fotogramas, el hueco
31–40 no se reproduce). `work` / `panic` / `sleep` aún no están en la pista.

## 4. Exportar desde Blender

1. Aplica transformaciones (`Ctrl+A` → Rotation & Scale) al mesh y a la armadura.
2. Nombra los huesos exactamente como arriba (mayúsculas y puntos incluidos).
3. Exporta **glTF binario (.glb)**: incluir *Selected Objects*, *+Y Up* **desactivado**
   (Luanti usa Y arriba), animación *Always Sample Animations*, una sola acción en la
   línea de tiempo con los rangos de la tabla.
4. Copia el `.glb` a esta carpeta y el `.png` a `../textures/`, con los nombres exactos.
5. En el juego: `/wolkers_genesis` en tu town para la camada inicial, y acércate al
   homeblock — los cuerpos aparecen solos en cuanto hay alguien cerca.

## 5. Entrega actual

`wolker_pos.glb` (Niko), `wolker_neg.glb` (Noemi) y `wolker_small.glb` (Nani) viven aquí,
pasados por `scripts/glb_for_luanti.py --yaw 180 --expect-frames 70`. Las PNG van en
`../textures/`. Reinicia el mundo: `/wolkers_genesis` en tu town y acércate al homeblock
(≤ 96 nodos). Sin jugador cerca no hay entidades; el censo sigue en la API.

### Lo que dicen los propios `.glb`

Medido sobre los archivos entregados (no sobre el contrato), porque son cosas que sólo se
ven abriendo el binario:

1. **Escala, y un factor escondido en la cría.** Las mallas miden 6.26 u (Niko), 7.45 u
   (Noemi) y 3.06 u (Nani). Luanti dibuja 10 u = 1 nodo, de ahí los cocientes de `VISUAL` en
   [`../entity.lua`](../entity.lua). Pero el `.glb` de Nani lleva una **escala de 0.619 sin
   aplicar en su nodo `Armature`**, que las juntas heredan: en pantalla no mide 3.06 sino
   1.90. Su `visual_size` está puesto a **5.27** contando ese factor.
   *Lo único que hay que mirar en el mundo:* ponte al lado de Nani. Si te llega al pecho
   (≈ 1 nodo) está bien; si te saca cabeza (≈ 1.6), el factor no se aplicaba y el número
   correcto es 3.27. La cura definitiva es un `Ctrl+A → Scale` sobre la armadura al exportar
   —el paso 1 de arriba—, y entonces el AABB vuelve a ser toda la verdad.
2. **Los tres esqueletos no son el mismo.** `wolker_pos` no tiene `Torso` y sí `Socket.Head`;
   los otros dos tienen `Torso` y no el socket. Y los nombres divergen: `Arm.L.2` · `Arm.L2` ·
   `Arm.L.001`, más ocho huesos sin nombrar (`Bone.003`…`Bone.011`). Hoy funciona porque cada
   pieza trae su animación horneada, pero **la promesa lego no se cumple todavía**: una
   animación nueva no servirá para las tres, y un escalado de huesos por ADN leería nombres
   que en dos de cada tres piezas no existen. Es trabajo de Blender, no de código.
3. **Rangos y giro, ya resueltos por el pipeline.** `glb_for_luanti.py` multiplica los
   tiempos de keyframe por los fps —por eso la pista va de 1 a 70 y `ANIM` puede hablar de
   fotogramas— y envuelve la escena en un nodo `LuantiFacing` con el yaw 180. Ese giro ya
   está en el asset, así que si aun así caminan de espaldas, el número a cambiar en
   `entity.lua` es `automatic_face_movement_dir` (hoy `90.0`) y el candidato es `-90`: lo que
   el envoltorio ya giró hay que descontarlo aquí.
