-- Gamen X | Core Logic v1.9.0 (UI Rebuild)
-- Update: Safe UI Mode (Tanpa SaveManager sementara untuk cegah blank)
-- Update: Perbaikan Struktur Tab Fluent Renewed

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v1.9.0...")

-- 1. LOAD VARIABLES
local success, Data = pcall(function()
    return loadstring(game:HttpGet(Variables_URL))()
end)

if not success or type(Data) ~= "table" then
    Data = { Config = {}, ShopData = {Rods={}, Baits={}}, LocationCoords = {} }
    warn("[Gamen X] Failed to load variables. Using empty defaults.")
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

if not successLib or not Fluent then 
    warn("[Gamen X] UI Failed!")
    return 
end

local Window = Fluent:CreateWindow({
    Title = "Gamen X | Core v1.9.0",
    SubTitle = "UI Rebuild",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- ====== LOCAL STATE ======
local Config = Data.Config or {}
-- Set Default Config Value jika nil
Config.AutoFish = false
Config.AutoEquip = false
Config.AutoSell = false
Config.FishDelay = 2.0
Config.CatchDelay = 0.5
Config.SellDelay = 10
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
            Events.fishCaught.OnClientEvent:Connect(function(...) 
                -- HandleFishCaught logika disini
            end)
        end

        NetworkLoaded = true
        Fluent:Notify({Title = "Gamen X", Content = "Game Connected!", Duration = 3})
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

-- ====== TABS UI ======
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- === TAB: MAIN ===
Tabs.Main:AddParagraph({
    Title = "Gamen X",
    Content = "Status: " .. (NetworkLoaded and "Connected" or "Connecting...")
})

Tabs.Main:AddToggle("AutoFish", {
    Title = "Auto Fish",
    Description = "Spam Cast & Reel",
    Default = false,
    Callback = function(state) Config.AutoFish = state end
})

Tabs.Main:AddToggle("AutoEquip", {
    Title = "Auto Equip",
    Default = false,
    Callback = function(state) Config.AutoEquip = state end
})

Tabs.Main:AddToggle("AutoSell", {
    Title = "Auto Sell",
    Default = false,
    Callback = function(state) Config.AutoSell = state end
})

Tabs.Main:AddInput("FishDelay", {
    Title = "Fish Delay (Bite)",
    Default = tostring(Config.FishDelay),
    Numeric = true,
    Finished = true,
    Callback = function(value) Config.FishDelay = tonumber(value) or 2.0 end
})

Tabs.Main:AddInput("SellDelay", {
    Title = "Sell Delay",
    Default = tostring(Config.SellDelay),
    Numeric = true,
    Finished = true,
    Callback = function(value) Config.SellDelay = tonumber(value) or 10 end
})

-- === TAB: SETTINGS (Merchant & Teleport Simplified) ===
local RodList = {}
for k, _ in pairs(ShopData.Rods) do table.insert(RodList, k) end
if #RodList == 0 then table.insert(RodList, "None") end

Tabs.Settings:AddDropdown("RodSelect", {
    Title = "Select Rod to Buy",
    Values = RodList,
    Multi = false,
    Default = nil,
    Callback = function(v) SelectedRod = ShopData.Rods[v] end
})

Tabs.Settings:AddButton({
    Title = "Buy Selected Rod",
    Callback = function() 
        if SelectedRod and NetworkLoaded then Events.buyRod:InvokeServer(SelectedRod) end 
    end
})

-- ====== LOOPS ======
task.spawn(function()
    while true do
        if Config.AutoFish and NetworkLoaded then
            CastRod()
            task.wait(Config.FishDelay)
            ReelIn()
        else
            task.wait(0.5)
        end
        task.wait(0.1)
    end
end)

task.spawn(function() 
    while true do 
        if Config.AutoEquip and NetworkLoaded then pcall(function() Events.equip:FireServer(1) end) end
        task.wait(2.5) 
    end 
end)

task.spawn(function() 
    while true do 
        if Config.AutoSell and NetworkLoaded then pcall(function() Events.sell:InvokeServer() end) end
        task.wait(Config.SellDelay) 
    end 
end)

Window:SelectTab(1)
