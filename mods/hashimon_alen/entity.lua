-- La entidad: la proyección de la ficha en el mapa.
--
-- static_save = false es DELIBERADO y no el descuido que era en el mod viejo:
-- aquí la persistencia vive en la ficha, así que dejar que Luanti serialice la
-- entidad sólo abriría la puerta a duplicados al reactivar mapblocks.

hashimon_alen = hashimon_alen or {}

hashimon_alen.ENTITY = "hashimon_alen:alen_gregory"
hashimon_alen._live = nil -- la única entidad viva; el candado en memoria

local BREATH_COOLDOWN = 2.6
local BREATH_SPEED = 22
local BREATH_DAMAGE = 9
local BREATH_TTL = 3.5

-- ---------------------------------------------------------------------------
-- Aliento
-- ---------------------------------------------------------------------------

core.register_entity("hashimon_alen:breath", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "sprite",
		visual_size = { x = 2.2, y = 2.2 },
		textures = { "default_item_smoke.png^[colorize:#F97316:220" },
		glow = 14,
		static_save = false,
	},
	_age = 0,
	on_step = function(self, dtime)
		self._age = self._age + dtime
		local pos = self.object:get_pos()
		if self._age > BREATH_TTL or not pos then
			self.object:remove()
			return
		end
		local node = core.get_node_or_nil(pos)
		local def = node and core.registered_nodes[node.name]
		if def and def.walkable then
			core.add_particlespawner({
				amount = 25, time = 0.2,
				minpos = vector.subtract(pos, 1), maxpos = vector.add(pos, 1),
				minvel = { x = -2, y = 0, z = -2 }, maxvel = { x = 2, y = 3, z = 2 },
				minexptime = 0.3, maxexptime = 0.9, minsize = 1, maxsize = 3,
				texture = "default_item_smoke.png^[colorize:#F97316:200", glow = 12,
			})
			self.object:remove()
			return
		end
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 2.0)) do
			if obj:is_player() then
				obj:set_hp((obj:get_hp() or 20) - BREATH_DAMAGE)
				self.object:remove()
				return
			end
		end
	end,
})

function hashimon_alen.try_breath(self, target)
	if not target or not target:get_pos() then
		return false
	end
	local now = core.get_gametime()
	if self._breath_cd and now - self._breath_cd < BREATH_COOLDOWN then
		return false
	end
	self._breath_cd = now

	local pos = self.object:get_pos()
	local tpos = target:get_pos()
	local dir = vector.normalize(vector.subtract(
		{ x = tpos.x, y = tpos.y + 1, z = tpos.z },
		{ x = pos.x, y = pos.y + 1.5, z = pos.z }
	))
	local spawn = {
		x = pos.x + dir.x * 3.0,
		y = pos.y + 1.5 + dir.y * 3.0,
		z = pos.z + dir.z * 3.0,
	}
	local obj = core.add_entity(spawn, "hashimon_alen:breath")
	if obj then
		obj:set_velocity(vector.multiply(dir, BREATH_SPEED))
	end
	hashimon_alen.play_oneshot(self, "breath")
	core.sound_play("fire_fire", { pos = pos, gain = 0.8, max_hear_distance = 40 }, true)
	return true
end

-- ---------------------------------------------------------------------------
-- Alen
-- ---------------------------------------------------------------------------

