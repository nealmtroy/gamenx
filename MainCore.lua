-- Gamen X | Core Logic v1.5.0 (Precision Shake Update)
-- Update: Auto Shake sekarang menargetkan tombol secara presisi (AbsolutePosition)
-- Fix: Mencegah klik meleset jika resolusi layar berubah

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v1.5.0...")

-- 1. LOAD VARIABLES
local success, Data = pcall(function()
    return loadstring(game:HttpGet(Variables_URL))()
end)

if not success or type(Data) ~= "table" then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Gamen X Error",
        Text = "Gagal memuat Variables! Script dihentikan.",
        Duration = 10
    })
    return
end

-- ====== SERVICES ======
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = nil
pcall(function() 
    VirtualUser = game:GetService("VirtualUser") 
    if VirtualUser then VirtualUser:CaptureController() end
end)

-- ====== UI LIBRARY ======
local successLib, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not successLib or not Fluent then return end

local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Gamen X | Core v1.5.0",
    SubTitle = "Precision Shake",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

Fluent:Notify({Title = "Gamen X", Content = "Precision Shake Active.", Duration = 3})

-- ====== LOCAL STATE ======
local Config = Data.Config
local ShopData = Data.ShopData
local LocationCoords = Data.LocationCoords
local FishTierMap = Data.FishTierMap or {}
local TierColors = Data.TierColors or {}

local SelectedRod, SelectedBait = nil, nil
local currentMode, selectedTarget = "None", nil
local NetworkLoaded = false
local Events = {}
local InputControlModule = nil

-- ====== HELPER ======
local function GetTierName(tier)
    local names = {[1]="Common",[2]="Uncommon",[3]="Rare",[4]="Epic",[5]="Legendary",[6]="Mythic",[7]="Secret"}
    return names[tier] or "Unknown"
end

local function SendWebhook(url, payload)
    local req = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
    if req then 
        req({
            Url = url, 
            Method = "POST", 
            Headers = {["Content-Type"] = "application/json"}, 
            Body = HttpService:JSONEncode(payload)
        }) 
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
    
    if Config.DiscordUrl ~= "" then
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
    
    if Config.TelegramToken ~= "" and Config.TelegramChatID ~= "" then
        SendWebhook("https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage", {
            ["chat_id"] = Config.TelegramChatID,
            ["text"] = string.format("🎣 *Gamen X Notification*\n\nFish: *%s*\nRarity: *%s*\nWeight: `%s kg`", fishNameStr, tierName, weight),
            ["parse_mode"] = "Markdown"
        })
    end
end

-- ====== NETWORK ======
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
        Events.unequip = NetFolder:WaitForChild("RE/UnequipToolFromHotbar", 2)
        Events.sell = NetFolder:WaitForChild("RF/SellAllItems", 2)
        Events.buyRod = NetFolder:WaitForChild("RF/PurchaseFishingRod", 2)
        Events.buyBait = NetFolder:WaitForChild("RF/PurchaseBait", 2)
        Events.updateState = NetFolder:WaitForChild("RF/UpdateAutoFishingState", 2)
        
        Events.fishCaught = NetFolder:WaitForChild("RE/FishCaught", 2)
        if Events.fishCaught then
            Events.fishCaught.OnClientEvent:Connect(HandleFishCaught)
        end

        NetworkLoaded = true
        Fluent:Notify({Title = "Connected", Content = "Gamen X Connected!", Duration = 3})
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

