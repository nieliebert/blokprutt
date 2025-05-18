--[[
    Enhanced Blox Fruits Script
    Created by: Nie Liebert
    Last Updated: May 18, 2025
    Features:
    - Auto Farm
    - Auto Quest
    - Weapon Selection
    - Fast Attack
    - Bring Mob
    - Auto Rejoin
    - Server Hop
    - Safety Features
    - Full Customizable UI
]]

-- Configuration (dapat disesuaikan)
local Config = {
    AutoFarm = false, -- Aktifkan/nonaktifkan auto farm
    Weapon = "Melee", -- "Melee", "Sword", "Gun", "Fruit" (pilihan senjata)
    AutoEquipWeapon = true, -- Otomatis menggunakan senjata terbaik
    FastAttack = true, -- Serangan cepat
    BringMob = true, -- Tarik musuh ke karakter
    Quest = "BanditQuest1",-- Quest yang ingin diambil
    QuestLevel = 1, -- Level quest
    TargetMob = "Bandit", -- Target musuh
    HopIfServerEmpty = false, -- Ganti server jika kosong
    Distance = 15, -- Jarak serangan
    SafetyHealth = 30, -- % health untuk keluar dari pertempuran
    AutoRejoin = true, -- Otomatis rejoin jika terputus
    AutoSkill = true, -- Otomatis menggunakan skill
    KillAura = false, -- Kill Aura (menyerang semua musuh dalam radius)
    KillAuraRange = 30, -- Radius kill aura
    ChestFarm = false, -- Auto ambil chest
    CollectFruit = false, -- Auto ambil fruit
    SelectedSkills = {
-- Skill yang ingin digunakan
        Z = true,
        X = true,
        C = true,
        V = false
    },
    TweenSpeed = 150 -- Kecepatan teleport (lebih tinggi = lebih cepat)
}

-- Variabel dan Services
local Player = game:GetService("Players").LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Mencoba mendapatkan RemoteEvents yang diperlukan
local Remotes, CommF, Combat
local success, err = pcall(function()
    Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    CommF = Remotes:WaitForChild("CommF_", 5)
    Combat = Remotes:WaitForChild("Combat", 5)
    end)

if not success then
warn("Error saat mengambil RemoteEvents, mencoba metode alternatif...")
-- Metode alternatif untuk mencari Remote Events
for _, v in pairs(ReplicatedStorage:GetDescendants()) do
if v.Name == "Remotes" then Remotes = v end
if v.Name == "CommF_" then CommF = v end
if v.Name == "Combat" then Combat = v end
end
end

-- Memastikan workspace folders ada
local Enemies = workspace:FindFirstChild("Enemies") or Instance.new("Folder")
if not workspace:FindFirstChild("Enemies") then
Enemies.Name = "Enemies"
Enemies.Parent = workspace
end

local QuestNPCs = workspace:FindFirstChild("QuestNPCs") or workspace:FindFirstChild("NPCs") or Instance.new("Folder")
if not workspace:FindFirstChild("QuestNPCs") and not workspace:FindFirstChild("NPCs") then
QuestNPCs.Name = "QuestNPCs"
QuestNPCs.Parent = workspace
end

-- Variables untuk tracking state
local AutoFarmConnection = nil
local UIActive = false
local FailCount = 0
local ChestCooldown = false
local LastTargetTime = 0
local NoTargetCount = 0
local SessionStartTime = os.time()
local MobsKilled = 0
local SessionStats = {
    StartTime = os.time(),
    MobsKilled = 0,
    LevelGained = 0,
    ChestsCollected = 0,
    FruitsCollected = 0,
    BelliEarned = 0
}

-- Anti-AFK
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("Anti-AFK triggered")
    end)

-- Character handling
local function SetupCharacter(Char)
Character = Char
Humanoid = Character:WaitForChild("Humanoid")
HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Setup health changed event
Humanoid.HealthChanged:Connect(function()
    if Config.AutoFarm and Humanoid.Health <= (Humanoid.MaxHealth * Config.SafetyHealth / 100) then
    print("Health rendah! Menunggu regenerasi...")
    local SafePosition = HumanoidRootPart.CFrame + Vector3.new(0, 50, 0)
    SafeTeleport(SafePosition)
    wait(5) -- Wait untuk regenerasi
    end
    end)
end

Player.CharacterAdded:Connect(SetupCharacter)

-- Fungsi Utilitas
local function GetDistance(Pos1, Pos2)
return (Pos1 - Pos2).Magnitude
end

local function CreateTween(Object, Time, Style, Direction, Properties)
local TweenInfo = TweenInfo.new(Time, Enum.EasingStyle[Style], Enum.EasingDirection[Direction])
local Tween = TweenService:Create(Object, TweenInfo, Properties)
return Tween
end

local function Teleport(Pos)
if not Character or not HumanoidRootPart then return end

local Distance = GetDistance(HumanoidRootPart.Position, Pos)
local Speed = math.clamp(Distance / Config.TweenSpeed, 0.1, 1) -- Kecepatan tween berdasarkan jarak

local Tween = CreateTween(
    HumanoidRootPart,
    Speed,
    "Linear",
    "In",
    {
        CFrame = CFrame.new(Pos)}
)

Tween:Play()
return Tween
end

