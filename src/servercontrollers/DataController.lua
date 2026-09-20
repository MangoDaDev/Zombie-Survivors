local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local Networker = require(ReplicatedStorage.Packages.networker)
local EconomyConfig = require(ReplicatedStorage.Modules.Game.EconomyConfig)
local Ranks = require(ReplicatedStorage.Modules.Platform.Ranks)
local PlayerStateController = require(ServerStorage.Controllers.PlayerStateController)

local DataController = {}
local DataService
local Network
local ResettingPlayers: { [Player]: boolean } = {}
local RecoveryConnections: { [Player]: { RBXScriptConnection } } = {}
local RecoveryChecksQueued: { [Player]: boolean } = {}
local MaximumCash = 1_000_000_000_000

local Commands = {
	Commands = { Aliases = { "/commands", "/help" }, Description = "Show Command Help", Usage = "/commands [command]" },
	Respawn = { Aliases = { "/respawn" }, Description = "Bring A Player Back", Usage = "/respawn [player]" },
	ResetData = { Aliases = { "/resetdata" }, Description = "Clear Saved Data", Usage = "/resetdata [player] confirm", OwnerOnly = true },
	SetCash = { Aliases = { "/setcash" }, Description = "Set Player Cash", Usage = "/setcash <player> <amount>", OwnerOnly = true },
	AddCash = { Aliases = { "/addcash" }, Description = "Give Player Cash", Usage = "/addcash <player> <amount>", OwnerOnly = true },
	Kick = { Aliases = { "/kick" }, Description = "Remove A Player", Usage = "/kick <player> [reason]", OwnerOnly = true },
}

local function IsOwner(Player: Player): boolean
	for _, Rank in Ranks do
		if Rank.Name == "Owner" and table.find(Rank.Users, Player.UserId) then return true end
	end
	return false
end

local function Notify(Player: Player, Message: string)
	if Network and Player.Parent == Players then Network:fire(Player, "ShowMessage", Message) end
end

local function ParseArguments(Message: string): { string }
	local Arguments = {}
	local Current = ""
	local QuoteCharacter = nil
	for Index = 1, #Message do
		local Character = string.sub(Message, Index, Index)
		if QuoteCharacter then
			if Character == QuoteCharacter then QuoteCharacter = nil else Current ..= Character end
		elseif Character == '"' or Character == "'" then
			QuoteCharacter = Character
		elseif string.match(Character, "%s") then
			if Current ~= "" then table.insert(Arguments, Current); Current = "" end
		else
			Current ..= Character
		end
	end
	if Current ~= "" then table.insert(Arguments, Current) end
	return Arguments
end