-- UPDATED: SHAKE PRESISI
local function PerformAutoShake()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return end
    local shakeUI = PlayerGui:FindFirstChild("shakeui")
    if shakeUI and shakeUI.Enabled then
        local safezone = shakeUI:FindFirstChild("safezone")
        local button = safezone and safezone:FindFirstChild("button")
        
        if button and button.Visible then
            pcall(function() button:Activate() end)
            pcall(function() if firesignal then firesignal(button.MouseButton1Click) end end)
            
            if VirtualUser then
                pcall(function()
                    -- MENGHITUNG TENGAH TOMBOL SECARA AKURAT
                    -- Bukan tengah layar, tapi tengah tombolnya sendiri
                    local pos = button.AbsolutePosition
                    local size = button.AbsoluteSize
                    local centerX = pos.X + (size.X / 2)
                    local centerY = pos.Y + (size.Y / 2)
                    
                    VirtualUser:Button1Down(Vector2.new(centerX, centerY))
                    task.wait(0.01)
                    VirtualUser:Button1Up(Vector2.new(centerX, centerY))
                end)
            end
        end
    end
end

-- ====== UI BUILDER ======
local Tabs = {
    Info = Window:AddTab({ Title = "Info", Icon = "scan-face" }),
    Fishing = Window:AddTab({ Title = "Fishing", Icon = "anchor" }),
    Merchant = Window:AddTab({ Title = "Merchant", Icon = "shopping-cart" }),
    Webhook = Window:AddTab({ Title = "Webhook", Icon = "bell" }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

Tabs.Info:AddParagraph({Title = "Gamen X Core", Content = "Version: 1.5.0\nUpdated Shake Logic."})

-- Fishing Tab
Tabs.Fishing:AddSection("Automation")
Tabs.Fishing:AddToggle("LegitMode", {Title="Legit Mode", Default=Config.LegitMode, Callback=function(v) Config.LegitMode=v; if NetworkLoaded and Events.updateState then Events.updateState:InvokeServer(v) end end})
Tabs.Fishing:AddToggle("AutoShake", {Title="Auto Shake", Default=Config.AutoShake, Callback=function(v) Config.AutoShake=v end})
Tabs.Fishing:AddToggle("AutoFish", {Title="Script Auto Fish", Default=Config.AutoFish, Callback=function(v) Config.AutoFish=v end})
Tabs.Fishing:AddToggle("AutoEquip", {Title="Auto Equip", Default=Config.AutoEquip, Callback=function(v) Config.AutoEquip=v end})
Tabs.Fishing:AddToggle("AutoSell", {Title="Auto Sell", Default=Config.AutoSell, Callback=function(v) Config.AutoSell=v end})

Tabs.Fishing:AddSection("Timings")
Tabs.Fishing:AddInput("ShakeD", {Title="Shake Delay", Default=tostring(Config.ShakeDelay), Numeric=true, Finished=true, Callback=function(v) Config.ShakeDelay=tonumber(v) or 0.1 end})
Tabs.Fishing:AddInput("FishD", {Title="Fish Delay", Default=tostring(Config.FishDelay), Numeric=true, Finished=true, Callback=function(v) Config.FishDelay=tonumber(v) or 2.0 end})
Tabs.Fishing:AddInput("SellD", {Title="Sell Delay", Default=tostring(Config.SellDelay), Numeric=true, Finished=true, Callback=function(v) Config.SellDelay=tonumber(v) or 10 end})

-- Merchant Tab
local RodList, BaitList = {}, {}
for k,_ in pairs(ShopData.Rods) do table.insert(RodList, k) end; table.sort(RodList)
for k,_ in pairs(ShopData.Baits) do table.insert(BaitList, k) end; table.sort(BaitList)

Tabs.Merchant:AddDropdown("Rods", {Title="Select Rod", Values=RodList, Callback=function(v) SelectedRod=ShopData.Rods[v] end})
Tabs.Merchant:AddButton({Title="Buy Rod", Callback=function() if SelectedRod and NetworkLoaded then Events.buyRod:InvokeServer(SelectedRod) end end})
Tabs.Merchant:AddDropdown("Baits", {Title="Select Bait", Values=BaitList, Callback=function(v) SelectedBait=ShopData.Baits[v] end})
Tabs.Merchant:AddButton({Title="Buy Bait", Callback=function() if SelectedBait and NetworkLoaded then Events.buyBait:InvokeServer(SelectedBait) end end})

-- Webhook Tab
Tabs.Webhook:AddSection("Configuration")
Tabs.Webhook:AddInput("Discord", {Title="Discord URL", Default=Config.DiscordUrl, Callback=function(v) Config.DiscordUrl=v end})
Tabs.Webhook:AddInput("TeleToken", {Title="Tele Token", Default=Config.TelegramToken, Callback=function(v) Config.TelegramToken=v end})
Tabs.Webhook:AddInput("TeleID", {Title="Tele Chat ID", Default=Config.TelegramChatID, Callback=function(v) Config.TelegramChatID=v end})

Tabs.Webhook:AddSection("Notification Settings")
Tabs.Webhook:AddToggle("WebhookFish", {Title="Notify Fish Caught", Default=Config.WebhookFish, Callback=function(v) Config.WebhookFish=v end})
Tabs.Webhook:AddDropdown("MinTierSelect", {
    Title = "Minimum Rarity to Notify",
    Values = {"1 - Common", "2 - Uncommon", "3 - Rare", "4 - Epic", "5 - Legendary", "6 - Mythic", "7 - Secret"},
    Default = Config.WebhookMinTier .. " - " .. GetTierName(Config.WebhookMinTier),
    Callback = function(v) Config.WebhookMinTier = tonumber(string.sub(v, 1, 1)) end
})
Tabs.Webhook:AddButton({Title="Test Webhook", Callback=function() 
    if Config.DiscordUrl~="" then SendWebhook(Config.DiscordUrl, {content="Test", embeds={{title="Gamen X", description="Discord OK!", color=65280}}}) end
    if Config.TelegramToken~="" then SendWebhook("https://api.telegram.org/bot"..Config.TelegramToken.."/sendMessage", {chat_id=Config.TelegramChatID, text="Gamen X\nTelegram OK!"}) end
end})

-- Teleport Tab
local LocationKeys = {}; for k,_ in pairs(LocationCoords) do table.insert(LocationKeys,k) end; table.sort(LocationKeys)
local TargetDrop = Tabs.Teleport:AddDropdown("Target", {Title="Target", Values={}, Callback=function(v) selectedTarget=v end})
local function GetNames() local l={}; for _,v in pairs(Players:GetPlayers()) do if v~=LocalPlayer then table.insert(l,v.Name) end end; return l end

Tabs.Teleport:AddDropdown("Mode", {Title="Mode", Values={"Player", "Location"}, Callback=function(v) currentMode=v; selectedTarget=nil; TargetDrop:SetValue(nil); if v=="Player" then TargetDrop:SetValues(GetNames()) else TargetDrop:SetValues(LocationKeys) end end})
Tabs.Teleport:AddButton({Title="Teleport", Callback=function()
    if currentMode=="Player" then local p=Players:FindFirstChild(selectedTarget); if p and p.Character then LocalPlayer.Character.HumanoidRootPart.CFrame=p.Character.HumanoidRootPart.CFrame end
    elseif currentMode=="Location" then LocalPlayer.Character.HumanoidRootPart.CFrame=CFrame.new(LocationCoords[selectedTarget]) end
end})

-- ====== LOOPS ======
task.spawn(function() while true do if Config.AutoFish and NetworkLoaded then CastRod(); task.wait(Config.FishDelay); ReelIn(); task.wait(Config.CatchDelay) else task.wait(0.5) end task.wait(0.1) end end)
task.spawn(function() while true do if Config.AutoShake then PerformAutoShake(); task.wait(Config.ShakeDelay) else task.wait(0.5) end end end)
task.spawn(function() while true do if Config.AutoEquip and NetworkLoaded then pcall(function() Events.equip:FireServer(1) end) end task.wait(2.5) end end)
task.spawn(function() while true do if Config.AutoSell and NetworkLoaded then pcall(function() Events.sell:InvokeServer() end) task.wait(Config.SellDelay) else task.wait(1) end end end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)
