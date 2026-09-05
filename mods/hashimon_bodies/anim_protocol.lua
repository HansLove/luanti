-- PROTOCOLO DE ANIMACIÓN — disposición canónica de frames para cuerpos propios.
--
-- Existe porque en glTF los timestamps SON los números de frame (ver
-- 3d-world/doc/lua_api.md línea 437). Eso convierte la numeración de frames en
-- parte del contrato entre Blender y el motor, no en un detalle del animador.
--
--     clip     empieza en   presupuesto   obligatorio
--     ------   ----------   -----------   -----------
--     idle              1     30 frames   sí
--     walk             41     30 frames   sí
--     run              81     30 frames   no
--     fly             121     30 frames   no  (capabilities.fly)
--     swim            161     30 frames   no  (capabilities.swim)
--     fly_boost       201     30 frames   no  (hold Sprint/E en montura aérea)
--     fly_rocket      241     30 frames   no  (Space+Sprint cohete / subida)
--     fly_dive        281     30 frames   no  (Sneak+Sprint picada)
--     run_boost       321     30 frames   no  (Sprint / rayo eléctrico en terrestre,
--                                              p.ej. Road eléctrico — NO es fly_boost)
--     perch_neck      361     30 frames   no  (baby carry: bufanda / Socket.Carry.Neck)
--     perch_head      401     30 frames   no  (baby carry: gorra / Socket.Carry.Head)
--     perch_shoulder  441     30 frames   no  (baby carry: hombro L/R)
--     perch_back      481     30 frames   no  (baby carry: mochila)
--     swim_boost      521     30 frames   no  (Sprint/aux1 hyper-nado en montura agua;
--                                              p.ej. Bastion agua — NO es swim ni run_boost)
--
-- Brief animador aéreo: fly_rocket = alas plegadas / cuerpo vertical arriba;
-- fly_dive = nose-down, alas retraídas. Si el GLB no tiene el clip, no lo
-- declares en bodies — el FSM degrada a fly_boost → fly.
-- `fly` también hace de hover/standby: montura aérea quieta en el aire NO usa
-- idle (se veía plantada). No hace falta un clip fly_stand_by aparte.
--
-- Brief animador perch (carry): anima la pose YA colocada en el socket de Bob
-- (cabeza/cuello/hombro). Runtime reproduce el clip según carry_view.anim_by_slot;
-- sin clip → stand + by_slot.rot/seat.
--
-- Brief animador terrestre eléctrico: run_boost = ciclo de sprint (cuerpo
-- "energía", extremidades rápidas). Hasta que el GLB llegue al frame 350,
-- declara sólo idle/walk/run; el FSM usa `run` como fallback.
--
-- Brief animador acuático: swim_boost = ciclo de hyper-nado (aletas/caparazón
-- más agresivo). Hasta que el GLB llegue al frame 550, declara sólo swim;
-- el FSM usa `swim` (o `run`/`walk`) como fallback.
--
--     inicio del clip n = 1 + 40*(n-1)
--
-- INICIO FIJO, LONGITUD LIBRE. Un idle natural respira lento y quiere más
-- frames que un ciclo de caminar. Bloques de tamaño fijo obligarían a acortar
-- el idle o a estirar el walk, así que lo único fijo es DÓNDE empieza cada
-- clip; cada uno usa los frames que necesite dentro de su presupuesto de 30.
--
-- POR QUÉ 10 FRAMES DE HUECO. La animación se exporta muestreada por frame, así
-- que entre el final de un clip y el inicio del siguiente hay poses de
-- transición sin sentido. Ningún rango las incluye, y el hueco deja margen para
-- alargar un ciclo sin renumerar lo demás. Es la convención que ya seguían los
-- cuerpos de Animalia (1-60, 70-89, 100-119), ahora explícita.
--
-- POR QUÉ SIEMPRE speed = fps DE AUTORÍA. En un .b3d `speed` son fps y se usaba
-- para fingir tempo reutilizando un clip (walk y run desde el mismo rango a 30
-- y 45). En glTF, tras pasar por scripts/glb_for_luanti.py los frames son los
-- de Blender, así que speed = fps reproduce el ritmo original y nada más. Si un
-- ciclo va lento, se anima más rápido; no se sube la velocidad de reproducción.
--
-- CLIPS AUSENTES. Declara sólo lo que hayas animado. El FSM degrada solo: sin
-- `run` usa `walk`, sin `walk` usa `idle`. Declarar un rango que la pista no
-- cubre congela la criatura en su última pose — por eso el exportador valida
-- que el último frame declarado exista de verdad.

