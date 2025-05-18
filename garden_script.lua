-- Nie Liebert Garden Script
-- Anti-Ban & Multi-Feature Garden Script

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Anti-Ban System
local function setupAntiBan()
    -- Spoofing system to avoid detection
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        -- Intercept and modify ban-related remote calls
        if method == "FireServer" or method == "InvokeServer" then
            local remoteName = tostring(self)
            
            -- Common ban remote patterns
            if remoteName:match("Ban") or 
               remoteName:match("Report") or 
               remoteName:match("Detect") or 
               remoteName:match("Admin") then
                
                print("Anti-Ban: Blocked suspicious remote: " .. remoteName)
                return nil -- Cancel the remote call
            end
            
            -- Protect against anomaly detection
            if method == "FireServer" and #args >= 1 then
                -- Check for common cheat detection arguments
                if typeof(args[1]) == "string" and 
                   (args[1]:match("Speed") or 
                    args[1]:match("Jump") or 
                    args[1]:match("Teleport") or 
                    args[1]:match("Noclip")) then
                    
                    print("Anti-Ban: Blocked cheat detection")
                    return nil
                end
            end
        end
        
        return oldNamecall(self, ...)
    end)
    
    -- Additional anti-detection measures
    local function spoofProperty(instance, property, value)
        local success, result = pcall(function()
            local mt = getrawmetatable(game)
            local oldindex = mt.__index
            setreadonly(mt, false)
            
            mt.__index = newcclosure(function(self, key)
                if self == instance and key == property then
                    return value
                end
                return oldindex(self, key)
            end)
            
            setreadonly(mt, true)
        end)
        
        if not success then
            warn("Failed to spoof property: " .. tostring(result))
        end
    end
    
    -- Spoof speed values to look legitimate
    spoofProperty(Humanoid, "WalkSpeed", 16)
    spoofProperty(Humanoid, "JumpPower", 50)
end

-- Initialize Anti-Ban
setupAntiBan()

-- Quest System
local QuestSystem = {}
QuestSystem.Quests = {}
QuestSystem.ActiveQuests = {}

function QuestSystem:FindQuests()
    -- Look for quest NPCs or quest objects in the game
    local questGivers = workspace:FindFirstChild("QuestGivers") or workspace:FindFirstChild("NPCs")
    
    if questGivers then
        for _, npc in pairs(questGivers:GetChildren()) do
            if npc:FindFirstChild("QuestPrompt") or npc:FindFirstChild("Interaction") then
                table.insert(self.Quests, {
                    Name = npc.Name,
                    NPC = npc,
                    Position = npc:FindFirstChild("HumanoidRootPart") and npc.HumanoidRootPart.Position or npc.Position
                })
            end
        end
    end
    
    -- Alternatively, find quest remotes
    for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            if remote.Name:match("Quest") or remote.Name:match("Mission") or remote.Name:match("Task") then
                table.insert(self.Quests, {
                    Name = remote.Name,
                    Remote = remote
                })
            end
        end
    end
    
    return self.Quests
end

function QuestSystem:AutoCompleteQuest(questIndex)
    local quest = self.Quests[questIndex]
    if not quest then return end
    
    -- Different approach based on quest type
    if quest.NPC then
        -- Physical quest - go to NPC
        local distanceTween = TweenService:Create(
            HumanoidRootPart,
            TweenInfo.new(2, Enum.EasingStyle.Quad),
            {CFrame = CFrame.new(quest.Position + Vector3.new(0, 0, 3))}
        )
        distanceTween:Play()
        distanceTween.Completed:Wait()
        
        -- Try to interact with NPC
        if quest.NPC:FindFirstChild("Interaction") and quest.NPC.Interaction:IsA("RemoteEvent") then
            quest.NPC.Interaction:FireServer("Accept")
            wait(1)
            quest.NPC.Interaction:FireServer("Complete")
        end
    elseif quest.Remote then
        -- Remote quest - try common patterns
        if quest.Remote:IsA("RemoteEvent") then
            quest.Remote:FireServer("Accept")
            wait(1)
            quest.Remote:FireServer("Complete")
        elseif quest.Remote:IsA("RemoteFunction") then
            quest.Remote:InvokeServer("Accept")
            wait(1)
            quest.Remote:InvokeServer("Complete")
        end
    end
end

function QuestSystem:StartAutoQuest()
    self:FindQuests()
    
    -- Quest completion loop
    spawn(function()
        while self.AutoQuestEnabled do
            for i, quest in pairs(self.Quests) do
                if self.AutoQuestEnabled then
                    self:AutoCompleteQuest(i)
                    wait(3) -- Wait between quests to avoid detection
                else
                    break
                end
            end
            wait(5)
        end
    end)
end

function QuestSystem:ToggleAutoQuest()
    self.AutoQuestEnabled = not self.AutoQuestEnabled
    
    if self.AutoQuestEnabled then
        self:StartAutoQuest()
    end
    
    return self.AutoQuestEnabled
end

-- Farming System
local FarmingSystem = {}
FarmingSystem.Plants = {}
FarmingSystem.RarePlants = {}
FarmingSystem.FarmingEnabled = false

function FarmingSystem:ScanForPlants()
    -- Clear previous plants
    self.Plants = {}
    self.RarePlants = {}
    
    -- Look for plants in common containers
    local plantContainers = {
        workspace:FindFirstChild("Plants"),
        workspace:FindFirstChild("Crops"),
        workspace:FindFirstChild("Harvestables"),
        workspace -- Fallback to entire workspace if specific containers not found
    }
    
    for _, container in pairs(plantContainers) do
        if container then
            for _, object in pairs(container:GetDescendants()) do
                -- Identify plants by common patterns
                if (object:IsA("Model") or object:IsA("Part")) and 
                   (object.Name:match("Plant") or 
                    object.Name:match("Crop") or 
                    object.Name:match("Fruit") or 
                    object.Name:match("Vegetable") or
                    object.Name:match("Seed")) then
                    
                    local position = nil
                    if object:IsA("Model") and object:FindFirstChild("PrimaryPart") then
                        position = object.PrimaryPart.Position
                    elseif object:IsA("Model") and object:FindFirstChild("HumanoidRootPart") then
                        position = object.HumanoidRootPart.Position
                    elseif object:IsA("Model") and object:FindFirstChild("Main") then
                        position = object.Main.Position
                    elseif object:IsA("BasePart") then
                        position = object.Position
                    end
                    
                    if position then
                        local plantInfo = {
                            Name = object.Name,
                            Object = object,
                            Position = position
                        }
                        
                        -- Check if it's rare by name patterns
                        if object.Name:match("Rare") or 
                           object.Name:match("Legendary") or 
                           object.Name:match("Epic") or 
                           object.Name:match("Mythic") or
                           object.Name:match("Special") then
                            table.insert(self.RarePlants, plantInfo)
                        else
                            table.insert(self.Plants, plantInfo)
                        end
                    end
                end
            end
        end
    end
    
    return self.Plants, self.RarePlants
end

