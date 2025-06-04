local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local character = Workspace:WaitForChild(localPlayer.Name)

local function findToolEquipped()
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            return tool
        end
    end
    return nil
end

local function getTypeTool(tool)
    local toolType = tool:GetAttribute("ItemType") or "Unknown"
    if type(toolType) ~= "string" then
        return "Unknown"
    end

    if toolType == "Seed" then
        return "Seed"
    elseif toolType == "Pet" then
        return "Pet"
    elseif toolType == "Holdable" then
        return "Fruit"
    else
        return "Unknown"
    end
end

local function dupeSeed(tool)
    local originalName = tool.Name
    local currentQuantity = tonumber(tool:GetAttribute("Quantity")) or 1

    print(string.format("Duplicating Seed: '%s', Current Quantity Attribute: %d", originalName, currentQuantity))

    local newQuantity = currentQuantity + 1
    tool:SetAttribute("Quantity", newQuantity)
    print(string.format("Set Attribute 'Quantity' to: %d", newQuantity))

    local newName = originalName
    local patternX = "(%S+)%s*%[X(%d+)%]"
    local patternSimple = "(%S+)%s*%[(%d+)%]"

    local baseName, _ = originalName:match(patternX)
    if baseName then
        newName = originalName:gsub("%[X%d+]", "[X" .. newQuantity .. "]")
    else
        baseName, _ = originalName:match(patternSimple)
        if baseName then
            newName = originalName:gsub("%[%d+]", "[" .. newQuantity .. "]")
        else
            print(string.format("Warning: Quantity pattern not found or not recognized in tool name: '%s'. Name will not be updated based on quantity.", originalName))
        end
    end
    
    if newName ~= originalName then
        tool.Name = newName
        print(string.format("Set Tool Name to: '%s'", newName))
    else
        print(string.format("Tool Name remains: '%s'", tool.Name))
    end
    
    print("Seed duplicated (modified equipped tool): " .. tool.Name .. ", New Quantity: " .. newQuantity)
end

local function dupeToolInBackPack()
    local tool = findToolEquipped()
    if tool then
        local toolType = getTypeTool(tool)
        print("Tool type: " .. toolType)
        if toolType == "Unknown" then
            print("Tool type is unknown, cannot duplicate.")
            return
        end
        if toolType == "Seed" then
            dupeSeed(tool)
            return
        end
        local clonedTool = tool:Clone()
        
        local existingUuidAttribute = clonedTool:GetAttribute("UUID")
        if existingUuidAttribute then
            local newUuid = HttpService:GenerateGUID()
            clonedTool:SetAttribute("UUID", newUuid)
            print("New UUID generated for cloned tool: " .. newUuid)
        end
        
        clonedTool.Parent = localPlayer.Backpack
        print("Tool duplicated and added to backpack: " .. clonedTool.Name)
    else
        print("No tool equipped to duplicate.")
    end
end

-- Simple way to execute the function (you can bind this to a key or use in other ways)
dupeToolInBackPack()