local function SafeTeleport(CF)
if not Character or not HumanoidRootPart then return end

local CurrentPosition = HumanoidRootPart.Position
local TargetPosition = CF.Position

-- Safety check untuk tinggi teleport
if TargetPosition.Y < -50 then
TargetPosition = Vector3.new(TargetPosition.X, 0, TargetPosition.Z)
end

-- Coba tween terlebih dahulu
local Success, TweenError = pcall(function()
    local Tween = Teleport(TargetPosition)
    Tween.Completed:Wait()
    end)

-- Jika tween gagal, coba teleport langsung
if not Success then
pcall(function()
    HumanoidRootPart.CFrame = CFrame.new(TargetPosition)
    end)
end
end

-- Fungsi untuk mendapatkan senjata terbaik
local function GetBestWeapon(Type)
local Backpack = Player:FindFirstChild("Backpack")
if not Backpack then return nil end

local WeaponType = Type or Config.Weapon
local HighestDamage = 0
local BestWeapon = nil

-- Pemetaan tipe senjata ke identifikasi
local TypeIdentifiers = {
    ["Melee"] = {
        "Combat", "Superhuman", "ElectricClaw", "DragonTalon", "Godhuman", "DeathStep", "SharkmanKarate"
    },
    ["Sword"] = {
        "Sword", "Katana", "Saber", "Buddy Sword", "Midnight Blade", "Shisui", "Saddi", "Wando", "Yama"
    },
    ["Gun"] = {
        "Gun", "Flintlock", "Musket", "Kabucha", "Acidum Rifle", "Soul Guitar"
    },
    ["Fruit"] = {
        "Blox Fruit", "Fruit", "Chop", "Spike", "Spring", "Bomb", "Smoke", "Flame", "Ice", "Sand", "Dark", "Light", "Rubber", "Barrier", "Magma", "Quake", "Human: Buddha", "String", "Bird: Phoenix", "Rumble", "Paw", "Gravity", "Dough", "Shadow", "Venom", "Control", "Spirit", "Dragon", "Leopard"
    }
}

-- Cari senjata berdasarkan tipe
local SelectedIdentifiers = TypeIdentifiers[WeaponType] or TypeIdentifiers["Melee"]

-- Pertama coba cari di karakter (senjata yang sudah diequip)
for _, Tool in pairs(Character:GetChildren()) do
if Tool:IsA("Tool") then
for _, Identifier in pairs(SelectedIdentifiers) do
if Tool.Name:find(Identifier) then
return Tool.Name
end
end
end
end

-- Kemudian cari di backpack
for _, Tool in pairs(Backpack:GetChildren()) do
if Tool:IsA("Tool") then
for _, Identifier in pairs(SelectedIdentifiers) do
if Tool.Name:find(Identifier) then
return Tool.Name
end
end
end
end

-- Jika tidak menemukan senjata spesifik, ambil tool pertama
for _, Tool in pairs(Backpack:GetChildren()) do
if Tool:IsA("Tool") then
return Tool.Name
end
end

return nil
end

-- Fungsi untuk mengequip senjata
local function EquipWeapon(WeaponName)
if not WeaponName then
WeaponName = GetBestWeapon()
end

if not WeaponName then return false end

local Backpack = Player:FindFirstChild("Backpack")
if not Backpack then return false end

local Weapon = Backpack:FindFirstChild(WeaponName)
if not Weapon then return false end

Humanoid:EquipTool(Weapon)
return true
end

-- Fungsi untuk menggunakan skill
local function UseSkill(Key)
if not Config.AutoSkill or not Config.SelectedSkills[Key] then return end

local VIM = game:GetService("VirtualInputManager")
VIM:SendKeyEvent(true, Enum.KeyCode[Key], false, game)
wait(0.1)
VIM:SendKeyEvent(false, Enum.KeyCode[Key], false, game)
end

-- Fungsi untuk mengambil quest
local function GetQuest()
if not CommF then
warn("CommF_ remote tidak tersedia!")
return false
end

local Args = {
    [1] = "StartQuest",
    [2] = Config.Quest,
    [3] = Config.QuestLevel
}

local Success, Result = pcall(function()
    return CommF:InvokeServer(unpack(Args))
    end)

if Success then
print("Quest diambil:", Config.Quest, Config.QuestLevel)
else
    warn("Gagal mengambil quest:", Result)
end

return Success
end

-- Fungsi untuk mengecek apakah quest sedang aktif
local function IsQuestActive()
local QuestGui = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("Main") and Player.PlayerGui.Main:FindFirstChild("Quest")

if QuestGui and QuestGui.Visible then
local QuestTitle = QuestGui:FindFirstChild("Container") and QuestGui.Container:FindFirstChild("QuestTitle")

if QuestTitle and QuestTitle.Text:find(Config.Quest) then
return true
end
end

return false
end

-- Fungsi untuk mendapatkan target musuh
local function GetTarget()
local ClosestDistance = math.huge
local Target = nil

for _, Enemy in pairs(Enemies:GetChildren()) do
if Enemy.Name == Config.TargetMob and Enemy:FindFirstChild("Humanoid") and Enemy.Humanoid.Health > 0 and Enemy:FindFirstChild("HumanoidRootPart") then

local Distance = GetDistance(HumanoidRootPart.Position, Enemy.HumanoidRootPart.Position)