function FarmingSystem:HarvestPlant(plantInfo)
    if not plantInfo or not plantInfo.Object or not plantInfo.Object.Parent then return false end
    
    -- Move to plant
    local distanceTween = TweenService:Create(
        HumanoidRootPart,
        TweenInfo.new(1, Enum.EasingStyle.Quad),
        {CFrame = CFrame.new(plantInfo.Position + Vector3.new(0, 3, 0))}
    )
    distanceTween:Play()
    distanceTween.Completed:Wait()
    
    -- Try different harvesting patterns
    local harvested = false
    
    -- Try clicking/touching the plant
    local clickDetector = plantInfo.Object:FindFirstChildOfClass("ClickDetector")
    if clickDetector then
        clickDetector.MaxActivationDistance = 32
        fireclickdetector(clickDetector)
        harvested = true
    end
    
    -- Try interaction with proximity prompt
    local proximityPrompt = plantInfo.Object:FindFirstChildOfClass("ProximityPrompt")
    if proximityPrompt then
        fireproximityprompt(proximityPrompt)
        harvested = true
    end
    
    -- Try common remotes
    for _, descendant in pairs(plantInfo.Object:GetDescendants()) do
        if (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) and
           (descendant.Name:match("Harvest") or 
            descendant.Name:match("Collect") or 
            descendant.Name:match("Pick") or 
            descendant.Name:match("Interact")) then
            
            if descendant:IsA("RemoteEvent") then
                descendant:FireServer()
            else
                descendant:InvokeServer()
            end
            harvested = true
            break
        end
    end
    
    -- If no specific interaction found, look for game-wide remotes
    if not harvested then
        for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
            if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) and
               (remote.Name:match("Harvest") or 
                remote.Name:match("Collect") or 
                remote.Name:match("Pick") or 
                remote.Name:match("Interact")) then
                
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(plantInfo.Object)
                else
                    remote:InvokeServer(plantInfo.Object)
                end
                harvested = true
                break
            end
        end
    end
    
    return harvested
end

function FarmingSystem:StartAutoFarm()
    self:ScanForPlants()
    
    spawn(function()
        while self.FarmingEnabled do
            local plants, rarePlants = self:ScanForPlants()
            
            -- First prioritize rare plants
            for _, plant in pairs(rarePlants) do
                if self.FarmingEnabled then
                    self:HarvestPlant(plant)
                    wait(0.5) -- Small delay between harvests
                else
                    break
                end
            end
            
            -- Then normal plants
            for _, plant in pairs(plants) do
                if self.FarmingEnabled then
                    self:HarvestPlant(plant)
                    wait(0.5)
                else
                    break
                end
            end
            
            wait(3) -- Wait before scanning again
        end
    end)
end

function FarmingSystem:ToggleAutoFarm()
    self.FarmingEnabled = not self.FarmingEnabled
    
    if self.FarmingEnabled then
        self:StartAutoFarm()
    end
    
    return self.FarmingEnabled
end

-- Teleport System
local TeleportSystem = {}
TeleportSystem.Locations = {}

function TeleportSystem:ScanLocations()
    self.Locations = {}
    
    -- Find teleport locations
    local commonLocationContainers = {
        workspace:FindFirstChild("Teleports"),
        workspace:FindFirstChild("Locations"),
        workspace:FindFirstChild("SpawnLocations"),
        workspace
    }
    
    for _, container in pairs(commonLocationContainers) do
        if container then
            for _, object in pairs(container:GetDescendants()) do
                if (object:IsA("Part") or object:IsA("SpawnLocation")) and
                   (object.Name:match("Spawn") or 
                    object.Name:match("Teleport") or
                    object.Name:match("Location") or
                    object:FindFirstChild("Teleport")) then
                    
                    table.insert(self.Locations, {
                        Name = object.Name:gsub("Teleport", ""):gsub("Location", ""):gsub("Spawn", ""),
                        Position = object.Position
                    })
                end
            end
        end
    end
    
    -- Add default locations
    if #self.Locations == 0 then
        -- Find areas with concentration of objects
        local areas = {}
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character) then
                local areaName = nil
                
                -- Check if part of a named model
                local ancestor = obj
                while ancestor.Parent ~= workspace and ancestor.Parent ~= game do
                    ancestor = ancestor.Parent
                    if ancestor:IsA("Model") and ancestor.Name ~= "Baseplate" and ancestor.Name ~= "Terrain" then
                        areaName = ancestor.Name
                        break
                    end
                end
                
                if areaName then
                    if not areas[areaName] then
                        areas[areaName] = {
                            Count = 1,
                            Position = obj.Position
                        }
                    else
                        areas[areaName].Count = areas[areaName].Count + 1
                        -- Update position to average
                        areas[areaName].Position = (areas[areaName].Position * (areas[areaName].Count - 1) + obj.Position) / areas[areaName].Count
                    end
                end
            end
        end
        
        -- Add significant areas to locations
        for name, info in pairs(areas) do
            if info.Count > 10 then -- Only significant clusters
                table.insert(self.Locations, {
                    Name = name,
                    Position = info.Position
                })
            end
        end
    end
    
    -- Add spawn location if we have nothing else
    if #self.Locations == 0 then
        local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
        if spawnLocation then
            table.insert(self.Locations, {
                Name = "Spawn",
                Position = spawnLocation.Position
            })
        end
    end
    
    return self.Locations
end

