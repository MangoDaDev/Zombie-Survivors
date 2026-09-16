local AmbientAudioConfig = {
	ZoneCheckInterval = 0.25,
	CrossfadeDuration = 2.5,
	Ducking = {
		VolumeMultiplier = 0.28,
		FadeOutDuration = 0.2,
		HoldDuration = 1.8,
		FadeInDuration = 1.35,
	},
	Music = {
		FolderName = "Music",
		SoundName = "Gymnopedie No. 1 (60)",
		Volume = 0.1,
	},
	Zones = {
		Outdoor = {
			FolderName = "Music",
			SoundName = "OutdoorAmbience",
			Volume = 0.16,
		},
		Museum = {
			FolderName = "Music",
			SoundName = "MuseumAmbience",
			Volume = 0.1,
		},
	},
}

return AmbientAudioConfig
