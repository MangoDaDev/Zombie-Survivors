local RarityInfo = {
	Common = {
		Gradient = ColorSequence.new(Color3.fromRGB(190, 196, 205), Color3.fromRGB(245, 248, 255)),
		RevealEffectDuration = 0.8,
	},
	Uncommon = {
		Gradient = ColorSequence.new(Color3.fromRGB(68, 210, 91), Color3.fromRGB(170, 255, 127)),
		RevealEffectDuration = 1,
	},
	Rare = {
		Gradient = ColorSequence.new(Color3.fromRGB(46, 132, 255), Color3.fromRGB(94, 232, 255)),
		RevealEffectDuration = 1.2,
	},
	Epic = {
		Gradient = ColorSequence.new(Color3.fromRGB(126, 64, 255), Color3.fromRGB(239, 107, 255)),
		RevealEffectDuration = 1.5,
	},
	Legendary = {
		Gradient = ColorSequence.new(Color3.fromRGB(255, 132, 36), Color3.fromRGB(255, 239, 92)),
		RevealEffectDuration = 1.9,
	},
	Mythic = {
		Gradient = ColorSequence.new(Color3.fromRGB(145, 0, 13), Color3.fromRGB(255, 62, 62)),
		RevealEffectDuration = 2.4,
	},
	Secret = {
		Gradient = ColorSequence.new(Color3.new(1, 1, 1)),
		RevealEffectDuration = 2.8,
	},
}

function RarityInfo.Get(Rarity: string)
	return RarityInfo[Rarity] or RarityInfo.Common
end

return RarityInfo
