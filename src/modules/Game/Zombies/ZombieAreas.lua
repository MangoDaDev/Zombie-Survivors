-- These volumes match the five progression floors currently present in Studio.
-- Add or rebalance entries here without changing the grouped spawning algorithm.
local ZombieAreas = {
	{
		Id = "Area1",
		Progression = 1,
		CFrame = CFrame.new(-4.25, -4, 0),
		Size = Vector2.new(90, 248),
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
		CFrame = CFrame.new(-178.25, -4, 0),
		Size = Vector2.new(242, 248),
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
		CFrame = CFrame.new(-428.25, -4, 0),
		Size = Vector2.new(242, 248),
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
		CFrame = CFrame.new(-678.25, -4, 0),
		Size = Vector2.new(242, 248),
		-- New floors inherit the highest established tier until their balance is tuned separately.
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
		Id = "Area5",
		Progression = 5,
		CFrame = CFrame.new(-928.25, -4, 0),
		Size = Vector2.new(242, 248),
		-- New floors inherit the highest established tier until their balance is tuned separately.
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
