-- Cuerpo de Alen: malla, textura y el CONTRATO de animación.
--
-- OJO con los frames: el cargador glTF de Luanti guarda el TIMESTAMP EN SEGUNDOS
-- como número de frame (irr/src/CGLTFMeshFileLoader.cpp:657, y doc/lua_api.md:437).
-- Los frames de Blender NO se usan tal cual: hay que dividirlos por los fps del
-- export. Por eso aquí se declaran en frames de Blender —que es como se autorean—
-- y la conversión ocurre en un solo sitio. Por lo mismo la velocidad base es 1.0.

hashimon_alen = hashimon_alen or {}

hashimon_alen.FPS = 24 -- fps del export de Blender

hashimon_alen.MESH = "hashimon_alen_gregory.glb"
hashimon_alen.TEXTURES = { "hashimon_alen_gregory.jpg" }

-- visual_size 8.2 lo deja en ~4 nodos de alto (bbox 4.08 x 4.86 x 5.87 unidades,
-- y glTF renderiza a 10 unidades por nodo). Ajustable en vivo con /alen size.
hashimon_alen.VISUAL_SIZE = 8.2

-- ---------------------------------------------------------------------------
-- CLIPS — rangos en frames de Blender, con 10 frames de hueco entre uno y otro
-- para que la mezcla nunca sangre de un clip al siguiente.
--
-- `have = false` significa "todavía no autorado": el estado que lo pide cae a su
-- alternativa y el juego sigue funcionando. Cuando lo animes en Blender en ese
-- rango exacto, pon have = true y el estado se enciende solo. `/alen frames`
-- lista qué falta.
-- ---------------------------------------------------------------------------

hashimon_alen.CLIPS = {
	walk        = { first = 41,  last = 70,  have = true  },
	run         = { first = 81,  last = 110, have = true  },
	fly         = { first = 121, last = 150, have = true  },

	idle        = { first = 161, last = 220, have = false }, -- respiración, cola, parpadeo
	hover       = { first = 231, last = 260, have = false }, -- aleteo sostenido en el sitio
	fly_fast    = { first = 271, last = 300, have = false }, -- crucero rápido / picado
	hurt        = { first = 311, last = 325, have = false }, -- sacudida corta al recibir daño
	breath      = { first = 336, last = 365, have = false }, -- cuello atrás y escupir
	roar        = { first = 376, last = 405, have = false }, -- telegrafía antes de atacar
	takeoff     = { first = 416, last = 435, have = false }, -- despegue desde el suelo
	land        = { first = 446, last = 465, have = false }, -- aterrizaje y plegado de alas
	death       = { first = 476, last = 535, have = false }, -- caída, no cicla
	jump_charge = { first = 546, last = 565, have = false }, -- carga del salto de bloque
}

-- ---------------------------------------------------------------------------
-- ESTADOS — lo que el comportamiento pide. Cada uno nombra una CADENA de clips:
-- el primero que exista gana. Así la lógica puede pedir "fly_fast" desde hoy
-- aunque ese clip aún no exista, y mejora sola cuando lo animes.
--
--   once     el clip se reproduce una vez y bloquea el estado base mientras dura
--   priority sólo un `once` de prioridad >= al vigente puede interrumpirlo
--   freeze   si toca caer a una alternativa, congélala en su primer frame
--            (así "idle" cayendo a "walk" es una pose quieta, no un paseo)
--   fallback en los `once`, si vale la pena reproducir una alternativa. Por
--            defecto NO: un golpe o un despegue sin su clip propio no aporta
--            nada y encima bloquearía el estado base mientras dura. Los cíclicos
--            siempre aceptan alternativa — para eso es la cadena.
-- ---------------------------------------------------------------------------

hashimon_alen.STATES = {
	idle        = { chain = { "idle", "walk" },              speed = 1.0,  freeze = true },
	hover       = { chain = { "hover", "fly" },              speed = 0.45 },
	walk        = { chain = { "walk" },                      speed = 1.0  },
	run         = { chain = { "run", "walk" },               speed = 1.0  },
	fly         = { chain = { "fly", "hover" },              speed = 1.0  },
	fly_fast    = { chain = { "fly_fast", "fly" },           speed = 1.9  },

	hurt        = { chain = { "hurt" },                speed = 1.0, once = true, priority = 5 },
	breath      = { chain = { "breath", "roar" },      speed = 1.0, once = true, priority = 3, fallback = true },
	roar        = { chain = { "roar", "breath" },      speed = 1.0, once = true, priority = 3, fallback = true },
	takeoff     = { chain = { "takeoff" },             speed = 1.0, once = true, priority = 2 },
	land        = { chain = { "land" },                speed = 1.0, once = true, priority = 2 },
	jump_charge = { chain = { "jump_charge", "roar" }, speed = 1.0, once = true, priority = 4, fallback = true },
	death       = { chain = { "death", "hurt" },       speed = 1.0, once = true, priority = 9, loop = false, fallback = true },
}

