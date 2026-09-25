local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local PartyTeleporterController = require(ReplicatedStorage.Controllers.PartyTeleporterController)
local PartyTeleporterConfig = require(ReplicatedStorage.Modules.Game.PartyTeleporterConfig)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source

local function makeText(name: string, text, position: UDim2, size: UDim2, color: Color3?)
	return create "TextLabel" {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = UIStyle.Font,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = color or UIStyle.Colors.Paper,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 62,
		create "UIStroke" {
			Color = UIStyle.Colors.Ink,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.025,
		},
	}
end

return function()
	local partyState = source(PartyTeleporterController.GetState())
	local connection = PartyTeleporterController.GetStateChangedSignal():Connect(function(state)
		partyState(state)
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	local function isLeader(): boolean
		local state = partyState()
		return state ~= nil and state.isLeader == true and state.locked ~= true
	end

	local function changePartySize(offset: number)
		local state = partyState()
		if not state or not isLeader() then
			return
		end
		local nextSize = math.clamp(
			state.maxSize + offset,
			math.max(PartyTeleporterConfig.MinimumPartySize, state.memberCount),
			PartyTeleporterConfig.MaximumPartySize
		)
		if nextSize ~= state.maxSize then
			PartyTeleporterController.SetMaxPartySize(nextSize)
		end
	end

	return create "Frame" {
		Name = "PartyTeleporterMenu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.34, 32, 0.43, 24),
		Visible = function()
			return partyState() ~= nil
		end,
		ZIndex = 60,
		create "UIAspectRatioConstraint" {
			AspectRatio = 1.25,
			DominantAxis = Enum.DominantAxis.Width,
		},
		makeText("Title", "PARTY", UDim2.fromScale(0.08, 0), UDim2.fromScale(0.84, 0.14)),
		makeText("Leader", function()
			local state = partyState()
			return state and ("LEADER  " .. state.leaderName) or ""
		end, UDim2.fromScale(0.08, 0.13), UDim2.fromScale(0.84, 0.08)),
		makeText("Status", function()
			local state = partyState()
			if not state then
				return ""
			end
			local timing = if state.locked then "STARTING" else string.format("%ds", state.countdown or 0)
			return string.format("%d / %d     %s", state.memberCount, state.maxSize, timing)
		end, UDim2.fromScale(0.08, 0.22), UDim2.fromScale(0.84, 0.11), UIStyle.Colors.Blue),
		makeText("PartySizeLabel", "PARTY SIZE", UDim2.fromScale(0.14, 0.36), UDim2.fromScale(0.72, 0.07)),
		create "Frame" {
			Name = "PartySizeControls",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.16, 0.44),
			Size = UDim2.fromScale(0.68, 0.13),
			ZIndex = 61,
			Button({
				Text = "-",
				Enabled = isLeader,
				BackgroundColor3 = UIStyle.Colors.Blue,
				Size = UDim2.fromScale(0.25, 1),
				OnActivated = function()
					changePartySize(-1)
				end,
			}),
			makeText("PartySize", function()
				local state = partyState()
				return state and tostring(state.maxSize) or "-"
			end, UDim2.fromScale(0.35, 0), UDim2.fromScale(0.3, 1)),
			create "Frame" {
				Name = "PlusButton",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.75, 0),
				Size = UDim2.fromScale(0.25, 1),
				Button({
					Text = "+",
					Enabled = isLeader,
					BackgroundColor3 = UIStyle.Colors.Blue,
					Size = UDim2.fromScale(1, 1),
					OnActivated = function()
						changePartySize(1)
					end,
				}),
			},
		},
		create "Frame" {
			Name = "PrivacyAction",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.16, 0.62),
			Size = UDim2.fromScale(0.68, 0.13),
			ZIndex = 61,
			Button({
				Text = function()
					local state = partyState()
					return if state and state.friendsOnly then "FRIENDS ONLY" else "OPEN TO EVERYONE"
				end,
				Enabled = isLeader,
				BackgroundColor3 = function()
					local state = partyState()
					return if state and state.friendsOnly then UIStyle.Colors.Green else UIStyle.Colors.Blue
				end,
				Size = UDim2.fromScale(1, 1),
				OnActivated = function()
					local state = partyState()
					if state and isLeader() then
						PartyTeleporterController.SetFriendsOnly(not state.friendsOnly)
					end
				end,
			}),
		},
		create "Frame" {
			Name = "ExitAction",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.25, 0.8),
			Size = UDim2.fromScale(0.5, 0.13),
			ZIndex = 61,
			Button({
				Text = "EXIT",
				Enabled = function()
					local state = partyState()
					return state ~= nil and not state.locked
				end,
				BackgroundColor3 = UIStyle.Colors.Red,
				Size = UDim2.fromScale(1, 1),
				OnActivated = PartyTeleporterController.LeaveParty,
			}),
		},
	}
end
