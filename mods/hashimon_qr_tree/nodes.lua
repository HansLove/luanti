-- High-contrast QR module nodes (matte, opaque — scannable from above).

core.register_node("hashimon_qr_tree:dark", {
	description = "QR Module (dark)",
	tiles = { { name = "default_snow.png", color = "#101010" } },
	groups = { cracky = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1 },
	paramtype = "light",
	sunlight_propagates = false,
	is_ground_content = false,
})

core.register_node("hashimon_qr_tree:light", {
	description = "QR Module (light)",
	tiles = { { name = "default_snow.png", color = "#F0F0F0" } },
	groups = { cracky = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1 },
	paramtype = "light",
	sunlight_propagates = false,
	is_ground_content = false,
})
