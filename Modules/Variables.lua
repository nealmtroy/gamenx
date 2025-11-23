-- Gamen X | Variables Module
-- Berisi Database, Koordinat, dan Konfigurasi Default
-- File ini harus dimuat SEBELUM Core Script

local Variables = {}

-- 1. KONFIGURASI DEFAULT
Variables.Config = {
    -- Automation
    AutoFish = false,
    LegitMode = false,
    AutoShake = false,
    AutoEquip = false,
    AutoSell = false,
    
    -- Timings (Detik)
    FishDelay = 2.0, 
    CatchDelay = 0.5,
    SellDelay = 10,
    ShakeDelay = 0.1,
    
    -- Webhook
    DiscordUrl = "",
    TelegramToken = "",
    TelegramChatID = "",
    WebhookFish = false -- Fitur Baru: Notifikasi Ikan
}

-- 2. DATABASE SHOP (ID Item)
Variables.ShopData = {
    Rods = {
        ["Carbon Rod"] = 76,
        ["Grass Rod"] = 85,
        ["Demascus Rod"] = 77,
        ["Ice Rod"] = 78
    },
    Baits = {
        ["Luck Bait"] = 2,
        ["Midnight Bait"] = 3
    }
}

-- 3. DATABASE LOKASI (Koordinat Teleport)
Variables.LocationCoords = {
    ["Fisherman Island Right"] = Vector3.new(93, 17, 2832),
    ["Fisherman Island Left"] = Vector3.new(-27, 17, 2829),
    ["Crater Island Ground"] = Vector3.new(970, 2, 5021),
    ["Crater Island Top"] = Vector3.new(1012, 22, 5077),
    ["Crater Island Pohon"] = Vector3.new(990, 20, 5059),
    ["Esoteric Depth"] = Vector3.new(3209, -1303, 1405),
    ["Enchant Eso"] = Vector3.new(3247, -1301, 1393),
    ["Ancient Jungle"] = Vector3.new(1269, 7, -182),
    ["Ancient Jungle Kolam Kecil"] = Vector3.new(1473, 4, -333),
    ["Ancient Jungle Jembatan"] = Vector3.new(1481, 7, -431),
    ["Sacred Tample"] = Vector3.new(1476, -22, -632),
    ["Crystalline Passage"] = Vector3.new(6050, -539, 4376),
    ["Ancient Ruin"] = Vector3.new(6086, -586, 4638),
    ["Kohana"] = Vector3.new(-606, 19, 428),
    ["Kohana Volcano"] = Vector3.new(-562, 21, 158),
    ["Kohana Volcano Lava Quest"] = Vector3.new(-593, 59, 125),
    ["Weather Machine"] = Vector3.new(-1581, 13, 1920),
    ["Coral Reefs Spot 1"] = Vector3.new(-3033, 2, 2276),
    ["Coral Reefs Spot 2"] = Vector3.new(-3274, 2, 2227),
    ["Coral Reefs Spot 3"] = Vector3.new(-3137, 2, 2124),
    ["Sisyphus Statue"] = Vector3.new(-3659, -135, -962),
    ["Treasure Room"] = Vector3.new(-3598, -276, -1643),
    ["Tropical Grove"] = Vector3.new(-2165, 53, 3663)
}

-- Mengembalikan tabel agar bisa dibaca oleh Core
return Variables
