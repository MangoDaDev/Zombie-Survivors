local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local Networker = require(ReplicatedStorage.Packages.networker)
local TeleportPlayer = require(ReplicatedStorage.Modules.Game.TeleportPlayer)
local ChatCommandConfig = require(ServerStorage.Controllers.ChatCommand.ChatCommandConfig)
local CharacterController = require(ServerStorage.Controllers.CharacterController)

type CommandContext = {
	Player: Player,
	Args: { string },
	Reply: (message: string, tone: string?) -> (),
	ResolvePlayer: (selector: string?) -> (Player?, string?),
}

export type CommandDefinition = {
	Name: string,
	Aliases: { string },
	Usage: string,
	Description: string,
	Execute: (context: CommandContext) -> (),
}

local ChatCommandController = {}

local chatNetwork
local dataService
local initialized = false
local orderedDefinitions: { CommandDefinition } = {}
local definitionsByName: { [string]: CommandDefinition } = {}
local claimedAliases: { [string]: boolean } = {}
local commandInstances: { TextChatCommand } = {}
local commandConnections: { RBXScriptConnection } = {}
local developerByPlayer: { [Player]: boolean } = {}
local lastCommandAt: { [Player]: number } = {}
local lastRespawnAt: { [Player]: number } = {}
local developerUserIds: { [number]: boolean } = {}

local configuredDeveloperUserIds = ChatCommandConfig.DeveloperUserIds
if type(configuredDeveloperUserIds) ~= "table" then
	configuredDeveloperUserIds = {}
end
for _, userId in configuredDeveloperUserIds do
	if type(userId) == "number" and userId % 1 == 0 then
		developerUserIds[userId] = true
	end
end

local function sendFeedback(player: Player, message: string, tone: string?)
	if chatNetwork and player.Parent == Players then
		chatNetwork:fire(player, "CommandFeedback", string.sub(message, 1, 1000), tone or "Info")
	end
end

local function computeDeveloper(player: Player): boolean
	if ChatCommandConfig.AllowAllInStudio and RunService:IsStudio() then
		return true
	end
	if developerUserIds[player.UserId] then
		return true
	end
	if ChatCommandConfig.AllowExperienceCreator ~= true then
		return false
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	if game.CreatorType == Enum.CreatorType.Group then
		-- Group rank lookup is an external platform request, so failure safely denies access.
		local success, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		local minimumRank = ChatCommandConfig.GroupMinimumDeveloperRank
		return success and type(rank) == "number" and type(minimumRank) == "number" and rank >= minimumRank
	end
	return false
end

local function isDeveloper(player: Player): boolean
	local cached = developerByPlayer[player]
	if cached ~= nil then
		return cached
	end
	local authorized = computeDeveloper(player)
	developerByPlayer[player] = authorized
	return authorized
end

