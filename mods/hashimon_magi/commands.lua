-- /magi — the player's whole interface to the object.

hashimon_magi = hashimon_magi or {}

local function say(name, msg)
	hashimon_magi.say(name, msg)
end

local function usage()
	return "Usage: /magi [status | verify | withdraw <n> | deposit <n|all> | supply | mint <player> <n>]"
end

--- Free slots for MAGI: each note is its own stack (stack_max = 1), so capacity is
--- counted in empty slots, not in item counts.
local function free_slots(inv, listname)
	local free = 0
	for _, stack in ipairs(inv:get_list(listname) or {}) do
		if stack:is_empty() then
			free = free + 1
		end
	end
	return free
end

local function cmd_status(name)
	hashimon_magi.api_holder(name, function(ok, err, body)
		if not ok or not body then
			say(name, "Ledger unreachable (" .. tostring(err) .. ").")
			return
		end
		local player = core.get_player_by_name(name)
		local carried = player and #(hashimon_magi.carried(player)) or 0
		say(name, string.format("Vault: %d MAGI  |  in the world under your name: %d  |  in your inventory right now: %d",
			body.vaulted or 0, body.materialized or 0, carried))
		if (body.materialized or 0) ~= carried then
			say(name, "The difference is MAGI of yours placed as blocks, or notes you have handed to someone else.")
		end
	end)
end

local function cmd_verify(name)
	say(name, "Checking every MAGI you carry ...")
	hashimon_magi.sweep(name, "manual", function(ok, err, rotated, destroyed)
		if not ok then
			say(name, "Could not reach the ledger (" .. tostring(err) .. "). Nothing was taken from you.")
			return
		end
		say(name, string.format("%d note(s) verified and re-sealed, %d destroyed.", rotated or 0, destroyed or 0))
	end)
end

