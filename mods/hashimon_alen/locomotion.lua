-- CÓMO se mueve Alen, que es una capa distinta de QUÉ quiere y de CÓMO se
-- comporta. La táctica pide un destino; aquí se decide si va andando o volando.
--
-- La física aérea de flight.lua NO se toca. Lo que se añade es su gemela
-- terrestre: `walk_toward` escribe sólo X y Z y deja la Y a la gravedad del
-- motor. Ese es el punto exacto donde una implementación ingenua se pelearía con
-- el vuelo — `fly_toward` escribe los tres ejes, así que reutilizarla para
-- caminar dejaría a Alen flotando a un centímetro del suelo.

hashimon_alen = hashimon_alen or {}

hashimon_alen.SPEEDS = {
	WALK = 3.0,
	GROUND_PURSUIT = 5.5,
	FLY = 7.0,
	FLY_FAST = 16.0,
	CIRCLE = 5.0,
}

-- Compromiso mínimo por modo, en segundos. Sin esto Alen oscila entre andar y
-- volar cada pocos segundos y parece un bicho indeciso en vez de uno enorme.
hashimon_alen.MODE_COMMIT = {
	WALK = 6.0, GROUND_PURSUIT = 4.0, FLY = 4.0,
	FLY_FAST = 3.0, CIRCLE = 8.0, GROUND_IDLE = 2.0,
}
hashimon_alen.SWITCH_MARGIN = 15  -- un modo nuevo tiene que GANAR por esto

-- Daño acumulado en el combate a partir del cual se toma el aire. Por debajo,
-- persigue a pie: es la escalada que hace del despegue un acontecimiento.
hashimon_alen.AIR_AFTER_DAMAGE = 25
-- ...pero sólo si es daño RECIENTE. Con el acumulado del combate, un solo golpe al
-- principio lo mandaba al aire para el resto de la pelea y ya no bajaba nunca.
hashimon_alen.RECENT_DAMAGE_WINDOW = 12
-- Y el aire cansa la decisión: cuanto más lleva volando sin que le peguen, más
-- tira el suelo. Es lo que le hace volver a bajar en vez de quedarse arriba.
hashimon_alen.AIR_PATIENCE = 25
-- Tras una explosión propia, nada de tierra: el cráter es exactamente donde se
-- queda enterrado. Decisión del usuario tras la sexta partida: "prefiero tenerlo
-- en el aire que perder calidad y hacerlo atorarse bajo tierra".
hashimon_alen.NO_GROUND_AFTER_BLAST = 10
hashimon_alen.BURIED_RESCUE_AFTER = 1.0

local GROUND_EPS = 1.6      -- a esta altura del suelo se considera en tierra
local STUCK_DIST = 0.5      -- movimiento real mínimo en STUCK_WINDOW
local STUCK_WINDOW = 2.0
local REPATH_MOVE = 15      -- si el destino se movió esto, recalcular ruta

-- --------------------------------------------------------------------------
-- Movimiento terrestre
-- --------------------------------------------------------------------------

function hashimon_alen.is_grounded(self)
	local pos = self.object:get_pos()
	if not pos then return false end
	local d = hashimon_alen.floor_below(pos, 3)
	return d ~= nil and d <= GROUND_EPS
end

--- Camina hacia un punto. Sólo X y Z: la Y es de la gravedad, y esa separación
--- es lo que hace que caminar se vea como caminar.
function hashimon_alen.walk_toward(self, target, speed, dtime)
	local pos = self.object:get_pos()
	if not pos or not target then return math.huge end

	local dx, dz = target.x - pos.x, target.z - pos.z
	local horiz = math.sqrt(dx * dx + dz * dz)
	if horiz < 0.001 then return 0 end

	local nx, nz = dx / horiz, dz / horiz
	local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }

	-- Subir un escalón. Las entidades de Luanti no tienen stepheight propio, así
	-- que un bordillo las para en seco: si hay bloque delante y aire encima, salta.
	local ahead = { x = pos.x + nx * 1.6, y = pos.y + 0.5, z = pos.z + nz * 1.6 }
	local n_ahead = core.get_node_or_nil(ahead)
	local d_ahead = n_ahead and core.registered_nodes[n_ahead.name]
	if d_ahead and d_ahead.walkable then
		local above = core.get_node_or_nil({ x = ahead.x, y = ahead.y + 1.6, z = ahead.z })
		local d_above = above and core.registered_nodes[above.name]
		if (not d_above or not d_above.walkable) and math.abs(vel.y) < 1.0 then
			vel.y = 5.5 -- salto corto para salvar el bordillo
		end
	end

	self.object:set_velocity({ x = nx * speed, y = vel.y, z = nz * speed })
	hashimon_alen.turn_toward(self, -math.atan2(dx, dz), dtime)
	return horiz
