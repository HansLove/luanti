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
-- Giro. Estaba en 2.6 rad/s: poco más de 20 segundos para dar una vuelta
-- completa, así que un jugador orbitando a pie lo dejaba atrás y parecía que no
-- lo veía. No era que no lo viera — era que no podía encararlo.
local YAW_RATE = 5.2       -- radianes por segundo

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

--- Distancia al suelo bajo `pos`, hasta `max` nodos.
---
--- `tolerate_unloaded` cambia qué significa encontrarse un mapblock sin cargar:
---   false (por defecto) → devuelve nil. Es lo correcto para VOLAR: no se
---     desciende hacia espacio desconocido.
---   true → lo salta y sigue buscando. Es lo correcto para PLANIFICAR: volando
---     alto, el aire por encima del área cargada no lo está, y abortar ahí hacía
---     que toda ruta terrestre saliera inviable... lo que lo mantenía volando.
---     Un bucle que se alimentaba a sí mismo, y la última causa de "vuela mucho".
function hashimon_alen.floor_below(pos, max, tolerate_unloaded)
	max = max or 40
	for i = 1, max do
		local p = { x = pos.x, y = pos.y - i, z = pos.z }
		local node = core.get_node_or_nil(p)
		if not node then
			if not tolerate_unloaded then
				return nil
			end
			node = nil -- sin cargar: se salta y se sigue mirando hacia abajo
		end
		local def = node and core.registered_nodes[node.name]
		if def and def.walkable then
			return i
		end
	end
	return nil
end

--- ¿Está el nodo en `pos` dentro de un líquido?
function hashimon_alen.node_is_liquid(pos)
	local node = core.get_node_or_nil(pos)
	local def = node and core.registered_nodes[node.name]
	return def and def.liquidtype and def.liquidtype ~= "none" or false
end

--- ¿Está METIDO en terreno sólido? Se mira a la altura del pecho, no a los pies:
--- a los pies siempre hay suelo cuando camina.
function hashimon_alen.is_buried(pos)
	if not pos then return false end
	local node = core.get_node_or_nil({ x = pos.x, y = pos.y + 1.5, z = pos.z })
	local def = node and core.registered_nodes[node.name]
	return (def and def.walkable) or false
end

--- Primer punto de aire libre por encima. Es la salida de emergencia cuando queda
--- enterrado: preferimos un reposicionamiento feo a un dragón clavado para siempre.
function hashimon_alen.first_air_above(pos, max)
	for i = 1, (max or 30) do
		local p = { x = pos.x, y = pos.y + i, z = pos.z }
		local n = core.get_node_or_nil(p)
		if n then
			local d = core.registered_nodes[n.name]
			local n2 = core.get_node_or_nil({ x = p.x, y = p.y + 3, z = p.z })
			local d2 = n2 and core.registered_nodes[n2.name]
			if (not d or not d.walkable) and (not d2 or not d2.walkable) then
				return p
			end
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

--- ¿Tiene línea de visión hasta ese punto? Es la diferencia entre "no te veo" y
--- "te veo y hay una pared en medio", y de ahí sale el asedio: un dragón que
--- SABE dónde estás y se queda flotando delante de tu puerta es el momento en
--- que deja de dar miedo.
function hashimon_alen.has_los(from, to)
	if not from or not to then return false end
	local a = { x = from.x, y = from.y + 1.5, z = from.z }
	local b = { x = to.x, y = to.y + 1.0, z = to.z }
	local ray = core.raycast(a, b, false, false)
	for pointed in ray do
		if pointed.type == "node" then
			local node = core.get_node_or_nil(pointed.under)
			local def = node and core.registered_nodes[node.name]
			if def and def.walkable then
				return false, pointed.under
			end
		end
	end
	return true
end

--- ¿Tiene techo encima? Es lo que distingue "se metió en una casa" de "hay una
--- colina en medio", y sin esa distinción el asedio bombardearía el paisaje.
function hashimon_alen.roof_over(pos, max)
	for i = 1, (max or 7) do
		local n = core.get_node_or_nil({ x = pos.x, y = pos.y + i, z = pos.z })
		local d = n and core.registered_nodes[n.name]
		if d and d.walkable then return true, i end
	end
	return false
end

--- Frena en el sitio conservando algo de deriva, para que quede flotando en vez
--- de congelarse en seco.
function hashimon_alen.hover_brake(self)
	-- Frenar es lo contrario de querer avanzar. Decirlo aquí evita que quedarse
	-- quieto a propósito (cargando el cubo, escuchando) se lea como un atasco.
	self._want_move = false
	local v = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
	self.object:set_velocity({ x = v.x * 0.86, y = v.y * 0.86 + 0.12, z = v.z * 0.86 })
end
