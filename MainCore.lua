-- Gamen X | Core Logic v6.1.0 (Stable Restore)
-- Update: Menghapus logika Accordion/Collapsible manual yang menyebabkan error 'nil value'
-- Update: Mengembalikan tampilan standar (List) agar semua fitur MUNCUL & BERFUNGSI
-- Update: Tetap menggunakan Auto-Scanner (Tanpa JSON manual di variable)

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v6.1.0...")

-- 1. LOAD VARIABLES
local success, Data = pcall(function()
    return loadstring(game:HttpGet(Variables_URL))()
end)

if not success or type(Data) ~= "table" then
    Data = { Config = {}, ShopData = {Rods={}, Baits={}}, LocationCoords = {}, InventoryMap={}, IdToName={} }
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
    Title = "Gamen X | Core v6.1.0",
    SubTitle = "Stable Version",
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
-- Default Safety
Config.AutoFish = false
Config.AutoEquip = false
Config.AutoSell = false
Config.FishDelay = 2.0
Config.SellDelay = 10.0
Config.WebhookFish = false
Config.WebhookMinTier = 1

local ShopData = { Rods = {}, Baits = {} } -- Kosongkan dulu, nanti diisi Scanner
local LocationCoords = Data.LocationCoords or {}
local FishTierMap = {} 
local IdToName = {}
local TierColors = Data.TierColors or {}

local SelectedRod, SelectedBait = nil, nil
local currentMode, selectedTarget = "None", nil
local NetworkLoaded = false
local Events = {}
local InputControlModule = nil
local GameModules = {}

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
    
    local realName = tostring(fishName)
    if IdToName[realName] then realName = IdToName[realName] end
    
    local tier = FishTierMap[realName] or 1
    if tier < Config.WebhookMinTier then return end
    
    local weight = (fishData and fishData.Weight) and tostring(fishData.Weight) or "?"
    local tierName = GetTierName(tier)
    local tierColor = TierColors[tier] or 16777215
    
    if Config.DiscordUrl and Config.DiscordUrl ~= "" then
        local contentMsg = Config.DiscordID ~= "" and "<@"..Config.DiscordID..">" or ""
        SendWebhook(Config.DiscordUrl, {content = contentMsg, embeds = {{title = "🎣 Fish Caught!", description = string.format("**%s**\nWeight: **%s** kg\nRarity: **%s**", realName, weight, tierName), color = tierColor}}})
    end
    if Config.TelegramToken and Config.TelegramToken ~= "" then
        local tagMsg = Config.TelegramUserID ~= "" and "["..Config.TelegramUserID.."](tg://user?id="..Config.TelegramUserID..") " or ""
        SendWebhook("https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage", {chat_id = Config.TelegramChatID, text = string.format("🎣 *Gamen X Notification*\n%s\nYou caught: *%s*\nRarity: *%s*\nWeight: `%s kg`", tagMsg, realName, tierName, weight), parse_mode = "Markdown"})
    end
end

-- [[ GAME ITEM SCANNER ]]
local function ScanGameItems()
    local itemsFolder = ReplicatedStorage:WaitForChild("Items", 5)
    if not itemsFolder then return end
    
    for _, module in pairs(itemsFolder:GetChildren()) do
        if module:IsA("ModuleScript") then
            local success, data = pcall(require, module)
            if success and data and data.Data then
                local d = data.Data
                if d.Id and d.Name then
                    IdToName[tostring(d.Id)] = d.Name
                    IdToName[d.Id] = d.Name
                end
                if d.Type == "Fish" and d.Name and d.Tier then
                    FishTierMap[d.Name] = d.Tier
                elseif d.Type == "Fishing Rods" and d.Name and d.Id then
                    ShopData.Rods[d.Name] = d.Id
                elseif d.Type == "Baits" and d.Name and d.Id then
                    ShopData.Baits[d.Name] = d.Id
                end
            end
        end
    end
end

