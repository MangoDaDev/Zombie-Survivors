local ClassAccessoryFit = {}

-- The authored block headpieces are measured around a 1.72 x 1 x 0.96 head.
-- Fit each axis independently so they hug both classic heads and narrower avatar MeshParts.
local REFERENCE_HEAD_SIZE = Vector3.new(1.72, 1, 0.96)

function ClassAccessoryFit.FitToHead(accessory: Model, head: BasePart)
	local mount = accessory.PrimaryPart
	if not mount then return end
	local pivot = accessory:GetPivot()
	local scale = Vector3.new(
		head.Size.X / REFERENCE_HEAD_SIZE.X,
		head.Size.Y / REFERENCE_HEAD_SIZE.Y,
		head.Size.Z / REFERENCE_HEAD_SIZE.Z
	)
	local parts = {}
	for _, descendant in accessory:GetDescendants() do
		if descendant:IsA("WeldConstraint") then
			-- Rebuild welds after resizing; old offsets were authored for the reference head.
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local relative = pivot:ToObjectSpace(descendant.CFrame)
			table.insert(parts, {
				part = descendant,
				size = descendant.Size,
				position = relative.Position,
				rotation = relative - relative.Position,
			})
		end
	end
	for _, entry in parts do
		local part = entry.part
		part.Size = Vector3.new(entry.size.X * scale.X, entry.size.Y * scale.Y, entry.size.Z * scale.Z)
		part.CFrame = pivot * CFrame.new(entry.position * scale) * entry.rotation
		if part ~= mount then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "MountWeld"
			weld.Part0 = mount
			weld.Part1 = part
			weld.Parent = mount
		end
	end
	accessory:PivotTo(head.CFrame)
end

return ClassAccessoryFit
