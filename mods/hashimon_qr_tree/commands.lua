local function send(name, msg)
	core.chat_send_player(name, "[QR] " .. msg)
end

local function require_admin(name)
	return core.check_player_privs(name, { hashimon_qr_admin = true })
end

core.register_chatcommand("qr_tree", {
	params = "<list|place|align|remove> [id|all]",
	description = "Admin: hidden sponsor QR groves (place, align for scan, list, remove)",
	func = function(name, param)
		if not require_admin(name) then
			return false, "Requires hashimon_qr_admin privilege."
		end

		local cmd, rest = param:match("^(%S*)%s*(.*)$")
		cmd = cmd ~= "" and cmd or "list"
		rest = (rest or ""):match("^%s*(.-)%s*$")

		if cmd == "list" then
			local lines = {}
			for _, sponsor in ipairs(hashimon_qr_tree.sponsors) do
				local placed = hashimon_qr_tree.placed[sponsor.id]
				local status = placed and "placed" or "pending"
				local coords = ""
				if placed then
					coords = string.format(" @ X=%d Z=%d", placed.center.x, placed.center.z)
				elseif sponsor.pos then
					coords = string.format(" → target X=%d Z=%d", sponsor.pos.x, sponsor.pos.z)
				end
				table.insert(lines, string.format("  %s [%s]%s — %s", sponsor.id, status, coords, sponsor.label or sponsor.url))
			end
			if #lines == 0 then
				return true, "No sponsors in sponsors.lua"
			end
			return true, "Sponsors:\n" .. table.concat(lines, "\n")
		end

		if cmd == "place" then
			if rest == "" or rest == "all" then
				hashimon_qr_tree.place_all(name, function(ok, msg)
					send(name, ok and msg or ("Error: " .. msg))
				end)
				return true, "Placing all sponsors (async)…"
			end
			hashimon_qr_tree.place_sponsor(rest, function(ok, msg)
				send(name, ok and msg or ("Error: " .. msg))
			end)
			return true, "Placing " .. rest .. "…"
		end

		if cmd == "align" then
			if rest == "" then
				return false, "Usage: /qr_tree align <id>"
			end
			local player = core.get_player_by_name(name)
			if not player then
				return false, "Player not found."
			end
			local ok, msg = hashimon_qr_tree.align_player(player, rest)
			return ok, msg
		end

		if cmd == "remove" then
			if rest == "" then
				return false, "Usage: /qr_tree remove <id>"
			end
			hashimon_qr_tree.remove_sponsor(rest, function(ok, msg)
				send(name, ok and msg or ("Error: " .. msg))
			end)
			return true, "Removing " .. rest .. "…"
		end

		return false, "Unknown subcommand. Use list, place, align, or remove."
	end,
})
