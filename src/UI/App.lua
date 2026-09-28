local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)
local Confirmation = require(script.Parent.Classes.Confirmation)
local AbilityInterface = require(script.Parent.HUD.AbilityInterface)
local BossHealthBar = require(script.Parent.HUD.BossHealthBar)
local BossWarning = require(script.Parent.HUD.BossWarning)
local ClassInterface = require(script.Parent.HUD.ClassInterface)
local GameOver = require(script.Parent.HUD.GameOver)
local HealthBar = require(script.Parent.HUD.HealthBar)
local LevelUpChoices = require(script.Parent.HUD.LevelUpChoices)
local Notifications = require(script.Parent.HUD.Notifications)
local OffscreenPlayerIndicators = require(script.Parent.HUD.OffscreenPlayerIndicators)
local PartyTeleporterMenu = require(script.Parent.HUD.PartyTeleporterMenu)
local RageBar = require(script.Parent.HUD.RageBar)
local RunHUD = require(script.Parent.HUD.RunHUD)
local ZombieIndex = require(script.Parent.HUD.ZombieIndex)
local create = vide.create

return function()
	return create "ScreenGui" {
		Name = "App",
		-- Keep the root available for the loading flow and future game-specific composition.
		ClipToDeviceSafeArea = false,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		-- Simulator-era roll, standalone currency, and extraction HUD components remain preserved in
		-- UI/HUD, but are intentionally not composed; the current unlock shop is mounted below.
		Notifications(),
		-- Permanent ability unlocks are managed from the lobby and feed the authoritative run choice pool.
		AbilityInterface(),
		ClassInterface(),
		ZombieIndex(),
		-- RunHUD is always mounted so Studio's promoted destination can activate reactively without remounting App.
		RunHUD(),
<<<<<<< HEAD
		-- Offscreen teammates remain findable without adding replicated state or changing character ownership.
		OffscreenPlayerIndicators(),
=======
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3
		-- Local Humanoid health is presentation-only here; damage and maximum-health changes remain authoritative.
		HealthBar(),
		-- Boss health mirrors authoritative zombie snapshots and exists only while the encounter boss is alive.
		BossHealthBar(),
		-- Milestone warning stages stay visible while players move through the guard wave and entrance.
		BossWarning(),
		-- Level-up presentation does not pause or intercept live combat outside the three choice cards.
		LevelUpChoices(),
		-- The Creation Menu is presentation-only; party membership, settings, and departure stay authoritative.
		PartyTeleporterMenu(),
		Confirmation.Component(),
		-- RageBar owns reactive Game-map visibility so Studio destination promotion needs no App remount.
		RageBar(),
		-- Per-player death results cover only the defeated player's client while survivors continue their run.
		GameOver(),
	}
end
