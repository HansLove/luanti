-- Baby carry: attach Hashimon baby (★1) to the player (inverse of mount).
-- Bob/Ana: Socket.Carry.* with seat {0,0,0}. Sam fallback: Arm/Head offsets.
-- Manual: owner right-click near baby. Slots cycle via /hashimon carry next|prev.
--
-- FACING PROTOCOL: Bob and babies both export with --yaw 180 (Luanti −Z =
-- forward). Attaching with rot {0,0,0} leaves the baby facing the opposite way
-- of Bob. Canonical align is Y=180 so baby Head points the same way as Bob.
-- Override per body with carry_view.rot / by_slot.rot, or live /hashimon carry rot.

hashimon = hashimon or {}

hashimon.carries = hashimon.carries or {}
hashimon._carry_slot_idx = hashimon._carry_slot_idx or {}

hashimon.CARRY_RANGE = 8
local BABY_STAGE = hashimon.EVOLVE_STAGE_BABY or 1

-- Align baby forward (−Z) with Bob forward on Socket.Carry.*.
local CARRY_ALIGN_ROT = { x = 0, y = 180, z = 0 }

-- Bob (Hashimon skeleton): sockets authored in Blender — seat stays zero.
local CARRY_SLOTS_HASHIMON = {
	{
		id = "shoulder_r",
		label = "hombro derecho",
		bone = "Socket.Carry.Shoulder.R",
		seat = { x = 0, y = 0, z = 0 },
		rot = CARRY_ALIGN_ROT,
		scale = 0.5,
	},
	{
		id = "shoulder_l",
		label = "hombro izquierdo",
		bone = "Socket.Carry.Shoulder.L",
		seat = { x = 0, y = 0, z = 0 },
		rot = CARRY_ALIGN_ROT,
		scale = 0.5,
	},
	{
		id = "head",
		label = "cabeza",
		bone = "Socket.Carry.Head",
		seat = { x = 0, y = 0, z = 0 },
		rot = CARRY_ALIGN_ROT,
		scale = 0.45,
	},
	{
		id = "back",
		label = "espalda",
		bone = "Socket.Carry.Back",
		seat = { x = 0, y = 0, z = 0 },
		rot = CARRY_ALIGN_ROT,
		scale = 0.55,
	},
	{
		id = "neck",
		label = "cuello",
		bone = "Socket.Carry.Neck",
		seat = { x = 0, y = 0, z = 0 },
		rot = CARRY_ALIGN_ROT,
		scale = 0.5,
	},
}