if Distance < ClosestDistance then
ClosestDistance = Distance
Target = Enemy
end
end
end

return Target, ClosestDistance
end

-- Fungsi untuk kill aura
local function KillAura()
if not Config.KillAura then return end

for _, Enemy in pairs(Enemies:GetChildren()) do
if Enemy:FindFirstChild("Humanoid") and Enemy.Humanoid.Health > 0 and Enemy:FindFirstChild("HumanoidRootPart") then

local Distance = GetDistance(HumanoidRootPart.Position, Enemy.HumanoidRootPart.Position)

if Distance <= Config.KillAuraRange then
-- Attack
pcall(function()
    if Combat then
    Combat:FireServer("SwingKatana")
    end

-- Gunakan skills secara otomatis
    UseSkill("Z")
    UseSkill("X")
    UseSkill("C")
    UseSkill("V")
    end)
end
end
end
end

-- Fungsi untuk menarik musuh
local function BringMob(Target)
if not Config.BringMob or not Target then return end

pcall(function()
    firetouchinterest(HumanoidRootPart, Target.HumanoidRootPart, 0)
    firetouchinterest(HumanoidRootPart, Target.HumanoidRootPart, 1)

    Target.HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.new(0, 0, -Config.Distance)
    Target.HumanoidRootPart.CanCollide = false
    Target.HumanoidRootPart.Size = Vector3.new(50, 50, 50)

    if not Target.HumanoidRootPart:FindFirstChild("BodyVelocity") then
    local BV = Instance.new("BodyVelocity")
    BV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    BV.Velocity = Vector3.new(0, 0, 0)
    BV.Parent = Target.HumanoidRootPart
    end
    end)
end

-- Fungsi untuk menyerang
local function Attack()
if not Combat then
warn("Combat remote tidak tersedia!")
return
end

if Config.FastAttack then
-- Fast attack method
for i = 1, 3 do -- Multiple attacks per cycle
pcall(function()
    Combat:FireServer("SwingKatana")
    Combat:FireServer("M1")
    Combat:FireServer("KnifeSpecial")
    end)
wait(0.05) -- Small delay between attacks
end
else
-- Normal attack
    pcall(function()
    Combat:FireServer("SwingKatana")
    end)
wait(0.2)
end

-- Auto skill
if Config.AutoSkill then
UseSkill("Z")
wait(0.2)
UseSkill("X")
wait(0.2)
UseSkill("C")
wait(0.2)
UseSkill("V")
end
end

-- Fungsi untuk collect chest
local function CollectChests()
if not Config.ChestFarm or ChestCooldown then return end

ChestCooldown = true

-- Cari semua chest di workspace
for _, v in pairs(workspace:GetChildren()) do
if string.find(v.Name, "Chest") and v:IsA("Part") or v:IsA("Model") then
if v:FindFirstChild("Mesh") or v:FindFirstChild("TouchInterest") then
local ChestPos = v:IsA("Model") and v:GetModelCFrame().Position or v.Position

-- Teleport ke chest
SafeTeleport(CFrame.new(ChestPos))
wait(1)

-- Coba interaksi dengan chest
pcall(function()
    firetouchinterest(HumanoidRootPart, v, 0)
    firetouchinterest(HumanoidRootPart, v, 1)
    end)

-- Update stats
SessionStats.ChestsCollected = SessionStats.ChestsCollected + 1

wait(0.5)
end
end
end

-- Cooldown
wait(30)
ChestCooldown = false
end

-- Fungsi untuk collect fruit
local function CollectFruits()
if not Config.CollectFruit then return end

-- Cari semua fruit di workspace
for _, v in pairs(workspace:GetChildren()) do
if string.find(v.Name, "Fruit") and v:IsA("Tool") then
if v:FindFirstChild("Handle") then
local FruitPos = v.Handle.Position

-- Teleport ke fruit
SafeTeleport(CFrame.new(FruitPos))
wait(1)

-- Coba interaksi dengan fruit
pcall(function()
    firetouchinterest(HumanoidRootPart, v.Handle, 0)
    firetouchinterest(HumanoidRootPart, v.Handle, 1)
    end)

-- Update stats
SessionStats.FruitsCollected = SessionStats.FruitsCollected + 1

wait(0.5)
end
end
end
end

-- Fungsi untuk update stats
local function UpdateSessionStats()
-- Update level gained
if Player:FindFirstChild("Data") and Player.Data:FindFirstChild("Level") then
local CurrentLevel = Player.Data.Level.Value
local StartLevel = SessionStats.StartLevel or CurrentLevel
SessionStats.LevelGained = CurrentLevel - StartLevel
SessionStats.StartLevel = StartLevel
end

-- Update belli earned
if Player:FindFirstChild("Data") and Player.Data:FindFirstChild("Beli") then
local CurrentBeli = Player.Data.Beli.Value
local StartBeli = SessionStats.StartBeli or CurrentBeli
SessionStats.BelliEarned = CurrentBeli - StartBeli
SessionStats.StartBeli = StartBeli
end

-- Update session duration
SessionStats.Duration = os.time() - SessionStats.StartTime
end

-- Main loop untuk Auto Farm
local function StartAutoFarm()
if AutoFarmConnection then return end

print("Auto Farm dimulai")

