-- Morphology spawn queue + roster entry point.

hashimon = hashimon or {}

hashimon._morph_setup_queue = hashimon._morph_setup_queue or {}

function hashimon.enqueue_morph_setup(owner, creature, morph)
	table.insert(hashimon._morph_setup_queue, {
		owner = owner,
		creature = creature,
		morph = morph,
	})
end

function hashimon.dequeue_morph_setup()
	return table.remove(hashimon._morph_setup_queue, 1)
end

--- Spawn a canonical Creatura body from compiled morphology.
function hashimon.spawn_morph_creature(pos, creature, owner)
	if not hashimon.morphology_available or not hashimon.compile_morphology then
		return nil
	end
	local morph = hashimon.compile_morphology(creature)
	if not morph or not morph.body_id then
		return nil
	end
	local entity_name = "hashimon_bodies:" .. morph.body_id
	if not core.registered_entities[entity_name] then
		return nil
	end
	hashimon.enqueue_morph_setup(owner, creature, morph)
	local obj = core.add_entity(pos, entity_name)
	if not obj then
		hashimon.dequeue_morph_setup()
		return nil
	end
	return obj
end
