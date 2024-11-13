--!strict

if plugin == nil then
	return
end

-- Services
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ScriptEditorService = game:GetService("ScriptEditorService")
local StudioService = game:GetService("StudioService")
local HttpService = game:GetService("HttpService")

-- Plugin Visual Settings
local toolbar = plugin:CreateToolbar("CDT Studio Tools")

local openScriptButton: PluginToolbarButton = toolbar:CreateButton("Open Script", "Open RunCommands", "rbxassetid://14978048121")
local runScriptFromSelectionButton: PluginToolbarButton = toolbar:CreateButton("Run From Selected", "Run selected scripts", "rbxassetid://14978048121")
local runScriptFromEditorButton: PluginToolbarButton = toolbar:CreateButton("Run From Editor", "Run script open in editor", "rbxassetid://14978048121")
local runPreviousScriptButton: PluginToolbarButton = toolbar:CreateButton("Run Previous", "Run last selected script", "rbxassetid://14978048121")

openScriptButton.ClickableWhenViewportHidden = true
runScriptFromSelectionButton.ClickableWhenViewportHidden = true
runScriptFromEditorButton.ClickableWhenViewportHidden = true
runPreviousScriptButton.ClickableWhenViewportHidden = true

runScriptFromSelectionButton.Enabled = false
runScriptFromEditorButton.Enabled = false
runPreviousScriptButton.Enabled = false

-- Creates a folder or fetches the current one 
local function GetRunCommandFolder(): Folder

	local runCommandFolder: Folder = ServerStorage:FindFirstChild("RunCommands") or Instance.new("Folder", ServerStorage)
	runCommandFolder.Name = "RunCommands"

	return runCommandFolder

end

-- Executes the script that is given to the function
local function ExecuteScript(selectedScript: Script)
	local newScript: ModuleScript = Instance.new("ModuleScript")

	newScript.Name = HttpService:GenerateGUID()

	local wrapperCode = `\n return coroutine.create(function() {selectedScript.Source} end)`
	ScriptEditorService:UpdateSourceAsync(newScript, function(oldContent: string)
		return wrapperCode
	end)

	local thread: thread = require(newScript) :: thread
	local destroyListener: RBXScriptConnection? = selectedScript:GetPropertyChangedSignal("Parent"):Connect(function()
		if thread then
			print("Destroying Module Script")
			coroutine.close(thread)
		end
	end)

	local success: boolean, runtimeErrorMessage: string = coroutine.resume(thread)

	if not success then
		warn(selectedScript.Name, " got this error: ")
		warn(runtimeErrorMessage)
	end

	while coroutine.status(thread) ~= "dead" do
		task.wait(1)
	end

	if destroyListener then
		destroyListener:Disconnect()
		destroyListener = nil
	end

	if newScript then
		newScript:Destroy()
	end

end

-- Fires respective functions on mouse clicks
openScriptButton.Click:Connect(function() 
	local newScript: Script = Instance.new("Script", GetRunCommandFolder())
	newScript.Name = "NewCommand"

	newScript.Source = "--Click Run Script to execute!\nprint(\"Hello To Run-Command!\")"

	Selection:Set({newScript})
	plugin:OpenScript(newScript)	
end)

local lastRanScript = nil

runScriptFromSelectionButton.Click:Connect(function() 
	local selectedObjects: {Instance} = Selection:Get()

	for _, selected: Instance in selectedObjects do
		if selected:IsA("Script") then
			ExecuteScript(selected)
			lastRanScript = selected
			runPreviousScriptButton.Enabled = true
		end
	end
end)


-- Listens to when you are currently editing a script or not
local currentlyEditing: LuaSourceContainer?
StudioService:GetPropertyChangedSignal("ActiveScript"):Connect(function()

	local newScript: LuaSourceContainer? = StudioService.ActiveScript

	if not newScript then
		runScriptFromEditorButton.Enabled = false
	else
		runScriptFromEditorButton.Enabled = true
		currentlyEditing = newScript
	end

end)

runScriptFromEditorButton.Click:Connect(function() 
	if currentlyEditing then
		ExecuteScript(currentlyEditing :: Script)
		lastRanScript = currentlyEditing
		runPreviousScriptButton.Enabled = true
	end
end)

runPreviousScriptButton.Click:Connect(function()
	local runCommandFolder = GetRunCommandFolder()
	if not lastRanScript then return end
	local isParented = lastRanScript and lastRanScript.Parent == runCommandFolder
	local shouldExecute = lastRanScript and isParented

	if not isParented then
		runPreviousScriptButton.Enabled = false
	end
	
	if shouldExecute then
		ExecuteScript(previousSelected :: Script)
	end
end)


-- When you select a different objects enable run script button
Selection.SelectionChanged:Connect(function()
	local selectedObjects: {Instance} = Selection:Get()

	for _, selected: Instance in selectedObjects do
		if selected:IsA("Script") then
			runScriptFromSelectionButton.Enabled = true
			return
		end
	end

	runScriptFromSelectionButton.Enabled = false
end)