end

--- Conmuta gravedad y suelo mínimo a la vez. Son las dos mitades del mismo
--- cambio: quien está en tierra cae y puede rozar el suelo; quien vuela ni una
--- cosa ni la otra. `_landing` ya existía en flight.lua y sólo cambia de dueño.
local function set_airborne(self, airborne)
	if self._airborne == airborne then return end
	self._airborne = airborne
	self._airborne_since = airborne and core.get_gametime() or nil
	self.object:set_acceleration(airborne and { x = 0, y = 0, z = 0 }
		or { x = 0, y = -9.8, z = 0 })
	self._landing = not airborne
end

-- --------------------------------------------------------------------------
-- Viabilidad terrestre: barata, a 1 Hz. La DECISIÓN de caminar no necesita la
-- ruta — necesita saber si es plausible, y eso son tres consultas de nodo. El A*
-- sólo se paga cuando ya decidió.
-- --------------------------------------------------------------------------

function hashimon_alen.ground_viable(self, target)
	local pos = self.object:get_pos()
	if not pos or not target then return false, 0 end

	local dx, dz = target.x - pos.x, target.z - pos.z
	local horiz = math.sqrt(dx * dx + dz * dz)
	if horiz > 90 then return false, horiz end

	-- El desnivel que importa es el del TERRENO, no la altura a la que él vaya
	-- volando. Antes se comparaba `target.y` con `pos.y`, así que a treinta nodos
	-- de altura ninguna ruta terrestre era viable nunca — y eso lo mantenía en el
	-- aire por un bucle que se alimentaba a sí mismo. Es la causa principal de
	-- "sigue volando mucho".
	local my_floor = hashimon_alen.floor_below({ x = pos.x, y = pos.y, z = pos.z }, 90, true)
	local tgt_floor = hashimon_alen.floor_below({ x = target.x, y = target.y + 2, z = target.z }, 30, true)
	if not my_floor or not tgt_floor then return false, horiz end
	local my_ground_y = pos.y - my_floor
	local tgt_ground_y = (target.y + 2) - tgt_floor
	if math.abs(tgt_ground_y - my_ground_y) > 14 then return false, horiz end

	-- Tres catas a lo largo del trayecto. Parten del nivel del SUELO, no de su
	-- altitud: antes salían de `pos.y + 4` y escaneaban 12 nodos, así que volando
	-- a treinta metros no alcanzaban tierra jamás y todo era "inviable". Mismo
	-- error que el desnivel, y la otra mitad de "sigue volando mucho".
	local prev_y = my_ground_y
	for _, f in ipairs({ 0.25, 0.5, 0.75 }) do
		local p = { x = pos.x + dx * f, y = prev_y + 20, z = pos.z + dz * f }
		local d = hashimon_alen.floor_below(p, 40, true)
		if not d then
			return false, horiz -- barranco, vacío o mapblock sin cargar
		end
		local y_here = (prev_y + 20) - d
		-- Y un escalón enorme entre catas consecutivas es un acantilado, aunque
		-- el desnivel total de punta a punta sea pequeño.
		if math.abs(y_here - prev_y) > 12 then
			return false, horiz
		end
		prev_y = y_here
	end
	return true, horiz
end

--- El A* del motor, sólo bajo demanda. Nunca en un tick fijo.
function hashimon_alen.repath(self, target)
	local pos = self.object:get_pos()
	if not pos or not target then return false end
	local path = core.find_path(vector.round(pos), vector.round(target), 32, 1, 2, "A*")
	if not path or #path == 0 then
		self._path, self._path_i = nil, nil
		return false
	end
	self._path, self._path_i = path, 1
	self._path_for = { x = target.x, y = target.y, z = target.z }
	return true
