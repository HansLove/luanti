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
hashimon_alen.SIGHT = 48        -- a cuánto detecta jugadores
hashimon_alen.STRAFE_MIN = 8    -- más cerca que esto, se aleja
hashimon_alen.STRAFE_MAX = 22   -- más lejos, se acerca
hashimon_alen.FLEE_HP = 0.22    -- fracción de vida a la que rompe el combate

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

hashimon_alen.VERBS = { "goto", "patrol_area", "hunt", "blockjump", "wait", "say" }

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
				{ motivo = why, verbo = had.i, de = #had.verbs }
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
		local d = hashimon_alen.fly_toward(self, v, CRUISE, dtime, 0)
		hashimon_alen.set_anim(self, "fly")
		done = d < 4

	elseif v.op == "patrol_area" then
		v._until = v._until or (core.get_gametime() + (v.minutes or 2) * 60)
		if not self._orbit or hashimon_alen.dist(pos, self._orbit) < 5 then
			local a = math.random() * math.pi * 2
			local r = v.radius or 30
			self._orbit = { x = v.x + math.cos(a) * r, y = v.y + 10, z = v.z + math.sin(a) * r }
		end
		hashimon_alen.fly_toward(self, self._orbit, CRUISE * 0.8, dtime, 0)
		hashimon_alen.set_anim(self, "fly")
		done = core.get_gametime() > v._until

	elseif v.op == "hunt" then
		local target = v.target and core.get_player_by_name(v.target)
		if not target or not target:get_pos() then
			target = nearest_player(pos, hashimon_alen.SIGHT)
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

	elseif v.op == "wait" then
		v._until = v._until or (core.get_gametime() + (v.seconds or 5))
		hashimon_alen.hover_brake(self)
		hashimon_alen.set_anim(self, "hover")
		done = core.get_gametime() > v._until

	elseif v.op == "say" then
		if not v._said then
			v._said = true
			core.chat_send_all(core.colorize("#F97316", "<Alen Gregory> ") .. tostring(v.text or "..."))
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

local function decide(self, pos)
	-- Vida baja rompe cualquier otra consideración.
	if self.hp <= hashimon_alen.MAX_HP * hashimon_alen.FLEE_HP then
		return "flee"
	end

	local target, d = nearest_player(pos, hashimon_alen.SIGHT)
	self._target = target
	if not target then
		self._seen = nil
		return "patrol"
	end

	-- Alguien a quien no conoce entrando en su campo: la novedad por excelencia.
	-- Se anota una sola vez por avistamiento, no una vez por segundo.
	local name = target:get_player_name()
	if self._seen ~= name then
		self._seen = name
		if not hashimon_alen.knows(name) and hashimon_alen.note_event then
			hashimon_alen.note_event("nuevo_jugador", name, { dist = math.floor(d) })
		end
	end
	if d < hashimon_alen.STRAFE_MIN then
		return "peel"     -- demasiado cerca: rompe y recoloca
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
			self._orbit = {
				x = self._anchor.x + math.cos(a) * r,
				y = self._anchor.y + 6 + math.random() * 14,
				z = self._anchor.z + math.sin(a) * r,
			}
		end
		local d = hashimon_alen.fly_toward(self, self._orbit, CRUISE * 0.7, dtime, 0)
		hashimon_alen.set_anim(self, d < 10 and "hover" or "fly")

	elseif mode == "approach" and tpos then
		hashimon_alen.fly_toward(self, tpos, CHARGE, dtime, 9)
		hashimon_alen.set_anim(self, "fly_fast")

	elseif mode == "strafe" and tpos then
		hashimon_alen.hover_brake(self)
		hashimon_alen.set_anim(self, "hover")
		local d = hashimon_alen.vsub(tpos, self.object:get_pos())
		hashimon_alen.turn_toward(self, -math.atan2(d.x, d.z), dtime)
		-- Telegrafía la primera vez que entra en banda de ataque contra este
		-- objetivo: el jugador merece medio segundo de aviso antes del aliento.
		if self._roared_at ~= target then
			self._roared_at = target
			hashimon_alen.play_oneshot(self, "roar")
		else
			hashimon_alen.try_breath(self, target)
		end

	elseif mode == "peel" and tpos then
		local away = hashimon_alen.vsub(self.object:get_pos(), tpos)
		hashimon_alen.fly_toward(self, {
			x = self.object:get_pos().x + away.x,
			y = self.object:get_pos().y + 6,
			z = self.object:get_pos().z + away.z,
		}, CHARGE, dtime, 0)
		hashimon_alen.set_anim(self, "fly")

	elseif mode == "flee" then
		-- Alen no muere en pantalla si puede evitarlo: salta y desaparece.
		local dest = hashimon_alen.find_jump_target(self.object:get_pos(), 120, 260, 14)
		if dest and hashimon_alen.begin_jump(self, dest) then
			self.hp = math.min(hashimon_alen.MAX_HP, self.hp + 40)
			self.mood = "replegado"
		else
			local t = tpos
			if t then
				local away = hashimon_alen.vsub(self.object:get_pos(), t)
				hashimon_alen.fly_toward(self, {
					x = self.object:get_pos().x + away.x * 3,
					y = self.object:get_pos().y + 20,
					z = self.object:get_pos().z + away.z * 3,
				}, CHARGE, dtime, 0)
			end
			hashimon_alen.set_anim(self, "fly")
		end
	end
end

--- Punto de entrada táctico, llamado desde el paso de la entidad.
function hashimon_alen.think(self, dtime)
	local pos = self.object:get_pos()
	if not pos then
		return
	end

	-- Un salto cargado congela todo lo demás hasta que sale.
	hashimon_alen.step_jump(self)
	if self._jump_at then
		return
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
