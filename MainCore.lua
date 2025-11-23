-- Gamen X | Core Logic v3.3.0 (Accordion Final Fix)
-- Update: Fungsi 'SetItemVisible' diperbaiki untuk Fluent Renewed
-- Update: Menu Teleport DIJAMIN tertutup saat awal jalan
-- Update: Logika Buka-Tutup lebih responsif

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v3.3.0...")

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
    Title = "Gamen X | Core v3.3.0",
    SubTitle = "Accordion Final",
    TabWidth = 120,
    Size = UDim2.fromOffset(580, 520),
    Resize = true,
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Options = Fluent.Options

-- ====== LOCAL STATE ======
local Config = Data.Config or {}
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
    local tierName = "Tier " .. tostring(tier)
    local tierColor = TierColors[tier] or 16777215
    
    if Config.DiscordUrl and Config.DiscordUrl ~= "" then
        local contentMsg = Config.DiscordID ~= "" and "<@"..Config.DiscordID..">" or ""
        SendWebhook(Config.DiscordUrl, {
            ["content"] = contentMsg,
            ["embeds"] = {{
                ["title"] = "🎣 Fish Caught!",
                ["description"] = string.format("**%s**\nWeight: **%s** kg\nRarity: **%s**", fishNameStr, weight, tierName),
                ["color"] = tierColor,
                ["footer"] = { ["text"] = "Gamen X | " .. os.date("%X") }
            }}
        })
    end
    
    if Config.TelegramToken and Config.TelegramToken ~= "" then
        local tagMsg = Config.TelegramUserID ~= "" and "["..Config.TelegramUserID.."](tg://user?id="..Config.TelegramUserID..") " or ""
        SendWebhook("https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage", {
            ["chat_id"] = Config.TelegramChatID,
            ["text"] = string.format("🎣 *Gamen X Notification*\n%s\nYou caught: *%s*\nRarity: *%s*\nWeight: `%s kg`", tagMsg, fishNameStr, tierName, weight),
            ["parse_mode"] = "Markdown"
        })
    end
end

-- [[ VISIBILITY HELPER v2 ]]
-- Fungsi ini lebih teliti mencari 'Frame' untuk disembunyikan
local function SetItemVisible(item, state)
    pcall(function()
        if item then
            -- Cek struktur Fluent Renewed yang mungkin
            if item.Frame then
                item.Frame.Visible = state
            elseif item.Instance and item.Instance.Frame then
                item.Instance.Frame.Visible = state
            elseif item.Instance and item.Instance:IsA("GuiObject") then
                item.Instance.Visible = state
            end
        end
    end)
end

local function ToggleGroup(group, state)
    for _, item in pairs(group) do
        SetItemVisible(item, state)
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
    Main = Window:Tab({ Title = "Main", Icon = "home" }),
    Teleport = Window:Tab({ Title = "Teleport", Icon = "map-pin" }),
    Merchant = Window:Tab({ Title = "Shop", Icon = "shopping-cart" }),
    Webhook = Window:Tab({ Title = "Webhook", Icon = "bell" }),
    Settings = Window:Tab({ Title = "Settings", Icon = "settings" }),
}

-- === TAB: MAIN ===
Tabs.Main:Paragraph("StatusPara", {Title = "Status", Content = "Script Active."})

Tabs.Main:Toggle("AutoFish", {Title = "Enable Auto Fish", Description = "Spam Cast & Reel (Barbar)", Default = false, Callback = function(v) Config.AutoFish=v end})
Tabs.Main:Toggle("AutoEquip", {Title = "Auto Equip Rod", Default = false, Callback = function(v) Config.AutoEquip=v end})
Tabs.Main:Toggle("AutoSell", {Title = "Auto Sell All", Default = false, Callback = function(v) Config.AutoSell=v end})

Tabs.Main:Input("FishDelay", {Title = "Fish Delay (Bite Time)", Default = "2.0", Numeric = true, Finished = true, Callback = function(v) Config.FishDelay=tonumber(v) or 2.0 end})
Tabs.Main:Input("SellDelay", {Title = "Sell Delay", Default = "10", Numeric = true, Finished = true, Callback = function(v) Config.SellDelay=tonumber(v) or 10 end})

-- === TAB: TELEPORT (ACCORDION) ===
local function GetPlayerNames()
    local l = {}
    for _,v in pairs(Players:GetPlayers()) do if v~=LocalPlayer then table.insert(l,v.Name) end end
    if #l==0 then table.insert(l, "No Players") end
    return l
end
local LocationKeys = {}
if LocationCoords then for k,_ in pairs(LocationCoords) do table.insert(LocationKeys,k) end end
table.sort(LocationKeys)

-- Group Storage
local PlayerGroup = {}
local LocationGroup = {}
local PlayerOpen = false
local LocationOpen = false

-- 1. PLAYER ACCORDION
Tabs.Teleport:Button({
    Title = "Player Teleport",
    Description = "Click to Show/Hide Menu",
    Callback = function()
        PlayerOpen = not PlayerOpen
        ToggleGroup(PlayerGroup, PlayerOpen)
        
        -- Auto Close other menu
        if PlayerOpen then 
            LocationOpen = false
            ToggleGroup(LocationGroup, false)
        end
    end
})

