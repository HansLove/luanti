-- Lua port of encubation-website/src/lib/compiler.ts + procedural-core.ts.
--
-- Must stay byte-for-byte in sync with those two files: same nibble positions,
-- same math, same trait-list order. This is what makes "colores adaptados"
-- true across runtimes — a Hashimon looks like the same creature in the portal
-- preview and in Luanti because both derive hue/ramp from the identical DNA
-- with the identical algorithm.
--
-- Ported 2026-08-17, from compiler.ts as it stood after fixing the
-- hue.exact/65535 vs. palette-mapped-hue bug (see hue.degrees in compiler.ts).
-- This port starts from the CORRECT formula directly — there is no bug to
-- carry over here.

hashimon = hashimon or {}

-- ---------------------------------------------------------------------------
-- Trait vocabularies — order matters, must match compiler.ts exactly.
-- ---------------------------------------------------------------------------

local BUILDS = { "delicate", "lean", "balanced", "stocky", "muscular", "bulbous", "angular", "round" }
local SIZES = { "diminutive", "small", "medium", "large", "huge", "massive" }
local MARKINGS = { "none", "stripes", "spots", "patches", "bands", "rings", "swirls", "gradients" }
local MATERIALS = { "flesh", "fur", "scale", "feather", "chitin", "stone", "metal", "crystal" }

-- Same bands as compiler.ts's ELEMENT_PALETTES. Keys use the accented Spanish
-- spelling ("eléctrico", "sueño") to match compiler.ts's TYPES array exactly —
-- species.json's `type` field must use these same spellings.
local ELEMENT_PALETTES = {
	fuego = { 0, 30 },
	agua = { 180, 240 },
	["eléctrico"] = { 45, 65 },
	tierra = { 30, 60 },
	aire = { 180, 210 },
	astro = { 240, 300 },
	pixel = { 0, 360 },
	["sueño"] = { 240, 300 },
	magia = { 270, 330 },
	metal = { 0, 20 },
	robot = { 0, 20 },
	plasma = { 350, 20 },
	vegetal = { 100, 150 },
	hongo = { 280, 340 },
	mental = { 200, 260 },
}

-- ---------------------------------------------------------------------------
-- DNA nibble helpers — mirrors compiler.ts's `DNA` object.
-- ---------------------------------------------------------------------------

local function dna_at(dna, position)
	return tonumber(dna:sub(position, position), 16) or 0
end

local function dna_window(dna, position, length)
	return tonumber(dna:sub(position, position + length - 1), 16) or 0
end