--- Resuelve un estado al primer clip de su cadena que exista.
--- Devuelve el clip, su nombre, y si hubo que caer a una alternativa.
function hashimon_alen.resolve_clip(state_name)
	local st = hashimon_alen.STATES[state_name]
	if not st then
		return nil
	end
	for i, clip_name in ipairs(st.chain) do
		local c = hashimon_alen.CLIPS[clip_name]
		if c and c.have then
			return c, clip_name, i > 1
		end
	end
	return nil, nil, true
end

--- Duración real de un estado en segundos, ya contando su velocidad. Es lo que
--- necesita saber el temporizador de los `once`.
function hashimon_alen.state_duration(state_name)
	local st = hashimon_alen.STATES[state_name]
	local c = hashimon_alen.resolve_clip(state_name)
	if not st or not c then
		return 0
	end
	local frames = c.last - c.first
	return (frames / hashimon_alen.FPS) / math.max(st.speed or 1.0, 0.01)
end

local function apply(obj, min_frame, max_frame, speed, loop, blend)
	if obj.play_animation then
		obj:play_animation(1, {
			min_frame = min_frame,
			max_frame = max_frame,
			speed = speed,
			blend = blend,
			loop = loop,
		})
	else
		obj:set_animation({ x = min_frame, y = max_frame }, speed, blend, loop)
	end
end

--- Estado base (cíclico). Lo ignora si hay un `once` en curso: un dragón que
--- recibe un golpe tiene que acusar el golpe, no volver a aletear a media
--- sacudida.
function hashimon_alen.set_anim(self, state_name, blend)
	if self._oneshot_until and core.get_gametime() < self._oneshot_until then
		self._anim_pending = state_name
		return
	end
	if self._anim == state_name then
		return
	end

	local st = hashimon_alen.STATES[state_name]
	local clip, _clip_name, fell_back = hashimon_alen.resolve_clip(state_name)
	if not st or not clip then
		return
	end
	self._anim = state_name

	local fps = hashimon_alen.FPS
	local min_frame = clip.first / fps
	local max_frame = clip.last / fps
	local speed = st.speed or 1.0

	-- Una alternativa "congelada" es una pose sostenida, no un ciclo equivocado.
	if fell_back and st.freeze then
		max_frame = min_frame
		speed = 0
	end

	apply(self.object, min_frame, max_frame, speed, st.loop ~= false, blend or 0.25)
end

--- Estado de un solo disparo. Bloquea el estado base mientras dura y luego
--- restaura lo que el comportamiento estuviera pidiendo.
function hashimon_alen.play_oneshot(self, state_name, blend)
	local st = hashimon_alen.STATES[state_name]
	local clip, _clip_name, fell_back = hashimon_alen.resolve_clip(state_name)
	if not st or not clip then
		return false -- sin clip ni alternativa: no pasa nada, el juego sigue
	end
	if fell_back and not st.fallback then
		return false -- el beat no existe todavía: mejor saltárselo que fingirlo
	end

	local now = core.get_gametime()
	local busy = self._oneshot_until and now < self._oneshot_until
	if busy and (st.priority or 0) < (self._oneshot_priority or 0) then
		return false
	end

	local dur = hashimon_alen.state_duration(state_name)
	if dur <= 0 then
		return false
	end

	self._anim_pending = self._anim_pending or self._anim
	self._oneshot_until = now + dur
	self._oneshot_priority = st.priority or 0
	self._anim = state_name

	local fps = hashimon_alen.FPS
	apply(self.object, clip.first / fps, clip.last / fps,
		st.speed or 1.0, st.loop ~= false, blend or 0.12)
	return true
end

--- Llamado cada tick: devuelve el control al estado base cuando el `once` acaba.
function hashimon_alen.step_anim(self)
	if not self._oneshot_until then
		return
	end
	if core.get_gametime() < self._oneshot_until then
		return
	end
	self._oneshot_until = nil
	self._oneshot_priority = nil
	local back = self._anim_pending
	self._anim_pending = nil
	if back then
		self._anim = nil -- fuerza el re-set
		hashimon_alen.set_anim(self, back, 0.2)
	end
end

--- Informe del contrato: qué estado tiene clip propio y qué está tirando de
--- alternativa. Es la lista de trabajo pendiente en Blender.
function hashimon_alen.frame_report()
	local lines, missing = {}, 0
	local names = {}
	for k in pairs(hashimon_alen.STATES) do
		names[#names + 1] = k
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local _clip, clip_name, fell_back = hashimon_alen.resolve_clip(name)
		local want = hashimon_alen.STATES[name].chain[1]
		local w = hashimon_alen.CLIPS[want]
		if clip_name == want then
			lines[#lines + 1] = string.format("  %-12s OK        clip %s (%d-%d)",
				name, want, w.first, w.last)
		else
			missing = missing + 1
			lines[#lines + 1] = string.format("  %-12s FALTA     autorar %s en frames %d-%d de Blender%s",
				name, want, w.first, w.last,
				clip_name and (" — usando " .. clip_name) or " — sin alternativa")
		end
	end
	return lines, missing
end