end

local function follow_path(self, speed, dtime)
	local p = self._path
	if not p then return nil end
	local wp = p[self._path_i]
	if not wp then
		self._path, self._path_i = nil, nil
		return nil
	end
	local pos = self.object:get_pos()
	if hashimon_alen.dist(pos, wp) < 1.5 then
		self._path_i = self._path_i + 1
		wp = p[self._path_i]
		if not wp then
			self._path, self._path_i = nil, nil
			return nil
		end
	end
	hashimon_alen.walk_toward(self, wp, speed, dtime)
	return true
end

-- --------------------------------------------------------------------------
-- Atascos: recuperación local ANTES de despegar. Nunca correr contra la pared, y
-- nunca despegar como primera reacción.
-- --------------------------------------------------------------------------

local function check_stuck(self, dtime)
	local pos = self.object:get_pos()
	if not pos then return false end
	self._stuck_acc = (self._stuck_acc or 0) + dtime
	if not self._stuck_from then
		self._stuck_from = pos
		return false
	end
	if self._stuck_acc < STUCK_WINDOW then return false end

	local moved = hashimon_alen.dist(pos, self._stuck_from)
	self._stuck_acc, self._stuck_from = 0, pos
	if moved >= STUCK_DIST then
		self._stuck_strikes = 0
		return false
	end
	self._stuck_strikes = (self._stuck_strikes or 0) + 1
	return true
end

function hashimon_alen.reset_stuck(self)
	self._stuck_acc, self._stuck_from, self._stuck_strikes = 0, nil, 0
end

--- ¿Está pisando un asentamiento? Es percepción pura —dónde está él— y por eso
--- es legítimo consultarlo: no es saber de qué pueblo es otro, es mirar al suelo.
function hashimon_alen.in_settlement(pos)
	if not (mg_villages and mg_villages.get_town_id_at_pos) then return false end
	return mg_villages.get_town_id_at_pos(pos) ~= nil
end

-- --------------------------------------------------------------------------
-- Utilidad de locomoción. Misma forma que tendrá la de objetivos: cada función
-- devuelve (total, términos), y los términos SON el WHY — no un registro aparte
-- que pueda mentir sobre lo que se decidió.
-- --------------------------------------------------------------------------

