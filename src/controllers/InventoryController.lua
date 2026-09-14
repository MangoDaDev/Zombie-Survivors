local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local Networker = require(ReplicatedStorage.Packages.networker)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local InventoryController = {}

function InventoryController:Init()
	task.spawn(function()
		local PackageIndex = ReplicatedStorage.Packages:FindFirstChild("_Index")
		if PackageIndex then
			for _, Package in PackageIndex:GetChildren() do
				local SatchelModule = Package.Name:match("^upliftgames_satchel@") and Package:FindFirstChild("satchel")
				if SatchelModule and SatchelModule:IsA("ModuleScript") then SatchelModule:SetAttribute("FontFace", UIStyle.Font); break end
			end
		end
		local satchel = require(ReplicatedStorage.Packages.satchel)
		local networker = Networker.client.new("InventoryController", self)
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
						if type(Tool:GetAttribute("BatId")) == "string" then BatSlot = Slot end
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
			local isCarrying = localPlayer:GetAttribute("IsCarryingItem") == true
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
				local itemId = child:GetAttribute("ItemId")
				if child:IsA("Tool") and type(itemId) == "number" then
					local slot = satchel:GetSlotForTool(child)
					if slot then
						table.insert(tools, {
							itemId = itemId,
							slotIndex = slot.Index,
						})
					end
				end
			end
		end

		local function saveInventoryOrder()
			if localPlayer:GetAttribute("IsFixing") == true then return end
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

		localPlayer:GetAttributeChangedSignal("IsCarryingItem"):Connect(updateBackpack)
		localPlayer:GetAttributeChangedSignal("IsFixing"):Connect(updateBackpack)
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
