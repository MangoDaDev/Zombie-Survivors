local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local CoinsConfig = require(ReplicatedStorage.Modules.Game.CoinsConfig)
local PowerupConfig = require(ReplicatedStorage.Modules.Game.PowerupConfig)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)
local ZombieDefinitions = require(ReplicatedStorage.Modules.Game.Zombies.ZombieDefinitions)
local AbilityController = require(ServerStorage.Controllers.AbilityController)
local ChatCommandController = require(ServerStorage.Controllers.ChatCommandController)
local ChatCommandConfig = require(ServerStorage.Controllers.ChatCommand.ChatCommandConfig)
local CoinsController = require(ServerStorage.Controllers.CoinsController)
local PowerupDropController = require(ServerStorage.Controllers.PowerupDropController)
local RageController = require(ServerStorage.Controllers.RageController)
local RoundController = require(ServerStorage.Controllers.RoundController)
local RunProgressionController = require(ServerStorage.Controllers.RunProgressionController)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local AdminGameplayCommandController = {}

local function getSortedIds(definitions): { string }
	local ids = {}
	for id in definitions do
		table.insert(ids, id)
	end
	table.sort(ids, function(left, right)
		return string.lower(left) < string.lower(right)
	end)
	return ids
end

local abilityIds = getSortedIds(AbilityDefinitions.ById)
local powerupIds = getSortedIds(PowerupConfig.Definitions)
local zombieIds = getSortedIds(ZombieDefinitions)

local function makeIdLookup(ids: { string }): { [string]: string }
	local lookup = {}
	for _, id in ids do
		lookup[string.lower(id)] = id
	end
	return lookup
end

local abilityIdLookup = makeIdLookup(abilityIds)
local powerupIdLookup = makeIdLookup(powerupIds)
local zombieIdLookup = makeIdLookup(zombieIds)

local function parseInteger(text: string?): number?
	local value = if type(text) == "string" then tonumber(text) else nil
	return if value and value == value and math.abs(value) < math.huge and value % 1 == 0 then value else nil
end

local function resolveValueAndTarget(context, usage: string): (number?, Player?)
	if #context.Args < 1 or #context.Args > 2 then
		context.Reply("Usage: " .. usage, "Error")
		return nil, nil
	end

	local value = parseInteger(context.Args[1])
	local selector = context.Args[2]
	if value == nil and #context.Args == 2 then
		selector = context.Args[1]
		value = parseInteger(context.Args[2])
	end
	if value == nil then
		context.Reply("A whole-number value is required. Usage: " .. usage, "Error")
		return nil, nil
	end

	local target, resolveError = context.ResolvePlayer(selector or "me")
	if not target then
		context.Reply(resolveError or "Player not found.", "Error")
		return nil, nil
	end
	return value, target
end

local function getLiveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end

local function getGroundY(player: Player, root: BasePart): number
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local result = workspace:Raycast(root.Position, Vector3.new(0, -50, 0), raycastParams)
	return if result then result.Position.Y else root.Position.Y - 3
end

local function register(definition)
	if not ChatCommandController.RegisterCommand(definition) then
		warn("Could not register admin chat command " .. tostring(definition.Name))
	end
end

