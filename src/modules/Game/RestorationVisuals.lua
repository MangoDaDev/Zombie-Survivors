local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local GreaseRenderer = require(ReplicatedStorage.Modules.Game.GreaseRenderer)
local PaintRenderer = require(ReplicatedStorage.Modules.Game.PaintRenderer)
local RestorationTargetRenderer = require(ReplicatedStorage.Modules.Game.RestorationTargetRenderer)

local RestorationVisuals = {}

local function GetStepState(FixingState, StepId)
	return type(FixingState) == "table" and type(FixingState.Steps) == "table" and FixingState.Steps[StepId] or nil
end

function RestorationVisuals.Apply(Model: Model, ItemInfo, FixingState)
	if type(FixingState) ~= "table" or FixingState.Completed == true then return end
	local Steps = CleaningConfig.GetStepsForItem(ItemInfo, FixingState)
	for _, Step in Steps do
		if Step.Type == "Paint" then
			local StepState = GetStepState(FixingState, Step.Id)
			if not StepState or StepState.Completed ~= true then
				local Count = if StepState and type(StepState.Remaining) == "number" then StepState.Remaining else PaintRenderer.GetSuggestedCount(Model)
				PaintRenderer.Add(Model, Count, Step.TargetHP, Step.DirtColor, Step.DirtAmountMinimum, Step.DirtAmountMaximum)
			end
		end
	end
	for _, Step in Steps do
		if Step.Type == "Dirt" or Step.Type == "Grease" or Step.Type == "Paint" then continue end
		local StepState = GetStepState(FixingState, Step.Id)
		if StepState and StepState.Completed == true then continue end
		if Step.Type == "Polish" then
			local PaintState = GetStepState(FixingState, "SprayPaint")
			if PaintState and PaintState.Completed ~= true then continue end
		end
		local Count = if StepState and type(StepState.Remaining) == "number"
			then StepState.Remaining
			else RestorationTargetRenderer.GetSuggestedCount(Model, Step.Type)
		RestorationTargetRenderer.Add(Model, Step.Type, Count, Step.TargetHP, Step)
	end
	for _, Step in Steps do
		if Step.Type == "Grease" then
			local StepState = GetStepState(FixingState, Step.Id)
			if not StepState or StepState.Completed ~= true then
				local Count = if StepState and type(StepState.Remaining) == "number" then StepState.Remaining else GreaseRenderer.GetSuggestedCount(Model)
				GreaseRenderer.Add(Model, Count, Step.TargetHP, Step.PatchColor, Step.PatchTransparency)
			end
		end
	end
	for _, Step in Steps do
		if Step.Type == "Dirt" then
			local StepState = GetStepState(FixingState, Step.Id)
			if not StepState or StepState.Completed ~= true then
				local Count = if StepState and type(StepState.Remaining) == "number"
					then StepState.Remaining
					else FixingState.Remaining or DirtRenderer.GetSuggestedCount(Model)
				DirtRenderer.Add(Model, Count, ItemInfo.DirtHP)
			end
		end
	end
end

return RestorationVisuals
