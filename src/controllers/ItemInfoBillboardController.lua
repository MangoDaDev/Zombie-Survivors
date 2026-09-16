local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemInteractionConfig = require(ReplicatedStorage.Modules.Game.ItemInteractionConfig)

local ItemInfoBillboardController = {}

local ITEM_INFO_TAG = "ItemInfoBillboard"
local CLOSE_DISTANCE = 35
local MEDIUM_DISTANCE = ItemInteractionConfig.ItemBillboardMaxDistance
local MAX_VISIBLE_BILLBOARDS = 4
local OVERLAP_DISTANCE = 130
local UPDATE_INTERVAL = 0.2

local UpdateConnection: RBXScriptConnection?
local ElapsedTime = 0

local function SetDisclosure(Billboard: BillboardGui, Disclosure: string)
	Billboard.Enabled = Disclosure ~= "Hidden"
	if not Billboard.Enabled then return end

	local IsClose = Disclosure == "Close"
	local GuestPay = Billboard:FindFirstChild("GuestPay")
	local Price = Billboard:FindFirstChild("Price")
	local FixIcons = Billboard:FindFirstChild("FixIcons")
	if GuestPay and GuestPay:IsA("GuiObject") then GuestPay.Visible = IsClose end
	if Price and Price:IsA("GuiObject") then Price.Visible = IsClose end
	if FixIcons and FixIcons:IsA("GuiObject") then FixIcons.Visible = IsClose end
end

local function UpdateBillboards()
	local Camera = workspace.CurrentCamera
	if not Camera then return end

	local BillboardDistances = {}
	for _, Billboard in CollectionService:GetTagged(ITEM_INFO_TAG) do
		if not Billboard:IsA("BillboardGui") or not Billboard:IsDescendantOf(workspace) then continue end
		local Adornee = Billboard.Adornee
		if not Adornee or not Adornee:IsA("BasePart") then
			SetDisclosure(Billboard, "Hidden")
			continue
		end
		table.insert(BillboardDistances, {
			Billboard = Billboard,
			Distance = (Camera.CFrame.Position - Adornee.Position).Magnitude,
			WorldPosition = Adornee.Position + Billboard.StudsOffsetWorldSpace,
		})
	end

	table.sort(BillboardDistances, function(First, Second)
		return First.Distance < Second.Distance
	end)

	local VisibleScreenPositions = {}
	for Index, Entry in BillboardDistances do
		local Disclosure = "Hidden"
		if Index <= MAX_VISIBLE_BILLBOARDS and Entry.Distance <= MEDIUM_DISTANCE then
			Disclosure = if Entry.Distance <= CLOSE_DISTANCE then "Close" else "Medium"
			local ScreenPosition, IsOnScreen = Camera:WorldToViewportPoint(Entry.WorldPosition)
			if IsOnScreen then
				for _, ExistingPosition in VisibleScreenPositions do
					if (Vector2.new(ScreenPosition.X, ScreenPosition.Y) - ExistingPosition).Magnitude < OVERLAP_DISTANCE then
						Disclosure = if Disclosure == "Close" then "Medium" else "Hidden"
						break
					end
				end
				if Disclosure ~= "Hidden" then
					table.insert(VisibleScreenPositions, Vector2.new(ScreenPosition.X, ScreenPosition.Y))
				end
			end
		end
		SetDisclosure(Entry.Billboard, Disclosure)
	end
end

function ItemInfoBillboardController.Init()
	if UpdateConnection then return end
	UpdateConnection = RunService.Heartbeat:Connect(function(DeltaTime)
		ElapsedTime += DeltaTime
		if ElapsedTime < UPDATE_INTERVAL then return end
		ElapsedTime = 0
		UpdateBillboards()
	end)
	UpdateBillboards()
end

return ItemInfoBillboardController
