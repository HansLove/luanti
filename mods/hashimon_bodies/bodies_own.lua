-- Cuerpos PROPIOS de Hashimon.
--
-- Distinto en naturaleza al resto del pack. Los demás archivos sólo REFERENCIAN
-- mallas que otro mod ya instaló (animalia_wolf.b3d y compañía) y por eso no
-- redistribuyen nada. Estos SÍ se distribuyen con el juego: los autoramos
-- nosotros y los poseemos por completo, sin obligación aguas arriba.
--
-- Es la capa que encoge la superficie GPL/CC del proyecto: cada cuerpo propio
-- que cubre una familia huérfana es una dependencia menos.
--
-- NOTAS DE glTF (ver 3d-world/doc/lua_api.md, sección glTF):
--
--   * `speed` NO es fps aquí como en los .b3d. En glTF los timestamps SON los
--     números de frame, así que la velocidad es "frames por segundo" respecto a
--     esa numeración. El modelo se autoró a 24 fps y scripts/glb_for_luanti.py
--     reescaló los tiempos a 1..50, de modo que speed = 24 reproduce el ritmo
--     original y los rangos se leen como los frames de Blender.
--   * El .glb pasa SIEMPRE por scripts/glb_for_luanti.py antes de entrar aquí:
--     corrige los tiempos, deja una sola textura (el base color) y borra las
--     imágenes embebidas, que Luanti no soporta y pesaban 6.9 MB de los 7.0.
--   * `--yaw 180` es OBLIGATORIO. Blender exporta mirando a su -Y, que es el
--     "frente" estándar de Blender y en glTF cae en +Z; Luanti espera lo
--     contrario, así que sin la rotación la criatura camina de espaldas. Se
--     detectó en el dragón y en el osezno por separado antes de dar con la
--     causa. La herramienta lo aplica envolviendo la escena en un nodo rotado,
--     no tocando vértices, para que el esqueleto gire con la malla.

-- ---------------------------------------------------------------------------
-- DRAGON — cría propia. Es el tier 1 que a la línea Crown le faltaba:
-- antes, su cuerpo más bajo era el wyvern de 1.51 nodos, así que un jugador de
-- stage 1 aparecía montado en un dragón adulto.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "dragon_hatchling",
	family = "dragon",
	mesh = "hashimon_dragon_hatchling.glb",
	textures = { "hashimon_dragon_hatchling.png" },
	-- Rig completo del estándar: los diez huesos, `Tail` incluida. Fue el primer
	-- asset propio y en su primera versión le faltaba, así que su `tailScale`
	-- —el rasgo más visible en un dragón— no llegaba a ningún hueso.
	bones = {
		head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R",
		leg_l = "Leg.L", leg_r = "Leg.R",
		wing_l = "Wing.L", wing_r = "Wing.R",
	},
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.35, height = 0.6 },
	mesh_height = 3.62,
	makes_footstep_sound = true,
})

-- ---------------------------------------------------------------------------
-- URSINE — osezno propio. El tier 1 que a la línea Guardian le faltaba: antes,
-- su cuerpo más bajo era un oso ADULTO de 1.00 nodos, así que un jugador de
-- stage 1 empezaba ya con la forma final de su especie.
--
-- Los huesos venían del auto-rig con nombres genéricos (Bone, Bone.001...) y se
-- renombraron con `glb_for_luanti.py --rename`. El mapeo salió de la jerarquía,
-- no de adivinar: Head es el hueso más alto y adelantado, Torso el que ramifica
-- en las dos patas traseras, y cada cadena descendente es un miembro. Cuál pata
-- es izquierda y cuál derecha da igual: proportions.lua aplica el mismo
-- multiplicador a las cuatro.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "ursine_cub",
	family = "ursine",
	mesh = "hashimon_ursine_cub.glb",
	textures = { "hashimon_ursine_cub.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.50 },
	mesh_height = 4.98,
	makes_footstep_sound = true,
})

-- ---------------------------------------------------------------------------
-- EQUINE — potro propio. Etapa A del linaje Road, que hasta ahora empezaba en
-- un cerdo adulto de 0.70 nodos. Es el primer cuerpo autorado ya contra el
-- estándar de esqueleto: trae `Tail` (que faltaba en el dragón y el osezno) y
-- hasta las orejas del nivel 3 opcional.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "equine_foal",
	family = "equine",
	mesh = "hashimon_equine_foal.glb",
	textures = { "hashimon_equine_foal.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.25, height = 0.45 },
	mesh_height = 4.37,
	makes_footstep_sound = true,
})

