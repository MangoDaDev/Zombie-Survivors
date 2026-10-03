local CombatPrediction = {}
local RECOVERY_SECONDS = 1.5
local RETAIN_SECONDS = 8
local MAX_PENDING_PER_ZOMBIE = 64

function CombatPrediction.Add(view, source: string, key: string, damage: number, now: number)
	local confirmed = view.confirmedHits and view.confirmedHits[source .. ":" .. key]
	if confirmed and (source ~= "OrbitingSwords" or now - confirmed < 0.12) then
		return false
	end
	view.predictedHits = view.predictedHits or {}
	local hits = view.predictedHits
	for _, hit in hits do
		if source ~= "OrbitingSwords" and hit.key == key and hit.source == source then
			return false
		end
	end
	if #hits >= MAX_PENDING_PER_ZOMBIE or view.health <= 0 then
		return false
	end
	-- Specials can shield, dodge, absorb, heal, or amplify damage. Predict their contact cue only;
	-- never announce a speculative kill or damage amount for those enemies (including bosses).
	local estimate = if not view.definition.SpecialBehavior and not view.definition.IsBoss then damage else 0
	local healthBefore = CombatPrediction.GetHealth(view)
	local hit = { source = source, key = key, damage = estimate, at = now, expiresAt = now + RECOVERY_SECONDS }
	table.insert(hits, hit)
	if estimate > 0 then
		hit.number = view:ShowDamageNumber(math.min(estimate, healthBefore))
	end
	CombatPrediction.Refresh(view)
	return true
end

function CombatPrediction.GetHealth(view): number
	local health = view.health
	for _, hit in view.predictedHits or {} do
		if not hit.resolved and not hit.expired then
			health -= hit.damage
		end
	end
	return math.max(health, 0)
end

function CombatPrediction.Refresh(view, animate: boolean?)
	local health = CombatPrediction.GetHealth(view)
	view.presentationHealth = health
	if health <= 0 and view.health > 0 then
		view.predictedDeathAt = view.predictedDeathAt or os.clock()
	else
		view.predictedDeathAt = nil
	end
	if view.healthBar then
		view.healthBar.Enabled = health > 0
	end
	view:RenderHealth(health, animate ~= false)
end

function CombatPrediction.Resolve(view, source, key, serverTime, actualDamage)
	if type(source) ~= "string" or type(serverTime) ~= "number" then
		return false, false
	end
	if key then
		view.confirmedHits = view.confirmedHits or {}
		view.confirmedHits[source .. ":" .. key] = serverTime
	end
	local matched
	local closestTime = math.huge
	for _, hit in view.predictedHits or {} do
		local timeDifference = math.abs(serverTime - hit.at)
		if not hit.resolved and hit.source == source
			and (key == hit.key or (key == nil and timeDifference <= RECOVERY_SECONDS))
			and (source ~= "OrbitingSwords" or timeDifference <= RECOVERY_SECONDS) then
			if source ~= "OrbitingSwords" then
				matched = hit
				break
			elseif timeDifference < closestTime then
				matched = hit
				closestTime = timeDifference
			end
		end
	end
	if not matched then
		return false
	end
	matched.resolved = true
	if matched.number and matched.number.Parent then
		if actualDamage > 0 then
			matched.number.Text = tostring(actualDamage)
		else
			matched.number.Parent:Destroy()
		end
	elseif actualDamage > 0 and (matched.expired or matched.damage == 0) then
		view:ShowDamageNumber(actualDamage)
	end
	return true, not matched.expired
end

function CombatPrediction.Step(view, now: number)
	for key, at in view.confirmedHits or {} do
		if now - at >= RETAIN_SECONDS then
			view.confirmedHits[key] = nil
		end
	end
	local changed = false
	local hits = view.predictedHits
	if not hits then
		return
	end
	for index = #hits, 1, -1 do
		local hit = hits[index]
		if not hit.resolved and not hit.expired and now >= hit.expiresAt then
			hit.expired = true
			if hit.number and hit.number.Parent then
				hit.number.Parent:Destroy()
			end
			changed = true
		end
		if now - hit.at >= RETAIN_SECONDS or (hit.resolved and hit.source == "OrbitingSwords") then
			table.remove(hits, index)
		end
	end
	if changed then
		CombatPrediction.Refresh(view)
	end
end

function CombatPrediction.Cancel(view, source: string?, key: string?)
	local changed = false
	for _, hit in view.predictedHits or {} do
		if (source == nil or hit.source == source) and (key == nil or hit.key == key)
			and not hit.resolved and not hit.expired then
			hit.expired = true
			changed = true
			if hit.number and hit.number.Parent then
				hit.number.Parent:Destroy()
			end
		end
	end
	if changed then
		CombatPrediction.Refresh(view)
	end
end

return CombatPrediction
