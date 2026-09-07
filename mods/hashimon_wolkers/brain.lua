-- La cabeza táctica: una FSM en Lua que corre gratis, sin red y sin modelo.
--
-- Nueve estados y ni uno más. La postura del pueblo (normal/rationing/shelter/exodus) llega
-- del servidor y NO da órdenes: sesga esta máquina — con `shelter` nadie sale a trabajar,
-- con `rationing` todo el mundo busca comida. Si el consejo nunca contesta, el wolker sigue
-- siendo un aldeano competente; sólo deja de reaccionar a lo que una regla no sabe leer.

hashimon_wolkers = hashimon_wolkers or {}

hashimon_wolkers.TACTIC_INTERVAL = 1.0
hashimon_wolkers.SIGHT = 16          -- lo que un aldeano ve; no es un vigía
hashimon_wolkers.FLEE_DIST = 10      -- se aparta de un hostil hasta esta distancia
hashimon_wolkers.HOME_LEASH = 24     -- fuera de esto vuelve a casa: no hay expediciones

local SPEED = { wander = 1.4, work = 1.4, flee = 3.6, home = 2.2 }

local function dist(a, b)
	return vector.distance(a, b)
end

--- Jugador hostil más cercano: alguien que no es residente del town y está dentro del claim.
--- La residencia la sabe Towny; sin Towny, nadie es hostil y los wolkers sólo huyen si les
--- pegan. Degradar así es deliberado: un mod que falta no debe volver paranoico al pueblo.
local function nearest_hostile(self, pos)
	local town = self.wolker and self.wolker.town
	local best, best_d = nil, hashimon_wolkers.SIGHT
	for _, player in ipairs(core.get_connected_players()) do
		local pp = player:get_pos()
		if pp and player:get_hp() > 0 and dist(pos, pp) < best_d then
			local name = player:get_player_name()
			local resident = true
			if town and towny and towny.residents then
				local res = towny.residents[name]
				resident = (res and res.town and res.town.name == town) and true or false
			end
			if not resident or self._grudge == name then
				best, best_d = player, dist(pos, pp)
			end
		end
	end
	return best, best_d
end

local function walk_toward(self, target, speed)
	local pos = self.object:get_pos()
	if not pos or not target then
		return
	end
	local dir = vector.direction(pos, target)
	local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
	self.object:set_velocity({ x = dir.x * speed, y = vel.y, z = dir.z * speed })
	hashimon_wolkers.set_anim(self, "walk")
end

local function halt(self, anim)
	local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
	self.object:set_velocity({ x = 0, y = vel.y, z = 0 })
	hashimon_wolkers.set_anim(self, anim or "stand")
end

local function wander_target(pos)
	return {
		x = pos.x + math.random(-6, 6),
		y = pos.y,
		z = pos.z + math.random(-6, 6),
	}
end

--- El estado se decide en este orden y el primero que aplica gana. Leerlo de arriba abajo
--- es leer las prioridades de un aldeano: la vida, luego el pueblo, luego el trabajo.
local function decide(self, pos)
	local hostile, hd = nearest_hostile(self, pos)
	if hostile and hd < hashimon_wolkers.FLEE_DIST then
		return "flee", hostile:get_pos()
	end

	local posture = hashimon_wolkers.posture_for(self.wolker and self.wolker.town)
	local home = self.wolker and self.wolker.home

	if posture == "shelter" then
		-- A cubierto: a casa, y quien ya está en casa no se mueve.
		if home and dist(pos, home) > 3 then
			return "home", home
		end
		return "idle"
	end

	if posture == "exodus" then
		-- La marcha en sí es Fase 3 (emigración); hasta entonces, el pueblo se agrupa en el
		-- homeblock en vez de fingir un viaje que el censo todavía no sabe registrar.
		if home and dist(pos, home) > 2 then
			return "home", home
		end
		return "idle"
	end

	if home and dist(pos, home) > hashimon_wolkers.HOME_LEASH then
		return "home", home
	end

	-- Con hambre alta o raciones cortas, buscar comida desplaza al trabajo.
	local hunger = (self.wolker and self.wolker.hunger) or 0
	if posture == "rationing" or hunger >= 50 then
		return "forage", wander_target(pos)
	end

	return "work", wander_target(pos)
end

function hashimon_wolkers.think(self, _moveresult)
	local pos = self.object:get_pos()
	if not pos then
		return
	end
	local state, target = decide(self, pos)
	self._state = state

	if state == "flee" then
		-- Huir es alejarse del hostil, no correr hacia un punto: se refleja el vector.
		local away = vector.add(pos, vector.multiply(vector.direction(target, pos), 8))
		walk_toward(self, away, SPEED.flee)
		hashimon_wolkers.set_anim(self, "panic")
		return
	end
	if state == "home" then
		walk_toward(self, target, SPEED.home)
		return
	end
	if state == "idle" then
		halt(self, "stand")
		return
	end
	if state == "work" then
		-- El oficio decide la animación, no el destino: el destino real (nodos de trabajo)
		-- llega en la Fase 2, cuando exista la despensa física del town.
		if math.random() < 0.4 then
			halt(self, "work")
		else
			walk_toward(self, target, SPEED.work)
		end
		return
	end
	if state == "forage" then
		walk_toward(self, target, SPEED.wander)
		return
	end
	halt(self, "stand")
end

--- Alguien le pegó. Dos consecuencias: le guarda rencor a ese nombre (deja de tratarlo como
--- vecino aunque sea residente) y el town anota un hostil, que es lo que puede acabar
--- despertando al consejo.
function hashimon_wolkers.note_hostile(self, puncher)
	if not puncher or not puncher.get_player_name then
		return
	end
	local name = puncher:get_player_name()
	if name == "" then
		return
	end
	self._grudge = name
	hashimon_wolkers.note_town_hostile(self.wolker and self.wolker.town, name)
end
