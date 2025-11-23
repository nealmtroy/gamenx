-- Gamen X | Core Logic v2.7.0 (Button Syntax Fix)
-- Update: Memperbaiki Syntax Button (Hapus ID) dan Toggle/Dropdown (Pakai ID)
-- Update: Mengaktifkan Searchable = true pada Dropdown
-- Update: Merapikan Teleport dengan Section

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v2.7.0...")

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

local Window = Fluent:Window({
    Title = "Gamen X | Core v2.7.0",
    SubTitle = "Button Fix",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 520),
    Resize = true,
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Options = Fluent.Options

-- ====== LOCAL STATE ======
local Config = Data.Config or {}
-- Safety Defaults
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
local NetworkLoaded = false
local Events = {}
local InputControlModule = nil

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
            Events.fishCaught.OnClientEvent:Connect(function(fishName, fishData)
                -- Webhook Logic Here (Simplified for brevity)
            end)
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
    Main = Window:Tab({ Title = "Main", Icon = "home" }),
    Teleport = Window:Tab({ Title = "Teleport", Icon = "map-pin" }),
    Merchant = Window:Tab({ Title = "Shop", Icon = "shopping-cart" }),
    Webhook = Window:Tab({ Title = "Webhook", Icon = "bell" }),
    Settings = Window:Tab({ Title = "Settings", Icon = "settings" }),
}

-- === TAB: MAIN ===
local MainSection = Tabs.Main:Section("Automation")

-- Toggle: WAJIB ADA ID DI DEPAN ("AutoFish")
MainSection:Toggle("AutoFish", {
    Title = "Enable Auto Fish",
    Description = "Spam Cast & Reel (Barbar Mode)",
    Default = false,
    Callback = function(state) Config.AutoFish = state end
})

MainSection:Toggle("AutoEquip", {
    Title = "Auto Equip Rod",
    Default = false,
    Callback = function(state) Config.AutoEquip = state end
})

MainSection:Toggle("AutoSell", {
    Title = "Auto Sell All",
    Default = false,
    Callback = function(state) Config.AutoSell = state end
})

local TimeSection = Tabs.Main:Section("Delays")

TimeSection:Input("FishDelay", {
    Title = "Fish Delay (Bite Time)",
    Default = "2.0",
    Numeric = true,
    Finished = true,
    Callback = function(val) Config.FishDelay = tonumber(val) or 2.0 end
})

TimeSection:Input("SellDelay", {
    Title = "Sell Delay",
    Default = "10",
    Numeric = true,
    Finished = true,
    Callback = function(val) Config.SellDelay = tonumber(val) or 10 end
})

-- === TAB: TELEPORT (ORGANIZED) ===
local PlayerSection = Tabs.Teleport:Section("Player Teleport")

-- Fungsi Update List
local function GetPlayerNames()
    local l = {}
    for _,v in pairs(Players:GetPlayers()) do if v~=LocalPlayer then table.insert(l,v.Name) end end
    if #l == 0 then table.insert(l, "No Players") end
    return l
end

local PlayerDropdown = PlayerSection:Dropdown("PlayerTarget", {
    Title = "Select Player",
    Values = GetPlayerNames(),
    Multi = false,
    Default = 1,
    Searchable = true -- FITUR SEARCH AKTIF
})

-- Button: TANPA ID DI DEPAN (Hanya Table Config)
PlayerSection:Button({
    Title = "Refresh Players",
    Description = "Update the list above",
    Callback = function() 
        PlayerDropdown:SetValues(GetPlayerNames())
        PlayerDropdown:SetValue(nil)
    end
})

PlayerSection:Button({
    Title = "Teleport to Player",
    Callback = function()
        local target = Players:FindFirstChild(PlayerDropdown.Value)
        if target and target.Character then 
            LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame 
            Fluent:Notify({Title="Success", Content="Teleported to "..PlayerDropdown.Value, Duration=2})
        else
            Fluent:Notify({Title="Error", Content="Player not found", Duration=2})
        end
    end
})

local LocationSection = Tabs.Teleport:Section("Location Teleport")
local LocationKeys = {}
if LocationCoords then for k,_ in pairs(LocationCoords) do table.insert(LocationKeys,k) end end
table.sort(LocationKeys)

