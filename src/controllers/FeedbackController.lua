local SocialService = game:GetService "SocialService"
local Workspace = game:GetService "Workspace"

local PROMPT_NAME = "FeedbackPrompt"
local PROMPT_DISTANCE = 10

local FeedbackController = {}

function FeedbackController.Init()
	task.spawn(function()
		local mailbox = Workspace:WaitForChild "Mailbox"
		local promptPart = mailbox:WaitForChild "PromptPart"

		local prompt = promptPart:FindFirstChild(PROMPT_NAME)
		if prompt == nil then
			prompt = Instance.new "ProximityPrompt"
			prompt.Name = PROMPT_NAME
			prompt.ActionText = "Give Feedback"
			prompt.ObjectText = "Mailbox"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = PROMPT_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = promptPart
		end

		if not prompt:IsA "ProximityPrompt" then
			warn(`Mailbox {PROMPT_NAME} must be a ProximityPrompt`)
			return
		end

		prompt.Triggered:Connect(function()
			-- Feedback prompts must be opened locally because SocialService targets the calling player.
			local success, errorMessage = pcall(function()
				SocialService:PromptFeedbackSubmissionAsync()
			end)

			if not success then
				warn(`Unable to open the feedback prompt: {errorMessage}`)
			end
		end)
	end)
end

return FeedbackController
