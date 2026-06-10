local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local UserInputService = game:GetService("UserInputService")

local MODES = {
	Light = "Light Mode",
	Dark = "Dark Mode",
}

local NOTES_BY_KEY = {
	[Enum.KeyCode.One] = "Simple note",
	[Enum.KeyCode.Two] = "Info note",
	[Enum.KeyCode.Three] = "Success note",
	[Enum.KeyCode.Four] = "Error note",
	[Enum.KeyCode.Five] = "Warning note",
}

local PREVIEW_ATTRIBUTE = "NotePreview"
local REMOTE_NAME = "NotePreviewRemote"
local CLOSE_ACTION = "close"

local VALID_MODES = {
	[MODES.Light] = true,
	[MODES.Dark] = true,
}

local VALID_NOTES = {}
for _, noteName in NOTES_BY_KEY do
	VALID_NOTES[noteName] = true
end

local remote

local function logInfo(message)
	print(`[NotePreview] {message}`)
end

local function logWarn(message)
	warn(`[NotePreview] {message}`)
end

local function clearPreview(player)
	local playerGui = player:WaitForChild("PlayerGui")

	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and child:GetAttribute(PREVIEW_ATTRIBUTE) then
			child:Destroy()
		end
	end
end

local function showNote(player, modeName, noteName)
	if not VALID_MODES[modeName] then
		return false, "Invalid mode"
	end

	if not VALID_NOTES[noteName] then
		return false, "Invalid note"
	end

	local modeFolder = ServerStorage:FindFirstChild(modeName)
	if not modeFolder then
		return false, `Mode folder not found: {modeName}`
	end

	local template = modeFolder:FindFirstChild(noteName)
	if not template or not template:IsA("ScreenGui") then
		return false, `Note not found: {noteName}`
	end

	clearPreview(player)

	local clone = template:Clone()
	clone:SetAttribute(PREVIEW_ATTRIBUTE, true)
	clone.Parent = player:WaitForChild("PlayerGui")

	return true
end

local function initServer()
	remote = Instance.new("RemoteFunction")
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage

	remote.OnServerInvoke = function(player, modeName, noteName)
		if modeName == CLOSE_ACTION then
			clearPreview(player)
			return true
		end

		return showNote(player, modeName, noteName)
	end
end

local function initClient()
	local Players = game:GetService("Players")
	local clientRemote = ReplicatedStorage:WaitForChild(REMOTE_NAME)
	local currentMode = MODES.Light
	local currentNote = nil

	logInfo(`Note preview ready. Q toggles mode (currently {currentMode}). 1-5 load notes.`)

	local function findCloseButton(screenGui)
		local container = screenGui:FindFirstChild("Container", true)
		if not container then
			return nil
		end

		local closeFrame = container:FindFirstChild("Close X (Vector)")
		if not closeFrame then
			return nil
		end

		local closeButton = closeFrame:FindFirstChild("Image")
		if closeButton and closeButton:IsA("ImageButton") then
			return closeButton
		end

		return nil
	end

	local function getActivePreview()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

		for _, child in playerGui:GetChildren() do
			if child:IsA("ScreenGui") and child:GetAttribute(PREVIEW_ATTRIBUTE) then
				return child
			end
		end

		return nil
	end

	local function wireCloseButton(screenGui)
		local closeButton = findCloseButton(screenGui)
		if not closeButton then
			logWarn("Close button not found on note preview")
			return
		end

		closeButton.Activated:Connect(function()
			clientRemote:InvokeServer(CLOSE_ACTION)
		end)
	end

	local function showCurrentNote()
		if not currentNote then
			return
		end

		local success, err = clientRemote:InvokeServer(currentMode, currentNote)
		if not success then
			logWarn(`Failed to show {currentNote} ({currentMode}): {err or "unknown error"}`)
			return
		end

		task.defer(function()
			local preview = getActivePreview()
			if preview then
				wireCloseButton(preview)
			end
		end)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if input.KeyCode == Enum.KeyCode.Q then
			if currentMode == MODES.Light then
				currentMode = MODES.Dark
			else
				currentMode = MODES.Light
			end

			logInfo(`Switched to {currentMode}`)
			showCurrentNote()
			return
		end

		local noteName = NOTES_BY_KEY[input.KeyCode]
		if not noteName then
			return
		end

		currentNote = noteName
		showCurrentNote()
	end)
end

if RunService:IsServer() then
	initServer()
elseif RunService:IsClient() then
	initClient()
end

return {}
