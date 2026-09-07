-- Los ataques de Alen y su economía, en un solo sitio.
--
-- El limitante estratégico es la ENERGÍA, no un enfriamiento por ataque. El
-- enfriamiento existe sólo para que la animación tenga tiempo de leerse; lo que
-- decide si Alen puede seguir castigando es el recurso.
--
-- Y el ataque mayor no se dispara sólo porque haya energía: se dispara porque
-- alguien se pasó de la raya. Que te pegue un jugador tiene que ser un
-- acontecimiento, y esta es la parte donde ese acontecimiento tiene consecuencias.

hashimon_alen = hashimon_alen or {}

hashimon_alen._has_tnt = core.get_modpath("tnt") ~= nil

-- --------------------------------------------------------------------------
-- La tabla central. Ningún número de ataque vive fuera de aquí.
-- --------------------------------------------------------------------------

hashimon_alen.ATTACKS = {
	breath = {
		energy_cost = 8,
		min_energy = 8,
		cooldown = 2.6,      -- se reduce con la ira, ver cooldown_for()
		range = 28,
		damage = 9,
		speed = 22,
		ttl = 3.5,
		anim = "breath",
	},
	firecube = {
		energy_cost = 45,
		-- Mínimo POR ENCIMA del coste: Alen no se deja a cero por decisión propia.
		-- Un jefe literalmente vacío parece tonto, no agotado. La furia sí puede
		-- saltarse este mínimo — ver rage_allows().
		min_energy = 50,
		cooldown = 8.0,
		range = 42,
		-- Distancia MÍNIMA. El radio de daño es 7: lanzarlo más cerca era
		-- reventarse los propios pies, caer al cráter y quedarse enterrado.
		min_range = 12,
		damage = 16,         -- impacto directo, aparte de la explosión
		speed = 11,          -- LENTO a propósito: se puede esquivar, y por eso
		                     -- es decisivo en vez de injusto
		ttl = 6.0,
		charge = 1.4,        -- segundos de telegrafía antes de salir
		blast_radius = 3,
		blast_damage_radius = 7,
		max_flames = 6,
		anim = "roar",
	},
}

-- El umbral de furia: daño acumulado en un mismo combate que provoca el cubo.
-- Con 400 de vida, 55 son ~14 % — unos pocos golpes buenos, no una eternidad.
hashimon_alen.RAGE_DAMAGE = 55

-- --------------------------------------------------------------------------
-- Escalones de energía, derivados. No se almacenan.
-- --------------------------------------------------------------------------

function hashimon_alen.energy_tier()
	local e = hashimon_alen.get_state().energy or 0
	if e >= 70 then return "ENERGETIC" end
	if e >= 35 then return "NORMAL" end
	if e >= 15 then return "LOW" end
	return "EXHAUSTED"
end

--- El enfriamiento del aliento baja con la ira. Es lo que hace que golpear a
--- Alen se NOTE: el mismo ataque, pero llegando el doble de seguido.
function hashimon_alen.cooldown_for(attack_name, target_name)
	local a = hashimon_alen.ATTACKS[attack_name]
	if not a then return 99 end
	local tier = hashimon_alen.tier_toward(target_name).name
	local mult = (tier == "WRATHFUL" and 0.55)
		or (tier == "ANGRY" and 0.7)
		or (tier == "IRRITATED" and 0.85)
		or 1.0
	return a.cooldown * mult
end

--- ¿La furia justifica saltarse el mínimo de energía? Un Alen iracundo puede
--- gastar sus últimas reservas: es una mala decisión que toma él, no un fallo.
local function rage_allows(self)
	return hashimon_alen.tier().name == "WRATHFUL"
		and (self._fight and self._fight.damage or 0) >= hashimon_alen.RAGE_DAMAGE
end

--- Razón exacta por la que un ataque no sale. Viaja al ack del planificador.
function hashimon_alen.attack_blocked(self, name)
	local a = hashimon_alen.ATTACKS[name]
	if not a then return "unknown_attack" end
	local now = core.get_gametime()
	local last = self._cd and self._cd[name]
	if last and now - last < hashimon_alen.cooldown_for(name, self._fight and self._fight.who) then
		return "cooling_down"
	end
	local floor_e = rage_allows(self) and a.energy_cost or a.min_energy
	if (hashimon_alen.get_state().energy or 0) < floor_e then
		return "insufficient_energy"
	end
	return nil
end

local function mark_used(self, name)
	self._cd = self._cd or {}
	self._cd[name] = core.get_gametime()
end

-- --------------------------------------------------------------------------
-- El cubo de fuego. Grande, lento y luminoso: se ve venir desde lejos, que es
-- exactamente lo que tiene que pasar.
-- --------------------------------------------------------------------------

local CUBE_TEX = "fire_basic_flame.png^[colorize:#F97316:110"

