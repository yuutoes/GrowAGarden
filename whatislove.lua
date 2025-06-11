repeat task.wait() until game:IsLoaded()

local replicatedStorage = game:GetService("ReplicatedStorage")
local collectionService = game:GetService("CollectionService")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local teleportService = game:GetService("TeleportService")
local coreGui = game:GetService("CoreGui")
local httpService = game:GetService("HttpService")

local localPlayer = players.LocalPlayer
local currentCamera = workspace.CurrentCamera

local TARGET_PETS = {
	"Dragon Fly", "dragonfly", "DragonFly",
	"Raccoon", "raccoon",
	"Disco Bee", "discoBee", "Discobee",
	"Queen Bee", "queenbee",
	"RedFox", "red fox", "Red Fox"
}

function PetHatchWebhook()
	if not WebhookURL and not Webhook then return end
	local Data = {
		["content"] = "@everyone",
		["embeds"] = {
			{
				["title"] = "[Auto Hatch] Pet Hatched!",
				["description"] = "Account: **" .. localPlayer.Name .. "** just hatched: **" .. petHook[#petHook] .. "**",
				["color"] = 0x00FF00,
				["image"] = {
					["url"] = "https://cdn.discordapp.com/attachments/1372635822037139496/1381269815313829929/togif.png?ex=6846e742&is=684595c2&hm=49a36f1cffff083cfa138dcc553b2132ddcc8ed693bee9d0f26118dfcd27698f&"
				}
			}
		}
	}
	local success, response = pcall(function()
		return httpService:PostAsync(WebhookURL, httpService:JSONEncode(Data), Enum.HttpContentType.ApplicationJson)
	end)
	if not success then
		warn("Pet Hatch Webhook Error: " .. response)
	end
end

function RejoinWebhook()
	if not WebhookURL and not Webhook then return end
	local Data = {
		["content"] = "@oscosc",
		["embeds"] = {
			{
				["title"] = "[Auto Farm] Rejoined Server!",
				["description"] = "Account: **" .. localPlayer.Name .. "** has rejoined a new server. Current Place ID: **" .. game.PlaceId .. "**",
				["color"] = 0x0000FF,
				["footer"] = {
					["text"] = "Auto Farm Rejoin"
				},
				["timestamp"] = DateTime.now():ToIsoDate(),
				["image"] = {
					["url"] = "https://cdn.discordapp.com/attachments/1372635822037139496/1381269815313829929/togif.png?ex=6846e742&is=684595c2&hm=49a36f1cffff083cfa138dcc553b2132ddcc8ed693bee9d0f26118dfcd27698f&"
				}
			}
		}
	}
	local success, response = pcall(function()
		return httpService:PostAsync(WebhookURL, httpService:JSONEncode(Data), Enum.HttpContentType.ApplicationJson)
	end)
	if not success then
		warn("Rejoin Webhook Error: " .. response)
	end
end

local function normalizePetName(name)
	return (name or ""):gsub("%s+", ""):lower()
end

local NORMALIZED_TARGETS = {}
for _, pet in ipairs(TARGET_PETS) do
	NORMALIZED_TARGETS[normalizePetName(pet)] = true
end

local checkedEggs = {}
local displayed = 0
local targetEggs = {}
local espCache = {}
local activeEggs = {}
local placedEggs = {}
petHook = {}

repeat task.wait() until replicatedStorage:FindFirstChild("GameEvents") and replicatedStorage.GameEvents:FindFirstChild("PetEggService")

local hatchFunc
pcall(function()
	local conns = getconnections(replicatedStorage.GameEvents.PetEggService.OnClientEvent)
	if conns[1] and conns[1].Function then
		hatchFunc = getupvalue(getupvalue(conns[1].Function, 1), 2)
	end
end)

if not hatchFunc then return end

local eggModels = getupvalue(hatchFunc, 1)
local eggPets = getupvalue(hatchFunc, 2)

local ui = Instance.new("ScreenGui")
ui.Name = "EggScannerUI"
ui.ResetOnSpawn = false
pcall(function() ui.Parent = coreGui end)

local slots = {}
local slotHeight = 52
local verticalOffset = 80

local function getSlot(index, total)
	if not slots[index] then
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 250, 0, 28)
		lbl.Position = UDim2.new(0, 10, 0.5, ((index - 1) * slotHeight) - ((total * slotHeight) / 2) + verticalOffset)
		lbl.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.BackgroundTransparency = 0.4
		lbl.TextStrokeTransparency = 0.3
		lbl.Font = Enum.Font.SourceSansBold
		lbl.TextSize = 18
		lbl.Text = "[Waiting...]"
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.AutomaticSize = Enum.AutomaticSize.X
		lbl.Parent = ui
		slots[index] = lbl
	end
	return slots[index]