-- Item-item Player (Dimasukkan ke tabel)
local PD = Tabs.Teleport:Dropdown("PlayerTarget", {Title = "Select Player", Values = GetPlayerNames(), Multi = false, Default = 1, Searchable = true})
local RB = Tabs.Teleport:Button({Title = "Refresh Players", Callback = function() PD:SetValues(GetPlayerNames()); PD:SetValue(nil) end})
local TPB = Tabs.Teleport:Button({
    Title = "Teleport to Player",
    Callback = function()
        local target = Players:FindFirstChild(PD.Value)
        if target and target.Character then LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame end
    end
})

table.insert(PlayerGroup, PD)
table.insert(PlayerGroup, RB)
table.insert(PlayerGroup, TPB)


-- 2. LOCATION ACCORDION
Tabs.Teleport:Button({
    Title = "Location Teleport",
    Description = "Click to Show/Hide Menu",
    Callback = function()
        LocationOpen = not LocationOpen
        ToggleGroup(LocationGroup, LocationOpen)
        
        if LocationOpen then 
            PlayerOpen = false
            ToggleGroup(PlayerGroup, false)
        end
    end
})

-- Item-item Location (Dimasukkan ke tabel)
local LD = Tabs.Teleport:Dropdown("LocTarget", {Title = "Select Location", Values = LocationKeys, Multi = false, Default = 1, Searchable = true})
local TLB = Tabs.Teleport:Button({
    Title = "Teleport to Location",
    Callback = function()
        local target = LocationCoords[LD.Value]
        if target then LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(target) end
    end
})

table.insert(LocationGroup, LD)
table.insert(LocationGroup, TLB)

-- [[ AUTO HIDE INIT ]]
-- Sembunyikan semua submenu saat script jalan
task.spawn(function()
    task.wait(0.5) -- Beri waktu render
    ToggleGroup(PlayerGroup, false)
    ToggleGroup(LocationGroup, false)
end)


-- === TAB: MERCHANT ===
local RodList = {}
if ShopData.Rods then for k,_ in pairs(ShopData.Rods) do table.insert(RodList, k) end end
table.sort(RodList)

Tabs.Merchant:Dropdown("RodSelect", {
    Title = "Select Rod", Values = RodList, Multi = false, Default = 1, Searchable = true,
    Callback = function(v) if ShopData.Rods then SelectedRod = ShopData.Rods[v] end end
})
Tabs.Merchant:Button({Title = "Buy Rod", Callback = function() if SelectedRod and NetworkLoaded then Events.buyRod:InvokeServer(SelectedRod) end end})

local BaitList = {}
if ShopData.Baits then for k,_ in pairs(ShopData.Baits) do table.insert(BaitList, k) end end
table.sort(BaitList)

Tabs.Merchant:Dropdown("BaitSelect", {
    Title = "Select Bait", Values = BaitList, Multi = false, Default = 1, Searchable = true,
    Callback = function(v) if ShopData.Baits then SelectedBait = ShopData.Baits[v] end end
})
Tabs.Merchant:Button({Title = "Buy Bait", Callback = function() if SelectedBait and NetworkLoaded then Events.buyBait:InvokeServer(SelectedBait) end end})

-- === TAB: WEBHOOK ===
Tabs.Webhook:Paragraph("DiscHeader", {Title="Discord Settings"})
Tabs.Webhook:Toggle("WebhookDiscord", {Title="Enable Discord", Default=false, Callback=function(v) Config.WebhookDiscord=v end})
Tabs.Webhook:Input("DiscordUrl", {Title="Webhook URL", Default="", Callback=function(v) Config.DiscordUrl=v end})
Tabs.Webhook:Input("DiscordID", {Title="Tag User ID", Default="", Callback=function(v) Config.DiscordID=v end})

Tabs.Webhook:Paragraph("TeleHeader", {Title="Telegram Settings"})
Tabs.Webhook:Toggle("WebhookTelegram", {Title="Enable Telegram", Default=false, Callback=function(v) Config.WebhookTelegram=v end})
Tabs.Webhook:Input("TeleToken", {Title="Bot Token", Default="", Callback=function(v) Config.TelegramToken=v end})
Tabs.Webhook:Input("TeleChatID", {Title="Chat ID", Default="", Callback=function(v) Config.TelegramChatID=v end})
Tabs.Webhook:Input("TeleUserID", {Title="Tag User ID", Default="", Callback=function(v) Config.TelegramUserID=v end})

Tabs.Webhook:Paragraph("GenHeader", {Title="General"})
local TierList = {"1 - Common", "2 - Uncommon", "3 - Rare", "4 - Epic", "5 - Legendary", "6 - Mythic", "7 - Secret"}
Tabs.Webhook:Dropdown("MinTier", {Title="Min Rarity", Values=TierList, Multi=false, Default=1, Searchable=true, Callback=function(v) Config.WebhookMinTier = tonumber(string.sub(v, 1, 1)) end})

Tabs.Webhook:Button({
    Title="Test Webhook",
    Callback=function() 
        if Config.WebhookDiscord and Config.DiscordUrl~="" then 
            local content = Config.DiscordID~="" and "<@"..Config.DiscordID..">" or ""
            SendWebhook(Config.DiscordUrl, {content=content, embeds={{title="Gamen X", description="Discord Connected!", color=65280}}}) 
        end
        if Config.WebhookTelegram and Config.TelegramToken~="" then 
            local tag = Config.TelegramUserID~="" and "["..Config.TelegramUserID.."](tg://user?id="..Config.TelegramUserID..") " or ""
            SendWebhook("https://api.telegram.org/bot"..Config.TelegramToken.."/sendMessage", {chat_id=Config.TelegramChatID, text=tag.."Gamen X\nTelegram Connected!", parse_mode="Markdown"}) 
        end
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