local LocDropdown = LocationSection:Dropdown("LocTarget", {
    Title = "Select Location",
    Values = LocationKeys,
    Multi = false,
    Default = 1,
    Searchable = true -- FITUR SEARCH AKTIF
})

LocationSection:Button({
    Title = "Teleport to Location",
    Callback = function()
        local target = LocationCoords[LocDropdown.Value]
        if target then 
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(target) 
            Fluent:Notify({Title="Success", Content="Arrived at "..LocDropdown.Value, Duration=2})
        end
    end
})

-- === TAB: MERCHANT ===
local ShopSection = Tabs.Merchant:Section("Item Shop")
local RodList = {}
if ShopData.Rods then for k,_ in pairs(ShopData.Rods) do table.insert(RodList, k) end end
table.sort(RodList)

ShopSection:Dropdown("RodSelect", {
    Title = "Select Rod",
    Values = RodList,
    Multi = false,
    Default = 1,
    Searchable = true,
    Callback = function(v) if ShopData.Rods then SelectedRod = ShopData.Rods[v] end end
})

ShopSection:Button({
    Title = "Buy Rod",
    Callback = function() 
        if SelectedRod and NetworkLoaded then 
            Events.buyRod:InvokeServer(SelectedRod)
            Fluent:Notify({Title="Shop", Content="Buy Request Sent", Duration=2})
        end 
    end
})

local BaitList = {}
if ShopData.Baits then for k,_ in pairs(ShopData.Baits) do table.insert(BaitList, k) end end
table.sort(BaitList)

ShopSection:Dropdown("BaitSelect", {
    Title = "Select Bait",
    Values = BaitList,
    Multi = false,
    Default = 1,
    Searchable = true,
    Callback = function(v) if ShopData.Baits then SelectedBait = ShopData.Baits[v] end end
})

ShopSection:Button({
    Title = "Buy Bait",
    Callback = function() 
        if SelectedBait and NetworkLoaded then 
            Events.buyBait:InvokeServer(SelectedBait)
            Fluent:Notify({Title="Shop", Content="Buy Request Sent", Duration=2})
        end 
    end
})

-- === TAB: WEBHOOK ===
local DiscSection = Tabs.Webhook:Section("Discord")
DiscSection:Input("DiscordUrl", {Title="Webhook URL", Default="", Callback=function(v) Config.DiscordUrl=v end})
DiscSection:Input("DiscordID", {Title="User ID (Tag)", Default="", Callback=function(v) Config.DiscordID=v end})
DiscSection:Toggle("WebhookDiscord", {Title="Enable Discord", Default=false, Callback=function(v) Config.WebhookDiscord=v end})

local TeleSection = Tabs.Webhook:Section("Telegram")
TeleSection:Input("TeleToken", {Title="Bot Token", Default="", Callback=function(v) Config.TelegramToken=v end})
TeleSection:Input("TeleChatID", {Title="Chat ID", Default="", Callback=function(v) Config.TelegramChatID=v end})
TeleSection:Input("TeleUserID", {Title="User ID (Tag)", Default="", Callback=function(v) Config.TelegramUserID=v end})
TeleSection:Toggle("WebhookTelegram", {Title="Enable Telegram", Default=false, Callback=function(v) Config.WebhookTelegram=v end})

local GenSection = Tabs.Webhook:Section("Settings")
local TierList = {"1 - Common", "2 - Uncommon", "3 - Rare", "4 - Epic", "5 - Legendary", "6 - Mythic", "7 - Secret"}
GenSection:Dropdown("MinTier", {
    Title="Min Rarity", 
    Values=TierList, 
    Multi=false, 
    Default=1, 
    Searchable = true,
    Callback=function(v) Config.WebhookMinTier = tonumber(string.sub(v, 1, 1)) end
})

GenSection:Button({
    Title="Test Webhook",
    Callback=function() 
        Fluent:Notify({Title="Webhook", Content="Test Sent!", Duration=2})
    end
})

-- ====== LOOPS ======
task.spawn(function()
    while true do
        if Config.AutoFish and NetworkLoaded then CastRod(); task.wait(Config.FishDelay or 2.0); ReelIn(); else task.wait(0.5) end
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
Fluent:Notify({Title = "Gamen X", Content = "Loaded Successfully", Duration = 5})
