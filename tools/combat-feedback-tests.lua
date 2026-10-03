-- Pass the source-loaded CombatPrediction module and ZombieView.SetHealth. Runs without a playtest.
return function(prediction, setHealth, makeAura, makeDagger)
	local checks = 0
	local function expect(condition, message)
		assert(condition, message)
		checks += 1
	end
	local function makeView(health, special)
		local view = {
			health = health, maximumHealth = health,
			definition = special or {}, healthBar = { Enabled = true }, numbers = {},
		}
		function view:ShowDamageNumber(amount)
			local gui = {}
			local label = { Text = tostring(amount), Parent = gui }
			function gui:Destroy()
				label.Parent = nil
			end
			table.insert(self.numbers, label)
			return label
		end
		function view:RenderHealth(amount)
			self.renderedHealth = amount
		end
		view.SetHealth = setHealth
		return view
	end

	for _, latency in { 0, 0.1, 0.35, 0.8 } do
		local view = makeView(100)
		expect(prediction.Add(view, "Dagger", "1:1", 30, 10), "initial prediction")
		expect(view.health == 100 and view.renderedHealth == 70, "prediction never changes authoritative health")
		local matched, suppress = prediction.Resolve(view, "Dagger", "1:1", 10 + latency, 30)
		view:SetHealth(70, 100, true, 10 + latency)
		expect(matched and suppress and view.renderedHealth == 70, "latency reconciliation without double subtraction")
		expect(#view.numbers == 1, "confirmation must not duplicate a damage number")
		expect(not prediction.Add(view, "Dagger", "1:1", 30, 10 + latency), "late cosmetic impact must not predict confirmed damage again")
	end

	local view = makeView(100)
	prediction.Add(view, "Dagger", "2:1", 60, 20)
	prediction.Add(view, "Dagger", "2:2", 60, 20)
	expect(view.predictedDeathAt ~= nil and not view.healthBar.Enabled, "immediate reversible lethal presentation")
	expect(view.numbers[2].Text == "40", "predicted numbers cap at remaining presentation health")
	prediction.Resolve(view, "Dagger", "2:1", 20.2, 20)
	view:SetHealth(80, 100, true, 20.2)
	expect(view.renderedHealth == 20 and view.predictedDeathAt == nil, "partial damage correction retains another pending hit")
	expect(view.numbers[1].Text == "20", "server amount replaces the estimate")
	prediction.Resolve(view, "Dagger", "2:2", 20.3, 0)
	view:SetHealth(80, 100, true, 20.3)
	expect(view.renderedHealth == 80 and view.numbers[2].Parent == nil, "blocked hit recovers and removes its number")
	view:SetHealth(100, 100, false, 20.1)
	expect(view.health == 80, "older snapshot cannot overwrite confirmed health")

	view = makeView(20)
	prediction.Add(view, "Dagger", "3:1", 30, 30)
	prediction.Step(view, 31.6)
	expect(view.renderedHealth == 20 and view.predictedDeathAt == nil and view.healthBar.Enabled, "missed hit recovers before any confirmation")
	local matched, suppress = prediction.Resolve(view, "Dagger", "3:1", 31.7, 20)
	view:SetHealth(0, 20, true, 31.7)
	expect(matched and not suppress and #view.numbers == 2 and view.renderedHealth == 0, "very late confirmed damage still presents once")

	view = makeView(20, { SpecialBehavior = "Shielder" })
	prediction.Add(view, "Dagger", "4:1", 30, 40)
	expect(view.health == 20 and view.renderedHealth == 20 and #view.numbers == 0, "special contact never predicts shield damage/death")
	prediction.Resolve(view, "Dagger", "4:1", 40.2, 5)
	view:SetHealth(15, 20, true, 40.2)
	expect(view.renderedHealth == 15 and #view.numbers == 1, "special actual damage appears on confirmation")

	view = makeView(100)
	prediction.Resolve(view, "Aura", "5", 50, 8)
	view:SetHealth(92, 100, true, 50)
	expect(not prediction.Add(view, "Aura", "5", 8, 50.01), "early authoritative Aura hit suppresses a later local tick")
	prediction.Add(view, "OrbitingSwords", "1", 10, 51)
	prediction.Add(view, "OrbitingSwords", "1", 10, 51.3)
	expect(view.renderedHealth == 72, "same blade can have multiple in-flight contacts")
	prediction.Resolve(view, "OrbitingSwords", "1", 51.1, 10)
	view:SetHealth(82, 100, true, 51.1)
	expect(view.renderedHealth == 72, "blade acknowledgement consumes one contact")
	prediction.Cancel(view, "OrbitingSwords")
	expect(view.renderedHealth == 82, "character/loadout boundary cancels pending contact")
	prediction.Step(view, 60)
	expect(#view.predictedHits == 0 and next(view.confirmedHits) == nil, "bounded retention cleans all records")

	view = makeView(100)
	prediction.Add(view, "Dagger", "6:1", 100, 70)
	prediction.Cancel(view, "Dagger", "6:1")
	expect(view.renderedHealth == 100 and view.predictedDeathAt == nil, "wrong target confirmation restores the original view")

	local predictions = {}
	local cleared = 0
	local root = { Position = Vector3.zero, CFrame = CFrame.identity }
	function root:IsA(name)
		return name == "BasePart"
	end
	local character = {}
	function character:FindFirstChild(name)
		return if name == "HumanoidRootPart" then root else nil
	end
	function character:FindFirstChildOfClass()
		return { Health = 100 }
	end
	local players = { LocalPlayer = { UserId = 1, Character = character } }
	local zombies = {}
	function zombies.GetContactCandidates()
		return { { id = 1, position = Vector3.new(1, 0, 0) } }
	end
	function zombies.GetNearestZombiePositions()
		return zombies.GetContactCandidates()
	end
	function zombies.PredictHit(id, source, key, damage)
		table.insert(predictions, { id = id, source = source, key = key, damage = damage })
	end
	function zombies.ClearPredictedHits()
		cleared += 1
	end
	function zombies.CancelPredictedHit()
		cleared += 1
	end
	local ready = { GetState = function() return { started = true } end }
	local definitions = { ById = { Aura = {
		Combat = { MaximumTargetsPerTick = 45 },
		GetZoneAtDistance = function() return { DamageMultiplier = 1.4 } end,
	} } }
	local aura = makeAura(players, definitions, zombies, ready)
	aura.ApplySchedule({ sequence = 1, enabled = true, nextAt = 100, radius = 5, damage = 10, interval = 0.2 })
	aura.Render(99.9)
	expect(#predictions == 0, "Aura waits for the scheduled timestamp")
	aura.Render(100)
	aura.Render(100.01)
	expect(#predictions == 1 and predictions[1].damage == 14, "Aura predicts a zoned tick once")
	aura.Render(100.21)
	expect(#predictions == 2 and predictions[2].key == "2", "Aura continues cadence through delayed push")
	aura.ApplySchedule({ sequence = 2, enabled = false })
	aura.ApplySchedule({ sequence = 1, enabled = true, nextAt = 101, radius = 5, damage = 10, interval = 0.2 })
	aura.Render(101)
	expect(#predictions == 2 and cleared > 0, "older Aura schedules cannot restore a disabled field")
	aura.ApplySchedule({ sequence = 3, enabled = true, nextAt = 102, radius = 5, damage = 10, interval = 0.2 })
	aura.Render(103.6)
	expect(#predictions == 2, "Aura cannot continue beyond recovery horizon")
	aura.ApplySchedule({ sequence = 4, enabled = true, nextAt = 104, radius = 5, damage = 10, interval = 0 })
	aura.Render(104)
	expect(#predictions == 2, "invalid cadence does not activate Aura")

	local now = 200
	local dagger = makeDagger(players, { GetServerTimeNow = function() return now end }, zombies, ready)
	local spawned = {}
	dagger.Init(function(packet)
		local projectile = table.clone(packet)
		projectile.model = { Parent = true, Destroy = function(self) self.Parent = nil end }
		table.insert(spawned, projectile)
		return projectile
	end)
	dagger.ApplySchedule({ sequence = 1, enabled = true, nextAt = 200, count = 1, range = 20,
		speed = 20, stagger = 0, lead = 0.06, minimumDuration = 0.1, maximumDuration = 0.5,
		scale = 0.5, rage = false, damage = 15 })
	dagger.Render(200)
	dagger.Render(200.07)
	expect(#spawned == 1 and spawned[1].targetId == 1, "Dagger carries its predicted target and hit identity")
	local confirmed = { ownerUserId = 1, sequence = 1, daggerIndex = 1, targetId = 2,
		damage = 20, predictionKey = "1:1", targetPosition = Vector3.new(2, 0, 0), launchAt = 200.06, duration = 0.1 }
	expect(dagger.Confirm(confirmed) and spawned[1].targetId == 2 and spawned[1].damage == 20,
		"Dagger reconciles the existing flight and changed target")
	expect(dagger.Confirm(confirmed) and #spawned == 1, "duplicate Dagger confirmation cannot launch again")
	spawned[1].model.Parent = nil
	expect(dagger.Confirm(confirmed) and #spawned == 1, "late confirmation cannot replay a completed flight")
	return { checks = checks, passed = true }
end
