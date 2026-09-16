local MuseumConfig = {
	Levels = {
		{ StartSlot = 1, EndSlot = 12 },
		{ StartSlot = 13, EndSlot = 20 },
	},
}

function MuseumConfig.GetLevelForSlot(SlotId: number): number?
	for LevelNumber, Level in MuseumConfig.Levels do
		if SlotId >= Level.StartSlot and SlotId <= Level.EndSlot then return LevelNumber end
	end
	return nil
end

function MuseumConfig.GetLocalDisplayIndex(SlotId: number): number?
	local LevelNumber = MuseumConfig.GetLevelForSlot(SlotId)
	local Level = LevelNumber and MuseumConfig.Levels[LevelNumber]
	return if Level then SlotId - Level.StartSlot + 1 else nil
end

function MuseumConfig.GetLevelCount(DisplayLimit: number): number
	local LevelCount = 0
	for LevelNumber, Level in MuseumConfig.Levels do
		if DisplayLimit >= Level.StartSlot then LevelCount = LevelNumber end
	end
	return LevelCount
end

function MuseumConfig.GetDisplayCount(LevelNumber: number, DisplayLimit: number): number
	local Level = MuseumConfig.Levels[LevelNumber]
	if not Level or DisplayLimit < Level.StartSlot then return 0 end
	return math.clamp(DisplayLimit - Level.StartSlot + 1, 0, Level.EndSlot - Level.StartSlot + 1)
end

function MuseumConfig.GetMaximumDisplayCount(): number
	local LastLevel = MuseumConfig.Levels[#MuseumConfig.Levels]
	return if LastLevel then LastLevel.EndSlot else 0
end

return MuseumConfig