local function cmd_withdraw(name, count)
	local player = core.get_player_by_name(name)
	if not player then
		return
	end
	local inv = player:get_inventory()
	local room = free_slots(inv, "main")
	if room == 0 then
		say(name, "No free inventory slot — a MAGI never stacks, it needs a slot of its own.")
		return
	end
	if count > room then
		say(name, string.format("Only %d free slot(s); withdrawing %d.", room, room))
		count = room
	end
	hashimon_magi.api_withdraw(name, count, function(ok, err, body)
		if not ok or not body then
			say(name, "Withdrawal failed (" .. tostring(err) .. ").")
			return
		end
		local notes = body.notes or {}
		if #notes == 0 then
			say(name, "Your vault holds no MAGI to withdraw.")
			return
		end
		local live = core.get_player_by_name(name)
		if not live then
			-- Left mid-request: the ledger already marked them materialized, so the
			-- notes are recoverable, but they are not in anyone's hands right now.
			core.log("warning", string.format("[hashimon_magi] %s left mid-withdrawal; %d note(s) materialized with no holder online", name, #notes))
			return
		end
		local given = 0
		for _, token in ipairs(notes) do
			local leftover = live:get_inventory():add_item("main", hashimon_magi.new_note(token))
			if leftover:is_empty() then
				given = given + 1
			else
				core.add_item(live:get_pos(), leftover)
			end
		end
		say(name, string.format("Withdrew %d MAGI (%d of %d requested).", #notes, given, body.requested or count))
	end)
end

local function cmd_deposit(name, count)
	local player = core.get_player_by_name(name)
	if not player then
		return
	end
	local carried = hashimon_magi.carried(player)
	if #carried == 0 then
		say(name, "You are not carrying any MAGI.")
		return
	end
	local notes = {}
	for i = 1, math.min(count, #carried) do
		notes[i] = carried[i]
	end
	hashimon_magi.api_deposit(name, notes, function(ok, err, body)
		if not ok or not body then
			say(name, "Deposit failed (" .. tostring(err) .. "). You still hold your notes.")
			return
		end
		local live = core.get_player_by_name(name)
		if not live then
			return
		end
		local deposited, destroyed = 0, 0
		for _, result in ipairs(body.results or {}) do
			local inv, listname, index = hashimon_magi.find_stack(live, result.serial)
			-- On `ok` the note is now vaulted: the item must disappear, not be
			-- re-sealed, or the balance would exist twice.
			if inv and (result.verdict == "ok" or hashimon_magi.DESTROY_REASONS[result.verdict]) then
				inv:set_stack(listname, index, ItemStack(""))
			end
			if result.verdict == "ok" then
				deposited = deposited + 1
			elseif hashimon_magi.DESTROY_REASONS[result.verdict] then
				destroyed = destroyed + 1
				say(name, string.format("MAGI #%s destroyed: %s",
					hashimon_magi.short_serial(result.serial), hashimon_magi.DESTROY_REASONS[result.verdict]))
			end
		end
		say(name, string.format("Deposited %d MAGI into your vault.%s",
			deposited, destroyed > 0 and (" " .. destroyed .. " rejected.") or ""))
	end)
end

local function cmd_supply(name)
	hashimon_magi.api_supply(function(ok, err, body)
		if not ok or not body then
			say(name, "Ledger unreachable (" .. tostring(err) .. ").")
			return
		end
		say(name, string.format("Supply: %d of %d issued (cap) | vaulted %d, in the world %d, retired %d",
			body.issued or 0, body.cap or 0, body.vaulted or 0, body.materialized or 0, body.retired or 0))
		say(name, string.format("Backing: %d sats per MAGI, %d sats across the whole issued supply (epoch %d).",
			body.satsPerMagi or 0, body.reserveSats or 0, body.epoch or 0))
	end)
end

local function cmd_mint(name, target, count)
	if not core.check_player_privs(name, { magi_admin = true }) then
		say(name, "You need the magi_admin privilege to issue MAGI.")
		return
	end
	hashimon_magi.api_issue(target, count, function(ok, err, body)
		if not ok then
			if err == "supply_exhausted" then
				say(name, "Refused: the supply cap is reached. No more MAGI can be issued in this epoch.")
			else
				say(name, "Issue failed (" .. tostring(err) .. ").")
			end
			return
		end
		say(name, string.format("Issued %d MAGI into %s's vault (%d of %d now issued).",
			body.issued or 0, target, (body.supply and body.supply.issued) or 0, (body.supply and body.supply.cap) or 0))
		if core.get_player_by_name(target) and target ~= name then
			say(target, string.format("%d MAGI were issued into your vault. Use /magi withdraw <n> to hold them.", body.issued or 0))
		end
	end)
end

core.register_chatcommand("magi", {
	params = "[status | verify | withdraw <n> | deposit <n|all> | supply | mint <player> <n>]",
	description = "Inspect, withdraw, deposit and verify MAGI",
	privs = { interact = true },
	func = function(name, param)
		local args = {}
		for word in tostring(param):gmatch("%S+") do
			args[#args + 1] = word
		end
		local sub = (args[1] or "status"):lower()

		if sub == "status" then
			cmd_status(name)
		elseif sub == "verify" then
			cmd_verify(name)
		elseif sub == "supply" then
			cmd_supply(name)
		elseif sub == "withdraw" then
			local n = tonumber(args[2]) or 1
			if n < 1 then
				return false, "Withdraw at least 1."
			end
			cmd_withdraw(name, math.min(math.floor(n), 64))
		elseif sub == "deposit" then
			local n = (args[2] == "all" or args[2] == nil) and 64 or tonumber(args[2])
			if not n or n < 1 then
				return false, "Deposit a count, or `all`."
			end
			cmd_deposit(name, math.min(math.floor(n), 64))
		elseif sub == "mint" then
			local target, n = args[2], tonumber(args[3])
			if not target or not n or n < 1 then
				return false, "Usage: /magi mint <player> <n>"
			end
			cmd_mint(name, target, math.min(math.floor(n), 64))
		else
			return false, usage()
		end
		return true
	end,
})