end

local EGG_TOOL_NAME = "Premium Anti Bee Egg"
local COOLDOWN = 2

local function generatePosition()
	for _, v in pairs(workspace.Farm:GetDescendants()) do
		if v:IsA("StringValue") and v.Name == "Owner" and v.Value == game.Players.LocalPlayer.Name then
			if v.Parent.Parent:FindFirstChild("Plant_Locations") and v.Parent.Parent:FindFirstChild("Plant_Locations"):FindFirstChild("Can_Plant") then
				return v.Parent.Parent:FindFirstChild("Plant_Locations"):FindFirstChild("Can_Plant").CFrame.Position
			end
		end
	end
end

local function findEggTool()
	local backpack = localPlayer:FindFirstChild("Backpack")
	if not backpack then return nil end
	for _, item in ipairs(backpack:GetChildren()) do
		if item:IsA("Tool") and item.Name:find(EGG_TOOL_NAME) then
			return item
		end
	end
	return nil
end

local function equipTool(tool)
	if localPlayer.Character and tool.Parent == localPlayer.Backpack then
		tool.Parent = localPlayer.Character
		task.wait(0.5)
	end
end

local function placeEgg()
	local tool = findEggTool()
	if not tool then
		warn("[ERROR] No tool containing '" .. EGG_TOOL_NAME .. "' found in backpack!")
		return
	end
	local position = generatePosition()
	equipTool(tool)
	local args = {"CreateEgg", position}
	local success, err = pcall(function()
		replicatedStorage.GameEvents.PetEggService:FireServer(unpack(args))
	end)
	if success then
		print("[PLACED] Used", tool.Name, "at", position)
		table.insert(placedEggs, position)
	else
		warn("[PLACEMENT FAILED]", err)
	end
end

local function checkPlacement()
	local tries = 0
	while tries < 50 do
		placeEgg()
		task.wait(COOLDOWN)
		tries = tries + 1
		local eggs = collectionService:GetTagged("PetEggServer")
		if #eggs >= tries then break end
	end
end

local function hatchTargetEggs()
	local petEggService = replicatedStorage.GameEvents.PetEggService
	local hatchCooldown = 1

	for _, egg in ipairs(targetEggs) do
		local args = {"HatchPet", egg}
		local success, err = pcall(function()
			petEggService:FireServer(unpack(args))
		end)

		if success then
			print("[HATCH] Success:", egg:GetAttribute("EggName"))
			PetHatchWebhook()
		else
			warn("[HATCH ERROR]", err)
		end

		task.wait(hatchCooldown)
	end
end

-- Server age filtering and teleport logic
local function isServerFullError()
    local errorPrompt = coreGui:FindFirstChild("ErrorPrompt")
    if errorPrompt and errorPrompt:FindFirstChild("Title") then
        return errorPrompt.Title.Text:lower():find("full") ~= nil
    end
    return false
end

