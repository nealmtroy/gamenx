-- Gamen X | Core Logic v5.7.0 (UI Layout Fix)
-- Update: Membungkus semua elemen dalam 'Section' agar UI muncul (Wajib di Fluent Renewed)
-- Update: Fitur Accordion (Buka/Tutup) tetap berjalan
-- Update: Inventory Scanner lebih sabar (tunggu data)

-- [[ KONFIGURASI DEPENDENCY ]]
local Variables_URL = "https://raw.githubusercontent.com/nealmtroy/gamenx/main/Modules/Variables.lua"

print("[Gamen X] Initializing v5.7.0...")

-- 1. LOAD VARIABLES
local success, Data = pcall(function()
    return loadstring(game:HttpGet(Variables_URL))()
end)

if not success or type(Data) ~= "table" then
    Data = { Config = {}, ShopData = {Rods={}, Baits={}}, LocationCoords = {}, InventoryMap={} }
    warn("[Gamen X] Variables failed. Using defaults.")
end

-- ====== SERVICES ======
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ====== UI LIBRARY ======
local successLib, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
end)

if not successLib or not Fluent then return end

local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Fluent:Window({
    Title = "Gamen X | Core v5.7.0",
    SubTitle = "Layout Fix",
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
-- Default
Config.AutoFish = false
Config.AutoEquip = false
Config.AutoSell = false
Config.AutoFavorite = false
Config.AutoTrade = false
Config.TradeCount = 1
Config.TradeDelay = 1.0
Config.WebhookFish = false
Config.WebhookMinTier = 1

local ShopData = Data.ShopData or {Rods={}, Baits={}}
local LocationCoords = Data.LocationCoords or {}
local FishTierMap = Data.FishTierMap or {}
local InventoryMap = Data.InventoryMap or {}
local TierColors = Data.TierColors or {}
local IdToName = Data.IdToName or {}

local SelectedRod, SelectedBait = nil, nil
local NetworkLoaded = false
local Events = {}
local InputControlModule = nil
local GameModules = {}

-- ====== VISIBILITY HELPER ======
-- Fungsi ini menyembunyikan elemen UI di dalam Section
local function SetItemVisible(item, state)
    pcall(function()
        if item then
            -- Fluent Renewed menyimpan Frame di item.Frame atau item.Instance.Frame
            if item.Frame then item.Frame.Visible = state
            elseif item.Instance and item.Instance.Frame then item.Instance.Frame.Visible = state
            elseif item.Instance and item.Instance:IsA("GuiObject") then item.Instance.Visible = state
            end
        end
    end)
end

local function ToggleGroup(group, state)
    for _, item in pairs(group) do SetItemVisible(item, state) end
end

-- ANIMATION
local PurpleColor = Color3.fromRGB(170, 85, 255)
local function AddActiveLine(element)
    local frame = nil
    if element.Frame then frame = element.Frame 
    elseif element.Instance and element.Instance.Frame then frame = element.Instance.Frame end
    
    if not frame then return nil end
    
    local line = Instance.new("Frame")
    line.Name = "ActiveIndicator"
    line.BackgroundColor3 = PurpleColor
    line.BorderSizePixel = 0
    line.Position = UDim2.new(0.5, 0, 1, -2)
    line.AnchorPoint = Vector2.new(0.5, 0)
    line.Size = UDim2.new(0, 0, 0, 2)
    line.Parent = frame
    return line
end

local function AnimateLine(line, isActive)
    if not line then return end
    local targetSize = isActive and UDim2.new(1, 0, 0, 2) or UDim2.new(0, 0, 0, 2)
    TweenService:Create(line, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Size = targetSize}):Play()
end

-- ====== WEBHOOK LOGIC ======
local function SendWebhook(url, payload)
    local req = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
    if req then req({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(payload)}) end
end

local function HandleFishCaught(fishName, fishData)
    if not Config.WebhookFish then return end
    local fishNameStr = tostring(fishName)
    -- Translate ID jika perlu
    if IdToName[fishNameStr] then fishNameStr = IdToName[fishNameStr] end

    local tier = FishTierMap[fishNameStr] or 1
    if tier < Config.WebhookMinTier then return end
    
    local weight = (fishData and fishData.Weight) and tostring(fishData.Weight) or "?"
    local tierName = "Tier " .. tostring(tier)
    local tierColor = TierColors[tier] or 16777215
    
    if Config.DiscordUrl ~= "" then
        local contentMsg = Config.DiscordID ~= "" and "<@"..Config.DiscordID..">" or ""
        SendWebhook(Config.DiscordUrl, {content = contentMsg, embeds = {{title = "🎣 Fish Caught!", description = string.format("**%s**\nWeight: **%s** kg\nRarity: **%s**", fishNameStr, weight, tierName), color = tierColor}}})
    end
    if Config.TelegramToken ~= "" then
        local tagMsg = Config.TelegramUserID ~= "" and "["..Config.TelegramUserID.."](tg://user?id="..Config.TelegramUserID..") " or ""
        SendWebhook("https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage", {chat_id = Config.TelegramChatID, text = string.format("🎣 *Gamen X*\n%s\nCaught: *%s*\nRarity: *%s*\nWeight: `%s kg`", tagMsg, fishNameStr, tierName, weight), parse_mode = "Markdown"})
    end
end

-- ====== NETWORK LOADER ======
task.spawn(function()
    task.wait(1)
    local success, err = pcall(function()
        local Packages = ReplicatedStorage:WaitForChild("Packages", 5)
        local Index = Packages and Packages:WaitForChild("_Index", 5)
        if not Index then return end
        
        local NetPackage = Index:FindFirstChild("sleitnick_net@0.2.0")
        if not NetPackage then
            for _, child in pairs(Index:GetChildren()) do if child.Name:find("sleitnick_net") then NetPackage = child break end end
        end
        local NetFolder = NetPackage and NetPackage:WaitForChild("net", 5)
        if not NetFolder then return end
        
        pcall(function() InputControlModule = ReplicatedStorage:WaitForChild("Modules", 2):WaitForChild("InputControl", 2) end)
        
        -- Load Replion (Data Stream)
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

-- [[ SMART INVENTORY SCANNER ]]
local function GetInventoryList()
    local items, counts = {}, {}
    
    -- 1. Replion
    if GameModules.PlayerDataReplion then
        local success, data = pcall(function() return GameModules.PlayerDataReplion:Get() end)
        if success and data and data.Inventory then
            for _, itemData in pairs(data.Inventory.Items or {}) do
                local name = itemData.Name
                if tonumber(name) and IdToName[tostring(name)] then name = IdToName[tostring(name)] end
                if name then counts[name] = (counts[name] or 0) + (itemData.Amount or 1) end
            end
        end
    end
    
    -- 2. Folder Scan (Backup)
    if next(counts) == nil then
        local playerData = ReplicatedStorage:FindFirstChild("PlayerData")
        local myData = playerData and playerData:FindFirstChild(tostring(LocalPlayer.UserId))
        local inventory = myData and myData:FindFirstChild("Inventory")
        
        if inventory then
            local folders = {inventory:FindFirstChild("Items"), inventory:FindFirstChild("Fish")}
            for _, folder in pairs(folders) do
                if folder then
                    for _, item in pairs(folder:GetChildren()) do
                        local nameVal = nil
                        local nameObj = item:FindFirstChild("Name")
                        if nameObj then nameVal = nameObj.Value end
                        
                        if not nameVal then
                            local idObj = item:FindFirstChild("Id")
                            if idObj then 
                                nameVal = IdToName[tostring(idObj.Value)] or ("ID: "..tostring(idObj.Value))
                            end
                        end
                        
                        if nameVal then counts[nameVal] = (counts[nameVal] or 0) + 1 end
                    end
                end
            end
        end
    end

    for name, count in pairs(counts) do table.insert(items, name .. " (x"..count..")") end
    if #items == 0 then table.insert(items, "Empty Inventory") end
    table.sort(items)
    return items
end

-- [[ AUTO FAVORITE ]]
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
                
                -- Translate ID
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

-- [[ TRADING ]]
local function PerformAutoTrade()
    if not NetworkLoaded or not Events.trade or not Config.AutoTrade then return end
    local targetPlayer = Players:FindFirstChild(Config.TradePlayer)
    if not targetPlayer then 
        Fluent:Notify({Title="Error", Content="Player not found!", Duration=2})
        Config.AutoTrade = false
        return
    end
    
    -- Scan & Trade
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
        if success then
            sentCount = sentCount + 1
            task.wait(Config.TradeDelay)
        end
    end
    
    Fluent:Notify({Title="Trading", Content="Sent "..sentCount.." requests.", Duration=3})
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
-- FIX: Membuat Section pembungkus agar elemen muncul
local MainSec = Tabs.Main:Section("Automation")

local FishingGroup, SellGroup = {}, {}
local FishingLine, SellLine = nil, nil
local FishingOpen, SellOpen = false, false

local FishHeader = MainSec:Button({
    Title = "📂 Fishing Feature",
    Description = "Click to Expand",
    Callback = function()
        FishingOpen = not FishingOpen
        ToggleGroup(FishingGroup, FishingOpen)
        AnimateLine(FishingLine, FishingOpen)
        if FishingOpen then SellOpen=false; ToggleGroup(SellGroup,false); AnimateLine(SellLine,false) end
    end
})
FishingLine = AddActiveLine(FishHeader, PurpleColor)

local Inp1 = MainSec:Input("FishDelay", {Title="Fish Delay (Bite Time)", Default="2.0", Numeric=true, Finished=true, Callback=function(v) Config.FishDelay=tonumber(v) or 2.0 end})
local Inp2 = MainSec:Input("CatchDelay", {Title="Catch Delay (Cooldown)", Default="0.5", Numeric=true, Finished=true, Callback=function(v) Config.CatchDelay=tonumber(v) or 0.5 end})
local Tog1 = MainSec:Toggle("AutoFish", {Title="Enable Auto Fish", Default=false, Callback=function(v) Config.AutoFish=v end})
local Tog2 = MainSec:Toggle("AutoEquip", {Title="Auto Equip Rod", Default=false, Callback=function(v) Config.AutoEquip=v end})
local Tog3 = MainSec:Toggle("AutoFavorite", {Title="Auto Favorite (Legendary+)", Description="Auto lock rare fish", Default=false, Callback=function(v) Config.AutoFavorite=v end})

table.insert(FishingGroup, Inp1); table.insert(FishingGroup, Inp2); table.insert(FishingGroup, Tog1); table.insert(FishingGroup, Tog2); table.insert(FishingGroup, Tog3)

local SellHeader = MainSec:Button({
    Title = "📂 Auto Sell",
    Description = "Click to Expand",
    Callback = function()
        SellOpen = not SellOpen
        ToggleGroup(SellGroup, SellOpen)
        AnimateLine(SellLine, SellOpen)
        if SellOpen then FishingOpen=false; ToggleGroup(FishingGroup,false); AnimateLine(FishingLine,false) end
    end
})
SellLine = AddActiveLine(SellHeader, PurpleColor)

local Inp3 = MainSec:Input("SellDelay", {Title="Sell Delay (Seconds)", Default="10", Numeric=true, Finished=true, Callback=function(v) Config.SellDelay=tonumber(v) or 10 end})
local Tog4 = MainSec:Toggle("AutoSell", {Title="Enable Auto Sell", Default=false, Callback=function(v) Config.AutoSell=v end})

table.insert(SellGroup, Inp3); table.insert(SellGroup, Tog4)
task.spawn(function() task.wait(0.5); ToggleGroup(FishingGroup, false); ToggleGroup(SellGroup, false) end)

-- === TAB: TRADING ===
local TradeSec = Tabs.Trading:Section("Trade Settings")

local function GetPlayerList()
    local l = {}
    for _,v in pairs(Players:GetPlayers()) do if v~=LocalPlayer then table.insert(l,v.Name) end end
    if #l==0 then table.insert(l, "No Players") end
    return l
end

local PlayerDrop = TradeSec:Dropdown("TradePlayer", {
    Title = "Select Player", Values = GetPlayerList(), Multi = false, Default = 1, Searchable = true,
    Callback = function(v) Config.TradePlayer = v end
})

TradeSec:Button({Title = "Refresh Players", Callback = function() PlayerDrop:SetValues(GetPlayerList()); PlayerDrop:SetValue(nil) end})

local ItemDrop = TradeSec:Dropdown("TradeItem", {
    Title = "Select Item", Values = {"Click Refresh"}, Multi = false, Default = 1, Searchable = true,
    Callback = function(v) if v then Config.TradeItem = string.match(v, "^(.-) %(") or v else Config.TradeItem = nil end end
})

TradeSec:Button({
    Title = "Refresh Inventory", 
    Callback = function() 
        local list = GetInventoryList()
        ItemDrop:SetValues(list); ItemDrop:SetValue(nil) 
        Fluent:Notify({Title="Inventory", Content="Refreshed!", Duration=1})
    end
})

TradeSec:Input("TradeCount", {
    Title = "Trade Amount", Default = "1", Numeric = true, Finished = true,
    Callback = function(v) Config.TradeCount = tonumber(v) or 1 end
})

TradeSec:Toggle("AutoTrade", {
    Title = "Start Trading", Default = false,
    Callback = function(v) Config.AutoTrade = v; if v then PerformAutoTrade() end end
})

-- === TAB: TELEPORT ===
local TeleSec = Tabs.Teleport:Section("Teleport Manager")

local LocationKeys = {}; if LocationCoords then for k,_ in pairs(LocationCoords) do table.insert(LocationKeys,k) end end; table.sort(LocationKeys)
local PlayerGroup, LocationGroup = {}, {}
local PlayerOpen, LocationOpen = false, false
local PlayerLine, LocationLine = nil, nil

local PlayerHeader = TeleSec:Button({Title="📂 Player Teleport", Description="Expand", Callback=function() PlayerOpen=not PlayerOpen; ToggleGroup(PlayerGroup, PlayerOpen); AnimateLine(PlayerLine, PlayerOpen); if PlayerOpen then LocationOpen=false; ToggleGroup(LocationGroup,false); AnimateLine(LocationLine,false) end end})
PlayerLine = AddActiveLine(PlayerHeader, PurpleColor)

local PD = TeleSec:Dropdown("PlayerTarget", {Title="Select Player", Values=GetPlayerList(), Multi=false, Default=1, Searchable=true})
local RB = TeleSec:Button({Title="Refresh", Callback=function() PD:SetValues(GetPlayerList()); PD:SetValue(nil) end})
local TPB = TeleSec:Button({Title="Teleport Now", Callback=function() local t=Players:FindFirstChild(PD.Value); if t and t.Character then LocalPlayer.Character.HumanoidRootPart.CFrame=t.Character.HumanoidRootPart.CFrame end end})
table.insert(PlayerGroup, PD); table.insert(PlayerGroup, RB); table.insert(PlayerGroup, TPB)

local LocationHeader = TeleSec:Button({Title="📂 Location Teleport", Description="Expand", Callback=function() LocationOpen=not LocationOpen; ToggleGroup(LocationGroup, LocationOpen); AnimateLine(LocationLine, LocationOpen); if LocationOpen then PlayerOpen=false; ToggleGroup(PlayerGroup,false); AnimateLine(PlayerLine,false) end end})
LocationLine = AddActiveLine(LocationHeader, PurpleColor)

local LD = TeleSec:Dropdown("LocTarget", {Title="Select Location", Values=LocationKeys, Multi=false, Default=1, Searchable=true})
local TLB = TeleSec:Button({Title="Teleport Now", Callback=function() local t=LocationCoords[LD.Value]; if t then LocalPlayer.Character.HumanoidRootPart.CFrame=CFrame.new(t) end end})
table.insert(LocationGroup, LD); table.insert(LocationGroup, TLB)

task.spawn(function() task.wait(0.5); ToggleGroup(PlayerGroup, false); ToggleGroup(LocationGroup, false) end)

-- === TAB: MERCHANT ===
local ShopSec = Tabs.Merchant:Section("Shop")
local RodList = {}; if ShopData.Rods then for k,_ in pairs(ShopData.Rods) do table.insert(RodList, k) end end; table.sort(RodList)
ShopSec:Dropdown("RodSelect", {Title="Select Rod", Values=RodList, Multi=false, Default=1, Searchable=true, Callback=function(v) if ShopData.Rods then SelectedRod=ShopData.Rods[v] end end})
ShopSec:Button({Title="Buy Rod", Callback=function() if SelectedRod and NetworkLoaded then Events.buyRod:InvokeServer(SelectedRod) end end})

local BaitList = {}; if ShopData.Baits then for k,_ in pairs(ShopData.Baits) do table.insert(BaitList, k) end end; table.sort(BaitList)
ShopSec:Dropdown("BaitSelect", {Title="Select Bait", Values=BaitList, Multi=false, Default=1, Searchable=true, Callback=function(v) if ShopData.Baits then SelectedBait=ShopData.Baits[v] end end})
ShopSec:Button({Title="Buy Bait", Callback=function() if SelectedBait and NetworkLoaded then Events.buyBait:InvokeServer(SelectedBait) end end})

-- === TAB: WEBHOOK ===
local WebhookSec = Tabs.Webhook:Section("Webhook Settings")
local DiscGroup, TeleGroup = {}, {}
local DiscOpen, TeleOpen = false, false
local DiscLine, TeleLine = nil, nil

local DiscHeader = WebhookSec:Button({Title="📂 Discord", Description="Expand", Callback=function() DiscOpen=not DiscOpen; ToggleGroup(DiscGroup, DiscOpen); AnimateLine(DiscLine, DiscOpen); if DiscOpen then TeleOpen=false; ToggleGroup(TeleGroup,false); AnimateLine(TeleLine,false) end end})
DiscLine = AddActiveLine(DiscHeader, PurpleColor)
local D1 = WebhookSec:Input("DiscordUrl", {Title="Webhook URL", Default="", Callback=function(v) Config.DiscordUrl=v end})
local D2 = WebhookSec:Input("DiscordID", {Title="User ID", Default="", Callback=function(v) Config.DiscordID=v end})
local D3 = WebhookSec:Toggle("WebhookDiscord", {Title="Enable", Default=false, Callback=function(v) Config.WebhookDiscord=v end})
local TierList = {"1 - Common", "2 - Uncommon", "3 - Rare", "4 - Epic", "5 - Legendary", "6 - Mythic", "7 - Secret"}
local D4 = WebhookSec:Dropdown("MinTier", {Title="Min Rarity", Values=TierList, Multi=false, Default=1, Searchable=true, Callback=function(v) Config.WebhookMinTier=tonumber(string.sub(v,1,1)) end})
local D5 = WebhookSec:Button({Title="Test", Callback=function() if Config.DiscordUrl~="" then SendWebhook(Config.DiscordUrl, {content="Test", embeds={{title="Gamen X", description="OK!", color=65280}}}) end end})
table.insert(DiscGroup, D1); table.insert(DiscGroup, D2); table.insert(DiscGroup, D3); table.insert(DiscGroup, D4); table.insert(DiscGroup, D5)

local TeleHeader = WebhookSec:Button({Title="📂 Telegram", Description="Expand", Callback=function() TeleOpen=not TeleOpen; ToggleGroup(TeleGroup, TeleOpen); AnimateLine(TeleLine, TeleOpen); if TeleOpen then DiscOpen=false; ToggleGroup(DiscGroup,false); AnimateLine(DiscLine,false) end end})
TeleLine = AddActiveLine(TeleHeader, PurpleColor)
local T1 = WebhookSec:Input("TeleToken", {Title="Bot Token", Default="", Callback=function(v) Config.TelegramToken=v end})
local T2 = WebhookSec:Input("TeleChatID", {Title="Chat ID", Default="", Callback=function(v) Config.TelegramChatID=v end})
local T3 = WebhookSec:Input("TeleUserID", {Title="User ID", Default="", Callback=function(v) Config.TelegramUserID=v end})
local T4 = WebhookSec:Toggle("WebhookTelegram", {Title="Enable", Default=false, Callback=function(v) Config.WebhookTelegram=v end})
local T5 = WebhookSec:Button({Title="Test", Callback=function() if Config.TelegramToken~="" then SendWebhook("https://api.telegram.org/bot"..Config.TelegramToken.."/sendMessage", {chat_id=Config.TelegramChatID, text="Gamen X OK!"}) end end})
table.insert(TeleGroup, T1); table.insert(TeleGroup, T2); table.insert(TeleGroup, T3); table.insert(TeleGroup, T4); table.insert(TeleGroup, T5)
task.spawn(function() task.wait(0.5); ToggleGroup(DiscGroup, false); ToggleGroup(TeleGroup, false) end)

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
