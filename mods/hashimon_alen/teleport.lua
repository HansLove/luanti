-- El salto de Alen: teletransporte con guarda de proximidad.
--
-- Regla del proyecto: puede saltar, pero NUNCA a unas coordenadas con un jugador
-- cerca. Aparecer encima de alguien no es una mecánica, es un atropello. Todas las
-- comprobaciones viven aquí y se aplican también cuando la orden viene del
-- servidor: el mundo valida, quien pide no decide.

hashimon_alen = hashimon_alen or {}

hashimon_alen.TP_CLEAR_RADIUS = 24   -- ningún jugador a menos de esto del destino
hashimon_alen.TP_HEADROOM = 4        -- nodos de aire libres sobre el destino
hashimon_alen.TP_COOLDOWN = 45       -- segundos entre saltos

local function players_near(pos, radius)
	local r2 = radius * radius
	for _, player in ipairs(core.get_connected_players()) do
		local pp = player:get_pos()
		if pp then
			local dx, dy, dz = pp.x - pos.x, pp.y - pos.y, pp.z - pos.z
			if dx * dx + dy * dy + dz * dz < r2 then
				return player:get_player_name()
			end
		end
	end
	return nil
end

hashimon_alen.players_near = players_near

--- ¿Es legal saltar a `pos`? Devuelve true, o false + el motivo exacto.
--- El motivo viaja de vuelta al servidor en el ack: si el mundo no puede decir
--- "rechacé esto y por esto", el planificador nunca aprende.
function hashimon_alen.can_jump_to(pos)
	if not pos then
		return false, "sin_destino"
	end

	local who = players_near(pos, hashimon_alen.TP_CLEAR_RADIUS)
	if who then
		return false, "jugador_cerca:" .. who
	end

	-- El mapblock tiene que estar cargado o no hay nada que comprobar.
	local node = core.get_node_or_nil(pos)
	if not node then
		return false, "mapblock_no_cargado"
	end

	for i = 0, hashimon_alen.TP_HEADROOM do
		local p = { x = pos.x, y = pos.y + i, z = pos.z }
		local n = core.get_node_or_nil(p)
		if not n then
			return false, "mapblock_no_cargado"
		end
		local def = core.registered_nodes[n.name]
		if def and def.walkable then
			return false, "sin_espacio"
		end
	end

	-- Nada de saltar al vacío: tiene que haber mundo debajo.
	if not hashimon_alen.floor_below(pos, 48) then
		return false, "vacio_debajo"
	end

	if core.is_protected(vector.round(pos), "alen_gregory") then
		return false, "zona_protegida"
	end

	return true
end

local function jump_fx(pos, tint)
	core.add_particlespawner({
		amount = 90,
		time = 0.4,
		minpos = { x = pos.x - 1.5, y = pos.y - 0.5, z = pos.z - 1.5 },
		maxpos = { x = pos.x + 1.5, y = pos.y + 3.0, z = pos.z + 1.5 },
		minvel = { x = -1.5, y = 0.5, z = -1.5 },
		maxvel = { x = 1.5, y = 3.5, z = 1.5 },
		minexptime = 0.5,
		maxexptime = 1.4,
		minsize = 1.5,
		maxsize = 4.0,
		texture = "default_item_smoke.png^[colorize:" .. (tint or "#7C3AED") .. ":180",
		glow = 10,
	})
	core.sound_play("default_break_glass", { pos = pos, gain = 0.7, max_hear_distance = 48 }, true)
end

--- Ejecuta el salto sobre la entidad viva. `visible` decide si se telegrafía:
--- observado se ve (es la firma de Block Jumper), sin observadores es silencioso
--- porque literalmente nadie está mirando.
function hashimon_alen.do_jump(self, target, visible)
	local ok, why = hashimon_alen.can_jump_to(target)
	if not ok then
		return false, why
	end

	local now = core.get_gametime()
	if self._last_jump and now - self._last_jump < hashimon_alen.TP_COOLDOWN then
		return false, "en_enfriamiento"
	end
	self._last_jump = now

	local from = self.object:get_pos()
	if visible ~= false and from then
		jump_fx(from, "#7C3AED")
	end

	self.object:set_velocity({ x = 0, y = 0, z = 0 })
	self.object:set_pos(target)
	hashimon_alen.sync_from_entity(self)

	if visible ~= false then
		jump_fx(target, "#F97316")
	end
	core.log("action", string.format("[alen] salto a (%.0f, %.0f, %.0f)", target.x, target.y, target.z))
	return true
end

--- Salto telegrafiado: carga primero, se va después. Es la versión que usa el
--- comportamiento; /alen jump usa do_jump directo porque ahí queremos verlo ya.
function hashimon_alen.begin_jump(self, dest)
	local ok, why = hashimon_alen.can_jump_to(dest)
	if not ok then
		return false, why
	end
	if self._jump_at then
		return false, "ya_cargando"
	end
	local charge = hashimon_alen.state_duration("jump_charge")
	if charge <= 0 then
		return hashimon_alen.do_jump(self, dest, true)
	end
	hashimon_alen.play_oneshot(self, "jump_charge")
	self._jump_at = core.get_gametime() + charge
	self._jump_dest = dest
	return true
end

--- Se llama cada tick: dispara el salto cargado cuando vence su tiempo.
function hashimon_alen.step_jump(self)
	if not self._jump_at then
		return
	end
	if core.get_gametime() < self._jump_at then
		hashimon_alen.hover_brake(self)
		return
	end
	local dest = self._jump_dest
	self._jump_at, self._jump_dest = nil, nil
	if dest then
		hashimon_alen.do_jump(self, dest, true)
	end
end

--- Busca un destino legal alrededor de `origin`. Prueba `tries` candidatos en un
--- anillo y devuelve el primero que pase todas las guardas, o nil con el último
--- motivo — que es la información útil cuando no encuentra ninguno.
function hashimon_alen.find_jump_target(origin, min_r, max_r, tries)
	local last_why = "sin_intentos"
	for _ = 1, (tries or 12) do
		local angle = math.random() * math.pi * 2
		local r = min_r + math.random() * (max_r - min_r)
		local cand = {
			x = origin.x + math.cos(angle) * r,
			y = origin.y,
			z = origin.z + math.sin(angle) * r,
		}
		local floor = hashimon_alen.floor_below({ x = cand.x, y = cand.y + 30, z = cand.z }, 70)
		if floor then
			cand.y = cand.y + 30 - floor + 12 -- 12 nodos sobre el suelo que encontró
		end
		local ok, why = hashimon_alen.can_jump_to(cand)
		if ok then
			return cand
		end
		last_why = why
	end
	return nil, last_why
end
