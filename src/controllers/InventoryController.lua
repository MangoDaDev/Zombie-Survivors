local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Networker = require(ReplicatedStorage.Packages.networker)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local InventoryItemKey = require(ReplicatedStorage.Modules.Game.InventoryItemKey)
local ToolResolver = require(ReplicatedStorage.Modules.Game.ToolResolver)

local InventoryController = {}
local Network

local PageFadeOut = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PageFadeIn = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ButtonTween = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ArrowImage = "rbxasset://textures/ui/Backpack/ScrollUpArrow.png"
local ArrowSize = 34
local ArrowGap = 8

function InventoryController.DropCarriedItem()
	if Network then Network:fire("RequestDrop") end
end

function InventoryController.Init()
	task.spawn(function()
		local Satchel = require(ReplicatedStorage.Packages.satchel)
		Network = Networker.client.new("InventoryController", InventoryController)
		local LastInventoryOrder: string?
		local OrderedTools = {}
		local HotbarSlots = {}
		local PageStarts = { 1 }
		local CurrentPage = 1
		local HotbarCapacity = 0
		local IsChangingPage = false
		local LeftArrow: ImageButton?
		local RightArrow: ImageButton?

		local function UpdateSlotIcon(Slot)
			local Tool = Slot and Slot.Tool
			local SlotFrame = Slot and Slot.Frame
			if not Tool or not Tool:IsA("Tool") or not SlotFrame then return end

			local Icon = SlotFrame:FindFirstChild("Icon")
			local ToolName = SlotFrame:FindFirstChild("ToolName")
			if not Icon or not Icon:IsA("ImageLabel") or not ToolName or not ToolName:IsA("TextLabel") then return end

			-- Satchel reads a custom attribute, but project tools use Roblox's native TextureId property.
			Icon.Image = Tool.TextureId
			ToolName.Visible = Tool.TextureId == ""
		end

		local function UpdateToolIcons()
			for _, Container in { LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack") } do
				if not Container then continue end
				for _, Tool in Container:GetChildren() do
					if Tool:IsA("Tool") then UpdateSlotIcon(Satchel:GetSlotForTool(Tool)) end
				end
			end
		end

		local function EnsureBatFirst()
			local BatSlot
			local SlotsByIndex = {}
			for _, Container in { LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack") } do
				if not Container then continue end
				for _, Tool in Container:GetChildren() do
					if not Tool:IsA("Tool") then continue end
					local Slot = Satchel:GetSlotForTool(Tool)
					if Slot then
						SlotsByIndex[Slot.Index] = Slot
						if ToolResolver.GetBatInfo(Tool) then BatSlot = Slot end
					end
				end
			end
			while BatSlot and BatSlot.Index > 1 do
				local PreviousSlot = SlotsByIndex[BatSlot.Index - 1]
				if not PreviousSlot then break end
				BatSlot:Swap(PreviousSlot)
				BatSlot = PreviousSlot
			end
		end

		local function GetCurrentTools()
			local Tools = {}
			for _, Container in { LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack") } do
				if not Container then continue end
				for _, Tool in Container:GetChildren() do
					if not Tool:IsA("Tool") then continue end
					local Slot = Satchel:GetSlotForTool(Tool)
					if Slot then
						if Slot.Index <= HotbarCapacity then HotbarSlots[Slot.Index] = Slot end
						table.insert(Tools, { Tool = Tool, Index = Slot.Index })
					end
				end
			end
			table.sort(Tools, function(Left, Right)
				return Left.Index < Right.Index
			end)
			return Tools
		end

		local function PutBatFirst()
			for Index, Tool in OrderedTools do
				if ToolResolver.GetBatInfo(Tool) then
					if Index > 1 then
						table.remove(OrderedTools, Index)
						table.insert(OrderedTools, 1, Tool)
					end
					return
				end
			end
		end

		local function RefreshOrderedToolsFromSlots()
			table.clear(OrderedTools)
			for _, ToolInfo in GetCurrentTools() do
				table.insert(OrderedTools, ToolInfo.Tool)
			end
			PutBatFirst()
		end

		local function ReconcileOrderedTools()
			local CurrentTools = GetCurrentTools()
			local CurrentToolSet = {}
			for _, ToolInfo in CurrentTools do
				CurrentToolSet[ToolInfo.Tool] = true
			end

			for Index = #OrderedTools, 1, -1 do
				if not CurrentToolSet[OrderedTools[Index]] then
					table.remove(OrderedTools, Index)
				end
			end
			for _, ToolInfo in CurrentTools do
				if not table.find(OrderedTools, ToolInfo.Tool) then
					table.insert(OrderedTools, ToolInfo.Tool)
				end
			end
			PutBatFirst()
		end

		local function RebuildPageStarts()
			table.clear(PageStarts)
			table.insert(PageStarts, 1)
			if HotbarCapacity <= 0 then return end

			local MaximumStart = math.max(1, #OrderedTools - HotbarCapacity + 1)
			local PageStart = 1
			while PageStart < MaximumStart do
				PageStart = math.min(PageStart + HotbarCapacity, MaximumStart)
				table.insert(PageStarts, PageStart)
			end
			CurrentPage = math.clamp(CurrentPage, 1, #PageStarts)
		end

		local function UpdateNavigationVisibility()
			if not LeftArrow or not RightArrow then return end
			local HasOverflow = #OrderedTools > HotbarCapacity and #PageStarts > 1 and not Satchel:IsOpened()
			LeftArrow.Visible = HasOverflow and CurrentPage > 1
			RightArrow.Visible = HasOverflow and CurrentPage < #PageStarts
		end

		local function RenderCurrentPage()
			if HotbarCapacity <= 0 then return end
			ReconcileOrderedTools()
			RebuildPageStarts()
			local PageStart = PageStarts[CurrentPage]

			-- Keep Satchel's numbered hotbar slots authoritative so clicks and keyboard shortcuts retain native behavior.
			for HotbarIndex = 1, math.min(HotbarCapacity, #OrderedTools) do
				local TargetSlot = HotbarSlots[HotbarIndex]
				local DesiredTool = OrderedTools[PageStart + HotbarIndex - 1]
				local DesiredSlot = DesiredTool and Satchel:GetSlotForTool(DesiredTool)
				if TargetSlot and DesiredSlot and TargetSlot ~= DesiredSlot then
					DesiredSlot:Swap(TargetSlot)
				end
			end
			UpdateNavigationVisibility()
		end

		local function AnimatePageChange(Callback)
			if IsChangingPage then return end
			IsChangingPage = true
			local FadedObjects = {}
			local CompletionTween

			for HotbarIndex = 1, HotbarCapacity do
				local Slot = HotbarSlots[HotbarIndex]
				local SlotFrame = Slot and Slot.Frame
				if not SlotFrame then continue end
				local Icon = SlotFrame:FindFirstChild("Icon")
				local ToolName = SlotFrame:FindFirstChild("ToolName")
				if Icon and Icon:IsA("ImageLabel") then
					FadedObjects[Icon] = Icon.ImageTransparency
					local Tween = TweenService:Create(Icon, PageFadeOut, { ImageTransparency = 0.55 })
					Tween:Play()
					CompletionTween = CompletionTween or Tween
				end
				if ToolName and ToolName:IsA("TextLabel") then
					FadedObjects[ToolName] = ToolName.TextTransparency
					local Tween = TweenService:Create(ToolName, PageFadeOut, { TextTransparency = 0.55 })
					Tween:Play()
					CompletionTween = CompletionTween or Tween
				end
			end

			local function FinishChange()
				Callback()
				for GuiObject, OriginalTransparency in FadedObjects do
					local Property = if GuiObject:IsA("ImageLabel") then "ImageTransparency" else "TextTransparency"
					TweenService:Create(GuiObject, PageFadeIn, { [Property] = OriginalTransparency }):Play()
				end
				task.delay(PageFadeIn.Time, function()
					IsChangingPage = false
				end)
			end

			if CompletionTween then
				CompletionTween.Completed:Once(FinishChange)
			else
				FinishChange()
			end
		end

		local function ChangePage(Direction)
			local NextPage = CurrentPage + Direction
			if IsChangingPage or NextPage < 1 or NextPage > #PageStarts then return end
			AnimatePageChange(function()
				CurrentPage = NextPage
				RenderCurrentPage()
				UpdateToolIcons()
			end)
		end

		local function CreateNavigationButton(Name, Rotation, Position, Callback)
			local Button = Instance.new("ImageButton")
			Button.Name = Name
			Button.AnchorPoint = Vector2.new(0.5, 0.5)
			Button.Position = Position
			Button.Size = UDim2.fromOffset(ArrowSize, ArrowSize)
			Button.BackgroundColor3 = Color3.fromRGB(25, 27, 29)
			Button.BackgroundTransparency = 0.2
			Button.AutoButtonColor = false
			Button.Image = ArrowImage
			Button.ImageColor3 = Color3.new(1, 1, 1)
			Button.Rotation = Rotation
			Button.ZIndex = 5

			local Corner = Instance.new("UICorner")
			Corner.CornerRadius = UDim.new(0, 8)
			Corner.Parent = Button

			local Stroke = Instance.new("UIStroke")
			Stroke.Color = Color3.new(1, 1, 1)
			Stroke.Transparency = 0.75
			Stroke.Thickness = 1
			Stroke.Parent = Button

			local Scale = Instance.new("UIScale")
			Scale.Parent = Button
			Button.MouseEnter:Connect(function()
				TweenService:Create(Scale, ButtonTween, { Scale = 1.06 }):Play()
			end)
			Button.MouseLeave:Connect(function()
				TweenService:Create(Scale, ButtonTween, { Scale = 1 }):Play()
			end)
			Button.MouseButton1Down:Connect(function()
				TweenService:Create(Scale, ButtonTween, { Scale = 0.92 }):Play()
			end)
			Button.MouseButton1Up:Connect(function()
				TweenService:Create(Scale, ButtonTween, { Scale = 1 }):Play()
			end)
			Button.Activated:Connect(Callback)
			return Button
		end

		local function SetupNavigation()
			local BackpackGui = LocalPlayer.PlayerGui:FindFirstChild("BackpackGui")
			local MainFrame = BackpackGui and BackpackGui:FindFirstChild("Backpack")
			local HotbarFrame = MainFrame and MainFrame:FindFirstChild("Hotbar")
			if not HotbarFrame or not HotbarFrame:IsA("Frame") then return end

			for _, Child in HotbarFrame:GetChildren() do
				if Child:IsA("TextButton") and tonumber(Child.Name) then
					HotbarCapacity += 1
				end
			end

			local HalfWidth = HotbarFrame.Size.X.Offset / 2
			LeftArrow = CreateNavigationButton(
				"PreviousPage",
				-90,
				UDim2.new(0.5, -HalfWidth - ArrowGap - ArrowSize / 2, 0.5, 0),
				function() ChangePage(-1) end
			)
			RightArrow = CreateNavigationButton(
				"NextPage",
				90,
				UDim2.new(0.5, HalfWidth + ArrowGap + ArrowSize / 2, 0.5, 0),
				function() ChangePage(1) end
			)
			LeftArrow.Parent = HotbarFrame
			RightArrow.Parent = HotbarFrame
		end

		local function UpdateBackpack()
			local IsCarrying = RuntimeState.Get(LocalPlayer, "IsCarryingItem", false) == true
			if IsCarrying then
				Satchel:UnequipAllTools()
			end
			Satchel:SetBackpackEnabled(not IsCarrying)
		end

		local function SaveInventoryOrder()
			if RuntimeState.Get(LocalPlayer, "IsFixing", false) == true then return end
			if CurrentPage == 1 and not IsChangingPage then
				RefreshOrderedToolsFromSlots()
			else
				ReconcileOrderedTools()
			end

			local ItemKeys = {}
			for _, Tool in OrderedTools do
				if not ToolResolver.GetItemInfo(Tool) then continue end
				local ItemKey = InventoryItemKey.Get(Tool)
				if ItemKey then table.insert(ItemKeys, ItemKey) end
			end
			local InventoryOrder = table.concat(ItemKeys, ",")
			if InventoryOrder == LastInventoryOrder then
				return
			end

			LastInventoryOrder = InventoryOrder
			Network:fire("SaveInventoryOrder", ItemKeys)
		end

		local function SaveInventoryOrderDeferred()
			task.defer(SaveInventoryOrder)
		end

		RuntimeState.GetChangedSignal(LocalPlayer, "IsCarryingItem"):Connect(UpdateBackpack)
		RuntimeState.GetChangedSignal(LocalPlayer, "IsFixing"):Connect(UpdateBackpack)
		Satchel.BackpackItemAdded.Event:Connect(function(Slot)
			if Slot.Index <= HotbarCapacity then HotbarSlots[Slot.Index] = Slot end
			UpdateSlotIcon(Slot)
			task.defer(function()
				EnsureBatFirst()
				ReconcileOrderedTools()
				RenderCurrentPage()
				UpdateToolIcons()
				SaveInventoryOrder()
			end)
		end)
		Satchel.BackpackItemRemoved.Event:Connect(function(Slot)
			if Slot.Index <= HotbarCapacity then HotbarSlots[Slot.Index] = Slot end
			task.defer(function()
				ReconcileOrderedTools()
				RenderCurrentPage()
				SaveInventoryOrder()
			end)
		end)
		Satchel.StateChanged.Event:Connect(function(IsOpen)
			if IsOpen then
				CurrentPage = 1
				RenderCurrentPage()
			else
				RefreshOrderedToolsFromSlots()
				RebuildPageStarts()
				SaveInventoryOrderDeferred()
			end
			UpdateNavigationVisibility()
		end)
		UserInputService.InputEnded:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				task.defer(UpdateToolIcons)
				SaveInventoryOrderDeferred()
			end
		end)
		SetupNavigation()
		UpdateBackpack()
		EnsureBatFirst()
		RefreshOrderedToolsFromSlots()
		RenderCurrentPage()
		UpdateToolIcons()
		SaveInventoryOrderDeferred()
	end)
end

return InventoryController