core.register_entity("hashimon_alen:firecube", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "cube",
		visual_size = { x = 3.4, y = 3.4, z = 3.4 },
		textures = { CUBE_TEX, CUBE_TEX, CUBE_TEX, CUBE_TEX, CUBE_TEX, CUBE_TEX },
		glow = 14,
		static_save = false,
	},
	_age = 0,

	on_activate = function(self)
		self.object:set_acceleration({ x = 0, y = -1.6, z = 0 }) -- arco suave
	end,

	on_step = function(self, dtime)
		self._age = self._age + dtime
		local a = hashimon_alen.ATTACKS.firecube
		local pos = self.object:get_pos()
		if not pos or self._age > a.ttl then
			if pos then hashimon_alen.firecube_burst(pos) end
			self.object:remove()
			return
		end

		-- Gira mientras cae. Un cubo que no rota parece un bloque colocado.
		local r = self.object:get_rotation()
		self.object:set_rotation({ x = r.x + dtime * 1.4, y = r.y + dtime * 2.1, z = r.z })

		core.add_particlespawner({
			amount = 6, time = dtime,
			minpos = vector.subtract(pos, 1.4), maxpos = vector.add(pos, 1.4),
			minvel = { x = -0.5, y = -1, z = -0.5 }, maxvel = { x = 0.5, y = 1, z = 0.5 },
			minexptime = 0.3, maxexptime = 0.9, minsize = 2, maxsize = 5,
			texture = CUBE_TEX, glow = 14,
		})

		local node = core.get_node_or_nil(pos)
		local def = node and core.registered_nodes[node.name]
		if def and def.walkable then
			hashimon_alen.firecube_burst(pos)
			self.object:remove()
			return
		end
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 2.4)) do
			if obj:is_player() then
				obj:set_hp((obj:get_hp() or 20) - a.damage)
				hashimon_alen.firecube_burst(pos)
				self.object:remove()
				return
			end
		end
	end,
})

--- La detonación. Toda la destrucción pasa por tnt.boom con `owner`, que consulta
--- core.is_protected nodo a nodo — el mismo override que desprotege las aldeas en
--- guerra. `ignore_protection` NO se pasa aquí ni en ningún otro sitio del mod:
--- Alen juega con las mismas reglas de propiedad que todos.
function hashimon_alen.firecube_burst(pos)
	local a = hashimon_alen.ATTACKS.firecube

	-- Si revienta cerca de él, el suelo de esa zona queda vetado un rato: el
	-- cráter es exactamente donde se quedaba enterrado.
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if live then
		local lp = live.object:get_pos()
		if lp and hashimon_alen.dist(lp, pos) < a.blast_damage_radius + 6 then
			live._no_ground_until = core.get_gametime()
				+ hashimon_alen.NO_GROUND_AFTER_BLAST
		end
	end

	if hashimon_alen._has_tnt and tnt and tnt.boom then
		tnt.boom(pos, {
			radius = a.blast_radius,
			damage_radius = a.blast_damage_radius,
			owner = "alen_gregory",
			explode_center = true,
		})
	else
		core.sound_play("tnt_explode", { pos = pos, max_hear_distance = 80 }, true)
		for _, obj in ipairs(core.get_objects_inside_radius(pos, a.blast_damage_radius)) do
			if obj:is_player() then
				obj:set_hp((obj:get_hp() or 20) - a.damage)
			end
		end
	end

	-- Llamas, acotadas. El techo del incendio es el techo de la explosión y no la
	-- extensión del bosque — y sólo donde la protección deja.
	if core.registered_nodes["fire:basic_flame"] then
		local placed = 0
		for _ = 1, a.max_flames * 3 do
			if placed >= a.max_flames then break end
			local p = {
				x = math.floor(pos.x + math.random(-a.blast_radius, a.blast_radius)),
				y = math.floor(pos.y + math.random(-1, 2)),
				z = math.floor(pos.z + math.random(-a.blast_radius, a.blast_radius)),
			}
			local n = core.get_node_or_nil(p)
			if n and n.name == "air" and not core.is_protected(p, "alen_gregory") then
				core.set_node(p, { name = "fire:basic_flame" })
				placed = placed + 1
			end
		end
	end

	core.add_particlespawner({
		amount = 140, time = 0.5,
		minpos = vector.subtract(pos, 3), maxpos = vector.add(pos, 3),
		minvel = { x = -4, y = 1, z = -4 }, maxvel = { x = 4, y = 7, z = 4 },
		minexptime = 0.7, maxexptime = 2.2, minsize = 3, maxsize = 8,
		texture = CUBE_TEX, glow = 14,
	})
end

-- --------------------------------------------------------------------------
-- Lanzamiento con telegrafía. La carga NO es decorativa: durante ella Alen se
-- queda quieto y visible, que es la ventana que tiene el jugador para apartarse.
-- --------------------------------------------------------------------------

--- ALEN SIEMPRE ADVIERTE ANTES DE ACTUAR.
---
--- Es una regla de carácter, no una cortesía del sistema: tiene complejo de dios y
--- un dios anuncia sus castigos. Además convierte el ataque mayor en una escena en
--- vez de en un golpe barato — el jugador oye la sentencia y tiene 1.4 s para
--- entender que va en serio.
function hashimon_alen.declare(self, category, ctx)
	hashimon_alen.say(category, { force = true }, ctx or {})
