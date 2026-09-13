local DirtRenderer = {}

local DirtColor = Color3.fromRGB(76, 50, 32)
local DirtSize = 0.16

function DirtRenderer.Add(Model: Model, Count: number, HP: number?): Folder?
	DirtRenderer.Clear(Model)
	local Root = Model.PrimaryPart or Model:FindFirstChild("BoundingBox") or Model:FindFirstChild("Handle")
	if Root == nil or not Root:IsA("BasePart") or Count <= 0 then
		return nil
	end

	local Folder = Instance.new("Folder")
	Folder.Name = "Dirt"
	Folder.Parent = Model
	local RandomGenerator = Random.new(tonumber(string.byte(Model.Name, 1)) or 1)
	for Index = 1, Count do
		local LocalPosition = Vector3.new(
			RandomGenerator:NextNumber(-0.5, 0.5) * Root.Size.X,
			RandomGenerator:NextNumber(-0.5, 0.5) * Root.Size.Y,
			RandomGenerator:NextNumber(-0.5, 0.5) * Root.Size.Z
		)
		local Face = Index % 6
		if Face == 0 then LocalPosition = Vector3.new(Root.Size.X / 2, LocalPosition.Y, LocalPosition.Z)
		elseif Face == 1 then LocalPosition = Vector3.new(-Root.Size.X / 2, LocalPosition.Y, LocalPosition.Z)
		elseif Face == 2 then LocalPosition = Vector3.new(LocalPosition.X, Root.Size.Y / 2, LocalPosition.Z)
		elseif Face == 3 then LocalPosition = Vector3.new(LocalPosition.X, -Root.Size.Y / 2, LocalPosition.Z)
		elseif Face == 4 then LocalPosition = Vector3.new(LocalPosition.X, LocalPosition.Y, Root.Size.Z / 2)
		else LocalPosition = Vector3.new(LocalPosition.X, LocalPosition.Y, -Root.Size.Z / 2) end

		local Dirt = Instance.new("Part")
		Dirt.Name = "Dirt"
		Dirt.Shape = Enum.PartType.Ball
		Dirt.Size = Vector3.one * DirtSize
		Dirt.Color = DirtColor
		Dirt.Material = Enum.Material.Ground
		Dirt.CanCollide = false
		Dirt.CanQuery = false
		Dirt.CanTouch = false
		Dirt.Massless = true
		Dirt.CFrame = Root.CFrame * CFrame.new(LocalPosition)
		Dirt:SetAttribute("HP", HP or 1)
		Dirt.Parent = Folder
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Root
		Weld.Part1 = Dirt
		Weld.Parent = Dirt
	end
	return Folder
end

function DirtRenderer.Clear(Model: Model)
	local Existing = Model:FindFirstChild("Dirt")
	if Existing then Existing:Destroy() end
end

return DirtRenderer
