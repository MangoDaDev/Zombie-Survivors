local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local indexes = Vide.indexes
local source = Vide.source
local spring = Vide.spring

local HEALTH_GREEN = Color3.fromRGB(69, 205, 105)
local HEALTH_YELLOW = Color3.fromRGB(235, 180, 60)
local HEALTH_RED = Color3.fromRGB(220, 75, 75)
local OUTLINE = Color3.fromRGB(15, 20, 18)

local function playerHealthBar(player: Player, inGame)
	local adornee = source(nil :: BasePart?)
	local health = source(0)
	local progress = source(0)
	local hasHumanoid = source(false)
	local smoothProgress = spring(progress, 0.18, 0.9)
	local humanoid: Humanoid? = nil
	local originalHealthDisplayType: Enum.HumanoidHealthDisplayType? = nil
	local healthConnection: RBXScriptConnection? = nil
	local maximumHealthConnection: RBXScriptConnection? = nil
	local characterConnections: { RBXScriptConnection } = {}

	local function disconnectHumanoid()
		if healthConnection then
			healthConnection:Disconnect()
			healthConnection = nil
		end
		if maximumHealthConnection then
			maximumHealthConnection:Disconnect()
			maximumHealthConnection = nil
		end
		if humanoid and originalHealthDisplayType then
			humanoid.HealthDisplayType = originalHealthDisplayType
		end
		humanoid = nil
		originalHealthDisplayType = nil
		hasHumanoid(false)
	end

	local function updateHealth()
		if not humanoid then
			return
		end
		local maximumHealth = math.max(humanoid.MaxHealth, 1)
		local currentHealth = math.clamp(humanoid.Health, 0, maximumHealth)
		health(currentHealth)
		progress(currentHealth / maximumHealth)
	end

	local function bindCharacter(character: Model?)
		for _, connection in characterConnections do
			connection:Disconnect()
		end
		table.clear(characterConnections)
		disconnectHumanoid()
		adornee(nil)
		if not character then
			return
		end

		local function refreshCharacter()
			local head = character:FindFirstChild("Head")
			adornee(if head and head:IsA("BasePart") then head else nil)
			local nextHumanoid = character:FindFirstChildOfClass("Humanoid")
			if nextHumanoid == humanoid then
				return
			end
			disconnectHumanoid()
			if not nextHumanoid then
				return
			end
			humanoid = nextHumanoid
			-- The requested custom bar replaces the native overhead health display, avoiding two bars.
			originalHealthDisplayType = nextHumanoid.HealthDisplayType
			nextHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			updateHealth()
			hasHumanoid(true)
			healthConnection = nextHumanoid.HealthChanged:Connect(updateHealth)
			maximumHealthConnection = nextHumanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)
		end

		local function onChildChanged(child: Instance)
			if child.Name == "Head" or child:IsA("Humanoid") then
				refreshCharacter()
			end
		end
		-- Neither character replication nor streaming guarantees Head and Humanoid arrive together.
		-- Keep these listeners until respawn so streamed-out parts also disable the bar immediately.
		table.insert(characterConnections, character.ChildAdded:Connect(onChildChanged))
		table.insert(characterConnections, character.ChildRemoved:Connect(onChildChanged))
		refreshCharacter()
	end

	local characterAddedConnection = player.CharacterAdded:Connect(bindCharacter)
	local characterRemovingConnection = player.CharacterRemoving:Connect(function()
		bindCharacter(nil)
	end)
	bindCharacter(player.Character)
	cleanup(function()
		characterAddedConnection:Disconnect()
		characterRemovingConnection:Disconnect()
		bindCharacter(nil)
	end)

	local healthColor = derive(function()
		if progress() <= 0.25 then
			return HEALTH_RED
		elseif progress() <= 0.5 then
			return HEALTH_YELLOW
		end
		return HEALTH_GREEN
	end)

	local billboard = create "BillboardGui" {
		Name = "PlayerHealthBar_" .. player.UserId,
		Adornee = adornee,
		AlwaysOnTop = true,
		Enabled = function()
			return inGame() and hasHumanoid() and adornee() ~= nil
		end,
		LightInfluence = 0,
		MaxDistance = 90,
		-- The entire bar, including its children and strokes, scales with world studs, never pixel offsets.
		Size = UDim2.fromScale(3.8, 0.5),
		StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0),
		create "Frame" {
			Name = "Bar",
			-- The empty portion must stay transparent: only a fill, outline, and centered remaining value.
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = OUTLINE,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.07,
			},
			create "Frame" {
				Name = "Fill",
				BackgroundColor3 = healthColor,
				BorderSizePixel = 0,
				Size = function()
					return UDim2.fromScale(math.clamp(smoothProgress(), 0, 1), 1)
				end,
				ZIndex = 2,
			},
			create "TextLabel" {
				Name = "Value",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.9),
				Text = function()
					return tostring(math.ceil(health()))
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 3,
				create "UIStroke" {
					Color = OUTLINE,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.055,
				},
			},
		},
	}
	cleanup(billboard)
	return billboard
end

return function()
	local playerEntries = source({} :: { [Player]: Player })
	local inGame = source(Workspace:FindFirstChild("Game") ~= nil)
	local function addPlayer(player: Player)
		local entries = table.clone(playerEntries())
		entries[player] = player
		playerEntries(entries)
	end
	local function removePlayer(player: Player)
		local entries = table.clone(playerEntries())
		entries[player] = nil
		playerEntries(entries)
	end
	local playerAddedConnection = Players.PlayerAdded:Connect(addPlayer)
	local playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	local function onMapChanged(child: Instance)
		if child.Name == "Game" then
			inGame(Workspace:FindFirstChild("Game") ~= nil)
		end
	end
	local mapAddedConnection = Workspace.ChildAdded:Connect(onMapChanged)
	local mapRemovedConnection = Workspace.ChildRemoved:Connect(onMapChanged)
	cleanup(function()
		playerAddedConnection:Disconnect()
		playerRemovingConnection:Disconnect()
		mapAddedConnection:Disconnect()
		mapRemovedConnection:Disconnect()
		playerEntries({})
	end)

	local folder = create "Folder" {
		Name = "PlayerHealthBars",
		-- Every client renders every player's replicated Humanoid, including its own; health stays server-owned.
		indexes(playerEntries, function(player)
			return playerHealthBar(player(), inGame)
		end),
	}
	cleanup(folder)
	return folder
end
