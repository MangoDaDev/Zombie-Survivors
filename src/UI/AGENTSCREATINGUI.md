FOLLOW THIS UI STYLE: **"STUD" UI STYLE**

When using a UIAspectRatioConstraint, keep meaningful nonzero responsive Size values on both axes unless a zero axis is explicitly required.

Avoid UITextSizeConstraint and UISizeConstraint where practical; UIAspectRatioConstraint is fine when preserving proportions is useful.

Use a mix of relative Scale values and pixel offsets in UI sizes and positions. Do not design layouts using only pixels or only Scale.

Avoid creating CanvasGroups unless they are needed for scrolling UI. Use Frames or other suitable GuiObjects for ordinary UI, including notifications.

Not everything has to have a background! Only have buttons and stuff with the button background. If no background have stroke.

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
                TileSize = UDim2.new(0, 80, 0, 80),
                Name = "StudTexture",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                ZIndex = 3,
            },
            create "TextLabel" {
                Text = "Text",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                TextWrapped = true,
                TextScaled = true,
                Name = "ButtonText",
                Size = UDim2.new(0.851955, 0, 0.840779, 0),
                Position = UDim2.new(0.070409, 0, 0.488095, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                ZIndex = 5,
                
                create "UIStroke" {
                    Thickness = 0.05999999865889549,
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

local function RebirthMenuExample()
	return
    create "Frame" {
        Name = "RebirthMenuExample",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        ZIndex = 100,
        
        create "Frame" {
            Name = "Background",
            Size = UDim2.new(0.4, 200, 0.4, 200),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(58, 41, 15),
            ZIndex = 60,
            
            create "UICorner" {
                CornerRadius = UDim.new(0.02, 0),
            },
            create "UIStroke" {
                Color = Color3.fromRGB(30, 30, 30),
                Thickness = 0.014999999664723873,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            },
            create "UIAspectRatioConstraint" {
                AspectRatio = 1.6180000305175781,
            },
            create "Frame" {
                Name = "Content",
                Size = UDim2.new(1, 0, 0.835948, 0),
                Position = UDim2.new(0.5, 0, 0.552563, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                
                create "UICorner" {
                    CornerRadius = UDim.new(0.02, 0),
                },
                create "UIStroke" {
                    Color = Color3.fromRGB(30, 30, 30),
                    Thickness = 0.014999999664723873,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                },
                create "UIGradient" {
                    Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(163, 163, 163)), ColorSequenceKeypoint.new(0.0259516, Color3.fromRGB(206, 206, 206)), ColorSequenceKeypoint.new(0.0640138, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))}),
                    Rotation = 90,
                },
                create "ImageLabel" {
                    Image = "rbxassetid://140085487158609",
                    ImageColor3 = Color3.fromRGB(65, 52, 29),
                    ImageTransparency = 0.8399999737739563,
                    TileSize = UDim2.new(0.3, 0, 0.75, 0),
                    Size = UDim2.new(0.956825, 0, 0.833117, 0),
                    Position = UDim2.new(0.499583, 0, 0.463743, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 2,
                },
                create "Frame" {
                    Name = "Changes",
                    Size = UDim2.new(0.897564, 0, 0.731498, 0),
                    Position = UDim2.new(0.5, 0, 0.486843, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 3,
                    
                    create "TextLabel" {
                        Text = "1000",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 14,
                        FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextScaled = true,
                        Name = "CoinsBefore",
                        Size = UDim2.new(0.315518, 0, 0.229606, 0),
                        Position = UDim2.new(0.249757, 0, 0.112362, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        
                        create "UIStroke" {
                            Color = Color3.fromRGB(21, 21, 21),
                            Thickness = 0.05999999865889549,
                        },
                    },
                    create "TextLabel" {
                        Text = "1000",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 14,
                        FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextScaled = true,
                        Name = "BucksBefore",
                        Size = UDim2.new(0.315518, 0, 0.229606, 0),
                        Position = UDim2.new(0.249757, 0, 0.343979, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        
                        create "UIStroke" {
                            Color = Color3.fromRGB(21, 21, 21),
                            Thickness = 0.05999999865889549,
                        },
                    },
                    create "TextLabel" {
                        Text = "Jungle",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 14,
                        FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextScaled = true,
                        Name = "AreasBefore",
                        Size = UDim2.new(0.315518, 0, 0.229606, 0),
                        Position = UDim2.new(0.249757, 0, 0.573569, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        
                        create "UIStroke" {
                            Color = Color3.fromRGB(21, 21, 21),
                            Thickness = 0.05999999865889549,
                        },
                    },
                    create "TextLabel" {
                        Text = "Plains",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 14,
                        FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextScaled = true,
                        Name = "AreasAfter",
                        Size = UDim2.new(0.315518, 0, 0.229606, 0),
                        Position = UDim2.new(0.842306, 0, 0.572105, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        
                        create "UIStroke" {
                            Color = Color3.fromRGB(21, 21, 21),
                            Thickness = 0.05999999865889549,
                        },
                        create "UIGradient" {},
                    },
                    create "TextLabel" {
                        Text = "0",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 14,
                        FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextScaled = true,
                        Name = "BucksAfter",
                        Size = UDim2.new(0.315518, 0, 0.229606, 0),
                        Position = UDim2.new(0.842306, 0, 0.342516, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        
                        create "UIStroke" {
                            Color = Color3.fromRGB(21, 21, 21),
                            Thickness = 0.05999999865889549,
                        },
                    },
                    create "TextLabel" {
                        Text = "0",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 14,
                        FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextScaled = true,
                        Name = "CoinsAfter",
                        Size = UDim2.new(0.315518, 0, 0.229606, 0),
                        Position = UDim2.new(0.842306, 0, 0.110899, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        
                        create "UIStroke" {
                            Color = Color3.fromRGB(21, 21, 21),
                            Thickness = 0.05999999865889549,
                        },
                    },
                    create "ImageLabel" {
                        Image = "rbxassetid://117589844207603",
                        Size = UDim2.new(0.09, 0, 0.215, 0),
                        Position = UDim2.new(-0.00334774, 0, 0.000633695, 0),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                    },
                    create "ImageLabel" {
                        Image = "rbxassetid://85844365023723",
                        Size = UDim2.new(0.09, 0, 0.215, 0),
                        Position = UDim2.new(-0.00334774, 0, 0.228973, 0),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                    },
                    create "ImageLabel" {
                        Image = "rbxassetid://97437550220113",
                        Size = UDim2.new(0.09, 0, 0.215, 0),
                        Position = UDim2.new(-0.00334774, 0, 0.461354, 0),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                    },
                    create "ImageLabel" {
                        Image = "rbxassetid://97437550220113",
                        Size = UDim2.new(0.09, 0, 0.215, 0),
                        Position = UDim2.new(0.579158, 0, 0.459031, 0),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                    },
                    create "ImageLabel" {
                        Image = "rbxassetid://85844365023723",
                        Size = UDim2.new(0.09, 0, 0.215, 0),
                        Position = UDim2.new(0.579158, 0, 0.22665, 0),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                    },
                    create "ImageLabel" {
                        Image = "rbxassetid://117589844207603",
                        Size = UDim2.new(0.09, 0, 0.215, 0),
                        Position = UDim2.new(0.579158, 0, -0.00168922, 0),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                    },
                    create "ImageLabel" {
                        Image = "rbxassetid://123892753905134",
                        Size = UDim2.new(0.135461, 0, 0.32387, 0),
                        Position = UDim2.new(0.407236, 0, 0.277643, 0),
                        Rotation = 90,
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                    },
                    create "ImageLabel" {
                        Image = "rbxassetid://140615134556624",
                        Size = UDim2.new(0.125151, 0, 0.303903, 0),
                        Position = UDim2.new(-0.00334774, 0, 0.699776, 0),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                    },
                    create "TextLabel" {
                        Text = "x6",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 14,
                        FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextScaled = true,
                        Name = "LuckBefore",
                        Size = UDim2.new(0.305475, 0, 0.270016, 0),
                        Position = UDim2.new(0.284908, 0, 0.84836, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        
                        create "UIStroke" {
                            Color = Color3.fromRGB(21, 21, 21),
                            Thickness = 0.05999999865889549,
                        },
                    },
                    create "TextLabel" {
                        Text = "x7",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 14,
                        FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextScaled = true,
                        Name = "LuckAfter",
                        Size = UDim2.new(0.305475, 0, 0.270016, 0),
                        Position = UDim2.new(0.847328, 0, 0.84836, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        
                        create "UIStroke" {
                            Color = Color3.fromRGB(21, 21, 21),
                            Thickness = 0.05999999865889549,
                        },
                        create "UIGradient" {
                            Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 247, 0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(203, 189, 82))}),
                            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.660093, 0, 0), NumberSequenceKeypoint.new(0.820186, 0.24375, 0), NumberSequenceKeypoint.new(1, 0.25625, 0)}),
                            Rotation = 90,
                        },
                    },
                    create "ImageLabel" {
                        Image = "rbxassetid://140615134556624",
                        Size = UDim2.new(0.125151, 0, 0.303903, 0),
                        Position = UDim2.new(0.559072, 0, 0.699776, 0),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                    },
                    create "TextLabel" {
                        Text = "Rebirth 0",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 14,
                        FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextScaled = true,
                        Name = "RebirthsBefore",
                        Size = UDim2.new(0.315518, 0, 0.121835, 0),
                        Position = UDim2.new(0.154346, 0, -0.060783, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        
                        create "UIStroke" {
                            Color = Color3.fromRGB(21, 21, 21),
                            Thickness = 0.05999999865889549,
                        },
                    },
                    create "TextLabel" {
                        Text = "Rebirth 1",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 14,
                        FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextScaled = true,
                        Name = "RebirthsAfter",
                        Size = UDim2.new(0.315518, 0, 0.121835, 0),
                        Position = UDim2.new(0.736852, 0, -0.060783, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        
                        create "UIStroke" {
                            Color = Color3.fromRGB(21, 21, 21),
                            Thickness = 0.05999999865889549,
                        },
                        create "UIGradient" {
                            Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 247, 0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(203, 189, 82))}),
                            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.660093, 0, 0), NumberSequenceKeypoint.new(0.820186, 0.24375, 0), NumberSequenceKeypoint.new(1, 0.25625, 0)}),
                            Rotation = 90,
                        },
                    },
                },
                create "ImageLabel" {
                    Image = "rbxassetid://6927295847",
                    ImageTransparency = 0.7400000095367432,
                    ScaleType = Enum.ScaleType.Tile,
                    TileSize = UDim2.new(0, 80, 0, 80),
                    Name = "StudTexture",
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    ZIndex = 2,
                },
                create "Frame" {
                    Name = "WhiteRectangularButtonExample",
                    Size = UDim2.new(0.2, 0, 0.2, 0),
                    Position = UDim2.new(0.5, 0, 0.93, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
                    BorderSizePixel = 0,
                    ZIndex = 5,
                    
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
                            TileSize = UDim2.new(0, 80, 0, 80),
                            Name = "StudTexture",
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            ZIndex = 3,
                        },
                        create "TextLabel" {
                            Text = "Rebirth",
                            TextColor3 = Color3.fromRGB(255, 255, 255),
                            FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                            TextWrapped = true,
                            TextScaled = true,
                            Name = "ButtonText",
                            Size = UDim2.new(0.851955, 0, 0.840779, 0),
                            Position = UDim2.new(0.070409, 0, 0.488095, 0),
                            AnchorPoint = Vector2.new(0, 0.5),
                            BackgroundTransparency = 1,
                            ZIndex = 5,
                            
                            create "UIStroke" {
                                Thickness = 0.05999999865889549,
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
                        AspectRatio = 4,
                    },
                },
                create "UIStroke" {
                    Color = Color3.fromRGB(255, 255, 255),
                    Thickness = 0.009999999776482582,
                    Transparency = 0.550000011920929,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    Name = "InsideStroke",
                    
                    create "UIGradient" {
                        Rotation = -90,
                    },
                },
            },
            create "UIGradient" {
                Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.934256, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(199, 199, 199))}),
                Rotation = 90,
            },
            create "Frame" {
                Name = "Title",
                Size = UDim2.new(1.019, 0, 0.161, 0),
                Position = UDim2.new(0.5, 0, 0.0629793, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                
                create "UICorner" {
                    CornerRadius = UDim.new(0.07, 0),
                },
                create "UIStroke" {
                    Color = Color3.fromRGB(30, 30, 30),
                    Thickness = 0.09000000357627869,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                },
                create "UIStroke" {
                    Color = Color3.fromRGB(255, 255, 255),
                    Thickness = 0.05000000074505806,
                    Transparency = 0.699999988079071,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    
                    create "UIGradient" {
                        Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.535492, 0.291925, 0), NumberSequenceKeypoint.new(1, 0.521739, 0)}),
                        Rotation = 90,
                    },
                },
                create "ImageLabel" {
                    Image = "rbxassetid://6927295847",
                    ImageColor3 = Color3.fromRGB(0, 0, 0),
                    ImageTransparency = 0.9399999976158142,
                    ScaleType = Enum.ScaleType.Tile,
                    TileSize = UDim2.new(0, 80, 0, 80),
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                },
                create "TextLabel" {
                    Text = "Rebirth",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 14,
                    FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextScaled = true,
                    Size = UDim2.new(0.97, 0, 1.05625, 0),
                    Position = UDim2.new(0.5, 0, 0.515625, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    
                    create "UIStroke" {
                        Color = Color3.fromRGB(21, 21, 21),
                        Thickness = 0.05999999865889549,
                    },
                },
                create "UIGradient" {},
                create "Frame" {
                    Name = "WhiteCloseButtonExample",
                    Size = UDim2.new(0.1, 0, 0.8, 0),
                    Position = UDim2.new(0.94, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
                    BorderSizePixel = 0,
                    ZIndex = 6,
                    
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
                            TileSize = UDim2.new(0, 80, 0, 80),
                            Name = "StudTexture",
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            ZIndex = 3,
                        },
                        create "TextLabel" {
                            Text = "X",
                            TextColor3 = Color3.fromRGB(255, 255, 255),
                            FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
                            TextWrapped = true,
                            TextScaled = true,
                            Name = "ButtonText",
                            Size = UDim2.new(0.851955, 0, 0.840779, 0),
                            Position = UDim2.new(0.070409, 0, 0.488095, 0),
                            AnchorPoint = Vector2.new(0, 0.5),
                            BackgroundTransparency = 1,
                            ZIndex = 5,
                            
                            create "UIStroke" {
                                Thickness = 0.05999999865889549,
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
                    create "UIAspectRatioConstraint" {},
                },
                create "UIStroke" {
                    Color = Color3.fromRGB(255, 255, 255),
                    Thickness = 0.029999999329447746,
                    Transparency = 0.550000011920929,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    Name = "InsideStroke",
                    
                    create "UIGradient" {
                        Rotation = -90,
                    },
                },
            },
        },
    }