local function resolvePlayer(speaker: Player, selector: string?): (Player?, string?)
	if type(selector) ~= "string" or selector == "" then
		return nil, "A player name is required."
	end

	local loweredSelector = string.lower(selector)
	if loweredSelector == "me" then
		return speaker, nil
	end

	local displayNameMatches = {}
	for _, candidate in Players:GetPlayers() do
		if string.lower(candidate.Name) == loweredSelector then
			return candidate, nil
		end
		if string.lower(candidate.DisplayName) == loweredSelector then
			table.insert(displayNameMatches, candidate)
		end
	end
	if #displayNameMatches == 1 then
		return displayNameMatches[1], nil
	elseif #displayNameMatches > 1 then
		return nil, "That display name belongs to multiple players. Use a username."
	end

	local prefixMatches = {}
	local matchedPlayers: { [Player]: boolean } = {}
	for _, candidate in Players:GetPlayers() do
		local usernameMatches = string.sub(string.lower(candidate.Name), 1, #loweredSelector) == loweredSelector
		local displayNameMatchesPrefix = string.sub(string.lower(candidate.DisplayName), 1, #loweredSelector)
			== loweredSelector
		if (usernameMatches or displayNameMatchesPrefix) and not matchedPlayers[candidate] then
			matchedPlayers[candidate] = true
			table.insert(prefixMatches, candidate)
		end
	end

	if #prefixMatches == 1 then
		return prefixMatches[1], nil
	elseif #prefixMatches > 1 then
		return nil, "That name matches multiple players. Type more of the username."
	end
	return nil, "No player matches that name."
end

local function resolveExactUsername(selector: string?): (Player?, string?)
	if type(selector) ~= "string" or selector == "" then
		return nil, "An exact username is required."
	end
	local loweredSelector = string.lower(selector)
	for _, candidate in Players:GetPlayers() do
		if string.lower(candidate.Name) == loweredSelector then
			return candidate, nil
		end
	end
	return nil, "No online player has that exact username."
end

local function getLiveHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

local function getLiveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end

local function clearMomentum(player: Player)
	local root = getLiveRoot(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function parseArguments(unfilteredText: string): { string }
	local words = {}
	for word in string.gmatch(unfilteredText, "%S+") do
		table.insert(words, word)
	end
	table.remove(words, 1)
	return words
end

local function handleTriggered(definition: CommandDefinition, textSource: TextSource, unfilteredText: string)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if not player or player.Parent ~= Players then
		return
	end

	local now = os.clock()
	if now - (lastCommandAt[player] or -math.huge) < ChatCommandConfig.CommandCooldown then
		return
	end
	lastCommandAt[player] = now

	-- Every command is developer-only and every gameplay/data mutation remains authoritative on the server.
	if not isDeveloper(player) then
		sendFeedback(player, "Only developers can use chat commands.", "Error")
		return
	end

	definition.Execute({
		Player = player,
		Args = parseArguments(unfilteredText),
		Reply = function(message, tone)
			sendFeedback(player, message, tone)
		end,
		ResolvePlayer = function(selector)
			return resolvePlayer(player, selector)
		end,
	})
end

local function bindDefinition(definition: CommandDefinition)
	local command = Instance.new("TextChatCommand")
	command.Name = definition.Name .. "Command"
	command.PrimaryAlias = definition.Aliases[1]
	command.SecondaryAlias = definition.Aliases[2] or ""
	command.AutocompleteVisible = true
	table.insert(commandConnections, command.Triggered:Connect(function(textSource, unfilteredText)
		handleTriggered(definition, textSource, unfilteredText)
	end))
	command.Parent = TextChatService
	table.insert(commandInstances, command)
end

function ChatCommandController.RegisterCommand(definition: CommandDefinition): boolean
	if type(definition) ~= "table"
		or type(definition.Name) ~= "string"
		or definition.Name == ""
		or type(definition.Aliases) ~= "table"
		or #definition.Aliases < 1
		or #definition.Aliases > 2
		or type(definition.Usage) ~= "string"
		or type(definition.Description) ~= "string"
		or type(definition.Execute) ~= "function"
	then
		return false
	end

	local normalizedName = string.lower(definition.Name)
	if definitionsByName[normalizedName] then
		return false
	end
	for _, alias in definition.Aliases do
		local normalizedAlias = string.lower(alias)
		if not string.match(alias, "^/[A-Za-z0-9_%-]+$") or claimedAliases[normalizedAlias] then
			return false
		end
	end

	definitionsByName[normalizedName] = definition
	table.insert(orderedDefinitions, definition)
	for _, alias in definition.Aliases do
		claimedAliases[string.lower(alias)] = true
	end
	if initialized then
		bindDefinition(definition)
	end
	return true
end

local function registerBuiltInCommands()
	ChatCommandController.RegisterCommand({
		Name = "Commands",
		Aliases = { "/commands", "/cmds" },
		Usage = "/commands",
		Description = "List the commands available to you.",
		Execute = function(context)
			local lines = { "Available commands:" }
			for _, definition in orderedDefinitions do
				table.insert(lines, string.format("%s - %s", definition.Usage, definition.Description))
			end
			context.Reply(table.concat(lines, "\n"))
		end,
	})

	ChatCommandController.RegisterCommand({
		Name = "Respawn",
		Aliases = { "/respawn", "/reset" },
		Usage = "/respawn [player]",
		Description = "Respawn yourself or another player.",
		Execute = function(context)
			if #context.Args > 1 then
				context.Reply("Usage: /respawn [player]", "Error")
				return
			end
			local target, resolveError = context.ResolvePlayer(context.Args[1] or "me")
			if not target then
				context.Reply(resolveError or "Player not found.", "Error")
				return
			end
			local now = os.clock()
			if now - (lastRespawnAt[target] or -math.huge) < ChatCommandConfig.RespawnCooldown then
				context.Reply("That player was respawned too recently.", "Error")
				return
			end
			lastRespawnAt[target] = now
			if CharacterController.ReloadCharacter(target) then
				context.Reply(
					if target == context.Player then "Respawned." else "Respawned " .. target.Name .. ".",
					"Success"
				)
			else
				context.Reply("That player could not be respawned right now.", "Error")
			end
		end,
	})

	ChatCommandController.RegisterCommand({
		Name = "Heal",
		Aliases = { "/heal" },
		Usage = "/heal [player]",
		Description = "Restore a living player's health.",
		Execute = function(context)
			local target, resolveError = context.ResolvePlayer(context.Args[1] or "me")
			local humanoid = target and getLiveHumanoid(target)
			if not target then
				context.Reply(resolveError or "Player not found.", "Error")
			elseif not humanoid then
				context.Reply(target.Name .. " does not have a living character.", "Error")
			else
				humanoid.Health = humanoid.MaxHealth
				context.Reply("Healed " .. target.Name .. ".", "Success")
			end
		end,
	})

	ChatCommandController.RegisterCommand({
		Name = "Kill",
		Aliases = { "/kill" },
		Usage = "/kill <player>",
		Description = "Eliminate a player's current character.",
		Execute = function(context)
			local target, resolveError = context.ResolvePlayer(context.Args[1])
			local humanoid = target and getLiveHumanoid(target)
			if not target then
				context.Reply(resolveError or "Player not found.", "Error")
			elseif not humanoid then
				context.Reply(target.Name .. " does not have a living character.", "Error")
			else
				humanoid.Health = 0
				context.Reply("Eliminated " .. target.Name .. ".", "Success")
			end
		end,
	})

	ChatCommandController.RegisterCommand({
		Name = "Bring",
		Aliases = { "/bring" },
		Usage = "/bring <player>",
		Description = "Teleport a player beside you.",
		Execute = function(context)
			local target, resolveError = context.ResolvePlayer(context.Args[1])
			local destinationRoot = getLiveRoot(context.Player)
			if not target then
				context.Reply(resolveError or "Player not found.", "Error")
			elseif not destinationRoot or not getLiveRoot(target) then
				context.Reply("Both players need living characters.", "Error")
			elseif TeleportPlayer(target, destinationRoot.CFrame * CFrame.new(3, 0, 0)) then
				clearMomentum(target)
				context.Reply("Brought " .. target.Name .. ".", "Success")
			else
				context.Reply("The teleport could not be completed.", "Error")
			end
		end,
	})

	ChatCommandController.RegisterCommand({
		Name = "Goto",
		Aliases = { "/goto" },
		Usage = "/goto <player>",
		Description = "Teleport yourself beside a player.",
		Execute = function(context)
			local target, resolveError = context.ResolvePlayer(context.Args[1])
			local destinationRoot = target and getLiveRoot(target)
			if not target then
				context.Reply(resolveError or "Player not found.", "Error")
			elseif not destinationRoot or not getLiveRoot(context.Player) then
				context.Reply("Both players need living characters.", "Error")
			elseif TeleportPlayer(context.Player, destinationRoot.CFrame * CFrame.new(3, 0, 0)) then
				clearMomentum(context.Player)
				context.Reply("Teleported to " .. target.Name .. ".", "Success")
			else
				context.Reply("The teleport could not be completed.", "Error")
			end
		end,
	})

	ChatCommandController.RegisterCommand({
		Name = "Kick",
		Aliases = { "/kick" },
		Usage = "/kick <player>",
		Description = "Remove a player from the server.",
		Execute = function(context)
			local target, resolveError = context.ResolvePlayer(context.Args[1])
			if not target then
				context.Reply(resolveError or "Player not found.", "Error")
				return
			end
			context.Reply("Kicked " .. target.Name .. ".", "Success")
			target:Kick("Removed by a game developer.")
		end,
	})

	ChatCommandController.RegisterCommand({
		Name = "ResetData",
		Aliases = { "/resetdata" },
		Usage = "/resetdata <player> confirm",
		Description = "Permanently reset a player's saved data and remove them from the server.",
		Execute = function(context)
			if #context.Args ~= 2 or string.lower(context.Args[2]) ~= "confirm" then
				context.Reply("Usage: /resetdata <player> confirm", "Error")
				return
			end

			local target, resolveError = resolveExactUsername(context.Args[1])
			if not target then
				context.Reply(resolveError or "Player not found.", "Error")
				return
			end
			if not dataService or not dataService:hasProfile(target) then
				context.Reply("That player's data is not available to reset.", "Error")
				return
			end

			-- Data deletion is irreversible, so the explicit confirmation token is required beside the target name.
			local success, resetError = pcall(dataService.resetData, dataService, target)
			if not success then
				warn(string.format("Failed to reset data for %s: %s", target.Name, tostring(resetError)))
				context.Reply("The data reset failed. Check the server output.", "Error")
				return
			end
			context.Reply("Reset data for " .. target.Name .. ".", "Success")
		end,
	})
end

function ChatCommandController.SetDataService(service)
	dataService = service
end

function ChatCommandController.Init()
	if initialized then
		return
	end
	chatNetwork = Networker.server.new("ChatCommandController", ChatCommandController, {})
	registerBuiltInCommands()
	initialized = true
	for _, definition in orderedDefinitions do
		bindDefinition(definition)
	end
end

function ChatCommandController.OnPlayerRemoving(player: Player)
	developerByPlayer[player] = nil
	lastCommandAt[player] = nil
	lastRespawnAt[player] = nil
end

return ChatCommandController
