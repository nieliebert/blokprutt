-- Enhanced Garden Script dengan fitur Game Guardian style
-- Load Library dan Setup
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()

-- Membuat GUI dengan fitur minimize/maximize
local Window = Library.CreateLib("Grow a Garden - Nuno-Cheat", "Midnight")

-- Pengaturan GUI yang dapat minimize/maximize
local isMinimized = false
local originalSize = UDim2.new(0, 500, 0, 350) -- Ukuran default
local minimizedSize = UDim2.new(0, 150, 0, 30) -- Ukuran saat diminimize
local originalPosition -- Akan disimpan saat runtime
local minimizedPosition = UDim2.new(0.85, 0, 0.05, 0) -- Posisi saat diminimize

-- Menambahkan event untuk mengatur ketika GUI dibuat
task.spawn(function()
    repeat wait() until game:IsLoaded() and Window.Motherframe
    local GUI = Window.Motherframe
    originalPosition = GUI.Position
    
    -- Tambahkan tombol minimize/maximize
    local MinMaxButton = Instance.new("TextButton")
    MinMaxButton.Name = "MinMaxButton"
    MinMaxButton.Size = UDim2.new(0, 20, 0, 20)
    MinMaxButton.Position = UDim2.new(1, -25, 0, 3)
    MinMaxButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MinMaxButton.BorderSizePixel = 0
    MinMaxButton.Text = "-"
    MinMaxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinMaxButton.Font = Enum.Font.SourceSansBold
    MinMaxButton.TextSize = 18
    MinMaxButton.Parent = GUI
    
    MinMaxButton.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        
        if isMinimized then
            -- Simpan konten GUI
            for _, child in pairs(GUI:GetChildren()) do
                if child.Name ~= "MinMaxButton" and child.Name ~= "NameLabel" and child.Name ~= "TopBar" then
                    child.Visible = false
                end
            end
            
            -- Ubah ukuran dan posisi
            GUI:TweenSize(minimizedSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.5, true)
            GUI:TweenPosition(minimizedPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.5, true)
            MinMaxButton.Text = "+"
        else
            -- Restore GUI
            GUI:TweenSize(originalSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.5, true)
            GUI:TweenPosition(originalPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.5, true)
            
            -- Restore konten setelah animasi selesai
            task.delay(0.5, function()
                for _, child in pairs(GUI:GetChildren()) do
                    if child.Name ~= "MinMaxButton" then
                        child.Visible = true
                    end
                end
            end)
            MinMaxButton.Text = "-"
        end
    end)
    
    -- Buat GUI bisa di-drag di mana saja (seperti Game Guardian)
    local UserInputService = game:GetService("UserInputService")
    local isDragging = false
    local dragInput
    local dragStart
    local startPos
    
    GUI.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = GUI.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                end
            end)
        end
    end)
    
    GUI.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and isDragging then
            local delta = input.Position - dragStart
            GUI.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end)

-- Main Tab dengan fitur utama
local Main = Window:NewTab("Main")
local MainSection = Main:NewSection("Main Features")

-- Variabel Global
_G.autoFarm = false
_G.autoCollect = false
_G.autoUpgrade = false
_G.autoReplant = false
_G.autoQuests = false
_G.speedMultiplier = 1
_G.teleportToGarden = false

-- Function untuk mendapatkan karakter player
local function getCharacter()
    local player = game:GetService("Players").LocalPlayer
    return player.Character or player.CharacterAdded:Wait()
end

-- Fungsi Teleport
local function teleportToPosition(position)
    local character = getCharacter()
    if character and character:FindFirstChild("HumanoidRootPart") then
        character:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(position)
    end
end