AutoFarmConnection = RunService.Heartbeat:Connect(function()
    if not Config.AutoFarm then
    if AutoFarmConnection then
    AutoFarmConnection:Disconnect()
    AutoFarmConnection = nil
    end
    return
    end

    pcall(function()
-- Cek health
        if Humanoid.Health <= (Humanoid.MaxHealth * Config.SafetyHealth / 100) then
        print("Health rendah! Menunggu regenerasi...")
        local SafePosition = HumanoidRootPart.CFrame + Vector3.new(0, 50, 0)
        SafeTeleport(SafePosition)
        wait(5) -- Wait untuk regenerasi
        return
        end

-- Kill Aura
        if Config.KillAura then
        KillAura()
        end

-- Collect Chest
        if Config.ChestFarm and not ChestCooldown then
        spawn(CollectChests)
        end

-- Collect Fruit
        if Config.CollectFruit then
        spawn(CollectFruits)
        end

-- Cek quest
        if not IsQuestActive() then
        GetQuest()
        wait(1)
        end

-- Equip senjata
        if Config.AutoEquipWeapon and not Character:FindFirstChildOfClass("Tool") then
        EquipWeapon()
        wait(0.5)
        end

-- Cari target
        local Target, Distance = GetTarget()

-- Jika target ditemukan
        if Target then
        LastTargetTime = os.time()
        NoTargetCount = 0

-- Teleport ke target
        local TargetCFrame = Target.HumanoidRootPart.CFrame * CFrame.new(0, 0, Config.Distance)
        SafeTeleport(TargetCFrame)

-- Bring mob
        BringMob(Target)

-- Serang
        Attack()

-- Check if target died
        if Target.Humanoid.Health <= 0 then
        MobsKilled = MobsKilled + 1
        SessionStats.MobsKilled = SessionStats.MobsKilled + 1
        end
        else
-- Jika tidak ada target, cari di lokasi spawn
            NoTargetCount = NoTargetCount + 1

-- Lokasi spawn potensial untuk berbagai mob
        local SpawnLocations = {
-- Starter Island
            CFrame.new(1057.8779296875, 16.516111373901367, 1545.8231201171875), -- Bandit area
            CFrame.new(977.0507202148438, 16.273073196411133, 1451.3717041015625), -- Bandit area 2
-- Jika mob lain ditambahkan, tambahkan lokasi spawn mereka di sini
            CFrame.new(-7894.6176757813, 5545.6030273438, -380.29119873047), -- Snow Mountain
            CFrame.new(-4607.82275, 872.54248, -1667.55688), -- Upper Skypiea
            CFrame.new(-7112.73389, 5612.3823, -1459.00659) -- Cold Island
        }

        for _, SpawnLocation in ipairs(SpawnLocations) do
        SafeTeleport(SpawnLocation)
        wait(1)

        local NewTarget = GetTarget()
        if NewTarget then
        break
        end
        end

-- Jika sudah coba semua lokasi tapi tetap tidak ada target, coba server hop
        if NoTargetCount > 30 and Config.HopIfServerEmpty then
        print("Tidak ada target dalam 30 iterasi, mencoba server hop...")
        ServerHop()
        end
        end

-- Update stats setiap 60 detik
        if os.time() % 60 == 0 then
        UpdateSessionStats()
        end
        end)
    end)
end

-- Fungsi untuk server hop
local function ServerHop()
if not Config.HopIfServerEmpty then return end

local PlayerCount = #game:GetService("Players"):GetPlayers()

if PlayerCount <= 1 then
print("Server kosong, mencari server baru...")
local servers = {}

-- Coba get servers
local success, result = pcall(function()
    local req = game:HttpGet('https://games.roblox.com/v1/games/' .. game.PlaceId .. '/servers/Public?sortOrder=Desc&limit=100')
    return HttpService:JSONDecode(req)
    end)

if success and result and result.data then
for _, v in pairs(result.data) do
if v.playing < v.maxPlayers and v.id ~= game.JobId then
table.insert(servers, v.id)
end
end

if #servers > 0 then
local randomServer = servers[math.random(1, #servers)]
print("Server baru ditemukan, teleporting...")

local success, error = pcall(function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, Player)
    end)

if not success then
warn("Gagal teleport:", error)
end

-- Tunggu beberapa detik untuk teleport
wait(5)
else
    print("Tidak ada server yang tersedia")
end
else
    warn("Gagal mendapatkan daftar server")
end
end
end

-- Error handling dan restart otomatis
local function StartScript()
local Success, Error = pcall(function()
    StartAutoFarm()
    end)

if not Success then
FailCount = FailCount + 1
warn("Script error:", Error)

if AutoFarmConnection then
AutoFarmConnection:Disconnect()
AutoFarmConnection = nil
end

if FailCount >= 5 and Config.AutoRejoin then
print("Terlalu banyak error, mencoba untuk rejoin...")
TeleportService:Teleport(game.PlaceId, Player)
return
end

wait(5) -- Tunggu sebelum restart
StartScript() -- Coba restart script
end
end

-- UI Components untuk GUI
local GUI = {}

-- Fungsi untuk membuat rounded frame
local function CreateRoundedFrame(Size, Position, Color, Parent, AnchorPoint)
local Frame = Instance.new("Frame")
Frame.Size = Size
Frame.Position = Position
Frame.BackgroundColor3 = Color
Frame.BorderSizePixel = 0
Frame.Parent = Parent

if AnchorPoint then
Frame.AnchorPoint = AnchorPoint
end

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Frame

return Frame
end

-- Fungsi untuk membuat slider
local function CreateSlider(Title, Min, Max, DefaultValue, Parent, Callback)
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -20, 0, 50)
Container.Position = UDim2.new(0, 10, 0, 0)
Container.BackgroundTransparency = 1
Container.Parent = Parent

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 20)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = Title
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Container