-- ORIENTACIÓN. Independiente del protocolo de frames pero igual de fácil de
-- olvidar: el modelo debe salir de glb_for_luanti.py con `--yaw 180`, o la
-- criatura camina de espaldas por muy bien animada que esté.

hashimon_bodies = hashimon_bodies or {}

hashimon_bodies.ANIM_START = {
	idle = 1,
	walk = 41,
	run  = 81,
	fly  = 121,
	swim = 161,
	fly_boost = 201,
	fly_rocket = 241,
	fly_dive = 281,
	run_boost = 321,
	perch_neck = 361,
	perch_head = 401,
	perch_shoulder = 441,
	perch_back = 481,
	swim_boost = 521,
}

hashimon_bodies.ANIM_BUDGET = 30
hashimon_bodies.ANIM_FPS = 24

-- El motor llama "stand" al reposo; el protocolo lo llama "idle" porque es como
-- se nombra en Blender. La traducción vive aquí y en ningún otro sitio.
local ENGINE_NAME = { idle = "stand" }

local ORDER = {
	"idle", "walk", "run", "fly", "swim",
	"fly_boost", "fly_rocket", "fly_dive", "run_boost",
	"perch_neck", "perch_head", "perch_shoulder", "perch_back",
	"swim_boost",
}

--- Tabla `animations` a partir de la LONGITUD de cada clip.
---
---   animations = hashimon_bodies.anims({ idle = 30, walk = 20 })
---   -- -> stand { 1, 30 }   walk { 41, 60 }
---
--- El autor sólo dice cuántos frames dura cada cosa; dónde empieza lo decide el
--- protocolo. Escribir los rangos a mano es lo que produce solapamientos y
--- typos silenciosos: un `y = 5o` no rompe nada, sólo deja la criatura quieta
--- para siempre.
--- @param lengths table {clip = nº de frames}
--- @param fps number|nil fps de autoría (por defecto 24)
function hashimon_bodies.anims(lengths, fps)
	local out = {}
	for name, len in pairs(lengths) do
		local start = hashimon_bodies.ANIM_START[name]
		if not start then
			error("anim_protocol: clip desconocido '" .. tostring(name) .. "'")
		end
		if type(len) ~= "number" or len < 2 then
			error("anim_protocol: '" .. name .. "' necesita al menos 2 frames")
		end
		if len > hashimon_bodies.ANIM_BUDGET then
			error(("anim_protocol: '%s' usa %d frames y el presupuesto es %d; " ..
				"pisaría el clip siguiente"):format(name, len, hashimon_bodies.ANIM_BUDGET))
		end
		out[ENGINE_NAME[name] or name] = {
			range = { x = start, y = start + len - 1 },
			speed = fps or hashimon_bodies.ANIM_FPS,
			loop = true,
		}
	end
	return out
end

--- Último frame que el export debe contener, para validar el .glb.
function hashimon_bodies.anim_last_frame(lengths)
	local last = 0
	for name, len in pairs(lengths) do
		local start = hashimon_bodies.ANIM_START[name]
		if start then last = math.max(last, start + len - 1) end
	end
	return last
end

--- La disposición como texto, para pegarla en el brief del animador.
function hashimon_bodies.anim_layout()
	local lines = {}
	for _, name in ipairs(ORDER) do
		local s = hashimon_bodies.ANIM_START[name]
		lines[#lines + 1] = ("%-5s %4d - %d"):format(name, s, s + hashimon_bodies.ANIM_BUDGET - 1)
	end
	return table.concat(lines, "\n")
end