local function dna_pick(dna, position, length, list)
	local span = 16 ^ length
	local i = math.floor((dna_window(dna, position, length) / span) * #list)
	if i > #list - 1 then i = #list - 1 end
	if i < 0 then i = 0 end
	return list[i + 1] -- Lua 1-indexed
end

local function dna_sine(dna, position, length)
	local norm = dna_window(dna, position, length) / (16 ^ length)
	return math.sin(norm * math.pi * 2) * 0.5 + 0.5
end

local function dna_cosine(dna, position, length)
	local norm = dna_window(dna, position, length) / (16 ^ length)
	return math.cos(norm * math.pi * 2) * 0.5 + 0.5
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- ---------------------------------------------------------------------------
-- HSL -> hex — exact port of compiler.ts's hslToHex.
-- ---------------------------------------------------------------------------

function hashimon.hsl_to_hex(h, s, l)
	local sNorm = s / 100
	local lNorm = l / 100
	local c = (1 - math.abs(2 * lNorm - 1)) * sNorm
	local x = c * (1 - math.abs((h / 60) % 2 - 1))
	local m = lNorm - c / 2

	local r, g, b = 0, 0, 0
	if h < 60 then r, g, b = c, x, 0
	elseif h < 120 then r, g, b = x, c, 0
	elseif h < 180 then r, g, b = 0, c, x
	elseif h < 240 then r, g, b = 0, x, c
	elseif h < 300 then r, g, b = x, 0, c
	else r, g, b = c, 0, x
	end

	local function to_hex(v)
		local n = math.floor((v + m) * 255 + 0.5)
		if n < 0 then n = 0 end
		if n > 255 then n = 255 end
		return string.format("%02x", n)
	end

	return "#" .. to_hex(r) .. to_hex(g) .. to_hex(b)
end

-- ---------------------------------------------------------------------------
-- compile(): dna + elementType -> look. elementType is fixed (from
-- species.json), matching compiler.ts's `species.type || DNA.pick(...)` for
-- genesis creatures where the type is always fixed by species.
-- ---------------------------------------------------------------------------

--- @param dna string 64-hex creature DNA
--- @param element_type string e.g. "fuego", "eléctrico" — must match ELEMENT_PALETTES keys
function hashimon.compile_look(dna, element_type)
	if not dna or #dna < 52 then
		return nil
	end

	-- [14]-[16]: Saturation (sine)
	local saturation = math.floor(dna_sine(dna, 14, 3) * 100 + 0.5)
	-- [17]-[19]: Lightness (sine)
	local lightness = math.floor(dna_sine(dna, 17, 3) * 100 + 0.5)

	-- [10]-[13]: Exact hue window, mapped into the element's palette band
	local palette = ELEMENT_PALETTES[element_type] or { 0, 360 }
	local hue_normalized = dna_window(dna, 10, 4) / 65535
	local base_hue = palette[1] + hue_normalized * (palette[2] - palette[1])
	local final_hue = (base_hue % 360 + 360) % 360

	-- [20]-[22]: Accent offset (cosine), ±60° from final_hue
	local accent_offset = dna_cosine(dna, 20, 3) * 120 - 60
	local accent_hue = (final_hue + accent_offset) % 360
	if accent_hue < 0 then accent_hue = accent_hue + 360 end

	-- [23]-[24]: Accent saturation (sine)
	local accent_saturation = math.floor(dna_sine(dna, 23, 2) * 100 + 0.5)

	-- [37],[41],[45],[49]: build, size, markings, material
	local build = dna_pick(dna, 37, 1, BUILDS)
	local size = dna_pick(dna, 41, 1, SIZES)
	local markings = dna_pick(dna, 45, 1, MARKINGS)
	local material = dna_pick(dna, 49, 1, MATERIALS)

	return {
		hue = final_hue,
		saturation = saturation,
		lightness = lightness,
		accentHue = accent_hue,
		accentSaturation = accent_saturation,
		build = build,
		size = size,
		markings = markings,
		material = material,
	}
end

-- ---------------------------------------------------------------------------
-- deriveColorRamp(): look -> 5-tone ramp. Mirrors procedural-core.ts exactly
-- (already using the palette-mapped hue, matching the compiler.ts fix).
-- ---------------------------------------------------------------------------

local function tone(h, s, l)
	return { h = h, s = s, l = l, hex = hashimon.hsl_to_hex(h, s, l) }
end

--- @param look table as returned by hashimon.compile_look
function hashimon.derive_color_ramp(look)
	local H, S, L = look.hue, look.saturation, look.lightness
	local AH, AS = look.accentHue, look.accentSaturation

	return {
		shadow = tone(H, S, clamp(L - 25, 12, 100)),
		base = tone(H, S, L),
		highlight = tone(H, clamp(S - 10, 0, 100), clamp(L + 18, 0, 92)),
		marking = tone(H, clamp(S + 15, 0, 100), clamp(L - 22, 10, 100)),
		accent = tone(AH, AS, 50),
	}
end

-- ---------------------------------------------------------------------------
-- Material -> surface (mirrors procedural-core.ts's materialSurface, minus
-- the roughness/metalness fields Luanti's engine doesn't expose per-entity;
-- kept for parity/logging and future PBR support).
-- ---------------------------------------------------------------------------

function hashimon.material_bump_scale(material)
	if material == "crystal" or material == "metal" then return 0.55 end
	if material == "stone" then return 1.15 end
	if material == "fur" or material == "feather" or material == "flesh" then return 0.5 end
	if material == "scale" or material == "chitin" then return 1.0 end
	return 0.75
end
