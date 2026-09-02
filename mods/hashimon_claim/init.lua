-- hashimon_claim — a retail-friendly /expand for Towny.
--
-- The problem: Towny's `/town claim` claims exactly the 16x16x16 mapblock you are
-- STANDING IN, and refuses ("you must be beside your town") unless that block is
-- (a) unclaimed and (b) orthogonally grid-adjacent to a town block. Because blocks
-- are 16 nodes wide, you can FEEL next to your border but have your feet in the
-- block one-over or diagonal — and it errors. It also errors "already claimed" the
-- moment your feet are in a block that is already yours.
--
-- /expand fixes the feel: it looks at the 3x3 mapblock neighbourhood around you,
-- picks the nearest FREE block that borders your town (preferring the way you
-- face), and claims THAT. Stand anywhere near your frontier and it grabs the right
-- free block; blocks that are already yours are simply skipped, never an error.
--
-- Additive + safe: reads Towny's public API and uses Towny's own block.new to
-- claim (the same call `/town claim` makes), honouring the same limits, the
-- vertical-towns rule, permissions and the outpost merge. It never edits the towny
-- mod, so it works with the stock ContentDB Towny. MIT — Hashimon, 2026.

if not core.get_modpath("towny") or not towny then
	core.log("warning", "[hashimon_claim] Towny not found — mod inactive.")
	return
end

local bs = (towny.settings and towny.settings.town_block_size) or 16

local function center_of_bp(bp)
	return vector.new(bp.x * bs + bs * 0.5, bp.y * bs + bs * 0.5, bp.z * bs + bs * 0.5)
end

local function is_officer(res)
	return res and res.has_flag
		and (res:has_flag(towny.RESIDENT_MAYOR) or res:has_flag(towny.RESIDENT_COMAYOR))
		and true or false
end

local function claim_limit_reached(name, town)
	if core.check_player_privs(name, "towny_blocks_no_limit") then
		return false
	end
	if core.check_player_privs(name, "towny_blocks_high_limit") then
		return #town >= (towny.settings.max_townblocks_high or 1024)
	end
	return #town >= (towny.settings.max_townblocks or 64)
end

-- Can `town` claim the block at this world pos? (mirrors /town claim's guards, minus
-- the block limit which is checked once up front).
local function claimable(pos, town)
	if towny.get_block_by_pos(pos) then
		return false -- already claimed by someone (including us) — skip, don't error
	end
	if not towny.settings.vertical_towns then
		local other = towny.exists_block_at_x_z(pos)
		if other and other.town ~= town then
			return false -- another town sits directly above/below here
		end
	end
	-- must be orthogonally adjacent to one of OUR blocks
	return towny.pos_borders_townblock(pos, town) ~= nil
end

-- Horizontal step (±1 on x or z) the player is facing, for the tie-break bias.
local function facing_step(player)
	local d = player:get_look_dir()
	if math.abs(d.x) >= math.abs(d.z) then
		return (d.x >= 0) and 1 or -1, 0
	else
		return 0, (d.z >= 0) and 1 or -1
	end
end

core.register_chatcommand("expand", {
	params = "",
	description = "Reclama el bloque libre junto a tu territorio más cercano a donde estás (Towny, sin exigir precisión).",
	privs = { towny = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Debes estar en el mundo para expandir."
		end
		local res = towny.residents[name]
		local town = res and res.town
		if not town then
			return false, "No tienes pueblo. Funda uno con /town new <nombre>."
		end
		if not is_officer(res) then
			return false, "Solo el alcalde o co-alcalde pueden reclamar territorio."
		end
		if claim_limit_reached(name, town) then
			return false, "Tu pueblo llegó a su límite de bloques."
		end

		local ppos = player:get_pos()
		local pbp = towny.get_blockpos(ppos)
		local fx, fz = facing_step(player)

		-- Best FREE bordering block in the 3x3 around the player; prefer the one
		-- you're looking toward, then the closest to your feet.
		local best, best_score
		for dx = -1, 1 do
			for dz = -1, 1 do
				local bp = { x = pbp.x + dx, y = pbp.y, z = pbp.z + dz }
				local center = center_of_bp(bp)
				if claimable(center, town) then
					local face_bonus = (dx == fx and dz == fz) and 2 or 0
					local score = face_bonus - vector.distance(ppos, center) * 0.01
					if not best_score or score > best_score then
						best_score = score
						best = { bp = bp, center = center }
					end
				end
			end
		end

		if not best then
			return false,
				"No hay ningún bloque libre junto a tu territorio por aquí. "
				.. "Acércate al borde de tu pueblo, o usa /town claim outpost para saltar lejos."
		end

		-- Claim exactly the way /town claim does (non-outpost path), including the
		-- outpost-merge handling, so state stays consistent with Towny.
		local ok, err = pcall(function()
			local block = towny.block.new(best.center, town)
			if towny.neighboring_townblocks_have_flag(town, block, towny.BLOCK_OUTPOST) then
				if towny.neighboring_townblocks_have_flag(town, block, towny.BLOCK_OUTPOST, true) then
					for i = 1, #town do
						town[i]:remove_flag(towny.BLOCK_OUTPOST)
					end
				else
					block:add_flag(towny.BLOCK_OUTPOST)
				end
			end
			if block.visualize then
				block:visualize(name)
			end
		end)
		if not ok then
			core.log("warning", "[hashimon_claim] claim failed: " .. tostring(err))
			return false, "No se pudo reclamar ese bloque. Inténtalo desde otro punto del borde."
		end

		return true, string.format("Reclamado. Tu pueblo tiene %d bloques.", #town)
	end,
})

core.log("action", "[hashimon_claim] loaded. /expand — friendly Towny claiming.")
