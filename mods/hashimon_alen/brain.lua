-- Capa TÁCTICA: máquina de estados en Lua. Corre gratis, sin red y sin modelo.
--
-- El reparto de trabajo es el que abarata todo el sistema:
--   reflejo  (cada tick)   → mover, esquivar, enfriamientos   [entity.lua]
--   táctica  (cada ~1 s)   → qué hacer ahora mismo            [este fichero]
--   intención(por evento)  → qué campaña y por qué            [el modelo, luego]
-- El modelo pone política; Lua ejecuta. Si el modelo nunca contesta, Alen sigue
-- siendo un jefe competente — sólo deja de ser sorprendente.

hashimon_alen = hashimon_alen or {}

hashimon_alen.TACTIC_INTERVAL = 1.0
hashimon_alen.SIGHT = 48        -- suelo de la escala: la vista de un Alen CALM.
                                -- La vista real la da hashimon_alen.tier().
hashimon_alen.STRAFE_MIN = 8    -- más cerca que esto, se aleja
hashimon_alen.STRAFE_MAX = 22   -- más lejos, se acerca
hashimon_alen.FLEE_HP = 0.10    -- fracción de vida a la que rompe el combate.
                                -- Con el multiplicador de ira, un Alen furioso
                                -- aguanta hasta el 3.5 %.

local CRUISE = 7
local CHARGE = 11

--- Jugador más cercano dentro de `range`, ignorando a los que no puede tocar.
local function nearest_player(pos, range)
	local best, best_d = nil, range
	for _, player in ipairs(core.get_connected_players()) do
		local pp = player:get_pos()
		if pp and player:get_hp() > 0 then
			local d = hashimon_alen.dist(pos, pp)
			if d < best_d then
				best, best_d = player, d
			end
		end
	end
	return best, best_d
end

hashimon_alen.nearest_player = nearest_player

-- ---------------------------------------------------------------------------
-- Cola de plan — la costura por donde entrarán las órdenes del servidor.
-- Un plan es una lista de verbos con presupuesto. Hoy se llena a mano desde
-- /alen plan; mañana lo llenará apply_alen_order desde la API, con exactamente
-- la misma forma. Nada más en el mod necesita enterarse del cambio.
-- ---------------------------------------------------------------------------

hashimon_alen.VERBS = { "goto", "patrol_area", "hunt", "blockjump", "wait", "say", "firecube" }

local function verb_allowed(name)
	for _, v in ipairs(hashimon_alen.VERBS) do
		if v == name then
			return true
		end
	end
	return false
end

--- Valida un plan entero antes de aceptarlo. Rechaza el plan completo si un solo
--- verbo no pasa: aplicar medio plan es peor que no aplicar ninguno.
function hashimon_alen.validate_plan(plan)
	if type(plan) ~= "table" or type(plan.verbs) ~= "table" or #plan.verbs == 0 then
		return false, "plan_vacio"
	end
	if #plan.verbs > 16 then
		return false, "plan_demasiado_largo"
	end
	for i, v in ipairs(plan.verbs) do
		if type(v) ~= "table" or not verb_allowed(v.op) then
			return false, "verbo_no_permitido:" .. tostring(type(v) == "table" and v.op or i)
		end
	end
	return true
end

function hashimon_alen.set_plan(self, plan)
	local ok, why = hashimon_alen.validate_plan(plan)
	if not ok then
		return false, why
	end
	plan.i = 1
	plan.deadline = core.get_gametime() + (plan.ttl or 300)
	self.plan = plan
	local s = hashimon_alen.get_state()
	s.plan = plan
	return true
end

