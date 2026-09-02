-- Hashimon canonical bone names (Arm.L, Socket.Head, …) ↔ Sam / player_api
-- (Body, Arm_Left, …). New skins and wearables are authored in Hashimon;
-- resolve_bone translates only when the attach parent is the MTG player mesh.

hashimon = hashimon or {}

--- Sam / character.b3d aliases for Hashimon semantic bones.
--- Socket.Mount has no Sam equivalent (riders attach to creatures, not the player).
hashimon.BONE_ALIAS_SAM = {
	Root = "",
	Torso = "Body",
	Head = "Head",
	["Arm.L"] = "Arm_Left",
	["Arm.R"] = "Arm_Right",
	["Leg.L"] = "Leg_Left",
	["Leg.R"] = "Leg_Right",
	["Socket.Head"] = "Head",
	["Socket.Chest"] = "Body",
	["Socket.Back"] = "Body",
	["Socket.Shoulder"] = "Arm_Right",
}

--- Proximal base for chain segments: Arm.R.2 → Arm.R, Spine.01 → Spine.
--- Numbered suffixes (.2, .01) are Hashimon-only; Sam maps the proximal bone.
local function proximal_base(name)
	if type(name) ~= "string" or name == "" then
		return name
	end
	-- Strip trailing .N or .NN numeric segments (Arm.R.2, Spine.01, Arm.R.3).
	local base = name:match("^(.-)%.%d+$")
	while base do
		name = base
		base = name:match("^(.-)%.%d+$")
	end
	return name
end

--- Resolve a Hashimon bone name for a mesh target.
--- @param name string canonical Hashimon name (e.g. "Arm.L", "Arm.R.2", "Socket.Mount")
--- @param target "hashimon"|"sam" default "hashimon"
--- @return string bone string for set_attach / set_bone_override ("" = entity origin)
function hashimon.resolve_bone(name, target)
	if name == nil or name == false then
		return ""
	end
	name = tostring(name)
	if name == "" then
		return ""
	end
	target = target or "hashimon"
	if target == "hashimon" then
		return name
	end
	if target ~= "sam" then
		return name
	end

	local aliases = hashimon.BONE_ALIAS_SAM
	if aliases[name] ~= nil then
		return aliases[name]
	end

	local base = proximal_base(name)
	if base ~= name then
		if aliases[base] ~= nil then
			return aliases[base]
		end
		-- Chain segment with no Sam alias: fall to proximal (Spine.01 → Spine).
		return base
	end

	-- Unknown Sam mapping: keep canonical name (may fail attach if bone missing).
	return name
end

local ZERO = { x = 0, y = 0, z = 0 }

--- Attach `child` to `parent` at a Hashimon socket/bone name.
--- @param parent ObjectRef
--- @param socket_name string Hashimon bone (e.g. "Socket.Back", "Arm.R")
--- @param child ObjectRef
--- @param seat table|nil set_attach position
--- @param rot table|nil set_attach rotation
--- @param target "hashimon"|"sam"|nil mesh convention of parent
--- @param forced_visible boolean|nil show attached child in first person (default false)
--- @return boolean success
function hashimon.attach_to_socket(parent, socket_name, child, seat, rot, target, forced_visible)
	if not parent or not child or not parent.set_attach or not child.set_attach then
		return false
	end
	local bone = hashimon.resolve_bone(socket_name, target or "hashimon")
	child:set_attach(parent, bone, seat or ZERO, rot or ZERO, forced_visible == true)
	return true
end
