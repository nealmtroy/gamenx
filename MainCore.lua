-- Gamen X | Core Logic v2.9.0 (Accordion UI & Webhook Beauty)
-- Update: Teleport Menu menggunakan sistem 'Manual Accordion' (Buka/Tutup)
-- Update: Webhook Notification dipercantik + Support Tag User ID
-- Update: Fix Syntax Button & Dropdown Search

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v2.9.0...")

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
    Title = "Gamen X | Core v2.9.0",
    SubTitle = "Accordion Update",
    TabWidth = 120,
    Size = UDim2.fromOffset(580, 520),
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
local NetworkLoaded = false
local Events = {}
local InputControlModule = nil

-- ====== VISIBILITY HELPER (ACCORDION SYSTEM) ======
local function ToggleVisible(element)
    pcall(function()
        if element and element.Frame then
            element.Frame.Visible = not element.Frame.Visible
        end
    end)
end

local function SetVisible(element, state)
    pcall(function()
        if element and element.Frame then
            element.Frame.Visible = state
        end
    end)
end

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

-- LOGIKA WEBHOOK DIPERCANTIK
local function HandleFishCaught(fishName, fishData)
    if not Config.WebhookFish then return end
    local fishNameStr = tostring(fishName)
    local tier = FishTierMap[fishNameStr] or 1
    if tier < Config.WebhookMinTier then return end
    
    local weight = (fishData and fishData.Weight) and tostring(fishData.Weight) or "?"
    local tierName = GetTierName(tier)
    local tierColor = TierColors[tier] or 16777215
    
    -- DISCORD
    if Config.DiscordUrl and Config.DiscordUrl ~= "" then
        local contentMsg = ""
        if Config.DiscordID and Config.DiscordID ~= "" then
            contentMsg = "Hey <@" .. Config.DiscordID .. ">, you caught something!"
        end
        
        SendWebhook(Config.DiscordUrl, {
            ["content"] = contentMsg,
            ["embeds"] = {{
                ["title"] = "🎣 Fish Caught!",
                ["description"] = string.format("You caught a **%s**!\n\n⚖️ **Weight:** %s kg\n⭐ **Rarity:** %s", fishNameStr, weight, tierName),
                ["color"] = tierColor,
                ["footer"] = { ["text"] = "Gamen X • " .. os.date("%X") },
                ["thumbnail"] = { ["url"] = "https://i.imgur.com/h5Xk5Fp.png" }
            }}
        })
    end
    
    -- TELEGRAM
    if Config.TelegramToken and Config.TelegramToken ~= "" then
        local tagMsg = ""
        if Config.TelegramUserID and Config.TelegramUserID ~= "" then
            tagMsg = "["..Config.TelegramUserID.."](tg://user?id="..Config.TelegramUserID..") "
        end
        
        SendWebhook("https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage", {
            ["chat_id"] = Config.TelegramChatID,
            ["text"] = string.format("🎣 *Gamen X Notification*\n\n%sHello!\nYou just caught a *%s*!\n\n⚖️ Weight: `%s kg`\n⭐ Rarity: *%s*", tagMsg, fishNameStr, weight, tierName),
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
    Main = Window:Tab({ Title = "Main", Icon = "home" }),
    Teleport = Window:Tab({ Title = "Teleport", Icon = "map-pin" }),
    Merchant = Window:Tab({ Title = "Shop", Icon = "shopping-cart" }),
    Webhook = Window:Tab({ Title = "Webhook", Icon = "bell" }),
    Settings = Window:Tab({ Title = "Settings", Icon = "settings" }),
}

-- === TAB: MAIN ===
local MainSection = Tabs.Main:Section("Automation Features")

MainSection:Toggle("AutoFish", {
    Title = "Enable Auto Fish",
    Description = "Spam Cast & Reel (Barbar Mode)",
    Default = false,
    Callback = function(state) Config.AutoFish = state end
})

MainSection:Toggle("AutoEquip", {Title = "Auto Equip Rod", Default = false, Callback = function(state) Config.AutoEquip = state end})
MainSection:Toggle("AutoSell", {Title = "Auto Sell All", Default = false, Callback = function(state) Config.AutoSell = state end})

local TimingSection = Tabs.Main:Section("Delays")
TimingSection:Input("FishDelay", {Title = "Fish Delay (Bite Time)", Default = "2.0", Numeric = true, Finished = true, Callback = function(val) Config.FishDelay = tonumber(val) or 2.0 end})
TimingSection:Input("SellDelay", {Title = "Sell Delay", Default = "10", Numeric = true, Finished = true, Callback = function(val) Config.SellDelay = tonumber(val) or 10 end})

-- === TAB: TELEPORT (ACCORDION STYLE) ===
local function GetPlayerNames()
    local l = {}
    for _,v in pairs(Players:GetPlayers()) do if v~=LocalPlayer then table.insert(l,v.Name) end end
    if #l == 0 then table.insert(l, "No Players") end
    return l
end

local LocationKeys = {}
if LocationCoords then for k,_ in pairs(LocationCoords) do table.insert(LocationKeys,k) end end
table.sort(LocationKeys)

local TeleSection = Tabs.Teleport:Section("Teleport Manager")

-- [[ 1. PLAYER ACCORDION ]]
TeleSection:Button({
    Title = "📂 Player Teleport",
    Description = "Click to Expand/Collapse",
    Callback = function()
        ToggleVisible(Options.PlayerTarget)
        ToggleVisible(Options.RefreshPlayers)
        ToggleVisible(Options.TeleportPlayerBtn)
    end
})

local PlayerDrop = TeleSection:Dropdown("PlayerTarget", {
    Title = "Select Player",
    Values = GetPlayerNames(),
    Multi = false,
    Default = 1,
    Searchable = true
})

local RefreshBtn = TeleSection:Button({
    Title = "Refresh Players",
    Callback = function() PlayerDrop:SetValues(GetPlayerNames()) end
})

local TelePlayerBtn = TeleSection:Button({
    Title = "Teleport to Player",
    Callback = function()
        local target = Players:FindFirstChild(PlayerDrop.Value)
        if target and target.Character then 
            LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame 
            Fluent:Notify({Title="Success", Content="Teleported!", Duration=2})
        else
            Fluent:Notify({Title="Error", Content="Player not found", Duration=2})
        end
    end
})

-- Hide Player Elements by Default
SetVisible(PlayerDrop, false)
SetVisible(RefreshBtn, false)
SetVisible(TelePlayerBtn, false)

-- [[ 2. LOCATION ACCORDION ]]
TeleSection:Button({
    Title = "📂 Location Teleport",
    Description = "Click to Expand/Collapse",
    Callback = function()
        ToggleVisible(Options.LocTarget)
        ToggleVisible(Options.TeleportLocBtn)
    end
})

local LocDrop = TeleSection:Dropdown("LocTarget", {
    Title = "Select Location",
    Values = LocationKeys,
    Multi = false,
    Default = 1,
    Searchable = true
})

local TeleLocBtn = TeleSection:Button({
    Title = "Teleport to Location",
    Callback = function()
        local target = LocationCoords[LocDrop.Value]
        if target then 
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(target) 
            Fluent:Notify({Title="Success", Content="Arrived!", Duration=2})
        end
    end
})

-- Hide Location Elements by Default
SetVisible(LocDrop, false)
SetVisible(TeleLocBtn, false)


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
    Callback = function() if SelectedRod and NetworkLoaded then Events.buyRod:InvokeServer(SelectedRod) end end
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
    Callback = function() if SelectedBait and NetworkLoaded then Events.buyBait:InvokeServer(SelectedBait) end end
})