-- ---------------------------------------------------------------------------
-- ARTHROPOD — mantis cría. Etapa A de Bloom.
--
-- Primer cuerpo hexápodo del catálogo: trae `Limb.M.L/R`, el par medio del
-- estándar nivel 3, y por él se amplió LIMB_KEYS en proportions.lua.
-- Su `Torax` se mapea a `torso` — el nombre anatómico correcto para un insecto
-- no coincide con el genérico del sistema, y esa traducción vive aquí.
--
-- La textura mide sd 0.132, por debajo del umbral de check_texture_contrast.
-- Verificado en render bajo cuatro tintes: se lee perfectamente. El umbral está
-- calibrado sobre pelaje de mamífero; aquí el contraste lo lleva la geometría
-- facetada. Se registra SIN el rescate `contrast`, a propósito.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "arthropod_mantis_baby",
	family = "arthropod",
	mesh = "hashimon_arthropod_mantis_baby.glb",
	textures = { "hashimon_arthropod_mantis_baby.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		limb_m_l = "Limb.M.L", limb_m_r = "Limb.M.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 29 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.19, height = 0.35 },
	mesh_height = 6.77,
	makes_footstep_sound = true,
})

-- ---------------------------------------------------------------------------
-- SERPENTINE — serpezuela. Etapa A de Key, y el PRIMER cuerpo que existe para
-- ese signo: hasta ahora Key vestía roedores y un canguro prehistórico.
--
-- Familia nueva. Ningún mod instalado tiene topología serpentina, así que no
-- había reutilización honesta posible.
--
-- Sin extremidades: declara sólo cuatro huesos, y proportions.lua omite las
-- claves ausentes sin quejarse. `torso` y `tail` se mapean a segmentos MEDIOS de
-- la cadena (era Bone.008 y Bone.013 de trece), no a su raíz: escalar el primer
-- segmento propagaría la escala a toda la cadena hija y estiraría la serpiente
-- entera. Un soporte serpentino de verdad necesita `Spine.01..NN`
-- (docs/SKELETON_STANDARD_V1.md §1.3), que el sistema todavía no lee.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "serpentine_snakelet",
	family = "serpentine",
	mesh = "hashimon_serpentine_snakelet.glb",
	textures = { "hashimon_serpentine_snakelet.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.35 },
	mesh_height = 11.40,
	makes_footstep_sound = false,
})

-- ---------------------------------------------------------------------------
-- CHELONIAN — cría de tortuga. Etapa A de Bastion.
--
-- Bastion tenía UN solo cuerpo (chelonian_tortoise, 0.30, sin animación
-- `stand`) y su línea se completaba con triceratops, estegosaurio y
-- braquiosaurio prestados. Ésta es la primera pieza de su línea propia.
-- Sin `Neck`: la cabeza va directa al caparazón, y proportions.lua omite la
-- clave ausente sin quejarse.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "chelonian_hatchling",
	family = "chelonian",
	mesh = "hashimon_chelonian_hatchling.glb",
	textures = { "hashimon_chelonian_hatchling.png" },
	bones = { head = "Head", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.35 },
	mesh_height = 2.31,
	makes_footstep_sound = true,
})

-- ---------------------------------------------------------------------------
-- APE — simio juvenil. Etapa A de Forge, y familia nueva.
--
-- Forge vestía gnomos de piedra y ogros: `construct` y `humanoid`. Un simio no
-- es ninguna de las dos, así que `ape` se crea con este cuerpo.
--
-- Sin `Tail`, y es CORRECTO: el plan antropomorfo del estándar es el único
-- donde omitirla es lo anatómicamente cierto.
--
-- `contrast` sí es necesario aquí. La textura mide sd 0.125 y media 0.28
-- —pelaje oscuro y uniforme, el mismo perfil que obligó a rescatar a bat, bear
-- y owl—. Comparado en render con y sin el pre-paso: con él, cara, pecho y
-- manos ganan separación real. Los valores son los mismos que ya usan los otros
-- tres, y quedan pendientes de un vistazo en juego: la previsualización usó una
-- aproximación del operador, no el operador del motor.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "ape_juvenile",
	family = "ape",
	mesh = "hashimon_ape_juvenile.glb",
	textures = { "hashimon_ape_juvenile.png" },
	contrast = { 90, 40 },
	bones = { head = "Head", neck = "Neck", torso = "Torso",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.32, height = 0.55 },
	mesh_height = 14.00,
	makes_footstep_sound = true,
})

