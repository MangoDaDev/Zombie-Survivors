-- Currently unused after removal of simulator gameplay. Preserved for future explicitly opened roll controls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local AbilityController = require(ReplicatedStorage.Controllers.AbilityController)
local RollController = require(ReplicatedStorage.Controllers.RollController)
local RollDefinitions = require(ReplicatedStorage.Modules.Game.Rolls.RollDefinitions)
local RunRewardsController = require(ReplicatedStorage.Controllers.RunRewardsController)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source

return function()
	local active = source(false)
	local sequenceRunning = false
	local autoEnabled = source(RollController.IsAutoRollEnabled())
	local hidden = source(RollController.IsPresentationHidden())
	local inSafeArea = source(RunRewardsController.IsInSafeArea())
	local totalRolls = source(RollController.GetTotalRolls())
	local connections = {}

	table.insert(connections, RollController.GetRollStartedSignal():Connect(function()
		sequenceRunning = true
		active(true)
	end))
	table.insert(connections, RollController.GetRollFinishedSignal():Connect(function(_, willAutoRoll)
		sequenceRunning = false
		if not willAutoRoll then
			active(false)
			RollController.SetPresentationHidden(false)
		end
	end))
	table.insert(connections, RollController.GetAutoRollChangedSignal():Connect(function(enabled)
		autoEnabled(enabled)
		if not enabled and active() and not sequenceRunning then
			active(false)
			RollController.SetPresentationHidden(false)
		end
	end))
	table.insert(connections, RollController.GetPresentationHiddenChangedSignal():Connect(function(value)
		hidden(value)
	end))
	table.insert(connections, RollController.GetTotalRollsChangedSignal():Connect(function(value)
		totalRolls(value)
	end))
	table.insert(connections, RunRewardsController.GetSafeAreaChangedSignal():Connect(function(value)
		inSafeArea(value)
		if not value then
			AbilityController.SetInventoryOpen(false)
		end
	end))
	cleanup(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

	local function toggleAuto()
		if totalRolls() >= RollDefinitions.AutoRollUnlockRolls then
			RollController.SetAutoRoll(not autoEnabled())
		end
	end

	return create "Frame" {
		Name = "RollControls",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 170,
		create "Frame" {
			Name = "Controls",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			-- This HUD row never moves with, or reparents into, the rolling presentation.
			Position = UDim2.new(0.5, 0, 1, -24),
			Size = UDim2.new(0.5, 220, 0.058, 18),
			ZIndex = 170,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.055, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			},
			create "Frame" {
				Name = "AbilitiesSlot",
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.3, 1),
				-- Keep this layout slot present outside the safe area so Roll remains exactly centered.
				create "Frame" {
					Name = "SafeAreaVisibility",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Visible = inSafeArea,
					Button({
						Text = "ABILITIES",
						BackgroundColor3 = UIStyle.Colors.Gold,
						Size = UDim2.fromScale(1, 1),
						OnActivated = function()
							if inSafeArea() then
								AbilityController.SetInventoryOpen(true)
							end
						end,
					}),
				},
			},
			Button({
				Text = function()
					if not active() then
						return "ROLL"
					end
					return if hidden() then "SHOW" else "HIDE"
				end,
				BackgroundColor3 = UIStyle.Colors.Blue,
				LayoutOrder = 2,
				OnActivated = function()
					if active() then
						RollController.SetPresentationHidden(not hidden())
					else
						RollController.RequestRoll()
					end
				end,
			}),
			Button({
				Text = function()
					if totalRolls() < RollDefinitions.AutoRollUnlockRolls then
						return string.format("AUTO: %d/%d", totalRolls(), RollDefinitions.AutoRollUnlockRolls)
					end
					return if autoEnabled() then "AUTO: ON" else "AUTO: OFF"
				end,
				BackgroundColor3 = function()
					if totalRolls() < RollDefinitions.AutoRollUnlockRolls then
						return UIStyle.Colors.Muted
					end
					return if autoEnabled() then UIStyle.Colors.Green else UIStyle.Colors.Red
				end,
				Enabled = function()
					return totalRolls() >= RollDefinitions.AutoRollUnlockRolls
				end,
				LayoutOrder = 3,
				OnActivated = toggleAuto,
			}),
		},
	}
end
