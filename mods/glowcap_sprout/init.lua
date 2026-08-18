-- Meshy AI 3D Hashimon: glowcap_sprout
-- Auto-generated Luanti mod
-- GLB model embedded as base64 or copied directly

local modpath = minetest.get_modpath("glowcap_sprout")
local model_file = "glowcap_sprout.glb"
local model_path = modpath .. "/" .. model_file

-- Register entity (will display GLB mesh in Luanti client)
minetest.register_entity("glowcap_sprout:creature", {
  initial_properties = {
    visual = "mesh",
    mesh = model_file,
    textures = {"white.png"},
    visual_size = {x = 1, y = 1, z = 1},
    backface_culling = true,
    use_texture_alpha = false,
  },

  on_activate = function(self)
    -- Load mesh
    local props = self.object:get_properties()
    props.mesh = model_file
    self.object:set_properties(props)
  end,

  on_step = function(self, dtime)
    -- Gentle rotation animation
    local rot = self.object:get_rotation()
    self.object:set_rotation({
      x = rot.x,
      y = (rot.y + dtime * 0.3) % (math.pi * 2),
      z = rot.z
    })
  end,

  on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
    self.object:remove()
  end,
})

-- Register item (can be placed in world)
minetest.register_item(":glowcap_sprout:model", {
  description = "Meshy glowcap_sprout",
  inventory_image = "default_cobble.png",
  on_place = function(itemstack, placer, pointed_thing)
    if pointed_thing.type == "node" then
      local pos = minetest.get_pointed_thing_position(pointed_thing, true)
      minetest.add_entity(pos, "glowcap_sprout:creature")
      itemstack:take_item()
      return itemstack
    end
  end,
})

-- Chat command to spawn
minetest.register_chatcommand("spawn_glowcap_sprout", {
  description = "Spawn Meshy glowcap_sprout in front of you",
  privs = {},
  func = function(name, param)
    local player = minetest.get_player_by_name(name)
    if not player then
      return false, "Player not found"
    end

    local pos = player:get_pos()
    pos.y = pos.y + 2  -- Spawn above player

    local look_dir = player:get_look_dir()
    pos.x = pos.x + look_dir.x * 3
    pos.z = pos.z + look_dir.z * 3

    minetest.add_entity(pos, "glowcap_sprout:creature")
    return true, "Spawned Meshy glowcap_sprout at " .. minetest.pos_to_string(pos)
  end
})

minetest.log("action", "[glowcap_sprout] Loaded - Use /spawn_glowcap_sprout")
