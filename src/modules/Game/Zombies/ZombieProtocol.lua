-- State is sent as small integers because it is included in every batched snapshot.
local ZombieProtocol = {
	SnapshotInterval = 0.2,
	State = {
		Idle = 0,
		Moving = 1,
		Attacking = 2,
	},
	-- Every special uses the same compact state channel; definitions and behavior strategies
	-- decide what the state means without adding zombie-type branches to replication code.
	SpecialState = {
		None = 0,
		Windup = 1,
		Active = 2,
		Recovery = 3,
		Countdown = 4,
		Burrowed = 5,
		Warning = 6,
		Frenzied = 7,
		Pulse = 8,
		Armored = 9,
		Dodge = 10,
	},
}

return ZombieProtocol
