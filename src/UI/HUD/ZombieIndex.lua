local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.vide)
local ZombieIndexController = require(ReplicatedStorage.Controllers.ZombieIndexController)
local AbilityController = require(ReplicatedStorage.Controllers.AbilityController)
local ClassController = require(ReplicatedStorage.Controllers.ClassController)
local RunProgressionController = require(ReplicatedStorage.Controllers.RunProgressionController)
local ZombieIndexConfig = require(ReplicatedStorage.Modules.Game.Zombies.ZombieIndexConfig)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Button = require(script.Parent.Parent.Classes.Button)
local StudTexture = require(script.Parent.Parent.Classes.StudTexture)

local action, cleanup, create, derive, source = Vide.action, Vide.cleanup, Vide.create, Vide.derive, Vide.source

local localPlayer = Players.LocalPlayer
local HEAVY_FONT = Font.fromName("Ubuntu", Enum.FontWeight.Heavy)
local BOLD_FONT = Font.fromName("Ubuntu", Enum.FontWeight.Bold)
local PANEL = Color3.fromRGB(3, 18, 30)
local PANEL_LIGHT = Color3.fromRGB(7, 32, 48)
local PAPER = Color3.fromRGB(238, 245, 248)
local INK = Color3.fromRGB(24, 41, 52)
local CYAN = Color3.fromRGB(0, 184, 219)
local GOLD = Color3.fromRGB(241, 180, 67)

local function getEntry(state, zombieId: string)
	local entry = state[zombieId]
	return if type(entry) == "table" and type(entry.Kills) == "number" and entry.Kills >= 1 then entry else nil
end

local function countDiscovered(state): number
	local total = 0
	for _, definition in ZombieIndexConfig.List do
		if getEntry(state, definition.Id) then
			total += 1
		end
	end
	return total
end

local function collectionCard(definition, order: number, props)
	local discovered = derive(function()
		return getEntry(props.state(), definition.Id) ~= nil
	end)
	local claimed = derive(function()
		local entry = getEntry(props.state(), definition.Id)
		return entry ~= nil and entry.RewardClaimed == true
	end)
	local selected = derive(function()
		return props.selectedId() == definition.Id
	end)
	local accent = definition.EffectColor

	return create "Frame" {
		Name = definition.Id,
		BackgroundColor3 = function()
			if not discovered() then
				return Color3.fromRGB(25, 34, 42)
			end
			return accent:Lerp(Color3.fromRGB(7, 20, 29), 0.7)
		end,
		BorderSizePixel = 0,
		LayoutOrder = order,
		ZIndex = 416,
		StudTexture({ ZIndex = 416, ImageTransparency = 0.91, TileSize = UDim2.fromOffset(52, 52) }),
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				if selected() then
					return Color3.fromRGB(255, 232, 135)
				end
				return if discovered() then accent:Lerp(Color3.new(1, 1, 1), 0.25) else Color3.fromRGB(78, 91, 101)
			end,
			Thickness = function()
				return if selected() then 4 else 2
			end,
		},
		create "Frame" {
			Name = "Portrait",
			BackgroundColor3 = function()
				return if discovered() then accent:Lerp(Color3.fromRGB(10, 20, 30), 0.78) else Color3.fromRGB(18, 24, 30)
			end,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(7, 7),
			Size = function()
				return UDim2.new(1, -14, 0, if props.portrait() then 88 else 98)
			end,
			ZIndex = 417,
			StudTexture({ ZIndex = 418, ImageTransparency = 0.93, TileSize = UDim2.fromOffset(48, 48) }),
			create "UIGradient" {
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(76, 88, 98)),
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.25),
					NumberSequenceKeypoint.new(1, 0.75),
				}),
			},
			create "ImageLabel" {
				Name = "Zombie",
				BackgroundTransparency = 1,
				Image = Images.Zombies[definition.Id],
				Position = UDim2.fromScale(0.04, 0.01),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.92, 0.98),
				Visible = discovered,
				ZIndex = 419,
			},
			create "ImageLabel" {
				Name = "Unknown",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = Images.Lock,
				ImageColor3 = Color3.fromRGB(107, 119, 128),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.34, 0.5),
				Visible = function()
					return not discovered()
				end,
				ZIndex = 419,
			},
			create "TextButton" {
				Name = "Select",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 422,
				Activated = function()
					props.selectedId(definition.Id)
					Sounds.Play("Click", localPlayer.PlayerGui)
				end,
			},
		},
		create "TextLabel" {
			Name = "Name",
			BackgroundTransparency = 1,
			FontFace = HEAVY_FONT,
			Position = function()
				return UDim2.fromOffset(8, if props.portrait() then 98 else 108)
			end,
			Size = UDim2.new(1, -16, 0, 22),
			Text = function()
				return if discovered() then string.upper(definition.Name) else "???"
			end,
			TextColor3 = function()
				return if discovered() then Color3.new(1, 1, 1) else Color3.fromRGB(146, 153, 159)
			end,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 418,
		},
		create "TextLabel" {
			Name = "Kills",
			BackgroundTransparency = 1,
			FontFace = BOLD_FONT,
			Position = function()
				return UDim2.fromOffset(8, if props.portrait() then 121 else 131)
			end,
			Size = UDim2.new(1, -16, 0, 16),
			Text = function()
				local entry = getEntry(props.state(), definition.Id)
				if not entry then
					return "UNDISCOVERED"
				end
				return string.format("KILLS  %s", FormatNumber(entry.Kills) or tostring(entry.Kills))
			end,
			TextColor3 = function()
				return if discovered() then accent:Lerp(Color3.new(1, 1, 1), 0.42) else Color3.fromRGB(105, 114, 122)
			end,
			TextScaled = true,
			ZIndex = 418,
		},
		create "Frame" {
			Name = "Claim",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 1, -7),
			Size = UDim2.new(1, -14, 0, 27),
			Visible = discovered,
			ZIndex = 425,
			Button({
				Text = function()
					return if claimed() then "CLAIMED" else string.format("CLAIM  +%d", definition.DiscoveryReward)
				end,
				Enabled = function()
					return not claimed()
				end,
				BackgroundColor3 = function()
					return if claimed() then UIStyle.Colors.Muted else GOLD
				end,
				FontFace = HEAVY_FONT,
				MaxTextSize = 17,
				MinTextSize = 10,
				Size = UDim2.fromScale(1, 1),
				StrokeThickness = 0.045,
				OnActivated = function()
					ZombieIndexController.ClaimDiscoveryReward(definition.Id)
				end,
			}),
		},
	}
