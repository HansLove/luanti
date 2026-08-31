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
	-- Los 9 huesos semánticos se renombraron a mano sobre el rig de Meshy (que
	-- traía 47 genéricos, Bone/Bone.001...). Verificado que los nueve tienen
	-- grupo de vértices, o sea que deforman geometría de verdad: un hueso
	-- renombrado pero sin pesos recibiría la override y no movería nada.
	--
	-- Primer cuerpo con `wing_l`/`wing_r` reales. Las alas usan el multiplicador
	-- de extremidades (LIMB_KEYS en proportions.lua), así que un dragón de
	-- limbLength alto tiene patas Y envergadura mayores.
	bones = {
		head = "Head", neck = "Neck", torso = "Torso",
		arm_l = "Arm.L", arm_r = "Arm.R",
		leg_l = "Leg.L", leg_r = "Leg.R",
		wing_l = "Wing.L", wing_r = "Wing.R",
	},
	-- TODO(protocolo): el walk vive hoy en 30-50 porque así se animó, antes de
	-- que existiera anim_protocol.lua. El idle (1-30) ya encaja. Falta mover los
	-- keyframes del walk a partir del frame 41 en Blender y reexportar; entonces
	-- esto se sustituye por:
	--
	--     animations = hashimon_bodies.anims({ idle = 30, walk = 21 }),
	--
	-- Mientras tanto los rangos van explícitos: declarar 41-61 sobre una pista
	-- que acaba en 50 congelaría al dragón, que es justo lo que el protocolo
	-- existe para evitar.
	animations = {
		stand = { range = { x = 1, y = 30 }, speed = 24, loop = true },
		walk  = { range = { x = 30, y = 50 }, speed = 24, loop = true },
	},
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.35, height = 0.6 },
	-- Altura real de la malla en el .glb, medida sobre el accessor POSITION.
	-- Con esto morphology.lua deriva visual_size_base solo; no se declara.
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
	mesh = "hashimon_bear_cub.glb",
	textures = { "hashimon_bear_cub.png" },
	bones = { head = "Head", neck = "Neck", torso = "Torso",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	animations = hashimon_bodies.anims({ idle = 30, walk = 20 }),
	capabilities = { walk = true, run = false, fly = false, swim = false, mount = false },
	hitbox = { width = 0.30, height = 0.50 },
	mesh_height = 4.98,
	makes_footstep_sound = true,
})