function TeleportSystem:TeleportTo(location)
    if typeof(location) == "number" then
        location = self.Locations[location]
    end
    
    if not location or not location.Position then return false end
    
    -- Safe teleport with anti-detection measures
    local distance = (HumanoidRootPart.Position - location.Position).Magnitude
    local teleportTime = math.min(distance / 100, 3) -- Cap at 3 seconds
    
    -- Create a smoother teleport using tweens to avoid detection
    local teleportTween = TweenService:Create(
        HumanoidRootPart,
        TweenInfo.new(teleportTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {CFrame = CFrame.new(location.Position + Vector3.new(0, 3, 0))}
    )
    
    teleportTween:Play()
    return true
end

-- Rare Plant Radar System
local RadarSystem = {}
RadarSystem.Enabled = false
RadarSystem.RarePlants = {}
RadarSystem.Markers = {}

function RadarSystem:CreateMarker(position, name, color)
    local marker = Instance.new("Part")
    marker.Anchored = true
    marker.CanCollide = false
    marker.Size = Vector3.new(0.5, 0.5, 0.5)
    marker.Material = Enum.Material.Neon
    marker.Color = color or Color3.fromRGB(255, 255, 0)
    marker.CFrame = CFrame.new(position + Vector3.new(0, 5, 0))
    marker.Transparency = 0.5
    marker.Parent = workspace
    
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = marker
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Text = name or "Rare Plant"
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = billboard
    
    local distance = Instance.new("TextLabel")
    distance.Size = UDim2.new(1, 0, 0.3, 0)
    distance.Position = UDim2.new(0, 0, 0.7, 0)
    distance.BackgroundTransparency = 1
    distance.TextColor3 = Color3.new(1, 1, 1)
    distance.TextStrokeTransparency = 0
    distance.TextStrokeColor3 = Color3.new(0, 0, 0)
    distance.Text = ""
    distance.Font = Enum.Font.Gotham
    distance.TextScaled = true
    distance.Parent = billboard
    
    -- Update distance text
    spawn(function()
        while marker and marker.Parent and HumanoidRootPart and HumanoidRootPart.Parent do
            local dist = (marker.Position - HumanoidRootPart.Position).Magnitude
            distance.Text = math.floor(dist) .. "m"
            wait(0.5)
        end
    end)
    
    return marker
end

function RadarSystem:UpdateRadar()
    -- Clear old markers
    for _, marker in pairs(self.Markers) do
        if marker and marker.Parent then
            marker:Destroy()
        end
    end
    self.Markers = {}
    
    -- Get rare plants from farming system
    local _, rarePlants = FarmingSystem:ScanForPlants()
    self.RarePlants = rarePlants
    
    -- Create markers for rare plants
    for _, plant in pairs(self.RarePlants) do
        local marker = self:CreateMarker(
            plant.Position,
            plant.Name,
            Color3.fromRGB(255, 215, 0) -- Gold color for rare plants
        )
        table.insert(self.Markers, marker)
    end
end

function RadarSystem:StartRadar()
    spawn(function()
        while self.Enabled do
            self:UpdateRadar()
            wait(5) -- Update every 5 seconds
        end
    end)
end

function RadarSystem:ToggleRadar()
    self.Enabled = not self.Enabled
    
    if self.Enabled then
        self:StartRadar()
    else
        -- Clear all markers when disabled
        for _, marker in pairs(self.Markers) do
            if marker and marker.Parent then
                marker:Destroy()
            end
        end
        self.Markers = {}
    end
    
    return self.Enabled
end

-- Player Stats System
local PlayerStatsSystem = {}
PlayerStatsSystem.Enabled = false
PlayerStatsSystem.PlayerStats = {}
PlayerStatsSystem.StatLabels = {}

function PlayerStatsSystem:ScanPlayerStats()
    self.PlayerStats = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character and character:FindFirstChild("Humanoid") then
                local humanoid = character:FindFirstChild("Humanoid")
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                
                local playerInfo = {
                    Name = player.Name,
                    DisplayName = player.DisplayName,
                    Health = humanoid.Health,
                    MaxHealth = humanoid.MaxHealth,
                    Position = rootPart and rootPart.Position or Vector3.new(0, 0, 0),
                    Distance = rootPart and (rootPart.Position - HumanoidRootPart.Position).Magnitude or 0
                }
                
                -- Try to get more stats based on common patterns
                for _, value in pairs(player:GetChildren()) do
                    if value:IsA("IntValue") or value:IsA("NumberValue") or value:IsA("StringValue") then
                        if value.Name:match("Level") or 
                           value.Name:match("Coins") or 
                           value.Name:match("Currency") or
                           value.Name:match("Gems") or
                           value.Name:match("Points") or
                           value.Name:match("Stats") then
                            
                            playerInfo[value.Name] = value.Value
                        end
                    end
                end
                
                -- Also check PlayerGui for visible stats
                if player:FindFirstChild("PlayerGui") then
                    for _, gui in pairs(player.PlayerGui:GetDescendants()) do
                        if gui:IsA("TextLabel") and 
                           (gui.Name:match("Level") or 
                            gui.Name:match("Coins") or
                            gui.Name:match("Stats")) then
                            
                            local text = gui.Text
                            local statMatch = text:match("%d+")
                            if statMatch then
                                playerInfo[gui.Name] = tonumber(statMatch)
                            end
                        end
                    end
                end
                
                table.insert(self.PlayerStats, playerInfo)
            end
        end
    end
    
    -- Sort by distance
    table.sort(self.PlayerStats, function(a, b)
        return a.Distance < b.Distance
    end)
    
    return self.PlayerStats
end

function PlayerStatsSystem:CreateStatLabel(player, position)
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "PlayerStatBillboard"
    billboardGui.AlwaysOnTop = true
    billboardGui.Size = UDim2.new(0, 200, 0, 100)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    
    local background = Instance.new("Frame")
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.BackgroundTransparency = 0.5
    background.BorderSizePixel = 0
    background.Parent = billboardGui
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.25, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Text = player.Name
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextScaled = true
    nameLabel.Parent = background
    
    local healthLabel = Instance.new("TextLabel")
    healthLabel.Size = UDim2.new(1, 0, 0.25, 0)
    healthLabel.Position = UDim2.new(0, 0, 0.25, 0)
    healthLabel.BackgroundTransparency = 1
    healthLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    healthLabel.TextStrokeTransparency = 0
    healthLabel.Text = "HP: " .. math.floor(player.Health) .. "/" .. math.floor(player.MaxHealth)
    healthLabel.Font = Enum.Font.Gotham
    healthLabel.TextScaled = true
    healthLabel.Parent = background
    
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(1, 0, 0.5, 0)
    statsLabel.Position = UDim2.new(0, 0, 0.5, 0)
    statsLabel.BackgroundTransparency = 1
    statsLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    statsLabel.TextStrokeTransparency = 0
    statsLabel.Text = ""
    statsLabel.Font = Enum.Font.Gotham
    statsLabel.TextScaled = true
    statsLabel.Parent = background
    
    -- Add additional stats
    local statsText = ""
    for statName, statValue in pairs(player) do
        if statName ~= "Name" and 
           statName ~= "DisplayName" and 
           statName ~= "Health" and 
           statName ~= "MaxHealth" and
           statName ~= "Position" and
           statName ~= "Distance" then
            
            statsText = statsText .. statName .. ": " .. tostring(statValue) .. "\n"
        end
    end
    
    statsLabel.Text = statsText ~= "" and statsText or "No additional stats"
    
    -- Add to character
    local character = Players:FindFirstChild(player.Name) and Players:FindFirstChild(player.Name).Character
    if character and character:FindFirstChild("Head") then
        billboardGui.Adornee = character.Head
        billboardGui.Parent = character.Head
    else
        -- Create a part at their last known position
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 1
        part.Position = position
        part.Parent = workspace
        
        billboardGui.Adornee = part
        billboardGui.Parent = part
        
        -- Store reference to remove later
        self.StatLabels[player.Name] = {
            GUI = billboardGui,
            Part = part
        }
    end
    
    return billboardGui
end

function PlayerStatsSystem:UpdatePlayerStats()
    -- Clear old labels
    for _, stat in pairs(self.StatLabels) do
        if stat.GUI and stat.GUI.Parent then
            stat.GUI:Destroy()
        end
        
        if stat.Part and stat.Part.Parent then
            stat.Part:Destroy()
        end
    end
    self.StatLabels = {}
    
    -- Get updated stats
    local playerStats = self:ScanPlayerStats()
    
    -- Create new labels
    for _, player in pairs(playerStats) do
        self:CreateStatLabel(player, player.Position)
    end
end

function PlayerStatsSystem:StartPlayerStats()
    spawn(function()
        while self.Enabled do
            self:UpdatePlayerStats()
            wait(3) -- Update every 3 seconds
        end
    end)
end

function PlayerStatsSystem:TogglePlayerStats()
    self.Enabled = not self.Enabled
    
    if self.Enabled then
        self:StartPlayerStats()
    else
        -- Clear all labels when disabled
        for _, stat in pairs(self.StatLabels) do
            if stat.GUI and stat.GUI.Parent then
                stat.GUI:Destroy()
            end
            
            if stat.Part and stat.Part.Parent then
                stat.Part:Destroy()
            end
        end
        self.StatLabels = {}
    end
    
    return self.Enabled
end

-- Create GUI
local function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "NieLiebertGardenScript"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Protection from detection
    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = game.CoreGui
    elseif gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = game.CoreGui
    end
    
    -- Main toggle button
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Size = UDim2.new(0, 50, 0, 50)
    ToggleButton.Position = UDim2.new(0, 10, 0.5, -25)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Text = ">"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.TextSize = 24
    ToggleButton.Parent = ScreenGui
    
    -- Add corner radius
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0.1, 0)
    UICorner.Parent = ToggleButton
    
    -- -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 300, 0, 350)
    MainFrame.Position = UDim2.new(0, -300, 0.5, -175)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    -- Add corner radius to main frame
    local MainFrameCorner = Instance.new("UICorner")
    MainFrameCorner.CornerRadius = UDim.new(0.03, 0)
    MainFrameCorner.Parent = MainFrame
    
    -- Title
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Size = UDim2.new(1, 0, 0, 40)
    TitleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TitleLabel.BorderSizePixel = 0
    TitleLabel.Text = "Nie Liebert Garden Script"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 18
    TitleLabel.Parent = MainFrame
    
    -- Add corner radius to title
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0.1, 0)
    TitleCorner.Parent = TitleLabel
    
    -- Create scrolling frame for buttons
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "ScrollFrame"
    ScrollFrame.Size = UDim2.new(1, -20, 1, -50)
    ScrollFrame.Position = UDim2.new(0, 10, 0, 45)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 400) -- Will be updated based on content
    ScrollFrame.Parent = MainFrame
    
    -- Function to create section
    local function createSection(title, position)
        local section = Instance.new("Frame")
        section.Name = title .. "Section"
        section.Size = UDim2.new(1, 0, 0, 30)
        section.Position = UDim2.new(0, 0, 0, position)
        section.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        section.BorderSizePixel = 0
        section.Parent = ScrollFrame
        
        local sectionLabel = Instance.new("TextLabel")
        sectionLabel.Size = UDim2.new(1, 0, 1, 0)
        sectionLabel.BackgroundTransparency = 1
        sectionLabel.Text = title
        sectionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        sectionLabel.Font = Enum.Font.GothamBold
        sectionLabel.TextSize = 14
        sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
        sectionLabel.TextTransparency = 0.2
        sectionLabel.Parent = section
        
        -- Add padding to text
        local UIPadding = Instance.new("UIPadding")
        UIPadding.PaddingLeft = UDim.new(0, 10)
        UIPadding.Parent = sectionLabel
        
        -- Add corner radius
        local SectionCorner = Instance.new("UICorner")
        SectionCorner.CornerRadius = UDim.new(0.2, 0)
        SectionCorner.Parent = section
        
        return section
    end
    
    -- Function to create a toggle button
    local function createToggleButton(title, description, position, callback)
        local button = Instance.new("Frame")
        button.Name = title .. "Button"
        button.Size = UDim2.new(1, 0, 0, 60)
        button.Position = UDim2.new(0, 0, 0, position)
        button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        button.BorderSizePixel = 0
        button.Parent = ScrollFrame
        
        -- Add corner radius
        local ButtonCorner = Instance.new("UICorner")
        ButtonCorner.CornerRadius = UDim.new(0.1, 0)
        ButtonCorner.Parent = button
        
        -- Button title
        local buttonTitle = Instance.new("TextLabel")
        buttonTitle.Size = UDim2.new(0.7, 0, 0.5, 0)
        buttonTitle.Position = UDim2.new(0, 0, 0, 0)
        buttonTitle.BackgroundTransparency = 1
        buttonTitle.Text = title
        buttonTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        buttonTitle.Font = Enum.Font.GothamBold
        buttonTitle.TextSize = 16
        buttonTitle.TextXAlignment = Enum.TextXAlignment.Left
        buttonTitle.Parent = button
        
        -- Add padding to text
        local TitlePadding = Instance.new("UIPadding")
        TitlePadding.PaddingLeft = UDim.new(0, 10)
        TitlePadding.Parent = buttonTitle
        
        -- Button description
        local buttonDesc = Instance.new("TextLabel")
        buttonDesc.Size = UDim2.new(0.7, 0, 0.5, 0)
        buttonDesc.Position = UDim2.new(0, 0, 0.5, 0)
        buttonDesc.BackgroundTransparency = 1
        buttonDesc.Text = description
        buttonDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
        buttonDesc.Font = Enum.Font.Gotham
        buttonDesc.TextSize = 14
        buttonDesc.TextXAlignment = Enum.TextXAlignment.Left
        buttonDesc.TextTransparency = 0.3
        buttonDesc.Parent = button
        
        -- Add padding to description
        local DescPadding = Instance.new("UIPadding")
        DescPadding.PaddingLeft = UDim.new(0, 10)
        DescPadding.Parent = buttonDesc
        
        -- Toggle indicator
        local toggleIndicator = Instance.new("Frame")
        toggleIndicator.Name = "ToggleIndicator"
        toggleIndicator.Size = UDim2.new(0, 40, 0, 24)
        toggleIndicator.Position = UDim2.new(0.9, -20, 0.5, -12)
        toggleIndicator.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        toggleIndicator.BorderSizePixel = 0
        toggleIndicator.Parent = button
        
        -- Add corner radius to indicator
        local IndicatorCorner = Instance.new("UICorner")
        IndicatorCorner.CornerRadius = UDim.new(0.5, 0)
        IndicatorCorner.Parent = toggleIndicator
        
        -- Toggle circle
        local toggleCircle = Instance.new("Frame")
        toggleCircle.Name = "ToggleCircle"
        toggleCircle.Size = UDim2.new(0, 18, 0, 18)
        toggleCircle.Position = UDim2.new(0, 3, 0.5, -9)
        toggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        toggleCircle.BorderSizePixel = 0
        toggleCircle.Parent = toggleIndicator
        
        -- Add corner radius to circle
        local CircleCorner = Instance.new("UICorner")
        CircleCorner.CornerRadius = UDim.new(1, 0)
        CircleCorner.Parent = toggleCircle
        
        -- Click detection and toggle functionality
        local clickArea = Instance.new("TextButton")
        clickArea.Size = UDim2.new(1, 0, 1, 0)
        clickArea.BackgroundTransparency = 1
        clickArea.Text = ""
        clickArea.Parent = button
        
        local enabled = false
        
        clickArea.MouseButton1Click:Connect(function()
            enabled = not enabled
            
            -- Visual update
            if enabled then
                toggleIndicator.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
                toggleCircle:TweenPosition(UDim2.new(0, 19, 0.5, -9), "Out", "Sine", 0.2, true)
            else
                toggleIndicator.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                toggleCircle:TweenPosition(UDim2.new(0, 3, 0.5, -9), "Out", "Sine", 0.2, true)
            end
            
            -- Run callback
            if callback then
                callback(enabled)
            end
        end)
        
        return button
    end
    
    -- Create sections and buttons
    local positionY = 0
    
    -- Farming section
    local farmingSection = createSection("Farming", positionY)
    positionY = positionY + 40
    
    -- Auto farm button
