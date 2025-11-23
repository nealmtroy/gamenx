-- Gamen X | Core Logic v1.9.1 (UI Structure Fix)
-- Update: Memperbaiki struktur AddTab dan AddSection
-- Update: Menghapus SaveManager/InterfaceManager sementara (Raw UI Only)
-- Update: Memastikan Tab terpilih secara otomatis

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v1.9.1...")

-- 1. LOAD VARIABLES
local success, Data = pcall(function()
    return loadstring(game:HttpGet(Variables_URL))()
end)

if not success or type(Data) ~= "table" then
    Data = { Config = {}, ShopData = {Rods={}, Baits={}}, LocationCoords = {} }
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

-- Membuat Window
local Window = Fluent:CreateWindow({
    Title = "Gamen X | Core v1.9.1",
    SubTitle = "UI Fix",
    TabWidth = 120,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- ====== LOCAL STATE ======
local Config = Data.Config or {}
-- Default Config (Safety)
Config.AutoFish = false
Config.AutoEquip = false
Config.AutoSell = false
Config.FishDelay = 2.0
Config.SellDelay = 10

local ShopData = Data.ShopData or {Rods={}, Baits={}}
local LocationCoords = Data.LocationCoords or {}
local NetworkLoaded = false
local Events = {}
local InputControlModule = nil
local SelectedRod = nil

-- ====== NETWORK LOADER ======
task.spawn(function()
    task.wait(1)
    local success, err = pcall(function()
        local Packages = ReplicatedStorage:WaitForChild("Packages", 5)
        if not Packages then return end
        local Index = Packages:WaitForChild("_Index", 5)
        if not Index then return end
        
        local NetPackage = nil
        for _, child in pairs(Index:GetChildren()) do
            if child.Name:find("sleitnick_net") then NetPackage = child break end
        end
        if not NetPackage then NetPackage = Index:FindFirstChild("sleitnick_net@0.2.0") end
        if not NetPackage then return end

        local NetFolder = NetPackage:WaitForChild("net", 5)
        pcall(function() InputControlModule = ReplicatedStorage:WaitForChild("Modules", 2):WaitForChild("InputControl", 2) end)

        Events.fishing = NetFolder:WaitForChild("RE/FishingCompleted", 2)
        Events.charge = NetFolder:WaitForChild("RF/ChargeFishingRod", 2)
        Events.minigame = NetFolder:WaitForChild("RF/RequestFishingMinigameStarted", 2)
        Events.equip = NetFolder:WaitForChild("RE/EquipToolFromHotbar", 2)
        Events.sell = NetFolder:WaitForChild("RF/SellAllItems", 2)
        Events.buyRod = NetFolder:WaitForChild("RF/PurchaseFishingRod", 2)
        
        NetworkLoaded = true
        Fluent:Notify({Title = "Gamen X", Content = "Connected!", Duration = 3})
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

-- ====== TABS DEFINITION (STRUKTUR BARU) ======
-- Kita buat Tabs satu per satu untuk memastikan tidak ada syntax error dalam table

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Settings = Window:AddTab({ Title = "Shop", Icon = "shopping-cart" }),
}

-- === TAB: MAIN CONTENT ===
-- Gunakan pcall di setiap elemen UI agar jika satu error, yang lain tetap muncul

pcall(function()
    Tabs.Main:AddParagraph({
        Title = "Gamen X Status",
        Content = "Script Active. Select features below."
    })
end)

pcall(function()
    Tabs.Main:AddToggle("AutoFish", {
        Title = "Auto Fish",
        Description = "Spam Cast & Reel (Barbar)",
        Default = false,
        Callback = function(state) Config.AutoFish = state end
    })
end)

pcall(function()
    Tabs.Main:AddToggle("AutoEquip", {
        Title = "Auto Equip",
        Default = false,
        Callback = function(state) Config.AutoEquip = state end
    })
end)

pcall(function()
    Tabs.Main:AddToggle("AutoSell", {
        Title = "Auto Sell",
        Default = false,
        Callback = function(state) Config.AutoSell = state end
    })
end)

pcall(function()
    Tabs.Main:AddInput("FishDelay", {
        Title = "Fish Delay (Bite Time)",
        Default = "2.0",
        Numeric = true,
        Finished = true,
        Callback = function(value) Config.FishDelay = tonumber(value) or 2.0 end
    })
end)

-- === TAB: SETTINGS / SHOP CONTENT ===
local RodList = {}
for k, _ in pairs(ShopData.Rods) do table.insert(RodList, k) end
if #RodList == 0 then table.insert(RodList, "No Data") end

pcall(function()
    Tabs.Settings:AddDropdown("RodSelect", {
        Title = "Select Rod",
        Values = RodList,
        Multi = false,
        Default = nil,
        Callback = function(v) SelectedRod = ShopData.Rods[v] end
    })
end)

pcall(function()
    Tabs.Settings:AddButton({
        Title = "Buy Rod",
        Callback = function() 
            if SelectedRod and NetworkLoaded then Events.buyRod:InvokeServer(SelectedRod) end 
        end
    })
end)

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

-- Select Tab Terakhir (Delay sedikit agar UI render dulu)
task.delay(1, function()
    Window:SelectTab(1)
end)
