-- El Hogar — el nodo con el que un jugador asienta población en su nación.
--
-- Es la única pieza de la Fase 2 que el jugador toca con las manos, y hace tres cosas:
--   1. marca DÓNDE nace y vive la gente (el censo guarda su coordenada como hogar);
--   2. pide la camada genesis del town la primera vez (idempotente en el servidor);
--   3. ancla el barrido de camas que fija el techo de población.
--
-- Sin Hogar no nace nadie. No porque esté prohibido: porque no hay dónde. Y romperlo no
-- mata a nadie — la gente que ya vive sigue viva, simplemente deja de crecer. Un pueblo se
-- despuebla por hambre o por guerra, nunca por picar un bloque.

hashimon_wolkers = hashimon_wolkers or {}

local BED_SCAN_RADIUS = 48       -- radio alrededor del Hogar donde cuentan las camas
local CAPACITY_INTERVAL = 60.0   -- cada cuánto se recuenta y se empuja el techo

-- El censo del mundo llega a la API cada 15 s; un pueblo recién fundado puede no estar
-- todavía cuando se enciende su Hogar. Cuatro intentos cubren de sobra esa ventana.
local GENESIS_RETRIES = 4
local GENESIS_RETRY_DELAY = 8.0

local hearths = {}   -- town -> pos

local function town_at(pos)
	if not (towny and towny.get_block_by_pos) then
		return nil
	end
	local block = towny.get_block_by_pos(pos)
	return block and block.town or nil
end

--- Camas construidas dentro del claim. Se reconocen las camas del juego base (`group:bed`)
--- en vez de inventar una cama propia: premia construir de verdad, y cualquier mod de
--- muebles que declare el grupo cuenta desde el primer día sin que toquemos nada.
---
--- Se cuentan los PIES de cama (`bed_bottom`) para no contar dos veces la misma cama: en
--- Minetest Game una cama son dos nodos, y contar los dos duplicaría el techo.
local function count_beds(center)
	local min = vector.subtract(center, BED_SCAN_RADIUS)
	local max = vector.add(center, BED_SCAN_RADIUS)
	local found = core.find_nodes_in_area(min, max, { "group:bed" })
	local beds = 0
	for _, p in ipairs(found) do
		local name = core.get_node(p).name
		if name:find("bottom") or not name:find("top") then
			beds = beds + 1
		end
	end
	return beds
end

local function push_capacity(town, pos)
	local beds = count_beds(pos)
	hashimon.push_wolker_capacity(hashimon.get_server_secret(), {
		town = town,
		beds = beds,
		hearth = { x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z) },
	}, function(ok, err, capacity)
		if not ok then
			core.log("warning", "[hashimon_wolkers] techo de " .. town .. ": " .. tostring(err))
			return
		end
		hashimon_wolkers.capacity_cache = hashimon_wolkers.capacity_cache or {}
		hashimon_wolkers.capacity_cache[town] = capacity
	end)
end

function hashimon_wolkers.capacity_info(town)
	return hashimon_wolkers.capacity_cache and hashimon_wolkers.capacity_cache[town] or nil
end