end

function hashimon_alen.begin_firecube(self, target)
	local why = hashimon_alen.attack_blocked(self, "firecube")
	if why then return false, why end
	if self._charging then return false, "already_charging" end
	if not target or not target:get_pos() then return false, "no_target" end

	local mypos = self.object:get_pos()
	local a0 = hashimon_alen.ATTACKS.firecube
	if mypos and hashimon_alen.dist(mypos, target:get_pos()) < a0.min_range then
		return false, "too_close" -- a bocajarro se usa el aliento, no el cubo
	end

	local a = hashimon_alen.ATTACKS.firecube
	mark_used(self, "firecube")

	-- La advertencia. Si ya estalló la furia lo dice ON_RAGE desde on_punch; si no,
	-- lo anuncia aquí. Un cubo sin sentencia previa sería un ataque a traición, y
	-- Alen no ataca a traición.
	local who = target.get_player_name and target:get_player_name() or nil
	if not (self._fight and self._fight.raged) then
		hashimon_alen.declare(self, "ON_WARN_ATTACK", { name = who })
	end
	self._charging = core.get_gametime() + a.charge
	self._charge_target = target

	hashimon_alen.play_oneshot(self, a.anim)
	local pos = self.object:get_pos()
	core.sound_play("fire_large", { pos = pos, gain = 1.0, max_hear_distance = 80 }, true)
	core.add_particlespawner({
		amount = 80, time = a.charge,
		minpos = vector.subtract(pos, 2), maxpos = vector.add(pos, 2),
		minvel = { x = -1, y = 0, z = -1 }, maxvel = { x = 1, y = 2, z = 1 },
		minexptime = 0.4, maxexptime = 1.0, minsize = 2, maxsize = 6,
		texture = CUBE_TEX, glow = 14,
	})
	return true
end

--- Se llama cada tick. Suelta el cubo cuando la carga vence.
function hashimon_alen.step_attacks(self, _dtime)
	if not self._charging then return end
	if core.get_gametime() < self._charging then
		hashimon_alen.hover_brake(self) -- clavado mientras carga: es el aviso
		return
	end

	local a = hashimon_alen.ATTACKS.firecube
	local target = self._charge_target
	self._charging, self._charge_target = nil, nil

	local floor_e = rage_allows(self) and a.energy_cost or a.min_energy
	if (hashimon_alen.get_state().energy or 0) < floor_e then return end
	hashimon_alen.spend_energy(a.energy_cost)

	local pos = self.object:get_pos()
	local tpos = target and target:get_pos()
	if not pos or not tpos then return end

	local dir = vector.normalize(vector.subtract(
		{ x = tpos.x, y = tpos.y + 1, z = tpos.z },
		{ x = pos.x, y = pos.y + 2, z = pos.z }))
	local obj = core.add_entity({
		x = pos.x + dir.x * 3.5,
		y = pos.y + 2 + dir.y * 3.5,
		z = pos.z + dir.z * 3.5,
	}, "hashimon_alen:firecube")
	if obj then
		-- Compensa el arco: apunta algo por encima para que llegue.
		obj:set_velocity(vector.multiply({ x = dir.x, y = dir.y + 0.22, z = dir.z }, a.speed))
	end
end

-- --------------------------------------------------------------------------
-- El combate como unidad. Sin esto, cada golpe es un suceso aislado y Alen
-- responde igual al primero que al décimo — que es exactamente lo que se vio en
-- la primera partida.
-- --------------------------------------------------------------------------

hashimon_alen.FIGHT_TIMEOUT = 20 -- sin golpes en este tiempo, el combate se cierra

--- Registra un golpe y devuelve el combate en curso. Un combate nuevo empieza si
--- cambia el agresor o si pasó demasiado tiempo desde el último golpe: así "van
--- tres" significa tres en ESTA pelea, no tres desde que existe el mundo.
function hashimon_alen.register_hit(self, who, damage)
	local now = core.get_gametime()
	local f = self._fight
	if not f or f.who ~= who or (now - (f.last_at or 0)) > hashimon_alen.FIGHT_TIMEOUT then
		f = { who = who, hits = 0, damage = 0, started_at = now, raged = false }
		self._fight = f
	end
	f.hits = f.hits + 1
	f.damage = f.damage + (damage or 0)
	f.last_at = now
	return f
end

--- ¿Se cruzó el umbral de furia? Devuelve true UNA sola vez por combate: la
--- escena del cubo pierde todo su peso si se repite cada golpe.
function hashimon_alen.should_rage(self)
	local f = self._fight
	if not f or f.raged or f.damage < hashimon_alen.RAGE_DAMAGE then
		return false
	end
	f.raged = true
	return true
end

--- Cierra el combate por abandono, para que el siguiente empiece de cero.
function hashimon_alen.expire_fight(self)
	local f = self._fight
	if f and (core.get_gametime() - (f.last_at or 0)) > hashimon_alen.FIGHT_TIMEOUT then
		self._fight = nil
		return f
	end
	return nil
end
