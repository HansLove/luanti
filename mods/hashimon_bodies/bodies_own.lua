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
	-- Rig 2026-09: sin Torso/Arm/Leg estándar; Root ancla; cola Tail.2; alas sí.
	bones = {
		head = "Head", neck = "Neck", torso = "Root", tail = "Tail.2",
		wing_l = "Wing.L", wing_r = "Wing.R",
	},
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.52, height = 0.90 },
	mesh_height = 4.18,
	makes_footstep_sound = true,
})

-- DRAGON — adulto propio. Etapa B del linaje Crown. Sustituye al wyvern MIT
-- (`dragon_wyvern`). Pista 1–150: idle/walk/run + fly. Sin fly_boost/rocket/dive
-- (la pista no llega a 201). Socket.Mount hijo de Torso, animado.
-- GLB: adult_crown.glb → glb_for_luanti.py --yaw 180 --expect-frames 150
hashimon_bodies.register_creatura_body({
	id = "crown_adult",
	family = "dragon",
	replaces = "dragon_wyvern",
	mesh = "hashimon_crown_adult.glb",
	textures = { "hashimon_crown_adult.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		wing_l = "Wing.L", wing_r = "Wing.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, run = 30, fly = 30 }),
	capabilities = { walk = true, run = true, fly = true, swim = false, mount = true },
	-- 1.51 = el peldaño B documentado del wyvern. Apex fire/ice miden 5.00.
	hitbox = { width = 0.85, height = 1.51 },
	mesh_height = 7.13,
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 20, z = 4 },
		eye_third = { x = 0, y = 14, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.50,
		suggest_camera = "third",
	},
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
	carry_view = { slot = "shoulder_r", scale = 0.5 },
	hitbox = { width = 0.45, height = 0.75 },
	mesh_height = 4.98,
	makes_footstep_sound = true,
})

-- Guardian ★B genérico (fuego/tierra/eléctrico). Sustituye al oso MIT
-- (`ursine_bear`). Aire usa `guardian_adult_air`; agua usa `guardian_adult_water`.
-- Pista 1–110: idle/walk/run. Socket.Mount hijo de Torso.
-- GLB: adult_guardian.glb → glb_for_luanti.py --yaw 180 --expect-frames 110
hashimon_bodies.register_creatura_body({
	id = "guardian_adult",
	family = "ursine",
	replaces = "ursine_bear",
	mesh = "hashimon_guardian_adult.glb",
	textures = { "hashimon_guardian_adult.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, run = 30 }),
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
	-- 1.4× vs el 1.00 original. mesh_height 19.13 es el export agrandado en
	-- Blender; el tamaño EN JUEGO lo fija hitbox, no la malla.
	hitbox = { width = 0.77, height = 1.40 },
	mesh_height = 19.13,
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 20, z = 4 },
		eye_third = { x = 0, y = 14, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.55,
		suggest_camera = "third",
	},
})

-- Guardian ★B agua (capa V2). Sustituye `guardian_adult` sólo si el elemento
-- es agua. Pista 1–190: idle/walk/run + swim @161. Sin swim_boost (no llega a
-- 521). Socket.Mount hijo de Torso, animado.
-- GLB: guardian_adult_water.glb → glb_for_luanti.py --yaw 180 --expect-frames 190
hashimon_bodies.register_creatura_body({
	id = "guardian_adult_water",
	family = "ursine",
	element = "agua",
	replaces = "guardian_adult",
	mesh = "hashimon_guardian_adult_water.glb",
	textures = { "hashimon_guardian_adult_water.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, run = 30, swim = 30 }),
	capabilities = { walk = true, run = true, fly = false, swim = true, mount = true },
	hitbox = { width = 0.77, height = 1.40 },
	mesh_height = 9.00,
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 20, z = 4 },
		eye_third = { x = 0, y = 14, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.55,
		suggest_camera = "third",
	},
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
-- EQUINE — adulto eléctrico (capa V2). Sustituye `road_adult` solo si el
-- elemento es eléctrico. Resto de elementos siguen con el universal.
--
-- GLB: adult-road-electric.glb → glb_for_luanti.py --yaw 180 --expect-frames 350
-- --rename Neck.003=Head. Socket.Mount animado (sigue el lomo en walk/run);
-- seat/rot calibrados en idle y validados para que el socket mantenga el asiento.
-- Clips: idle 1–30, walk 41–70, run 81–110, run_boost 321–350 (sprint/fase).
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "road_adult_electric",
	family = "equine",
	element = "electrico",
	replaces = "road_adult",
	mesh = "hashimon_road_adult_electric.glb",
	textures = { "hashimon_road_adult_electric.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({
		idle = 30, walk = 30, run = 30, run_boost = 30,
	}),
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
	hitbox = { width = 0.75, height = 1.60 },
	mesh_height = 14.62,
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0.65, y = -1.5, z = 1.1 },
		rot = { x = 2, y = 210, z = 2 },
		eye_first = { x = 0, y = 12, z = 2 },
		eye_third = { x = 0, y = 12, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.45,
		suggest_camera = "third",
	},
})