local autoFarmButton = createToggleButton("Auto Farm", "Automatically harvest and plant crops", positionY, function(enabled)
    if enabled then
        print("Auto Farm enabled")
        -- Implement auto farm functionality here
    else
        print("Auto Farm disabled")
        -- Disable auto farm functionality here
    end
end)
positionY = positionY + 70

-- Auto collect button
local autoCollectButton = createToggleButton("Auto Collect", "Automatically collect all resources", positionY, function(enabled)
    if enabled then
        print("Auto Collect enabled")
        -- Implement auto collect functionality here
    else
        print("Auto Collect disabled")
        -- Disable auto collect functionality here
    end
end)
positionY = positionY + 70

-- Speed section
local speedSection = createSection("Character Modifications", positionY)
positionY = positionY + 40

-- Speed hack button
local speedHackButton = createToggleButton("Speed Boost", "Increase character movement speed", positionY, function(enabled)
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    
    if enabled then
        print("Speed Boost enabled")
        humanoid.WalkSpeed = 32 -- Increased speed
    else
        print("Speed Boost disabled")
        humanoid.WalkSpeed = 16 -- Default speed
    end
end)
positionY = positionY + 70

-- Jump boost button
local jumpBoostButton = createToggleButton("Jump Boost", "Increase character jump height", positionY, function(enabled)
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    
    if enabled then
        print("Jump Boost enabled")
        humanoid.JumpPower = 75 -- Increased jump
    else
        print("Jump Boost disabled")
        humanoid.JumpPower = 50 -- Default jump
    end
end)
positionY = positionY + 70