local function T(list, name, value)
	if value ~= 0 then list[#list + 1] = { name = name, v = value } end
	return value
end

local function sum(list)
	local s = 0
	for i = 1, #list do s = s + list[i].v end
	return s
end

--- Azar acotado y reproducible: se deriva de la semilla, no de math.random, para
--- que un Alen impredecible siga siendo depurable.
local function noise(mode, span)
	local s = hashimon_alen.get_state()
	local h = core.sha256((s.seed or "x") .. mode .. tostring(math.floor(core.get_gametime() / 5)))
	return ((tonumber(h:sub(1, 4), 16) / 0xFFFF) - 0.5) * 2 * span
end

function hashimon_alen.score_modes(self, ctx)
	local st = hashimon_alen.get_state()
	local tier = hashimon_alen.tier()
	local energy = st.energy or 0
	local grounded = ctx.grounded
	local dist = ctx.dist or 999
	local dy = ctx.dy or 0
	local out = {}

	-- La penalización energética se ablanda con la ira: un Alen furioso PUEDE
	-- tomar la mala decisión de volar sin reservas, y eso es carácter.
	local rage_soften = 1 - (st.anger or 0) / 150

	-- REGLA NUEVA, de la tercera partida: Alen DISFRUTA estar en tierra. Un dragón
	-- de cuatro metros caminando hacia ti impone mucho más que uno flotando, que
	-- se lee barato. El aire deja de ser el estado por defecto y pasa a ser la
	-- ESCALADA: despega cuando ya ha recibido daño, o cuando el terreno no le deja
	-- otra. Eso convierte el despegue en un acontecimiento en vez de en su modo
	-- de vida.
	-- Daño RECIENTE, no del combate entero.
	local f = self._fight
	local fresh = f and (core.get_gametime() - (f.last_at or 0)) <= hashimon_alen.RECENT_DAMAGE_WINDOW
	local hurt = fresh and (f.damage or 0) >= hashimon_alen.AIR_AFTER_DAMAGE
	local wants_air = hurt or ctx.target_airborne or (not ctx.viable) or dy > 12 or dist > 70

	-- Cuánto lleva en el aire. Pasada la paciencia, el suelo empieza a tirar.
	local air_time = (not grounded) and self._airborne_since
		and (core.get_gametime() - self._airborne_since) or 0
	local air_tired = math.min(45, math.max(0,
		(air_time - hashimon_alen.AIR_PATIENCE) * 1.5))

	-- VETOS DUROS al suelo. Cada uno es un sitio real donde se quedó atascado.
	local pos = self.object and self.object:get_pos()
	local in_liquid = pos and hashimon_alen.node_is_liquid(pos) or false
	local buried = pos and hashimon_alen.is_buried(pos) or false
	local blasted = self._no_ground_until
		and core.get_gametime() < self._no_ground_until or false
	local veto = (in_liquid and -250 or 0) + (buried and -250 or 0)
		+ (blasted and -150 or 0)

	local w = {}
	T(w, "prefiere el suelo", 18)
	T(w, "veto: líquido/enterrado/cráter", veto)             -- le gusta estar abajo, sin más
	T(w, "cerca", dist < 40 and 45 * (1 - dist / 40) or 0)
	T(w, "sin desnivel", dy < 8 and 18 or 0)
	T(w, "ya en tierra", grounded and 40 or 0) -- quedarse abajo es muy barato
	T(w, "ruta viable", ctx.viable and 20 or -60)
	T(w, "energía baja", 22 * (1 - energy / hashimon_alen.MAX_ENERGY))
	T(w, "en asentamiento", ctx.in_settlement and 25 or 0)
	T(w, "aún no le han hecho daño", (not hurt) and 20 or -25)
	-- Si ha decidido escuchar, moverse contradice la escena entera: un dragón que
	-- se pone a caminar mientras le hablas no está escuchando.
	T(w, "le están hablando", ctx.standing and -90 or 0)
	T(w, "lleva rato volando", air_tired)
	T(w, "azar", noise("WALK", 4))
	out.WALK = { score = sum(w), terms = w }

	-- Perseguir a pie es LA imagen que buscamos. Por eso la ira suma aquí y ya no
	-- en volar: un Alen furioso camina hacia ti, no te sobrevuela.
	local gp = {}
	T(gp, "veto: líquido/enterrado/cráter", veto)
	T(gp, "objetivo", ctx.target and 40 or -100)
	T(gp, "cerca", dist < 45 and 45 * (1 - dist / 45) or 0)
	T(gp, "ya en tierra", grounded and 35 or -10)
	T(gp, "ruta viable", ctx.viable and 20 or -60)
	T(gp, "sin desnivel", dy < 10 and 18 or -25)
	T(gp, "ira", (tier.name == "ANGRY" or tier.name == "WRATHFUL") and 30 or 0)
	T(gp, "aún no le han hecho daño", (not hurt) and 25 or -20)
	T(gp, "le están hablando", ctx.standing and -90 or 0)
	T(gp, "lleva rato volando", air_tired)
	T(gp, "azar", noise("GP", 4))
	out.GROUND_PURSUIT = { score = sum(gp), terms = gp }

	local f = {}
	-- El aire arranca en negativo: hay que darle una razón. Antes era el estado
	-- por defecto y por eso "se sentía barato".
	T(f, "base", -20)
	-- El reverso del veto: si el suelo es una trampa, el aire es la respuesta.
	T(f, "suelo peligroso", (veto < 0) and 200 or 0)
	T(f, "le han hecho daño", hurt and 55 or 0)   -- LA razón principal para volar
	T(f, "lejos", dist > 70 and 45 or 0)
	T(f, "desnivel", dy > 12 and 40 or 0)
	T(f, "ruta terrestre inviable", (not ctx.viable) and 55 or 0)
	T(f, "objetivo en el aire", ctx.target_airborne and 50 or 0)
	T(f, "ya volando", (not grounded) and 15 or 0)
	T(f, "lleva rato volando", -air_tired)
	T(f, "energía baja", -25 * (1 - energy / hashimon_alen.MAX_ENERGY) * rage_soften)
	T(f, "azar", noise("FLY", 4))
	out.FLY = { score = sum(f), terms = f }

	local ff = {}
	T(ff, "base", -40)
	T(ff, "furia persiguiendo", (tier.name == "WRATHFUL" and ctx.target and wants_air) and 75 or 0)
	T(ff, "huyendo", ctx.fleeing and 70 or 0)
	T(ff, "viaje largo", dist > 200 and 50 or 0)
	T(ff, "salida", ctx.departing and 45 or 0)
	T(ff, "sin energía", energy < hashimon_alen.MAX_ENERGY * 0.1 and -30 * rage_soften or 0)
	out.FLY_FAST = { score = sum(ff), terms = ff }

	local c = {}
	T(c, "observando", ctx.circling and 40 or -30)
	T(c, "ya volando", (not grounded) and 20 or -20)
	T(c, "recargando", energy < hashimon_alen.MAX_ENERGY * 0.15 and 25 or 0)
	out.CIRCLE = { score = sum(c), terms = c }

	-- Quedarse quieto en el suelo NO es la ausencia de una decisión: es la
	-- invitación a que le hables. Un dragón plantado mirándote es una escena.
	local gi = {}
	T(gi, "veto: líquido/enterrado/cráter", veto)
	T(gi, "quieto a propósito", ctx.standing and 70 or 0)
	T(gi, "en tierra sin destino", (grounded and not ctx.dest) and 35 or -40)
	T(gi, "curiosidad", ctx.standing and hashimon_alen.traits().curiosity * 25 or 0)
	out.GROUND_IDLE = { score = sum(gi), terms = gi }

	return out
end

--- Elige modo con las dos histéresis: tiempo mínimo Y margen. Cada una sola se
--- puede burlar — el tiempo deja un modo equivocado clavado, y el margen solo
--- parpadea cuando dos puntuaciones se rozan.
function hashimon_alen.choose_mode(self, ctx, critical)
	local scores = hashimon_alen.score_modes(self, ctx)
	self._loco_scores = scores

	local cur = self._loco_mode
	local now = core.get_gametime()
	local held = now - (self._loco_since or 0)

	-- Las transiciones son intocables salvo emergencia: TAKEOFF y LAND duran lo
	-- que dura su clip, y cortarlas es el teletransporte vertical que delata a
	-- un sprite.
	if (cur == "TAKEOFF" or cur == "LAND") and not critical then
		return cur
	end

	local best, best_s = nil, -math.huge
	for m, r in pairs(scores) do
		if r.score > best_s then best, best_s = m, r.score end
	end
	if not cur then return best end

	if not critical then
		if held < (hashimon_alen.MODE_COMMIT[cur] or 4) then
			return cur
		end
		local cur_s = scores[cur] and scores[cur].score or -math.huge
		if best_s < cur_s + hashimon_alen.SWITCH_MARGIN then
			return cur
		end
	end
	return best
end

--- Aplica el modo, insertando TAKEOFF o LAND cuando toca cruzar entre tierra y
--- aire. Los dos conjuntos no se tocan directamente nunca.
function hashimon_alen.set_mode(self, mode)
	if self._loco_mode == mode then return end

	local GROUND = { WALK = true, GROUND_PURSUIT = true, GROUND_IDLE = true, SLEEP = true }
	local from_ground = GROUND[self._loco_mode or "GROUND_IDLE"]
	local to_ground = GROUND[mode]

	if self._loco_mode and from_ground ~= to_ground then
		local trans = to_ground and "LAND" or "TAKEOFF"
		self._loco_mode = trans
		self._loco_since = core.get_gametime()
		self._loco_after = mode
		set_airborne(self, true) -- ambas transiciones ocurren en el aire
		hashimon_alen.play_oneshot(self, trans:lower())
		self._trans_until = core.get_gametime()
			+ math.max(hashimon_alen.state_duration(trans:lower()), 0.6)
		return
	end

	self._loco_mode = mode
	self._loco_since = core.get_gametime()
	set_airborne(self, not to_ground)
	hashimon_alen.reset_stuck(self)
end

--- El golpe de un dragón de cuatro nodos tocando el suelo. Polvo, ruido y
--- empujón: aterrizar tiene que sentirse, no sólo verse.
function hashimon_alen.landing_impact(self)
	local pos = self.object:get_pos()
	if not pos then return end

	core.sound_play("default_hard_footstep",
		{ pos = pos, gain = 1.6, max_hear_distance = 70 }, true)
	core.add_particlespawner({
		amount = 120, time = 0.45,
		minpos = { x = pos.x - 3, y = pos.y - 0.5, z = pos.z - 3 },
		maxpos = { x = pos.x + 3, y = pos.y + 1.0, z = pos.z + 3 },
		minvel = { x = -5, y = 0.5, z = -5 }, maxvel = { x = 5, y = 3.5, z = 5 },
		minexptime = 0.5, maxexptime = 1.6, minsize = 2, maxsize = 6,
		texture = "default_dirt.png", collisiondetection = false,
	})

	-- Empujón a quien esté debajo. Poco daño: el susto es el efecto, no la muerte.
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 6)) do
		if obj:is_player() then
			local pp = obj:get_pos()
			local away = vector.subtract(pp, pos)
			away.y = 0
			if vector.length(away) > 0.1 then
				away = vector.normalize(away)
				obj:add_velocity({ x = away.x * 7, y = 4, z = away.z * 7 })
			else
				obj:add_velocity({ x = 0, y = 5, z = 0 })
			end
			obj:set_hp((obj:get_hp() or 20) - 2)
		end
	end
