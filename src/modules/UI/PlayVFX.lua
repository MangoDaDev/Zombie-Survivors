local Debris = game:GetService("Debris")

local DEFAULT_LIFETIME = 5

local function startEffect(instance: Instance): number
	if instance:IsA("ParticleEmitter") then
		return if instance.Enabled then instance.Lifetime.Max else 0
	elseif instance:IsA("Beam") or instance:IsA("Trail") then
		instance.Enabled = true
		return DEFAULT_LIFETIME
	elseif instance:IsA("Sound") then
		instance:Play()
		return math.max(instance.TimeLength, DEFAULT_LIFETIME)
	end

	return 0
end

local function PlayVFX(template: Instance, parent: Instance): { Instance }
	local templates = template:GetChildren()
	if #templates == 0 then
		templates = { template }
	end

	local clones = {}
	for _, child in templates do
		local clone = child:Clone()
		clone.Parent = parent
		table.insert(clones, clone)

		local lifetime = startEffect(clone)
		for _, descendant in clone:GetDescendants() do
			lifetime = math.max(lifetime, startEffect(descendant))
		end

		Debris:AddItem(clone, math.max(lifetime + 1, DEFAULT_LIFETIME))
	end

	return clones
end

return PlayVFX