end

return function()
	local state = source(ZombieIndexController.GetState())
	local open = source(ZombieIndexController.IsOpen())
	local abilityOpen = source(AbilityController.IsInventoryOpen())
	local classOpen = source(ClassController.IsOpen())
	local runState = source(RunProgressionController.GetState())
	local selectedId = source(ZombieIndexConfig.List[1].Id)
	local viewportSize = source(Vector2.new(1280, 720))
	local topOffset = source(SafeArea.GetTopOffset(12))
	local viewportConnection: RBXScriptConnection?
	local connections = {}

	local portrait = derive(function()
		local size = viewportSize()
		return size.X < 600 and size.X < size.Y
	end)
	local compactPortrait = derive(function()
		return portrait() and viewportSize().Y < 760
	end)
	local shortLandscape = derive(function()
		local size = viewportSize()
		return not portrait() and size.Y < 560
	end)
	local veryShortLandscape = derive(function()
		local size = viewportSize()
		return not portrait() and size.Y < 440
	end)
	local inRun = derive(function()
		return runState().active == true
	end)
	local selectedDefinition = derive(function()
		return ZombieIndexConfig.ById[selectedId()] or ZombieIndexConfig.List[1]
	end)
	local selectedEntry = derive(function()
		return getEntry(state(), selectedDefinition().Id)
	end)
	local selectedDiscovered = derive(function()
		return selectedEntry() ~= nil
	end)
	local selectedClaimed = derive(function()
		local entry = selectedEntry()
		return entry ~= nil and entry.RewardClaimed == true
	end)

	table.insert(connections, ZombieIndexController.GetStateChangedSignal():Connect(function(newState)
		state(newState)
	end))
	table.insert(connections, ZombieIndexController.GetOpenChangedSignal():Connect(function(isOpen)
		open(isOpen)
	end))
	table.insert(connections, AbilityController.GetInventoryOpenChangedSignal():Connect(function(isOpen)
		abilityOpen(isOpen)
	end))
	table.insert(connections, ClassController.GetOpenChangedSignal():Connect(function(isOpen)
		classOpen(isOpen)
	end))
	table.insert(connections, RunProgressionController.GetStateChangedSignal():Connect(function(newState)
		runState(newState)
	end))
	table.insert(connections, SafeArea.GetChangedSignal():Connect(function()
		topOffset(SafeArea.GetTopOffset(12))
	end))
	cleanup(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)

	local cards = {}
	local detailPortraits = {}
	for order, definition in ZombieIndexConfig.List do
		table.insert(cards, collectionCard(definition, order, {
			state = state,
			selectedId = selectedId,
			portrait = portrait,
		}))
		table.insert(detailPortraits, create "ImageLabel" {
			Name = definition.Id .. "Portrait",
			BackgroundTransparency = 1,
			Image = Images.Zombies[definition.Id],
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return selectedDiscovered() and selectedId() == definition.Id
			end,
			ZIndex = 433,
		})
	end

	return create "Frame" {
		Name = "ZombieIndex",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 390,
		action(function(instance)
			local root = instance :: Frame
			viewportSize(root.AbsoluteSize)
			viewportConnection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				viewportSize(root.AbsoluteSize)
			end)
		end),
		create "Frame" {
			Name = "OpenButton",
			BackgroundTransparency = 1,
			Position = function()
				return UDim2.fromOffset(if portrait() then 10 else 18, topOffset() + (if portrait() then 110 else 124))
			end,
			Size = UDim2.fromOffset(if portrait() then 142 else 176, if portrait() then 48 else 54),
			Visible = function()
				return not inRun() and not open() and not abilityOpen() and not classOpen()
			end,
			ZIndex = 55,
			Button({
				Text = "ZOMBIE INDEX",
				BackgroundColor3 = Color3.fromRGB(100, 183, 80),
				CornerRadius = UDim.new(0, 4),
				FontFace = HEAVY_FONT,
				MaxTextSize = 23,
				Size = UDim2.fromScale(1, 1),
				OnActivated = function()
					ZombieIndexController.SetOpen(true)
				end,
			}),
		},
		create "Frame" {
			Name = "Overlay",
			Active = true,
			BackgroundColor3 = Color3.fromRGB(2, 8, 14),
			BackgroundTransparency = 0.16,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return open() and not inRun()
			end,
			ZIndex = 400,
			create "TextButton" {
				Name = "BackdropSensor",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 400,
				Activated = function()
					ZombieIndexController.SetOpen(false)
				end,
			},
			create "Frame" {
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = PANEL,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = function()
					if compactPortrait() then
						return UDim2.new(1, -12, 1, -(topOffset() + 12))
					elseif portrait() then
						return UDim2.new(1, -16, 1, -28)
					elseif shortLandscape() then
						return UDim2.new(0.96, 0, 0.96, 0)
					end
					return UDim2.new(0.82, 30, 0.84, 20)
				end,
				ZIndex = 405,
				-- The collection now uses the same stud surface language as the active HUD and shared buttons.
				StudTexture({ ZIndex = 406, ImageTransparency = 0.92, TileSize = UDim2.fromOffset(76, 76) }),
				create "UISizeConstraint" {
					MaxSize = function()
						return if portrait() then Vector2.new(430, 880) else Vector2.new(1080, 650)
					end,
				},
				create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(0, 5, 10), Thickness = 6 },
				create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = CYAN, Thickness = 3 },
				create "Frame" {
					Name = "Header",
					BackgroundColor3 = Color3.fromRGB(15, 164, 202),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(12, 12),
					Size = function()
						return UDim2.new(1, if portrait() then -76 else -92, 0, if portrait() then 72 else 80)
					end,
					ZIndex = 408,
					StudTexture({ ZIndex = 409, ImageTransparency = 0.82, TileSize = UDim2.fromOffset(92, 92) }),
					create "UIGradient" {
						Color = ColorSequence.new(Color3.fromRGB(28, 221, 238), Color3.fromRGB(31, 111, 172)),
						Rotation = 90,
					},
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(88, 235, 246), Thickness = 2 },
					create "TextLabel" {
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = HEAVY_FONT,
						Position = UDim2.fromOffset(if portrait() then 10 else 20, 7),
						Size = UDim2.new(0.6, 0, 0, if portrait() then 34 else 42),
						Text = "ZOMBIE INDEX",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 410,
					},
					create "TextLabel" {
						Name = "Progress",
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundColor3 = Color3.fromRGB(6, 53, 75),
						BorderSizePixel = 0,
						FontFace = HEAVY_FONT,
						Position = UDim2.new(1, -14, 0.5, 0),
						Size = function()
							return UDim2.fromOffset(if portrait() then 106 else 176, if portrait() then 34 else 42)
						end,
						Text = function()
							if portrait() then
								return string.format("%d / %d", countDiscovered(state()), #ZombieIndexConfig.List)
							end
							return string.format("DISCOVERED  %d/%d", countDiscovered(state()), #ZombieIndexConfig.List)
						end,
						TextColor3 = Color3.fromRGB(184, 242, 250),
						TextScaled = true,
						ZIndex = 410,
						create "UIPadding" { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) },
					},
				},
				create "Frame" {
					Name = "CloseSlot",
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -12, 0, 12),
					Size = UDim2.fromOffset(if portrait() then 52 else 56, if portrait() then 72 else 80),
					ZIndex = 412,
					Button({
						Text = "X",
						BackgroundColor3 = UIStyle.Colors.Red,
						FontFace = HEAVY_FONT,
						MaxTextSize = 44,
						Size = UDim2.fromScale(1, 1),
						OnActivated = function()
							ZombieIndexController.SetOpen(false)
						end,
					}),
				},
				create "ScrollingFrame" {
					Name = "Catalog",
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = PANEL_LIGHT,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromScale(0, 0),
					Position = function()
						return UDim2.fromOffset(12, if portrait() then 96 else 104)
					end,
					ScrollBarImageColor3 = CYAN,
					ScrollBarThickness = 4,
					Size = function()
						if portrait() then
							-- The proportional split guarantees the details footer keeps enough room on short phones.
							return UDim2.new(1, -24, 0.54, -58)
						end
						return UDim2.new(0.62, -16, 1, -116)
					end,
					ZIndex = 414,
					StudTexture({ ZIndex = 415, ImageTransparency = 0.93, TileSize = UDim2.fromOffset(60, 60) }),
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(0, 120, 148), Thickness = 2 },
					create "UIPadding" { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) },
					create "UIGridLayout" {
						CellPadding = function()
							return UDim2.fromOffset(if portrait() then 7 else 9, if portrait() then 7 else 9)
						end,
						CellSize = function()
							return if portrait() then UDim2.new(0.5, -4, 0, 174) else UDim2.new(1 / 3, -6, 0, 184)
						end,
						FillDirectionMaxCells = function()
							return if portrait() then 2 else 3
						end,
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					cards,
				},
				create "Frame" {
					Name = "Details",
					BackgroundColor3 = PAPER,
					BorderSizePixel = 0,
					Position = function()
						if portrait() then
							return UDim2.new(0, 12, 0.54, 48)
						end
						return UDim2.new(0.62, 2, 0, 104)
					end,
					Size = function()
						if portrait() then
							return UDim2.new(1, -24, 0.46, -60)
						end
						return UDim2.new(0.38, -14, 1, -116)
					end,
					ZIndex = 428,
					StudTexture({
						ZIndex = 429,
						ImageColor3 = INK,
						ImageTransparency = 0.96,
						TileSize = UDim2.fromOffset(68, 68),
					}),
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(96, 145, 171), Thickness = 2 },
					create "Frame" {
						Name = "Portrait",
						BackgroundColor3 = function()
							return if selectedDiscovered()
								then selectedDefinition().EffectColor:Lerp(Color3.fromRGB(11, 24, 34), 0.78)
								else Color3.fromRGB(34, 42, 48)
						end,
						BorderSizePixel = 0,
						Position = function()
							return UDim2.fromOffset(if portrait() then 12 else 18, if portrait() then 12 else 18)
						end,
						Size = function()
							local size = if compactPortrait() then 78 elseif portrait() then 96 elseif veryShortLandscape() then 68 elseif shortLandscape() then 88 else 144
							return UDim2.fromOffset(size, size)
						end,
						ZIndex = 431,
						StudTexture({ ZIndex = 432, ImageTransparency = 0.93, TileSize = UDim2.fromOffset(52, 52) }),
						create "UIStroke" {
							Color = function()
								return if selectedDiscovered() then selectedDefinition().EffectColor else Color3.fromRGB(91, 101, 109)
							end,
							Thickness = 2,
						},
						detailPortraits,
						create "ImageLabel" {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = Images.Lock,
							ImageColor3 = Color3.fromRGB(134, 143, 150),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.34, 0.45),
							Visible = function()
								return not selectedDiscovered()
							end,
							ZIndex = 433,
						},
					},
					create "TextLabel" {
						Name = "ZombieName",
						BackgroundTransparency = 1,
						FontFace = HEAVY_FONT,
						Position = function()
							return UDim2.fromOffset(if compactPortrait() then 104 elseif portrait() then 122 elseif veryShortLandscape() then 98 elseif shortLandscape() then 120 else 180, if portrait() then 10 elseif shortLandscape() then 14 else 20)
						end,
						Size = function()
							return UDim2.new(1, if compactPortrait() then -116 elseif portrait() then -134 elseif veryShortLandscape() then -110 elseif shortLandscape() then -132 else -194, 0, if compactPortrait() or veryShortLandscape() then 26 elseif portrait() or shortLandscape() then 30 else 40)
						end,
						Text = function()
							return if selectedDiscovered() then string.upper(selectedDefinition().Name) else "UNKNOWN ZOMBIE"
						end,
						TextColor3 = function()
							return if selectedDiscovered() then selectedDefinition().EffectColor:Lerp(Color3.fromRGB(18, 65, 77), 0.55) else Color3.fromRGB(74, 83, 90)
						end,
						TextScaled = true,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 432,
					},
					create "TextLabel" {
						Name = "Description",
						BackgroundTransparency = 1,
						FontFace = UIStyle.Font,
						Position = function()
							return UDim2.fromOffset(if compactPortrait() then 104 elseif portrait() then 122 elseif veryShortLandscape() then 98 elseif shortLandscape() then 120 else 180, if compactPortrait() or veryShortLandscape() then 42 elseif portrait() then 46 elseif shortLandscape() then 52 else 68)
						end,
						Size = function()
							return UDim2.new(1, if compactPortrait() then -116 elseif portrait() then -134 elseif veryShortLandscape() then -110 elseif shortLandscape() then -132 else -194, 0, if veryShortLandscape() then 44 elseif compactPortrait() then 50 elseif portrait() then 56 elseif shortLandscape() then 55 else 82)
						end,
						Text = function()
							return if selectedDiscovered()
								then selectedDefinition().Description
								else "Defeat this zombie to reveal what it does and unlock its coin reward."
						end,
						TextColor3 = INK,
						TextScaled = true,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						ZIndex = 432,
					},
					create "Frame" {
						Name = "Stats",
						BackgroundColor3 = Color3.fromRGB(211, 228, 235),
						BorderSizePixel = 0,
						Position = function()
							return UDim2.fromOffset(if portrait() then 12 else 18, if compactPortrait() then 101 elseif portrait() then 112 elseif veryShortLandscape() then 92 elseif shortLandscape() then 116 else 178)
						end,
						Size = function()
							return UDim2.new(1, if portrait() then -24 else -36, 0, if compactPortrait() or veryShortLandscape() then 28 elseif portrait() or shortLandscape() then 40 else 54)
						end,
						Visible = selectedDiscovered,
						ZIndex = 431,
						StudTexture({
							ZIndex = 431,
							ImageColor3 = INK,
							ImageTransparency = 0.94,
							TileSize = UDim2.fromOffset(48, 48),
						}),
						create "UIStroke" { Color = Color3.fromRGB(104, 146, 163), Thickness = 2 },
						create "TextLabel" {
							BackgroundTransparency = 1,
							FontFace = BOLD_FONT,
							Position = UDim2.fromOffset(10, 6),
							Size = UDim2.new(1, -20, 1, -12),
							Text = function()
								local entry = selectedEntry()
								return string.format("THREAT %d  |  %s HEALTH  |  %s KILLS", selectedDefinition().ThreatLevel, FormatNumber(selectedDefinition().MaxHealth) or tostring(selectedDefinition().MaxHealth), FormatNumber(entry and entry.Kills or 0) or tostring(entry and entry.Kills or 0))
							end,
							TextColor3 = Color3.fromRGB(34, 78, 96),
							TextScaled = true,
							TextWrapped = true,
							ZIndex = 432,
						},
					},
					create "Frame" {
						Name = "RewardSummary",
						BackgroundColor3 = Color3.fromRGB(224, 235, 238),
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(18, 250),
						Size = function()
							-- Medium-height desktop screens get a compact summary; taller panels let it fill the unused space.
							return if viewportSize().Y < 680 then UDim2.new(1, -36, 0, 80) else UDim2.new(1, -36, 1, -338)
						end,
						Visible = function()
							return selectedDiscovered() and not portrait() and not shortLandscape() and viewportSize().Y >= 620
						end,
						ZIndex = 431,
						StudTexture({
							ZIndex = 431,
							ImageColor3 = Color3.fromRGB(108, 91, 48),
							ImageTransparency = 0.95,
							TileSize = UDim2.fromOffset(56, 56),
						}),
						create "UIStroke" { Color = Color3.fromRGB(196, 145, 45), Thickness = 2 },
						create "ImageLabel" {
							Name = "Coin",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = Images.Coin,
							Position = UDim2.fromScale(0.25, 0.5),
							Size = function()
								local size = if viewportSize().Y < 680 then 64 else 96
								return UDim2.fromOffset(size, size)
							end,
							ZIndex = 432,
						},
						create "TextLabel" {
							Name = "RewardLabel",
							BackgroundTransparency = 1,
							FontFace = BOLD_FONT,
							Position = function()
								return UDim2.new(0.42, 0, 0.5, if viewportSize().Y < 680 then -34 else -55)
							end,
							Size = function()
								return UDim2.new(0.56, -8, 0, if viewportSize().Y < 680 then 18 else 30)
							end,
							Text = "DISCOVERY REWARD",
							TextColor3 = Color3.fromRGB(88, 72, 35),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 432,
						},
						create "TextLabel" {
							Name = "RewardAmount",
							BackgroundTransparency = 1,
							FontFace = HEAVY_FONT,
							Position = function()
								return UDim2.new(0.42, 0, 0.5, if viewportSize().Y < 680 then -14 else -22)
							end,
							Size = function()
								return UDim2.new(0.56, -8, 0, if viewportSize().Y < 680 then 28 else 52)
							end,
							Text = function()
								return string.format("+%d COINS", selectedDefinition().DiscoveryReward)
							end,
							TextColor3 = Color3.fromRGB(190, 127, 20),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 432,
						},
						create "TextLabel" {
							Name = "RewardState",
							BackgroundTransparency = 1,
							FontFace = BOLD_FONT,
							Position = function()
								return UDim2.new(0.42, 0, 0.5, if viewportSize().Y < 680 then 17 else 34)
							end,
							Size = function()
								return UDim2.new(0.56, -8, 0, if viewportSize().Y < 680 then 16 else 24)
							end,
							Text = function()
								return if selectedClaimed() then "COLLECTED" else "READY TO CLAIM"
							end,
							TextColor3 = function()
								return if selectedClaimed() then Color3.fromRGB(72, 125, 75) else Color3.fromRGB(175, 102, 25)
							end,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 432,
						},
					},
					create "Frame" {
						Name = "Action",
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Position = function()
							return UDim2.new(0.5, 0, 1, if compactPortrait() or veryShortLandscape() then -8 elseif portrait() or shortLandscape() then -10 else -14)
						end,
						Size = function()
							return UDim2.new(1, if portrait() then -24 else -36, 0, if compactPortrait() then 36 elseif portrait() then 42 elseif veryShortLandscape() then 34 elseif shortLandscape() then 42 else 52)
						end,
						Visible = selectedDiscovered,
						ZIndex = 435,
						Button({
							Text = function()
								return if selectedClaimed()
									then if portrait() then "REWARD CLAIMED" else "DISCOVERY REWARD CLAIMED"
									else string.format("CLAIM  +%d COINS", selectedDefinition().DiscoveryReward)
							end,
							Enabled = function()
								return not selectedClaimed()
							end,
							BackgroundColor3 = function()
								return if selectedClaimed() then UIStyle.Colors.Muted else GOLD
							end,
							FontFace = HEAVY_FONT,
							MaxTextSize = 26,
							Size = UDim2.fromScale(1, 1),
							OnActivated = function()
								ZombieIndexController.ClaimDiscoveryReward(selectedDefinition().Id)
							end,
						}),
					},
				},
			},
		},
	}
end