local SliderBG = Instance.new("Frame")
SliderBG.Size = UDim2.new(0.7, 0, 0, 10)
SliderBG.Position = UDim2.new(0, 0, 0, 25)
SliderBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SliderBG.BorderSizePixel = 0
SliderBG.Parent = Container

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 5)
UICorner.Parent = SliderBG

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new((DefaultValue - Min) / (Max - Min), 0, 1, 0)
SliderFill.Position = UDim2.new(0, 0, 0, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderBG

local UICorner2 = Instance.new("UICorner")
UICorner2.CornerRadius = UDim.new(0, 5)
UICorner2.Parent = SliderFill

local ValueLabel = Instance.new("TextLabel")
ValueLabel.Size = UDim2.new(0.25, 0, 0, 20)
ValueLabel.Position = UDim2.new(0.75, 0, 0, 20)
ValueLabel.BackgroundTransparency = 1
ValueLabel.Text = tostring(DefaultValue)
ValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ValueLabel.TextSize = 14
ValueLabel.Font = Enum.Font.SourceSans
ValueLabel.Parent = Container

-- Slider functionality
local IsSliding = false
local Value = DefaultValue

SliderBG.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    IsSliding = true

    local SliderPosition = math.clamp((input.Position.X - SliderBG.AbsolutePosition.X) / SliderBG.AbsoluteSize.X, 0, 1)
    Value = Min + (Max - Min) * SliderPosition
    Value = math.floor(Value * 10) / 10 -- Round to 1 decimal place

    SliderFill.Size = UDim2.new(SliderPosition, 0, 1, 0)
    ValueLabel.Text = tostring(Value)

    if Callback then
    Callback(Value)
    end
    end
    end)

UserInputService.InputChanged:Connect(function(input)
    if IsSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    local SliderPosition = math.clamp((input.Position.X - SliderBG.AbsolutePosition.X) / SliderBG.AbsoluteSize.X, 0, 1)
    Value = Min + (Max - Min) * SliderPosition
    Value = math.floor(Value * 10) / 10 -- Round to 1 decimal place

    SliderFill.Size = UDim2.new(SliderPosition, 0, 1, 0)
    ValueLabel.Text = tostring(Value)

    if Callback then
    Callback(Value)
    end
    end
    end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    IsSliding = false
    end
    end)

return Container, function()
return Value
end
end

-- Fungsi untuk membuat toggle button
local function CreateToggle(Title, DefaultValue, Parent, Callback)
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -20, 0, 30)
Container.Position = UDim2.new(0, 10, 0, 0)
Container.BackgroundTransparency = 1
Container.Parent = Parent

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = Title
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Container

local ToggleBG = Instance.new("Frame")
ToggleBG.Size = UDim2.new(0, 40, 0, 20)
ToggleBG.Position = UDim2.new(0.75, 0, 0.5, -10)
ToggleBG.BackgroundColor3 = DefaultValue and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(50, 50, 50)
ToggleBG.BorderSizePixel = 0
ToggleBG.Parent = Container

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = ToggleBG

local Toggle = Instance.new("Frame")
Toggle.Size = UDim2.new(0, 16, 0, 16)
Toggle.Position = DefaultValue and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
Toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Toggle.BorderSizePixel = 0
Toggle.Parent = ToggleBG

local UICorner2 = Instance.new("UICorner")
UICorner2.CornerRadius = UDim.new(0, 8)
UICorner2.Parent = Toggle

-- Toggle functionality
local IsEnabled = DefaultValue

ToggleBG.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    IsEnabled = not IsEnabled

    if IsEnabled then
    ToggleBG.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    Toggle.Position = UDim2.new(1, -18, 0.5, -8)
    else
        ToggleBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Toggle.Position = UDim2.new(0, 2, 0.5, -8)
    end

    if Callback then
    Callback(IsEnabled)
    end
    end
    end)

return Container, function()
return IsEnabled
end, function(Value)
IsEnabled = Value

if IsEnabled then
ToggleBG.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
Toggle.Position = UDim2.new(1, -18, 0.5, -8)
else
    ToggleBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Toggle.Position = UDim2.new(0, 2, 0.5, -8)
end
end
end

-- Fungsi untuk membuat dropdown
local function CreateDropdown(Title, Options, DefaultValue, Parent, Callback)
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -20, 0, 60)
Container.Position = UDim2.new(0, 10, 0, 0)
Container.BackgroundTransparency = 1
Container.Parent = Parent

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 20)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = Title
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Container

