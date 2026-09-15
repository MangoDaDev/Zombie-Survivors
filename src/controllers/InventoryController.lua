local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local Networker = require(ReplicatedStorage.Packages.networker)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local ToolResolver = require(ReplicatedStorage.Modules.Game.ToolResolver)

local InventoryController = {}

function InventoryController.Init()
	task.spawn(function()
		local satchel = require(ReplicatedStorage.Packages.satchel)
		local networker = Networker.client.new("InventoryController", InventoryController)
		local lastInventoryOrder: string?

		local function EnsureBatFirst()
			local BatSlot
			local SlotsByIndex = {}
			for _, Container in { localPlayer.Character, localPlayer:FindFirstChildOfClass("Backpack") } do
				if not Container then continue end
				for _, Tool in Container:GetChildren() do
					if not Tool:IsA("Tool") then continue end
					local Slot = satchel:GetSlotForTool(Tool)
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

		local function updateBackpack()
			local isCarrying = RuntimeState.Get(localPlayer, "IsCarryingItem", false) == true
			if isCarrying then
				satchel:UnequipAllTools()
			end
			satchel:SetBackpackEnabled(not isCarrying)
		end

		local function addToolsFrom(container: Instance?, tools)
			if container == nil then
				return
			end
			for _, child in container:GetChildren() do
				local ItemInfo = ToolResolver.GetItemInfo(child)
				if ItemInfo then
					local slot = satchel:GetSlotForTool(child)
					if slot then
						table.insert(tools, {
							itemId = ItemInfo.Id,
							slotIndex = slot.Index,
						})
					end
				end
			end
		end

		local function saveInventoryOrder()
			if RuntimeState.Get(localPlayer, "IsFixing", false) == true then return end
			local tools = {}
			addToolsFrom(localPlayer:FindFirstChildOfClass("Backpack"), tools)
			addToolsFrom(localPlayer.Character, tools)
			table.sort(tools, function(a, b)
				return a.slotIndex < b.slotIndex
			end)

			local itemIds = table.create(#tools)
			for position, toolInfo in tools do
				itemIds[position] = toolInfo.itemId
			end
			local inventoryOrder = table.concat(itemIds, ",")
			if inventoryOrder == lastInventoryOrder then
				return
			end

			lastInventoryOrder = inventoryOrder
			networker:fire("SaveInventoryOrder", itemIds)
		end

		local function saveInventoryOrderDeferred()
			task.defer(saveInventoryOrder)
		end

		RuntimeState.GetChangedSignal(localPlayer, "IsCarryingItem"):Connect(updateBackpack)
		RuntimeState.GetChangedSignal(localPlayer, "IsFixing"):Connect(updateBackpack)
		satchel.BackpackItemAdded.Event:Connect(function()
			task.defer(function()
				EnsureBatFirst()
				saveInventoryOrder()
			end)
		end)
		satchel.BackpackItemRemoved.Event:Connect(saveInventoryOrderDeferred)
		satchel.StateChanged.Event:Connect(function(isOpen)
			if not isOpen then
				saveInventoryOrderDeferred()
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				saveInventoryOrderDeferred()
			end
		end)
		updateBackpack()
		EnsureBatFirst()
		saveInventoryOrderDeferred()
	end)
end

return InventoryController