-- Teleport section
local teleportSection = createSection("Teleportation", positionY)
positionY = positionY + 40

-- Teleport to garden button
local teleportGardenButton = createToggleButton("TP to Garden", "Teleport to your garden area", positionY, function(enabled)
    if enabled then
        print("Teleporting to garden")
        
        local player = game.Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        
        -- Replace these coordinates with actual garden coordinates
        humanoidRootPart.CFrame = CFrame.new(100, 10, 200)
        
        -- Auto turn off after teleporting
        local button = ScrollFrame:FindFirstChild("TP to GardenButton")
        if button then
            local clickArea = button:FindFirstChildOfClass("TextButton")
            if clickArea then
                clickArea.MouseButton1Click:Fire()
            end
        end
    end
end)
positionY = positionY + 70

-- Teleport to shop button
local teleportShopButton = createToggleButton("TP to Shop", "Teleport to the shop area", positionY, function(enabled)
    if enabled then
        print("Teleporting to shop")
        
        local player = game.Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        
        -- Replace these coordinates with actual shop coordinates
        humanoidRootPart.CFrame = CFrame.new(150, 10, 300)
        
        -- Auto turn off after teleporting
        local button = ScrollFrame:FindFirstChild("TP to ShopButton")
        if button then
            local clickArea = button:FindFirstChildOfClass("TextButton")
            if clickArea then
                clickArea.MouseButton1Click:Fire()
            end
        end
    end
end)
positionY = positionY + 70

-- Misc section
local miscSection = createSection("Miscellaneous", positionY)
positionY = positionY + 40

-- Anti AFK button
local antiAFKButton = createToggleButton("Anti AFK", "Prevent being kicked for inactivity", positionY, function(enabled)
    if enabled then
        print("Anti AFK enabled")
        
        -- Create anti-AFK system
        local antiAFK = game:GetService("VirtualUser")
        local connection
        
        connection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
            antiAFK:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            wait(1)
            antiAFK:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            print("Anti-AFK triggered")
        end)
        
        -- Store connection in script for later disconnection
        script.antiAFKConnection = connection
    else
        print("Anti AFK disabled")
        
        -- Disable anti-AFK system
        if script.antiAFKConnection then
            script.antiAFKConnection:Disconnect()
            script.antiAFKConnection = nil
        end
    end
end)
positionY = positionY + 70

-- Auto sell button
local autoSellButton = createToggleButton("Auto Sell", "Automatically sell harvested resources", positionY, function(enabled)
    if enabled then
        print("Auto Sell enabled")
        -- Implement auto sell functionality here
    else
        print("Auto Sell disabled")
        -- Disable auto sell functionality here
    end
end)
positionY = positionY + 70

-- Update canvas size based on content
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, positionY + 10)

-- Toggle GUI visibility
local guiVisible = false
local tweenService = game:GetService("TweenService")

-- Function to toggle GUI
local function toggleGUI()
    guiVisible = not guiVisible
    
    local targetPosition
    if guiVisible then
        targetPosition = UDim2.new(0, 20, 0.5, -175)
    else
        targetPosition = UDim2.new(0, -300, 0.5, -175)
    end
    
    local tweenInfo = TweenInfo.new(
        0.5,
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    )
    
    local tween = tweenService:Create(MainFrame, tweenInfo, {Position = targetPosition})
    tween:Play()
end

-- -- Create toggle button
local toggleButton = Instance.new("ImageButton")
toggleButton.Size = UDim2.new(0, 40, 0, 40)
toggleButton.Position = UDim2.new(0, -40, 0.5, -20)
toggleButton.AnchorPoint = Vector2.new(0, 0.5)
toggleButton.Image = "rbxassetid://3926307971" -- Menu icon
toggleButton.ImageRectOffset = Vector2.new(604, 724)
toggleButton.ImageRectSize = Vector2.new(36, 36)
toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
toggleButton.BorderSizePixel = 0
toggleButton.Parent = ScreenGui

-- Add rounded corners to toggle button
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleButton

-- Connect toggle button click event
toggleButton.MouseButton1Click:Connect(toggleGUI)

-- Initialize GUI in hidden state
MainFrame.Position = UDim2.new(0, -300, 0.5, -175)

-- Add GUI dragging functionality
local UserInputService = game:GetService("UserInputService")
local dragging = false
local dragInput
local dragStart
local startPos

local function updateDrag(input)
    local delta = input.Position - dragInput.Position
    MainFrame.Position = UDim2.new(
        startPos.X.Scale, 
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        updateDrag(input)
    end
end)

-- Add keybind to toggle GUI
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
        toggleGUI()
    end
end)

-- Function to check if auto farm is enabled
local function isAutoFarmEnabled()
    local button = ScrollFrame:FindFirstChild("Auto FarmButton")
    if button then
        local toggle = button:FindFirstChild("ToggleFrame")
        if toggle then
            return toggle.BackgroundColor3 == Color3.fromRGB(0, 170, 255)
        end
    end
    return false