-- ---------------------------------------------------------------------------
-- EQUINE — adulto tierra (capa V2). Sustituye `road_adult` solo si el
-- elemento es tierra. Resto de elementos siguen con el universal.
--
-- GLB: road_adult_earth.blend → export 1–590 → glb_for_luanti.py --yaw 180
-- --rename Bone.003=Head,Bone.001=Neck,Bone.020=Torso,Bone.035=Tail,
-- Bone.014=Arm.L,Bone.012=Arm.R,Bone.021=Leg.L,Bone.026=Leg.R.
-- Clips: idle 1–30, walk 41–70, run 81–110, dig 561–590.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "road_adult_earth",
	family = "equine",
	element = "tierra",
	replaces = "road_adult",
	mesh = "hashimon_road_adult_earth.glb",
	textures = { "hashimon_road_adult_earth.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, run = 30, dig = 30 }),
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
	hitbox = { width = 0.75, height = 1.60 },
	mesh_height = 10.40,
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
	-- Oruga: bufanda (Neck) → gorra (Head). Socket.Perch = contacto artístico.
	carry_view = {
		slot = "neck",
		scale = 0.9,
		slots = { "neck", "head" },
	},
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

-- Key ★B genérico (fuego/aire/tierra/eléctrico): cobra terrestre.
-- Agua usa `key_adult_water` (replaces). Pista 1–110: idle/walk/run.
-- GLB: key_adult.glb → glb_for_luanti.py --yaw 180 --expect-frames 110
hashimon_bodies.register_creatura_body({
	id = "key_adult",
	family = "serpentine",
	mesh = "hashimon_key_adult.glb",
	textures = { "hashimon_key_adult.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, run = 30 }),
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
	hitbox = { width = 0.70, height = 1.20 },
	mesh_height = 11.93,
	makes_footstep_sound = false,
})

-- Key ★B agua: serpiente marina. Sustituye a key_adult sólo en agua.
-- Pista 190 → swim @161; Socket.Mount para montura oceánica.
hashimon_bodies.register_creatura_body({
	id = "key_adult_water",
	family = "serpentine",
	element = "agua",
	replaces = "key_adult",
	mesh = "hashimon_key_adult_water.glb",
	textures = { "hashimon_key_adult_water.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, swim = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = true, mount = true },
	hitbox = { width = 0.85, height = 1.25 },
	mesh_height = 16.24,
	makes_footstep_sound = false,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 18, z = 4 },
		eye_third = { x = 0, y = 12, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.55,
		suggest_camera = "third",
	},
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
	-- Etapa A propia; saca a la tortuga CC BY-SA sin stand del peldaño Genesis.
	replaces = "chelonian_tortoise",
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

-- Bastion ★B: tortuga de guerra. Socket.Mount; idle/walk/run (pista 110).
hashimon_bodies.register_creatura_body({
	id = "bastion_adult",
	family = "chelonian",
	mesh = "hashimon_bastion_adult.glb",
	textures = { "hashimon_bastion_adult.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, run = 30 }),
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
	-- 1.4× visual. hitbox.height se queda en 1.10 (peldaño B).
	hitbox = { width = 0.85, height = 1.10 },
	mesh_height = 5.82,
	visual_size_base = 2.646, -- 1.10*10/5.82 * 1.4
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 20, z = 4 },
		eye_third = { x = 0, y = 14, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.55,
		suggest_camera = "third",
	},
})

-- Bastion ★B agua: caparazón abisal. Sustituye a bastion_adult sólo en agua.
-- Fuente: bastion_adult_water.glb → glb_for_luanti --yaw 180 --expect-frames 550
-- (idle/walk/run + swim @161 + swim_boost @521; sin Neck).
hashimon_bodies.register_creatura_body({
	id = "bastion_adult_water",
	family = "chelonian",
	element = "agua",
	replaces = "bastion_adult",
	mesh = "hashimon_bastion_adult_water.glb",
	textures = { "hashimon_bastion_adult_water.png" },
	bones = { head = "Head", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({
		idle = 30, walk = 30, run = 30, swim = 30, swim_boost = 30,
	}),
	capabilities = { walk = true, run = true, fly = false, swim = true, mount = true },
	hitbox = { width = 0.85, height = 1.10 },
	mesh_height = 7.21,
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = -0.3, y = 1, z = -0.1 },
		rot = { x = -11, y = 270, z = -15 },
		eye_first = { x = 0, y = 20, z = 4 },
		eye_third = { x = 0, y = 14, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.55,
		suggest_camera = "third",
	},
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
	-- Phase-1 DNA tint mask (white/alpha = tintable). Without this field, no DNA paint.
	tintmask = "hashimon_hearth_baby_tintmask.png",
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.55 },
	mesh_height = 3.16,
	makes_footstep_sound = true,
})

-- Hearth ★B: cánido adulto propio. Sustituye al lobo MIT (`canine_wolf`).
-- Pista 1–500; se declaran idle/walk/run (1–110). Socket.Mount animado
-- (hermano de Torso bajo Root). hitbox.height 0.85: direwolf (C) mide 0.90.
-- GLB: hearth_adult.glb → glb_for_luanti.py --yaw 180 --expect-frames 110
hashimon_bodies.register_creatura_body({
	id = "hearth_adult",
	family = "canine",
	replaces = "canine_wolf",
	mesh = "hashimon_hearth_adult.glb",
	textures = { "hashimon_hearth_adult.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, run = 30 }),
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
	-- 1.4× visual. mesh ~31 u; sin el factor se lee como cría. hitbox 0.85
	-- queda bajo el direwolf (0.90).
	hitbox = { width = 0.50, height = 0.85 },
	mesh_height = 31.27,
	visual_size_base = 0.381, -- 0.85*10/31.27 * 1.4
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 16, z = 3 },
		eye_third = { x = 0, y = 12, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.5,
		suggest_camera = "third",
	},
})

hashimon_bodies.register_creatura_body({
	id = "mirror_baby",
	family = "feline",
	-- Etapa A propia; saca al gato MIT del peldaño Genesis.
	replaces = "feline_cat",
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

-- Mirror ★B: felino adulto propio. Sustituye thylacoleo; smilodon sigue como C.
-- GLB: adult_mirror.glb → glb_for_luanti.py --yaw 180 --expect-frames 110
-- Pista 1–500; se declaran idle/walk/run (1–110). Socket.Mount animado (hermano
-- de Torso bajo Bone.001).
hashimon_bodies.register_creatura_body({
	id = "mirror_adult",
	family = "feline",
	replaces = "feline_thylacoleo",
	mesh = "hashimon_mirror_adult.glb",
	textures = { "hashimon_mirror_adult.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, run = 30 }),
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
	-- 1.4× visual. hitbox.height se queda en 0.90: smilodon (C) mide 0.95 y la
	-- línea se ordena por altura — subir de 0.95 invertiría adulto y apex.
	hitbox = { width = 0.77, height = 0.90 },
	mesh_height = 32.02,
	visual_size_base = 0.394, -- 0.90*10/32.02 * 1.4
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 16, z = 3 },
		eye_third = { x = 0, y = 12, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.5,
		suggest_camera = "third",
	},
})

-- Mirror ★B aire (capa V2). Sustituye `mirror_adult` sólo si el elemento es
-- aire. Pista 1–310: idle/walk + fly/fly_boost/fly_rocket/fly_dive. Socket.Mount
-- animado (hermano de Torso bajo Root). hitbox.height = 0.90: smilodon (C) mide
-- 0.95 y la línea se ordena por altura.
-- GLB: mirror_adult_air.glb → glb_for_luanti.py --yaw 180 --expect-frames 310
hashimon_bodies.register_creatura_body({
	id = "mirror_adult_air",
	family = "feline",
	element = "aire",
	replaces = "mirror_adult",
	mesh = "hashimon_mirror_adult_air.glb",
	textures = { "hashimon_mirror_adult_air.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({
		idle = 30, walk = 30, fly = 30, fly_boost = 30,
		fly_rocket = 30, fly_dive = 30,
	}),
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = true },
	-- 1.3× previo × 1.4 = 1.82× del derivado. hitbox.height se queda en 0.90.
	hitbox = { width = 0.77, height = 0.90 },
	mesh_height = 14.92,
	visual_size_base = 1.098, -- 0.784 * 1.4
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 16, z = 3 },
		eye_third = { x = 0, y = 12, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.5,
		suggest_camera = "third",
	},
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

-- Beacon ★1 aire: serpiente-bufanda. Socket.Perch = origen; perch_neck @361.
-- Familia `avian` (línea Beacon): sin patas el proportions omite claves ausentes.
-- Sustituye al polluelo compartido sólo para elemento aire.
-- Escala 1:1 con Bob: mismo visual_size_base (2.76). En Blender se posa junto a
-- Bob ~1.7 m; en juego hitbox ≈ mesh_height×2.76/10 ≈ 0.72 nodos.
-- NUNCA exportar Bob dentro del GLB del baby (infla AABB y aplasta la malla).
hashimon_bodies.register_creatura_body({
	id = "beacon_baby_air",
	family = "avian",
	element = "aire",
	replaces = "beacon_baby",
	mesh = "hashimon_beacon_baby_air.glb",
	textures = { "hashimon_beacon_baby_air.png" },
	-- Sin `Torso` en el GLB: Root ancla la cadena; Tail distal.
	bones = { head = "Head", neck = "Neck", torso = "Root", tail = "Tail" },
	animations = hashimon_bodies.anims({
		idle = 30,
		walk = 30,
		perch_neck = 30, -- 361–390
	}),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.55, height = 0.72 },
	mesh_height = 2.60,
	visual_size_base = 2.76, -- = Bob; carry scale ~1.15 ⇒ un poco más grande en cuello
	makes_footstep_sound = false,
	carry_view = {
		slot = "neck",
		scale = 1.15,
		slots = { "neck" },
		anim_by_slot = { neck = "perch_neck" },
		-- Calibrado in-game: /hashimon carry seat -0.15 0.5 0.33
		by_slot = {
			neck = { seat = { x = -0.15, y = 0.5, z = 0.33 } },
		},
	},
})

-- Beacon ★1 agua: cría singular (pingüino). Sustituye al polluelo sólo en agua.
-- Tierra / fuego / eléctrico siguen con `beacon_baby` (pajarito compartido).
-- Carry en hombro (no cuello): sin perch; en Neck el mesh queda dentro de Bob.
hashimon_bodies.register_creatura_body({
	id = "beacon_baby_water",
	family = "avian",
	element = "agua",
	replaces = "beacon_baby",
	mesh = "hashimon_beacon_baby_water.glb",
	textures = { "hashimon_beacon_baby_water.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30 }),
	capabilities = { walk = true, run = false, fly = false, swim = true, mount = false },
	hitbox = { width = 0.40, height = 0.70 },
	mesh_height = 8.09,
	makes_footstep_sound = true,
	carry_view = {
		slot = "shoulder_r",
		scale = 0.9,
		slots = { "shoulder_r", "shoulder_l", "back" },
	},
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
	-- 1.3× visual. hitbox.height 0.55 = tier 1 (stage 1). El GLB tenía el
	-- origen en el centro (AABB y[-2.01, 2.01]); LuantiFacing lo sube al suelo.
	hitbox = { width = 0.38, height = 0.55 },
	mesh_height = 4.02,
	visual_size_base = 1.778, -- 0.55*10/4.02 * 1.3
	makes_footstep_sound = false,
})

-- Depth ★B: leviatán propio. Sustituye al dunkleosteus GPL (sin `stand`).
-- Pista 1–190: idle/walk/run + swim @161. Socket.Mount hijo de Torso.
-- GLB: depth_adult.glb → glb_for_luanti.py --yaw 180 --expect-frames 190
hashimon_bodies.register_creatura_body({
	id = "depth_adult",
	family = "aquatic",
	replaces = "marine_reptile_dunkleosteus",
	mesh = "hashimon_depth_adult.glb",
	textures = { "hashimon_depth_adult.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		fin_t = "Top.Fin",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 30, run = 30, swim = 30 }),
	capabilities = { walk = true, run = true, fly = false, swim = true, mount = true },
	hitbox = { width = 0.90, height = 1.30 },
	mesh_height = 8.64,
	makes_footstep_sound = false,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 18, z = 4 },
		eye_third = { x = 0, y = 12, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.55,
		suggest_camera = "third",
	},
})

-- ---------------------------------------------------------------------------
-- URSINE · AIRE — etapa B del Guardian de aire. PRIMER CUERPO DE LA CAPA V2.
--
-- Hasta aquí el elemento sólo sesgaba color y proporciones; el cuerpo lo
-- decidían linaje y etapa. Éste es el primero que un elemento SELECCIONA:
--
--   `element`   sólo lo viste una criatura de aire. Para las demás no existe.
--   `replaces`  sustituye al Guardian adulto genérico en su peldaño en vez de
--               sumarse, o ambos competirían por el mismo destino.
--
-- GLB: guardian_adult_air.glb → glb_for_luanti.py --yaw 180 --expect-frames 310
-- (idle/walk + fly/fly_boost/fly_rocket/fly_dive). Socket.Mount animado (hermano
-- de Torso bajo Root; el asiento está keyed al lomo). Socket.Tail sigue en el
-- rig. Sin Wing.L/R ni Socket.Back: el vuelo lo llevan los brazos del clip.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "guardian_adult_air",
	family = "ursine",
	element = "aire",
	replaces = "guardian_adult",
	mesh = "hashimon_guardian_adult_air.glb",
	textures = { "hashimon_guardian_adult_air.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({
		idle = 30, walk = 30, fly = 30, fly_boost = 30,
		fly_rocket = 30, fly_dive = 30,
	}),
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = true },
	-- 1.4× visual. hitbox.height se queda en 1.00 (tier 2, por debajo del apex).
	hitbox = { width = 0.55, height = 1.00 },
	mesh_height = 11.12,
	visual_size_base = 1.259, -- 1.00*10/11.12 * 1.4
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 20, z = 4 },
		eye_third = { x = 0, y = 14, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.55,
		suggest_camera = "third",
	},
})

