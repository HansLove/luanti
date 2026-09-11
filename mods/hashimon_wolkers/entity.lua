-- El cuerpo. Tres entidades, una por pieza de lego; todo lo que distingue a un wolker de
-- otro vive en `self.wolker` (los datos del padrón), no en un registro nuevo.
--
-- Reparto de trabajo, el mismo que aprendimos con Alen:
--   reflejo   (cada paso)  → moverse, caerse, mirar        [aquí]
--   táctica   (~1 s)       → qué hacer ahora               [brain.lua]
--   consejo   (raro)       → qué postura tiene el pueblo   [el servidor, sync.lua]

local S = core.get_translator("hashimon_wolkers")

local MODELS = { "wolker_pos", "wolker_neg", "wolker_small" }

-- Escala visual por pieza. La cría no es un adulto encogido en el eje Y: se declara aparte
-- para que el asset pueda tener sus propias proporciones sin tocar código.
--
-- altura_nodos = mesh_AABB × visual_size / 10. Los .glb salen a ~6-7 u (adulto) y ~3 u
-- (cría); con visual_size = 1 medirían medio metro. Números = hitbox.height × 10 / AABB.
--
-- OJO con la cría: su AABB de malla es 3.06, pero el nodo Armature del .glb lleva una
-- escala de 0.619 que los huesos heredan, así que en pantalla mide 1.90 u, no 3.06. El
-- cociente se calcula contra lo que se ve (1.90), no contra lo que dice el accessor; con
-- 3.27 Nani salía a 0.62 nodos, un 38 % por debajo de su propia caja de colisión.
local VISUAL = {
	wolker_pos   = { x = 2.80, y = 2.80 }, -- AABB 6.26 × escala 1.000 = 6.26 u → 1.75 nodos
	wolker_neg   = { x = 2.28, y = 2.28 }, -- AABB 7.45 × escala 1.000 = 7.45 u → 1.70 nodos
	wolker_small = { x = 5.27, y = 5.27 }, -- AABB 3.06 × escala 0.619 = 1.90 u → 1.00 nodos
}

local COLLISION = {
	wolker_pos   = { -0.3, 0.0, -0.3, 0.3, 1.75, 0.3 },
	wolker_neg   = { -0.3, 0.0, -0.3, 0.3, 1.70, 0.3 },
	wolker_small = { -0.2, 0.0, -0.2, 0.2, 1.00, 0.2 },
}

-- Fotogramas del contrato (models/README.md). Primera entrega: stand + walk en los
-- arranques del contrato (1–30 / 41–70). work/panic/sleep se declaran igual; sin pista
-- set_animation congela y el wolker sigue vivo.
hashimon_wolkers.ANIM = {
	stand = { x = 1,   y = 30  },
	walk  = { x = 41,  y = 70  },
	work  = { x = 81,  y = 120 },
	panic = { x = 121, y = 160 },
	sleep = { x = 161, y = 200 },
}

function hashimon_wolkers.set_anim(self, name)
	if self._anim == name then
		return
	end
	local frames = hashimon_wolkers.ANIM[name]
	if not frames then
		return
	end
	self._anim = name
	self.object:set_animation(frames, name == "walk" and 24 or 15, 0, true)
end

local MARK = { guardia = "\u{2694}", granjero = "\u{1F33e}", constructor = "\u{1F528}", porteador = "\u{1F4E6}" }

local function nametag(w)
	-- El nombre visible es el id corto: cualquiera puede cruzarlo con el padrón de la web.
	-- Y delante va el oficio, porque saber de un vistazo cuántos guardias tiene un pueblo
	-- es la mitad de decidir si atacarlo.
	local sign = (w.sign == 1) and "+" or "-"
	local role = w.role or (w.oficio and hashimon_wolkers.role_of(w.oficio)) or "granjero"
	return (MARK[role] or "") .. " " .. sign .. " " .. string.sub(w.id or "?", 1, 6)
end

local proto = {
	initial_properties = {
		hp_max = 20,
		physical = true,
		collide_with_objects = true,
		visual = "mesh",
		makes_footstep_sound = true,
		stepheight = 1.1,
		automatic_face_movement_dir = 90.0,
		automatic_face_movement_max_rotation_per_sec = 300,
	},

	-- El wolker no se guarda en staticdata: al descargarse el bloque, el cuerpo desaparece
	-- y el censo del servidor sigue intacto. Volver a entrar en el área lo vuelve a encarnar
	-- desde el padrón. Esto es lo que hace que la población no dependa del rendimiento.
	get_staticdata = function(self)
		return core.write_json({ id = self.wolker and self.wolker.id or nil })
	end,

	on_activate = function(self, staticdata, _dtime)
		self.object:set_acceleration({ x = 0, y = -9.81, z = 0 })
		self.object:set_armor_groups({ fleshy = 100 })
		self._anim = nil
		self._think = 0
		local data = staticdata ~= "" and core.parse_json(staticdata) or nil
		local id = data and data.id
		-- Un cuerpo sin padrón detrás no es nadie: se retira en vez de quedarse de adorno.
		local w = id and hashimon_wolkers.roster_entry(id) or hashimon_wolkers.dequeue_spawn()
		if not w then
			self.object:remove()
			return
		end
		hashimon_wolkers.bind(self, w)
	end,

	on_step = function(self, dtime, moveresult)
		self._think = self._think + dtime
		if self._think < hashimon_wolkers.TACTIC_INTERVAL then
			return
		end
		self._think = 0
		hashimon_wolkers.think(self, moveresult)
	end,

	on_punch = function(self, puncher)
		-- Pegar a un wolker no da nada; lo que hace es que el pueblo se entere.
		hashimon_wolkers.note_hostile(self, puncher)
		return false
	end,

	on_death = function(self, killer)
		-- La muerte se REPORTA, no se decide aquí: el servidor la firma en el censo, y
		-- hasta que la firme el wolker sigue contando. El mundo no da bajas por su cuenta.
		hashimon_wolkers.report_death(self, killer)
	end,
}

function hashimon_wolkers.bind(self, w)
	self.wolker = w
	hashimon_wolkers.claim_body(w.id, self)
	self.object:set_properties({
		visual_size = VISUAL[w.model] or VISUAL.wolker_pos,
		collisionbox = COLLISION[w.model] or COLLISION.wolker_pos,
	})
	self.object:set_nametag_attributes({ text = nametag(w), color = "#D7E3B8" })
	hashimon_wolkers.set_anim(self, "stand")
end

for _, model in ipairs(MODELS) do
	local def = table.copy(proto)
	def.initial_properties = table.copy(proto.initial_properties)
	def.initial_properties.mesh = model .. ".glb"
	def.initial_properties.textures = { model .. ".png" }
	def.initial_properties.visual_size = VISUAL[model]
	def.initial_properties.collisionbox = COLLISION[model]
	def.initial_properties.description = S("Wolker")
	core.register_entity(hashimon_wolkers.entity_for(model), def)
end