end

-- Function to check if auto collect is enabled
local function isAutoCollectEnabled()
    local button = ScrollFrame:FindFirstChild("Auto CollectButton")
    if button then
        local toggle = button:FindFirstChild("ToggleFrame")
        if toggle then
            return toggle.BackgroundColor3 == Color3.fromRGB(0, 170, 255)
        end
    end
    return false
end

-- Function to check if auto sell is enabled
local function isAutoSellEnabled()
    local button = ScrollFrame:FindFirstChild("Auto SellButton")
    if button then
        local toggle = button:FindFirstChild("ToggleFrame")
        if toggle then
            return toggle.BackgroundColor3 == Color3.fromRGB(0, 170, 255)
        end
    end
    return false
end

-- Main loop for script features
local RunService = game:GetService("RunService")

-- Variables to control timing
local farmCooldown = 0
local collectCooldown = 0
local sellCooldown = 0

RunService.Heartbeat:Connect(function(deltaTime)
    -- Auto Farm functionality
    if isAutoFarmEnabled() then
        farmCooldown = farmCooldown - deltaTime
        if farmCooldown <= 0 then
            -- Implement auto farming logic here
            -- Example:
            local player = game.Players.LocalPlayer
            local character = player.Character or player.CharacterAdded:Wait()
            
            -- Find nearest harvestable plant
            local nearestPlant = findNearestPlant()
            if nearestPlant then
                -- Interact with the plant
                interactWithPlant(nearestPlant)
            end
            
            farmCooldown = 1.5 -- Set cooldown between farm actions (1.5 seconds)
        end
    end
    
    -- Auto Collect functionality
    if isAutoCollectEnabled() then
        collectCooldown = collectCooldown - deltaTime
        if collectCooldown <= 0 then
            -- Implement auto collect logic here
            -- Example:
            local player = game.Players.LocalPlayer
            local character = player.Character or player.CharacterAdded:Wait()
            
            -- Find nearest collectible resource
            local nearestResource = findNearestResource()
            if nearestResource then
                -- Collect the resource
                collectResource(nearestResource)
            end
            
            collectCooldown = 1.0 -- Set cooldown between collect actions (1 second)
        end
    end
    
    -- Auto Sell functionality
    if isAutoSellEnabled() then
        sellCooldown = sellCooldown - deltaTime
        if sellCooldown <= 0 then
            -- Implement auto sell logic here
            -- Example:
            local player = game.Players.LocalPlayer
            local backpack = player:WaitForChild("Backpack")
            
            -- Check if inventory has items to sell
            if hasItemsToSell(backpack) then
                -- Teleport to shop if needed
                teleportToShop()
                -- Sell all items
                sellAllItems()
            end
            
            sellCooldown = 5.0 -- Set cooldown between sell actions (5 seconds)
        end
    end
end)

-- Placeholder functions for the farming system
-- These would need to be implemented based on the specific game

function findNearestPlant()
    -- Implementation would depend on how plants are structured in the game
    -- Example:
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    local nearestDistance = math.huge
    local nearestPlant = nil
    
    -- Loop through potential plants in workspace
    for _, plant in pairs(workspace.Plants:GetChildren()) do
        if plant:FindFirstChild("Harvestable") and plant.Harvestable.Value == true then
            local distance = (plant.PrimaryPart.Position - humanoidRootPart.Position).Magnitude
            if distance < nearestDistance and distance < 50 then
                nearestDistance = distance
                nearestPlant = plant
            end
        end
    end
    
    return nearestPlant
end

function interactWithPlant(plant)
    -- Implementation would depend on how plant interaction works in the game
    -- Example:
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Move closer to plant if needed
    if (plant.PrimaryPart.Position - humanoidRootPart.Position).Magnitude > 10 then
        humanoidRootPart.CFrame = CFrame.new(
            plant.PrimaryPart.Position + Vector3.new(0, 2, 0),
            plant.PrimaryPart.Position
        )
    end
    
    -- Fire remote event to harvest plant
    game.ReplicatedStorage.RemoteEvents.HarvestPlant:FireServer(plant)
    
    -- Plant new seed if the plant was harvested
    game.ReplicatedStorage.RemoteEvents.PlantSeed:FireServer(plant.PlantID.Value, plant.PlotID.Value)
end

function findNearestResource()
    -- Implementation would depend on how resources are structured in the game
    -- Example:
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    local nearestDistance = math.huge
    local nearestResource = nil
    
    -- Loop through potential resources in workspace
    for _, resource in pairs(workspace.Resources:GetChildren()) do
        if resource:FindFirstChild("Collectible") and resource.Collectible.Value == true then
            local distance = (resource.PrimaryPart.Position - humanoidRootPart.Position).Magnitude
            if distance < nearestDistance and distance < 50 then
                nearestDistance = distance
                nearestResource = resource
            end
        end
    end
    
    return nearestResource
end

function collectResource(resource)
    -- Implementation would depend on how resource collection works in the game
    -- Example:
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Move closer to resource if needed
    if (resource.PrimaryPart.Position - humanoidRootPart.Position).Magnitude > 10 then
        humanoidRootPart.CFrame = CFrame.new(
            resource.PrimaryPart.Position + Vector3.new(0, 2, 0),
            resource.PrimaryPart.Position
        )
    end
    
    -- Fire remote event to collect resource
    game.ReplicatedStorage.RemoteEvents.CollectResource:FireServer(resource)
end

function hasItemsToSell(backpack)
    -- Implementation would depend on how inventory system works in the game
    -- Example:
    for _, item in pairs(backpack:GetChildren()) do
        if item:FindFirstChild("Sellable") and item.Sellable.Value == true then
            return true
        end
    end
    
    return false
end

function teleportToShop()
    -- Implementation would teleport player to shop area
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Replace these coordinates with actual shop coordinates
    humanoidRootPart.CFrame = CFrame.new(150, 10, 300)
end

function sellAllItems()
    -- Implementation would depend on how selling works in the game
    -- Example:
    -- Fire remote event to sell all items
    game.ReplicatedStorage.RemoteEvents.SellAllItems:FireServer()
end

-- Display notification when script is loaded
local notificationGui = Instance.new("ScreenGui")
notificationGui.Name = "ScriptNotification"
notificationGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local notification = Instance.new("Frame")
notification.Size = UDim2.new(0, 300, 0, 50)
notification.Position = UDim2.new(0.5, -150, 0, -60)
notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
notification.BorderSizePixel = 0
notification.Parent = notificationGui

local notificationCorner = Instance.new("UICorner")
notificationCorner.CornerRadius = UDim.new(0, 8)
notificationCorner.Parent = notification