-- ---------------------------------------------------------------------------
-- CAPA V2 · BLOOM AIRE — oruga y su imago.
--
-- Naming estándar de fuente: {familia}_{etapa}[_{tipo}].glb
--   → bloom_baby_air.glb (familia bloom, etapa baby, variante aire)
--
-- Para un Bloom de aire la mantis genérica deja de existir: nace oruga y se
-- convierte en lo que sale del capullo. Es la primera línea del juego donde el
-- elemento decide la criatura entera y no sólo su acabado, y encaja con el signo
-- —cambio, renovación, crecimiento—: Bloom ES la metamorfosis.
--
-- El adulto sustituye a `arthropod_wasp`, que además estaba roto: sus tres
-- animaciones apuntaban al mismo clip de 5 frames, así que ni volaba pese a
-- declarar `fly`, ni distinguía quieta de andando.
--
-- GLB: bloom_baby_air.glb → glb_for_luanti --yaw 180 --expect-frames 470
-- Carry: perch_neck 361–390 (hombro), perch_head 401–430, pista hasta 470.
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
	bones = { head = "Head", neck = "Neck", torso = "Torax", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R" },
	animations = hashimon_bodies.anims({
		idle = 30,
		walk = 30,
		perch_neck = 30,       -- 361–390 · acomodo hombro (autoría)
		perch_head = 30,       -- 401–430
		perch_shoulder = 30,   -- 441–470
	}),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.55 },
	mesh_height = 2.09,
	makes_footstep_sound = false,
	-- scale = fracción del tamaño EN EL SUELO (ya se compensa el ×Bob).
	-- ~0.9 ≈ misma presencia que suelto; 0.32 quedaba “piedrita”.
	carry_view = {
		slot = "head",
		scale = 0.9,
		slots = { "head", "shoulder_r" },
		anim_by_slot = {
			head = "perch_head",
			-- Clip nuevo en 361–390: el protocolo lo llama perch_neck; en Bloom
			-- aire es el acomodo de hombro que se revisa en juego.
			shoulder_r = "perch_neck",
		},
	},
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
	-- GLB: adult-bloom-air.glb → expect-frames 310 (fly_dive inclusive).
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		wing_l = "Wing.L", wing_r = "Wing.R",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({
		idle = 30, walk = 30, fly = 30, fly_boost = 30,
		fly_rocket = 30, fly_dive = 30,
	}),
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = true },
	hitbox = { width = 1.10, height = 2.00 },
	mesh_height = 8.22,
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
-- GLB: adult-faro-air.blend → glb_for_luanti.py --yaw 180 --expect-frames 310.
-- Socket.Mount hijo de Torso; clips idle/walk/fly/fly_boost/fly_rocket/fly_dive.
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
	animations = hashimon_bodies.anims({
		idle = 30, walk = 30, fly = 30, fly_boost = 30,
		fly_rocket = 30, fly_dive = 30,
	}),
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = true },
	-- Adulto montable: antes 1.20 se leía como cría grande; alineado a Bloom aire (~2.0).
	hitbox = { width = 1.20, height = 2.10 },
	mesh_height = 22.49,
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 0, y = 180, z = 0 },
		eye_first = { x = 0, y = 24, z = 4 },
		eye_third = { x = 0, y = 15, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.55,
		suggest_camera = "third",
	},
})