function hashimon_alen.clear_plan(self, why)
	local had = self.plan
	self.plan = nil
	hashimon_alen.get_state().plan = nil
	if why then
		core.log("action", "[alen] plan cerrado: " .. why)
		-- Un plan que termina es una novedad: es cuando el planificador tiene algo
		-- nuevo que decidir. Es también el disparo más frecuente, y por eso el que
		-- más conviene que sea barato.
		if had and hashimon_alen.note_event then
			hashimon_alen.note_event(
				why == "completado" and "plan_completo" or "plan_fallido",
				nil,
				{ motivo = why, verbo = had.i, de = #had.verbs, origen = had.origin_id }
			)
		end
	end
end

--- Ejecuta el verbo en curso. Devuelve true si el plan sigue vivo.
local function step_plan(self, dtime)
	local plan = self.plan
	if not plan then
		return false
	end
	if core.get_gametime() > (plan.deadline or 0) then
		hashimon_alen.clear_plan(self, "ttl_agotado")
		return false
	end

	local v = plan.verbs[plan.i]
	if not v then
		hashimon_alen.clear_plan(self, "completado")
		return false
	end

	local pos = self.object:get_pos()
	local done = false

	if v.op == "goto" then
		hashimon_alen.move_to(self, v, dtime, {})
		done = hashimon_alen.dist(pos, v) < 4

	elseif v.op == "patrol_area" then
		v._until = v._until or (core.get_gametime() + (v.minutes or 2) * 60)
		if not self._orbit or hashimon_alen.dist(pos, self._orbit) < 5 then
			local a = math.random() * math.pi * 2
			local r = v.radius or 30
			self._orbit = { x = v.x + math.cos(a) * r, y = v.y + 10, z = v.z + math.sin(a) * r }
		end
		hashimon_alen.move_to(self, self._orbit, dtime, {
			in_settlement = hashimon_alen.in_settlement(pos),
		})
		done = core.get_gametime() > v._until

	elseif v.op == "hunt" then
		local target = v.target and core.get_player_by_name(v.target)
		if not target or not target:get_pos() then
			target = nearest_player(pos, hashimon_alen.tier().sight)
		end
		if target then
			self._target = target
			done = false
		else
			done = true
		end
		v._until = v._until or (core.get_gametime() + (v.seconds or 60))
		if core.get_gametime() > v._until then
			done = true
		end

	elseif v.op == "blockjump" then
		local dest = (v.x and v) or hashimon_alen.find_jump_target(pos, 60, 140, 12)
		if dest then
			if v.visible == false then
				hashimon_alen.do_jump(self, dest, false)
			else
				hashimon_alen.begin_jump(self, dest)
			end
		end
		done = true

	elseif v.op == "firecube" then
		local target = (v.target and core.get_player_by_name(v.target))
			or self._target or nearest_player(pos, hashimon_alen.tier().sight)
		if target then
			hashimon_alen.begin_firecube(self, target)
		end
		done = true

	elseif v.op == "wait" then
		v._until = v._until or (core.get_gametime() + (v.seconds or 5))
		hashimon_alen.hover_brake(self)
		hashimon_alen.set_anim(self, "hover")
		done = core.get_gametime() > v._until

	elseif v.op == "say" then
		if not v._said then
			v._said = true
			-- Por la MISMA puerta que las frases locales, para que el enfriamiento
			-- viva en un solo sitio. `force` porque el modelo eligió esta línea a
			-- propósito y pagarla para que la trague un contador sería absurdo.
			hashimon_alen.say_text(v.text, { force = true })
		end
		done = true
	end

	if done then
		plan.i = plan.i + 1
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Comportamiento autónomo: lo que hace cuando no hay plan.
-- ---------------------------------------------------------------------------

--- ¿Retrocede o se queda a castigar cuando lo tienes encima? Extraído de decide()
--- para poder probarlo sin jugadores conectados — y porque es LA regla que hacía
--- que golpear a Alen pareciera no tener efecto.
function hashimon_alen.close_quarters_tactic(target_name)
	local t = hashimon_alen.tier_toward(target_name).name
	if t == "ANGRY" or t == "WRATHFUL" then
		return "strafe"
	end
	return "peel"
end

--- Vida a la que rompe combate, escalada con la ira.
function hashimon_alen.flee_threshold(target_name)
	local t = hashimon_alen.tier_toward(target_name).name
	local mult = (t == "WRATHFUL" and 0.35) or (t == "ANGRY" and 0.7) or 1.0
	return hashimon_alen.MAX_HP * hashimon_alen.FLEE_HP * mult
end

--- ¿Hay alguien que pueda VERLO? Regla del proyecto: el trabajo de Alen es ser
--- villano cuando hay jugadores. Sin público no destruye nada — no porque no
--- quiera, sino porque destruir sin testigos no es ser un villano, es ser erosión.
function hashimon_alen.has_audience(pos)
	for _, player in ipairs(core.get_connected_players()) do
		local pp = player:get_pos()
		if pp and hashimon_alen.dist(pos, pp) <= hashimon_alen.tier().sight then
			return player
		end
	end
	return nil
end

--- El cañonazo al pueblo. Tres condiciones y una tirada: ganas de destruir, estar
--- sobre un asentamiento, y que haya alguien mirando. Si el azar no le favorece,
--- la voluntad de Alen es lanzarlo.
function hashimon_alen.consider_bombard(self, pos)
	local s = hashimon_alen.get_state()
	if (s.destruction_desire or 0) < 45 then return false end
	if not hashimon_alen.in_settlement(pos) then return false end

	local witness = hashimon_alen.has_audience(pos)
	if not witness then return false end             -- sin público, no hay función
	if hashimon_alen.attack_blocked(self, "firecube") then return false end
	if self._bombard_at and core.get_gametime() - self._bombard_at < 90 then return false end

	-- La tirada: cuanto más deseo y más crueldad, más probable. Nunca certeza.
	local p = ((s.destruction_desire or 0) / 100) * 0.5
		* hashimon_alen.trait_mult("cruelty", 0.35)
	if math.random() > p then return false end

	self._bombard_at = core.get_gametime()
	hashimon_alen.declare(self, "ON_WARN_TOWN", {})
	-- Se avisa y DESPUÉS se lanza: siempre advierte antes de actuar.
	core.after(2.0, function()
		local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
		if not live then return end
		hashimon_alen.begin_firecube(live, witness)
		s.destruction_desire = math.max(0, (s.destruction_desire or 0) - 35)
		if hashimon_alen.note_event then
			hashimon_alen.note_event("canonazo", witness:get_player_name(),
				{ deseo_restante = math.floor(s.destruction_desire) })
		end
	end)
	return true
end

--- ¿Está alguien hablándole ahora mismo? Que una conversación lo DETENGA es la
--- mitad de la escena: un dragón que sigue patrullando mientras le hablas no está
--- escuchando, está tolerándote.
local function in_conversation_with(name)
	local c = hashimon_alen.convo
	return c and c.who == name and
		(core.get_gametime() - (c.last_at or 0)) < hashimon_alen.CONVO_TIMEOUT
end

--- Curiosidad: plantarse a mirar a alguien que no le ha hecho nada. No es la
--- ausencia de una decisión, es la invitación a que le hables — y sale de su
--- rasgo, así que un Alen poco curioso casi nunca lo hace.
local function wants_to_watch(self, name, d)
	if (hashimon_alen.get_state().anger or 0) > 30 then return false end
	local r = hashimon_alen.knows(name)
	if r and (r.grudge or 0) > 25 then return false end
	if d > 30 then return false end
	if self._watch_until and core.get_gametime() < self._watch_until then return true end
	if self._watch_cd and core.get_gametime() < self._watch_cd then return false end
	-- Tirada rara, ponderada por curiosidad: no se planta con todo el mundo.
	if math.random() < hashimon_alen.traits().curiosity * 0.06 then
		self._watch_until = core.get_gametime() + 12 + math.random() * 10
		self._watch_cd = core.get_gametime() + 60
		return true
	end
	return false
end

--- ENCUENTRO: alguien acaba de entrar en su radio.
---
--- Regla de la partida: "en cuanto entres a su círculo estás en problemas, a menos
--- que tengas suerte y decida ignorarte, decirte que te pierdas, o quiera jugar
--- contigo". Lo que NO puede pasar es que no pase nada — pasar por delante de un
--- dragón y que siga a lo suyo es lo que rompe la ilusión.
---
--- Devuelve la táctica que impone el encuentro, o nil si decide seguir a lo suyo
--- (y hasta eso lo dice en voz alta).
function hashimon_alen.encounter(self, player, d)
	local name = player:get_player_name()
	local r = hashimon_alen.knows(name)
	local grudge = r and r.grudge or 0
	local tier = hashimon_alen.tier_toward(name)
	local tr = hashimon_alen.traits()

	-- Con rencor o con la ira alta no hay tirada: te tiene.
	if grudge >= 35 or tier.name == "ANGRY" or tier.name == "WRATHFUL" then
		self._depart_until = nil          -- cancela cualquier retirada
		self._target = player
		hashimon_alen.say(grudge >= 35 and "ON_ENRAGED" or "ON_WARN_ATTACK",
			{ force = true }, { name = name })
		return "approach"
	end

	local roll = math.random()
	-- Curiosidad: se planta a mirarte. Es la invitación a hablarle.
	if roll < tr.curiosity * 0.35 then
		self._depart_until = nil
		self._watch_until = core.get_gametime() + 14
		self._target = player
		return "listen"
	end
	-- Vanidad: te dice que te pierdas y sigue a lo suyo.
	if roll < tr.curiosity * 0.35 + tr.vanity * 0.35 then
		hashimon_alen.say((r and (r.sentiment or 0) > 30) and "ON_PLAYER_LIKED"
			or "ON_GREETED_COLD", { force = true }, { name = name })
		return nil
	end
	-- Y a veces, suerte: no se digna ni a mirarte.
	return nil
end

--- ¿Ha entrado alguien nuevo en su vista desde el último tick táctico?
local function new_arrival(self, pos)
	local range = hashimon_alen.tier().sight
	self._known_near = self._known_near or {}
	local seen_now, arrival = {}, nil
	for _, player in ipairs(core.get_connected_players()) do
		local pp = player:get_pos()
		if pp then
			local d = hashimon_alen.dist(pos, pp)
			if d <= range then
				local n = player:get_player_name()
				seen_now[n] = true
				if not self._known_near[n] and not arrival then
					arrival = { player = player, d = d }
				end
			end
		end
	end
	self._known_near = seen_now
	return arrival
end

local function decide(self, pos)
	-- El encuentro se evalúa SIEMPRE, incluso mientras se retira. Que se vaya
	-- volando no puede significar que seas invisible.
	local arrival = new_arrival(self, pos)
	if arrival then
		local forced = hashimon_alen.encounter(self, arrival.player, arrival.d)
		if forced then
			self._target = arrival.player
			return forced
		end
	end

	-- Retirada declarada: se va andando o volando, no de un salto.
	if self._depart_until and core.get_gametime() < self._depart_until then
		return "depart"
	end

	local tier = hashimon_alen.tier()

	-- La huida escala con la ira. Un Alen iracundo no rompe combate al 22 % de
	-- vida: aguanta hasta el 8 %. Rendirse al mismo número pase lo que pase es
	-- otra forma de que golpearlo no cambie nada.
	if self.hp <= hashimon_alen.flee_threshold(self._target
		and self._target:get_player_name() or nil) then
		return "flee"
	end

	-- Dos distancias distintas y la diferencia importa: te DETECTA a `sight`,
	-- pero una vez que te tiene te SIGUE hasta `pursuit`. Un Alen iracundo no ve
	-- mucho más lejos que uno calmado — te persigue muchísimo más.
	local range = self._target and tier.pursuit or tier.sight
	local target, d = nearest_player(pos, range)
	self._target = target
	if not target then
		self._seen = nil
		return "patrol"
	end

	-- Verlo es una observación, y las observaciones pasan por el escritor único.
	-- Se anota una vez por avistamiento, no una vez por segundo.
	local name = target:get_player_name()
	if self._seen ~= name then
		self._seen = name
		local first_time = hashimon_alen.knows(name) == nil
		hashimon_alen.alen_learn({ kind = "seen", who = name })
		if first_time and hashimon_alen.note_event then
			hashimon_alen.note_event("nuevo_jugador", name, { dist = math.floor(d) })
		end
		-- Puede saludar, o no. Lo decide su vanidad y lo que sienta por ti.
		local cat = hashimon_alen.greeting_for(name)
		if cat then hashimon_alen.say(cat) end
	end
	-- Si le estás hablando, se para. Y si le has picado la curiosidad, también.
	if in_conversation_with(name) or wants_to_watch(self, name, d) then
		return "listen"
	end

	if d < hashimon_alen.STRAFE_MIN then
		-- ESTE era el fallo que más se notaba en la partida: te acercabas para
		-- pegarle y él se alejaba, así que golpearlo parecía no hacer nada. Un
		-- Alen furioso no retrocede — se queda y castiga.
		return hashimon_alen.close_quarters_tactic(name)
	elseif d <= hashimon_alen.STRAFE_MAX then
		return "strafe"   -- banda de ataque
	end
	return "approach"
end

local function act(self, mode, pos, dtime)
	local target = self._target
	local tpos = target and target:get_pos()

	if mode == "patrol" then
		local s = hashimon_alen.get_state()
		self._anchor = self._anchor or s.pos or pos
		if not self._orbit or hashimon_alen.dist(pos, self._orbit) < 6 then
			local a = math.random() * math.pi * 2
			local r = 20 + math.random() * 30
			-- El destino de patrulla se generaba SIEMPRE en alto (+6 a +20), y un
			-- destino elevado mete "desnivel +40" en la puntuación de volar: le
			-- estábamos pidiendo caminar y dándole a la vez la razón para despegar.
			-- Si está en el suelo, patrulla a ras.
			local grounded = hashimon_alen.is_grounded(self)
			self._orbit = {
				x = self._anchor.x + math.cos(a) * r,
				y = grounded and pos.y or (self._anchor.y + 6 + math.random() * 14),
				z = self._anchor.z + math.sin(a) * r,
			}
		end
		-- El sitio donde más se va a ver caminar: patrullando cerca de casa, y
		-- sobre todo dentro de un asentamiento. Un dragón que cruza andando entre
		-- las casas intimida más que uno que flota encima.
		if hashimon_alen.consider_bombard(self, pos) then
			return
		end
		hashimon_alen.move_to(self, self._orbit, dtime, {
			in_settlement = hashimon_alen.in_settlement(pos),
		})

	elseif mode == "approach" and tpos then
		hashimon_alen.move_to(self, tpos, dtime, {
			target = target,
			target_airborne = tpos.y - (self.object:get_pos() or tpos).y > 8,
			in_settlement = hashimon_alen.in_settlement(pos),
			lift = 9,
		})

	elseif mode == "strafe" and tpos then
		if hashimon_alen.is_grounded(self) then
			local v = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
			self.object:set_velocity({ x = 0, y = v.y, z = 0 })
			hashimon_alen.set_anim(self, "idle")
		else
			hashimon_alen.hover_brake(self)
			hashimon_alen.set_anim(self, "hover")
		end
		local d = hashimon_alen.vsub(tpos, self.object:get_pos())
		hashimon_alen.turn_toward(self, -math.atan2(d.x, d.z), dtime)
		-- Telegrafía la primera vez que entra en banda de ataque contra este
		-- objetivo: el jugador merece medio segundo de aviso antes del aliento.
		if self._roared_at ~= target then
			self._roared_at = target
			hashimon_alen.play_oneshot(self, "roar")
			return
		end

		-- El cubo también es una decisión táctica, no sólo una reacción a la
		-- furia — pero sólo a partir de ANGRY. Un Alen calmado nunca abre con él,
		-- y el mínimo de energía 50 más el enfriamiento de 8 s hacen el resto.
		local tname = hashimon_alen.tier_toward(target:get_player_name()).name
		if (tname == "ANGRY" or tname == "WRATHFUL")
			and not hashimon_alen.attack_blocked(self, "firecube") then
			-- begin_firecube puede negarse por "too_close": entonces el aliento.
			if hashimon_alen.begin_firecube(self, target) then
				return
			end
		end
		hashimon_alen.try_breath(self, target)

	elseif mode == "peel" and tpos then
		local p0 = self.object:get_pos()
		local away = hashimon_alen.vsub(p0, tpos)
		hashimon_alen.move_to(self, {
			x = p0.x + away.x, y = p0.y + 6, z = p0.z + away.z,
		}, dtime, { target = target })

	elseif mode == "peel" and tpos == nil then
		hashimon_alen.hover_brake(self)

	elseif mode == "listen" then
		-- Quieto, en el suelo si puede, y mirándote. Sin ataques: escuchar y
		-- castigar a la vez no es escuchar.
		hashimon_alen.move_to(self, nil, dtime, { standing = true })
		if tpos then
			local p0 = self.object:get_pos()
			hashimon_alen.turn_toward(self, -math.atan2(tpos.x - p0.x, tpos.z - p0.z), dtime)
		end
		if hashimon_alen.is_grounded(self) then
			hashimon_alen.set_anim(self, "idle")
		else
			hashimon_alen.hover_brake(self)
			hashimon_alen.set_anim(self, "hover")
		end

	elseif mode == "depart" then
		-- La salida que pediste: se aleja de verdad, con la locomoción, y puede
		-- acabar en FLY_FAST si le apetece la salida dramática. Nada de saltos.
		local p0 = self.object:get_pos()
		local ref = tpos or self._anchor or p0
		local away = hashimon_alen.vsub(p0, ref)
		if math.abs(away.x) + math.abs(away.z) < 1 then
			away = { x = math.random(-1, 1) * 40, y = 0, z = math.random(-1, 1) * 40 }
		end
		hashimon_alen.move_to(self, {
			x = p0.x + away.x * 4, y = p0.y + 25, z = p0.z + away.z * 4,
		}, dtime, { departing = true })

	elseif mode == "flee" then
		-- Alen no muere en pantalla si puede evitarlo: salta y desaparece.
		local dest = hashimon_alen.find_jump_target(self.object:get_pos(), 120, 260, 14)
		if dest and hashimon_alen.begin_jump(self, dest) then
			self.hp = math.min(hashimon_alen.MAX_HP, self.hp + 40)
			self.mood = "replegado"
		else
			local t = tpos
			if t then
				local p0 = self.object:get_pos()
				local away = hashimon_alen.vsub(p0, t)
				hashimon_alen.move_to(self, {
					x = p0.x + away.x * 3, y = p0.y + 20, z = p0.z + away.z * 3,
				}, dtime, { fleeing = true, critical = true })
			end
		end
	end
end

--- Punto de entrada táctico, llamado desde el paso de la entidad.
function hashimon_alen.think(self, dtime)
	local pos = self.object:get_pos()
	if not pos then
		return
	end

	-- Estar atascado manda sobre absolutamente todo: si está enterrado o sumergido
	-- no hay táctica que valga, hay que sacarlo.
	if hashimon_alen.step_unstick(self, dtime) then
		return
	end

	-- Despegar y aterrizar mandan sobre todo lo demás. Van ANTES que la táctica
	-- porque hay ramas tácticas que frenan la velocidad a mano y peleaban contra
	-- el descenso.
	if hashimon_alen.step_transition(self) then
		return
	end

	-- Un salto cargado congela todo lo demás hasta que sale.
	hashimon_alen.step_jump(self)
	if self._jump_at then
		return
	end

	-- Igual el cubo: durante la carga se queda quieto y visible. Esa quietud ES
	-- el aviso, así que nada puede moverlo mientras dura.
	hashimon_alen.step_attacks(self, dtime)
	if self._charging then
		return
	end
	hashimon_alen.expire_fight(self)

	-- La psique corre a 1 Hz DENTRO del tick táctico que ya existía. No es un
	-- reloj nuevo: es el mismo acumulador, con otra carga.
	self._psy_acc = (self._psy_acc or 0) + dtime
	if self._psy_acc >= 1.0 then
		local pdt = self._psy_acc
		self._psy_acc = 0
		hashimon_alen.psyche_step(pdt, {
			in_combat = self._target ~= nil,
			-- Hasta la fase 4 no hay locomoción terrestre, así que la fatiga se
			-- acumula siempre al ritmo de vuelo. Es exacto hoy, no una simplificación.
			flying = true,
			-- Si la entidad existe es porque hay alguien a menos de 150 nodos:
			-- el gestor de observación lo garantiza.
			observed = true,
			target = self._target,
		})
	end

	if step_plan(self, dtime) then
		-- Un plan activo con un verbo "hunt" sigue necesitando el combate táctico.
		local v = self.plan and self.plan.verbs[self.plan.i]
		if v and v.op == "hunt" and self._target then
			act(self, decide(self, pos), pos, dtime)
		end
		return
	end

	self._tactic_acc = (self._tactic_acc or 0) + dtime
	if self._tactic_acc >= hashimon_alen.TACTIC_INTERVAL then
		self._tactic_acc = 0
		self.mode = decide(self, pos)
		self.mood = self.mode
	end
	act(self, self.mode or "patrol", pos, dtime)
end
