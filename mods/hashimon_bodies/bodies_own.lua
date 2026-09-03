-- Cuerpos PROPIOS de Hashimon.
--
-- CONVENCIÓN DE NOMBRE
--
--     hashimon_<signo>_<etapa>[_<elemento>].glb
--
--     hashimon_guardian_baby.glb        universal, sirve a los cinco elementos
--     hashimon_guardian_adult.glb       universal
--     hashimon_guardian_adult_air.glb   variante elemental (capa V2)
--     hashimon_guardian_apex_fire.glb
--
-- El `id` del registro es el nombre sin el prefijo: `guardian_adult_air`. Ese
-- mismo identificador nombra el archivo del mod, el de la web y la clave de
-- SPIRIT_BABY_MODEL en spirits.ts, para que no haya traducciones intermedias.
--
-- Sin elemento = universal. Con elemento = variante que SUSTITUYE al universal
-- de su peldaño (campo `replaces`), no que se suma a él.
--
-- ELEMENTOS EN INGLÉS EN EL ARCHIVO, en español en el campo `element`:
--
--     fire · water · air · earth · electric
--
-- Esa asimetría es deliberada, no un descuido. El identificador interno del
-- elemento ("aire") está dentro del preimagen del ADN vía la speciesKey
-- g2_<signo>_<elemento>; cambiarlo cambiaría el ADN de toda criatura viva y
-- rompería su PoW. El nombre de archivo no tiene esa atadura, así que va en
-- inglés como el resto del código.
--
-- Si falta el archivo de una celda, el sistema cae al universal de su etapa y,
-- si tampoco existe, a la etapa anterior. La ausencia es el caso normal
-- mientras el grafo se llena; sólo el fallback debe ser la excepción.
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
	id = "crown_baby",
	family = "dragon",
	mesh = "hashimon_crown_baby.glb",
	textures = { "hashimon_crown_baby.png" },
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
	hitbox = { width = 0.52, height = 0.90 },
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
	id = "guardian_baby",
	family = "ursine",
	mesh = "hashimon_guardian_baby.glb",
	textures = { "hashimon_guardian_baby.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.45, height = 0.75 },
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
	id = "road_baby",
	family = "equine",
	mesh = "hashimon_road_baby.glb",
	textures = { "hashimon_road_baby.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.38, height = 0.68 },
	mesh_height = 4.37,
	makes_footstep_sound = true,
})

-- ---------------------------------------------------------------------------
-- EQUINE — adulto propio. Etapa B del linaje Road.
--
-- Sustituye al caballo MIT (`equine_horse`) en el peldaño desarrollado.
-- GLB: adult-road-2.blend → glb_for_luanti.py --yaw 180 --expect-frames 110
-- (idle 1–30, walk 41–70, run 81–110). Socket.Mount hijo de Torso, calibrado
-- en Blender para el jinete — seat ≈ {0,0,0}; rider_scale sigue compensando
-- la multiplicación de visual_size del motor al attach.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "road_adult",
	family = "equine",
	replaces = "equine_horse",
	mesh = "hashimon_road_adult.glb",
	textures = { "hashimon_road_adult.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, run = 30 }),
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
	hitbox = { width = 0.75, height = 1.60 },
	mesh_height = 10.21,
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 12, z = 2 },
		eye_third = { x = 0, y = 12, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.45,
		suggest_camera = "third",
	},
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
	id = "bloom_baby",
	family = "arthropod",
	mesh = "hashimon_bloom_baby.glb",
	textures = { "hashimon_bloom_baby.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		limb_m_l = "Limb.M.L", limb_m_r = "Limb.M.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 29 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.55 },
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
	id = "key_baby",
	family = "serpentine",
	mesh = "hashimon_key_baby.glb",
	textures = { "hashimon_key_baby.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.45, height = 0.55 },
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
	id = "bastion_baby",
	family = "chelonian",
	mesh = "hashimon_bastion_baby.glb",
	textures = { "hashimon_bastion_baby.png" },
	bones = { head = "Head", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.45, height = 0.55 },
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
	id = "forge_baby",
	family = "ape",
	mesh = "hashimon_forge_baby.glb",
	textures = { "hashimon_forge_baby.png" },
	contrast = { 90, 40 },
	bones = { head = "Head", neck = "Neck", torso = "Torso",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.48, height = 0.83 },
	mesh_height = 14.00,
	makes_footstep_sound = true,
})

-- ---------------------------------------------------------------------------
-- Etapa A de los cinco linajes que aún vestían adultos pequeños.
--
-- Hitbox de bebés: mínimo ~0.55 de alto (×~1.5 vs la primera pasada). Por debajo
-- de eso el mesh queda inapuntabile / imposible de cargar a stage 1.
--
-- Los rigs llegaron con nombres genéricos (el lobo con CERO huesos del
-- estándar), así que el mapeo se dedujo de la jerarquía: el hueso más alto y
-- adelantado es la cabeza, el que ramifica en las dos patas traseras es el
-- torso, y cada cadena descendente un miembro. Izquierda y derecha son
-- intercambiables: proportions.lua aplica el mismo multiplicador a todas.
-- ---------------------------------------------------------------------------