end

--- Cierra las transiciones cuando su clip termina.
---
--- PÚBLICA y llamada desde think(), no desde move_to. Ese era el fallo del
--- aterrizaje: move_to no se ejecuta en todas las ramas tácticas —strafe y wait
--- frenan a mano— y `hover_brake` suma +0.12 de sustentación cada tick, así que
--- peleaba contra el descenso. Una transición es estado de LOCOMOCIÓN y tiene que
--- avanzar pase lo que pase, con todo lo demás sin tocar la velocidad.
function hashimon_alen.step_transition(self)
	if self._loco_mode ~= "TAKEOFF" and self._loco_mode ~= "LAND" then return false end
	if core.get_gametime() < (self._trans_until or 0) then
		local v = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
		if self._loco_mode == "TAKEOFF" then
			self.object:set_velocity({ x = v.x * 0.8, y = 4.5, z = v.z * 0.8 })
		else
			-- Descenso que acelera: un aterrizaje a velocidad constante parece un
			-- ascensor. Y se frena en seco al tocar.
			local d = hashimon_alen.floor_below(self.object:get_pos(), 4)
			if d and d <= 1.2 then
				self._trans_until = 0 -- ya está: cierra ya, sin esperar al clip
			else
				self.object:set_velocity({ x = v.x * 0.7, y = -6.5, z = v.z * 0.7 })
			end
		end
		return true
	end

	local landed = self._loco_mode == "LAND"
	local after = self._loco_after or "FLY"
	self._loco_after, self._trans_until = nil, nil
	self._loco_mode = nil -- fuerza el set_mode limpio
	hashimon_alen.set_mode(self, after)
	if landed then
		self.object:set_velocity({ x = 0, y = 0, z = 0 })
		hashimon_alen.landing_impact(self)
	end
	return false
