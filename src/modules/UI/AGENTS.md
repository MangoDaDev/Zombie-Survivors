# Shared UI utility guidance

- This category contains presentation-only data and effects that can be used by client UI or other visual systems. Vide components still belong under `src/UI`.
- `Images.lua` is the imported image asset-ID catalog. Reuse its named entries instead of scattering duplicate IDs through components.
- `PlayVFX.lua` clones effect templates, starts supported particles, beams, trails, and sounds, and schedules cleanup. Pass a Studio-owned template rather than mutating the source asset.
- Assets under `ReplicatedStorage.Assets` are reusable by default, including every sound in `Assets.Sounds`, unless an asset name, attribute, containing-folder instruction, or `AGENTS` value says otherwise.
- Inspect the live asset hierarchy through Studio MCP before adding a new reference because Assets is Studio-owned and not mapped by Rojo.

FOLLOW THIS UI STYLE: 'STUD' UI STYLE

Example code: White Rectangular Button Example

local function WhiteRectangularButtonExample()
	return
    create "Frame" {
        Name = "WhiteRectangularButtonExample",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BorderSizePixel = 0,
        
        create "UICorner" {
            CornerRadius = UDim.new(0.05, 0),
        },
        create "UIStroke" {
            Color = Color3.fromRGB(30, 30, 30),
            Thickness = 3,
            Transparency = 0.07999999821186066,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            
            create "UIGradient" {
                Rotation = 12,
                Name = "ThemeGradient",
            },
        },
        create "ImageLabel" {
            Image = "rbxassetid://85440167673906",
            ImageTransparency = 0.7200000286102295,
            Name = "Glow",
            Size = UDim2.new(1.4, 0, 1.8, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            
            create "UIGradient" {
                Name = "ThemeGradient",
            },
        },
        create "Frame" {
            Name = "Content",
            Size = UDim2.new(1, 0, 0.86, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(87, 136, 171),
            ZIndex = 2,
            
            create "UICorner" {
                CornerRadius = UDim.new(0.05, 0),
            },
            create "UIGradient" {
                Rotation = 90,
            },
            create "ImageLabel" {
                Image = "rbxassetid://6927295847",
                ImageTransparency = 0.7400000095367432,
                ScaleType = Enum.ScaleType.Tile,
                Name = "StudTexture",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                ZIndex = 3,
            },
            create "TextLabel" {
                Text = "Text",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Cartoon,
                TextWrapped = true,
                TextScaled = true,
                Name = "ButtonText",
                Size = UDim2.new(0.851955, 0, 0.840779, 0),
                Position = UDim2.new(0.070409, 0, 0.488095, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                ZIndex = 5,
                
                create "UIStroke" {
                    Thickness = 2,
                    Transparency = 0.10000000149011612,
                },
            },
            create "UIStroke" {
                Color = Color3.fromRGB(255, 255, 255),
                Thickness = 3.799999952316284,
                Transparency = 0.550000011920929,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Name = "InsideStroke",
                
                create "UIGradient" {
                    Rotation = -90,
                },
            },
        },
        create "TextButton" {
            Text = "",
            AutoButtonColor = false,
            Name = "Sensor",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            ZIndex = 20,
        },
        create "UIAspectRatioConstraint" {
            AspectRatio = 3,
        },
    }
end

return WhiteRectangularButtonExample

- THIS IS ONLY AN EXAMPLE. Feel free to add other stuff like images if needed.

- Make sure to lerp the dark outlines/background to the intended color a bit but do not call it in live for this use

- Use slight gradients that make sense and are the same style across the codebase

- Create Elements for specific things like buttons.