local function checkDone()
    if #targetEggs > 0 then
        print("[AUTO-HATCH] Starting hatch sequence...")
        hatchTargetEggs()
    end
    
    table.clear(targetEggs)
    table.clear(checkedEggs)
    displayed = 0
    
    for _, egg in collectionService:GetTagged("PetEggServer") do
        task.spawn(scanEgg, egg)
    end
    
    print("[TELEPORTING] Finding old server...")
    
    local function filterOldServers(jobIds)
        local now = DateTime.now().UnixTimestamp
        local filtered = {}
        
        for _, jobId in ipairs(jobIds) do
            -- Decode job ID timestamp (approximate method)
            local timestamp = tonumber(jobId:sub(1, 8), 16)
            local serverAgeHours = (now - timestamp) / 3600
            
            if serverAgeHours >= 40 and serverAgeHours <= 50 then
                table.insert(filtered, jobId)
            end
        end
        
        return filtered
    end
    
    while true do
        local success, jobIds = pcall(function()
            return teleportService:GetJobIdsForPlaceAsync(game.PlaceId)
        end)
        
        if success and #jobIds > 0 then
            local oldServers = filterOldServers(jobIds)
            
            if #oldServers > 0 then
                for _, jobId in ipairs(oldServers) do
                    local teleportResult = teleportService:TeleportToPlaceInstance(game.PlaceId, jobId, localPlayer)
                    
                    if teleportResult == Enum.TeleportResult.Success then
                        RejoinWebhook()
                        return
                    elseif isServerFullError() then
                        print("Server full, trying next old server...")
                        task.wait(2)
                    end
                end
            end
        end
        
        -- Fallback to new server if no old servers found
        teleportService:Teleport(game.PlaceId, localPlayer)
        RejoinWebhook()
        task.wait(2)
    end
end

local function scanEgg(egg)
	if egg:GetAttribute("OWNER") ~= localPlayer.Name then return end
	local id = egg:GetAttribute("OBJECT_UUID")
	if checkedEggs[id] then return end
	checkedEggs[id] = true
	displayed += 1

	local eggName = egg:GetAttribute("EggName")
	local petName = eggPets[id] or "Unknown"

	local total = displayed
	local slot = getSlot(displayed, total)
	slot.Text = string.format("[Egg %d] %s → %s", displayed, eggName, petName)
	slot.Size = UDim2.new(0, slot.TextBounds.X + 20, 0, 28)

	local normalized = normalizePetName(petName)
	if NORMALIZED_TARGETS[normalized] then
		table.insert(targetEggs, egg)
		table.insert(petHook, petName)
	end

	local label = Drawing.new("Text")
	label.Text = string.format("%s | %s", eggName, petName)
	label.Size = 18
	label.Color = Color3.new(1, 1, 1)
	label.Outline = true
	label.OutlineColor = Color3.new(0, 0, 0)
	label.Center = true
	label.Visible = false
	espCache[id] = label
	activeEggs[id] = egg
end

local function updateESP()
	for id, egg in pairs(activeEggs) do
		if not egg or not egg:IsDescendantOf(workspace) then
			activeEggs[id] = nil
			if espCache[id] then espCache[id].Visible = false end
			continue
		end

		local label = espCache[id]
		if label then
			local pos, onScreen = currentCamera:WorldToViewportPoint(egg:GetPivot().Position)
			label.Position = Vector2.new(pos.X, pos.Y)
			label.Visible = onScreen
		end
	end
end

task.spawn(function()
    repeat task.wait() until game:IsLoaded()
    repeat task.wait() until replicatedStorage:FindFirstChild("GameEvents") and replicatedStorage.GameEvents:FindFirstChild("PetEggService")
    if hatchFunc then
        while true do
            checkDone()
            task.wait(1)
        end
    else
        warn("Hatch function not found, continuous teleport loop will not start.")
    end
end)

for _, egg in collectionService:GetTagged("PetEggServer") do
	task.spawn(scanEgg, egg)
end

collectionService:GetInstanceAddedSignal("PetEggServer"):Connect(scanEgg)
runService.PreRender:Connect(updateESP)

