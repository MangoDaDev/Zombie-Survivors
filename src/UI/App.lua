local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)
local RunSessionController = require(ReplicatedStorage.Controllers.RunSessionController)
local Confirmation = require(script.Parent.Classes.Confirmation)
local AbilityInterface = require(script.Parent.HUD.AbilityInterface)
local BossHealthBar = require(script.Parent.HUD.BossHealthBar)
local BossWarning = require(script.Parent.HUD.BossWarning)
local ClassInterface = require(script.Parent.HUD.ClassInterface)
local ClassesAbilitiesTutorial = require(script.Parent.HUD.ClassesAbilitiesTutorial)
local DownedOverlay = require(script.Parent.HUD.DownedOverlay)
local GameOver = require(script.Parent.HUD.GameOver)
local HealthBar = require(script.Parent.HUD.HealthBar)
local LevelUpChoices = require(script.Parent.HUD.LevelUpChoices)
local MonetizationShop = require(script.Parent.HUD.MonetizationShop)
local Notifications = require(script.Parent.HUD.Notifications)
local OffscreenPlayerIndicators = require(script.Parent.HUD.OffscreenPlayerIndicators)
local PartyTeleporterMenu = require(script.Parent.HUD.PartyTeleporterMenu)
local PurchaseCelebration = require(script.Parent.HUD.PurchaseCelebration)
local RageBar = require(script.Parent.HUD.RageBar)
local RunHUD = require(script.Parent.HUD.RunHUD)
local ZombieIndex = require(script.Parent.HUD.ZombieIndex)
local cleanup = vide.cleanup
local create = vide.create
local derive = vide.derive
local source = vide.source

return function()
	local runSessionState = source(RunSessionController.GetState())
	local regularUiVisible = derive(function()
		local state = runSessionState()
		return not (state.dead == true and state.active ~= true)
	end)
	local stateConnection = RunSessionController.GetStateChangedSignal():Connect(function(state)
		runSessionState(state)
	end)
	cleanup(function()
		stateConnection:Disconnect()
	end)

	return create "ScreenGui" {
		Name = "App",
		-- Keep the root available for the loading flow and future game-specific composition.
		ClipToDeviceSafeArea = false,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		create "Frame" {
			Name = "RegularUI",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			-- Spectators only need the dedicated downed/spectate controls. Keeping all ordinary UI under
			-- one reactive gate also prevents queued ability choices from covering the observed teammate.
			Visible = regularUiVisible,
			-- Simulator-era roll, standalone currency, and extraction HUD components remain preserved in
			-- UI/HUD, but are intentionally not composed; the current unlock shop is mounted below.
			Notifications(),
			-- Permanent ability unlocks are managed from the lobby and feed the authoritative run choice pool.
			AbilityInterface(),
			ClassInterface(),
			-- The returning-player shop tutorial layers guidance over the existing class UI without replacing it.
			ClassesAbilitiesTutorial(),
			ZombieIndex(),
			-- RunHUD is always mounted so Studio's promoted destination can activate reactively without remounting App.
			RunHUD(),
			-- Offscreen teammates remain findable without adding replicated state or changing character ownership.
			OffscreenPlayerIndicators(),
			-- Local Humanoid health is presentation-only here; damage and maximum-health changes remain authoritative.
			HealthBar(),
			-- Boss health mirrors authoritative zombie snapshots and exists only while the encounter boss is alive.
			BossHealthBar(),
			-- Milestone warning stages stay visible while players move through the guard wave and entrance.
			BossWarning(),
			-- Level-up presentation does not pause or intercept live combat outside the three choice cards.
			LevelUpChoices(),
			-- The gold shop shares the existing App, interaction components, and responsive style infrastructure.
			MonetizationShop(),
			-- Confirmed receipts and verified passes share one celebratory feedback surface across every purchase route.
			PurchaseCelebration(),
			-- The Creation Menu is presentation-only; party membership, settings, and departure stay authoritative.
			PartyTeleporterMenu(),
			Confirmation.Component(),
			-- RageBar owns reactive Game-map visibility so Studio destination promotion needs no App remount.
			RageBar(),
		},
		-- Downed players spectate living teammates and can deliberately revive; results appear only after a team wipe.
		DownedOverlay(),
		GameOver(),
	}
end
