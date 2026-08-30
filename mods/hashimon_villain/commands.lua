local function send(name, msg)
	core.chat_send_player(name, "[HV] " .. msg)
end

local function check_priv(name)
	return core.check_player_privs(name, { hashimon_villain = true })
		or core.check_player_privs(name, { server = true })
end

local function spawn_pos(player)
	local pos = player:get_pos()
	if not pos then
		return nil
	end
	local look = player:get_look_dir()
	return {
		x = pos.x + look.x * 2,
		y = pos.y + 1,
		z = pos.z + look.z * 2,
	}
end

core.register_privilege("hashimon_villain", {
	description = "Spawn and possess Hashimon villain mobs",
	give_to_singleplayer = true,
})

core.register_chatcommand("hv", {
	params = "<spawn|possess|release|mode|list> [args]",
	description = "Villain admin: spawn, possess, release, mode, list",
	func = function(name, param)
		if not check_priv(name) then
			return false, "Requires hashimon_villain or server privilege."
		end

		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end

		local cmd, rest = param:match("^(%S*)%s*(.*)$")
		cmd = cmd ~= "" and cmd or "list"
		rest = rest or ""

		if cmd == "spawn" then
			local body_id
			if rest ~= "" then
				body_id = rest
			else
				body_id = hashimon_villain.default_body_id()
			end
			if not body_id then
				return false, "No hay body volador disponible (dragon_wyvern o avian_bat)."
			end
			local pos = spawn_pos(player)
			if not pos then
				return false, "Could not determine spawn position."
			end
			local obj, err = hashimon_villain.spawn(body_id, pos, { mode = hashimon_villain.CONTROLLER_AI })
			if not obj then
				return false, "Spawn failed: " .. tostring(err)
			end
			send(name, "Monstruo spawneado: " .. hashimon_villain.display_name(body_id) .. " — /hv possess")
			return true
		end

		if cmd == "possess" then
			local pos = player:get_pos()
			local target = hashimon_villain.nearest_villain(pos)
			if not target then
				return false, "No hay villano cerca (≤ " .. hashimon_villain.POSSESS_RANGE .. " nodes)."
			end
			local ok, err = hashimon_villain.possess(player, target)
			if not ok then
				return false, "Possess failed: " .. tostring(err)
			end
			return true
		end

		if cmd == "release" then
			hashimon_villain.release(player)
			return true
		end

		if cmd == "mode" then
			local mode = rest:match("^(%S+)")
			if mode ~= "ai" and mode ~= "idle" then
				return false, "Usage: /hv mode ai|idle"
			end
			local pos = player:get_pos()
			local target = hashimon_villain.nearest_villain(pos, 16)
			if not target then
				return false, "No villain nearby."
			end
			local ent = target:get_luaentity()
			if ent.possessor then
				return false, "Release possession first."
			end
			hashimon_villain.set_controller_mode(ent, mode)
			send(name, "Modo " .. mode .. " aplicado a " .. (ent.body_id or "villain"))
			return true
		end

		if cmd == "list" then
			local lines = hashimon_villain.list_active()
			if #lines == 0 then
				send(name, "No hay villanos activos.")
			else
				send(name, "Villanos activos (" .. #lines .. "):")
				for _, line in ipairs(lines) do
					send(name, line)
				end
			end
			return true
		end

		return false, "Unknown subcommand. Use: spawn|possess|release|mode|list"
	end,
})
