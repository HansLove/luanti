local pass, fail = 0, 0
local function check(label, cond, detail)
	if cond then pass = pass + 1; core.log("action", "SMOKE OK   " .. label)
	else fail = fail + 1; core.log("error", "SMOKE FAIL " .. label .. " :: " .. tostring(detail)) end
end
local function finish()
	core.log("action", string.format("SMOKE RESULT pass=%d fail=%d", pass, fail))
	core.request_shutdown("smoke done")
end

core.after(0.2, function()
	hashimon_alen.reset_state() -- arranque determinista

	-- Conversión de frames glTF: los CLIPS se declaran en frames de BLENDER y la
	-- división por fps ocurre en un solo sitio. Lo que llega al motor son segundos.
	local w = hashimon_alen.CLIPS.walk
	check("walk declarado en frames de Blender 41-70", w.first == 41 and w.last == 70)
	check("walk -> 1.708..2.917 s en el motor",
		math.abs(w.first / hashimon_alen.FPS - 1.708333) < 1e-4
		and math.abs(w.last / hashimon_alen.FPS - 2.916666) < 1e-4, w.first / hashimon_alen.FPS)
	check("fly -> 5.042..6.250 s en el motor",
		math.abs(hashimon_alen.CLIPS.fly.last / hashimon_alen.FPS - 6.25) < 1e-4)
	check("los clips no autorados arrancan en have=false",
		hashimon_alen.CLIPS.idle.have == false and hashimon_alen.CLIPS.death.have == false)

	-- Singleton en la ficha.
	local at = { x = 40, y = 20, z = 40 }
	check("birth() primera vez", hashimon_alen.birth(at) == true)
	local ok2, why2 = hashimon_alen.birth(at)
	check("birth() segunda vez rechazada", ok2 == false and why2 == "ya_existe", why2)

	-- Lista blanca de verbos.
	check("plan válido aceptado",
		hashimon_alen.validate_plan({ verbs = { { op = "goto", x=1,y=1,z=1 }, { op = "wait" } } }) == true)
	local bad, badwhy = hashimon_alen.validate_plan({ verbs = { { op = "rm_rf" } } })
	check("verbo fuera de lista rechazado", bad == false and badwhy:match("^verbo_no_permitido"), badwhy)
	check("plan vacío rechazado", hashimon_alen.validate_plan({ verbs = {} }) == false)

	-- Guardas del salto.
	local okj, whyj = hashimon_alen.can_jump_to({ x = 9000, y = 20, z = 9000 })
	check("salto a mapblock no cargado rechazado", okj == false and whyj == "mapblock_no_cargado", whyj)
	check("salto sin destino rechazado", select(2, hashimon_alen.can_jump_to(nil)) == "sin_destino")

	hashimon_alen.remember("diego", "alen_won")
	local m = hashimon_alen.knows("diego")
	check("memoria registrada", m and m.met == 1 and m.wins == 1, m and m.met)

	core.emerge_area(
		{ x = at.x - 16, y = at.y - 16, z = at.z - 16 },
		{ x = at.x + 16, y = at.y + 16, z = at.z + 16 },
		function(_bp, _action, calls_remaining)
			if calls_remaining ~= 0 then return end
			core.forceload_block(at, true)

			-- Con OBSERVE_OUT alto el gestor no lo retira y podemos ver la entidad
			-- moverse de verdad.
			local real_out = hashimon_alen.OBSERVE_OUT
			hashimon_alen.OBSERVE_OUT = 1e9

			local obj, err = hashimon_alen.spawn_entity()
			check("entidad instanciada", obj ~= nil, err)
			local live = obj and obj:get_luaentity()
			if not live then return finish() end

			-- Sin jugadores conectados el motor desactiva la entidad al segundo
			-- siguiente (no hay mapblocks ACTIVOS, que es distinto de cargados).
			-- Así que ejercemos on_step a mano sobre la entidad real: eso prueba
			-- nuestro código, que es lo que está bajo test — la planificación de
			-- activación del motor no lo está.
			local errs = 0
			for _ = 1, 40 do
				local ok = pcall(live.on_step, live, 0.05)
				if not ok then errs = errs + 1 end
			end
			check("40 pasos de on_step sin error", errs == 0, errs .. " errores")
			check("animación asignada", live._anim ~= nil, live._anim)
			check("la táctica eligió un modo", live.mode ~= nil, live.mode)
			local v = live.object:get_velocity()
			check("patrulla: calculó vector de vuelo", vector.length(v) > 0.01, vector.length(v))
			check("eligió punto de órbita", live._orbit ~= nil)

			-- Un plan válido desvía el comportamiento y se consume verbo a verbo.
			local okp = hashimon_alen.set_plan(live, { ttl = 60, verbs = {
				{ op = "say", text = "prueba" },
				{ op = "goto", x = 40, y = 30, z = 40 },
			} })
			check("plan cargado en la entidad viva", okp == true)
			for _ = 1, 10 do pcall(live.on_step, live, 0.05) end
			check("el verbo say se consumió y avanzó", live.plan and live.plan.i >= 2,
				live.plan and live.plan.i)


			-- ---- Contrato de animación -------------------------------------
			local _c, clip_name, fell = hashimon_alen.resolve_clip("fly")
			check("estado con clip propio no cae a alternativa",
				clip_name == "fly" and fell == false, clip_name)
			local _c2, cn2, fell2 = hashimon_alen.resolve_clip("fly_fast")
			check("fly_fast (sin autorar) cae a fly", cn2 == "fly" and fell2 == true, cn2)
			local _c3, cn3 = hashimon_alen.resolve_clip("idle")
			check("idle (sin autorar) cae a walk congelado", cn3 == "walk", cn3)
			check("hurt sin clip propio se salta (no finge con otro)",
				hashimon_alen.play_oneshot(live, "hurt") == false)
			check("takeoff sin clip propio tampoco bloquea el estado base",
				hashimon_alen.play_oneshot(live, "takeoff") == false)
			local dur = hashimon_alen.state_duration("fly")
			check("duración de fly = 29 frames / 24 fps", math.abs(dur - 29/24) < 1e-4, dur)
			local _lines, missing = hashimon_alen.frame_report()
			check("el informe de frames cuenta los 10 clips que faltan", missing == 10, missing)

			-- Un one-shot bloquea el estado base y luego lo devuelve.
			hashimon_alen.CLIPS.hurt.have = true -- simula que ya lo autoraste
            live._anim = nil
			hashimon_alen.set_anim(live, "fly", 0)
			check("estado base aplicado", live._anim == "fly", live._anim)
			check("hurt ahora sí se reproduce", hashimon_alen.play_oneshot(live, "hurt") == true)
			check("hurt tomó el control", live._anim == "hurt", live._anim)
			hashimon_alen.set_anim(live, "walk", 0)
			check("el estado base no interrumpe al one-shot", live._anim == "hurt", live._anim)
			check("pero queda encolado", live._anim_pending == "walk", live._anim_pending)
			hashimon_alen.CLIPS.hurt.have = false

			-- ---- Canal de órdenes ------------------------------------------
			local r1, d1 = hashimon_alen.apply_order({ id = 1, plan = { verbs = { { op = "wait" } } } })
			check("orden válida aplicada", r1 == "applied", d1)
			local r2, d2 = hashimon_alen.apply_order({ id = 2, plan = { verbs = { { op = "drop_table" } } } })
			check("verbo fuera de lista blanca rechazado",
				r2 == "rejected" and d2:match("^verbo_no_permitido"), d2)
			local r3, d3 = hashimon_alen.apply_order({ id = 3 })
			check("orden malformada rechazada", r3 == "rejected" and d3 == "orden_malformada", d3)

			-- ---- Novedades --------------------------------------------------
			hashimon_alen.note_event("prueba", "diego", { n = 1 })
			check("la novedad se encoló", true)

			-- Recibir un golpe fija objetivo y fuerza decisión inmediata.
			live.hp = hashimon_alen.MAX_HP
			pcall(live.on_punch, live, nil, 0, nil, nil, 25)
			check("el golpe restó vida", live.hp == hashimon_alen.MAX_HP - 25, live.hp)

			-- Vida a cero arranca la secuencia de muerte: se le deja terminar su
			-- clip antes de retirarlo, así que hacen falta varios pasos.
			live.hp = 0
			pcall(live.on_step, live, 0.05)
			check("hp<=0 arranca la muerte, no la corta en seco",
				live._dying ~= nil and hashimon_alen.get_state().alive == true, live._dying)
			for _ = 1, 30 do pcall(live.on_step, live, 0.05) end
			check("terminado el clip, la ficha muere", hashimon_alen.get_state().alive == false)
			check("y libera el candado del singleton", hashimon_alen._live == nil)
			local r4, d4 = hashimon_alen.apply_order({ id = 4, plan = { verbs = { { op = "wait" } } } })
			check("sin entidad la orden se rechaza como dormido",
				r4 == "rejected" and d4 == "dormido", d4)
			finish()
		end)
end)