-- Fitur Auto Farm yang ditingkatkan
MainSection:NewToggle("Auto Farm", "Menyiram tanaman otomatis dengan kecepatan tinggi", function(state)
    _G.autoFarm = state
    while _G.autoFarm and wait(0.5 / _G.speedMultiplier) do
        pcall(function()
            for _,v in pairs(game:GetService("Workspace").Plots:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.ObjectText == "Water Plant" then
                    -- Teleport jika opsi diaktifkan
                    if _G.teleportToGarden and v.Parent and v.Parent:IsA("BasePart") then
                        teleportToPosition(v.Parent.Position + Vector3.new(0, 5, 0))
                    end
                    
                    -- Fire prompt dengan prioritas tinggi
                    fireproximityprompt(v, 0) -- 0 = instant
                end
            end
        end)
    end
end)

-- Auto Collect yang ditingkatkan
MainSection:NewToggle("Auto Collect", "Memanen tanaman otomatis dengan kecepatan tinggi", function(state)
    _G.autoCollect = state
    while _G.autoCollect and wait(0.5 / _G.speedMultiplier) do
        pcall(function()
            for _,v in pairs(game:GetService("Workspace").Plots:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.ObjectText == "Harvest Plant" then
                    -- Teleport jika opsi diaktifkan
                    if _G.teleportToGarden and v.Parent and v.Parent:IsA("BasePart") then
                        teleportToPosition(v.Parent.Position + Vector3.new(0, 5, 0))
                    end
                    
                    -- Fire prompt dengan prioritas tinggi
                    fireproximityprompt(v, 0)
                end
            end
        end)
    end
end)

-- Auto Upgrade yang ditingkatkan
MainSection:NewToggle("Auto Upgrade", "Meningkatkan peralatan otomatis", function(state)
    _G.autoUpgrade = state
    while _G.autoUpgrade and wait(1 / _G.speedMultiplier) do
        pcall(function()
            for _,v in pairs(game:GetService("Workspace").Shops:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.ObjectText:lower():find("upgrade") then
                    -- Teleport jika diperlukan
                    if v.Parent and v.Parent:IsA("BasePart") then
                        teleportToPosition(v.Parent.Position + Vector3.new(0, 5, 0))
                    end
                    
                    fireproximityprompt(v, 0)
                end
            end
        end)
    end
end)

-- Auto Replant (Fitur baru)
MainSection:NewToggle("Auto Replant", "Menanam kembali tanaman secara otomatis", function(state)
    _G.autoReplant = state
    while _G.autoReplant and wait(0.8 / _G.speedMultiplier) do
        pcall(function()
            for _,v in pairs(game:GetService("Workspace").Plots:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.ObjectText == "Plant Seed" then
                    -- Teleport jika diperlukan
                    if _G.teleportToGarden and v.Parent and v.Parent:IsA("BasePart") then
                        teleportToPosition(v.Parent.Position + Vector3.new(0, 5, 0))
                    end
                    
                    fireproximityprompt(v, 0)
                end
            end
        end)
    end
end)

-- Auto Quests (Fitur baru)
MainSection:NewToggle("Auto Quests", "Menyelesaikan quest secara otomatis", function(state)
    _G.autoQuests = state
    while _G.autoQuests and wait(3 / _G.speedMultiplier) do
        pcall(function()
            for _,v in pairs(game:GetService("Workspace").Quests:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.ObjectText == "Complete Quest" then
                    -- Teleport ke quest
                    if v.Parent and v.Parent:IsA("BasePart") then
                        teleportToPosition(v.Parent.Position + Vector3.new(0, 5, 0))
                    end
                    
                    fireproximityprompt(v, 0)
                end
            end
        end)
    end
end)

-- Clear All Quests dengan fitur teleport
MainSection:NewButton("Clear All Quests", "Menyelesaikan semua quest secara langsung", function()
    pcall(function()
        for _,v in pairs(game:GetService("Workspace").Quests:GetDescendants()) do
            if v:IsA("ProximityPrompt") and v.ObjectText == "Complete Quest" then
                -- Teleport ke quest
                if v.Parent and v.Parent:IsA("BasePart") then
                    teleportToPosition(v.Parent.Position + Vector3.new(0, 5, 0))
                    wait(0.2) -- Tunggu sedikit untuk stabilitas
                end
                
                fireproximityprompt(v, 0)
            end
        end
    end)
end)

-- Speed Control (Fitur baru)
local SpeedSection = Main:NewSection("Speed Control")

SpeedSection:NewSlider("Speed Multiplier", "Atur kecepatan proses otomatis", 10, 1, function(value)
    _G.speedMultiplier = value
end)

-- Tab Settings
local Settings = Window:NewTab("Settings")
local SettingsSection = Settings:NewSection("Game Settings")

-- Teleport Options
SettingsSection:NewToggle("Teleport to Garden", "Teleport ke tanaman saat Auto Farm", function(state)
    _G.teleportToGarden = state
end)

-- Anti AFK
SettingsSection:NewToggle("Anti AFK", "Mencegah kick karena AFK", function(state)
    if state then
        local VirtualUser = game:GetService("VirtualUser")
        local antiAFKConnection
        
        antiAFKConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            wait(2)
        end)
        
        _G.antiAFKConnection = antiAFKConnection
    else
        if _G.antiAFKConnection then
            _G.antiAFKConnection:Disconnect()
            _G.antiAFKConnection = nil
        end
    end
end)

-- Tab Player
local Player = Window:NewTab("Player")
local PlayerSection = Player:NewSection("Player Controls")

-- Speed Hack
PlayerSection:NewToggle("Speed Hack", "Meningkatkan kecepatan gerakan", function(state)
    if state then
        _G.speedHackConnection = game:GetService("RunService").RenderStepped:Connect(function()
            pcall(function()
                local humanoid = getCharacter():FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = 50
                end
            end)
        end)
    else
        if _G.speedHackConnection then
            _G.speedHackConnection:Disconnect()
            _G.speedHackConnection = nil
            
            -- Reset speed
            pcall(function()
                local humanoid = getCharacter():FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = 16
                end
            end)
        end
    end
end)

-- Jump Hack
PlayerSection:NewToggle("Jump Hack", "Meningkatkan kemampuan lompat", function(state)
    if state then
        _G.jumpHackConnection = game:GetService("RunService").RenderStepped:Connect(function()
            pcall(function()
                local humanoid = getCharacter():FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.JumpPower = 100
                end
            end)
        end)
    else
        if _G.jumpHackConnection then
            _G.jumpHackConnection:Disconnect()
            _G.jumpHackConnection = nil
            
            -- Reset jump power
            pcall(function()
                local humanoid = getCharacter():FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.JumpPower = 50
                end
            end)
        end
    end
end)

-- No Clip
PlayerSection:NewToggle("No Clip", "Menembus objek di dunia", function(state)
    if state then
        _G.noClipConnection = game:GetService("RunService").Stepped:Connect(function()
            for _, part in pairs(getCharacter():GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        if _G.noClipConnection then
            _G.noClipConnection:Disconnect()
            _G.noClipConnection = nil
            
            -- Reset collision
            for _, part in pairs(getCharacter():GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end)

-- Teleport Tab
local Teleport = Window:NewTab("Teleport")
local TeleportSection = Teleport:NewSection("Location Teleport")

-- Teleport to Garden
TeleportSection:NewButton("Go to Garden", "Teleport ke area garden", function()
    pcall(function()
        local gardenArea = game:GetService("Workspace").Plots:FindFirstChild("PlayerPlot")
        if gardenArea then
            teleportToPosition(gardenArea.Position + Vector3.new(0, 5, 0))
        end
    end)
end)

-- Teleport to Shop
TeleportSection:NewButton("Go to Shop", "Teleport ke area toko", function()
    pcall(function()
        local shopArea = game:GetService("Workspace").Shops:FindFirstChild("Shop")
        if shopArea then
            teleportToPosition(shopArea.Position + Vector3.new(0, 5, 0))
        end
    end)
end)

-- Teleport to Quest Hub
TeleportSection:NewButton("Go to Quest Hub", "Teleport ke area quest", function()
    pcall(function()
        local questArea = game:GetService("Workspace").Quests:FindFirstChild("QuestBoard")
        if questArea then
            teleportToPosition(questArea.Position + Vector3.new(0, 5, 0))
        end
    end)
end)

-- GUI Control Tab
local GUI = Window:NewTab("GUI")
local GUISection = GUI:NewSection("Interface Controls")

-- Toggle GUI dengan hotkey
GUISection:NewKeybind("Toggle UI", "Menampilkan/menyembunyikan GUI", Enum.KeyCode.RightControl, function()
    Library:ToggleUI()
end)

-- Save Settings
GUISection:NewButton("Save Settings", "Menyimpan pengaturan GUI", function()
    local settingsTable = {
        autoFarm = _G.autoFarm,
        autoCollect = _G.autoCollect,
        autoUpgrade = _G.autoUpgrade,
        autoReplant = _G.autoReplant,
        autoQuests = _G.autoQuests,
        speedMultiplier = _G.speedMultiplier,
        teleportToGarden = _G.teleportToGarden
    }
    
    -- Simpan ke file JSON
    local HttpService = game:GetService("HttpService")
    local json = HttpService:JSONEncode(settingsTable)
    writefile("GrowGardenSettings.json", json)
    
    -- Notifikasi
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Settings Saved",
        Text = "Your settings have been saved successfully!",
        Duration = 3
    })
end)

-- Load Settings
GUISection:NewButton("Load Settings", "Memuat pengaturan GUI", function()
    pcall(function()
        if isfile("GrowGardenSettings.json") then
            local HttpService = game:GetService("HttpService")
            local settings = HttpService:JSONDecode(readfile("GrowGardenSettings.json"))
            
            -- Muat pengaturan
            for k, v in pairs(settings) do
                if _G[k] ~= nil then
                    _G[k] = v
                end
            end
            
            -- Notifikasi
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Settings Loaded",
                Text = "Your settings have been loaded successfully!",
                Duration = 3
            })
        end
    end)
end)

-- Credits Tab
local Credits = Window:NewTab("Credits")
local CreditsSection = Credits:NewSection("Script Information")

CreditsSection:NewLabel("Made by: Nuno-Cheat (Upgraded)")
CreditsSection:NewLabel("Version: 2.0 Pro")
CreditsSection:NewLabel("Last Update: May 2025")

-- Auto-execute script greeting
task.spawn(function()
    wait(1)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Script Loaded!",
        Text = "Garden script is ready. Press RightCtrl to toggle GUI.",
        Duration = 5
    })
end)

-- Anti-deteksi dan perlindungan
local AntiCheat = {}
AntiCheat.__index = AntiCheat

function AntiCheat.new()
    local self = setmetatable({}, AntiCheat)
    self:Init()
    return self
end

function AntiCheat:Init()
    -- Bypass hooks
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        -- Bypass anti-cheat checks
        if method == "FireServer" and self.Name:match("Cheat") or self.Name:match("Detection") then
            return wait(9e9)
        end
        
        -- Bypass kick attempts
        if method == "Kick" then
            return wait(9e9)
        end
        
        return oldNamecall(self, ...)
    end)
    
    -- Automatically hide suspicious global variables
    for _, name in pairs({"autoFarm", "autoCollect", "autoUpgrade", "speedMultiplier"}) do
        local success, err = pcall(function()
            local metatable = getrawmetatable(game)
            setreadonly(metatable, false)
        end)
    end
end

-- Inisialisasi AntiCheat
local antiCheat = AntiCheat.new()