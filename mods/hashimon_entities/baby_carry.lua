-- Baby carry: attach Hashimon baby (★1) to Sam player skeleton (inverse of mount).
-- Manual: owner right-click near baby. Slots cycle via /hashimon carry next|prev.

hashimon = hashimon or {}

hashimon.carries = hashimon.carries or {}
hashimon._carry_slot_idx = hashimon._carry_slot_idx or {}

hashimon.CARRY_RANGE = 8
local BABY_STAGE = hashimon.EVOLVE_STAGE_BABY or 1

-- Seat/rot in Luanti set_attach units (×10). Tune with /hashimon carry in-game.
local CARRY_SLOTS = {
	{
		id = "shoulder_r",
		label = "hombro derecho",
		bone = "Arm.R",
		seat = { x = 0, y = 2, z = 1 },
		rot = { x = 0, y = 180, z = 0 },
		scale = 0.5,
	},
	{
		id = "shoulder_l",
		label = "hombro izquierdo",
		bone = "Arm.L",
		seat = { x = 0, y = 2, z = 1 },
		rot = { x = 0, y = 180, z = 0 },
		scale = 0.5,
	},
	{
		id = "head",
		label = "cabeza",
		bone = "Socket.Head",
		seat = { x = 0, y = 3, z = 0 },
		rot = { x = 0, y = 0, z = 0 },
		scale = 0.45,
	},
	{
		id = "back",
		label = "espalda",
		bone = "Socket.Back",
		seat = { x = 0, y = 4, z = -2 },
		rot = { x = 0, y = 0, z = 0 },
		scale = 0.55,
	},
	{
		id = "neck",
		label = "cuello",
		bone = "Socket.Chest",
		seat = { x = 0, y = 5, z = 1 },
		rot = { x = 0, y = 0, z = 0 },
		scale = 0.5,
	},
}

local ZERO_COLLISION = { -0.01, -0.01, -0.01, 0.01, 0.01, 0.01 }

local function creature_from(ent)
	if hashimon.creature_from_entity then
		return hashimon.creature_from_entity(ent)
	end
	return ent and (ent.hashimon_creature or ent.creature)
end

local function slot_by_id(id)
	for i, slot in ipairs(CARRY_SLOTS) do
		if slot.id == id then
			return slot, i
		end
	end
	return CARRY_SLOTS[1], 1
end

local function slot_index_for_player(name, slot_id)
	if slot_id then
		local _, idx = slot_by_id(slot_id)
		hashimon._carry_slot_idx[name] = idx
		return idx
	end
	local idx = hashimon._carry_slot_idx[name] or 1
	if idx < 1 or idx > #CARRY_SLOTS then
		idx = 1
	end
	return idx
end

function hashimon.is_carryable(creature)
	if not creature then
		return false
	end
	local stage = hashimon.creature_stage and hashimon.creature_stage(creature) or 0
	return stage <= BABY_STAGE
end

local function can_attach_entity(ent)
	if not ent then
		return false
	end
	if ent.hashimon_creature or ent.hashimon_morph or ent.body_id then
		return true
	end
	local ename = ent.name or ""
	if ename:match("hashimon_bodies:") or ename == "hashimon_entities:companion" then
		return true
	end
	return false
end

local function carry_blocked(name)
	if hashimon.mounts and hashimon.mounts[name] then
		return "mounted"
	end
	if hashimon._impact_flights and hashimon._impact_flights[name] then
		return "yeeting"
	end
	if hashimon._evolve_rituals and hashimon._evolve_rituals[name] then
		return "busy"
	end
	if hashimon_villain and hashimon_villain.possessions and hashimon_villain.possessions[name] then
		return "possessed"
	end
	return nil
end