core.register_node("hashimon_wolkers:hearth", {
	description = "Hogar de wolkers — asienta población en tu nación",
	drawtype = "nodebox",
	tiles = { "default_stone.png^[colorize:#8a4b1e:60" },
	paramtype = "light",
	light_source = 9,
	node_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, -0.25, 0.5 },
			{ -0.35, -0.25, -0.35, 0.35, 0.1, 0.35 },
		},
	},
	groups = { cracky = 2, oddly_breakable_by_hand = 1 },
	is_ground_content = false,

	-- Sólo dentro de tu propio claim: un Hogar en tierra ajena sería una forma de meter
	-- población en la nación de otro.
	on_place = function(itemstack, placer, pointed)
		local pos = pointed.above
		local town = town_at(pos)
		if not town then
			core.chat_send_player(placer:get_player_name(),
				"El Hogar sólo se enciende dentro de un claim de tu town.")
			return itemstack
		end
		local name = placer:get_player_name()
		local res = towny.residents and towny.residents[name]
		if not res or not res.town or res.town.name ~= town.name then
			core.chat_send_player(name, "Ese claim no es de tu town.")
			return itemstack
		end
		return core.item_place_node(itemstack, placer, pointed)
	end,

	after_place_node = function(pos, placer)
		local town = town_at(pos)
		if not town then
			return
		end
		hearths[town.name] = pos
		local name = placer and placer:get_player_name() or ""

		-- Primera vez: se pide la camada. El servidor es idempotente por homeblock, así que
		-- mover el Hogar o volver a ponerlo NO reparte una segunda camada.
		--
		-- Y se REINTENTA, porque el caso más común es justo el que fallaba: un pueblo recién
		-- fundado todavía no ha llegado a la API —el mundo empuja su censo cada 15 s— y el
		-- alta de los wolkers rebota contra la clave foránea. La camada no se pierde (el
		-- servidor revierte la transacción entera), pero antes el jugador no se enteraba de
		-- nada: encendía el Hogar y no pasaba nada. Ahora se insiste y, si aun así no sale,
		-- se le dice qué hacer.
		local function ask(attempt)
			hashimon.request_wolker_genesis(hashimon.get_server_secret(), {
				town = town.name,
				home = { x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z) },
			}, function(ok, err, granted)
				if ok then
					if name ~= "" then
						if granted and #granted > 0 then
							core.chat_send_player(name, "Se asientan " .. #granted .. " wolkers en " .. town.name .. ".")
						else
							core.chat_send_player(name, "El Hogar arde. Tu gente ya estaba censada; ahora vivirá aquí.")
						end
					end
					return
				end
				if attempt < GENESIS_RETRIES then
					if attempt == 1 and name ~= "" then
						core.chat_send_player(name, "El Hogar arde. Esperando a que el censo reconozca a " .. town.name .. "...")
					end
					core.after(GENESIS_RETRY_DELAY, function() ask(attempt + 1) end)
					return
				end
				if name ~= "" then
					core.chat_send_player(name,
						"El Hogar arde, pero el censo aún no conoce a " .. town.name ..
						" (" .. tostring(err) .. "). Rompe y vuelve a poner el Hogar en un minuto.")
				end
			end)
		end
		ask(1)
		push_capacity(town.name, pos)
	end,

	on_destruct = function(pos)
		local town = town_at(pos)
		if town then
			hearths[town.name] = nil
			-- Techo a cero por falta de Hogar: nadie muere, pero nadie nace.
			hashimon.push_wolker_capacity(hashimon.get_server_secret(),
				{ town = town.name, beds = 0, hearth = nil }, nil)
		end
	end,
})

core.register_craft({
	output = "hashimon_wolkers:hearth",
	recipe = {
		{ "group:stone", "default:torch", "group:stone" },
		{ "group:stone", "group:wood",    "group:stone" },
		{ "group:stone", "group:stone",   "group:stone" },
	},
})

-- Recuento periódico: las camas se construyen y se rompen, y el techo tiene que seguirlas.
local acc = 0
core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < CAPACITY_INTERVAL then
		return
	end
	acc = 0
	for town, pos in pairs(hearths) do
		push_capacity(town, pos)
	end
end)

--- Al cargarse el bloque de un Hogar, el mundo lo vuelve a registrar: el mod no guarda una
--- lista propia de Hogares en disco, la reconstruye de lo que hay puesto. El nodo ES el
--- registro, y así no puede desincronizarse de lo que se ve.
core.register_lbm({
	label = "Registrar Hogares de wolkers",
	name = "hashimon_wolkers:register_hearth",
	nodenames = { "hashimon_wolkers:hearth" },
	run_at_every_load = true,
	action = function(pos)
		local town = town_at(pos)
		if town then
			hearths[town.name] = pos
			push_capacity(town.name, pos)
		end
	end,
})