-- Sam fallback (offsets in set_attach ×10 units).
local CARRY_SLOTS_SAM = {
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

local function carry_slots_for(player)
	local target = hashimon.player_attach_target and hashimon.player_attach_target(player) or "sam"
	if target == "hashimon" then
		return CARRY_SLOTS_HASHIMON, "hashimon"
	end
	return CARRY_SLOTS_SAM, "sam"
end

local ZERO_COLLISION = { -0.01, -0.01, -0.01, 0.01, 0.01, 0.01 }

local function creature_from(ent)
	if hashimon.creature_from_entity then
		return hashimon.creature_from_entity(ent)
	end
	return ent and (ent.hashimon_creature or ent.creature)
end

local function slot_by_id(slots, id)
	for i, slot in ipairs(slots) do
		if slot.id == id then
			return slot, i
		end
	end
	return slots[1], 1
end

local function slot_index_for_player(name, slots, slot_id)
	if slot_id then
		local _, idx = slot_by_id(slots, slot_id)
		hashimon._carry_slot_idx[name] = idx
		return idx
	end
	local idx = hashimon._carry_slot_idx[name] or 1
	if idx < 1 or idx > #slots then
		idx = 1
	end
	return idx
end

--- body_def.carry_view from entity or compiled morph.
local function resolve_carry_view(ent, creature)
	local body_id = hashimon.body_id_from_entity and hashimon.body_id_from_entity(ent)
	local body = body_id and hashimon.get_body and hashimon.get_body(body_id)
	if body and body.carry_view then
		return body.carry_view
	end
	if creature and hashimon.compile_morphology then
		local morph = hashimon.compile_morphology(creature)
		if morph and morph.body_id and hashimon.get_body then
			body = hashimon.get_body(morph.body_id)
			if body and body.carry_view then
				return body.carry_view
			end
		end
	end
	return nil
end

--- Preferred carry slot from body_def.carry_view or morph body.
local function preferred_slot_id(ent, creature)
	local cv = resolve_carry_view(ent, creature)
	if cv and cv.slot then
		return cv.slot, cv.scale, cv
	end
	return nil, nil, nil
end

--- Restrict player slots to carry_view.slots (e.g. bloom: neck ↔ head).
local function slots_for_entity(player, ent, creature)
	local all_slots, attach_target = carry_slots_for(player)
	local cv = resolve_carry_view(ent, creature)
	if not cv or type(cv.slots) ~= "table" or #cv.slots == 0 then
		-- Still honor global carry_view.rot when slots list is absent.
		if cv and cv.rot and type(cv.rot) == "table" then
			local out = {}
			for _, s in ipairs(all_slots) do
				out[#out + 1] = {
					id = s.id,
					label = s.label,
					bone = s.bone,
					seat = s.seat,
					rot = cv.rot,
					scale = (cv.scale and type(cv.scale) == "number") and cv.scale or s.scale,
				}
			end
			return out, attach_target, cv
		end
		return all_slots, attach_target, cv
	end
	local filtered = {}
	for _, id in ipairs(cv.slots) do
		local found = select(1, slot_by_id(all_slots, id))
		if found and found.id == id then
			local slot = {
				id = found.id,
				label = found.label,
				bone = found.bone,
				seat = found.seat,
				rot = (cv.rot and type(cv.rot) == "table") and cv.rot or found.rot,
				scale = (cv.scale and type(cv.scale) == "number") and cv.scale or found.scale,
			}
			-- Optional per-slot seat/rot: carry_view.by_slot[id] = { seat=, rot=, scale= }
			local by = cv.by_slot and cv.by_slot[id]
			if by and type(by) == "table" then
				slot = {
					id = slot.id,
					label = slot.label,
					bone = slot.bone,
					seat = by.seat or slot.seat,
					rot = by.rot or slot.rot,
					scale = by.scale or slot.scale,
				}
			end
			filtered[#filtered + 1] = slot
		end
	end
	if #filtered == 0 then
		return all_slots, attach_target, cv
	end
	return filtered, attach_target, cv
end

local function copy_vec3(v, fallback)
	if type(v) == "table" and type(v.x) == "number" then
		return { x = v.x, y = v.y or 0, z = v.z or 0 }
	end
	return {
		x = fallback.x,
		y = fallback.y,
		z = fallback.z,
	}
end

local function apply_carry_scale(slot, pref_scale)
	if not pref_scale or type(pref_scale) ~= "number" then
		return slot
	end
	if slot.scale == pref_scale then
		return slot
	end
	return {
		id = slot.id,
		label = slot.label,
		bone = slot.bone,
		seat = slot.seat,
		rot = slot.rot,
		scale = pref_scale,
	}
end

local function carry_anim_name(ent, creature, slot_id)
	local cv = resolve_carry_view(ent, creature)
	if not slot_id and ent and ent.carried_by and hashimon.carries then
		local carry = hashimon.carries[ent.carried_by]
		if carry then
			slot_id = carry.slot
		end
	end
	if cv and type(cv.anim_by_slot) == "table" and slot_id then
		local named = cv.anim_by_slot[slot_id]
		if type(named) == "string" and named ~= "" then
			return named
		end
	end
	if cv and type(cv.anim) == "string" and cv.anim ~= "" then
		return cv.anim
	end
	return "stand"
end

local function play_carry_anim(ent, creature, slot_id)
	if not ent or not ent.object then
		return
	end
	local anim_name = carry_anim_name(ent, creature, slot_id)
	-- Prefer morph/body_def ranges so a hot-reload picks up new perch_* clips
	-- even if the live Creatura entity still has a stale animations table.
	local body = nil
	local morph = ent.hashimon_morph
	if morph and morph.body_id and hashimon.get_body then
		body = hashimon.get_body(morph.body_id)
	end
	if not body then
		local body_id = hashimon.body_id_from_entity and hashimon.body_id_from_entity(ent)
		body = body_id and hashimon.get_body and hashimon.get_body(body_id)
	end
	local spec = body and body.animations and body.animations[anim_name]
	if not spec and ent.animations then
		spec = ent.animations[anim_name]
	end
	if not spec then
		spec = body and body.animations and body.animations.stand
			or (ent.animations and ent.animations.stand)
	end
	if not spec or not spec.range then
		core.log("warning", "[baby_carry] no anim spec for " .. tostring(anim_name))
		return
	end
	local range = spec.range
	local speed = spec.speed or 24
	local loop = spec.loop ~= false
	-- Bypass Creatura :animate so we always hit ObjectRef frames.
	ent._anim = anim_name
	ent.object:set_animation(range, speed, 0, loop)
	core.log("action", string.format(
		"[baby_carry] perch anim %s frames %s-%s @%s",
		tostring(anim_name), tostring(range.x), tostring(range.y), tostring(speed)
	))
end

--- World-space scale for an attached child. Luanti multiplies child visual_size
--- by the parent's (same as mount rider_scale) — divide so carry_view.scale is
--- "fraction of unattached size in world space".
local function attached_visual_size(base_vs, scale, parent)
	local bx = (type(base_vs) == "table" and base_vs.x) or 1
	local by = (type(base_vs) == "table" and base_vs.y) or bx
	local mult = (type(scale) == "number" and scale > 0) and scale or 0.5
	local parent_vs = 1
	if parent and parent.get_properties then
		local pp = parent:get_properties()
		local pvs = pp and pp.visual_size
		if type(pvs) == "table" and type(pvs.x) == "number" and pvs.x > 0.001 then
			parent_vs = pvs.x
		end
	end
	local factor = mult / parent_vs
	return { x = bx * factor, y = by * factor }
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

local function apply_carry_attach(player, obj, ent, slot, attach_target)
	attach_target = attach_target
		or (hashimon.player_attach_target and hashimon.player_attach_target(player))
		or "sam"
	if hashimon.attach_to_socket then
		hashimon.attach_to_socket(player, slot.bone, obj, slot.seat, slot.rot, attach_target, true)
	else
		local bone = hashimon.resolve_bone and hashimon.resolve_bone(slot.bone, attach_target) or slot.bone
		obj:set_attach(player, bone, slot.seat, slot.rot, true)
	end

	local props = obj:get_properties()
	local vs = props and props.visual_size
	if vs and type(vs.x) == "number" then
		obj:set_properties({
			visual_size = attached_visual_size(vs, slot.scale or 0.5, player),
			collisionbox = ZERO_COLLISION,
			physical = false,
		})
	end
	obj:set_nametag_attributes({ text = "" })

	ent.carried_by = player:get_player_name()
	ent._carry_anim_set = nil
	play_carry_anim(ent, creature_from(ent), slot.id)
	ent._carry_anim_set = true
end

--- Live-calibrate attach rotation while carrying (like /hashimon rot for mounts).
--- Paste the printed rot into carry_view.rot or by_slot.<id>.rot.
function hashimon.apply_carry_rot(player, rot)
	if not player or not player:is_player() then
		return false, "no_player"
	end
	local name = player:get_player_name()
	local carry = hashimon.carries[name]
	if not carry or not carry.obj or not carry.obj:get_luaentity() then
		return false, "none"
	end
	if type(rot) ~= "table" or type(rot.x) ~= "number" then
		return false, "bad_rot"
	end

	local ent = carry.ent
	local slots, attach_target = slots_for_entity(player, ent, carry.creature)
	local base = select(1, slot_by_id(slots, carry.slot))
	local slot = {
		id = base.id,
		label = base.label,
		bone = base.bone,
		seat = copy_vec3(carry.live_seat or base.seat, { x = 0, y = 0, z = 0 }),
		rot = { x = rot.x, y = rot.y, z = rot.z },
		scale = base.scale,
	}

	local obj = carry.obj
	obj:set_detach()
	if carry.saved and carry.saved.visual_size then
		obj:set_properties({
			visual_size = carry.saved.visual_size,
			collisionbox = ZERO_COLLISION,
			physical = false,
		})
	end
	apply_carry_attach(player, obj, ent, slot, attach_target)
	carry.slot = slot.id
	carry.attach_target = attach_target
	carry.live_rot = slot.rot

	return true, slot
end

--- Live-calibrate attach seat while carrying (like /hashimon seat for mounts).
--- Paste into carry_view.by_slot.<id>.seat.
function hashimon.apply_carry_seat(player, seat)
	if not player or not player:is_player() then
		return false, "no_player"
	end
	local name = player:get_player_name()
	local carry = hashimon.carries[name]
	if not carry or not carry.obj or not carry.obj:get_luaentity() then
		return false, "none"
	end
	if type(seat) ~= "table" or type(seat.x) ~= "number" then
		return false, "bad_seat"
	end

	local ent = carry.ent
	local slots, attach_target = slots_for_entity(player, ent, carry.creature)
	local base = select(1, slot_by_id(slots, carry.slot))
	local slot = {
		id = base.id,
		label = base.label,
		bone = base.bone,
		seat = { x = seat.x, y = seat.y, z = seat.z },
		rot = copy_vec3(carry.live_rot or base.rot, CARRY_ALIGN_ROT),
		scale = base.scale,
	}

	local obj = carry.obj
	obj:set_detach()
	if carry.saved and carry.saved.visual_size then
		obj:set_properties({
			visual_size = carry.saved.visual_size,
			collisionbox = ZERO_COLLISION,
			physical = false,
		})
	end
	apply_carry_attach(player, obj, ent, slot, attach_target)
	carry.slot = slot.id
	carry.attach_target = attach_target
	carry.live_seat = slot.seat

	return true, slot
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

	local slots, attach_target = slots_for_entity(player, ent, creature)
	local pref_id, pref_scale = preferred_slot_id(ent, creature)
	if not slot_id and pref_id then
		slot_id = pref_id
	end

	local idx = slot_index_for_player(name, slots, slot_id)
	local slot = slots[idx]
	if slot_id then
		local found, new_idx = slot_by_id(slots, slot_id)
		slot = found
		idx = new_idx
		hashimon._carry_slot_idx[name] = idx
	end
	slot = apply_carry_scale(slot, pref_scale)

	local existing = hashimon.carries[name]
	local saved
	if existing and existing.obj == obj and existing.saved then
		-- Re-slotting same baby: keep original props and detach first.
		saved = existing.saved
		obj:set_detach()
		if saved.visual_size then
			obj:set_properties({
				visual_size = saved.visual_size,
				collisionbox = ZERO_COLLISION,
				physical = false,
			})
		end
	else
		local props = obj:get_properties()
		saved = {
			visual_size = props and props.visual_size,
			collisionbox = props and props.collisionbox,
			physical = props and props.physical,
			nametag = obj:get_nametag_attributes(),
		}
	end

	apply_carry_attach(player, obj, ent, slot, attach_target)

	hashimon.carries[name] = {
		obj = obj,
		ent = ent,
		creature = creature,
		slot = slot.id,
		slot_idx = idx,
		saved = saved,
		attach_target = attach_target,
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

	local slots = slots_for_entity(player, ent, carry.creature)
	local slot_def = select(1, slot_by_id(slots, carry.slot))
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

	local ent = carry.ent
	local slots, attach_target = slots_for_entity(player, ent, carry.creature)
	dir = (dir or "next"):lower()
	local idx = carry.slot_idx or 1
	-- Remap idx if slots list changed (e.g. body with restricted slots).
	local cur = select(1, slot_by_id(slots, carry.slot))
	if cur and cur.id == carry.slot then
		_, idx = slot_by_id(slots, carry.slot)
	elseif idx < 1 or idx > #slots then
		idx = 1
	end
	if dir == "prev" then
		idx = idx - 1
		if idx < 1 then
			idx = #slots
		end
	else
		idx = idx + 1
		if idx > #slots then
			idx = 1
		end
	end

	hashimon._carry_slot_idx[name] = idx
	local slot = slots[idx]
	local _, pref_scale = preferred_slot_id(ent, carry.creature)
	slot = apply_carry_scale(slot, pref_scale)

	local obj = carry.obj
	obj:set_detach()

	-- Restore base visual_size so apply_carry_attach scales once (not compound).
	if carry.saved and carry.saved.visual_size then
		obj:set_properties({
			visual_size = carry.saved.visual_size,
			collisionbox = ZERO_COLLISION,
			physical = false,
		})
	end

	apply_carry_attach(player, obj, ent, slot, attach_target)
	carry.slot = slot.id
	carry.slot_idx = idx
	carry.attach_target = attach_target

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
			"[Hashimon] Cargando en %s — Shift+Z posición, Shift+Space soltar.",
			result or "?"
		))
	else
		core.chat_send_player(name, "[Hashimon] " .. carry_err_msg(result))
	end
	return true
end

function hashimon.step_carried(self, _dtime)
	if not self._carry_anim_set then
		local slot_id = nil
		if self.carried_by and hashimon.carries and hashimon.carries[self.carried_by] then
			slot_id = hashimon.carries[self.carried_by].slot
		end
		play_carry_anim(self, creature_from(self), slot_id)
		self._carry_anim_set = true
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

	if sub == "rot" then
		local x_s, y_s, z_s = tostring(rest or ""):match("^%S+%s+(%S+)%s+(%S+)%s+(%S+)$")
		local x, y, z = tonumber(x_s), tonumber(y_s), tonumber(z_s)
		if not x or not y or not z then
			return false, "Usage: /hashimon carry rot <x> <y> <z>  (mientras cargas; °)"
		end
		local ok, slot = hashimon.apply_carry_rot(player, { x = x, y = y, z = z })
		if not ok then
			if slot == "none" then
				return false, "Primero carga un baby."
			end
			return false, "No se pudo aplicar rot (" .. tostring(slot) .. ")."
		end
		local r = slot.rot
		return true, string.format(
			"carry rot = { x=%.0f, y=%.0f, z=%.0f }  — pega en carry_view.rot (slot %s)",
			r.x, r.y, r.z, tostring(slot.id)
		)
	end

	if sub == "seat" then
		local x_s, y_s, z_s = tostring(rest or ""):match("^%S+%s+(%S+)%s+(%S+)%s+(%S+)$")
		local x, y, z = tonumber(x_s), tonumber(y_s), tonumber(z_s)
		if not x or not y or not z then
			return false, "Usage: /hashimon carry seat <x> <y> <z>  (mientras cargas; set_attach)"
		end
		local ok, slot = hashimon.apply_carry_seat(player, { x = x, y = y, z = z })
		if not ok then
			if slot == "none" then
				return false, "Primero carga un baby."
			end
			return false, "No se pudo aplicar seat (" .. tostring(slot) .. ")."
		end
		local s = slot.seat
		return true, string.format(
			"carry seat = { x=%.2f, y=%.2f, z=%.2f }  — pega en by_slot.%s.seat",
			s.x, s.y, s.z, tostring(slot.id)
		)
	end

	local carry = hashimon.carries[name]
	local slots
	if carry and carry.obj and carry.obj:get_luaentity() then
		slots = slots_for_entity(player, carry.ent, carry.creature)
	else
		slots = carry_slots_for(player)
	end
	for _, slot in ipairs(slots) do
		if sub == slot.id or sub == slot.label:gsub(" ", "_") then
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
			"Cargando en %s — Shift+Z posición, Shift+Space soltar.",
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
	hashimon._carry_key_held[name] = nil
end)

