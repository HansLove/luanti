-- Mando mínimo: ver el estado del pueblo y forzar la camada genesis de un town nuevo.

local function town_of(name)
	if not (towny and towny.residents) then
		return nil
	end
	local res = towny.residents[name]
	return res and res.town or nil
end

core.register_chatcommand("wolkers", {
	description = "Estado de la población de tu town",
	func = function(name)
		local town = town_of(name)
		if not town then
			return false, "No perteneces a ningún town."
		end
		local lines = { town.name .. ":" }

		-- Lo primero que necesita saber un alcalde no es cuánta gente tiene: es QUÉ le está
		-- frenando. El término más bajo de los tres es la obra que toca hacer mañana.
		local cap = hashimon_wolkers.capacity_info(town.name)
		if not cap then
			table.insert(lines, "  Sin Hogar encendido: nadie puede nacer aquí todavía.")
		else
			local obra = {
				beds = "construye camas",
				food = "mina más croquetas",
				blocks = "reclama más territorio",
			}
			table.insert(lines, string.format("  techo %d  (camas %d · comida %d · territorio %d)",
				cap.cap, cap.byBeds, cap.byFood, cap.byBlocks))
			table.insert(lines, string.format("  te frena: %s → %s",
				cap.bottleneck, obra[cap.bottleneck] or "?"))
		end

		-- Reparto de oficios: un pueblo sin guardias no se defiende solo, y eso no se
		-- arregla con un comando — se arregla con inmigración o con la siguiente camada.
		local roles = hashimon_wolkers.role_census(town.name)
		if roles then
			table.insert(lines, string.format("  oficios: %d guardias · %d granjeros · %d constructores · %d porteadores",
				roles.guardia, roles.granjero, roles.constructor, roles.porteador))
			if roles.guardia == 0 and roles.total > 0 then
				table.insert(lines, "  nadie se plantará si entran: no te ha tocado ningún guardia.")
			end
		end

		local info = hashimon_wolkers.posture_info(town.name)
		if info then
			table.insert(lines, string.format("  postura %s (%s): %s",
				info.posture, info.source or "?", info.reason or ""))
		else
			table.insert(lines, "  postura normal (sin noticias del consejo)")
		end
		return true, table.concat(lines, "\n")
	end,
})

core.register_chatcommand("wolkers_genesis", {
	description = "Pide la camada genesis para tu town (una vez por homeblock)",
	privs = { server = true },
	func = function(name)
		local town = town_of(name)
		if not town then
			return false, "No perteneces a ningún town."
		end
		local pos = town.pos
		hashimon.request_wolker_genesis(hashimon.get_server_secret(), {
			town = town.name,
			home = { x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z) },
		}, function(ok, err, granted)
			if not ok then
				core.chat_send_player(name, "Genesis falló: " .. tostring(err))
				return
			end
			if #granted == 0 then
				core.chat_send_player(name, "Este homeblock ya tuvo su camada. No hay segunda.")
			else
				core.chat_send_player(name, "Nacieron " .. #granted .. " wolkers en " .. town.name .. ".")
			end
		end)
		return true, "Pidiendo camada genesis..."
	end,
})