local notificationText = Instance.new("TextLabel")
notificationText.Size = UDim2.new(1, -20, 1, 0)
notificationText.Position = UDim2.new(0, 10, 0, 0)
notificationText.BackgroundTransparency = 1
notificationText.TextColor3 = Color3.fromRGB(255, 255, 255)
notificationText.TextSize = 16
notificationText.Font = Enum.Font.GothamSemibold
notificationText.Text = "Farming Script Loaded! Press Right Ctrl to toggle GUI"
notificationText.TextXAlignment = Enum.TextXAlignment.Center
notificationText.Parent = notification

-- Animate notification
local tweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(
    0.5,
    Enum.EasingStyle.Quart,
    Enum.EasingDirection.Out
)

notification:TweenPosition(UDim2.new(0.5, -150, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.5, true)

wait(3)

-- Fade out notification
local fadeOutTween = tweenService:Create(notification, tweenInfo, {Position = UDim2.new(0.5, -150, 0, -60)})
fadeOutTween:Play()

fadeOutTween.Completed:Connect(function()
    notificationGui:Destroy()
end)

-- Log script loaded in console
print("Farming Script v1.0 loaded successfully!")
print("Press Right Ctrl to toggle the script GUI")

-- Add anti-AFK system
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

-- Prevent AFK kicks
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("Anti-AFK: Prevented AFK kick")
end)

-- Add teleport function for various farm areas
local teleportLocations = {
    ["Farm"] = Vector3.new(250, 10, 150),
    ["Forest"] = Vector3.new(350, 10, 200),
    ["Mountain"] = Vector3.new(450, 50, 300),
    ["Desert"] = Vector3.new(550, 10, 400),
    ["Shop"] = Vector3.new(150, 10, 300)
}

function teleportToLocation(locationName)
    local location = teleportLocations[locationName]
    if location then
        local player = game.Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        
        humanoidRootPart.CFrame = CFrame.new(location)
        print("Teleported to " .. locationName)
    else
        print("Invalid teleport location: " .. locationName)
    end
end

-- Create teleport buttons in the GUI
for locationName, _ in pairs(teleportLocations) do
    createFeatureButton(locationName .. " Teleport", function()
        teleportToLocation(locationName)
    end)
end

-- Add auto-upgrade system
local playerStats = player:WaitForChild("PlayerStats")
local coins = playerStats:WaitForChild("Coins")

function canAffordUpgrade(upgradeCost)
    return coins.Value >= upgradeCost
end

function purchaseUpgrade(upgradeType)
    -- Implement purchasing logic based on game mechanics
    -- Example:
    local upgradeCosts = {
        ["Speed"] = 500,
        ["Capacity"] = 750,
        ["Efficiency"] = 1000
    }
    
    local cost = upgradeCosts[upgradeType]
    if cost and canAffordUpgrade(cost) then
        -- Fire remote event to purchase upgrade
        game.ReplicatedStorage.RemoteEvents.PurchaseUpgrade:FireServer(upgradeType)
        print("Purchased " .. upgradeType .. " upgrade for " .. cost .. " coins")
        return true
    else
        print("Cannot afford " .. upgradeType .. " upgrade")
        return false
    end
end

-- Create upgrade buttons in the GUI
local upgradeTypes = {"Speed", "Capacity", "Efficiency"}
for _, upgradeType in ipairs(upgradeTypes) do
    createFeatureButton("Upgrade " .. upgradeType, function()
        purchaseUpgrade(upgradeType)
    end)
end

-- Add auto-rebirth system
local autoRebirthEnabled = false
local rebirthCooldown = 0

function canRebirth()
    -- Implement rebirth condition check based on game mechanics
    -- Example:
    local requiredLevel = 25
    return player.PlayerStats.Level.Value >= requiredLevel
end

function performRebirth()
    -- Implement rebirth logic based on game mechanics
    -- Example:
    game.ReplicatedStorage.RemoteEvents.Rebirth:FireServer()
    print("Performed rebirth!")
end

-- Create auto-rebirth toggle button
createToggleButton("Auto Rebirth", function(enabled)
    autoRebirthEnabled = enabled
    print("Auto Rebirth " .. (enabled and "enabled" or "disabled"))
end)

-- Add auto-rebirth to main loop
RunService.Heartbeat:Connect(function(deltaTime)
    -- Previously implemented auto features are still running...
    
    -- Auto Rebirth functionality
    if autoRebirthEnabled then
        rebirthCooldown = rebirthCooldown - deltaTime
        if rebirthCooldown <= 0 then
            if canRebirth() then
                performRebirth()
            end
            rebirthCooldown = 10.0 -- Set cooldown between rebirth attempts (10 seconds)
        end
    end
end)

-- Add statistics display
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(0, 280, 0, 100)
statsFrame.Position = UDim2.new(0, 10, 0, 290)
statsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
statsFrame.BorderSizePixel = 0
statsFrame.Parent = MainFrame

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 8)
statsCorner.Parent = statsFrame

local statsTitle = Instance.new("TextLabel")
statsTitle.Size = UDim2.new(1, 0, 0, 30)
statsTitle.Position = UDim2.new(0, 0, 0, 0)
statsTitle.BackgroundTransparency = 1
statsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
statsTitle.TextSize = 16
statsTitle.Font = Enum.Font.GothamSemibold
statsTitle.Text = "Statistics"
statsTitle.Parent = statsFrame

local statsContent = Instance.new("TextLabel")
statsContent.Size = UDim2.new(1, -20, 1, -40)
statsContent.Position = UDim2.new(0, 10, 0, 30)
statsContent.BackgroundTransparency = 1
statsContent.TextColor3 = Color3.fromRGB(200, 200, 200)
statsContent.TextSize = 14
statsContent.Font = Enum.Font.Gotham
statsContent.Text = "Loading statistics..."
statsContent.TextXAlignment = Enum.TextXAlignment.Left
statsContent.TextYAlignment = Enum.TextYAlignment.Top
statsContent.Parent = statsFrame

-- Update statistics periodically
local sessionsStats = {
    itemsCollected = 0,
    itemsSold = 0,
    coinsEarned = 0,
    startTime = os.time()
}

-- Connect to relevant events to track statistics
game.ReplicatedStorage.RemoteEvents.CollectResource.OnClientEvent:Connect(function()
    sessionsStats.itemsCollected = sessionsStats.itemsCollected + 1
end)

game.ReplicatedStorage.RemoteEvents.SellAllItems.OnClientEvent:Connect(function(amount)
    sessionsStats.itemsSold = sessionsStats.itemsSold + 1
    sessionsStats.coinsEarned = sessionsStats.coinsEarned + (amount or 0)
end)

-- Update statistics display
local function updateStats()
    local elapsedTime = os.time() - sessionsStats.startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    
    local timeString = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    
    statsContent.Text = string.format(
        "Session Time: %s\nItems Collected: %d\nItems Sold: %d\nCoins Earned: %d",
        timeString,
        sessionsStats.itemsCollected,
        sessionsStats.itemsSold,
        sessionsStats.coinsEarned
    )
end

-- Update stats every second
while wait(1) do
    updateStats()
end

-- Add settings system
local settingsFilePath = "FarmingScriptSettings.json"

