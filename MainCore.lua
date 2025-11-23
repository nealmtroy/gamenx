-- Gamen X | Core Logic v2.1.0 (Syntax Final Fix)
-- Update: Mengganti semua 'Add...' menjadi 'Create...' (Wajib untuk Fluent Renewed)
-- Update: Menghapus penggunaan Section (Langsung ke Tab) agar anti-blank
-- Update: Perbaikan argumen tombol (Button pakai table { }, Toggle pakai ("ID", { }))

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v2.1.0...")

-- 1. LOAD VARIABLES
local success, Data = pcall(function()
    return loadstring(game:HttpGet(Variables_URL))()
end)

if not success or type(Data) ~= "table" then
    -- Fallback jika gagal load, supaya script TIDAK MATI
    Data = { Config = {}, ShopData = {Rods={}, Baits={}}, LocationCoords = {} }
    warn("[Gamen X] Variables fail. Using empty data.")
end

-- ====== SERVICES ======
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ====== UI LIBRARY (FLUENT RENEWED) ======
local successLib, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
end)

if not successLib or not Fluent then return end

local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Fluent:CreateWindow({
    Title = "Gamen X | Core v2.1.0",
    SubTitle = "Syntax Fix",
    TabWidth = 120,
    Size = UDim2.fromOffset(580, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Options = Fluent.Options

-- ====== LOCAL STATE ======
local Config = Data.Config or {}
-- Default Values (Anti Nil)
Config.AutoFish = false
Config.AutoEquip = false
Config.AutoSell = false
Config.FishDelay = 2.0
Config.SellDelay = 10.0

local ShopData = Data.ShopData or {Rods={}, Baits={}}
local LocationCoords = Data.LocationCoords or {}
local NetworkLoaded = false
local Events = {}
local InputControlModule = nil
local SelectedRod = nil

-- ====== TABS ======
-- Syntax Baru: Window:CreateTab
local Tabs = {
    Main = Window:CreateTab({ Title = "Main", Icon = "home" }),
    Settings = Window:CreateTab({ Title = "Shop", Icon = "shopping-cart" }),
}

-- === TAB: MAIN ===

-- Paragraph: CreateParagraph("ID", { ... })
Tabs.Main:CreateParagraph("StatusInfo", {
    Title = "Status",
    Content = "Script Active (Syntax v2.1.0)"
})

-- Toggle: CreateToggle("ID", { ... })
local AutoFishToggle = Tabs.Main:CreateToggle("AutoFish", {
    Title = "Auto Fish",
    Description = "Spam Cast & Reel",
    Default = false
})
AutoFishToggle:OnChanged(function() Config.AutoFish = Options.AutoFish.Value end)

local AutoEquipToggle = Tabs.Main:CreateToggle("AutoEquip", {
    Title = "Auto Equip",
    Default = false
})
AutoEquipToggle:OnChanged(function() Config.AutoEquip = Options.AutoEquip.Value end)

local AutoSellToggle = Tabs.Main:CreateToggle("AutoSell", {
    Title = "Auto Sell",
    Default = false
})
AutoSellToggle:OnChanged(function() Config.AutoSell = Options.AutoSell.Value end)

-- Input: CreateInput("ID", { ... })
local FishDelayInput = Tabs.Main:CreateInput("FishDelay", {
    Title = "Fish Delay",
    Default = "2.0",
    Numeric = true,
    Finished = true,
    Callback = function(val) Config.FishDelay = tonumber(val) or 2.0 end
})

local SellDelayInput = Tabs.Main:CreateInput("SellDelay", {
    Title = "Sell Delay",
    Default = "10",
    Numeric = true,
    Finished = true,
    Callback = function(val) Config.SellDelay = tonumber(val) or 10 end
})

-- === TAB: SETTINGS / SHOP ===
local RodList = {}
for k, _ in pairs(ShopData.Rods) do table.insert(RodList, k) end
if #RodList == 0 then table.insert(RodList, "No Data") end
table.sort(RodList)

-- Dropdown: CreateDropdown("ID", { ... })
local RodDropdown = Tabs.Settings:CreateDropdown("RodSelect", {
    Title = "Select Rod",
    Values = RodList,
    Multi = false,
    Default = 1,
})
RodDropdown:OnChanged(function(val) SelectedRod = ShopData.Rods[val] end)

-- Button: CreateButton{ ... } (PERHATIKAN: Tanpa ID string di depan, pakai kurung kurawal)
Tabs.Settings:CreateButton{
    Title = "Buy Selected Rod",
    Description = "Purchase from merchant",
    Callback = function() 
        if SelectedRod and NetworkLoaded then 
            Events.buyRod:InvokeServer(SelectedRod)
            Fluent:Notify({Title="Shop", Content="Buy Request Sent", Duration=2})
        else
            Fluent:Notify({Title="Error", Content="Wait loading / Select rod", Duration=2})
        end
    end
}

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
        Events.sell = NetFolder:WaitForChild("RF/SellAllItems", 2)
        Events.buyRod = NetFolder:WaitForChild("RF/PurchaseFishingRod", 2)
        
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

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
