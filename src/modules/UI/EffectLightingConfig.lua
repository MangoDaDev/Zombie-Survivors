-- All gameplay-effect lights and emissive particles/trails use this shared scale so their
-- authored relative contrast is preserved while the game's overall effect lighting stays halved.
local INTENSITY_SCALE = 0.5

local EffectLightingConfig = {
	IntensityScale = INTENSITY_SCALE,
}

function EffectLightingConfig.Scale(intensity: number): number
	return intensity * INTENSITY_SCALE
end

function EffectLightingConfig.Apply(instance: Instance)
	if instance:IsA("Light") then
		instance.Brightness = EffectLightingConfig.Scale(instance.Brightness)
	elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") then
		instance.LightEmission = EffectLightingConfig.Scale(instance.LightEmission)
	end
end

function EffectLightingConfig.ApplyTree(root: Instance)
	EffectLightingConfig.Apply(root)
	for _, descendant in root:GetDescendants() do
		EffectLightingConfig.Apply(descendant)
	end
end

return table.freeze(EffectLightingConfig)
