-- hashimon_town_desk — additive Town Desk on top of stock Towny.
-- Does not modify the towny mod files. Wraps /town after towny registers it.
-- MIT — Hashimon, 2026.

if not core.get_modpath("towny") or not towny then
	core.log("error", "[hashimon_town_desk] Towny not found — mod inactive.")
	return
end

dofile(core.get_modpath(core.get_current_modname()) .. "/desk.lua")

-- Original Towny handlers (must capture BEFORE we re-register).
local orig_town = core.registered_chatcommands["town"]
local orig_resident = core.registered_chatcommands["resident"]

if not orig_town or not orig_town.func then
	core.log("error", "[hashimon_town_desk] /town not registered yet — load order broken.")
	return
end

-- desk.lua calls registered_chatcommands["town"] for found/invite/etc.
-- Point those at the ORIGINAL so we never recurse into this wrapper.
towny.desk._orig_town = orig_town.func
towny.desk._orig_resident = orig_resident and orig_resident.func

local function is_officer(res)
	return res and res.has_flag
		and (res:has_flag(towny.RESIDENT_MAYOR) or res:has_flag(towny.RESIDENT_COMAYOR))
		and true or false
end

local function is_mayor(res)
	return res and res.has_flag and res:has_flag(towny.RESIDENT_MAYOR) and true or false
end

local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Wrap /town: empty → desk; gate invite/set mayor/rank mayor; else stock.
core.override_chatcommand("town", {
	params = "(sin args = Escritorio) || " .. (orig_town.params or ""),
	description = "Escritorio del pueblo (Hashimon). Sin args abre el panel. Subcomandos Towny siguen disponibles.",
	privs = orig_town.privs or { towny = true },
	func = function(name, param)
		param = trim(param)
		if param == "" or param == "desk" or param == "menu" or param == "ui" then
			local ok, err = pcall(towny.desk.show, name, "main")
			if not ok then
				core.log("error", "[hashimon_town_desk] show failed: " .. tostring(err))
				return false, "Error abriendo Escritorio: " .. tostring(err)
			end
			return true, "Abriendo el Escritorio del pueblo…"
		end

		-- Officer-only invites
		local invite_target = param:match("^invite%s+(%S+)$")
		if invite_target and invite_target ~= "sent" and invite_target ~= "revoke" then
			local res = towny.residents[name]
			if not is_officer(res) then
				return false, "Solo el alcalde o co-alcalde pueden invitar."
			end
		end
		if param:match("^invite%s+revoke") or param == "invite sent" then
			local res = towny.residents[name]
			if not is_officer(res) then
				return false, "Solo el alcalde o co-alcalde pueden gestionar invitaciones."
			end
		end

		-- Mayor transfer → desk confirm (ex-mayor stays co-mayor)
		local mayor_target = param:match("^set%s+mayor%s+(%S+)$")
		if mayor_target then
			local res = towny.residents[name]
			if not is_mayor(res) then
				return false, "Solo el alcalde puede transferir la alcaldía."
			end
			if not (res.town and res.town.members[mayor_target]) then
				return false, mayor_target .. " no está en tu pueblo."
			end
			towny.desk.pending_mayor[name] = mayor_target
			towny.desk.show(name, "confirm_mayor")
			return true, "Confirma la transferencia en el Escritorio (escribe el nombre del pueblo)."
		end

		-- Block inventing mayors via /town rank
		if param:match("^rank%s+") and param:match("%smayor%s*$") then
			return false, "Usa /town set mayor <jugador> (pide confirmación en el Escritorio)."
		end
		-- Only mayor may add/remove comayor
		if param:match("^rank%s+") and param:match("comayor") then
			local res = towny.residents[name]
			if not is_mayor(res) then
				return false, "Solo el alcalde puede nombrar o quitar co-alcaldes."
			end
		end

		-- Block kicking the mayor
		local kick_target = param:match("^kick%s+(%S+)$")
		if kick_target then
			local res = towny.residents[name]
			local member = res and res.town and res.town.members[kick_target]
			if member and is_mayor(member) then
				return false, "No puedes expulsar al alcalde. Transfiere la alcaldía primero."
			end
		end

		return orig_town.func(name, param)
	end,
})

core.register_chatcommand("pueblo", {
	params = core.registered_chatcommands["town"].params,
	description = "Alias de /town — abre el Escritorio del pueblo.",
	privs = { towny = true },
	func = core.registered_chatcommands["town"].func,
})

core.log("action", "[hashimon_town_desk] loaded — /town /pueblo / Space+Z open the desk (stock Towny untouched).")
