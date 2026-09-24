-- State is sent as small integers because it is included in every batched snapshot.
local ZombieProtocol = {
	SnapshotInterval = 0.2,
	State = {
		Idle = 0,
		Moving = 1,
		Attacking = 2,
	},
}

return ZombieProtocol