-- ====== NETWORK LOADER ======
task.spawn(function()
    task.wait(1)
    local success, err = pcall(function()
        ScanGameItems()
        
        local Packages = ReplicatedStorage:WaitForChild("Packages", 5)
        if not Packages then return end
        local Index = Packages:WaitForChild("_Index", 5)
        if not Index then return end
        local NetPackage = Index:FindFirstChild("sleitnick_net@0.2.0")
        if not NetPackage then
            for _, child in pairs(Index:GetChildren()) do if child.Name:find("sleitnick_net") then NetPackage = child break end end
        end
        if not NetPackage then return end
        local NetFolder = NetPackage:WaitForChild("net", 5)
        
        pcall(function() InputControlModule = ReplicatedStorage:WaitForChild("Modules", 2):WaitForChild("InputControl", 2) end)
        pcall(function()
            GameModules.Replion = require(ReplicatedStorage:WaitForChild("Packages", 5):WaitForChild("Replion", 5))
            if GameModules.Replion then GameModules.PlayerDataReplion = GameModules.Replion.Client:WaitReplion("Data") end
        end)

        Events.fishing = NetFolder:WaitForChild("RE/FishingCompleted", 2)
        Events.charge = NetFolder:WaitForChild("RF/ChargeFishingRod", 2)
        Events.minigame = NetFolder:WaitForChild("RF/RequestFishingMinigameStarted", 2)
        Events.equip = NetFolder:WaitForChild("RE/EquipToolFromHotbar", 2)
        Events.unequip = NetFolder:WaitForChild("RE/UnequipToolFromHotbar", 2)
        Events.sell = NetFolder:WaitForChild("RF/SellAllItems", 2)
        Events.buyRod = NetFolder:WaitForChild("RF/PurchaseFishingRod", 2)
        Events.buyBait = NetFolder:WaitForChild("RF/PurchaseBait", 2)
        Events.favorite = NetFolder:WaitForChild("RE/FavoriteItem", 2)
        Events.trade = NetFolder:WaitForChild("RF/InitiateTrade", 2)
        Events.getData = NetFolder:WaitForChild("RF/GetPlayerData", 2)
        Events.fishCaught = NetFolder:WaitForChild("RE/FishCaught", 2)
        
        if Events.fishCaught then Events.fishCaught.OnClientEvent:Connect(HandleFishCaught) end
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

local function GetInventoryList()
    local items, counts = {}, {}
    if GameModules.PlayerDataReplion then
        local success, data = pcall(function() return GameModules.PlayerDataReplion:Get() end)
        if success and data and data.Inventory then
            for _, itemData in pairs(data.Inventory.Items or {}) do
                local name = itemData.Name
                if tonumber(name) and IdToName[tostring(name)] then name = IdToName[tostring(name)] end
                if name then counts[name] = (counts[name] or 0) + (itemData.Amount or 1) end
            end
        end
    elseif Events.getData then
        local success, data = pcall(function() return Events.getData:InvokeServer() end)
        if success and data and data.Inventory then
            for _, item in pairs(data.Inventory) do
                local name = item.Name
                if name then counts[name] = (counts[name] or 0) + (item.Amount or 1) end
            end
        end
    end
    for name, count in pairs(counts) do table.insert(items, name .. " (x"..count..")") end
    if #items == 0 then table.insert(items, "Empty / Loading...") end
    table.sort(items)
    return items
end

local function PerformAutoFavorite()
    if not NetworkLoaded or not Events.favorite then return end
    local playerData = ReplicatedStorage:FindFirstChild("PlayerData")
    local myData = playerData and playerData:FindFirstChild(tostring(LocalPlayer.UserId))
    local inventory = myData and myData:FindFirstChild("Inventory")
    local folders = {inventory:FindFirstChild("Items"), inventory:FindFirstChild("Fish")}
    for _, folder in pairs(folders) do
        if folder then
            for _, item in pairs(folder:GetChildren()) do
                local nameObj = item:FindFirstChild("Name")
                local itemName = nameObj and nameObj.Value
                if not itemName then
                    local idObj = item:FindFirstChild("Id")
                    if idObj then itemName = IdToName[tostring(idObj.Value)] end
                end
                if itemName then
                    local tier = FishTierMap[itemName] or 0
                    if tier >= 5 then 
                         local lockedObj = item:FindFirstChild("Locked")
                         local isLocked = lockedObj and lockedObj.Value
                         if not isLocked then Events.favorite:FireServer(item.Name) task.wait(0.5) end
                    end
                end
            end
        end
    end
end

local function PerformAutoTrade()
    if not NetworkLoaded or not Events.trade or not Config.AutoTrade then return end
    local targetPlayer = Players:FindFirstChild(Config.TradePlayer)
    if not targetPlayer then Config.AutoTrade = false return end
    
    local itemsToSend = {}
    local playerData = ReplicatedStorage:FindFirstChild("PlayerData")
    local myData = playerData and playerData:FindFirstChild(tostring(LocalPlayer.UserId))
    local inventory = myData and myData:FindFirstChild("Inventory")
    local folders = {inventory:FindFirstChild("Items"), inventory:FindFirstChild("Fish")}
    
    for _, folder in pairs(folders) do
        if folder then
            for _, item in pairs(folder:GetChildren()) do
                local nameVal = nil
                local nameObj = item:FindFirstChild("Name")
                if nameObj then nameVal = nameObj.Value end
                if not nameVal then
                     local idObj = item:FindFirstChild("Id")
                     if idObj then nameVal = IdToName[tostring(idObj.Value)] end
                end
                local lockedObj = item:FindFirstChild("Locked")
                local isLocked = lockedObj and lockedObj.Value
                
                if nameVal == Config.TradeItem and not isLocked then
                    table.insert(itemsToSend, item.Name)
                end
            end
        end
    end
    
    local sentCount = 0
    for _, uuid in ipairs(itemsToSend) do
        if sentCount >= Config.TradeCount then break end
        local args = {targetPlayer.UserId, uuid}
        local success = pcall(function() Events.trade:InvokeServer(unpack(args)) end)
        if success then sentCount = sentCount + 1; task.wait(Config.TradeDelay) end
    end
    Config.AutoTrade = false 
end

-- ====== TABS ======
local Tabs = {
    Main = Window:Tab({ Title = "Main", Icon = "home" }),
    Teleport = Window:Tab({ Title = "Teleport", Icon = "map-pin" }),
    Trading = Window:Tab({ Title = "Trading", Icon = "repeat" }),
    Merchant = Window:Tab({ Title = "Shop", Icon = "shopping-cart" }),
    Webhook = Window:Tab({ Title = "Webhook", Icon = "bell" }),
    Settings = Window:Tab({ Title = "Settings", Icon = "settings" }),
}

-- === TAB: MAIN ===
local MainSec = Tabs.Main

MainSec:Toggle("AutoFish", {Title = "Enable Auto Fish", Description = "Spam Cast & Reel (Barbar)", Default = false, Callback = function(v) Config.AutoFish=v end})
MainSec:Toggle("AutoEquip", {Title = "Auto Equip Rod", Default = false, Callback = function(v) Config.AutoEquip=v end})
MainSec:Toggle("AutoSell", {Title = "Auto Sell All", Default = false, Callback = function(v) Config.AutoSell=v end})
MainSec:Toggle("AutoFavorite", {Title = "Auto Favorite (Legendary+)", Description = "Lock rare fish", Default = false, Callback = function(v) Config.AutoFavorite=v end})

MainSec:Input("FishDelay", {Title = "Fish Delay (Bite Time)", Default = "2.0", Numeric = true, Finished = true, Callback = function(v) Config.FishDelay=tonumber(v) or 2.0 end})
MainSec:Input("SellDelay", {Title = "Sell Delay (Seconds)", Default = "10", Numeric = true, Finished = true, Callback = function(v) Config.SellDelay=tonumber(v) or 10 end})

-- === TAB: TELEPORT ===
local LocationKeys = {}; if LocationCoords then for k,_ in pairs(LocationCoords) do table.insert(LocationKeys,k) end end; table.sort(LocationKeys)
local TeleSec = Tabs.Teleport

local function GetPlayerList()
    local l = {}
    for _,v in pairs(Players:GetPlayers()) do if v~=LocalPlayer then table.insert(l,v.Name) end end
    if #l==0 then table.insert(l, "No Players") end
    return l
end

TeleSec:Dropdown("TeleMode", {
    Title = "Teleport Mode", Values = {"Player", "Location"}, Multi = false, Default = 1,
    Callback = function(v) currentMode = v end
})

TeleSec:Dropdown("PlayerTarget", {Title = "Select Player", Values = GetPlayerList(), Multi = false, Default = 1, Searchable = true, Callback = function(v) selectedTarget=v end})
TeleSec:Button({Title = "Refresh Players", Callback = function() Fluent:Notify({Title="Updated",Content="Refreshed",Duration=1}) end}) -- Hacky refresh via re-render jika perlu, tapi biasanya values update otomatis jika library support

TeleSec:Dropdown("LocTarget", {Title = "Select Location", Values = LocationKeys, Multi = false, Default = 1, Searchable = true, Callback = function(v) selectedTarget=v end})

TeleSec:Button({
    Title = "Teleport Now",
    Callback = function()
        if currentMode == "Player" then
            local t = Players:FindFirstChild(selectedTarget)
            if t and t.Character then LocalPlayer.Character.HumanoidRootPart.CFrame=t.Character.HumanoidRootPart.CFrame end
        elseif currentMode == "Location" then
            local t = LocationCoords[selectedTarget]
            if t then LocalPlayer.Character.HumanoidRootPart.CFrame=CFrame.new(t) end
        end
    end
})

-- === TAB: TRADING ===
local TradeSec = Tabs.Trading
local PlayerDrop = TradeSec:Dropdown("TradePlayer", {Title = "Select Player", Values = GetPlayerList(), Multi = false, Default = 1, Searchable = true, Callback = function(v) Config.TradePlayer = v end})
TradeSec:Button({Title="Refresh Players", Callback=function() end})

local ItemDrop = TradeSec:Dropdown("TradeItem", {Title = "Select Item", Values = {"Click Refresh"}, Multi = false, Default = 1, Searchable = true, Callback = function(v) if v then Config.TradeItem = string.match(v, "^(.-) %(") or v end end})
TradeSec:Button({Title="Refresh Inventory", Callback=function() local list=GetInventoryList(); ItemDrop:SetValues(list); ItemDrop:SetValue(nil) end})

TradeSec:Input("TradeCount", {Title="Amount", Default="1", Numeric=true, Finished=true, Callback=function(v) Config.TradeCount=tonumber(v) or 1 end})
TradeSec:Toggle("AutoTrade", {Title="Start Trading", Default=false, Callback=function(v) Config.AutoTrade=v; if v then PerformAutoTrade() end end})

-- === TAB: MERCHANT ===
local ShopSec = Tabs.Merchant
local RodList = {}; if ShopData.Rods then for k,_ in pairs(ShopData.Rods) do table.insert(RodList, k) end end; table.sort(RodList)
local RodDrop = ShopSec:Dropdown("RodSelect", {Title="Select Rod", Values=RodList, Multi=false, Default=1, Searchable=true, Callback=function(v) if ShopData.Rods then SelectedRod=ShopData.Rods[v] end end})
ShopSec:Button({Title="Buy Rod", Callback=function() if SelectedRod and NetworkLoaded then Events.buyRod:InvokeServer(SelectedRod) end end})

local BaitList = {}; if ShopData.Baits then for k,_ in pairs(ShopData.Baits) do table.insert(BaitList, k) end end; table.sort(BaitList)
local BaitDrop = ShopSec:Dropdown("BaitSelect", {Title="Select Bait", Values=BaitList, Multi=false, Default=1, Searchable=true, Callback=function(v) if ShopData.Baits then SelectedBait=ShopData.Baits[v] end end})
ShopSec:Button({Title="Buy Bait", Callback=function() if SelectedBait and NetworkLoaded then Events.buyBait:InvokeServer(SelectedBait) end end})

-- Update Dropdown Shop (Async)
task.spawn(function()
    repeat task.wait(2) until next(ShopData.Rods)
    local NR, NB = {}, {}
    for k,_ in pairs(ShopData.Rods) do table.insert(NR,k) end; table.sort(NR); RodDrop:SetValues(NR)
    for k,_ in pairs(ShopData.Baits) do table.insert(NB,k) end; table.sort(NB); BaitDrop:SetValues(NB)
end)

-- === TAB: WEBHOOK ===
local WebhookSec = Tabs.Webhook
WebhookSec:Input("DiscordUrl", {Title="Discord URL", Default="", Callback=function(v) Config.DiscordUrl=v end})
WebhookSec:Input("DiscordID", {Title="Discord User ID", Default="", Callback=function(v) Config.DiscordID=v end})
WebhookSec:Toggle("WebhookDiscord", {Title="Enable Discord", Default=false, Callback=function(v) Config.WebhookDiscord=v end})
local TierList = {"1 - Common", "2 - Uncommon", "3 - Rare", "4 - Epic", "5 - Legendary", "6 - Mythic", "7 - Secret"}
WebhookSec:Dropdown("MinTier", {Title="Min Rarity", Values=TierList, Multi=false, Default=1, Searchable=true, Callback=function(v) Config.WebhookMinTier=tonumber(string.sub(v,1,1)) end})

WebhookSec:Input("TeleToken", {Title="Telegram Token", Default="", Callback=function(v) Config.TelegramToken=v end})
WebhookSec:Input("TeleChatID", {Title="Telegram Chat ID", Default="", Callback=function(v) Config.TelegramChatID=v end})
WebhookSec:Input("TeleUserID", {Title="Telegram User ID", Default="", Callback=function(v) Config.TelegramUserID=v end})
WebhookSec:Toggle("WebhookTelegram", {Title="Enable Telegram", Default=false, Callback=function(v) Config.WebhookTelegram=v end})
WebhookSec:Button({Title="Test Webhook", Callback=function() if Config.DiscordUrl~="" then SendWebhook(Config.DiscordUrl, {content="Test", embeds={{title="Gamen X", description="OK!", color=65280}}}) end end})

-- ====== LOOPS ======
task.spawn(function()
    while true do
        if Config.AutoFish and NetworkLoaded then CastRod(); task.wait(Config.FishDelay); ReelIn(); else task.wait(0.5) end
        task.wait(0.1) 
    end
end)
task.spawn(function() while true do if Config.AutoEquip and NetworkLoaded then pcall(function() Events.equip:FireServer(1) end) end task.wait(2.5) end end)
task.spawn(function() while true do if Config.AutoSell and NetworkLoaded then pcall(function() Events.sell:InvokeServer() end) end task.wait(Config.SellDelay or 10) end end)
task.spawn(function() while true do if Config.AutoFavorite and NetworkLoaded then PerformAutoFavorite() end task.wait(5) end end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
Fluent:Notify({Title = "Gamen X", Content = "Loaded Successfully", Duration = 5})
