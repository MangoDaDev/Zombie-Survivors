local Images = {
	Invite = "rbxassetid://115327667449209",
	Group = "rbxassetid://85374765114431",
	Luck = "rbxassetid://140615134556624",
	Cash = "rbxassetid://85844365023723",
	Fire = "rbxassetid://86050971312005",
	Coin = "rbxassetid://117589844207603",
	Area = "rbxassetid://97437550220113",
	Rebirth = "rbxassetid://78448825074454",
	Lock = "rbxassetid://18209587260",
	Dice = "rbxassetid://114320506048396",
	Auto = "rbxassetid://103004451874902",
	Settings = "rbxassetid://114320506048396",
	Robux = "rbxassetid://89121052656533",
	Upgrade = "rbxassetid://129209820289889",
	Changelog = "rbxassetid://119703720791230",
	Binoculars = "rbxassetid://106957185207855",
	Hexagon = "rbxassetid://102072576281291",
	Spray = "rbxassetid://135880301537221",
	SprayPaint = "rbxassetid://89126720010251",
	Sponge = "rbxassetid://123208274489359",
	Clock = "rbxassetid://115870617412099",
	SoftBrush = "rbxassetid://139473195533221", -- TODO: Replace with the uploaded Soft Brush icon.
	Polisher = "rbxassetid://91692314279454", -- TODO: Replace with the uploaded Polisher icon.
	Hairdryer = "rbxassetid://134997762633338", -- TODO: Replace with the uploaded Hairdryer icon.
	Hammer = "rbxassetid://109595730626206", -- TODO: Replace with the uploaded Hammer icon.
	Magnet = "rbxassetid://115492398859678", -- TODO: Replace with the uploaded Magnet icon.
	WoodenBat = "rbxassetid://71860797320768",
	StoneBat = "rbxassetid://138894146261760",
	BronzeBat = "rbxassetid://124720062419393",
	IronBat = "rbxassetid://93152709806790", -- TODO: Replace with the uploaded Iron Bat icon.
	GoldBat = "rbxassetid://75025107278341",
	EmeraldBat = "rbxassetid://111478517832404",
	TitaniumBat = "rbxassetid://112727939488705", -- TODO: Replace with the uploaded Titanium Bat icon.
	DiamondBat = "rbxassetid://113517459215926",
	ReinforcedSteelBat = "rbxassetid://137962500944413", -- TODO: Replace with the uploaded Reinforced Steel Bat icon.
	ObsidianBat = "rbxassetid://140370237259106",
	MeteoriteBat = "rbxassetid://124720062419393", -- TODO: Replace with the uploaded Meteorite Bat icon.
	ObjectiveArrow = "rbxassetid://123892753905134",
	Vignette = "rbxassetid://129145674033527",
	Sparkle = "rbxassetid://5639840603",

	FixIcons = {
		Dirt = "rbxassetid://111727278981257",
		Paint = "rbxassetid://118966242175055",
		Grease = "rbxassetid://97022398341091",
		LightDust = "rbxassetid://120760438361834",
		LooseDebris = "rbxassetid://131209811325776",
		Bent = "rbxassetid://132116868428994",
		Metal = "rbxassetid://91240324179971",
		Polish = "rbxassetid://119830985868329",
	},

	Abilities = {
		-- Ability icons must use the uploaded Image asset IDs, not their Decal container IDs.
		Dagger = "rbxassetid://90721390422076",
		Sword = "rbxassetid://102194989748667",
		Heart = "rbxassetid://137700856951592",
		Boots = "rbxassetid://117665946564493",
		Fireball = "rbxassetid://107539350715780",
		Lightning = "rbxassetid://103421034720026",
		Boomerang = "rbxassetid://90733680856488",
		Aura = "rbxassetid://108597622069687",
		Ball = "rbxassetid://120933689418972",
		Drill = "rbxassetid://93715158975572",
		Mine = "rbxassetid://122745392008314",
		Poison = "rbxassetid://138815331623694",
		Blast = "rbxassetid://100442748933829",
		Burn = "rbxassetid://109206613200684",
		Thorns = "rbxassetid://86137962796522",
		-- Approved ability art: each entry uses its own uploaded Image asset, not a reused placeholder.
		Shotgun = "rbxassetid://136656086573473",
		FrostNova = "rbxassetid://80207696332371",
		Meteor = "rbxassetid://86955110614000",
		Turret = "rbxassetid://128949649605246",
		Vortex = "rbxassetid://110093432119413",
		Giant = "rbxassetid://75109106190883",
		Greed = "rbxassetid://72933067458939",
		Critical = "rbxassetid://127237893669592",
		Adrenaline = "rbxassetid://129265581193404",
		Impact = "rbxassetid://95046721760053",
	},

	-- Zombie portraits use the uploaded Image asset IDs; Decal container IDs do not render in ImageLabels.
	Zombies = {
		Walker = "rbxassetid://138149267728810", Runner = "rbxassetid://84550798854786", Brute = "rbxassetid://105624079612551",
		Spitter = "rbxassetid://116945381993947", Charger = "rbxassetid://130455942869445", Screamer = "rbxassetid://105246434468073",
		Tank = "rbxassetid://90063847460789", Leaper = "rbxassetid://116199380357467", Shielder = "rbxassetid://94300796030420",
		Bomber = "rbxassetid://117887625615533", Grabber = "rbxassetid://128298909808225", Summoner = "rbxassetid://110538258607197",
		Splitter = "rbxassetid://133513083944714", Splitling = "rbxassetid://84256249857769", Burrower = "rbxassetid://138354754179650",
		Frenzy = "rbxassetid://118333796583654", Medic = "rbxassetid://122914293108923", Hardened = "rbxassetid://100557703031534",
		Dodger = "rbxassetid://76527414640165", Sludger = "rbxassetid://72360871962397", Warden = "rbxassetid://102636410391388",
		CorpseEater = "rbxassetid://114220524771207", Hexer = "rbxassetid://79491621743049", Anchor = "rbxassetid://82216613156318",
		Frostbite = "rbxassetid://137871328795264", Rallying = "rbxassetid://105334244517742", Hoarder = "rbxassetid://103921542625931",
		BroodPod = "rbxassetid://113683634311694", Martyr = "rbxassetid://99190229992808", Stalker = "rbxassetid://131514028415117",
		Juggernaut = "rbxassetid://110769893485140",
	},
}

return Images