-- ---------------------------------------------------------------------------
-- Etapa A de los cinco linajes que aún vestían adultos pequeños.
--
-- Los rigs llegaron con nombres genéricos (el lobo con CERO huesos del
-- estándar), así que el mapeo se dedujo de la jerarquía: el hueso más alto y
-- adelantado es la cabeza, el que ramifica en las dos patas traseras es el
-- torso, y cada cadena descendente un miembro. Izquierda y derecha son
-- intercambiables: proportions.lua aplica el mismo multiplicador a todas.
-- ---------------------------------------------------------------------------

hashimon_bodies.register_creatura_body({
	id = "canine_pup",
	family = "canine",
	mesh = "hashimon_canine_pup.glb",
	textures = { "hashimon_canine_pup.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.20, height = 0.30 },
	mesh_height = 3.16,
	makes_footstep_sound = true,
})

hashimon_bodies.register_creatura_body({
	id = "feline_catling",
	family = "feline",
	mesh = "hashimon_feline_catling.glb",
	textures = { "hashimon_feline_catling.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.18, height = 0.28 },
	mesh_height = 7.18,
	makes_footstep_sound = true,
})

hashimon_bodies.register_creatura_body({
	id = "avian_fledgling",
	family = "avian",
	mesh = "hashimon_avian_fledgling.glb",
	textures = { "hashimon_avian_fledgling.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	-- Un polluelo NO vuela. Es la etapa A de Beacon, el único linaje con `fly`
	-- verificado en B y C: que la cría no lo tenga es la progresión, no una carencia.
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.16, height = 0.25 },
	mesh_height = 7.43,
	makes_footstep_sound = true,
})

hashimon_bodies.register_creatura_body({
	id = "theropod_hatchling",
	family = "theropod",
	mesh = "hashimon_theropod_hatchling.glb",
	textures = { "hashimon_theropod_hatchling.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.20, height = 0.32 },
	mesh_height = 5.00,
	makes_footstep_sound = true,
})

-- Primer cuerpo con hueso de aleta. `Fin.T` es la dorsal, y por él se ampliaron
-- las LIMB_KEYS con fin_l/fin_r/fin_t. Sin patas: declara siete claves y
-- proportions.lua omite las ausentes.
hashimon_bodies.register_creatura_body({
	id = "aquatic_calf",
	family = "aquatic",
	mesh = "hashimon_aquatic_calf.glb",
	textures = { "hashimon_aquatic_calf.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", fin_t = "Fin.T" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = true, mount = false },
	hitbox = { width = 0.25, height = 0.35 },
	mesh_height = 4.02,
	makes_footstep_sound = false,
})

-- ---------------------------------------------------------------------------
-- URSINE · AIRE — etapa B del Guardian de aire. PRIMER CUERPO DE LA CAPA V2.
--
-- Hasta aquí el elemento sólo sesgaba color y proporciones; el cuerpo lo
-- decidían linaje y etapa. Éste es el primero que un elemento SELECCIONA:
--
--   `element`   sólo lo viste una criatura de aire. Para las demás no existe.
--   `replaces`  sustituye al oso genérico en su peldaño en vez de sumarse,
--               o ambos competirían por el mismo destino.
--
-- Trae `Socket.Tail`, el primer socket del proyecto. Todavía no hay
-- `Socket.Back`, así que un ala montada no tiene dónde anclarse: sus alas
-- tendrían que ir en el rig como `Wing.L/R`, que este cuerpo aún no declara.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "ursine_bear_air",
	family = "ursine",
	element = "aire",
	replaces = "ursine_bear",
	mesh = "hashimon_ursine_bear_air.glb",
	textures = { "hashimon_ursine_bear_air.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.55, height = 1.00 },
	mesh_height = 11.12,
	makes_footstep_sound = true,
})
