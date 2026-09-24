-- These volumes match the four combat floors currently present in Studio; the smaller
-- green floor containing the SpawnLocation is intentionally not a zombie area.
-- Add or rebalance entries here without changing the grouped spawning algorithm.
-- Keep each CFrame on its floor surface and its X/Z extent inside that floor so zombies
-- spawn above the ground and cannot cross into an adjacent difficulty zone.
local ZombieAreas = {
	{
		Id = "Area1",
		Progression = 1,
		CFrame = CFrame.new(105.1682, 0, 0),
		Size = Vector2.new(107.8594, 110.448),
		MaxZombies = 30,
		SpawnInterval = 3,
		GroupSize = NumberRange.new(2, 4),
		GroupRadius = 10,
		MinPlayerDistance = 28,
		ZombieWeights = {
			{ Name = "Walker", Weight = 80 },
			{ Name = "Runner", Weight = 18 },
			{ Name = "Brute", Weight = 2 },
		},
	},
	{
		Id = "Area2",
		Progression = 2,
		CFrame = CFrame.new(-2.6912, 0, 0),
		Size = Vector2.new(107.8594, 110.448),
		MaxZombies = 55,
		SpawnInterval = 2.5,
		GroupSize = NumberRange.new(3, 6),
		GroupRadius = 12,
		MinPlayerDistance = 30,
		ZombieWeights = {
			{ Name = "Walker", Weight = 55 },
			{ Name = "Runner", Weight = 30 },
			{ Name = "Brute", Weight = 15 },
		},
	},
	{
		Id = "Area3",
		Progression = 3,
		CFrame = CFrame.new(-110.5506, 0, 0),
		Size = Vector2.new(107.8594, 110.448),
		MaxZombies = 85,
		SpawnInterval = 2,
		GroupSize = NumberRange.new(4, 8),
		GroupRadius = 14,
		MinPlayerDistance = 32,
		ZombieWeights = {
			{ Name = "Walker", Weight = 30 },
			{ Name = "Runner", Weight = 35 },
			{ Name = "Brute", Weight = 35 },
		},
	},
	{
		Id = "Area4",
		Progression = 4,
		CFrame = CFrame.new(-218.41, 0, 0),
		Size = Vector2.new(107.8594, 110.448),
		MaxZombies = 85,
		SpawnInterval = 2,
		GroupSize = NumberRange.new(4, 8),
		GroupRadius = 14,
		MinPlayerDistance = 32,
		ZombieWeights = {
			{ Name = "Walker", Weight = 30 },
			{ Name = "Runner", Weight = 35 },
			{ Name = "Brute", Weight = 35 },
		},
	},
}

return ZombieAreas