hashimon_bodies.register_creatura_body({
	id = "hearth_baby",
	family = "canine",
	mesh = "hashimon_hearth_baby.glb",
	textures = { "hashimon_hearth_baby.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.55 },
	mesh_height = 3.16,
	makes_footstep_sound = true,
})

hashimon_bodies.register_creatura_body({
	id = "mirror_baby",
	family = "feline",
	mesh = "hashimon_mirror_baby.glb",
	textures = { "hashimon_mirror_baby.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.55 },
	mesh_height = 7.18,
	makes_footstep_sound = true,
})

hashimon_bodies.register_creatura_body({
	id = "beacon_baby",
	family = "avian",
	-- Etapa A propia; saca al songbird MIT del peldaño Genesis.
	replaces = "avian_songbird",
	mesh = "hashimon_beacon_baby.glb",
	textures = { "hashimon_beacon_baby.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	-- Un polluelo NO vuela. Es la etapa A de Beacon, el único linaje con `fly`
	-- verificado en B y C: que la cría no lo tenga es la progresión, no una carencia.
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.55 },
	mesh_height = 7.43,
	makes_footstep_sound = true,
})

hashimon_bodies.register_creatura_body({
	id = "edge_baby",
	family = "theropod",
	mesh = "hashimon_edge_baby.glb",
	textures = { "hashimon_edge_baby.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.55 },
	mesh_height = 5.00,
	makes_footstep_sound = true,
})

-- Primer cuerpo con hueso de aleta. `Fin.T` es la dorsal, y por él se ampliaron
-- las LIMB_KEYS con fin_l/fin_r/fin_t. Sin patas: declara siete claves y
-- proportions.lua omite las ausentes.
hashimon_bodies.register_creatura_body({
	id = "depth_baby",
	family = "aquatic",
	mesh = "hashimon_depth_baby.glb",
	textures = { "hashimon_depth_baby.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", fin_t = "Fin.T" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = true, mount = false },
	hitbox = { width = 0.38, height = 0.55 },
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
	id = "guardian_adult_air",
	family = "ursine",
	element = "aire",
	replaces = "ursine_bear",
	mesh = "hashimon_guardian_adult_air.glb",
	textures = { "hashimon_guardian_adult_air.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.55, height = 1.00 },
	mesh_height = 11.12,
	makes_footstep_sound = true,
})

-- ---------------------------------------------------------------------------
-- CAPA V2 · BLOOM AIRE — oruga y su imago.
--
-- Para un Bloom de aire la mantis genérica deja de existir: nace oruga y se
-- convierte en lo que sale del capullo. Es la primera línea del juego donde el
-- elemento decide la criatura entera y no sólo su acabado, y encaja con el signo
-- —cambio, renovación, crecimiento—: Bloom ES la metamorfosis.
--
-- El adulto sustituye a `arthropod_wasp`, que además estaba roto: sus tres
-- animaciones apuntaban al mismo clip de 5 frames, así que ni volaba pese a
-- declarar `fly`, ni distinguía quieta de andando.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "bloom_baby_air",
	family = "arthropod",
	element = "aire",
	replaces = "bloom_baby",
	mesh = "hashimon_bloom_baby_air.glb",
	textures = { "hashimon_bloom_baby_air.png" },
	-- Sin patas traseras: una oruga se arrastra. proportions.lua omite las
	-- claves ausentes sin quejarse.
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.55 },
	mesh_height = 0.71,
	makes_footstep_sound = false,
})

hashimon_bodies.register_creatura_body({
	id = "bloom_adult_air",
	family = "arthropod",
	element = "aire",
	replaces = "arthropod_wasp",
	mesh = "hashimon_bloom_adult_air.glb",
	textures = { "hashimon_bloom_adult_air.png" },
	-- Socket.Mount = asiento (hijo de Torso en la silla). Cámara = eye_*; no
	-- meter el socket en el cráneo. Ver docs/SKELETON_STANDARD_V1.md §3a.
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		wing_l = "Wing.L", wing_r = "Wing.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, fly = 30, fly_boost = 30 }),
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = true },
	hitbox = { width = 1.10, height = 2.00 },
	mesh_height = 7.56,
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 10, y = 185, z = -10 }, -- calibrado in-game /hashimon rot
		-- Calibrado in-game (1ª persona por encima de la cresta).
		eye_first = { x = 0, y = 25, z = 5 },
		eye_third = { x = 0, y = 15, z = -5 }, -- tope del motor
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.5,
		suggest_camera = "third",
	},
})

-- ---------------------------------------------------------------------------
-- CAPA V2 · BEACON AIRE — el faro adulto.
--
-- Sustituye al pteranodonte prestado (GPL) en el camino de un Beacon de aire.
-- GLB: adult-faro-air.blend → glb_for_luanti.py --yaw 180 --expect-frames 230.
-- Socket.Mount hijo de Torso; clips idle/walk/fly/fly_boost (hyper 201–230).
--
-- `contrast` va con el brillo NEGATIVO, al revés que los rescates anteriores.
-- Su textura salió muy clara (media 0.72) y plana (sd 0.098): el rescate
-- estándar {90,40} la habría dejado en media 0.99, casi blanca. Medido con
-- scripts/luanti_contrast.py, que porta el operador del motor:
--     {90,40}    sd 0.053  media 0.99   <- peor
--     {110,-50}  sd 0.333  media 0.65   <- elegido
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "beacon_adult_air",
	family = "avian",
	element = "aire",
	replaces = "pterosaur_pteranodon",
	mesh = "hashimon_beacon_adult_air.glb",
	textures = { "hashimon_beacon_adult_air.png" },
	contrast = { 110, -50 },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", wing_l = "Wing.L", wing_r = "Wing.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, fly = 30, fly_boost = 30 }),
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = true },
	hitbox = { width = 0.70, height = 1.20 },
	mesh_height = 11.60,
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 20, z = 3 },
		eye_third = { x = 0, y = 15, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.65,
		suggest_camera = "third",
	},
})