local defaultSettings = {
    autoFarm = false,
    autoCollect = false,
    autoSell = false,
    autoRebirth = false,
    farmDelay = 1.5,
    collectDelay = 1.0,
    sellDelay = 5.0,
    rebirthDelay = 10.0
}

local currentSettings = table.clone(defaultSettings)

-- Load settings from file
local function loadSettings()
    local success, result = pcall(function()
        if isfile(settingsFilePath) then
            return game:GetService("HttpService"):JSONDecode(readfile(settingsFilePath))
        end
        return nil
    end)
    
    if success and result then
        -- Merge saved settings with default settings
        for key, value in pairs(result) do
            currentSettings[key] = value
        end
        print("Settings loaded successfully!")
    else
        print("Failed to load settings or settings file doesn't exist")
    end
end

-- Save settings to file
local function saveSettings()
    local success, result = pcall(function()
        local json = game:GetService("HttpService"):JSONEncode(currentSettings)
        writefile(settingsFilePath, json)
        return true
    end)
    
    if success then
        print("Settings saved successfully!")
    else
        print("Failed to save settings: " .. tostring(result))
    end
end

-- Apply loaded settings
local function applySettings()
    -- Apply toggle states
    local toggles = {
        ["Auto Farm"] = "autoFarm",
        ["Auto Collect"] = "autoCollect",
        ["Auto Sell"] = "autoSell",
        ["Auto Rebirth"] = "autoRebirth"
    }
    
    for buttonName, settingName in pairs(toggles) do
        local button = ScrollFrame:FindFirstChild(buttonName .. "Button")
        if button then
            local toggle = button:FindFirstChild("ToggleFrame")
            if toggle then
                -- Set toggle state based on settings
                if currentSettings[settingName] then
                    toggle.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
                else
                    toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                end
            end
        end
    end
    
    -- Apply cooldown values
    farmCooldown = currentSettings.farmDelay
    collectCooldown = currentSettings.collectDelay
    sellCooldown = currentSettings.sellDelay
    rebirthCooldown = currentSettings.rebirthDelay
end

-- Try to load settings on script start
loadSettings()
applySettings()

-- Add save/reset settings buttons
createFeatureButton("Save Settings", function()
    -- Update current settings from toggle states
    currentSettings.autoFarm = isAutoFarmEnabled()
    currentSettings.autoCollect = isAutoCollectEnabled()
    currentSettings.autoSell = isAutoSellEnabled()
    currentSettings.autoRebirth = autoRebirthEnabled
    
    -- Save settings to file
    saveSettings()
    
    -- Show notification
    showNotification("Settings saved successfully!")
end)

createFeatureButton("Reset Settings", function()
    -- Reset to default settings
    currentSettings = table.clone(defaultSettings)
    
    -- Apply reset settings
    applySettings()
    
    -- Save reset settings to file
    saveSettings()
    
    -- Show notification
    showNotification("Settings reset to defaults!")
end)

-- Function to show notification
function showNotification(message, duration)
    duration = duration or 3
    
    local notificationGui = Instance.new("ScreenGui")
    notificationGui.Name = "ScriptNotification"
    notificationGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, 300, 0, 50)
    notification.Position = UDim2.new(0.5, -150, 0, -60)
    notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    notification.BorderSizePixel = 0
    notification.Parent = notificationGui
    
    local notificationCorner = Instance.new("UICorner")
    notificationCorner.CornerRadius = UDim.new(0, 8)
    notificationCorner.Parent = notification
    
    local notificationText = Instance.new("TextLabel")
    notificationText.Size = UDim2.new(1, -20, 1, 0)
    notificationText.Position = UDim2.new(0, 10, 0, 0)
    notificationText.BackgroundTransparency = 1
    notificationText.TextColor3 = Color3.fromRGB(255, 255, 255)
    notificationText.TextSize = 16
    notificationText.Font = Enum.Font.GothamSemibold
    notificationText.Text = message
    notificationText.TextXAlignment = Enum.TextXAlignment.Center
    notificationText.Parent = notification
    
    -- Animate notification
    local tweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(
        0.5,
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    )
    
    notification:TweenPosition(UDim2.new(0.5, -150, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.5, true)
    
    wait(duration)
    
    -- Fade out notification
    local fadeOutTween = tweenService:Create(notification, tweenInfo, {Position = UDim2.new(0.5, -150, 0, -60)})
    fadeOutTween:Play()
    
    fadeOutTween.Completed:Connect(function()
        notificationGui:Destroy()
    end)
end

-- Add auto-detect game features
local function detectGameFeatures()
    local detectedFeatures = {}
    
    -- Check for plant system
    if workspace:FindFirstChild("Plants") then
        table.insert(detectedFeatures, "Farming")
    end
    
    -- Check for resource system
    if workspace:FindFirstChild("Resources") then
        table.insert(detectedFeatures, "Resources")
    end
    
    -- Check for shop system
    if workspace:FindFirstChild("Shops") or game.ReplicatedStorage:FindFirstChild("ShopItems") then
        table.insert(detectedFeatures, "Shop")
    end
    
    -- Check for rebirth system
    if game.ReplicatedStorage.RemoteEvents:FindFirstChild("Rebirth") then
        table.insert(detectedFeatures, "Rebirth")
    end
    
    return detectedFeatures
end

-- Update GUI based on detected features
local detectedFeatures = detectGameFeatures()
if #detectedFeatures > 0 then
    print("Detected game features: " .. table.concat(detectedFeatures, ", "))
    showNotification("Detected features: " .. table.concat(detectedFeatures, ", "), 5)
else
    print("No specific game features detected")
    showNotification("No specific game features detected", 5)
end

-- Add error handling and recovery
local function safeCallback(callback)
    return function(...)
        local success, result = pcall(callback, ...)
        if not success then
            print("Error in callback: " .. tostring(result))
            -- Try to recover from error
            if string.find(tostring(result), "Player is not available") then
                wait(1)
                return safeCallback(callback)(...)
            end
        end
        return result
    end
end

-- Wrap critical functions with error handling
findNearestPlant = safeCallback(findNearestPlant)
interactWithPlant = safeCallback(interactWithPlant)
findNearestResource = safeCallback(findNearestResource)
collectResource = safeCallback(collectResource)
teleportToShop = safeCallback(teleportToShop)
sellAllItems = safeCallback(sellAllItems)

-- Add version checking and update notification
local currentVersion = "1.0"
local function checkForUpdates()
    -- This is a placeholder for actual update checking logic
    -- In a real implementation, this would make an HTTP request to check for updates
    local latestVersion = "1.1" -- Simulated latest version
    
    if latestVersion ~= currentVersion then
        showNotification("Update available: v" .. latestVersion, 5)
        return true
    end
    return false
end

-- Check for updates periodically
spawn(function()
    while wait(3600) do -- Check once per hour
        checkForUpdates()
    end
end)

-- Final setup
print("Farming Script v" .. currentVersion .. " fully initialized!")
print("Detected game features: " .. table.concat(detectedFeatures, ", "))
print("Settings loaded: " .. (isfile(settingsFilePath) and "Yes" or "No"))