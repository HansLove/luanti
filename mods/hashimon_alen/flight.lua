-- Vuelo: ir hacia un punto sin incrustarse en el terreno.
--
-- Deliberadamente NO hay A*. Un volador no necesita buscar ruta por el aire vóxel:
-- necesita ver lo que tiene delante y subir. Un raycast hacia adelante más un
-- sensor de suelo cubren la inmensa mayoría de los casos por una fracción del
-- coste, y son las dos cosas que a la IA vieja le faltaban por completo.

hashimon_alen = hashimon_alen or {}

local LOOKAHEAD = 9        -- nodos que mira hacia adelante
local FLOOR_CLEARANCE = 5  -- altura mínima sobre el suelo en crucero
local CLIMB_GAIN = 1.4     -- fuerza del vector de ascenso al detectar obstáculo
local YAW_RATE = 2.6       -- radianes por segundo; sin esto el giro es un salto

local function vlen(v)
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

local function vnorm(v)
	local l = vlen(v)
	if l < 1e-6 then
		return { x = 0, y = 0, z = 0 }, 0
	end
	return { x = v.x / l, y = v.y / l, z = v.z / l }, l
end

function hashimon_alen.vsub(a, b)
	return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

function hashimon_alen.dist(a, b)
	return vlen(hashimon_alen.vsub(a, b))
end

--- ¿Hay terreno sólido en la línea pos → pos + dir*range?
--- Devuelve la distancia al impacto, o nil si está despejado.
local function terrain_ahead(pos, dir, range)
	local to = {
		x = pos.x + dir.x * range,
		y = pos.y + dir.y * range,
		z = pos.z + dir.z * range,
	}
	local ray = core.raycast(pos, to, false, false)
	for pointed in ray do
		if pointed.type == "node" then
			local node = core.get_node_or_nil(pointed.under)
			local def = node and core.registered_nodes[node.name]
			if def and def.walkable then
				return hashimon_alen.dist(pos, pointed.under)
			end
		end
	end
	return nil
end

hashimon_alen.terrain_ahead = terrain_ahead

--- Distancia al suelo bajo `pos`, hasta `max` nodos. nil si no hay suelo (o el
--- mapblock no está cargado, que a efectos de vuelo es lo mismo: no bajes).
function hashimon_alen.floor_below(pos, max)
	max = max or 40
	for i = 1, max do
		local p = { x = pos.x, y = pos.y - i, z = pos.z }
		local node = core.get_node_or_nil(p)
		if not node then
			return nil
		end
		local def = core.registered_nodes[node.name]
		if def and def.walkable then
			return i
		end
	end
	return nil
end

--- Gira el yaw hacia `target_yaw` a ritmo limitado, en vez de saltar. Es la
--- diferencia entre un dragón y un cartel que rota.
function hashimon_alen.turn_toward(self, target_yaw, dtime)
	local cur = self.object:get_yaw() or 0
	local diff = (target_yaw - cur + math.pi) % (2 * math.pi) - math.pi
	local step = YAW_RATE * dtime
	if math.abs(diff) <= step then
		self.object:set_yaw(target_yaw)
	else
		self.object:set_yaw(cur + (diff > 0 and step or -step))
	end
end

--- Vuela hacia `target` esquivando terreno. Devuelve la distancia restante.
--- `lift` es un desplazamiento vertical del objetivo: positivo para sobrevolar.
function hashimon_alen.fly_toward(self, target, speed, dtime, lift)
	local pos = self.object:get_pos()
	if not pos or not target then
		return math.huge
	end

	local goal = { x = target.x, y = target.y + (lift or 0), z = target.z }
	local dir, dist = vnorm(hashimon_alen.vsub(goal, pos))
	if dist < 0.001 then
		return dist
	end

	-- Evasión: si hay pared delante, mete componente de ascenso proporcional a lo
	-- cerca que esté. No es esquivar bonito, es no estrellarse — y basta.
	local hit = terrain_ahead(pos, dir, LOOKAHEAD)
	if hit then
		local urgency = 1 - (hit / LOOKAHEAD)
		dir.y = dir.y + CLIMB_GAIN * urgency
		dir = vnorm(dir)
	end

	-- Suelo: nunca vuela a ras salvo que esté aterrizando a propósito.
	if not self._landing then
		local floor = hashimon_alen.floor_below(pos, FLOOR_CLEARANCE)
		if floor and floor < FLOOR_CLEARANCE then
			dir.y = math.max(dir.y, (FLOOR_CLEARANCE - floor) / FLOOR_CLEARANCE)
			dir = vnorm(dir)
		end
	end

	self.object:set_velocity({
		x = dir.x * speed,
		y = dir.y * speed,
		z = dir.z * speed,
	})
	hashimon_alen.turn_toward(self, -math.atan2(dir.x, dir.z), dtime)
	return dist
end

--- Frena en el sitio conservando algo de deriva, para que quede flotando en vez
--- de congelarse en seco.
function hashimon_alen.hover_brake(self)
	local v = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
	self.object:set_velocity({ x = v.x * 0.86, y = v.y * 0.86 + 0.12, z = v.z * 0.86 })
end
