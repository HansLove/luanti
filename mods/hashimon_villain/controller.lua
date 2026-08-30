-- Controller mode: human (admin possessed), ai (brain/LLM), idle (stand still).

hashimon_villain = hashimon_villain or {}

hashimon_villain.CONTROLLER_HUMAN = "human"
hashimon_villain.CONTROLLER_AI = "ai"
hashimon_villain.CONTROLLER_IDLE = "idle"

function hashimon_villain.init_controller(self, mode)
	self.controller_mode = mode or hashimon_villain.CONTROLLER_AI
	self.possessor = nil
end

function hashimon_villain.set_controller_mode(self, mode)
	if mode ~= hashimon_villain.CONTROLLER_HUMAN
		and mode ~= hashimon_villain.CONTROLLER_AI
		and mode ~= hashimon_villain.CONTROLLER_IDLE
	then
		return false
	end
	self.controller_mode = mode
	return true
end

function hashimon_villain.is_human_controlled(self)
	return self.possessor ~= nil or self.controller_mode == hashimon_villain.CONTROLLER_HUMAN
end

function hashimon_villain.is_ai_controlled(self)
	if hashimon_villain.is_human_controlled(self) then
		return false
	end
	return self.controller_mode == hashimon_villain.CONTROLLER_AI
end
