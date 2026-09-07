-- Comprueba que `appearance.lua` da EXACTAMENTE lo mismo que `appearanceOf` en TypeScript.
-- Los vectores los genera el servidor: api/scripts/gen-wolker-golden.mts. Si tocas una de
-- las dos implementaciones, regenera los vectores y corre esto — un desacuerdo aquí
-- significa que un wolker cambiaría de cuerpo al reconectar.
--
-- Corre dentro de Luanti (mundo de pruebas) o con `lua golden.lua` si hay un `core` mínimo.

local pass, fail = 0, 0
local function check(label, cond, detail)
	if cond then
		pass = pass + 1
	else
		fail = fail + 1
		print("GOLDEN FAIL " .. label .. " :: " .. tostring(detail))
	end
end

local path = (core and core.get_modpath and core.get_modpath("hashimon_wolkers") .. "/test/")
	or "./"
local f = assert(io.open(path .. "appearance_golden.json", "r"))
local raw = f:read("*a")
f:close()

local golden
if core and core.parse_json then
	golden = core.parse_json(raw)
else
	error("golden.lua necesita core.parse_json (correr dentro de Luanti)")
end

check("childDays coincide", hashimon_wolkers.CHILD_DAYS == golden.childDays,
	tostring(hashimon_wolkers.CHILD_DAYS) .. " vs " .. tostring(golden.childDays))

for _, v in ipairs(golden.vectors) do
	local look = hashimon_wolkers.appearance_of(v.id, v.ageDays)
	local label = string.sub(v.id, 1, 8) .. "@" .. v.ageDays .. "d"
	check(label .. " signo", look.sign == v.sign, look.sign .. " vs " .. v.sign)
	check(label .. " etapa", look.stage == v.stage, look.stage .. " vs " .. v.stage)
	check(label .. " modelo", look.model == v.model, look.model .. " vs " .. v.model)
end

print(string.format("GOLDEN RESULT pass=%d fail=%d", pass, fail))
if core and core.request_shutdown then
	core.request_shutdown("golden done")
end