-- ---------------------------------------------------------------------------
-- CAPA V2 · BEACON AGUA — pingüino adulto.
--
-- Sustituye al pteranodonte prestado (GPL) en el camino de un Beacon de agua.
-- GLB: beacon_adult_water.glb → glb_for_luanti.py --yaw 180 --expect-frames 550
-- Socket.Mount hijo de Torso. Clips: idle/walk/run + swim @161 + swim_boost @521.
-- Wing.L en el rig (sin Wing.R); los brazos cubren el otro lado.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "beacon_adult_water",
	family = "avian",
	element = "agua",
	replaces = "pterosaur_pteranodon",
	mesh = "hashimon_beacon_adult_water.glb",
	textures = { "hashimon_beacon_adult_water.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R",
		wing_l = "Wing.L",
		mount_socket = "Socket.Mount" },
	animations = hashimon_bodies.anims({
		idle = 30, walk = 30, run = 30, swim = 30, swim_boost = 30,
	}),
	capabilities = { walk = true, run = true, fly = false, swim = true, mount = true },
	hitbox = { width = 0.95, height = 1.60 },
	mesh_height = 10.79,
	makes_footstep_sound = true,
	mount_view = {
		bone = "Socket.Mount",
		seat = { x = 0, y = 0, z = 0 },
		rot = { x = 15, y = 100, z = 20 }, -- calibrado in-game /hashimon rot
		eye_first = { x = 0, y = 18, z = 4 },
		eye_third = { x = 0, y = 12, z = -5 },
		hide_rider = false,
		forced_visible = true,
		rider_scale = 0.55,
		suggest_camera = "third",
	},
})