local function registerProgressionCommands()
	register({
		Name = "Status",
		Aliases = { "/status" },
		Usage = "/status [player]",
		Description = "Show a player's run level, XP, Coins, and the shared round/horde state.",
		Execute = function(context)
			if #context.Args > 1 then
				context.Reply("Usage: /status [player]", "Error")
				return
			end
			local target, resolveError = context.ResolvePlayer(context.Args[1] or "me")
			if not target then
				context.Reply(resolveError or "Player not found.", "Error")
				return
			end
			local summary = RunProgressionController.GetRunSummary(target)
			local coins = CoinsController.Get(target)
			context.Reply(string.format(
				"%s | Level %d | Total XP %d | Coins %s | Round %d | Zombies %d",
				target.Name,
				summary.level,
				summary.totalXP,
				if coins == nil then "unavailable" else tostring(coins),
				RoundController.GetCurrentRound(),
				ZombieController.GetTotalLivingZombieCount()
			))
		end,
	})

	register({
		Name = "SetLevel",
		Aliases = { "/setlevel", "/level" },
		Usage = "/setlevel <level> [player]",
		Description = "Set a run level and queue normal choices for gained levels.",
		Execute = function(context)
			local level, target = resolveValueAndTarget(context, "/setlevel <level> [player]")
			if not level or not target then
				return
			end
			if level < 1 or level > RunProgressionConfig.XP.MaximumLevel then
				context.Reply(string.format("Level must be between 1 and %d.", RunProgressionConfig.XP.MaximumLevel), "Error")
				return
			end
			if RunProgressionController.SetLevelForAdmin(target, level) then
				context.Reply(string.format("Set %s's run level to %d.", target.Name, level), "Success")
			else
				context.Reply("Run progression is not active for that player.", "Error")
			end
		end,
	})

	register({
		Name = "GiveLevels",
		Aliases = { "/givelevels", "/addlevels" },
		Usage = "/givelevels <amount> [player]",
		Description = "Add run levels and queue their normal ability choices.",
		Execute = function(context)
			local amount, target = resolveValueAndTarget(context, "/givelevels <amount> [player]")
			if not amount or not target then
				return
			end
			if amount < 1 then
				context.Reply("Level amount must be at least 1.", "Error")
				return
			end
			local currentLevel = RunProgressionController.GetRunSummary(target).level
			local targetLevel = currentLevel + amount
			if targetLevel > RunProgressionConfig.XP.MaximumLevel then
				context.Reply(string.format("That would exceed maximum level %d.", RunProgressionConfig.XP.MaximumLevel), "Error")
				return
			end
			if RunProgressionController.SetLevelForAdmin(target, targetLevel) then
				context.Reply(string.format("Gave %s %d level(s); now level %d.", target.Name, amount, targetLevel), "Success")
			else
				context.Reply("Run progression is not active for that player.", "Error")
			end
		end,
	})

	register({
		Name = "GiveXP",
		Aliases = { "/givexp", "/addxp" },
		Usage = "/givexp <amount> [player]",
		Description = "Grant run XP through the normal progression rules.",
		Execute = function(context)
			local amount, target = resolveValueAndTarget(context, "/givexp <amount> [player]")
			if not amount or not target then
				return
			end
			if amount < 1 or amount > ChatCommandConfig.MaximumXPGrant then
				context.Reply(string.format("XP must be between 1 and %d.", ChatCommandConfig.MaximumXPGrant), "Error")
				return
			end
			if RunProgressionController.AddXP(target, amount) then
				context.Reply(string.format("Granted %s %d XP.", target.Name, amount), "Success")
			else
				context.Reply("Run progression is not active for that player.", "Error")
			end
		end,
	})
end

local function registerCurrencyCommands()
	register({
		Name = "SetCoins",
		Aliases = { "/setcoins" },
		Usage = "/setcoins <amount> [player]",
		Description = "Set a player's persistent Coin balance.",
		Execute = function(context)
			local amount, target = resolveValueAndTarget(context, "/setcoins <amount> [player]")
			if not amount or not target then
				return
			end
			if amount < 0 or amount > CoinsConfig.MaximumBalance then
				context.Reply("Coin amount is outside the valid balance range.", "Error")
				return
			end
			local success, balance = CoinsController.Set(target, amount)
			if success then
				context.Reply(string.format("Set %s's Coins to %s.", target.Name, tostring(balance)), "Success")
			else
				context.Reply("That player's Coin data is unavailable.", "Error")
			end
		end,
	})

	register({
		Name = "GiveCoins",
		Aliases = { "/givecoins", "/addcoins" },
		Usage = "/givecoins <amount> [player]",
		Description = "Add to a player's persistent Coin balance.",
		Execute = function(context)
			local amount, target = resolveValueAndTarget(context, "/givecoins <amount> [player]")
			if not amount or not target then
				return
			end
			if amount < 1 then
				context.Reply("Coin amount must be at least 1.", "Error")
				return
			end
			local success, balance = CoinsController.Add(target, amount)
			if success then
				context.Reply(string.format("Gave %s %d Coins; balance is %s.", target.Name, amount, tostring(balance)), "Success")
			else
				context.Reply("The Coin grant failed or would exceed the maximum balance.", "Error")
			end
		end,
	})
end

