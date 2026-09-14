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
		Gradient = ColorSequence.new(Color3.fromRGB(255, 45, 76), Color3.fromRGB(255, 102, 226)),
	},
	Secret = {
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 63, 105)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 215, 69)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(74, 255, 160)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(74, 198, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(216, 86, 255)),
		}),
	},
}

function RarityInfo.Get(Rarity: string)
	return RarityInfo[Rarity] or RarityInfo.Common
end

return RarityInfo
