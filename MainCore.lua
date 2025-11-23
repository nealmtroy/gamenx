-- Gamen X | Core Logic v2.4.0 (Final UI Fix)
-- Update: Menambahkan 'Section' (Wajib agar UI tidak blank)
-- Update: Mengaktifkan fitur SEARCH di Dropdown (Searchable = true)
-- Update: Logika Teleport dinamis (Player/Location)

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v2.4.0...")

-- 1. LOAD VARIABLES
local success, Data = pcall(function()
    return loadstring(game:HttpGet(Variables_URL))()
end)

if not success or type(Data) ~= "table" then
    Data = { Config = {}, ShopData = {Rods={}, Baits={}}, LocationCoords = {} }
    warn("[Gamen X] Variables failed. Using defaults.")
end

-- ====== SERVICES ======
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ====== UI LIBRARY ======
local successLib, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
end)

if not successLib or not Fluent then return end

local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Fluent:CreateWindow({
    Title = "Gamen X | Core v2.4.0",
    SubTitle = "Search & UI Fix",
    TabWidth = 120,
    Size = UDim2.fromOffset(580, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Options = Fluent.Options

-- ====== LOCAL STATE ======
local Config = Data.Config or {}
-- Default Safety
Config.AutoFish = false
Config.AutoEquip = false
Config.AutoSell = false
Config.FishDelay = 2.0
Config.SellDelay = 10.0
Config.WebhookFish = false
Config.WebhookMinTier = 1

local ShopData = Data.ShopData or {Rods={}, Baits={}}
local LocationCoords = Data.LocationCoords or {}
local FishTierMap = Data.FishTierMap or {}
local TierColors = Data.TierColors or {}

local SelectedRod, SelectedBait = nil, nil
local currentMode, selectedTarget = "None", nil
local NetworkLoaded = false
local Events = {}
local InputControlModule = nil

-- ====== HELPER FUNCTIONS ======
local function GetTierName(tier)
    local names = {[1]="Common",[2]="Uncommon",[3]="Rare",[4]="Epic",[5]="Legendary",[6]="Mythic",[7]="Secret"}
    return names[tier] or "Unknown"
end

local function SendWebhook(url, payload)
    local req = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
    if req then 
        req({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(payload)}) 
    end
end

local function HandleFishCaught(fishName, fishData)
    if not Config.WebhookFish then return end
    local fishNameStr = tostring(fishName)
    local tier = FishTierMap[fishNameStr] or 1
    if tier < Config.WebhookMinTier then return end
    
    local weight = (fishData and fishData.Weight) and tostring(fishData.Weight) or "?"
    local tierName = GetTierName(tier)
    local tierColor = TierColors[tier] or 16777215
    
    if Config.DiscordUrl and Config.DiscordUrl ~= "" then
        SendWebhook(Config.DiscordUrl, {
            ["content"] = "",
            ["embeds"] = {{
                ["title"] = "🎣 Fish Caught!",
                ["description"] = string.format("**%s**\nWeight: **%s** kg\nRarity: **%s**", fishNameStr, weight, tierName),
                ["color"] = tierColor,
                ["footer"] = { ["text"] = "Gamen X | " .. os.date("%X") }
            }}
        })
    end
    
    if Config.TelegramToken and Config.TelegramToken ~= "" then
        SendWebhook("https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage", {
            ["chat_id"] = Config.TelegramChatID,
            ["text"] = string.format("🎣 *Gamen X Notification*\n\nFish: *%s*\nRarity: *%s*\nWeight: `%s kg`", fishNameStr, tierName, weight),
            ["parse_mode"] = "Markdown"
        })
    end
end

-- ====== NETWORK LOADER ======
task.spawn(function()
    task.wait(1)
    local success, err = pcall(function()
        local Packages = ReplicatedStorage:WaitForChild("Packages", 5)
        if not Packages then return end
        local Index = Packages:WaitForChild("_Index", 5)
        if not Index then return end
        
        local NetPackage = Index:FindFirstChild("sleitnick_net@0.2.0")
        if not NetPackage then
            for _, child in pairs(Index:GetChildren()) do
                if child.Name:find("sleitnick_net") then NetPackage = child break end
            end
        end
        if not NetPackage then return end

        local NetFolder = NetPackage:WaitForChild("net", 5)
        pcall(function() InputControlModule = ReplicatedStorage:WaitForChild("Modules", 2):WaitForChild("InputControl", 2) end)

        Events.fishing = NetFolder:WaitForChild("RE/FishingCompleted", 2)
        Events.charge = NetFolder:WaitForChild("RF/ChargeFishingRod", 2)
        Events.minigame = NetFolder:WaitForChild("RF/RequestFishingMinigameStarted", 2)
        Events.equip = NetFolder:WaitForChild("RE/EquipToolFromHotbar", 2)
        Events.unequip = NetFolder:WaitForChild("RE/UnequipToolFromHotbar", 2)
        Events.sell = NetFolder:WaitForChild("RF/SellAllItems", 2)
        Events.buyRod = NetFolder:WaitForChild("RF/PurchaseFishingRod", 2)
        Events.buyBait = NetFolder:WaitForChild("RF/PurchaseBait", 2)
        
        Events.fishCaught = NetFolder:WaitForChild("RE/FishCaught", 2)
        if Events.fishCaught then
            Events.fishCaught.OnClientEvent:Connect(HandleFishCaught)
        end

        NetworkLoaded = true
        Fluent:Notify({Title = "Gamen X", Content = "System Connected!", Duration = 3})
    end)
end)

-- ====== LOGIC ======
local function CastRod()
    if not NetworkLoaded or not Events.equip then return end
    pcall(function()
        Events.equip:FireServer(1)
        task.wait(0.05)
        if InputControlModule then Events.charge:InvokeServer(InputControlModule) else Events.charge:InvokeServer(1755848498.4834) end
        task.wait(0.02)
        Events.minigame:InvokeServer(1.2854545116425, 1)
    end)
end

local function ReelIn()
    if not NetworkLoaded or not Events.fishing then return end
    pcall(function() Events.fishing:FireServer() end)
end

-- ====== TABS ======
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Merchant = Window:AddTab({ Title = "Shop", Icon = "shopping-cart" }),
    Webhook = Window:AddTab({ Title = "Webhook", Icon = "bell" }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

-- === TAB: MAIN ===
-- PENTING: Gunakan AddSection sebelum menambahkan elemen lain!
local MainSection = Tabs.Main:AddSection("Automation Features")

MainSection:AddToggle("AutoFish", {
    Title = "Enable Auto Fish",
    Description = "Spam Cast & Reel (Barbar Mode)",
    Default = false,
    Callback = function(state) Config.AutoFish = state end
})

MainSection:AddToggle("AutoEquip", {
    Title = "Auto Equip Rod",
    Default = false,
    Callback = function(state) Config.AutoEquip = state end
})

MainSection:AddToggle("AutoSell", {
    Title = "Auto Sell All",
    Default = false,
    Callback = function(state) Config.AutoSell = state end
})

local TimingSection = Tabs.Main:AddSection("Delays (Seconds)")

TimingSection:AddInput("FishDelay", {
    Title = "Fish Delay (Bite Time)",
    Description = "Time before reeling in",
    Default = "2.0",
    Numeric = true,
    Finished = true,
    Callback = function(val) Config.FishDelay = tonumber(val) or 2.0 end
})

TimingSection:AddInput("CatchDelay", {
    Title = "Catch Delay (Cooldown)",
    Default = "0.5",
    Numeric = true,
    Finished = true,
    Callback = function(val) Config.CatchDelay = tonumber(val) or 0.5 end
})

TimingSection:AddInput("SellDelay", {
    Title = "Sell Delay",
    Default = "10",
    Numeric = true,
    Finished = true,
    Callback = function(val) Config.SellDelay = tonumber(val) or 10 end
})

-- === TAB: MERCHANT ===
local ShopSection = Tabs.Merchant:AddSection("Item Shop")

local RodList = {}
if ShopData.Rods then for k,_ in pairs(ShopData.Rods) do table.insert(RodList, k) end end
table.sort(RodList)

ShopSection:AddDropdown("RodSelect", {
    Title = "Select Rod",
    Values = RodList,
    Multi = false,
    Default = 1,
    Searchable = true -- FITUR SEARCH DIAKTIFKAN
})
Options.RodSelect:OnChanged(function()
    if ShopData.Rods then SelectedRod = ShopData.Rods[Options.RodSelect.Value] end
end)

ShopSection:AddButton({
    Title = "Buy Selected Rod",
    Callback = function() if SelectedRod and NetworkLoaded then Events.buyRod:InvokeServer(SelectedRod) end end
})

local BaitList = {}
if ShopData.Baits then for k,_ in pairs(ShopData.Baits) do table.insert(BaitList, k) end end
table.sort(BaitList)

ShopSection:AddDropdown("BaitSelect", {
    Title = "Select Bait",
    Values = BaitList,
    Multi = false,
    Default = 1,
    Searchable = true -- FITUR SEARCH DIAKTIFKAN
})
Options.BaitSelect:OnChanged(function()
    if ShopData.Baits then SelectedBait = ShopData.Baits[Options.BaitSelect.Value] end
end)

ShopSection:AddButton({
    Title = "Buy Selected Bait",
    Callback = function() if SelectedBait and NetworkLoaded then Events.buyBait:InvokeServer(SelectedBait) end end
})

-- === TAB: WEBHOOK ===
local WebhookConfig = Tabs.Webhook:AddSection("Configuration")
WebhookConfig:AddInput("Discord", {Title="Discord URL", Default="", Callback=function(v) Config.DiscordUrl=v end})
WebhookConfig:AddInput("TeleToken", {Title="Tele Token", Default="", Callback=function(v) Config.TelegramToken=v end})
WebhookConfig:AddInput("TeleID", {Title="Tele Chat ID", Default="", Callback=function(v) Config.TelegramChatID=v end})

local WebhookSettings = Tabs.Webhook:AddSection("Settings")
WebhookSettings:AddToggle("WebhookFish", {Title="Notify Fish Caught", Default=false, Callback=function(v) Config.WebhookFish=v end})

local TierList = {"1 - Common", "2 - Uncommon", "3 - Rare", "4 - Epic", "5 - Legendary", "6 - Mythic", "7 - Secret"}
WebhookSettings:AddDropdown("MinTier", {
    Title="Min Rarity", 
    Values=TierList, 
    Multi=false, 
    Default=1, 
    Searchable = true
})
Options.MinTier:OnChanged(function()
    Config.WebhookMinTier = tonumber(string.sub(Options.MinTier.Value, 1, 1)) 
end)

WebhookSettings:AddButton({Title="Test Webhook", Callback=function() 
    if Config.DiscordUrl~="" then SendWebhook(Config.DiscordUrl, {content="Test", embeds={{title="Gamen X", description="Discord OK!", color=65280}}}) end
    if Config.TelegramToken~="" then SendWebhook("https://api.telegram.org/bot"..Config.TelegramToken.."/sendMessage", {chat_id=Config.TelegramChatID, text="Gamen X\nTelegram OK!"}) end
end})

-- === TAB: TELEPORT (ORGANIZED) ===
local TeleportSection = Tabs.Teleport:AddSection("Teleport Manager")

local LocationKeys = {}
if LocationCoords then for k,_ in pairs(LocationCoords) do table.insert(LocationKeys,k) end end
if #LocationKeys == 0 then table.insert(LocationKeys, "No Data") end
table.sort(LocationKeys)

-- Dropdown Mode
local ModeDrop = TeleportSection:AddDropdown("TeleportMode", {
    Title = "Teleport Mode",
    Values = {"Player", "Location"},
    Multi = false,
    Default = 1,
})

-- Dropdown Target (Dinamis)
local TargetDrop = TeleportSection:AddDropdown("TeleportTarget", {
    Title = "Select Target",
    Values = {"Select Mode First"},
    Multi = false,
    Default = 1,
    Searchable = true -- SEARCHABLE DIAKTIFKAN
})

-- Logic Update Dropdown saat Mode berubah
ModeDrop:OnChanged(function()
    currentMode = ModeDrop.Value
    TargetDrop:SetValue(nil)
    
    if currentMode == "Player" then
        local names = {}
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer then table.insert(names, v.Name) end
        end
        if #names == 0 then names = {"No Players Found"} end
        TargetDrop:SetValues(names)
    else
        TargetDrop:SetValues(LocationKeys)
    end
end)

TargetDrop:OnChanged(function()
    selectedTarget = TargetDrop.Value
end)

TeleportSection:AddButton({
    Title = "Teleport Now",
    Description = "Teleport to selected target",
    Callback = function()
        if currentMode == "Player" then
            local p = Players:FindFirstChild(selectedTarget)
            if p and p.Character then LocalPlayer.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame end
        elseif currentMode == "Location" and LocationCoords[selectedTarget] then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocationCoords[selectedTarget])
        else
            Fluent:Notify({Title="Error", Content="Invalid Target", Duration=2})
        end
    end
})

TeleportSection:AddButton({
    Title = "Refresh Players",
    Callback = function()
        if currentMode == "Player" then
            local names = {}
            for _, v in pairs(Players:GetPlayers()) do
                if v ~= LocalPlayer then table.insert(names, v.Name) end
            end
            TargetDrop:SetValues(names)
            Fluent:Notify({Title="Teleport", Content="List Refreshed", Duration=1})
        end
    end
})

-- ====== LOOPS ======
task.spawn(function()
    while true do
        if Config.AutoFish and NetworkLoaded then
            CastRod()
            task.wait(Config.FishDelay or 2.0)
            ReelIn()
        else
            task.wait(0.5)
        end
        task.wait(0.1)
    end
end)

task.spawn(function() while true do if Config.AutoEquip and NetworkLoaded then pcall(function() Events.equip:FireServer(1) end) end task.wait(2.5) end end)
task.spawn(function() while true do if Config.AutoSell and NetworkLoaded then pcall(function() Events.sell:InvokeServer() end) end task.wait(Config.SellDelay or 10) end end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("GamenX")
SaveManager:SetFolder("GamenX/configs")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