-- === TAB: WEBHOOK (SEPARATED & TAG USER) ===
local DiscSection = Tabs.Webhook:Section("Discord Settings")
DiscSection:Toggle("WebhookDiscord", {Title="Enable Discord", Default=false, Callback=function(v) Config.WebhookDiscord=v end})
DiscSection:Input("DiscordUrl", {Title="Webhook URL", Default="", Callback=function(v) Config.DiscordUrl=v end})
DiscSection:Input("DiscordID", {Title="Tag User ID", Description="Example: 123456789", Default="", Callback=function(v) Config.DiscordID=v end})

local TeleSection = Tabs.Webhook:Section("Telegram Settings")
TeleSection:Toggle("WebhookTelegram", {Title="Enable Telegram", Default=false, Callback=function(v) Config.WebhookTelegram=v end})
TeleSection:Input("TeleToken", {Title="Bot Token", Default="", Callback=function(v) Config.TelegramToken=v end})
TeleSection:Input("TeleChatID", {Title="Chat ID", Default="", Callback=function(v) Config.TelegramChatID=v end})
TeleSection:Input("TeleUserID", {Title="Tag User ID", Description="Optional", Default="", Callback=function(v) Config.TelegramUserID=v end})

local GenSection = Tabs.Webhook:Section("General Settings")
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
    Description="Send test notification",
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
