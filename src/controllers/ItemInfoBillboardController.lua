local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemInteractionConfig = require(ReplicatedStorage.Modules.Game.ItemInteractionConfig)

local ItemInfoBillboardController = {}

local ITEM_INFO_TAG = "ItemInfoBillboard"
local MAX_VISIBLE_BILLBOARDS = 4
local OVERLAP_DISTANCE = 130
local UPDATE_INTERVAL = 0.2

local UpdateConnection: RBXScriptConnection?
local ElapsedTime = 0

local function SetVisible(Billboard: BillboardGui, IsVisible: boolean)
	-- The complete item information panel shares one visibility decision and distance.
	Billboard.Enabled = IsVisible
end

local function UpdateBillboards()
	local Camera = workspace.CurrentCamera
	if not Camera then return end

	local BillboardDistances = {}
	for _, Billboard in CollectionService:GetTagged(ITEM_INFO_TAG) do
		if not Billboard:IsA("BillboardGui") or not Billboard:IsDescendantOf(workspace) then continue end
		local Adornee = Billboard.Adornee
		if not Adornee or not Adornee:IsA("BasePart") then
			SetVisible(Billboard, false)
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
		local IsVisible = false
		if Index <= MAX_VISIBLE_BILLBOARDS and Entry.Distance <= ItemInteractionConfig.ItemBillboardMaxDistance then
			IsVisible = true
			local ScreenPosition, IsOnScreen = Camera:WorldToViewportPoint(Entry.WorldPosition)
			if IsOnScreen then
				for _, ExistingPosition in VisibleScreenPositions do
					if (Vector2.new(ScreenPosition.X, ScreenPosition.Y) - ExistingPosition).Magnitude < OVERLAP_DISTANCE then
						IsVisible = false
						break
					end
				end
				if IsVisible then
					table.insert(VisibleScreenPositions, Vector2.new(ScreenPosition.X, ScreenPosition.Y))
				end
			end
		end
		SetVisible(Entry.Billboard, IsVisible)
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