end

return RebirthMenuExample

Use the provided UI code as the main visual reference. Match its overall appearance, structure, depth, texture, outlines, gradients, typography, and proportions across any UI you create or modify.

The example is **only a reference**, not something that must be copied exactly. Adapt the style appropriately depending on whether the element is a button, panel, card, upgrade node, tab, notification, progress bar, etc.

Additional rules:

* Keep the style consistent across the entire UI/codebase.
* Use the same general stud texture, layered depth, rounded corners, strokes, and subtle gradients demonstrated in the reference.
* Feel free to add icons, images, labels, badges, glows, or other elements when they improve the UI.
* Do not overuse effects. Keep gradients, glows, and animations subtle.
* Dark outlines/backing layers should be slightly lerped toward the intended theme color instead of always being generic black/dark gray.
* Do **not** calculate this lerp continuously/live. Use the resulting color as a normal static UI color.
* Different theme colors should still use the same STUD structure and styling.
* Keep spacing, padding, text sizing, stroke thickness, corner radius, and visual hierarchy consistent.
* Interactive elements should have appropriate hover, pressed, disabled, selected, and notification states when needed.
* Reuse existing hover/click/animation modules if the codebase already contains them instead of duplicating functionality.
* Preserve existing functionality when restyling UI. Do not break logic just to change appearance.
* Prefer responsive sizing and layouts so the UI works across different screen sizes.
* Use clear internal names such as `Content`, `StudTexture`, `Glow`, `Icon`, `Label`, `Cost`, `Sensor`, etc.

### Reusable Elements

Create reusable **Elements/components** for UI structures that appear repeatedly.

For example:

* Standard buttons
* Icon buttons
* Panels
* Cards
* Upgrade nodes
* Tabs
* Cost/currency displays
* Notification badges
* Locked overlays
* Progress bars

Do not rebuild the same styled button or panel separately in multiple places.

Reusable Elements should accept the values they need, such as text, icon, theme color, size, price, selected state, locked state, disabled state, callbacks, etc., while keeping the actual STUD styling controlled internally.

Avoid over-engineering or creating components for tiny one-off pieces.

### Style Consistency

When adding a new UI element, first determine which existing STUD Element it should use or extend.

Do not create a completely different visual style for individual screens.

Do not use weak-key tables as the sole ownership registry for live Instance-backed UI. Keep explicit ownership, clean it up when the Instance is removed, and deduplicate against the actual hierarchy before creating another UI instance.

The final result should make every UI feel like it belongs to the same **STUD design system**, while still allowing different UI types to have layouts appropriate to their purpose.

