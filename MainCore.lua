-- Gamen X | Core Logic v2.5.0 (UI Redesign & Beautify)
-- Update: Teleport Tab dipisah (Player Section & Location Section)
-- Update: Webhook dipisah (Discord Section & Telegram Section)
-- Update: Fitur Tag User (Discord ID / Telegram UserID)
-- Update: Notifikasi Webhook lebih cantik (Embed & Markdown)

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v2.5.0...")

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
    Title = "Gamen X | Core v2.5.0",
    SubTitle = "Redesign",
    TabWidth = 120,
    Size = UDim2.fromOffset(580, 520),
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
Config.WebhookDiscord = false
Config.WebhookTelegram = false
Config.WebhookMinTier = 1

local ShopData = Data.ShopData or {Rods={}, Baits={}}
local LocationCoords = Data.LocationCoords or {}
local FishTierMap = Data.FishTierMap or {}
local TierColors = Data.TierColors or {}

local SelectedRod, SelectedBait = nil, nil
local selectedPlayer, selectedLocation = nil, nil
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
    local fishNameStr = tostring(fishName)
    local tier = FishTierMap[fishNameStr] or 1
    if tier < Config.WebhookMinTier then return end
    
    local weight = (fishData and fishData.Weight) and tostring(fishData.Weight) or "?"
    local tierName = GetTierName(tier)
    local tierColor = TierColors[tier] or 16777215
    
    -- === DISCORD ===
    if Config.WebhookDiscord and Config.DiscordUrl ~= "" then
        local contentText = ""
        if Config.DiscordID and Config.DiscordID ~= "" then
            contentText = "<@" .. Config.DiscordID .. ">" -- Tag User
        end
        
        SendWebhook(Config.DiscordUrl, {
            ["content"] = contentText,
            ["embeds"] = {{
                ["title"] = "🎣 Fish Caught!",
                ["description"] = string.format("**%s**\n\n⚖️ Weight: **%s** kg\n⭐ Rarity: **%s**", fishNameStr, weight, tierName),
                ["color"] = tierColor,
                ["footer"] = { ["text"] = "Gamen X | " .. os.date("%X") },
                ["thumbnail"] = { ["url"] = "https://i.imgur.com/h5Xk5Fp.png" } -- Opsional: Icon pancing
            }}
        })
    end
    
    -- === TELEGRAM ===
    if Config.WebhookTelegram and Config.TelegramToken ~= "" and Config.TelegramChatID ~= "" then
        local tagText = ""
        if Config.TelegramUserID and Config.TelegramUserID ~= "" then
            tagText = "["..Config.TelegramUserID.."](tg://user?id="..Config.TelegramUserID..") " -- Tag User Link
        end
        
        SendWebhook("https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage", {
            ["chat_id"] = Config.TelegramChatID,
            ["text"] = string.format("🎣 *Gamen X Notification*\n\n%sYou caught: *%s*\n⚖️ Weight: `%s kg`\n⭐ Rarity: *%s*", tagText, fishNameStr, weight, tierName),
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

-- ====== TABS DEFINITION ======
local Tabs = {
    Main = Window:CreateTab({ Title = "Main", Icon = "home" }),
    Teleport = Window:CreateTab({ Title = "Teleport", Icon = "map-pin" }), -- Dipindah ke posisi 2 biar enak
    Merchant = Window:CreateTab({ Title = "Shop", Icon = "shopping-cart" }),
    Webhook = Window:CreateTab({ Title = "Webhook", Icon = "bell" }),
    Settings = Window:CreateTab({ Title = "Settings", Icon = "settings" }),
}

-- === TAB: MAIN ===
local MainSection = Tabs.Main:Section("Automation Features")

MainSection:CreateToggle("AutoFish", {
    Title = "Enable Auto Fish",
    Description = "Spam Cast & Reel (Barbar Mode)",
    Default = false,
    Callback = function(state) Config.AutoFish = state end
})

MainSection:CreateToggle("AutoEquip", {Title = "Auto Equip Rod", Default = false, Callback = function(state) Config.AutoEquip = state end})
MainSection:CreateToggle("AutoSell", {Title = "Auto Sell All", Default = false, Callback = function(state) Config.AutoSell = state end})

local TimingSection = Tabs.Main:Section("Delays (Seconds)")
TimingSection:CreateInput("FishDelay", {
    Title = "Fish Delay (Bite Time)",
    Default = "2.0",
    Numeric = true,
    Finished = true,
    Callback = function(val) Config.FishDelay = tonumber(val) or 2.0 end
})
TimingSection:CreateInput("SellDelay", {
    Title = "Sell Delay",
    Default = "10",
    Numeric = true,
    Finished = true,
    Callback = function(val) Config.SellDelay = tonumber(val) or 10 end
})

-- === TAB: TELEPORT (SEPARATED) ===
local function GetPlayerNames()
    local l = {}
    for _,v in pairs(Players:GetPlayers()) do if v~=LocalPlayer then table.insert(l,v.Name) end end
    if #l == 0 then table.insert(l, "No Players") end
    return l
end

local LocationKeys = {}
if LocationCoords then for k,_ in pairs(LocationCoords) do table.insert(LocationKeys,k) end end
if #LocationKeys == 0 then table.insert(LocationKeys, "No Locations") end
table.sort(LocationKeys)

-- Section 1: Player
local PlayerSection = Tabs.Teleport:Section("Player Teleport")
local PlayerDrop = PlayerSection:CreateDropdown("PlayerTarget", {
    Title = "Select Player",
    Values = GetPlayerNames(),
    Multi = false,
    Default = 1,
    Searchable = true
})

PlayerSection:CreateButton({
    Title = "Refresh Players",
    Callback = function() PlayerDrop:SetValues(GetPlayerNames()) end
})

PlayerSection:CreateButton({
    Title = "Teleport to Player",
    Callback = function()
        local target = Players:FindFirstChild(PlayerDrop.Value)
        if target and target.Character then 
            LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame 
        else
            Fluent:Notify({Title="Error", Content="Player not found", Duration=2})
        end
    end
})

-- Section 2: Location
local LocationSection = Tabs.Teleport:Section("Location Teleport")
local LocDrop = LocationSection:CreateDropdown("LocTarget", {
    Title = "Select Location",
    Values = LocationKeys,
    Multi = false,
    Default = 1,
    Searchable = true
})

LocationSection:CreateButton({
    Title = "Teleport to Location",
    Callback = function()
        local target = LocationCoords[LocDrop.Value]
        if target then 
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(target) 
        end
    end
})

-- === TAB: MERCHANT ===
local ShopSection = Tabs.Merchant:Section("Item Shop")
local RodList = {}
if ShopData.Rods then for k,_ in pairs(ShopData.Rods) do table.insert(RodList, k) end end
table.sort(RodList)

local RodDrop = ShopSection:CreateDropdown("RodSelect", {Title = "Select Rod", Values = RodList, Multi = false, Default = 1, Searchable = true})
RodDrop:OnChanged(function(v) if ShopData.Rods then SelectedRod = ShopData.Rods[v] end end)
ShopSection:CreateButton({Title = "Buy Rod", Callback = function() if SelectedRod and NetworkLoaded then Events.buyRod:InvokeServer(SelectedRod) end end})

local BaitList = {}
if ShopData.Baits then for k,_ in pairs(ShopData.Baits) do table.insert(BaitList, k) end end
table.sort(BaitList)

local BaitDrop = ShopSection:CreateDropdown("BaitSelect", {Title = "Select Bait", Values = BaitList, Multi = false, Default = 1, Searchable = true})
BaitDrop:OnChanged(function(v) if ShopData.Baits then SelectedBait = ShopData.Baits[v] end end)
ShopSection:CreateButton({Title = "Buy Bait", Callback = function() if SelectedBait and NetworkLoaded then Events.buyBait:InvokeServer(SelectedBait) end end})

-- === TAB: WEBHOOK (SEPARATED) ===
-- Section Discord
local DiscordSection = Tabs.Webhook:Section("Discord Settings")
DiscordSection:CreateToggle("WebhookDiscord", {Title="Enable Discord Webhook", Default=false, Callback=function(v) Config.WebhookDiscord=v end})
DiscordSection:CreateInput("DiscordUrl", {Title="Webhook URL", Default="", Placeholder="https://discord.com/api/webhooks/...", Callback=function(v) Config.DiscordUrl=v end})
DiscordSection:CreateInput("DiscordID", {Title="Discord User ID", Description="Input ID to ping user (Example: 123456789)", Default="", Callback=function(v) Config.DiscordID=v end})

-- Section Telegram
local TelegramSection = Tabs.Webhook:Section("Telegram Settings")
TelegramSection:CreateToggle("WebhookTelegram", {Title="Enable Telegram Webhook", Default=false, Callback=function(v) Config.WebhookTelegram=v end})
TelegramSection:CreateInput("TeleToken", {Title="Bot Token", Default="", Placeholder="123:ABC...", Callback=function(v) Config.TelegramToken=v end})
TelegramSection:CreateInput("TeleChatID", {Title="Chat ID", Default="", Placeholder="-100...", Callback=function(v) Config.TelegramChatID=v end})
TelegramSection:CreateInput("TeleUserID", {Title="User ID (Tag)", Description="Input ID to tag user (Optional)", Default="", Callback=function(v) Config.TelegramUserID=v end})

-- Section General
local GeneralWeb = Tabs.Webhook:Section("General Settings")
local TierList = {"1 - Common", "2 - Uncommon", "3 - Rare", "4 - Epic", "5 - Legendary", "6 - Mythic", "7 - Secret"}
GeneralWeb:CreateDropdown("MinTier", {Title="Min Rarity", Values=TierList, Multi=false, Default=1, Searchable = true, Callback=function(v) Config.WebhookMinTier = tonumber(string.sub(v, 1, 1)) end})

GeneralWeb:CreateButton({Title="Test Webhook", Callback=function() 
    if Config.WebhookDiscord and Config.DiscordUrl~="" then 
        local content = Config.DiscordID~="" and "<@"..Config.DiscordID..">" or ""
        SendWebhook(Config.DiscordUrl, {content=content, embeds={{title="Gamen X", description="Discord Connected!", color=65280}}}) 
    end
    if Config.WebhookTelegram and Config.TelegramToken~="" then 
        local tag = Config.TelegramUserID~="" and "["..Config.TelegramUserID.."](tg://user?id="..Config.TelegramUserID..") " or ""
        SendWebhook("https://api.telegram.org/bot"..Config.TelegramToken.."/sendMessage", {chat_id=Config.TelegramChatID, text=tag.."Gamen X\nTelegram Connected!", parse_mode="Markdown"}) 
    end
end})

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
