-- Procedural per-bone proportions.
--
-- hashimon_core hands down ABSTRACT multipliers ({head = 1.14, torso = 0.97, …}).
-- This file is the only place that knows a skeleton calls that part "Head". A
-- body declares its own mapping via `bones = { head = "Head", ... }`; a body that
-- declares none is left alone, which is how packs whose meshes have meaningless
-- bone names (paleotest's `cube.014`, dmobs' `Cube.004`) opt out for now.
--
-- Why bone scaling rather than swapping meshes: it needs no new assets, carries
-- no licence, composes with the running animation, and cannot land somewhere
-- absurd the way an attached prop can. The worst failure is a slightly odd
-- silhouette, not a box in the sky.

hashimon_bodies = hashimon_bodies or {}

--- Every limb bone a skeleton might expose. Missing ones are skipped, so a
--- two-legged bird and a four-legged wolf share one declaration shape.
-- Extremidades que reciben el multiplicador `limbLength`. Añadir una clave es
-- seguro: scale_bone() ignora las que un cuerpo no declare.
-- `limb_m_*` es el par medio de los hexápodos (docs/SKELETON_STANDARD_V1.md §1.3).
local LIMB_KEYS = { "arm_l", "arm_r", "leg_l", "leg_r", "wing_l", "wing_r",
	"limb_m_l", "limb_m_r", "fin_l", "fin_r", "fin_t" }

--- A scale is "no change" if all three axes sit this close to 1.0.
local NEUTRAL = 0.001

function hashimon_bodies.apply_proportions(self, morph)
	local obj = self.object
	if not obj or not morph or not morph.proportions then
		return 0
	end
	local body = hashimon.get_body and hashimon.get_body(morph.body_id)
	local bones = body and body.bones
	if not bones then
		return 0 -- skeleton has no semantic bone names; nothing safe to do
	end

	local p = morph.proportions
	local applied = 0

	--- @param vec table per-axis scale, {x=,y=,z=}
	local function scale_bone(bone_name, vec)
		if not bone_name or not vec then
			return
		end
		if math.abs(vec.x - 1) < NEUTRAL
			and math.abs(vec.y - 1) < NEUTRAL
			and math.abs(vec.z - 1) < NEUTRAL then
			return
		end
		-- absolute = false: per-axis MULTIPLICATION against the animated scale,
		-- so the override rides the walk cycle instead of fighting it.
		obj:set_bone_override(bone_name, {
			scale = { vec = vector.new(vec.x, vec.y, vec.z), absolute = false },
		})
		applied = applied + 1
	end

	scale_bone(bones.head, p.head)
	scale_bone(bones.neck, p.neck)
	scale_bone(bones.torso, p.torso)
	scale_bone(bones.tail, p.tail)
	for _, key in ipairs(LIMB_KEYS) do
		scale_bone(bones[key], p.limbs)
	end

	return applied
end

--- Clear every override this system set, so a body can be re-shaped without the
--- previous multipliers compounding.
function hashimon_bodies.clear_proportions(self, morph)
	local obj = self.object
	if not obj then
		return
	end
	local body = hashimon.get_body and hashimon.get_body(morph and morph.body_id)
	local bones = body and body.bones
	if not bones then
		return
	end
	for _, bone in pairs(bones) do
		obj:set_bone_override(bone, nil)
	end
end