local DropdownButton = Instance.new("TextButton")
DropdownButton.Size = UDim2.new(1, 0, 0, 30)
DropdownButton.Position = UDim2.new(0, 0, 0, 25)
DropdownButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
DropdownButton.BorderSizePixel = 0
DropdownButton.Text = DefaultValue or Options[1]
DropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DropdownButton.TextSize = 14
DropdownButton.Font = Enum.Font.SourceSans
DropdownButton.TextXAlignment = Enum.TextXAlignment.Left
DropdownButton.TextTruncate = Enum.TextTruncate.AtEnd
DropdownButton.Parent = Container

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingLeft = UDim.new(0, 10)
UIPadding.Parent = DropdownButton

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = DropdownButton

local DropdownArrow = Instance.new("ImageLabel")
DropdownArrow.Size = UDim2.new(0, 20, 0, 20)
DropdownArrow.Position = UDim2.new(1, -25, 0.5, -10)
DropdownArrow.BackgroundTransparency = 1
DropdownArrow.Image = "rbxassetid://3926305904"
DropdownArrow.ImageRectOffset = Vector2.new(564, 284)
DropdownArrow.ImageRectSize = Vector2.new(36, 36)
DropdownArrow.Parent = DropdownButton

local DropdownMenu = Instance.new("Frame")
DropdownMenu.Size = UDim2.new(1, 0, 0, #Options * 30)
DropdownMenu.Position = UDim2.new(0, 0, 1, 5)
DropdownMenu.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
DropdownMenu.BorderSizePixel = 0
DropdownMenu.Visible = false
DropdownMenu.ZIndex = 5
DropdownMenu.Parent = DropdownButton

local UICorner2 = Instance.new("UICorner")
UICorner2.CornerRadius = UDim.new(0, 6)
UICorner2.Parent = DropdownMenu

-- Create options
for i, Option in pairs(Options) do
local OptionButton = Instance.new("TextButton")
OptionButton.Size = UDim2.new(1, 0, 0, 30)
OptionButton.Position = UDim2.new(0, 0, 0, (i-1) * 30)
OptionButton.BackgroundTransparency = 1
OptionButton.Text = Option
OptionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
OptionButton.TextSize = 14
OptionButton.Font = Enum.Font.SourceSans
OptionButton.TextXAlignment = Enum.TextXAlignment.Left
OptionButton.ZIndex = 6
OptionButton.Parent = DropdownMenu

local UIPadding2 = Instance.new("UIPadding")
UIPadding2.PaddingLeft = UDim.new(0, 10)
UIPadding2.Parent = OptionButton

OptionButton.MouseButton1Click:Connect(function()
    DropdownButton.Text = Option
    DropdownMenu.Visible = false

    if Callback then
    Callback(Option)
    end
    end)
end

-- Dropdown functionality
local IsOpen = false

DropdownButton.MouseButton1Click:Connect(function()
    IsOpen = not IsOpen
    DropdownMenu.Visible = IsOpen
    end)

return Container, function()
return DropdownButton.Text
end
end

-- Create the UI
local function CreateUI()
if UIActive then return end
UIActive = true

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BloxFruitsScript"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

GUI.ScreenGui = ScreenGui

-- Main Frame
local MainFrame = CreateRoundedFrame(
    UDim2.new(0, 450, 0, 350),
    UDim2.new(0.5, 0, 0.5, 0),
    Color3.fromRGB(30, 30, 30),
    ScreenGui,
    Vector2.new(0.5, 0.5)
)

GUI.MainFrame = MainFrame

-- Title Bar
local TitleBar = CreateRoundedFrame(
    UDim2.new(1, 0, 0, 30),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(20, 20, 20),
    MainFrame
)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -60, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Enhanced Blox Fruits Script - by Nie Liebert"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 25, 0, 25)
CloseButton.Position = UDim2.new(1, -27, 0, 2)
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 14
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.Parent = TitleBar

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 4)
UICorner.Parent = CloseButton

-- Tabs
local TabsFrame = CreateRoundedFrame(
    UDim2.new(0.25, 0, 1, -40),
    UDim2.new(0, 5, 0, 35),
    Color3.fromRGB(25, 25, 25),
    MainFrame
)

local TabsContainer = Instance.new("ScrollingFrame")
TabsContainer.Size = UDim2.new(1, -10, 1, -10)
TabsContainer.Position = UDim2.new(0, 5, 0, 5)
TabsContainer.BackgroundTransparency = 1
TabsContainer.ScrollBarThickness = 4
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 200)
TabsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabsContainer.Parent = TabsFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.Parent = TabsContainer

-- Content Frame
local ContentFrame = CreateRoundedFrame(
    UDim2.new(0.7, 0, 1, -40),
    UDim2.new(0.275, 10, 0, 35),
    Color3.fromRGB(25, 25, 25),
    MainFrame
)

-- Status Bar
local StatusBar = CreateRoundedFrame(
    UDim2.new(1, -10, 0, 25),
    UDim2.new(0, 5, 1, -30),
    Color3.fromRGB(20, 20, 20),
    MainFrame
)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -10, 1, 0)
StatusLabel.Position = UDim2.new(0, 5, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Idle | Mobs Killed: 0 | Level Gained: 0"
StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusBar

GUI.StatusLabel = StatusLabel

-- Draggable functionality
local IsDragging = false
local DragStart = nil
local StartPos = nil

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    IsDragging = true
    DragStart = input.Position
    StartPos = MainFrame.Position
    end
    end)