end

-- --------------------------------------------------------------------------
-- La puerta que usa la táctica. Reemplaza las llamadas directas a fly_toward:
-- se le da un destino y ella decide cómo se llega.
-- --------------------------------------------------------------------------

--- Rescate. Un dragón clavado dentro del terreno no es un bug de física que se
--- pueda esperar a que se resuelva solo: hay que sacarlo. Feo pero terminante.
function hashimon_alen.step_unstick(self, dtime)
	local pos = self.object:get_pos()
	if not pos then return false end

	local trapped = hashimon_alen.is_buried(pos) or hashimon_alen.node_is_liquid(pos)
	if not trapped then
		self._buried_for = 0
		return false
	end

	self._buried_for = (self._buried_for or 0) + dtime
	-- Primero se intenta salir volando por las buenas.
	self.object:set_acceleration({ x = 0, y = 0, z = 0 })
	self._airborne, self._landing = true, false
	self.object:set_velocity({ x = 0, y = 6, z = 0 })
	self._loco_mode, self._loco_since = "FLY", core.get_gametime()
	self._airborne_since = self._airborne_since or core.get_gametime()

	if self._buried_for >= hashimon_alen.BURIED_RESCUE_AFTER then
		local air = hashimon_alen.first_air_above(pos, 40)
		if air then
			self.object:set_pos({ x = air.x, y = air.y + 2, z = air.z })
			self.object:set_velocity({ x = 0, y = 2, z = 0 })
			core.log("action", string.format(
				"[alen] rescatado de estar atascado en (%.0f,%.0f,%.0f)", pos.x, pos.y, pos.z))
		end
		self._buried_for = 0
	end
	return true
