local RarityInfo = {
	Common = {
		Gradient = ColorSequence.new(Color3.fromRGB(190, 196, 205), Color3.fromRGB(245, 248, 255)),
	},
	Uncommon = {
		Gradient = ColorSequence.new(Color3.fromRGB(68, 210, 91), Color3.fromRGB(170, 255, 127)),
	},
	Rare = {
		Gradient = ColorSequence.new(Color3.fromRGB(46, 132, 255), Color3.fromRGB(94, 232, 255)),
	},
	Epic = {
		Gradient = ColorSequence.new(Color3.fromRGB(126, 64, 255), Color3.fromRGB(239, 107, 255)),
	},
	Legendary = {
		Gradient = ColorSequence.new(Color3.fromRGB(255, 132, 36), Color3.fromRGB(255, 239, 92)),
	},
	Mythic = {
		Gradient = ColorSequence.new(Color3.fromRGB(145, 0, 13), Color3.fromRGB(255, 62, 62)),
	},
	Secret = {
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 8, 10)),
			ColorSequenceKeypoint.new(0.18, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.22, Color3.fromRGB(45, 45, 50)),
			ColorSequenceKeypoint.new(0.47, Color3.fromRGB(235, 235, 240)),
			ColorSequenceKeypoint.new(0.52, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(0.76, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.81, Color3.fromRGB(70, 70, 76)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(245, 245, 245)),
		}),
	},
}

function RarityInfo.Get(Rarity: string)
	return RarityInfo[Rarity] or RarityInfo.Common
end

return RarityInfo
