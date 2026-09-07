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
		local info = hashimon_wolkers.posture_info(town.name)
		if not info then
			return true, town.name .. ": todavía sin noticias del consejo (postura: normal)."
		end
		return true, string.format("%s → postura %s (%s): %s",
			town.name, info.posture, info.source or "?", info.reason or "")
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