local function carry_err_msg(err)
	if err == "mounted" then
		return "Baja del Hashimon primero."
	elseif err == "yeeting" then
		return "Espera a terminar el impacto."
	elseif err == "busy" then
		return "Hay un ritual en curso."
	elseif err == "possessed" then
		return "No puedes cargar mientras estás poseído."
	elseif err == "already_carrying" then
		return "Ya llevas un baby. Suelta con click o /hashimon carry off."
	elseif err == "not_carryable" then
		return "Solo forma baby (★1) se puede cargar."
	elseif err == "not_rigged" then
		return "Solo mallas riggeadas (GLB/Creatura). Usa /hashimon sync con morph."
	elseif err == "none_nearby" then
		return "Acércate a tu Hashimon baby (menos de 8 bloques)."
	elseif err == "no_player" then
		return "Jugador no encontrado."
	elseif err == "not_owner" then
		return "Solo el dueño puede cargarlo."
	end
	return "No se pudo cargar (" .. tostring(err) .. ")."
end

function hashimon.clear_carry_state(player_name)
	hashimon.carries[player_name] = nil
end

--- Drop carried baby if `obj` matches (e.g. before evolve respawn).
function hashimon.clear_carry_for_object(player_name, obj)
	local carry = hashimon.carries[player_name]
	if carry and carry.obj == obj then
		hashimon.clear_carry_state(player_name)
		local ent = obj:get_luaentity()
		if ent then
			ent.carried_by = nil
			ent._carry_anim_set = nil
		end
	end
end

local function drop_pos_in_front(player)
	local pos = player:get_pos()
	if not pos then
		return nil
	end
	local yaw = player:get_look_horizontal()
	return {
		x = pos.x - math.sin(yaw) * 1.2,
		y = pos.y,
		z = pos.z + math.cos(yaw) * 1.2,
	}
end

local function restore_entity_props(obj, ent, saved)
	if not obj or not saved then
		return
	end
	local patch = {}
	if saved.visual_size then
		patch.visual_size = saved.visual_size
	end
	if saved.collisionbox then
		patch.collisionbox = saved.collisionbox
	end
	if saved.physical ~= nil then
		patch.physical = saved.physical
	end
	if next(patch) then
		obj:set_properties(patch)
	end
	if saved.nametag and saved.nametag.text then
		obj:set_nametag_attributes(saved.nametag)
	end
	if ent then
		ent.carried_by = nil
		ent._carry_anim_set = nil
	end
end

local function apply_carry_attach(player, obj, ent, slot)
	if hashimon.attach_to_socket then
		hashimon.attach_to_socket(player, slot.bone, obj, slot.seat, slot.rot, "sam", true)
	else
		local bone = hashimon.resolve_bone and hashimon.resolve_bone(slot.bone, "sam") or slot.bone
		obj:set_attach(player, bone, slot.seat, slot.rot, true)
	end

	local props = obj:get_properties()
	local vs = props and props.visual_size
	local mult = slot.scale or 0.5
	if vs and type(vs.x) == "number" then
		obj:set_properties({
			visual_size = { x = vs.x * mult, y = vs.y * mult },
			collisionbox = ZERO_COLLISION,
			physical = false,
		})
	end
	obj:set_nametag_attributes({ text = "" })

	ent.carried_by = player:get_player_name()
	ent._carry_anim_set = nil
	if ent.set_animation then
		ent:set_animation("stand")
	end
end

--- Nearest owned baby within range.
function hashimon.find_nearest_carryable_entity(player, max_dist)
	if not player or not player:is_player() then
		return nil
	end
	local name = player:get_player_name()
	local ppos = player:get_pos()
	if not ppos then
		return nil
	end
	max_dist = max_dist or hashimon.CARRY_RANGE
	local max2 = max_dist * max_dist

	local best_obj, best_ent, best_c, best_d2
	for _, ref in ipairs(hashimon.get_roster_entities and hashimon.get_roster_entities(name) or {}) do
		local ent = ref and ref:get_luaentity()
		local c = creature_from(ent)
		if ent and c and hashimon.is_carryable(c) and can_attach_entity(ent) then
			local rpos = ref:get_pos()
			if rpos then
				local dx, dy, dz = rpos.x - ppos.x, rpos.y - ppos.y, rpos.z - ppos.z
				local d2 = dx * dx + dy * dy + dz * dz
				if d2 <= max2 and (not best_obj or d2 < best_d2) then
					best_obj = ref
					best_d2 = d2
					best_ent = ent
					best_c = c
				end
			end
		end
	end
	return best_obj, best_ent, best_c
end