local function registerRoundAndSpawnCommands()
	register({
		Name = "SetRound",
		Aliases = { "/setround", "/round" },
		Usage = "/setround <round>",
		Description = "Clear the horde and start an exact shared round.",
		Execute = function(context)
			if #context.Args ~= 1 then
				context.Reply("Usage: /setround <round>", "Error")
				return
			end
			local roundNumber = parseInteger(context.Args[1])
			if not roundNumber or roundNumber < 1 or roundNumber > ChatCommandConfig.MaximumRound then
				context.Reply(string.format("Round must be between 1 and %d.", ChatCommandConfig.MaximumRound), "Error")
				return
			end
			local success, currentRound = RoundController.SetRoundForAdmin(roundNumber)
			if success then
				context.Reply("Started round " .. currentRound .. ".", "Success")
			else
				context.Reply("Rounds are not active yet in this server.", "Error")
			end
		end,
	})

	register({
		Name = "NextRound",
		Aliases = { "/nextround", "/skipround" },
		Usage = "/nextround",
		Description = "Force the shared game into the next round.",
		Execute = function(context)
			if #context.Args ~= 0 then
				context.Reply("Usage: /nextround", "Error")
				return
			end
			local success, roundNumber = RoundController.AdvanceForAdmin()
			if success then
				context.Reply("Advanced to round " .. roundNumber .. ".", "Success")
			else
				context.Reply("The round cannot advance right now.", "Error")
			end
		end,
	})

	register({
		Name = "ZombieTypes",
		Aliases = { "/zombietypes", "/zombies" },
		Usage = "/zombietypes",
		Description = "List exact zombie IDs accepted by /spawnzombie.",
		Execute = function(context)
			context.Reply("Zombie types: " .. table.concat(zombieIds, ", "))
		end,
	})

	register({
		Name = "SpawnZombie",
		Aliases = { "/spawnzombie", "/spawnz" },
		Usage = "/spawnzombie <type> [amount]",
		Description = "Spawn a selected zombie type using safe arena placement.",
		Execute = function(context)
			if #context.Args < 1 or #context.Args > 2 then
				context.Reply("Usage: /spawnzombie <type> [amount]", "Error")
				return
			end
			local typeName = zombieIdLookup[string.lower(context.Args[1])]
			local amount = if context.Args[2] then parseInteger(context.Args[2]) else 1
			if not typeName then
				context.Reply("Unknown zombie type. Use /zombietypes.", "Error")
				return
			end
			if not amount or amount < 1 or amount > ChatCommandConfig.MaximumZombieSpawnCount then
				context.Reply(string.format("Amount must be between 1 and %d.", ChatCommandConfig.MaximumZombieSpawnCount), "Error")
				return
			end
			local roundNumber = math.max(RoundController.GetCurrentRound(), 1)
			local spawnedIds = ZombieController.SpawnSpecific(typeName, amount, roundNumber)
			if #spawnedIds > 0 then
				context.Reply(string.format("Spawned %d %s zombie(s).", #spawnedIds, typeName), "Success")
			else
				context.Reply("No zombies spawned. The game and a living player must be active.", "Error")
			end
		end,
	})

	register({
		Name = "ClearZombies",
		Aliases = { "/clearzombies", "/despawnzombies" },
		Usage = "/clearzombies",
		Description = "Despawn every living zombie without granting rewards.",
		Execute = function(context)
			if #context.Args ~= 0 then
				context.Reply("Usage: /clearzombies", "Error")
				return
			end
			local removedCount = ZombieController.ClearAll()
			context.Reply(string.format("Despawned %d zombie(s).", removedCount), "Success")
		end,
	})

	register({
		Name = "PowerupTypes",
		Aliases = { "/poweruptypes", "/powerups" },
		Usage = "/poweruptypes",
		Description = "List power-up IDs accepted by /spawnpowerup.",
		Execute = function(context)
			context.Reply("Power-up types: random, " .. table.concat(powerupIds, ", "))
		end,
	})

	register({
		Name = "SpawnPowerup",
		Aliases = { "/spawnpowerup", "/spawnp" },
		Usage = "/spawnpowerup <type|random> [amount]",
		Description = "Spawn power-ups beside your living character.",
		Execute = function(context)
			if #context.Args < 1 or #context.Args > 2 then
				context.Reply("Usage: /spawnpowerup <type|random> [amount]", "Error")
				return
			end
			local requestedId = string.lower(context.Args[1])
			local powerupId = powerupIdLookup[requestedId]
			local randomPowerup = requestedId == "random"
			local amount = if context.Args[2] then parseInteger(context.Args[2]) else 1
			if not powerupId and not randomPowerup then
				context.Reply("Unknown power-up type. Use /poweruptypes.", "Error")
				return
			end
			if not amount or amount < 1 or amount > ChatCommandConfig.MaximumPowerupSpawnCount then
				context.Reply(string.format("Amount must be between 1 and %d.", ChatCommandConfig.MaximumPowerupSpawnCount), "Error")
				return
			end
			local root = getLiveRoot(context.Player)
			if not root then
				context.Reply("You need a living character to place power-ups.", "Error")
				return
			end
			local groundY = getGroundY(context.Player, root)
			local spawnedCount = 0
			for _ = 1, amount do
				local spawned = if randomPowerup
					then PowerupDropController.Spawn(root.Position, groundY, context.Player)
					else PowerupDropController.SpawnSpecific(powerupId, root.Position, groundY, context.Player)
				if spawned then
					spawnedCount += 1
				end
			end
			if spawnedCount > 0 then
				context.Reply(string.format("Spawned %d power-up(s).", spawnedCount), "Success")
			else
				context.Reply("Power-ups can only spawn in an active game server.", "Error")
			end
		end,
	})
end

local function registerAbilityAndCombatCommands()
	register({
		Name = "AbilityTypes",
		Aliases = { "/abilitytypes", "/abilities" },
		Usage = "/abilitytypes",
		Description = "List ability IDs accepted by /setability.",
		Execute = function(context)
			context.Reply("Ability types: " .. table.concat(abilityIds, ", "))
		end,
	})

	register({
		Name = "SetAbility",
		Aliases = { "/setability", "/giveability" },
		Usage = "/setability <ability> <level> [player]",
		Description = "Add or set a run-only ability without changing permanent unlocks.",
		Execute = function(context)
			if #context.Args < 2 or #context.Args > 3 then
				context.Reply("Usage: /setability <ability> <level> [player]", "Error")
				return
			end
			local abilityId = abilityIdLookup[string.lower(context.Args[1])]
			local level = parseInteger(context.Args[2])
			if not abilityId then
				context.Reply("Unknown ability. Use /abilitytypes.", "Error")
				return
			end
			local definition = AbilityDefinitions.ById[abilityId]
			if not level or level < 1 or level > definition.MaxLevel then
				context.Reply(string.format("%s level must be between 1 and %d.", abilityId, definition.MaxLevel), "Error")
				return
			end
			local target, resolveError = context.ResolvePlayer(context.Args[3] or "me")
			if not target then
				context.Reply(resolveError or "Player not found.", "Error")
				return
			end
			if AbilityController.SetRunAbilityLevelForAdmin(target, abilityId, level) then
				RunProgressionController.RefreshPlayer(target)
				context.Reply(string.format("Set %s's %s to run level %d.", target.Name, abilityId, level), "Success")
			else
				context.Reply("The run is inactive or that ability category has no free slot.", "Error")
			end
		end,
	})

	register({
		Name = "Rage",
		Aliases = { "/rage" },
		Usage = "/rage [player]",
		Description = "Activate or extend bonus Rage for a living player.",
		Execute = function(context)
			if #context.Args > 1 then
				context.Reply("Usage: /rage [player]", "Error")
				return
			end
			local target, resolveError = context.ResolvePlayer(context.Args[1] or "me")
			if not target then
				context.Reply(resolveError or "Player not found.", "Error")
				return
			end
			if RageController.ActivateBonusRage(target) then
				context.Reply("Activated bonus Rage for " .. target.Name .. ".", "Success")
			else
				context.Reply("Rage requires an active game and a living character.", "Error")
			end
		end,
	})
end

function AdminGameplayCommandController.Init()
	-- All registered commands inherit ChatCommandController's centralized developer authorization,
	-- cooldown, player resolution, and private response channel.
	registerProgressionCommands()
	registerCurrencyCommands()
	registerRoundAndSpawnCommands()
	registerAbilityAndCombatCommands()
end

return AdminGameplayCommandController