local function FindPlayer(Query: string, ExecutingPlayer: Player): (Player?, string?)
	local NormalizedQuery = string.lower(Query)
	if NormalizedQuery == "me" then return ExecutingPlayer end
	local Matches = {}
	for _, Player in Players:GetPlayers() do
		local Name = string.lower(Player.Name)
		local DisplayName = string.lower(Player.DisplayName)
		if Name == NormalizedQuery then return Player end
		if string.sub(Name, 1, #NormalizedQuery) == NormalizedQuery or string.sub(DisplayName, 1, #NormalizedQuery) == NormalizedQuery then
			table.insert(Matches, Player)
		end
	end
	if #Matches == 1 then return Matches[1] end
	if #Matches > 1 then return nil, "Many Players Found" end
	return nil, "Player Not Found"
end

local function GetTarget(ExecutingPlayer: Player, Query: string?): Player?
	if not Query or Query == "" then return ExecutingPlayer end
	local Target, ErrorMessage = FindPlayer(Query, ExecutingPlayer)
	if not Target then Notify(ExecutingPlayer, ErrorMessage or "Player Not Found") end
	return Target
end

local function GetAmount(ExecutingPlayer: Player, Value: string?): number?
	local Amount = if Value then tonumber(Value) else nil
	if not Amount or Amount ~= Amount or Amount == math.huge or Amount == -math.huge then
		Notify(ExecutingPlayer, "Use A Whole Number")
		return nil
	end
	return math.floor(Amount)
end

local function RunCommands(Player: Player, Arguments: { string })
	local RequestedName = Arguments[1]
	if RequestedName then
		RequestedName = string.lower(string.gsub(RequestedName, "^/", ""))
		for Name, Command in Commands do
			local MatchesName = string.lower(Name) == RequestedName
			for _, Alias in Command.Aliases do
				MatchesName = MatchesName or string.lower(string.gsub(Alias, "^/", "")) == RequestedName
			end
			if MatchesName then
				if Command.OwnerOnly and not IsOwner(Player) then Notify(Player, "Owners Only"); return end
				Notify(Player, Command.Usage)
				return
			end
		end
		Notify(Player, "Command Not Found")
		return
	end
	local Usages = {}
	for _, Command in Commands do
		if not Command.OwnerOnly or IsOwner(Player) then table.insert(Usages, Command.Usage) end
	end
	table.sort(Usages)
	Notify(Player, `Commands: {table.concat(Usages, ", ")}`)
end

local function RunRespawn(Player: Player, Arguments: { string })
	local Target = GetTarget(Player, Arguments[1])
	if not Target then return end
	if Target ~= Player and not IsOwner(Player) then Notify(Player, "Owners Only"); return end
	Target:LoadCharacter()
	Notify(Player, if Target == Player then "Coming Back..." else `Brought {Target.Name} Back`)
end

local function RunResetData(Player: Player, Arguments: { string })
	local TargetQuery = if string.lower(Arguments[1] or "") == "confirm" then nil else Arguments[1]
	local Confirmation = if TargetQuery then Arguments[2] else Arguments[1]
	if string.lower(Confirmation or "") ~= "confirm" then Notify(Player, "Type Confirm First"); return end
	local Target = GetTarget(Player, TargetQuery)
	if not Target or ResettingPlayers[Target] then
		if Target then Notify(Player, "Reset In Progress") end
		return
	end
	ResettingPlayers[Target] = true
	Notify(Player, `Resetting {Target.Name}`)
	DataService:resetData(Target)
end

local function RunSetCash(Player: Player, Arguments: { string })
	if not Arguments[1] or not Arguments[2] then Notify(Player, `Usage: {Commands.SetCash.Usage}`); return end
	local Target = GetTarget(Player, Arguments[1])
	local Amount = GetAmount(Player, Arguments[2])
	if not Target or not Amount then return end
	Amount = math.clamp(Amount, 0, MaximumCash)
	DataService:set(Target, "Cash", Amount)
	Notify(Player, `Cash Set: {Amount}`)
end

local function RunAddCash(Player: Player, Arguments: { string })
	if not Arguments[1] or not Arguments[2] then Notify(Player, `Usage: {Commands.AddCash.Usage}`); return end
	local Target = GetTarget(Player, Arguments[1])
	local Amount = GetAmount(Player, Arguments[2])
	if not Target or not Amount then return end
	DataService:update(Target, "Cash", function(CurrentCash)
		return math.clamp((if type(CurrentCash) == "number" then CurrentCash else 0) + Amount, 0, MaximumCash)
	end)
	Notify(Player, `Cash Added: {Amount}`)
end

local function RunKick(Player: Player, Arguments: { string })
	if not Arguments[1] then Notify(Player, `Usage: {Commands.Kick.Usage}`); return end
	local Target = GetTarget(Player, Arguments[1])
	if not Target then return end
	local Reason = table.concat(Arguments, " ", 2)
	Target:Kick(if Reason ~= "" then Reason else "Removed by an Owner.")
	Notify(Player, `Removed {Target.Name}`)
end

local Handlers = { Commands = RunCommands, Respawn = RunRespawn, ResetData = RunResetData, SetCash = RunSetCash, AddCash = RunAddCash, Kick = RunKick }

local function RegisterCommand(Name: string, Command)
	local ChatCommand = Instance.new("TextChatCommand")
	ChatCommand.Name = `{Name}Command`
	ChatCommand.PrimaryAlias = Command.Aliases[1]
	ChatCommand.SecondaryAlias = Command.Aliases[2] or ""
	ChatCommand.Triggered:Connect(function(TextSource, UnfilteredText)
		local Player = Players:GetPlayerByUserId(TextSource.UserId)
		if not Player then return end
		if Command.OwnerOnly and not IsOwner(Player) then Notify(Player, "Owners Only"); return end
		local Arguments = ParseArguments(UnfilteredText)
		table.remove(Arguments, 1)
		Handlers[Name](Player, Arguments)
	end)
	ChatCommand.Parent = TextChatService
end

function DataController.SetDataService(Service) DataService = Service end

function DataController.Init()
	Network = Networker.server.new("DataController", DataController, {})
	for Name, Command in Commands do RegisterCommand(Name, Command) end
end

local function ApplySoftlockRecovery(Player: Player)
	if Player.Parent ~= Players then return end
	local Inventory = DataService:get(Player, "Inventory")
	local Displays = DataService:get(Player, "Displays")
	local Cash = DataService:get(Player, "Cash")
	local HasInventory = type(Inventory) == "table" and next(Inventory) ~= nil
	local HasDisplay = type(Displays) == "table" and next(Displays) ~= nil
	local IsCarryingItem = PlayerStateController.Get(Player, "IsCarryingItem", false) == true
	local MinimumItemPrice = EconomyConfig.GetMinimumItemPrice()

	-- Keep players with no owned items able to afford the cheapest item and restart the earning loop.
	if not HasInventory
		and not HasDisplay
		and not IsCarryingItem
		and (type(Cash) ~= "number" or Cash < MinimumItemPrice)
	then
		DataService:set(Player, "Cash", MinimumItemPrice)
	end
end

local function QueueSoftlockRecovery(Player: Player)
	if RecoveryChecksQueued[Player] then return end
	RecoveryChecksQueued[Player] = true
	task.defer(function()
		RecoveryChecksQueued[Player] = nil
		ApplySoftlockRecovery(Player)
	end)
end

function DataController.OnPlayerAdded(Player: Player)
	ApplySoftlockRecovery(Player)
	RecoveryConnections[Player] = {
		DataService:getChangedSignal(Player, "Cash"):Connect(function() QueueSoftlockRecovery(Player) end),
		DataService:getChangedSignal(Player, "Inventory"):Connect(function() QueueSoftlockRecovery(Player) end),
		DataService:getChangedSignal(Player, "Displays"):Connect(function() QueueSoftlockRecovery(Player) end),
	}
end

function DataController.OnPlayerRemoving(Player)
	ResettingPlayers[Player] = nil
	RecoveryChecksQueued[Player] = nil
	for _, Connection in RecoveryConnections[Player] or {} do Connection:Disconnect() end
	RecoveryConnections[Player] = nil
end

return DataController