core.register_entity(hashimon_alen.ENTITY, {
	initial_properties = {
		physical = true,
		collide_with_objects = true,
		pointable = true,
		visual = "mesh",
		mesh = hashimon_alen.MESH,
		textures = hashimon_alen.TEXTURES,
		visual_size = {
			x = hashimon_alen.VISUAL_SIZE,
			y = hashimon_alen.VISUAL_SIZE,
			z = hashimon_alen.VISUAL_SIZE,
		},
		collisionbox = { -1.0, 0, -1.0, 1.0, 2.8, 1.0 },
		selectionbox = { -1.6, 0, -1.6, 1.6, 3.4, 1.6 },
		backface_culling = false,
		static_save = false,
		makes_footstep_sound = false,
	},

	hp = hashimon_alen.MAX_HP,
	mode = "patrol",
	mood = "acecho",

	on_activate = function(self, _staticdata, _dtime)
		-- Candado del singleton, segunda línea: si el motor ya nos dio una entidad
		-- viva, esta sobra y se va antes de dibujar un solo frame.
		if hashimon_alen._live and hashimon_alen._live:get_luaentity() then
			self.object:remove()
			return
		end
		hashimon_alen._live = self.object

		local s = hashimon_alen.get_state()
		self.hp = s.hp or hashimon_alen.MAX_HP
		self.mood = s.mood or "acecho"
		self.plan = s.plan
		self.object:set_armor_groups({ fleshy = 70 })
		self.object:set_acceleration({ x = 0, y = 0, z = 0 }) -- vuela: sin gravedad
		self.object:set_yaw(s.yaw or 0)
		self.object:set_nametag_attributes({
			text = "Alen Gregory",
			color = "#F97316",
		})
		hashimon_alen.set_anim(self, "hover", 0)
		hashimon_alen.play_oneshot(self, "takeoff")
		core.log("action", "[alen] entidad instanciada")
	end,

	on_step = function(self, dtime)
		-- Reflejo: nada de red aquí dentro, nunca.
		hashimon_alen.step_anim(self)

		-- Muerte: se le deja terminar su clip antes de retirarlo. Un jefe que
		-- desaparece en el fotograma del golpe final no se lee como derrotado.
		if self._dying then
			self._dying = self._dying - dtime
			hashimon_alen.hover_brake(self)
			if self._dying <= 0 then
				hashimon_alen.death("derrotado")
				hashimon_alen._live = nil
				self.object:remove()
			end
			return
		end
		if self.hp <= 0 then
			self._dying = math.max(hashimon_alen.state_duration("death"), 0.6)
			hashimon_alen.play_oneshot(self, "death")
			if self._killer then
				hashimon_alen.remember(self._killer, "alen_lost")
			end
			if hashimon_alen.note_event then
				hashimon_alen.note_event("derrotado", self._killer, {})
			end
			return
		end

		hashimon_alen.think(self, dtime)

		self._save_acc = (self._save_acc or 0) + dtime
		if self._save_acc > 5 then
			self._save_acc = 0
			hashimon_alen.sync_from_entity(self)
			hashimon_alen.save_state()
		end
	end,

	on_punch = function(self, puncher, _tfl, tool_caps, _dir, damage)
		local dmg = damage or (tool_caps and tool_caps.damage_groups
			and tool_caps.damage_groups.fleshy) or 1
		self.hp = self.hp - dmg
		hashimon_alen.play_oneshot(self, "hurt")
		-- Cruzar la mitad de la vida es novedad; recibir el golpe número 40 no.
		-- El umbral es lo que separa un disparo útil de una factura.
		if not self._half_reported and self.hp <= hashimon_alen.MAX_HP * 0.5 then
			self._half_reported = true
			if hashimon_alen.note_event then
				hashimon_alen.note_event("herido", puncher and puncher:is_player()
					and puncher:get_player_name() or nil, { hp = math.floor(self.hp) })
			end
		end
		if puncher and puncher:is_player() then
			self._target = puncher
			self._killer = puncher:get_player_name()
			self._tactic_acc = 99 -- fuerza una decisión táctica inmediata
			hashimon_alen.remember(puncher:get_player_name(), "golpeo")
		end
		return true
	end,

	on_deactivate = function(self)
		core.log("action", "[alen] entidad desactivada (mapblock inactivo o retirada)")
		if hashimon_alen._live == self.object then
			hashimon_alen._live = nil
		end
		hashimon_alen.sync_from_entity(self)
		hashimon_alen.save_state()
	end,
})

-- ---------------------------------------------------------------------------
-- Gestor de observación: instancia la entidad sólo mientras alguien puede verla.
--
-- Esta es la pieza que abarata todo: sin observadores Alen es una coordenada en
-- la ficha, no consume CPU y — cuando llegue la capa del modelo — tampoco gasta
-- un solo token. Un servidor vacío cuesta cero.
-- ---------------------------------------------------------------------------

hashimon_alen.OBSERVE_IN = 150   -- se instancia si alguien entra en este radio
hashimon_alen.OBSERVE_OUT = 200  -- se retira cuando todos salen de este otro
                                 -- (histéresis: sin ella parpadearía en el borde)

local function nearest_player_dist(pos)
	local best = math.huge
	for _, player in ipairs(core.get_connected_players()) do
		local pp = player:get_pos()
		if pp then
			best = math.min(best, hashimon_alen.dist(pos, pp))
		end
	end
	return best
end

function hashimon_alen.spawn_entity()
	local s = hashimon_alen.get_state()
	if not s.alive or not s.pos then
		return nil, "no_vive"
	end
	if hashimon_alen._live and hashimon_alen._live:get_luaentity() then
		return hashimon_alen._live
	end
	if not core.get_node_or_nil(s.pos) then
		return nil, "mapblock_no_cargado"
	end
	local obj = core.add_entity(s.pos, hashimon_alen.ENTITY)
	if not obj then
		return nil, "add_entity_fallo"
	end
	return obj
end

function hashimon_alen.despawn_entity()
	local live = hashimon_alen._live
	if live and live:get_luaentity() then
		local ent = live:get_luaentity()
		hashimon_alen.sync_from_entity(ent)
		hashimon_alen.save_state()
		live:remove()
	end
	hashimon_alen._live = nil
end

local acc = 0
core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < 1.0 then
		return
	end
	acc = 0

	local s = hashimon_alen.get_state()
	if not s.alive or not s.pos then
		return
	end

	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	local d = nearest_player_dist(s.pos)

	if not live and d <= hashimon_alen.OBSERVE_IN then
		hashimon_alen.spawn_entity()
	elseif live and d > hashimon_alen.OBSERVE_OUT then
		hashimon_alen.despawn_entity()
	end
end)

core.register_on_shutdown(function()
	hashimon_alen.despawn_entity()
	hashimon_alen.save_state()
end)
