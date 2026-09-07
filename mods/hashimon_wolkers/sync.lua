-- El puente con el censo. Tres corrientes, cada una con su reloj:
--   padrón   (30 s por town cargado) → a quién hay que dar cuerpo
--   deltas   (10 s, en lote)         → dónde quedó cada cuerpo y quién cayó
--   consejo  (por evento, con TTL)   → qué postura tiene el pueblo
--
-- Ninguna de las tres es autoridad sobre la población: el mod pide y reporta, el servidor
-- decide. Si el API se cae, los wolkers que ya tienen cuerpo siguen viviendo con la última
-- postura conocida — degradan a aldeanos tontos, no a estatuas ni a un crash.

hashimon_wolkers = hashimon_wolkers or {}

local ROSTER_INTERVAL = 30.0
local DELTA_INTERVAL = 10.0
local MAX_BODIES_PER_TOWN = 24   -- techo de entidades, NO de población (el censo no lo ve)
local SPAWN_RADIUS = 12
local PLAYER_RANGE = 96          -- sólo se encarna un town con alguien cerca

local roster = {}        -- id -> entrada del padrón
local bodies = {}        -- id -> luaentity
local towns_seen = {}    -- town -> última postura { posture, reason, until_us }
local hostiles = {}      -- town -> { nombre -> true } desde la última consulta
local pending = {}       -- deltas en cola
local spawn_queue = {}

local function secret()
	return hashimon.get_server_secret()
end

function hashimon_wolkers.roster_entry(id)
	return roster[id]
end

function hashimon_wolkers.claim_body(id, self)
	bodies[id] = self
end

function hashimon_wolkers.dequeue_spawn()
	return table.remove(spawn_queue, 1)
end

--- Postura vigente de un town. Sin consejo todavía, "normal": un pueblo sin noticias no es
--- un pueblo en crisis.
function hashimon_wolkers.posture_for(town)
	local t = town and towns_seen[town]
	if not t then
		return "normal"
	end
	if t.until_us and core.get_us_time() > t.until_us then
		-- El TTL venció: se mantiene la postura pero se marca para volver a preguntar.
		t.stale = true
	end
	return t.posture or "normal"
end

function hashimon_wolkers.note_town_hostile(town, name)
	if not town then
		return
	end
	hostiles[town] = hostiles[town] or {}
	hostiles[town][name] = true
end

--- Una muerte vista en el mundo. Se encola como delta; el servidor la firma. Hasta que la
--- firme, el wolker sigue en el padrón — y si el push se pierde, el siguiente padrón lo
--- vuelve a encarnar. Preferimos un muerto que resucita a un vivo borrado por un timeout.
function hashimon_wolkers.report_death(self, killer)
	local w = self.wolker
	if not w then
		return
	end
	bodies[w.id] = nil
	local cause = "combat"
	if killer and killer.get_player_name == nil then
		cause = "raid"   -- lo mató algo que no es un jugador (criatura, explosión)
	end
	table.insert(pending, { id = w.id, died = cause })
end

local function alive_players_near(pos)
	for _, player in ipairs(core.get_connected_players()) do
		local pp = player:get_pos()
		if pp and vector.distance(pp, pos) < PLAYER_RANGE then
			return true
		end
	end
	return false
end

--- Da cuerpo a quien falte, hasta el techo. El techo es de RENDIMIENTO: un town de 180
--- wolkers con 24 cuerpos sigue teniendo 180 en el censo, y eso es exactamente lo que
--- permite que la población crezca sin que el servidor se arrodille.
local function embody(town, entries)
	local count = 0
	for _, w in ipairs(entries) do
		if bodies[w.id] then
			count = count + 1
		end
	end
	for _, w in ipairs(entries) do
		if count >= MAX_BODIES_PER_TOWN then
			return
		end
		if not bodies[w.id] and w.home then
			if alive_players_near(w.home) then
				local pos = {
					x = w.home.x + math.random(-SPAWN_RADIUS, SPAWN_RADIUS),
					y = w.home.y + 1,
					z = w.home.z + math.random(-SPAWN_RADIUS, SPAWN_RADIUS),
				}
				w.town = town
				table.insert(spawn_queue, w)
				local obj = core.add_entity(pos, hashimon_wolkers.entity_for(w.model))
				if not obj then
					table.remove(spawn_queue, #spawn_queue)
				else
					count = count + 1
				end
			end
		end
	end
end

local function towns_with_players()
	local out = {}
	if not (towny and towny.residents) then
		return out
	end
	for _, player in ipairs(core.get_connected_players()) do
		local res = towny.residents[player:get_player_name()]
		if res and res.town then
			out[res.town.name] = true
		end
	end
	return out
end

local function pull_roster(town)
	hashimon.fetch_wolkers(secret(), town, function(ok, err, list)
		if not ok then
			core.log("warning", "[hashimon_wolkers] padrón de " .. town .. ": " .. tostring(err))
			return
		end
		local entries = {}
		for _, w in ipairs(list) do
			w.town = town
			roster[w.id] = w
			table.insert(entries, w)
		end
		embody(town, entries)
	end)
end

--- Sube las posiciones de los cuerpos vivos junto con las muertes pendientes. Va en lote:
--- una petición por ciclo y por mundo, no una por wolker.
local function push_deltas()
	local batch = {}
	for _, d in ipairs(pending) do
		table.insert(batch, d)
	end
	pending = {}
	for id, self in pairs(bodies) do
		local obj = self.object
		if obj and obj:get_pos() then
			local p = obj:get_pos()
			table.insert(batch, { id = id, pos = { x = p.x, y = p.y, z = p.z } })
		else
			bodies[id] = nil
		end
	end
	if #batch == 0 then
		return
	end
	hashimon.push_wolker_deltas(secret(), { deltas = batch }, function(ok, err)
		if not ok then
			core.log("warning", "[hashimon_wolkers] deltas: " .. tostring(err))
		end
	end)
end

--- Pide consejo. Sólo cuando hay algo que contar (hostiles) o el TTL de la postura venció;
--- el servidor tiene sus propias válvulas encima, así que esto es la primera de dos.
local function ask_council(town)
	local h = hostiles[town] or {}
	local n = 0
	for _ in pairs(h) do
		n = n + 1
	end
	local cur = towns_seen[town]
	if n == 0 and cur and not cur.stale then
		return
	end
	hostiles[town] = {}
	hashimon.ask_wolker_council(secret(), { town = town, hostiles = n }, function(ok, err, body)
		if not ok then
			-- Sin respuesta se conserva la postura anterior: el pueblo no se queda mudo.
			core.log("warning", "[hashimon_wolkers] consejo de " .. town .. ": " .. tostring(err))
			return
		end
		towns_seen[town] = {
			posture = body.posture,
			reason = body.reason,
			source = body.source,
			stale = false,
			until_us = core.get_us_time() + (tonumber(body.ttlS) or 600) * 1000000,
		}
		core.log("action", string.format("[hashimon_wolkers] %s → %s (%s) %s",
			town, tostring(body.posture), tostring(body.source), tostring(body.reason)))
	end)
end

function hashimon_wolkers.posture_info(town)
	return towns_seen[town]
end

local roster_acc, delta_acc = 0, 0
core.register_globalstep(function(dtime)
	roster_acc = roster_acc + dtime
	delta_acc = delta_acc + dtime

	if roster_acc >= ROSTER_INTERVAL then
		roster_acc = 0
		for town in pairs(towns_with_players()) do
			pull_roster(town)
			ask_council(town)
		end
	end

	if delta_acc >= DELTA_INTERVAL then
		delta_acc = 0
		push_deltas()
	end
end)
