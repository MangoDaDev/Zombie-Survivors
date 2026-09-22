local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local Networker = require(ReplicatedStorage.Packages.networker)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local InventoryItemKey = require(ReplicatedStorage.Modules.Game.InventoryItemKey)
local ToolResolver = require(ReplicatedStorage.Modules.Game.ToolResolver)

local InventoryController = {}
local network

function InventoryController.DropCarriedItem()
	if network then network:fire("RequestDrop") end
end

function InventoryController.Init()
	task.spawn(function()
		local satchel = require(ReplicatedStorage.Packages.satchel)
		network = Networker.client.new("InventoryController", InventoryController)
		local lastInventoryOrder: string?

		local function updateSlotIcon(slot)
			local tool = slot and slot.Tool
			local frame = slot and slot.Frame
			if not tool or not tool:IsA("Tool") or not frame then return end

			local icon = frame:FindFirstChild("Icon")
			local toolName = frame:FindFirstChild("ToolName")
			if not icon or not icon:IsA("ImageLabel") or not toolName or not toolName:IsA("TextLabel") then return end

			-- Satchel reads a custom attribute, but project tools use Roblox's native TextureId property.
			icon.Image = tool.TextureId
			toolName.Visible = tool.TextureId == ""
		end

		local function updateToolIcons()
			for _, container in { localPlayer.Character, localPlayer:FindFirstChildOfClass("Backpack") } do
				if not container then continue end
				for _, tool in container:GetChildren() do
					if tool:IsA("Tool") then updateSlotIcon(satchel:GetSlotForTool(tool)) end
				end
			end
		end

		local function ensureBatFirst()
			local batSlot
			local slotsByIndex = {}
			for _, container in { localPlayer.Character, localPlayer:FindFirstChildOfClass("Backpack") } do
				if not container then continue end
				for _, tool in container:GetChildren() do
					if not tool:IsA("Tool") then continue end
					local slot = satchel:GetSlotForTool(tool)
					if slot then
						slotsByIndex[slot.Index] = slot
						if ToolResolver.GetBatInfo(tool) then batSlot = slot end
					end
				end
			end
			while batSlot and batSlot.Index > 1 do
				local previousSlot = slotsByIndex[batSlot.Index - 1]
				if not previousSlot then break end
				batSlot:Swap(previousSlot)
				batSlot = previousSlot
			end
		end

		local function updateBackpack()
			local isCarrying = RuntimeState.Get(localPlayer, "IsCarryingItem", false) == true
			if isCarrying then satchel:UnequipAllTools() end
			satchel:SetBackpackEnabled(not isCarrying)
		end

		local function saveInventoryOrder()
			if RuntimeState.Get(localPlayer, "IsFixing", false) == true then return end
			local tools = {}
			for _, container in { localPlayer.Character, localPlayer:FindFirstChildOfClass("Backpack") } do
				if not container then continue end
				for _, tool in container:GetChildren() do
					if not tool:IsA("Tool") or not ToolResolver.GetItemInfo(tool) then continue end
					local slot = satchel:GetSlotForTool(tool)
					local itemKey = InventoryItemKey.Get(tool)
					if slot and itemKey then
						table.insert(tools, { Index = slot.Index, Key = itemKey })
					end
				end
			end
			table.sort(tools, function(left, right)
				return left.Index < right.Index
			end)
			local itemKeys = table.create(#tools)
			for index, tool in tools do itemKeys[index] = tool.Key end
			local inventoryOrder = table.concat(itemKeys, ",")
			if inventoryOrder == lastInventoryOrder then return end

			lastInventoryOrder = inventoryOrder
			network:fire("SaveInventoryOrder", itemKeys)
		end

		local function saveInventoryOrderDeferred()
			task.defer(saveInventoryOrder)
		end

		RuntimeState.GetChangedSignal(localPlayer, "IsCarryingItem"):Connect(updateBackpack)
		RuntimeState.GetChangedSignal(localPlayer, "IsFixing"):Connect(updateBackpack)
		satchel.BackpackItemAdded.Event:Connect(function(slot)
			updateSlotIcon(slot)
			task.defer(function()
				if slot.Tool and ToolResolver.GetBatInfo(slot.Tool) then ensureBatFirst() end
				updateToolIcons()
				saveInventoryOrder()
			end)
		end)
		satchel.BackpackItemRemoved.Event:Connect(function()
			-- Removing a displayed item must leave every other Tool bound to its existing Satchel slot.
			lastInventoryOrder = nil
			saveInventoryOrderDeferred()
		end)
		satchel.StateChanged.Event:Connect(function(isOpen)
			if not isOpen then saveInventoryOrderDeferred() end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				task.defer(updateToolIcons)
				saveInventoryOrderDeferred()
			end
		end)
		updateBackpack()
		ensureBatFirst()
		updateToolIcons()
		saveInventoryOrderDeferred()
	end)
end

return InventoryController