-- Keybinds (Luanti only exposes control bits — not raw letters):
--   Shift+Z  (sneak+zoom)  → carry next   — only while carrying
--   Shift+Space (sneak+jump) → carry off  — only while carrying
-- Rising edge; ignored when mounted / yeeting / ritual.
hashimon.carry_keybind_enabled = true
hashimon._carry_key_held = hashimon._carry_key_held or {}

core.register_globalstep(function(_dtime)
	if not hashimon.carry_keybind_enabled then
		return
	end
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local carry = hashimon.carries[name]
		local ctrl = player:get_player_control()
		local held = hashimon._carry_key_held[name] or {}

		local next_combo = ctrl.sneak and ctrl.zoom and not ctrl.aux1
		local off_combo = ctrl.sneak and ctrl.jump and not ctrl.aux1
			and not ctrl.left and not ctrl.right and not ctrl.zoom

		local next_edge = next_combo and not held.next
		local off_edge = off_combo and not held.off
		hashimon._carry_key_held[name] = { next = next_combo, off = off_combo }

		if not carry or not carry.obj or not carry.obj:get_luaentity() then
			-- Binds only apply while a baby is attached.
		elseif hashimon.mounts and hashimon.mounts[name] then
			-- Mount owns jump / mobility.
		elseif hashimon._impact_flights and hashimon._impact_flights[name] then
			-- Yeeting.
		elseif hashimon._evolve_rituals and hashimon._evolve_rituals[name] then
			-- Ritual in progress.
		elseif off_edge then
			local ok = hashimon.uncarry(player, true)
			if ok then
				core.chat_send_player(name, "[Hashimon] Baby suelto (Shift+Space).")
			end
		elseif next_edge then
			local ok, label = hashimon.cycle_carry_slot(player, "next")
			if ok then
				core.chat_send_player(name, "[Hashimon] Posición: " .. tostring(label) .. " (Shift+Z).")
			end
		end
	end
end)

core.log("action", "[hashimon_entities] baby_carry loaded (Bob Socket.Carry.* / Sam fallback; Shift+Z next, Shift+Space off)")