--- Attach baby to player at slot (default: player's cycle index).
function hashimon.carry(player, obj, slot_id)
	if not player or not player:is_player() or not obj then
		return false, "no_player"
	end
	local name = player:get_player_name()
	local ent = obj:get_luaentity()
	if not ent then
		return false, "none_nearby"
	end

	local blocked = carry_blocked(name)
	if blocked then
		return false, blocked
	end

	if hashimon.carries[name] and hashimon.carries[name].obj ~= obj then
		return false, "already_carrying"
	end

	local creature = creature_from(ent)
	if not hashimon.is_carryable(creature) then
		return false, "not_carryable"
	end
	if not can_attach_entity(ent) then
		return false, "not_rigged"
	end
	if not hashimon.player_owns_mount(name, ent, ent.owner) then
		return false, "not_owner"
	end
	if ent.rider then
		return false, "mounted"
	end

	local idx = slot_index_for_player(name, slot_id)
	local slot = CARRY_SLOTS[idx]
	if slot_id then
		local _, new_idx = slot_by_id(slot_id)
		slot = CARRY_SLOTS[new_idx]
		idx = new_idx
		hashimon._carry_slot_idx[name] = idx
	end

	local props = obj:get_properties()
	local saved = {
		visual_size = props and props.visual_size,
		collisionbox = props and props.collisionbox,
		physical = props and props.physical,
		nametag = obj:get_nametag_attributes(),
	}

	apply_carry_attach(player, obj, ent, slot)

	hashimon.carries[name] = {
		obj = obj,
		ent = ent,
		creature = creature,
		slot = slot.id,
		slot_idx = idx,
		saved = saved,
	}

	return true, slot.label
end

--- Detach baby and optionally place in front of player.
function hashimon.uncarry(player, drop_at_feet)
	if not player or not player:is_player() then
		return false, "no_player"
	end
	local name = player:get_player_name()
	local carry = hashimon.carries[name]
	if not carry or not carry.obj then
		return false, "none"
	end

	local obj = carry.obj
	local ent = carry.ent
	if not obj:get_luaentity() then
		hashimon.carries[name] = nil
		return false, "gone"
	end

	obj:set_detach()
	restore_entity_props(obj, ent, carry.saved)

	if drop_at_feet ~= false then
		local drop = drop_pos_in_front(player)
		if drop then
			obj:set_pos(drop)
		end
	end

	local slot_def = select(1, slot_by_id(carry.slot))
	local label = (slot_def and slot_def.label) or carry.slot
	hashimon.carries[name] = nil
	return true, label
end

--- Rotate carry slot while baby is attached.
function hashimon.cycle_carry_slot(player, dir)
	if not player or not player:is_player() then
		return false, "no_player"
	end
	local name = player:get_player_name()
	local carry = hashimon.carries[name]
	if not carry or not carry.obj or not carry.obj:get_luaentity() then
		return false, "none"
	end

	dir = (dir or "next"):lower()
	local idx = carry.slot_idx or 1
	if dir == "prev" then
		idx = idx - 1
		if idx < 1 then
			idx = #CARRY_SLOTS
		end
	else
		idx = idx + 1
		if idx > #CARRY_SLOTS then
			idx = 1
		end
	end

	hashimon._carry_slot_idx[name] = idx
	local slot = CARRY_SLOTS[idx]

	local obj = carry.obj
	local ent = carry.ent
	obj:set_detach()

	-- Re-apply shrunk size before attach (restore would full-size it).
	local props = obj:get_properties()
	local vs = props and props.visual_size
	local mult = slot.scale or 0.5
	if carry.saved and carry.saved.visual_size and type(carry.saved.visual_size.x) == "number" then
		local base = carry.saved.visual_size
		obj:set_properties({
			visual_size = { x = base.x * mult, y = base.y * mult },
			collisionbox = ZERO_COLLISION,
			physical = false,
		})
	elseif vs and type(vs.x) == "number" then
		obj:set_properties({
			visual_size = { x = vs.x * mult, y = vs.y * mult },
			collisionbox = ZERO_COLLISION,
			physical = false,
		})
	end

	apply_carry_attach(player, obj, ent, slot)
	carry.slot = slot.id
	carry.slot_idx = idx

	return true, slot.label
end

--- Owner right-click: toggle carry on baby, or pass through to mount.
function hashimon.try_owner_carry(clicker, obj, creature, owner)
	if not clicker or not clicker:is_player() or not obj then
		return false
	end
	local name = clicker:get_player_name()
	local ent = obj:get_luaentity()
	if not ent then
		return false
	end

	creature = creature or creature_from(ent)
	local owns = hashimon.player_owns_mount(name, ent, owner)

	local carry = hashimon.carries[name]
	if carry and carry.obj == obj then
		local ok = hashimon.uncarry(clicker, true)
		if ok then
			core.chat_send_player(name, "[Hashimon] Baby suelto.")
		end
		return true
	end

	if not owns or not hashimon.is_carryable(creature) then
		return false
	end

	if not can_attach_entity(ent) then
		if owns then
			core.chat_send_player(name, "[Hashimon] " .. carry_err_msg("not_rigged"))
		end
		return false
	end

	if carry then
		core.chat_send_player(name, "[Hashimon] " .. carry_err_msg("already_carrying"))
		return true
	end

	local ok, result = hashimon.carry(clicker, obj, nil)
	if ok then
		core.chat_send_player(name, string.format(
			"[Hashimon] Cargando en %s — /hashimon carry next para cambiar posición.",
			result or "?"
		))
	else
		core.chat_send_player(name, "[Hashimon] " .. carry_err_msg(result))
	end
	return true
end

function hashimon.step_carried(self, _dtime)
	if self.set_animation then
		if not self._carry_anim_set then
			self:set_animation("stand")
			self._carry_anim_set = true
		end
	end
end

function hashimon.carry_nearest(player)
	if not player or not player:is_player() then
		return false, "no_player"
	end
	local name = player:get_player_name()

	if hashimon.carries[name] then
		local ok = hashimon.uncarry(player, true)
		if ok then
			return true, "dropped"
		end
		return false, "none"
	end

	local obj = hashimon.find_nearest_carryable_entity(player, hashimon.CARRY_RANGE)
	if not obj then
		return false, "none_nearby"
	end
	local ok, result = hashimon.carry(player, obj, nil)
	return ok, ok and "carried" or result, result
end

function hashimon.carry_command(name, rest)
	local player = core.get_player_by_name(name)
	if not player then
		return false, "Player not found"
	end
	local sub = (tostring(rest or ""):match("^(%S*)") or ""):lower()

	if sub == "off" or sub == "drop" or sub == "soltar" then
		local ok = hashimon.uncarry(player, true)
		if ok then
			return true, "Baby suelto."
		end
		return false, "No llevas ningún baby."
	end

	if sub == "next" or sub == "prev" or sub == "siguiente" or sub == "anterior" then
		local dir = (sub == "prev" or sub == "anterior") and "prev" or "next"
		local ok, label = hashimon.cycle_carry_slot(player, dir)
		if ok then
			return true, "Posición: " .. tostring(label) .. "."
		end
		return false, "Primero carga un baby (click derecho o /hashimon carry)."
	end

	for _, slot in ipairs(CARRY_SLOTS) do
		if sub == slot.id or sub == slot.label:gsub(" ", "_") then
			local carry = hashimon.carries[name]
			if carry and carry.obj and carry.obj:get_luaentity() then
				local ok, label = hashimon.carry(player, carry.obj, slot.id)
				if ok then
					return true, "Posición: " .. tostring(label) .. "."
				end
				return false, carry_err_msg(label)
			end
			break
		end
	end

	local ok, result, label = hashimon.carry_nearest(player)
	if ok then
		if result == "dropped" then
			return true, "Baby suelto."
		end
		return true, string.format(
			"Cargando en %s — /hashimon carry next para rotar.",
			label or "?"
		)
	end
	return false, carry_err_msg(result)
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local carry = hashimon.carries[name]
	if carry and carry.obj and carry.obj:get_luaentity() then
		hashimon.uncarry(player, true)
	else
		hashimon.clear_carry_state(name)
	end
end)

core.log("action", "[hashimon_entities] baby_carry loaded (Shift-free: click baby, carry next/prev)")
