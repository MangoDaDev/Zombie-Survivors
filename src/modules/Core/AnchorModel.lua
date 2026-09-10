local function setAnchored(instance: Instance, anchored: boolean)
	if instance:IsA("BasePart") then
		instance.Anchored = anchored
	end
end

local function AnchorModel(root: Instance, anchored: boolean?)
	local shouldAnchor = if anchored == nil then true else anchored

	setAnchored(root, shouldAnchor)
	for _, descendant in root:GetDescendants() do
		setAnchored(descendant, shouldAnchor)
	end
end

return AnchorModel