UserInputService.InputChanged:Connect(function(input)
    if IsDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    local Delta = input.Position - DragStart
    MainFrame.Position = UDim2.new(
        StartPos.X.Scale,
        StartPos.X.Offset + Delta.X,
        StartPos.Y.Scale,
        StartPos.Y.Offset + Delta.Y
    )
    end
    end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    IsDragging = false
    end
    end)

-- Close button functionality
CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    UIActive = false

    if AutoFarmConnection then
    AutoFarmConnection:Disconnect()
    AutoFarmConnection = nil
    end
    end)

-- Create tabs
local Tabs = {}
local TabContent = {}

local function CreateTab(Name)
local TabButton = Instance.new("TextButton")
TabButton.Size = UDim2.new(1, 0, 0, 30)
TabButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TabButton.BorderSizePixel = 0
TabButton.Text = Name
TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TabButton.TextSize = 14
TabButton.Font = Enum.Font.SourceSansBold
TabButton.Parent = TabsContainer

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = TabButton

local ContentContainer = Instance.new("ScrollingFrame")
ContentContainer.Size = UDim2.new(1, -10, 1, -10)
ContentContainer.Position = UDim2.new(0, 5, 0, 5)
ContentContainer.BackgroundTransparency = 1
ContentContainer.ScrollBarThickness = 4
ContentContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentContainer.Visible = false
ContentContainer.Parent = ContentFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.Parent = ContentContainer

TabButton.MouseButton1Click:Connect(function()
    for _, Tab in pairs(Tabs) do
    Tab.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    end

    TabButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)

    for _, Content in pairs(TabContent) do
    Content.Visible = false
    end

    ContentContainer.Visible = true
    end)

table.insert(Tabs, TabButton)
table.insert(TabContent, ContentContainer)

return ContentContainer
end

-- Create tabs
local FarmTab = CreateTab("Farming")
local WeaponTab = CreateTab("Weapons")
local TeleportTab = CreateTab("Teleport")
local SettingsTab = CreateTab("Settings")
local StatsTab = CreateTab("Stats")

-- Set first tab as active
Tabs[1].BackgroundColor3 = Color3.fromRGB(0, 170, 255)
TabContent[1].Visible = true

-- Fill tabs with content

-- Farming Tab
local AutoFarmToggle, GetAutoFarmState, SetAutoFarmState = CreateToggle("Auto Farm", Config.AutoFarm, FarmTab, function(Value)
    Config.AutoFarm = Value

    if Value then
    StartAutoFarm()
    else
        if AutoFarmConnection then
    AutoFarmConnection:Disconnect()
    AutoFarmConnection = nil
    end
    end
    end)

local QuestDropdown, GetQuest = CreateDropdown("Select Quest", {
    "BanditQuest1", "BuggyQuest1", "MarineQuest1"
}, Config.Quest, FarmTab, function(Value)
    if Value then
    Config.Quest = Value

-- Set default target mob based on quest
    if Value == "BanditQuest1" then
    Config.TargetMob = "Bandit"
    elseif Value == "BuggyQuest1" then
    Config.TargetMob = "Buggy Pirate"
    elseif Value == "MarineQuest1" then
    Config.TargetMob = "Marine"
    end
    end
    end)

local MobDropdown, GetTargetMob = CreateDropdown("Target Mob", {
    "Bandit", "Buggy Pirate", "Marine", "Monkey", "Gorilla"
}, Config.TargetMob, FarmTab, function(Value)
    if Value then
    Config.TargetMob = Value
    end
    end)

local FastAttackToggle, GetFastAttackState = CreateToggle("Fast Attack", Config.FastAttack, FarmTab, function(Value)
    Config.FastAttack = Value
    end)

local BringMobToggle, GetBringMobState = CreateToggle("Bring Mob", Config.BringMob, FarmTab, function(Value)
    Config.BringMob = Value
    end)

local AutoSkillToggle, GetAutoSkillState = CreateToggle("Auto Skill", Config.AutoSkill, FarmTab, function(Value)
    Config.AutoSkill = Value
    end)

local KillAuraToggle, GetKillAuraState = CreateToggle("Kill Aura", Config.KillAura, FarmTab, function(Value)
    Config.KillAura = Value
    end)

local ChestFarmToggle, GetChestFarmState = CreateToggle("Chest Farm", Config.ChestFarm, FarmTab, function(Value)
    Config.ChestFarm = Value
    end)

local FruitFarmToggle, GetFruitFarmState = CreateToggle("Collect Fruit", Config.CollectFruit, FarmTab, function(Value)
    Config.CollectFruit = Value
    end)

local DistanceSlider, GetDistance = CreateSlider("Attack Distance", 5, 30, Config.Distance, FarmTab, function(Value)
    Config.Distance = Value
    end)

-- Weapons Tab
local WeaponDropdown, GetWeapon = CreateDropdown("Select Weapon Type", {
    "Melee", "Sword", "Gun", "Fruit"
}, Config.Weapon, WeaponTab, function(Value)
    Config.Weapon = Value
    end)

local AutoEquipWeaponToggle, GetAutoEquipWeaponState = CreateToggle("Auto Equip Weapon", Config.AutoEquipWeapon, WeaponTab, function(Value)
    Config.AutoEquipWeapon = Value
    end)

