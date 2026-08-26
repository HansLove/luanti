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

-- Colour harmony rules. The DNA picks one, and it decides where the secondary
-- and accent hues sit relative to the base hue. This is what makes a palette
-- read as *designed* rather than as a random triple of colours.
--
-- Order matters for TS<->Lua parity: same list, same order, in compiler.ts.
local HARMONIES = {
	{ name = "analogous", secondary = 30, accent = -30 },
	{ name = "complementary", secondary = 180, accent = 180 },
	{ name = "split", secondary = 150, accent = 210 },
	{ name = "triadic", secondary = 120, accent = 240 },
	{ name = "tetradic", secondary = 90, accent = 180 },
	{ name = "monochrome", secondary = 0, accent = 0 },
}

-- Saturation/lightness live in deliberately narrow, flattering bands.
-- The previous code mapped both to the full 0..100, which meant a sine landing
-- near an extreme produced a black, white or washed-out creature. These ranges
-- keep every roll readable and vivid.
local SAT_MIN, SAT_SPAN = 55, 40 -- 55..95
local LIGHT_MIN, LIGHT_SPAN = 42, 22 -- 42..64
local ACCENT_SAT_MIN, ACCENT_SAT_SPAN = 60, 35 -- 60..95
local ACCENT_LIGHT_MIN, ACCENT_LIGHT_SPAN = 45, 18 -- 45..63

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

--- Compile the visual look from DNA alone.
---
--- The elemental type does NOT influence colour. It used to: each element owned
--- a hue band, so every Water Hashimon came out blue and the type, not the
--- individual, decided what you saw. Colour is the *identity* axis and belongs
--- to the creature; the element is a separate axis entirely (see
--- api/docs/ADN_PROPIEDAD_TEORIA_DE_JUEGO.md §8).
---
--- @param dna string 64-hex creature DNA
--- @param element_type string kept for signature compatibility; unused for colour
function hashimon.compile_look(dna, element_type) -- luacheck: ignore element_type
	if not dna or #dna < 52 then
		return nil
	end

	-- [10]-[13]: base hue over the FULL wheel (65,536 values). /65536 rather
	-- than /65535 so the distribution is uniform and 0xFFFF cannot alias to 0.
	local hue = (dna_window(dna, 10, 4) / 65536) * 360

	-- [14]-[16] saturation, [17]-[19] lightness — banded, see constants above.
	local saturation = math.floor(SAT_MIN + dna_sine(dna, 14, 3) * SAT_SPAN + 0.5)
	local lightness = math.floor(LIGHT_MIN + dna_sine(dna, 17, 3) * LIGHT_SPAN + 0.5)

	-- [32]: harmony rule. Nibble [32] was reserved; this is its first use.
	local harmony = dna_pick(dna, 32, 1, HARMONIES)

	local secondary_hue = (hue + harmony.secondary) % 360
	local accent_hue = (hue + harmony.accent) % 360
	if accent_hue < 0 then accent_hue = accent_hue + 360 end

	-- [20]-[22] accent lightness, [23]-[24] accent saturation.
	local accent_lightness =
		math.floor(ACCENT_LIGHT_MIN + dna_cosine(dna, 20, 3) * ACCENT_LIGHT_SPAN + 0.5)
	local accent_saturation =
		math.floor(ACCENT_SAT_MIN + dna_sine(dna, 23, 2) * ACCENT_SAT_SPAN + 0.5)

	-- [37],[41],[45],[49]: build, size, markings, material
	local build = dna_pick(dna, 37, 1, BUILDS)
	local size = dna_pick(dna, 41, 1, SIZES)
	local markings = dna_pick(dna, 45, 1, MARKINGS)
	local material = dna_pick(dna, 49, 1, MATERIALS)

	return {
		hue = hue,
		secondaryHue = secondary_hue,
		harmony = harmony.name,
		saturation = saturation,
		lightness = lightness,
		accentHue = accent_hue,
		accentSaturation = accent_saturation,
		accentLightness = accent_lightness,
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
	local SH = look.secondaryHue or H
	local AH, AS = look.accentHue, look.accentSaturation
	local AL = look.accentLightness or 50

	return {
		shadow = tone(H, S, clamp(L - 25, 12, 100)),
		base = tone(H, S, L),
		highlight = tone(H, clamp(S - 10, 0, 100), clamp(L + 18, 0, 92)),
		-- Markings use the SECONDARY hue, not a darker shade of the base. That
		-- one change is most of what separates "a creature with a palette" from
		-- "a model dipped in one colour".
		marking = tone(SH, clamp(S + 10, 0, 100), clamp(L - 18, 10, 100)),
		accent = tone(AH, AS, AL),
	}
end

--- Luanti texture modifier that recolours a body texture from the ramp.
---
--- Uses [colorizehsl, NOT [colorize. [colorize blends a flat colour over every
--- pixel, which at the ratio this project used (180/255) flattened the eyes,
--- muzzle and fur shading painted into the Animalia textures into one solid
--- slab of colour — the "all-blue dog with no face" problem. [colorizehsl
--- converts to greyscale and tints, so the luminance structure survives and the
--- painted face comes back for free.
--- @param ramp table as returned by hashimon.derive_color_ramp
function hashimon.texture_mod_from_ramp(ramp)
	local base = ramp.base
	-- Luanti wants hue in [-180,180]; standard HSL is [0,360).
	local hue = base.h
	if hue > 180 then hue = hue - 360 end
	-- [colorizehsl lightness is a delta around the greyscale result, where 0 is
	-- no change; our L is absolute HSL lightness centred on 50.
	local light = (base.l - 50) * 2
	if light < -100 then light = -100 elseif light > 100 then light = 100 end
	return string.format("^[colorizehsl:%d:%d:%d",
		math.floor(hue + 0.5), math.floor(base.s + 0.5), math.floor(light + 0.5))
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