end

function hashimon_alen.move_to(self, dest, dtime, opts)
	opts = opts or {}
	-- Las transiciones las avanza think(); aquí sólo hay que no estorbarlas.
	if self._loco_mode == "TAKEOFF" or self._loco_mode == "LAND" then return end

	local pos = self.object:get_pos()
	if not pos then return end

	local grounded = hashimon_alen.is_grounded(self)
	local dist = dest and hashimon_alen.dist(pos, dest) or 999
	local dy = dest and math.abs(dest.y - pos.y) or 0

	-- Viabilidad a 1 Hz, no cada tick.
	self._viab_acc = (self._viab_acc or 0) + dtime
	if self._viab_acc >= 1.0 or self._viable == nil then
		self._viab_acc = 0
		self._viable = dest and hashimon_alen.ground_viable(self, dest) or false
	end

	local ctx = {
		grounded = grounded, dist = dist, dy = dy, dest = dest,
		viable = self._viable, target = opts.target,
		target_airborne = opts.target_airborne, fleeing = opts.fleeing,
		departing = opts.departing, circling = opts.circling,
		in_settlement = opts.in_settlement, standing = opts.standing,
	}

	local critical = opts.critical
	-- Un atasco confirmado dos veces es motivo crítico: rompe la histéresis y
	-- despega, pero sólo DESPUÉS de haber intentado rodear.
	if grounded and check_stuck(self, dtime) then
		if (self._stuck_strikes or 0) == 1 then
			self._detour_until = core.get_gametime() + 1.5
			self._detour_sign = math.random() < 0.5 and 1 or -1
		elseif (self._stuck_strikes or 0) >= 2 then
			critical = true
			ctx.viable = false -- que la utilidad sepa por qué
			hashimon_alen.reset_stuck(self)
		end
	end

	hashimon_alen.set_mode(self, hashimon_alen.choose_mode(self, ctx, critical))
	local mode = self._loco_mode
	if mode == "TAKEOFF" or mode == "LAND" then return end
	if not dest then
		if mode == "GROUND_IDLE" then
			local v = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
			self.object:set_velocity({ x = 0, y = v.y, z = 0 })
			hashimon_alen.set_anim(self, "idle")
		end
		return
	end

	local speed = hashimon_alen.SPEEDS[mode] or 5

	if mode == "WALK" or mode == "GROUND_PURSUIT" then
		-- Rodeo local antes que nada.
		if self._detour_until and core.get_gametime() < self._detour_until then
			local d = vector.subtract(dest, pos)
			local side = { x = -d.z * self._detour_sign, y = 0, z = d.x * self._detour_sign }
			hashimon_alen.walk_toward(self, vector.add(pos, vector.normalize(side)), speed, dtime)
			hashimon_alen.set_anim(self, "walk")
			return
		end
		-- A* sólo si hace falta: al entrar en el modo o si el destino se movió.
		if not self._path or (self._path_for
			and hashimon_alen.dist(self._path_for, dest) > REPATH_MOVE) then
			hashimon_alen.repath(self, dest)
		end
		if not follow_path(self, speed, dtime) then
			hashimon_alen.walk_toward(self, dest, speed, dtime)
		end
		hashimon_alen.set_anim(self, mode == "GROUND_PURSUIT" and "run" or "walk")
		return
	end

	-- Aéreo: la física de siempre, sin tocar.
	hashimon_alen.fly_toward(self, dest, speed, dtime, opts.lift or 0)
	hashimon_alen.set_anim(self, mode == "FLY_FAST" and "fly_fast" or "fly")
end