local SkillZ, GetSkillZ = CreateToggle("Use Skill Z", Config.SelectedSkills.Z, WeaponTab, function(Value)
    Config.SelectedSkills.Z = Value
    end)

local SkillX, GetSkillX = CreateToggle("Use Skill X", Config.SelectedSkills.X, WeaponTab, function(Value)
    Config.SelectedSkills.X = Value
    end)

local SkillC, GetSkillC = CreateToggle("Use Skill C", Config.SelectedSkills.C, WeaponTab, function(Value)
    Config.SelectedSkills.C = Value
    end)

local SkillV, GetSkillV = CreateToggle("Use Skill V", Config.SelectedSkills.V, WeaponTab, function(Value)
    Config.SelectedSkills.V = Value
    end)

-- Teleport Tab
local ServerHopToggle, GetServerHopState = CreateToggle("Server Hop If Empty", Config.HopIfServerEmpty, TeleportTab, function(Value)
    Config.HopIfServerEmpty = Value
    end)

-- Settings Tab
local SafetyHealthSlider, GetSafetyHealth = CreateSlider("Safety Health %", 10, 90, Config.SafetyHealth, SettingsTab, function(Value)
    Config.SafetyHealth = Value
    end)

local AutoRejoinToggle, GetAutoRejoinState = CreateToggle("Auto Rejoin", Config.AutoRejoin, SettingsTab, function(Value)
    Config.AutoRejoin = Value
    end)

local TweenSpeedSlider, GetTweenSpeed = CreateSlider("Tween Speed", 50, 300, Config.TweenSpeed, SettingsTab, function(Value)
    Config.TweenSpeed = Value
    end)

-- Stats Tab
local StatsContainer = Instance.new("Frame")
StatsContainer.Size = UDim2.new(1, -20, 0, 200)
StatsContainer.Position = UDim2.new(0, 10, 0, 10)
StatsContainer.BackgroundTransparency = 1
StatsContainer.Parent = StatsTab

local StatsLabels = {}

local function CreateStatsLabel(Text, YPos)
local Label = Instance.new("TextLabel")
Label.Size = UDim2.new(1, 0, 0, 25)
Label.Position = UDim2.new(0, 0, 0, YPos)
Label.BackgroundTransparency = 1
Label.Text = Text
Label.TextColor3 = Color3.fromRGB(255, 255, 255)
Label.TextSize = 14
Label.Font = Enum.Font.SourceSans
Label.TextXAlignment = Enum.TextXAlignment.Left
Label.Parent = StatsContainer

table.insert(StatsLabels, Label)
return Label
end

local SessionTimeLabel = CreateStatsLabel("Session Time: 00:00:00", 0)
local MobsKilledLabel = CreateStatsLabel("Mobs Killed: 0", 30)
local LevelGainedLabel = CreateStatsLabel("Levels Gained: 0", 60)
local BelliEarnedLabel = CreateStatsLabel("Belli Earned: 0", 90)
local ChestsCollectedLabel = CreateStatsLabel("Chests Collected: 0", 120)
local FruitsCollectedLabel = CreateStatsLabel("Fruits Collected: 0", 150)

-- Update stats display
spawn(function()
    while wait(1) do
    if not UIActive then break end

-- Update session time
    local TimeDiff = os.time() - SessionStats.StartTime
    local Hours = math.floor(TimeDiff / 3600)
    local Minutes = math.floor((TimeDiff % 3600) / 60)
    local Seconds = TimeDiff % 60

    SessionTimeLabel.Text = string.format("Session Time: %02d:%02d:%02d", Hours, Minutes, Seconds)
    MobsKilledLabel.Text = "Mobs Killed: " .. SessionStats.MobsKilled
    LevelGainedLabel.Text = "Levels Gained: " .. SessionStats.LevelGained
    BelliEarnedLabel.Text = "Belli Earned: " .. SessionStats.BelliEarned
    ChestsCollectedLabel.Text = "Chests Collected: " .. SessionStats.ChestsCollected
    FruitsCollectedLabel.Text = "Fruits Collected: " .. SessionStats.FruitsCollected

-- Update status bar
    local StatusText = ""
    if Config.AutoFarm then
    StatusText = "Status: Farming | Mobs: " .. SessionStats.MobsKilled .. " | Level Gained: " .. SessionStats.LevelGained
    else
        StatusText = "Status: Idle | Mobs: " .. SessionStats.MobsKilled .. " | Level Gained: " .. SessionStats.LevelGained
    end

    StatusLabel.Text = StatusText
    end
    end)

-- Keybind to toggle UI
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightControl then
    MainFrame.Visible = not MainFrame.Visible
    end
    end)

return GUI
end

-- Create GUI on script startup
CreateUI()

-- Start script
StartScript()

-- Return functions
return {
    StartAutoFarm = StartAutoFarm,
    StopAutoFarm = function()
    Config.AutoFarm = false
    if AutoFarmConnection then
    AutoFarmConnection:Disconnect()
    AutoFarmConnection = nil
    end
    end,
    ToggleUI = function()
    if not GUI.MainFrame then
    CreateUI()
    else
        GUI.MainFrame.Visible = not GUI.MainFrame.Visible
    end
    end,
    Config = Config
}