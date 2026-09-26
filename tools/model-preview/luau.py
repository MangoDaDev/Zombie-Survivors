"""Export exact, validated construction data; never execute pasted Luau locally."""
import json
from schema import parse_json, ValidationError

PREFIX = '-- model-preview construction v1\n-- Edit the JSON payload; keep the construction adapter unchanged.\nlocal definition = game:GetService("HttpService"):JSONDecode('
BODY = ''')
-- This adapter creates only Models and Parts. It never creates permanent scripts.
-- CFrames are world-space: parenting and WorldPivot must not transform geometry.
local instancesById = {}
local deferredModels = {}
local function build(node)
    local instance = Instance.new(node.class)
    instance.Name = node.name
    if node.id then instancesById[node.id] = instance end
    for property, value in node.properties do
        if property == "PrimaryPart" then
            -- Resolve references after all descendants have been created.
        elseif property == "CFrame" or property == "WorldPivot" or property == "PivotOffset" then
            instance[property] = CFrame.new(table.unpack(value))
        elseif property == "Size" then
            instance.Size = Vector3.new(table.unpack(value))
        elseif property == "Color" then
            instance.Color = Color3.new(table.unpack(value))
        elseif property == "Material" then
            instance.Material = Enum.Material[value]
        elseif property == "Shape" then
            instance.Shape = Enum.PartType[value]
        elseif string.sub(property, -7) == "Surface" then
            instance[property] = Enum.SurfaceType[value]
        elseif property == "CustomPhysicalProperties" then
            instance.CustomPhysicalProperties = PhysicalProperties.new(value.Density, value.Friction,
                value.Elasticity, value.FrictionWeight, value.ElasticityWeight)
        else
            instance[property] = value
        end
    end
    for _, child in node.children do build(child).Parent = instance end
    if node.class == "Model" then table.insert(deferredModels, {instance, node.properties.PrimaryPart}) end
    return instance
end
local model = build(definition.root)
for _, entry in deferredModels do
    if entry[2] then entry[1].PrimaryPart = instancesById[entry[2]] end
end
-- The caller owns parenting and cleanup. No game assets are changed automatically.
return model
'''


def canonical_definition(model):
    def convert(node):
        result = dict(name=node["name"], **{"class": node["className"]},
                      properties=node["properties"], children=[convert(c) for c in node["children"]])
        if node["id"] is not None:
            result["id"] = node["id"]
        return result
    return dict(version=1, root=convert(model["root"]))


def export_luau(model):
    payload = json.dumps(canonical_definition(model), ensure_ascii=True, sort_keys=True, indent=2)
    equal = "="
    while "]"+equal+"]" in payload:
        equal += "="
    return PREFIX + "["+equal+"[" + payload + "]"+equal+"]" + BODY


def parse_source(source):
    source = source.lstrip("\ufeff")
    if source.lstrip().startswith("{"):
        return parse_json(source)
    if not source.startswith(PREFIX):
        raise ValidationError("input: expected JSON or model-preview exported construction.luau; arbitrary Luau is unsupported and never executed")
    remaining = source[len(PREFIX):]
    import re
    match = re.match(r"\[(=+)\[", remaining)
    if not match:
        raise ValidationError("Luau payload: expected long-bracket JSON string")
    end = "]"+match[1]+"]"
    index = remaining.find(end, match.end())
    if index < 0 or remaining[index+len(end):].replace("\r\n", "\n") != BODY:
        raise ValidationError("Luau adapter changed: rendering its embedded JSON would no longer guarantee the same construction; restore the generated adapter")
    return parse_json(remaining[match.end():index])
