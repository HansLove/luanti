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
| `stand` | **0 – 40** | quieto, respirando |
| `walk` | **41 – 80** | caminar en bucle (se reproduce a 24 fps) |
| `work` | **81 – 120** | agacharse/golpear: labrar, martillear |
| `panic` | **121 – 160** | correr asustado, brazos arriba |
| `sleep` | **161 – 200** | tumbado, en bucle |

Los rangos son **inclusivos** y todos en bucle. Si una pieza llega sin alguno, el wolker se
queda quieto en ese estado pero sigue vivo y funcionando — nada peta por una animación que
falta, así que se puede entregar `stand` + `walk` primero y el resto después.

## 4. Exportar desde Blender

1. Aplica transformaciones (`Ctrl+A` → Rotation & Scale) al mesh y a la armadura.
2. Nombra los huesos exactamente como arriba (mayúsculas y puntos incluidos).
3. Exporta **glTF binario (.glb)**: incluir *Selected Objects*, *+Y Up* **desactivado**
   (Luanti usa Y arriba), animación *Always Sample Animations*, una sola acción en la
   línea de tiempo con los rangos de la tabla.
4. Copia el `.glb` a esta carpeta y el `.png` a `../textures/`, con los nombres exactos.
5. En el juego: `/wolkers_genesis` en tu town para la camada inicial, y acércate al
   homeblock — los cuerpos aparecen solos en cuanto hay alguien cerca.

## 5. Marcadores de trabajo en curso

Mientras no existan los `.glb`, el mod registra las entidades igual y Luanti mostrará un
cubo por cada wolker: **la lógica no espera a los assets**. Se puede probar el padrón, la
FSM y el consejo con cubos, y cambiar de cubo a wolker sin tocar una línea de código.
