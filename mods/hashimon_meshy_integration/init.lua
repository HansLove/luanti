-- Hashimon × Meshy AI Integration Mod
-- Brings Meshy-generated 3D models into Luanti with Hashimon data binding
--
-- Features:
-- - Register GLB models as Hashimon creatures
-- - Fetch creature stats from API (DNA, HP, ATK, etc.)
-- - Spawn with /hashimon_spawn <dna>
-- - Display stats on right-click
-- - Persist creature ownership

local mod = {}
local modpath = minetest.get_modpath(minetest.get_current_modname())

-- Configuration
local API_URL = os.getenv("HASHIMON_API") or "http://localhost:4000"
local MESH_MOD_PREFIX = "meshy_" -- Mods named: meshy_glowcap_sprout, etc.

-- HTTP request helper (needs async_requests privilege or future async)
local function http_get(url, callback)
  minetest.log("info", "[hashimon_meshy] Fetching: " .. url)
  -- Note: Luanti's http.fetch is async but requires proper handling
  -- For MVP, we do synchronous via curl as fallback
  local cmd = string.format("curl -s '%s'", url)
  local f = io.popen(cmd)
  if f then
    local response = f:read("*a")
    f:close()
    if response and response ~= "" then
      return minetest.parse_json(response)
    end
  end
  return nil
end

-- Fetch creature data from API
function mod.fetch_creature_data(dna)
  local url = API_URL .. "/hashimons?dna=" .. dna
  local data = http_get(url)
  return data
end

-- Register a Meshy-generated creature as entity
function mod.register_meshy_creature(mesh_mod_name, dna, creature_name)
  local mesh_path = mesh_mod_name .. ".glb"
  local entity_name = "hashimon_meshy_integration:" .. mesh_mod_name

  minetest.register_entity(entity_name, {
    initial_properties = {
      visual = "mesh",
      mesh = mesh_path,
      textures = {"white.png"}, -- GLB has embedded textures
      visual_size = {x = 1, y = 1, z = 1},
      backface_culling = true,
      use_texture_alpha = false,

      -- Make it an object, not invisible
      physical = false,
      pointable = true,

      -- For future: collision and HP
      hp_max = 100,
    },

    -- Store creature data
    dna = dna,
    creature_name = creature_name,
    mesh_mod = mesh_mod_name,
    stats = nil, -- Loaded from API on activate

    on_activate = function(self, staticdata)
      -- Load mesh from mod
      local props = self.object:get_properties()
      props.mesh = self.mesh_mod .. ".glb"
      self.object:set_properties(props)

      -- Try to fetch stats from API if we have DNA
      if self.dna and self.dna ~= "" then
        local creature_data = mod.fetch_creature_data(self.dna)
        if creature_data then
          self.stats = creature_data
          -- Update HP from API data
          if creature_data.hp then
            props.hp_max = creature_data.hp
            self.object:set_properties(props)
          end
        end
      end

      -- Store persistent data
      self.object:set_armor_groups({immortal = 1}) -- Don't die from environment
    end,

    on_step = function(self, dtime)
      -- Gentle rotation
      local rot = self.object:get_rotation()
      self.object:set_rotation({
        x = rot.x,
        y = (rot.y + dtime * 0.3) % (math.pi * 2),
        z = rot.z
      })
    end,

    on_rightclick = function(self, clicker)
      if not clicker or not clicker:is_player() then
        return
      end

      -- Display creature info
      local name = clicker:get_player_name()
      local msg = "═══════════════════════════\n"
      msg = msg .. "🦖 " .. self.creature_name .. "\n"
      msg = msg .. "═══════════════════════════\n"

      if self.stats then
        msg = msg .. "DNA: " .. self.dna:sub(1, 12) .. "...\n"
        msg = msg .. "HP: " .. (self.stats.hp or "?") .. "\n"
        msg = msg .. "ATK: " .. (self.stats.atk or "?") .. "\n"
        msg = msg .. "DEF: " .. (self.stats.def or "?") .. "\n"
        msg = msg .. "SPD: " .. (self.stats.spd or "?") .. "\n"
      else
        msg = msg .. "(Stats loading...)\n"
      end

      msg = msg .. "═══════════════════════════\n"
      msg = msg .. "Mesh: " .. self.mesh_mod .. ".glb\n"

      minetest.chat_send_player(name, msg)
    end,

    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
      -- Destroy on punch (for now)
      self.object:remove()
      if puncher and puncher:is_player() then
        minetest.chat_send_player(puncher:get_player_name(), "💥 Creature defeated!")
      end
    end,
  })

  return entity_name
end

-- Auto-detect Meshy mods and register creatures
function mod.auto_register_meshy_mods()
  local mods = minetest.get_modnames()
  for _, modname in ipairs(mods) do
    if modname:sub(1, #MESH_MOD_PREFIX) == MESH_MOD_PREFIX then
      local creature_name = modname:sub(#MESH_MOD_PREFIX + 1)
      minetest.log("action", "[hashimon_meshy] Auto-registering: " .. modname)
      mod.register_meshy_creature(modname, "auto_" .. modname, creature_name)
    end
  end
end

-- Chat commands
minetest.register_chatcommand("hashimon_spawn", {
  description = "Spawn a Meshy Hashimon by mod name or DNA",
  privs = {},
  func = function(name, param)
    local player = minetest.get_player_by_name(name)
    if not player then
      return false, "Player not found"
    end

    if param == "" then
      return false, "Usage: /hashimon_spawn <mesh_mod_name> [dna]"
    end

    local parts = param:split(" ")
    local mesh_mod = parts[1]
    local dna = parts[2] or "preview_" .. mesh_mod

    local pos = player:get_pos()
    pos.y = pos.y + 2

    local entity_name = "hashimon_meshy_integration:" .. mesh_mod
    local ent = minetest.add_entity(pos, entity_name)

    if ent then
      local le = ent:get_luaentity()
      if le then
        le.dna = dna
        le.creature_name = mesh_mod
      end
      return true, "Spawned " .. mesh_mod .. " at " .. minetest.pos_to_string(pos)
    else
      return false, "Failed to spawn entity (mod not loaded?)"
    end
  end,
})

minetest.register_chatcommand("hashimon_list", {
  description = "List available Meshy creatures",
  privs = {},
  func = function(name, param)
    local mods = minetest.get_modnames()
    local creatures = {}

    for _, modname in ipairs(mods) do
      if modname:sub(1, #MESH_MOD_PREFIX) == MESH_MOD_PREFIX then
        table.insert(creatures, modname:sub(#MESH_MOD_PREFIX + 1))
      end
    end

    if #creatures == 0 then
      return true, "No Meshy creatures found. Enable GLB mods first!"
    end

    local msg = "Available creatures:\n"
    for _, c in ipairs(creatures) do
      msg = msg .. "  • " .. c .. " (/hashimon_spawn " .. c .. ")\n"
    end

    return true, msg
  end,
})

-- Auto-register on mod load
minetest.register_on_mods_loaded(function()
  minetest.log("action", "[hashimon_meshy] Scanning for Meshy mods...")
  mod.auto_register_meshy_mods()
end)

minetest.log("action", "[hashimon_meshy] Integration mod loaded")

return mod
