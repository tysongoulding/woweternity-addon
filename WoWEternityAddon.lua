-- ============================================================================
-- WoW Eternity Addon (WEA) - /wea
-- WoW Eternity Client BiS Tooltip Sync, Cadberry Guide & In-Game Character Exporter
-- Version: 1.2.0 (Interface: 16001 - Build 1.60.1.70170)
-- ============================================================================

local ADDON_NAME = "WoW Eternity Addon"
local SOUND_ID = 888
local SOUND_DEBOUNCE_INTERVAL = 2.0

-- Root addon namespace
local WoWEternityAddon = {
    name = "WoW Eternity Addon",
    version = "1.2.0",
    build = "1.60.1.70170",
    interfaceVersion = 16001,
    lastSoundPlayedTime = 0,
    isCorrupted = false,
    debounceInterval = SOUND_DEBOUNCE_INTERVAL,
    mainFrame = nil,
    minimapButton = nil,
    unitIlvlCache = {},
    lastInspectTime = 0,
    pendingInspectGuid = nil,
    pendingInspectUnit = nil,
}

_G.WoWEternityAddon = WoWEternityAddon

-- ============================================================================
-- Client Compatibility Patch (WoW Forever Beta 1.60.1.70170 / Camelot Beta)
-- Fixes Blizzard bug where Blizzard_GroupFinder_VanillaStyle crashes on UI
-- reload during LFGBrowseFrame OnLoad because LFGParentFrame_SetTab indexes
-- LFGWhoListFrame before Blizzard_LFGVanilla_WhoList.xml has finished loading.
-- ============================================================================
if not rawget(_G, "LFGWhoListFrame") and CreateFrame then
    pcall(function()
        local stub = CreateFrame("Frame", "LFGWhoListFrame")
        if stub then stub:Hide() end
    end)
end

-- Inventory Slot Mapping
local INVENTORY_SLOTS = {
    { id = 1, name = "Head" },
    { id = 2, name = "Neck" },
    { id = 3, name = "Shoulder" },
    { id = 4, name = "Shirt" },
    { id = 5, name = "Chest" },
    { id = 6, name = "Waist" },
    { id = 7, name = "Legs" },
    { id = 8, name = "Feet" },
    { id = 9, name = "Wrist" },
    { id = 10, name = "Hands" },
    { id = 11, name = "Finger1" },
    { id = 12, name = "Finger2" },
    { id = 13, name = "Trinket1" },
    { id = 14, name = "Trinket2" },
    { id = 15, name = "Back" },
    { id = 16, name = "MainHand" },
    { id = 17, name = "OffHand" },
    { id = 18, name = "Ranged" },
    { id = 19, name = "Tabard" },
}

local CLASS_TALENT_TREES = {
    ["PALADIN"] = {
        { name = "Holy", texture = "spell_holy_holybolt" },
        { name = "Protection", texture = "spell_holy_devotionaura" },
        { name = "Retribution", texture = "spell_holy_auraoflight" },
    },
    ["WARRIOR"] = {
        { name = "Arms", texture = "ability_rogue_eviscerate" },
        { name = "Fury", texture = "ability_warrior_innerrage" },
        { name = "Protection", texture = "inv_shield_06" },
    },
    ["HUNTER"] = {
        { name = "Beast Mastery", texture = "ability_hunter_beasttaming" },
        { name = "Marksmanship", texture = "ability_marksmanship" },
        { name = "Survival", texture = "ability_hunter_swiftstrike" },
    },
    ["ROGUE"] = {
        { name = "Assassination", texture = "ability_rogue_eviscerate" },
        { name = "Combat", texture = "ability_backstab" },
        { name = "Subtlety", texture = "ability_stealth" },
    },
    ["PRIEST"] = {
        { name = "Discipline", texture = "spell_holy_wordfortitude" },
        { name = "Holy", texture = "spell_holy_guardianspirit" },
        { name = "Shadow", texture = "spell_shadow_shadowwordpain" },
    },
    ["SHAMAN"] = {
        { name = "Elemental", texture = "spell_nature_lightning" },
        { name = "Enhancement", texture = "spell_nature_lightningshield" },
        { name = "Restoration", texture = "spell_nature_magicimmunity" },
    },
    ["MAGE"] = {
        { name = "Arcane", texture = "spell_holy_magicalsentry" },
        { name = "Fire", texture = "spell_fire_firebolt02" },
        { name = "Frost", texture = "spell_frost_frostbolt02" },
    },
    ["WARLOCK"] = {
        { name = "Affliction", texture = "spell_shadow_deathcoil" },
        { name = "Demonology", texture = "spell_shadow_metamorphosis" },
        { name = "Destruction", texture = "spell_shadow_rainoffire" },
    },
    ["DRUID"] = {
        { name = "Balance", texture = "spell_nature_starfall" },
        { name = "Feral Combat", texture = "ability_racial_bearform" },
        { name = "Restoration", texture = "spell_nature_healingtouch" },
    },
}

local TALENT_TREE_CLASSIFIER = {
    ["PALADIN"] = {
        [1] = { "divine strength", "divine intellect", "spiritual focus", "righteousness", "healing light", "consecration", "illumination", "lay on hands", "blessing of wisdom", "wisdom", "divine favor", "holy power", "holy shock", "beacon of light", "infusion of light", "pure of heart", "purifying power", "blessed life", "judgements of the pure", "aura mastery", "blessed hands", "light's grace", "holy guidance", "sacred cleansing", "unyielding faith", "sanctified light" },
        [2] = { "redoubt", "precision", "toughness", "devotion aura", "shield specialization", "anticipation", "blessing of kings", "kings", "righteous fury", "shield of the righteous", "holy shield", "reckoning", "one-handed", "ardent defender", "avenger's shield", "hammer of the righteous", "touched by the light", "guarded by the light", "combat expertise", "sacred duty", "spell warding", "guardian's favor", "hammer of justice", "concentration aura", "sanctuary", "blessing of sanctuary" },
        [3] = { "blessing of might", "might", "benediction", "judgement", "crusader", "deflection", "conviction", "seal of command", "pursuit of justice", "eye for an eye", "retribution aura", "crusade", "two-handed", "sanctity", "vengeance", "repentance", "fanaticism", "crusader strike", "sheath of light", "art of war", "righteous vengeance", "swift retribution", "judgements of the wise", "vindication" },
    },
    ["WARRIOR"] = {
        [1] = { "arms", "rend", "deflection", "tactical mastery", "overpower", "deep wounds", "two-handed", "impale", "poleaxe", "mace", "sword", "sweeping strikes", "mortal strike", "second wind", "blood frenzy", "bladestorm", "sudden death", "wrecking crew", "anger management" },
        [2] = { "fury", "booming voice", "cruelty", "demoralizing", "unbridled", "piercing howl", "blood craze", "commanding", "enrage", "flurry", "death wish", "bloodthirst", "rampage", "titans grip", "titan's grip", "furious attacks", "heroic fury", "dual wield" },
        [3] = { "protection", "shield specialization", "anticipation", "toughness", "iron will", "bloodrage", "last stand", "defiance", "one-handed", "shield slam", "devastate", "shockwave", "vitality", "damage shield", "warbringer", "critical block", "concussion blow", "shield block" },
    },
    ["ROGUE"] = {
        [1] = { "assassination", "eviscerate", "remorseless", "malice", "ruthlessness", "murder", "puncturing", "relentless", "lethality", "vile poisons", "cold blood", "seal fate", "vigor", "deadened nerves", "quick recovery", "mutilate", "hunger for blood" },
        [2] = { "combat", "gouge", "sinister strike", "lightning reflexes", "deflection", "precision", "riposte", "dual wield", "blade flurry", "sword specialization", "mace specialization", "weapon expertise", "adrenaline rush", "combat potency", "killing spree" },
        [3] = { "subtlety", "master of deception", "opportunity", "sleight of hand", "initiative", "ghostly strike", "camouflage", "elusiveness", "serrated blades", "setup", "hemorrhage", "preparation", "dirty deeds", "premeditation", "cheat death", "shadowstep", "shadow dance" },
    },
    ["HUNTER"] = {
        [1] = { "beast", "aspect", "hawk", "monkey", "thick hide", "revive pet", "pathfinding", "frenzy", "bestial wrath", "the beast within", "intimidation", "spirit bond", "endurance training", "unleashed fury" },
        [2] = { "marksmanship", "concussive", "hunters mark", "hunter's mark", "lethal shots", "efficiency", "aimed shot", "mortal shots", "barrage", "trueshot aura", "silencing shot", "chimera shot" },
        [3] = { "survival", "monster slaying", "humanoid slaying", "deflection", "entrapment", "surefooted", "survivalist", "killer instinct", "counterattack", "wyvern sting", "explosive shot", "black arrow" },
    },
    ["MAGE"] = {
        [1] = { "arcane", "subtlety", "focus", "clearcasting", "concentration", "impact", "meditation", "presence of mind", "arcane mind", "arcane power", "arcane barrage", "slow", "wand" },
        [2] = { "fire", "improved fireball", "fireball", "ignite", "flame throwing", "pyroblast", "burning wish", "critical mass", "blast wave", "combustion", "living bomb" },
        [3] = { "frost", "frostbite", "ice shards", "shatter", "ice block", "ice barrier", "deep freeze", "fingers of frost", "brain freeze", "cold snap", "piercing ice", "permafrost" },
    },
    ["PRIEST"] = {
        [1] = { "discipline", "unbreakable will", "wand", "silent resolve", "inner focus", "meditation", "mental agility", "divine spirit", "power infusion", "pain suppression", "penance" },
        [2] = { "holy", "healing focus", "renew", "holy specialization", "divine fury", "holy nova", "blessed recovery", "inspiration", "spirit of redemption", "lightwell", "circle of healing", "guardian spirit" },
        [3] = { "shadow", "spirit tap", "blackout", "shadow affinity", "shadow focus", "shadow reach", "shadowform", "vampiric embrace", "mind flay", "silence", "vampiric touch", "dispersion" },
    },
    ["WARLOCK"] = {
        [1] = { "affliction", "corruption", "drain soul", "curse of agony", "suppression", "amplify curse", "life tap", "siphon life", "shadow mastery", "dark pact", "unstable affliction", "haunt" },
        [2] = { "demonology", "healthstone", "imp", "stamina", "demonic embrace", "fel stamina", "fel intellect", "fel domination", "master summoner", "soul link", "demonic pact", "metamorphosis" },
        [3] = { "destruction", "shadow bolt", "cataclysm", "bane", "aftermath", "devastation", "shadowburn", "searing pain", "ruin", "conflagrate", "chaos bolt", "shadowfury" },
    },
    ["DRUID"] = {
        [1] = { "balance", "wrath", "moonfire", "nature's grasp", "starlight wrath", "celestial focus", "vengeance", "moonkin form", "starfall", "eclipse", "typhoon", "force of nature" },
        [2] = { "feral", "ferocity", "thick hide", "brutal impact", "feral swiftness", "feral charge", "sharpened claws", "predatory strikes", "primal fury", "leader of the pack", "survival instincts", "mangle", "berserk", "king of the jungle" },
        [3] = { "restoration", "mark of the wild", "furor", "naturalist", "nature's focus", "subtlety", "omen of clarity", "tranquility", "swiftmend", "tree of life", "wild growth", "living seed" },
    },
    ["SHAMAN"] = {
        [1] = { "elemental", "concussion", "convection", "call of flame", "elemental focus", "reverberation", "call of thunder", "elemental mastery", "lightning mastery", "thunderstorm", "lava burst" },
        [2] = { "enhancement", "shield specialization", "thundering strikes", "flurry", "spirit weapons", "dual wield", "stormstrike", "shamanistic rage", "feral spirit", "maelstrom weapon" },
        [3] = { "restoration", "tidal focus", "healing focus", "tidal mastery", "nature's swiftness", "purification", "mana tide", "chain heal", "riptide", "earth shield" },
    },
}

-- ============================================================================
-- Helper Utilities & Adler-32 Checksum Engine (RFC 1950)
-- ============================================================================

function WoWEternityAddon:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    elseif print then
        print(msg)
    end
end

function WoWEternityAddon:ComputeAdler32(data)
    if not data or data == "" then
        return 1
    end

    local a = 1
    local b = 0
    local MOD_ADLER = 65521
    local len = string.len(data)

    for i = 1, len do
        local byte = string.byte(data, i)
        a = (a + byte) % MOD_ADLER
        b = (b + a) % MOD_ADLER
    end

    return (b * 65536) + a
end

-- ============================================================================
-- Cryptographic HMAC-SHA256 & Anti-Tamper Engine (RFC 6234 / RFC 2104)
-- ============================================================================

local _bit = _G.bit
if not _bit then
    pcall(function() _bit = require("bit") end)
end
if not _bit then
    local has_native, ops = pcall(loadstring or load, [[
        return {
            band = function(a, b) return (a & b) & 0xFFFFFFFF end,
            bor = function(a, b) return (a | b) & 0xFFFFFFFF end,
            bxor = function(a, b) return (a ~ b) & 0xFFFFFFFF end,
            bnot = function(a) return (~a) & 0xFFFFFFFF end,
            rshift = function(a, n) return ((a & 0xFFFFFFFF) >> n) & 0xFFFFFFFF end,
            lshift = function(a, n) return (a << n) & 0xFFFFFFFF end,
            ror = function(a, n)
                a = a & 0xFFFFFFFF
                return ((a >> n) | (a << (32 - n))) & 0xFFFFFFFF
            end,
        }
    ]])
    if has_native and ops then
        _bit = ops()
    end
end
if not _bit then
    local function band(a, b)
        local res, p = 0, 1
        a, b = a % 4294967296, b % 4294967296
        while a > 0 and b > 0 do
            local ra, rb = a % 2, b % 2
            if ra == 1 and rb == 1 then res = res + p end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            p = p * 2
        end
        return res
    end
    local function bor(a, b)
        local res, p = 0, 1
        a, b = a % 4294967296, b % 4294967296
        while a > 0 or b > 0 do
            local ra, rb = a % 2, b % 2
            if ra == 1 or rb == 1 then res = res + p end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            p = p * 2
        end
        return res
    end
    local function bxor(a, b)
        local res, p = 0, 1
        a, b = a % 4294967296, b % 4294967296
        while a > 0 or b > 0 do
            local ra, rb = a % 2, b % 2
            if (ra == 1 and rb == 0) or (ra == 0 and rb == 1) then res = res + p end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            p = p * 2
        end
        return res
    end
    local function bnot(a)
        return (4294967295 - (a % 4294967296))
    end
    local function rshift(a, n)
        return math.floor((a % 4294967296) / (2 ^ n))
    end
    local function lshift(a, n)
        return (math.floor(a % 4294967296) * (2 ^ n)) % 4294967296
    end
    local function ror(a, n)
        a = a % 4294967296
        local right = math.floor(a / (2 ^ n))
        local left = (a % (2 ^ n)) * (2 ^ (32 - n))
        return (right + left) % 4294967296
    end
    _bit = { band = band, bor = bor, bxor = bxor, bnot = bnot, rshift = rshift, lshift = lshift, ror = ror }
end

local SHA256_K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

function WoWEternityAddon:ComputeSHA256Raw(msg)
    if not _bit then return "" end
    local band, bor, bxor, bnot = _bit.band, _bit.bor, _bit.bxor, _bit.bnot
    local rshift, lshift, ror = _bit.rshift, _bit.lshift, _bit.ror

    local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

    msg = msg or ""
    local len = #msg
    local bit_len = len * 8
    local pad = msg .. string.char(0x80)
    local rem = (#pad) % 64
    local pad_zeros = (56 - rem) % 64
    pad = pad .. string.rep(string.char(0), pad_zeros)

    local high_len = math.floor(bit_len / 4294967296)
    local low_len = bit_len % 4294967296
    local len_bytes = string.char(
        rshift(high_len, 24) % 256, rshift(high_len, 16) % 256, rshift(high_len, 8) % 256, high_len % 256,
        rshift(low_len, 24) % 256, rshift(low_len, 16) % 256, rshift(low_len, 8) % 256, low_len % 256
    )
    pad = pad .. len_bytes

    local w = {}
    for i = 1, #pad, 64 do
        for j = 1, 16 do
            local off = i + (j - 1) * 4
            local b1, b2, b3, b4 = string.byte(pad, off, off + 3)
            w[j] = bor(lshift(b1, 24), bor(lshift(b2, 16), bor(lshift(b3, 8), b4)))
        end
        for j = 17, 64 do
            local s0 = bxor(ror(w[j - 15], 7), bxor(ror(w[j - 15], 18), rshift(w[j - 15], 3)))
            local s1 = bxor(ror(w[j - 2], 17), bxor(ror(w[j - 2], 19), rshift(w[j - 2], 10)))
            w[j] = (w[j - 16] + s0 + w[j - 7] + s1) % 4294967296
        end

        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
        for j = 1, 64 do
            local S1 = bxor(ror(e, 6), bxor(ror(e, 11), ror(e, 25)))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = (h + S1 + ch + SHA256_K[j] + w[j]) % 4294967296
            local S0 = bxor(ror(a, 2), bxor(ror(a, 13), ror(a, 22)))
            local maj = bxor(band(a, b), bxor(band(a, c), band(b, c)))
            local temp2 = (S0 + maj) % 4294967296

            h = g
            g = f
            f = e
            e = (d + temp1) % 4294967296
            d = c
            c = b
            b = a
            a = (temp1 + temp2) % 4294967296
        end

        h0 = (h0 + a) % 4294967296
        h1 = (h1 + b) % 4294967296
        h2 = (h2 + c) % 4294967296
        h3 = (h3 + d) % 4294967296
        h4 = (h4 + e) % 4294967296
        h5 = (h5 + f) % 4294967296
        h6 = (h6 + g) % 4294967296
        h7 = (h7 + h) % 4294967296
    end

    local words = { h0, h1, h2, h3, h4, h5, h6, h7 }
    local raw = {}
    for _, val in ipairs(words) do
        table.insert(raw, string.char(
            rshift(val, 24) % 256,
            rshift(val, 16) % 256,
            rshift(val, 8) % 256,
            val % 256
        ))
    end
    return table.concat(raw)
end

function WoWEternityAddon:ComputeSHA256Hex(msg)
    local raw = self:ComputeSHA256Raw(msg)
    local hex = {}
    for i = 1, #raw do
        table.insert(hex, string.format('%02x', string.byte(raw, i)))
    end
    return table.concat(hex)
end

function WoWEternityAddon:ComputeHMACSHA256(key, data)
    if not _bit then return "" end
    local bxor = _bit.bxor
    key = key or ""
    data = data or ""

    if #key > 64 then
        key = self:ComputeSHA256Raw(key)
    end
    if #key < 64 then
        key = key .. string.rep(string.char(0), 64 - #key)
    end

    local o_key_pad = {}
    local i_key_pad = {}
    for i = 1, 64 do
        local kb = string.byte(key, i)
        table.insert(o_key_pad, string.char(bxor(kb, 0x5c)))
        table.insert(i_key_pad, string.char(bxor(kb, 0x36)))
    end

    local inner = self:ComputeSHA256Raw(table.concat(i_key_pad) .. data)
    local outer = self:ComputeSHA256Raw(table.concat(o_key_pad) .. inner)

    local hex = {}
    for i = 1, #outer do
        table.insert(hex, string.format('%02x', string.byte(outer, i)))
    end
    return table.concat(hex)
end

local DEFAULT_PLAYER_SIGNING_KEY = "woweternity-anti-tamper-v1-key"

function WoWEternityAddon:CanonicalPlayerString(name, realm, raid_progress, parse_ranking, timestamp)
    name = (name or ""):gsub("^%s*(.-)%s*$", "%1"):lower()
    realm = (realm or ""):gsub("^%s*(.-)%s*$", "%1"):lower()
    raid_progress = (raid_progress or ""):gsub("^%s*(.-)%s*$", "%1")
    local rank = tonumber(parse_ranking) or 0.0
    local ts = tonumber(timestamp) or 0
    return string.format("%s:%s:%s:%.1f:%d", name, realm, raid_progress, rank, ts)
end

function WoWEternityAddon:VerifyPlayerSignature(player)
    if type(player) ~= "table" then
        return false, "invalid_table"
    end

    local sig = player.sig
    if not sig or sig == "" then
        return false, "unsigned"
    end

    local canonical = self:CanonicalPlayerString(
        player.name,
        player.realm,
        player.raid_progress,
        player.parse_ranking,
        player.timestamp
    )
    local expected = self:ComputeHMACSHA256(DEFAULT_PLAYER_SIGNING_KEY, canonical)

    if sig:lower() == expected:lower() then
        return true, "verified"
    else
        return false, "tampered"
    end
end

function WoWEternityAddon:VerifyAllPlayersIntegrity()
    if not WoWEternityAddonDB or not WoWEternityAddonDB.players then
        return 0, 0, 0
    end
    local verifiedCount = 0
    local tamperedCount = 0
    local unsignedCount = 0
    for _, p in ipairs(WoWEternityAddonDB.players) do
        local ok, reason = self:VerifyPlayerSignature(p)
        if ok then
            verifiedCount = verifiedCount + 1
        elseif reason == "tampered" then
            tamperedCount = tamperedCount + 1
        else
            unsignedCount = unsignedCount + 1
        end
    end
    return verifiedCount, tamperedCount, unsignedCount
end

function WoWEternityAddon:ToJson(val)
    local t = type(val)
    if t == "string" then
        return string.format("%q", val):gsub("\n", "\\n"):gsub("\r", "")
    elseif t == "number" then
        return tostring(val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "table" then
        local isArray = true
        local maxIndex = 0
        local count = 0
        for k, _ in pairs(val) do
            count = count + 1
            if type(k) == "number" and k > 0 and math.floor(k) == k then
                if k > maxIndex then maxIndex = k end
            else
                isArray = false
            end
        end
        if count == 0 then
            return "{}"
        end
        if isArray and maxIndex == count then
            local parts = {}
            for i = 1, maxIndex do
                table.insert(parts, self:ToJson(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            local sortedKeys = {}
            for k in pairs(val) do
                table.insert(sortedKeys, tostring(k))
            end
            table.sort(sortedKeys)
            for _, k in ipairs(sortedKeys) do
                local v = val[k] or val[tonumber(k)]
                if v ~= nil then
                    table.insert(parts, string.format("%q:%s", k, self:ToJson(v)))
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "null"
    end
end

function WoWEternityAddon:ReconstructItemsBlock(items)
    if not items then return "" end
    local keys = {}
    for itemId in pairs(items) do
        table.insert(keys, itemId)
    end
    table.sort(keys)

    local lines = {}
    for _, itemId in ipairs(keys) do
        local it = items[itemId]
        local isCustom = (it.source_type == "Custom Profile" or it.is_custom == true)
        local itemName = it.name or ("Item " .. itemId)
        local specId = it.spec_id or ""
        local sourceType = it.source_type or "Default"
        table.insert(lines, string.format('    [%d] = { name = "%s", spec_id = "%s", source_type = "%s", is_custom = %s },',
            itemId, itemName, specId, sourceType, isCustom and "true" or "false"))
    end
    return table.concat(lines, "\n")
end

function WoWEternityAddon:VerifyIntegrity()
    if type(WoWEternityAddonDB) ~= "table" then
        return false, 0, 0
    end

    local declaredChecksum = tonumber(WoWEternityAddonDB.checksum) or 0
    if declaredChecksum == 0 then
        return false, 0, 0
    end

    local dataToHash = WoWEternityAddonDB.payload
    if not dataToHash or dataToHash == "" then
        dataToHash = self:ReconstructItemsBlock(WoWEternityAddonDB.items)
    end

    local calculatedChecksum = self:ComputeAdler32(dataToHash)
    local isValid = (calculatedChecksum == declaredChecksum)
    return isValid, calculatedChecksum, declaredChecksum
end

function WoWEternityAddon:GetItemCount()
    if not WoWEternityAddonDB or not WoWEternityAddonDB.items then return 0 end
    local count = 0
    for _ in pairs(WoWEternityAddonDB.items) do
        count = count + 1
    end
    return count
end

function WoWEternityAddon:PlayBiSSound()
    if WoWEternityAddonDB and WoWEternityAddonDB.playBiSSound == false then return false end
    local now = (GetTime and GetTime()) or 0
    local interval = self.debounceInterval or SOUND_DEBOUNCE_INTERVAL
    if (now - self.lastSoundPlayedTime) >= interval or self.lastSoundPlayedTime == 0 then
        if PlaySound then
            pcall(PlaySound, SOUND_ID)
        end
        self.lastSoundPlayedTime = now
        return true
    end
    return false
end

-- ============================================================================
-- Character Inspection & Exporter Engine
-- ============================================================================

local function SafeCall(fn, ...)
    if not fn then return 0 end
    local ok, val = pcall(fn, ...)
    if ok and val ~= nil then return val end
    return 0
end

function WoWEternityAddon:GetItemInfoSafe(linkOrId, slotId)
    local itemName = nil
    local itemQuality = nil
    local itemLevel = 0
    local itemType = ""
    local itemSubType = ""
    local itemEquipLoc = ""
    local itemTexture = ""

    local itemId = 0
    local enchantId = 0

    if type(linkOrId) == "string" then
        local id, ench = linkOrId:match("item:(%d+):?(%d*)")
        itemId = tonumber(id) or 0
        enchantId = tonumber(ench) or 0
    elseif type(linkOrId) == "number" then
        itemId = linkOrId
    end

    if itemId == 0 and slotId and GetInventoryItemID then
        pcall(function()
            itemId = GetInventoryItemID("player", slotId) or 0
        end)
    end

    -- 1. Try C_Item.GetItemInfo or _G.GetItemInfo
    local infoFn = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if infoFn then
        pcall(function()
            local target = linkOrId or itemId
            if target and target ~= 0 then
                local name, link, quality, ilvl, reqLevel, itype, isubtype, maxStack, equipLoc, texture = infoFn(target)
                if name then
                    itemName = name
                    itemQuality = quality
                    itemLevel = ilvl or 0
                    itemType = itype or ""
                    itemSubType = isubtype or ""
                    itemEquipLoc = equipLoc or ""
                    itemTexture = texture or ""
                end
            end
        end)
    end

    -- 2. Try C_Item.GetItemInfoInstant for metadata & texture
    if C_Item and C_Item.GetItemInfoInstant and itemId > 0 then
        pcall(function()
            local id, itype, isubtype, equipLoc, icon = C_Item.GetItemInfoInstant(itemId)
            if id then
                if not itemTexture or itemTexture == "" then itemTexture = icon or "" end
                if itemType == "" then itemType = itype or "" end
                if itemSubType == "" then itemSubType = isubtype or "" end
                if itemEquipLoc == "" then itemEquipLoc = equipLoc or "" end
            end
        end)
    end

    -- 3. Fallback: get texture directly from equipped inventory slot
    if (not itemTexture or itemTexture == "") and slotId and GetInventoryItemTexture then
        pcall(function()
            itemTexture = GetInventoryItemTexture("player", slotId) or ""
        end)
    end

    -- 4. Fallback: get detailed item level
    if itemLevel == 0 and linkOrId and GetDetailedItemLevelInfo then
        pcall(function()
            local lvl = GetDetailedItemLevelInfo(linkOrId)
            if lvl and lvl > 0 then itemLevel = lvl end
        end)
    end

    -- 5. Fallback: extract item name from link brackets: [Brawler's Harness]
    if (not itemName or itemName == "") and type(linkOrId) == "string" then
        local bracketName = linkOrId:match("%[(.+)%]")
        if bracketName and bracketName ~= "" then
            itemName = bracketName
        end
    end

    -- 6. Fallback: extract item quality from link color code: |cffa335ee
    if (not itemQuality or itemQuality == 0) and type(linkOrId) == "string" then
        local color = linkOrId:match("|cff(%x%x%x%x%x%x)") or linkOrId:match("|cFF(%x%x%x%x%x%x)")
        if color then
            color = color:lower()
            if color == "9d9d9d" then itemQuality = 0
            elseif color == "ffffff" then itemQuality = 1
            elseif color == "1eff00" then itemQuality = 2
            elseif color == "0070dd" then itemQuality = 3
            elseif color == "a335ee" then itemQuality = 4
            elseif color == "ff8000" then itemQuality = 5
            elseif color == "e6cc80" then itemQuality = 7
            end
        end
    end

    if not itemName or itemName == "" then
        itemName = (itemId > 0) and ("Item " .. itemId) or "Unknown Item"
    end

    return itemName,
           itemQuality or 1,
           itemLevel or 0,
           itemType or "",
           itemSubType or "",
           itemEquipLoc or "",
           itemTexture or "",
           itemId,
           enchantId
end

function WoWEternityAddon:ExportCharacter(silent)
    local name = UnitName("player") or "Unknown"
    local realm = (GetRealmName and GetRealmName()) or "Unknown"
    local level = (UnitLevel and UnitLevel("player")) or 60
    local sex = (UnitSex and UnitSex("player")) or 2
    local gender = (sex == 2 and "Male") or (sex == 3 and "Female") or "Unknown"
    local localizedClass, classFileName = UnitClass("player")
    local localizedRace, raceFileName = UnitRace("player")
    local guildName = (GetGuildInfo and GetGuildInfo("player")) or ""

    -- 1. Equipment Extraction (all 19 slots)
    local equipment = {}
    local totalIlvl = 0
    local equippedCount = 0

    for _, slot in ipairs(INVENTORY_SLOTS) do
        local slotId = slot.id
        local slotName = slot.name
        local link = (GetInventoryItemLink and GetInventoryItemLink("player", slotId)) or nil
        local equippedItemId = (GetInventoryItemID and GetInventoryItemID("player", slotId)) or 0

        if (link and link ~= "") or (equippedItemId and equippedItemId > 0) then
            local itemName, itemQuality, itemLevel, itemType, itemSubType, itemEquipLoc, itemTexture, parsedItemId, parsedEnchantId =
                self:GetItemInfoSafe(link or equippedItemId, slotId)

            local runeInfo = nil
            if C_Engraving and C_Engraving.GetEngravingInfoForSlot then
                pcall(function()
                    local eng = C_Engraving.GetEngravingInfoForSlot(slotId)
                    if eng then
                        runeInfo = {
                            spell_id = eng.spellID,
                            name = eng.name,
                            icon = eng.iconTexture,
                        }
                    end
                end)
            end

            local ilvl = itemLevel or 0
            if ilvl > 0 then
                totalIlvl = totalIlvl + ilvl
                equippedCount = equippedCount + 1
            elseif equippedItemId > 0 or (parsedItemId and parsedItemId > 0) then
                equippedCount = equippedCount + 1
            end

            local gems = { 0, 0, 0, 0 }
            local suffixId = 0
            if link and type(link) == "string" then
                local _, _, g1, g2, g3, g4, sfx =
                    link:match("item:%d+:%d*:(%d*):(%d*):(%d*):(%d*):([-%d]*)")
                gems = { tonumber(g1) or 0, tonumber(g2) or 0, tonumber(g3) or 0, tonumber(g4) or 0 }
                suffixId = tonumber(sfx) or 0
            end

            equipment[slotName] = {
                slot_id = slotId,
                slot_name = slotName,
                item_id = parsedItemId or equippedItemId or 0,
                enchant_id = parsedEnchantId or 0,
                gems = gems,
                suffix_id = suffixId,
                item_name = itemName,
                quality = itemQuality or 1,
                item_level = ilvl,
                item_type = itemType or "",
                sub_type = itemSubType or "",
                equip_loc = itemEquipLoc or "",
                texture = itemTexture or "",
                link = link or "",
                rune = runeInfo,
            }
        end
    end

    local avgIlvl = equippedCount > 0 and math.floor((totalIlvl / equippedCount) * 10) / 10 or 0

    -- 2. Talents & Spec Extraction (Universal Multi-Engine: Classic Era / SoD / Camelot / Modern)
    local talentTrees = {}
    local specPoints = {}
    local spentTalents = {}
    local detectedSpecName = nil
    local probeLog = {}

    local function LogProbe(msg)
        table.insert(probeLog, msg)
    end

    pcall(function()
        -- 2A. Attempt to load talent addons across engine flavors
        local loader = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
        if loader then
            pcall(loader, "Blizzard_TalentUI")
            pcall(loader, "Blizzard_PlayerSpells")
            pcall(loader, "Blizzard_ClassTalentUI")
        end

        local activeGroup = 1
        if GetActiveTalentGroup then
            local okG, ag = pcall(GetActiveTalentGroup)
            if okG and ag then activeGroup = ag end
        elseif GetActiveSpecGroup then
            local okG, ag = pcall(GetActiveSpecGroup)
            if okG and ag then activeGroup = ag end
        end
        LogProbe("activeGroup=" .. tostring(activeGroup))

        -- 2B. Method 1: Legacy / Classic 3-Tab Talent API
        local numTabs = 0
        if GetNumTalentTabs then
            local ok, res = pcall(GetNumTalentTabs)
            if ok and type(res) == "number" and res > 0 then
                numTabs = res
            else
                local ok2, res2 = pcall(GetNumTalentTabs, false, false)
                if ok2 and type(res2) == "number" and res2 > 0 then
                    numTabs = res2
                end
            end
        end
        LogProbe("GetNumTalentTabs=" .. tostring(numTabs))

        if numTabs > 0 and GetTalentTabInfo then
            for tabIndex = 1, numTabs do
                local tName, tTexture, tPoints = "", "", 0

                -- Try standard calls across client variations
                local ok, a1, a2, a3, a4, a5 = pcall(GetTalentTabInfo, tabIndex)
                if not ok or not a1 then
                    ok, a1, a2, a3, a4, a5 = pcall(GetTalentTabInfo, tabIndex, false, false, activeGroup)
                end
                if not ok or not a1 then
                    ok, a1, a2, a3, a4, a5 = pcall(GetTalentTabInfo, tabIndex, false, false)
                end

                if ok and a1 then
                    if type(a1) == "string" then
                        -- Classic format: name, texture, pointsSpent, background
                        tName = a1
                        tTexture = a2 or ""
                        tPoints = tonumber(a3) or 0
                    elseif type(a2) == "string" then
                        -- Modern format: id, name, description, icon, pointsSpent
                        tName = a2
                        tTexture = a4 or ""
                        tPoints = tonumber(a5) or 0
                    end
                end

                -- Verify points by iterating individual talents in this tab
                local sumPoints = 0
                if GetNumTalents and GetTalentInfo then
                    local nTal = 0
                    local okN, resN = pcall(GetNumTalents, tabIndex)
                    if not okN or not resN or resN == 0 then
                        okN, resN = pcall(GetNumTalents, tabIndex, false, false)
                    end
                    if not okN or not resN or resN == 0 then
                        okN, resN = pcall(GetNumTalents, tabIndex, false, false, activeGroup)
                    end
                    nTal = (okN and tonumber(resN)) or 0

                    for talentIdx = 1, nTal do
                        local okT, tn, tIcon, tier, col, rank, maxRank = pcall(GetTalentInfo, tabIndex, talentIdx)
                        if not okT or not rank then
                            okT, tn, tIcon, tier, col, rank, maxRank = pcall(GetTalentInfo, tabIndex, talentIdx, false, false, activeGroup)
                        end
                        if not okT or not rank then
                            okT, tn, tIcon, tier, col, rank, maxRank = pcall(GetTalentInfo, tabIndex, talentIdx, false, false)
                        end
                        if okT and rank and tonumber(rank) and tonumber(rank) > 0 then
                            local r = tonumber(rank)
                            sumPoints = sumPoints + r
                            table.insert(spentTalents, {
                                name = tn or ("Talent " .. talentIdx),
                                rank = r,
                                max_rank = tonumber(maxRank) or r,
                                icon = tostring(tIcon or ""),
                                tree_index = tabIndex,
                                tree_name = tName or ("Tree " .. tabIndex),
                                spell_id = 0,
                            })
                        end
                    end
                end

                if sumPoints > tPoints then
                    tPoints = sumPoints
                end

                LogProbe(string.format("Tab%d: %s (%d pts)", tabIndex, tostring(tName), tPoints))

                if tName and tName ~= "" then
                    table.insert(talentTrees, {
                        index = tabIndex,
                        name = tName,
                        texture = tTexture or "",
                        points_spent = tPoints,
                    })
                    table.insert(specPoints, tostring(tPoints))
                end
            end
        end

        -- 2C. Method 2: Modern Dragonflight/War Within C_ClassTalents & C_Traits API
        if #talentTrees == 0 and C_ClassTalents and C_Traits then
            local configID = (C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()) or nil
            LogProbe("C_ClassTalents.configID=" .. tostring(configID))
            if configID and C_Traits.GetConfigInfo then
                local configInfo = C_Traits.GetConfigInfo(configID)
                if configInfo and configInfo.treeIDs then
                    LogProbe("configInfo.trees=" .. tostring(#configInfo.treeIDs))

                    local cKey = (classFileName or "WARRIOR"):upper()
                    local defaultTrees = CLASS_TALENT_TREES[cKey] or {
                        { name = "Tree 1", texture = "" },
                        { name = "Tree 2", texture = "" },
                        { name = "Tree 3", texture = "" },
                    }
                    local treePoints = { 0, 0, 0 }

                    for treeIdx, treeID in ipairs(configInfo.treeIDs) do
                        local treeNodes = C_Traits.GetTreeNodes(treeID) or {}
                        LogProbe(string.format("treeID=%s nodes=%d", tostring(treeID), #treeNodes))

                        for _, nodeID in ipairs(treeNodes) do
                            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                            if nodeInfo and nodeInfo.currentRank and nodeInfo.currentRank > 0 then
                                local rank = nodeInfo.currentRank
                                local maxRank = nodeInfo.maxRanks or rank
                                local spellID = nil
                                local talentName = nil
                                local talentIcon = nil

                                -- Resolve active entry / definition
                                local entryID = nil
                                if nodeInfo.activeEntry then
                                    if type(nodeInfo.activeEntry) == "table" then
                                        entryID = nodeInfo.activeEntry.entryID or nodeInfo.activeEntry.id
                                    elseif type(nodeInfo.activeEntry) == "number" then
                                        entryID = nodeInfo.activeEntry
                                    end
                                end
                                if not entryID and nodeInfo.entryIDs and #nodeInfo.entryIDs > 0 then
                                    entryID = nodeInfo.entryIDs[1]
                                end

                                if entryID and C_Traits.GetEntryInfo then
                                    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                                    if entryInfo and entryInfo.definitionID and C_Traits.GetDefinitionInfo then
                                        local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                                        if defInfo then
                                            spellID = defInfo.spellID
                                            if defInfo.overrideName and defInfo.overrideName ~= "" then
                                                talentName = defInfo.overrideName
                                            end
                                            if defInfo.overrideIcon then
                                                talentIcon = tostring(defInfo.overrideIcon)
                                            end
                                        end
                                    end
                                end

                                if not spellID and nodeInfo.spellID then
                                    spellID = nodeInfo.spellID
                                end

                                if spellID then
                                    if C_Spell and C_Spell.GetSpellInfo then
                                        local sInfo = C_Spell.GetSpellInfo(spellID)
                                        if sInfo then
                                            if not talentName or talentName == "" then talentName = sInfo.name end
                                            if not talentIcon or talentIcon == "" then
                                                talentIcon = tostring(sInfo.iconID or sInfo.originalIconID or "")
                                            end
                                        end
                                    end
                                    if (not talentName or talentName == "") and GetSpellInfo then
                                        local sName, _, sIcon = GetSpellInfo(spellID)
                                        if sName then
                                            talentName = sName
                                            if not talentIcon or talentIcon == "" then talentIcon = tostring(sIcon or "") end
                                        end
                                    end
                                end

                                if not talentName or talentName == "" then
                                    talentName = "Talent #" .. tostring(nodeID)
                                end
                                if not talentIcon or talentIcon == "" then
                                    talentIcon = "inv_misc_questionmark"
                                end

                                -- Classify talent into Tab 1, 2, or 3
                                local assignedTreeIdx = nil

                                -- If multiple trees exist in configInfo, check treeIdx
                                if #configInfo.treeIDs == 3 then
                                    assignedTreeIdx = treeIdx
                                end

                                -- Match by talent keyword classifier
                                if not assignedTreeIdx then
                                    local classClassifier = TALENT_TREE_CLASSIFIER[cKey]
                                    if classClassifier and talentName then
                                        local lowerName = talentName:lower()
                                        for tabIdx = 1, 3 do
                                            local keywords = classClassifier[tabIdx] or {}
                                            for _, kw in ipairs(keywords) do
                                                if string.find(lowerName, kw, 1, true) then
                                                    assignedTreeIdx = tabIdx
                                                    break
                                                end
                                            end
                                            if assignedTreeIdx then break end
                                        end
                                    end
                                end

                                -- Fallback to 1 if unclassified
                                if not assignedTreeIdx or assignedTreeIdx < 1 or assignedTreeIdx > 3 then
                                    assignedTreeIdx = 1
                                end

                                treePoints[assignedTreeIdx] = (treePoints[assignedTreeIdx] or 0) + rank

                                local tTreeName = defaultTrees[assignedTreeIdx] and defaultTrees[assignedTreeIdx].name or ("Tree " .. assignedTreeIdx)

                                table.insert(spentTalents, {
                                    name = talentName,
                                    rank = rank,
                                    max_rank = maxRank,
                                    icon = talentIcon,
                                    tree_index = assignedTreeIdx,
                                    tree_name = tTreeName,
                                    spell_id = spellID or 0,
                                })

                                LogProbe(string.format("Node %d: %s (%d/%d) -> Tree %d [%s] (spell=%s pos=%s,%s)",
                                    nodeID, talentName, rank, maxRank, assignedTreeIdx, tTreeName,
                                    tostring(spellID), tostring(nodeInfo.posX), tostring(nodeInfo.posY)))
                            end
                        end
                    end

                    -- Assemble the 3 canonical talent trees
                    for idx = 1, 3 do
                        local dt = defaultTrees[idx] or { name = "Tree " .. idx, texture = "" }
                        local pts = treePoints[idx] or 0
                        table.insert(talentTrees, {
                            index = idx,
                            name = dt.name,
                            texture = dt.texture,
                            points_spent = pts,
                        })
                        table.insert(specPoints, tostring(pts))
                    end
                end
            end
        end

        -- 2D. Method 3: Specialization Info
        if GetSpecialization and GetSpecializationInfo then
            local specIdx = GetSpecialization()
            LogProbe("GetSpecialization=" .. tostring(specIdx))
            if specIdx and specIdx > 0 then
                local sId, sName = GetSpecializationInfo(specIdx)
                if sName then
                    detectedSpecName = sName
                    LogProbe("SpecInfo=" .. tostring(sName))
                end
            end
        end
    end)

    -- Fallback: if client talent API returned 0 trees, supply default 3 trees for the class
    if #talentTrees == 0 then
        local cKey = (classFileName or "WARRIOR"):upper()
        local defaultTrees = CLASS_TALENT_TREES[cKey]
        if defaultTrees then
            for idx, dt in ipairs(defaultTrees) do
                table.insert(talentTrees, {
                    index = idx,
                    name = dt.name,
                    texture = dt.texture,
                    points_spent = 0,
                })
                table.insert(specPoints, "0")
            end
        end
        LogProbe("Used fallback trees for " .. tostring(cKey))
    end

    local talentString = table.concat(specPoints, "/")
    if talentString == "" then talentString = "0/0/0" end

    -- Primary spec name is the tree with highest points
    local primarySpecName = detectedSpecName or localizedClass or "Specialist"
    local highestPoints = -1
    for _, tree in ipairs(talentTrees) do
        if tree.points_spent > highestPoints and tree.points_spent > 0 then
            highestPoints = tree.points_spent
            primarySpecName = tree.name
        end
    end

    -- 3. Professions Extraction (Primary & Secondary: Cooking, First Aid, Fishing, etc.)
    local professions = {}
    local seenProfessions = {}

    local PRIMARY_PROFESSIONS = {
        ["Alchemy"] = true, ["Blacksmithing"] = true, ["Enchanting"] = true,
        ["Engineering"] = true, ["Herbalism"] = true, ["Leatherworking"] = true,
        ["Mining"] = true, ["Skinning"] = true, ["Tailoring"] = true,
        ["Jewelcrafting"] = true, ["Inscription"] = true,
    }

    local SECONDARY_PROFESSIONS = {
        ["Cooking"] = true, ["First Aid"] = true, ["Fishing"] = true, ["Archaeology"] = true,
    }

    pcall(function()
        -- Expand all collapsed headers so GetSkillLineInfo doesn't skip secondary skills
        local collapsedHeaders = {}
        if GetNumSkillLines and GetSkillLineInfo and ExpandSkillHeader then
            local numInitial = GetNumSkillLines() or 0
            for i = numInitial, 1, -1 do
                local _, isHeader, isExpanded = GetSkillLineInfo(i)
                if isHeader and not isExpanded then
                    table.insert(collapsedHeaders, i)
                    pcall(ExpandSkillHeader, i)
                end
            end
        end

        if GetNumSkillLines and GetSkillLineInfo then
            local numSkills = GetNumSkillLines() or 0
            local currentHeader = ""
            for i = 1, numSkills do
                local skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
                if isHeader then
                    currentHeader = (skillName or ""):lower()
                elseif skillName and skillRank and skillMaxRank and skillMaxRank > 1 then
                    local isSecondary = false
                    local isKnownProf = false

                    if SECONDARY_PROFESSIONS[skillName] or currentHeader:find("secondary") then
                        isSecondary = true
                        isKnownProf = true
                    elseif PRIMARY_PROFESSIONS[skillName] or currentHeader:find("profession") or currentHeader:find("m\195\169tier") then
                        isSecondary = false
                        isKnownProf = true
                    end

                    -- Only insert actual professions, exclude weapon skills / armor proficiencies / languages
                    if isKnownProf and not seenProfessions[skillName] then
                        seenProfessions[skillName] = true
                        table.insert(professions, {
                            name = skillName,
                            rank = skillRank,
                            max_rank = skillMaxRank,
                            is_secondary = isSecondary,
                        })
                    end
                end
            end
        end

        -- In 1.15+ (Dragonflight engine), also supplement from GetProfessions if available
        if GetProfessions and GetProfessionInfo then
            local p1, p2, arch, fish, cook, firstAid = GetProfessions()
            local profIndices = {
                { id = p1, secondary = false },
                { id = p2, secondary = false },
                { id = arch, secondary = true },
                { id = fish, secondary = true },
                { id = cook, secondary = true },
                { id = firstAid, secondary = true },
            }
            for _, item in ipairs(profIndices) do
                if item.id then
                    local pName, _, pRank, pMaxRank = GetProfessionInfo(item.id)
                    if pName and not seenProfessions[pName] then
                        seenProfessions[pName] = true
                        table.insert(professions, {
                            name = pName,
                            rank = pRank or 0,
                            max_rank = pMaxRank or 0,
                            is_secondary = item.secondary,
                        })
                    end
                end
            end
        end

        -- Restore collapsed headers
        if CollapseSkillHeader then
            for _, idx in ipairs(collapsedHeaders) do
                pcall(CollapseSkillHeader, idx)
            end
        end
    end)

    -- 4. Live Combat Stats Extraction (Unbuffed Base + Gear, stripping temporary positive buffs)
    local function GetUnbuffedStat(statIdx)
        if not UnitStat then return 0 end
        local ok, base, stat, posBuff, negBuff = pcall(UnitStat, "player", statIdx)
        if ok and stat then
            local unbuffed = stat - (posBuff or 0)
            return math.max(0, math.floor(unbuffed + 0.5))
        elseif ok and base then
            return base
        end
        return 0
    end

    local function GetUnbuffedAttackPower()
        if not UnitAttackPower then return 0 end
        local ok, base, pos, neg = pcall(UnitAttackPower, "player")
        if ok and base then
            -- base is pure unbuffed attack power from Strength/Agility and equipped gear.
            -- pos is temporary spell buffs (e.g. Blessing of Might +25 AP, Battle Shout).
            -- Returning base strips positive spell buffs for accurate gear planner integration.
            return base
        end
        return 0
    end

    local function GetUnbuffedRangedAttackPower()
        if not UnitRangedAttackPower then return 0 end
        local ok, base, pos, neg = pcall(UnitRangedAttackPower, "player")
        if ok and base then
            return base
        end
        return 0
    end

    local function GetUnbuffedArmor()
        if not UnitArmor then return 0 end
        local ok, base, effectiveArmor, armor, posBuff, negBuff = pcall(UnitArmor, "player")
        if ok and effectiveArmor then
            -- Strip temporary armor buffs (e.g. Devotion Aura, Stoneskin, Elixirs)
            local unbuffed = effectiveArmor - (posBuff or 0)
            return math.max(0, unbuffed)
        elseif ok and base then
            return base
        end
        return 0
    end

    local function GetUnbuffedResistance(schoolIdx)
        if not UnitResistance then return 0 end
        local ok, base, total, posBuff, negBuff = pcall(UnitResistance, "player", schoolIdx)
        if ok and total then
            return math.max(0, total - (posBuff or 0))
        elseif ok and base then
            return base
        end
        return 0
    end

    local resists = {
        holy = GetUnbuffedResistance(0),
        fire = GetUnbuffedResistance(2),
        nature = GetUnbuffedResistance(3),
        frost = GetUnbuffedResistance(4),
        shadow = GetUnbuffedResistance(5),
        arcane = GetUnbuffedResistance(6),
    }

    local maxHealth = SafeCall(UnitHealthMax, "player")
    local maxPower = SafeCall(UnitPowerMax, "player")
    pcall(function()
        if UnitStat then
            local _, _, posStam = UnitStat("player", 3)
            if posStam and posStam > 0 then
                maxHealth = math.max(1, maxHealth - (posStam * 10))
            end
            local _, _, posInt = UnitStat("player", 4)
            if posInt and posInt > 0 then
                maxPower = math.max(0, maxPower - (posInt * 15))
            end
        end
    end)

    local stats = {
        strength = GetUnbuffedStat(1),
        agility = GetUnbuffedStat(2),
        stamina = GetUnbuffedStat(3),
        intellect = GetUnbuffedStat(4),
        spirit = GetUnbuffedStat(5),
        armor = GetUnbuffedArmor(),
        attack_power = GetUnbuffedAttackPower(),
        ranged_attack_power = GetUnbuffedRangedAttackPower(),
        crit_chance = math.floor(SafeCall(GetCritChance) * 100) / 100,
        ranged_crit_chance = math.floor(SafeCall(GetRangedCritChance) * 100) / 100,
        spell_crit_chance = math.floor(SafeCall(GetSpellCritChance, 1) * 100) / 100,
        hit_modifier = SafeCall(GetHitModifier),
        spell_damage = SafeCall(GetSpellBonusDamage, 1),
        healing_power = SafeCall(GetSpellBonusHealing),
        dodge_chance = math.floor(SafeCall(GetDodgeChance) * 100) / 100,
        parry_chance = math.floor(SafeCall(GetParryChance) * 100) / 100,
        block_chance = math.floor(SafeCall(GetBlockChance) * 100) / 100,
        resists = resists,
        max_health = maxHealth,
        max_power = maxPower,
        power_type = SafeCall(UnitPowerType, "player"),
        is_unbuffed = true,
    }

    -- 5. Legacy & PvP Data
    local pvp = {}
    pcall(function()
        local rankNumber = 0
        if UnitPVPRank and GetPVPRankInfo then
            rankNumber = GetPVPRankInfo(UnitPVPRank("player")) or 0
        end
        local lifetimeHK = (GetPVPLifetimeStats and select(1, GetPVPLifetimeStats())) or 0
        pvp = {
            rank = rankNumber,
            lifetime_hk = lifetimeHK,
        }
    end)

    -- CRITICAL SAFETY GUARD:
    -- If no items and no health were detected (e.g. during logout, reload teardown, or before world data loads),
    -- NEVER overwrite an existing valid character export in SavedVariables!
    if equippedCount == 0 and (totalIlvl == 0 or stats.max_health == 0) then
        if WoWEternityAddonDB and WoWEternityAddonDB.character_export and (WoWEternityAddonDB.character_export.equipped_count or 0) > 0 then
            if not silent then
                self:Print("|cffff9900[WoW Eternity Addon]|r Preserved existing character export; player data is not yet loaded from game server.")
            end
            return WoWEternityAddonDB.character_export
        end
    end

    local exportData = {
        name = name,
        realm = realm,
        class = localizedClass or "Warrior",
        class_file = (classFileName or "WARRIOR"):lower(),
        race = localizedRace or "Human",
        race_file = (raceFileName or "Human"):lower(),
        gender = gender,
        level = level,
        guild = guildName,
        spec_name = primarySpecName,
        talents = talentString,
        talent_trees = talentTrees,
        spent_talents = spentTalents,
        avg_ilvl = avgIlvl,
        equipped_count = equippedCount,
        equipment = equipment,
        professions = professions,
        stats = stats,
        pvp = pvp,
        probe_log = probeLog,
        exported_at = (time and time()) or 0,
        exported_at_iso = (date and date("!%Y-%m-%dT%H:%M:%SZ")) or "",
    }

    -- Persist in global SavedVariables and Per-Character store
    WoWEternityAddonDB = WoWEternityAddonDB or {}
    WoWEternityAddonDB.character_export = exportData
    WoWEternityAddonDB.characters = WoWEternityAddonDB.characters or {}
    local charKey = string.format("%s-%s", tostring(name or "Unknown"), tostring(realm or "Unknown"))
    WoWEternityAddonDB.characters[charKey] = exportData
    pcall(function()
        WoWEternityAddonDB.character_export_json = self:ToJson(exportData)
    end)
    WoWEternityAddonDB.last_character_export_time = exportData.exported_at
    WoWEternityAddonDB.talent_probe_log = probeLog
    WoWEternityAddonCharDB = exportData

    if not silent then
        self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Character profile |cffffd100%s|r (%s, %d items, ilvl %.1f) exported successfully!",
            name, talentString, equippedCount, avgIlvl))
        self:Print("|cffe6cc80[WoW Eternity Addon]|r Stats exported as Unbuffed Base (temporary buffs stripped).")
        if #probeLog > 0 then
            self:Print("|cffe6cc80[WoW Eternity Addon]|r |cffaaaaaaTalent Diagnostics:|r " .. table.concat(probeLog, " | "))
        end
        self:Print("|cffe6cc80[WoW Eternity Addon]|r Saved to SavedVariables. Type |cffffffff/reload|r to flush to WoW Eternity Client.")
    end

    -- Update UI if frame is open
    if self.mainFrame and self.mainFrame:IsShown() then
        self:UpdateMainFrameView()
    end

    return exportData
end

-- ============================================================================
-- Minimap Button Engine (Pure Lua, zero dependencies)
-- ============================================================================

function WoWEternityAddon:UpdateMinimapVisibility()
    if not self.minimapButton then return end
    if WoWEternityAddonDB and WoWEternityAddonDB.showMinimap == false then
        self.minimapButton:Hide()
    else
        self.minimapButton:Show()
    end
end

function WoWEternityAddon:RepositionMinimapButton()
    if not self.minimapButton or not Minimap then return end
    local angle = (WoWEternityAddonDB and WoWEternityAddonDB.minimapPos) or 45
    local rad = math.rad(angle)
    local radius = 80
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function WoWEternityAddon:CreateMinimapButton()
    if not CreateFrame or not Minimap then return end
    if self.minimapButton then return end

    local button = CreateFrame("Button", "WoWEternityAddonMinimapButton", Minimap)
    self.minimapButton = button

    button:SetFrameStrata("HIGH")
    button:SetSize(32, 32)
    local lvl = (Minimap.GetFrameLevel and Minimap:GetFrameLevel()) or 8
    button:SetFrameLevel(lvl + 10)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("RightButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-Button-Highlight")

    -- Circular tracking border overlay
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", 0, 0)

    -- Custom icon texture
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("CENTER", 0, 1)

    self:RepositionMinimapButton()
    self:UpdateMinimapVisibility()

    -- Dragging Handler with safe coordinates
    button:SetScript("OnDragStart", function(btn)
        btn:LockHighlight()
        btn:SetScript("OnUpdate", function()
            if not Minimap then return end
            local mx, my = Minimap:GetCenter()
            if not mx or not my then return end
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale() or 1
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            if angle < 0 then angle = angle + 360 end
            WoWEternityAddonDB = WoWEternityAddonDB or {}
            WoWEternityAddonDB.minimapPos = angle
            self:RepositionMinimapButton()
        end)
    end)

    button:SetScript("OnDragStop", function(btn)
        btn:UnlockHighlight()
        btn:SetScript("OnUpdate", nil)
    end)

    -- Tooltip & Click Handlers
    button:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffe6cc80WoW Eternity Addon (/wea)|r", 1, 1, 1)

        local name = UnitName("player") or "Hero"
        local _, class = UnitClass("player")
        local level = UnitLevel("player") or 60
        GameTooltip:AddLine(string.format("|cffffffff%s|r (|cffffd100Lvl %d %s|r)", name, level, class or ""), 0.9, 0.9, 0.9)

        local count = WoWEternityAddon:GetItemCount()
        local specStr = (WoWEternityAddonDB and WoWEternityAddonDB.active_spec and WoWEternityAddonDB.active_spec ~= "") and WoWEternityAddonDB.active_spec or "All Specs"
        GameTooltip:AddLine(string.format("Synced BiS Items: |cff00ff00%d|r (Spec: |cffffd100%s|r)", count, specStr), 0.8, 0.8, 0.8)

        local lastExport = WoWEternityAddonDB and WoWEternityAddonDB.character_export and WoWEternityAddonDB.character_export.exported_at_iso
        if lastExport and lastExport ~= "" then
            GameTooltip:AddLine(string.format("Last Character Export: |cff60a5fa%s|r", lastExport:sub(1, 16):gsub("T", " ")), 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffe6cc80Left-Click:|r Open WoW Eternity Addon (/wea)", 0.9, 0.8, 0.5)
        GameTooltip:AddLine("|cffffd100Right-Click Drag:|r Reposition minimap icon", 1, 0.8, 0.2)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    button:SetScript("OnClick", function(_, btn)
        if btn == "LeftButton" then
            WoWEternityAddon:ToggleSettingsFrame()
        end
    end)
end

-- ============================================================================
-- In-Game 5-Tab Control Panel (/wea)
-- Tabs: Account, Char, Gear Planner, BIS-Lists, Settings
-- ============================================================================

local function GetBackdropTemplate()
    return BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function ApplyBackdrop(f, bgR, bgG, bgB, bgA, edgeR, edgeG, edgeB, edgeA)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(bgR or 0.05, bgG or 0.06, bgB or 0.10, bgA or 0.95)
    f:SetBackdropBorderColor(edgeR or 0.23, edgeG or 0.27, edgeB or 0.38, edgeA or 1)
end

local function CreateCard(parent, bgR, bgG, bgB, bgA, edgeR, edgeG, edgeB, edgeA)
    local card = CreateFrame("Frame", nil, parent, GetBackdropTemplate())
    ApplyBackdrop(card, bgR or 0.03, bgG or 0.04, bgB or 0.07, bgA or 0.92, edgeR or 0.18, edgeG or 0.22, edgeB or 0.32, edgeA or 1)
    return card
end

local function CreateStyledButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    if width and height then
        btn:SetSize(width, height)
    end
    btn:SetText(text)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function CreateCheckbox(parent, name, labelText, defaultChecked, onClick)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    local label = _G[name .. "Text"] or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    label:SetText(labelText)
    cb:SetChecked(defaultChecked)
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if onClick then onClick(checked) end
    end)
    return cb
end

local function IsItemInBags(targetItemId)
    if not targetItemId or targetItemId <= 0 then return false end
    for bag = 0, 4 do
        local numSlots = 0
        if C_Container and C_Container.GetContainerNumSlots then
            numSlots = C_Container.GetContainerNumSlots(bag) or 0
        elseif GetContainerNumSlots then
            numSlots = GetContainerNumSlots(bag) or 0
        end
        for slot = 1, numSlots do
            local itemId = 0
            if C_Container and C_Container.GetContainerItemID then
                itemId = C_Container.GetContainerItemID(bag, slot) or 0
            elseif GetContainerItemID then
                itemId = GetContainerItemID(bag, slot) or 0
            end
            if itemId == targetItemId then
                return true
            end
        end
    end
    return false
end

local function IsItemEquipped(targetItemId)
    if not targetItemId or targetItemId <= 0 then return false end
    for _, slot in ipairs(INVENTORY_SLOTS) do
        local equippedId = (GetInventoryItemID and GetInventoryItemID("player", slot.id)) or 0
        if equippedId == targetItemId then
            return true, slot.name
        end
    end
    return false
end

function WoWEternityAddon:GetBuildUrl()
    local name = UnitName("player") or "Hero"
    local _, classFile = UnitClass("player")
    local classSlug = (classFile or "warrior"):lower()
    local _, raceFile = UnitRace("player")
    local raceSlug = (raceFile or "human"):lower()

    local cur = (WoWEternityAddonDB and WoWEternityAddonDB.character_export)
    local talents = cur and cur.talents or "0/0/0"
    local spec = cur and cur.spec_name or (classSlug:sub(1, 1):upper() .. classSlug:sub(2))

    local prof1 = ""
    local prof2 = ""
    if cur and cur.professions then
        for _, p in ipairs(cur.professions) do
            if not p.is_secondary then
                if prof1 == "" then prof1 = p.name else prof2 = p.name end
            end
        end
    end

    local gearParts = {}
    if cur and cur.equipment then
        for _, slot in ipairs(INVENTORY_SLOTS) do
            local eq = cur.equipment[slot.name]
            if eq and eq.item_id and eq.item_id > 0 then
                table.insert(gearParts, string.format("%d:%d:%d", eq.slot_id or slot.id, eq.item_id or 0, eq.enchant_id or 0))
            end
        end
    end

    local cleanName = name:gsub(" ", "%%20")
    local cleanSpec = spec:gsub(" ", "%%20")
    local cleanProf1 = prof1:gsub(" ", "%%20")
    local cleanProf2 = prof2:gsub(" ", "%%20")

    return string.format("https://woweternity.com/build/new?class=%s&race=%s&spec=%s&name=%s&talents=%s&prof1=%s&prof2=%s&gear=%s",
        classSlug, raceSlug, cleanSpec, cleanName, talents, cleanProf1, cleanProf2, table.concat(gearParts, ","))
end

-- ============================================================================
-- Cadberry Leveling Extravaganza Database (Alliance 44 Steps, Horde 34 Steps)
-- Source: https://woweternity.com/forever/guides/cadberry-leveling
-- ============================================================================

local CADBERRY_ALLIANCE_GUIDE = {
    faction = "alliance",
    title = "Alliance 1–60 Leveling & Dungeon Path",
    description = "Complete 1–60 leveling progression for Alliance, covering RestedXP zone routes, Sleeping Bag quest pickup, dungeon prerequisite quest chains, and endgame attunements.",
    steps = {
    {
        id = "ally-1",
        stepNumber = 1,
        levelBadge = "1–12",
        title = "Starter Zone & Loch Modan Leveling",
        type = "leveling",
        location = "Dun Morogh / Elwynn / Loch Modan",
        dungeonName = "",
        details = { "Follow standard RestedXP leveling route through starting zones all the way through Loch Modan.", "Keep up with class trainers and secondary skill training along the route." },
        note = "",
        links = {},
        mapID = 27,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-2",
        stepNumber = 2,
        levelBadge = "~13",
        title = "Get Hall of Thanes (HoT) Quest from Gol'Bolar Quarry",
        type = "prep",
        location = "Gol'Bolar Quarry, Dun Morogh (/way 64.8 58.4)",
        dungeonName = "",
        details = { "Pick up quest from Earthseer Farsen at /way 64.8 58.4 in Gol'Bolar Quarry.", "Prerequisite to pick up Underground Map from Dark Iron Map object." },
        note = "Gotta go kill Captain Beld which is located far southeast of Dun Morogh.",
        links = {},
        mapID = 27,
        x = 0.6480,
        y = 0.5840,
    },
    {
        id = "ally-3",
        stepNumber = 3,
        levelBadge = "~13",
        title = "Get Cozy Sleeping Bag Starting in Westfall",
        type = "quest",
        location = "Westfall (Starting Point)",
        dungeonName = "",
        details = { "Critical leveling item: Provides +3% stacking rested XP gain anywhere in the world.", "Starts in Westfall with the quest \"This Must Be the Place\"." },
        note = "",
        links = { { text = "Sleeping Bag Quest Chain (Wowhead Guide)", url = "https://www.wowhead.com/forever/quest=79976/this-must-be-the-place" } },
        mapID = 52,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-4",
        stepNumber = 4,
        levelBadge = "13–15",
        title = "Get Hall of Thanes (HoT) Quests",
        type = "prep",
        location = "Old Ironforge",
        dungeonName = "",
        details = { "These are all in Old Ironforge: 2 of them located just north of the bank, plus 2 inside the instance." },
        note = "",
        links = {},
        mapID = 87,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-5",
        stepNumber = 5,
        levelBadge = "13–16",
        title = "Do Hall of Thanes (HoT)",
        type = "dungeon",
        location = "",
        dungeonName = "Hall of Thanes",
        details = {},
        note = "Turn in quests upon completion. Most turn-ins are located in Ironforge.",
        links = {},
        mapID = 27,
        x = 0.6480,
        y = 0.5840,
    },
    {
        id = "ally-6",
        stepNumber = 6,
        levelBadge = "15–18",
        title = "Go Do Ruins of Lordaeron (RoL)",
        type = "dungeon",
        location = "",
        dungeonName = "Ruins of Lordaeron",
        details = {},
        note = "All dungeon quests are picked up directly inside the instance for Alliance.",
        links = {},
        mapID = 18,
        x = 0.6120,
        y = 0.6720,
    },
    {
        id = "ally-7",
        stepNumber = 7,
        levelBadge = "17–20",
        title = "Prepare for Deadmines",
        type = "prep",
        location = "Westfall / Lakeshire / Stormwind",
        dungeonName = "",
        details = { "Start Defias Brotherhood chain in Westfall that sends you to Lakeshire. Fly back and forth and eventually kill the Defias Messenger.", "Pick up 3 other quests in the Dwarven District of Stormwind while traveling for the Messenger quest.", "Last quest is on top of the tower in Sentinel Hill, Westfall." },
        note = "",
        links = {},
        mapID = 52,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-8",
        stepNumber = 8,
        levelBadge = "~22",
        title = "Do The Deadmines",
        type = "dungeon",
        location = "Moonbrook, Westfall",
        dungeonName = "The Deadmines",
        details = {},
        note = "Finish all Defias Brotherhood turn-ins. Expect to be level 22 or so upon completion.",
        links = {},
        mapID = 52,
        x = 0.4260,
        y = 0.7220,
    },
    {
        id = "ally-9",
        stepNumber = 9,
        levelBadge = "22–25",
        title = "Quest Until Level 24–25 (Duskwood & Redridge)",
        type = "leveling",
        location = "Redridge Mountains & Duskwood",
        dungeonName = "",
        details = {},
        note = "Follow the RestedXP guide through Redridge and Duskwood until it routes you into Stormwind Stockades.",
        links = {},
        mapID = 49,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-10",
        stepNumber = 10,
        levelBadge = "24–26",
        title = "Skip Shadowfang Keep (SFK)",
        type = "info",
        location = "Silverpine Forest",
        dungeonName = "",
        details = {},
        note = "SFK quests do NOT exist for Alliance. Not worth running for Alliance due to the total lack of quest rewards.",
        links = {},
        mapID = 21,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-11",
        stepNumber = 11,
        levelBadge = "24–28",
        title = "Get Stockades Quests & Do The Stockade",
        type = "dungeon",
        location = "Stormwind City",
        dungeonName = "The Stockade",
        details = { "Pick up quests across Stormwind, Redridge, and Duskwood.", "Quick instance run inside Stormwind City." },
        note = "Expect to be around level 28 upon completion.",
        links = {},
        mapID = 84,
        x = 0.5050,
        y = 0.6650,
    },
    {
        id = "ally-12",
        stepNumber = 12,
        levelBadge = "26–30",
        title = "Get Wetlands Excavation Site Quests & Do ESW",
        type = "dungeon",
        location = "Wetlands",
        dungeonName = "Wetlands Excavation Site",
        details = {},
        note = "",
        links = {},
        mapID = 56,
        x = 0.3540,
        y = 0.4760,
    },
    {
        id = "ally-13",
        stepNumber = 13,
        levelBadge = "24–30",
        title = "Get Blackfathom Deeps (BFD) Quests",
        type = "prep",
        location = "Ironforge / Darnassus",
        dungeonName = "",
        details = { "One quest in Ironforge: Forlorn Caverns from Gerrig Bonegrip.", "One in Darnassus: Craftsman's Terrace from Dawnwatcher Shaedlass.", "Another in Darnassus: same area from Argent Guard Manados.", "Last is from The Park in Darnassus, which routes to Auberdine before heading into BFD." },
        note = "",
        links = {},
        mapID = 87,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-14",
        stepNumber = 14,
        levelBadge = "24–32",
        title = "Do Blackfathom Deeps (BFD)",
        type = "dungeon",
        location = "Ashenvale",
        dungeonName = "Blackfathom Deeps",
        details = {},
        note = "",
        links = {},
        mapID = 63,
        x = 0.1420,
        y = 0.1440,
    },
    {
        id = "ally-15",
        stepNumber = 15,
        levelBadge = "~30",
        title = "Get City of Dalaran Quests & Do Dalaran",
        type = "dungeon",
        location = "Alterac Mountains / Dalaran",
        dungeonName = "City of Dalaran",
        details = {},
        note = "Expect to be around level 30.",
        links = {},
        mapID = 94,
        x = 0.2010,
        y = 0.7320,
    },
    {
        id = "ally-16",
        stepNumber = 16,
        levelBadge = "29–33",
        title = "Gnomeregan Prerequisite Quests",
        type = "prep",
        location = "Stormwind / Darnassus / Stonetalon / Kharanos",
        dungeonName = "",
        details = { "Stormwind Cathedral: Brother Sarno (sends you to Ironforge).", "Darnassus Warrior's Terrace: Mathiel.", "Stonetalon Mountains South: Gaxim Rustfizzle.", "Gnogaine quest: Kharanos, Ozzie Togglevolt. Unlocks \"The Only Cure is More Green Glow\" (complete outside Gnomer and turn in)." },
        note = "",
        links = {},
        mapID = 84,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-17",
        stepNumber = 17,
        levelBadge = "29–34",
        title = "Get Gnomeregan Quests",
        type = "quest",
        location = "Ironforge & Stormwind",
        dungeonName = "",
        details = { "Stormwind Dwarven District: Shoni the Shilent.", "Techbot's CPU: Ironforge Tinker Town, Tinkmaster Overspark.", "Essential Artificials: Ironforge Tinker Town, Klockmort Spannerspan.", "Data Rescue: Ironforge Tinker Town, Master Mechanic Castpipe.", "The Grand Betrayal: Ironforge Tinker Town, High Tinker Mekkatorque." },
        note = "",
        links = {},
        mapID = 87,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-18",
        stepNumber = 18,
        levelBadge = "29–34",
        title = "Do Gnomeregan",
        type = "dungeon",
        location = "Dun Morogh",
        dungeonName = "Gnomeregan",
        details = { "Inside dungeon quest right after the Clean Room: Kernobee (escort quest).", "Cleanse Grime-Encrusted Object in dungeon Sparklematic 5200.", "Pick up and cleanse Grime-Encrusted Ring." },
        note = "",
        links = {},
        mapID = 27,
        x = 0.2450,
        y = 0.3950,
    },
    {
        id = "ally-19",
        stepNumber = 19,
        levelBadge = "33–35",
        title = "Get Scarlet Monastery Library Quests",
        type = "prep",
        location = "Hillsbrad & Ironforge",
        dungeonName = "",
        details = { "Hillsbrad: Raleigh the Devout (requires level 34).", "Ironforge Hall of Explorers: Librarian Mae Paledust." },
        note = "",
        links = {},
        mapID = 87,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-20",
        stepNumber = 20,
        levelBadge = "33–36",
        title = "Do Scarlet Monastery: Library",
        type = "dungeon",
        location = "Tirisfal Glades",
        dungeonName = "Scarlet Monastery (Library)",
        details = {},
        note = "",
        links = {},
        mapID = 18,
        x = 0.8520,
        y = 0.3160,
    },
    {
        id = "ally-21",
        stepNumber = 21,
        levelBadge = "30–35",
        title = "Razorfen Kraul (RFK) Prerequisites & Quests",
        type = "prep",
        location = "Thousand Needles & Ratchet",
        dungeonName = "",
        details = { "Prereq starts at the elevator in Thousand Needles in a bag next to a body, routes to easternmost spot of Feralas from Falfindel Waywarder.", "Blueleaf Tubers: Ratchet, Mebok Mizzyrix." },
        note = "",
        links = {},
        mapID = 64,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-22",
        stepNumber = 22,
        levelBadge = "~36",
        title = "Do Razorfen Kraul (RFK)",
        type = "dungeon",
        location = "Southern Barrens",
        dungeonName = "Razorfen Kraul",
        details = {},
        note = "Expect to be around level 36 upon completion.",
        links = {},
        mapID = 10,
        x = 0.4080,
        y = 0.8980,
    },
    {
        id = "ally-23",
        stepNumber = 23,
        levelBadge = "36–39",
        title = "Get SM Armory & Cathedral Quests & Run Both Wings",
        type = "dungeon",
        location = "Tirisfal Glades",
        dungeonName = "Scarlet Monastery (Armory & Cathedral)",
        details = { "No additional quests required — just the follow-up obtained from Library at level 34." },
        note = "",
        links = {},
        mapID = 18,
        x = 0.8540,
        y = 0.3160,
    },
    {
        id = "ally-24",
        stepNumber = 24,
        levelBadge = "~39",
        title = "Get Drowned City Quests & Do Drowned City",
        type = "dungeon",
        location = "",
        dungeonName = "Drowned City",
        details = {},
        note = "Expect to be around level 39.",
        links = {},
        mapID = 51,
        x = 0.6500,
        y = 0.3500,
    },
    {
        id = "ally-25",
        stepNumber = 25,
        levelBadge = "39–41",
        title = "Quest Until Level 41",
        type = "leveling",
        location = "Badlands / Stranglethorn Vale / Arathi Highlands",
        dungeonName = "",
        details = {},
        note = "Follow RestedXP guide until level 41 before zoning into Krol'dok.",
        links = {},
        mapID = 14,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-26",
        stepNumber = 26,
        levelBadge = "41–43",
        title = "Get Krol'dok Quests & Do Krol'Dok",
        type = "dungeon",
        location = "",
        dungeonName = "Krol'dok",
        details = {},
        note = "",
        links = {},
        mapID = 66,
        x = 0.5500,
        y = 0.5500,
    },
    {
        id = "ally-27",
        stepNumber = 27,
        levelBadge = "39–43",
        title = "Get Razorfen Downs (RFD) Quests",
        type = "quest",
        location = "Stormwind & Southern Barrens",
        dungeonName = "",
        details = { "Stormwind Cathedral Square: Archbishop Benedictus (level 39).", "Outside RFD: Mariam Moonsinger (south near Thousand Needles border)." },
        note = "",
        links = {},
        mapID = 84,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-28",
        stepNumber = 28,
        levelBadge = "40–44",
        title = "Do Razorfen Downs (RFD)",
        type = "dungeon",
        location = "Southern Barrens",
        dungeonName = "Razorfen Downs",
        details = {},
        note = "",
        links = {},
        mapID = 10,
        x = 0.4720,
        y = 0.9250,
    },
    {
        id = "ally-29",
        stepNumber = 29,
        levelBadge = "40–45",
        title = "Uldaman Prerequisites",
        type = "prep",
        location = "Ironforge / Loch Modan / Badlands",
        dungeonName = "",
        details = { "Ironband Wants You!: Ironforge Hall of Explorers, Prospector Stormpike -> SE Loch Modan -> Badlands.", "The Lost Dwarves: Ironforge Hall of Explorers, Prospector Stormpike (level 35).", "Badlands Reagent Run: Ghak Healtouch in Thelsamar (Loch Modan) -> Badlands Reagent Run 2.", "Pick up the hidden map in Badlands at coordinates /way 53 33." },
        note = "",
        links = {},
        mapID = 48,
        x = 0.5300,
        y = 0.3300,
    },
    {
        id = "ally-30",
        stepNumber = 30,
        levelBadge = "40–46",
        title = "Get Uldaman Quests",
        type = "quest",
        location = "Badlands & Ironforge",
        dungeonName = "",
        details = { "Solution to Doom: Theldurin the Lost (middle south Badlands, outside instance).", "Turn in Sign of Hope right outside instance portal.", "Power Stones (30): Rigglefuzz (middle of Badlands).", "Reclaimed Treasures: Ironforge Hall of Explorers, Krom Stoutarm (outside instance).", "Agmond's Fate: Battered Dwarven Skeleton / Urns (outside instance)." },
        note = "",
        links = {},
        mapID = 87,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-31",
        stepNumber = 31,
        levelBadge = "40–47",
        title = "Do Uldaman",
        type = "dungeon",
        location = "Badlands",
        dungeonName = "Uldaman",
        details = {},
        note = "",
        links = {},
        mapID = 15,
        x = 0.4400,
        y = 0.1250,
    },
    {
        id = "ally-32",
        stepNumber = 32,
        levelBadge = "44–47",
        title = "Zul'Farrak (ZF) Prerequisites & Mallet Quest Chain",
        type = "prep",
        location = "Booty Bay / Stormwind / Tanaris / Hinterlands",
        dungeonName = "",
        details = { "Tran'rek: Booty Bay, Krazek.", "Tabetha's Task: Stormwind Mage Quarter, Bink or Jennea Cannon.", "Screecher Spirits: Steamwheedle Port, Yeh'kinya.", "The Brassbolts Brothers: Ironforge Tinker Town, Klockmort.", "Mallet of Zul'Farrak: Hinterlands Jintha'Alor elite area, kill Qiaga the Keeper for Sacred Mallet, take to top of pyramid altar to forge the Mallet.", "Witherbark Cages chain: Aerie Peak -> Altar of Zul -> Thadias Grimshade (Nethergarde Keep) -> ZF." },
        note = "",
        links = {},
        mapID = 84,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-33",
        stepNumber = 33,
        levelBadge = "44–48",
        title = "Get Zul'Farrak (ZF) Quests",
        type = "quest",
        location = "Gadgetzan / Steamwheedle Port / Shimmering Flats",
        dungeonName = "",
        details = { "Troll Temper: Gadgetzan, Trenton Lighthammer.", "Scarab Shells: Gadgetzan, Tran'rek.", "Prophecy of Mosh'aru: Steamwheedle Port, Yeh'kinya.", "Divino-matic Rod: Gadgetzan, Chief Engineer Bilgewhizzle.", "Gahz'rilla: Shimmering Flats, Wizzle Brassbolts." },
        note = "",
        links = {},
        mapID = 0,
        x = 0.0000,
        y = 0.0000,
    },
    {
        id = "ally-34",
        stepNumber = 34,
        levelBadge = "~47",
        title = "Do Zul'Farrak (ZF)",
        type = "dungeon",
        location = "Tanaris",
        dungeonName = "Zul'Farrak",
        details = {},
        note = "Expect to be around level 47.",
        links = {},
        mapID = 71,
        x = 0.3920,
        y = 0.2130,
    },
    {
        id = "ally-35",
        stepNumber = 35,
        levelBadge = "46–50",
        title = "Get Maraudon Quests & Do All 3 Wings",
        type = "dungeon",
        location = "Desolace",
        dungeonName = "Maraudon",
        details = { "Twisted Evils: Desolace middle cliffs, Willow.", "The Pariah's Instructions: South Desolace, Centaur Pariah (half outside, half inside).", "Legends of Maraudon (Scepter): Orange side Maraudon, Cavindra.", "Shadowshard Fragments: Theramore, Archmage Tervosh.", "Vyletongue Corruption: Nijel's Point, Talendria.", "Corruption of Earth and Seed: Nijel's Point, Keeper Marandis." },
        note = "",
        links = {},
        mapID = 66,
        x = 0.2920,
        y = 0.6250,
    },
    {
        id = "ally-36",
        stepNumber = 36,
        levelBadge = "~52",
        title = "Get Alcaz Prison Quests & Do Alcaz Prison",
        type = "dungeon",
        location = "Dustwallow Marsh (Alcaz Island)",
        dungeonName = "Alcaz Prison",
        details = {},
        note = "Expect to be around level 52.",
        links = {},
        mapID = 70,
        x = 0.7750,
        y = 0.1780,
    },
    {
        id = "ally-37",
        stepNumber = 37,
        levelBadge = "47–55",
        title = "BRD & Sunken Temple Prerequisite Chains",
        type = "prep",
        location = "Searing Gorge / Burning Steppes / Feralas / Tanaris / Stormwind",
        dungeonName = "",
        details = { "BRD Taste of Flame: Searing Gorge, Cyrus Therepentous (long chain, start at level 47).", "BRD Incendius!: Burning Steppes SE, Jalinda Sprig.", "BRD Kharan Mighthammer: Ironforge, King Magni Bronzebeard.", "ST The Sunken Temple: Feathermoon Stronghold, Angelas Moonbreeze -> Stone Circle.", "ST The Ancient Eggs: Tanaris, Yeh'kinya -> top of Jintha'Alor -> The God Hakkar.", "ST Into the Temple: SW Dwarven District Brohann -> Swamp of Sorrows -> Aerie Peak Gryphon Master Talonaxe -> Rhapsody Shindigger -> Tanaris/Feralas -> SW Dwarven District.", "ST Haze of Evil: Un'Goro Crater, Muigin -> Feralas." },
        note = "",
        links = {},
        mapID = 84,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-38",
        stepNumber = 38,
        levelBadge = "55",
        title = "Hit Level 55 Milestone",
        type = "milestone",
        location = "Western Plaguelands / Un'Goro / Silithus",
        dungeonName = "",
        details = {},
        note = "Ensure you are level 55 before proceeding to the endgame dungeon circuit.",
        links = {},
        mapID = 22,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "ally-39",
        stepNumber = 39,
        levelBadge = "50–55",
        title = "Get Sunken Temple Quests & Do Sunken Temple",
        type = "dungeon",
        location = "Swamp of Sorrows",
        dungeonName = "Sunken Temple",
        details = { "Jammal'an the Prophet: Hinterlands southern troll temple.", "Into the Temple of Atal'Hakkar.", "Statue Activation Puzzle Order: South, North, Southwest, Southeast, Northwest, Northeast -> then center large snake statue." },
        note = "",
        links = {},
        mapID = 51,
        x = 0.6980,
        y = 0.5360,
    },
    {
        id = "ally-40",
        stepNumber = 40,
        levelBadge = "52–56",
        title = "Get BRD Quests & Run BRD (First Half)",
        type = "dungeon",
        location = "Blackrock Mountain",
        dungeonName = "Blackrock Depths",
        details = { "Heart of the Mountain: Burning Steppes far north camp, Maxwort Uberglint.", "Dark Iron Legacy (Shadowforge Key): Franclorn Forgewright (ghost at tomb near summoning stone).", "Incendius!: Burning Steppes, Jalinda Sprig.", "The Good Stuff: Burning Steppes, Jalinda Sprig." },
        note = "Recommended to stop halfway through on first run (Prison, Arena, Shadowforge Key). Save Princess / Emperor for second dedicated run.",
        links = {},
        mapID = 32,
        x = 0.3520,
        y = 0.8440,
    },
    {
        id = "ally-41",
        stepNumber = 41,
        levelBadge = "55–58",
        title = "Get LBRS Quests & Run Lower Blackrock Spire",
        type = "dungeon",
        location = "Blackrock Mountain",
        dungeonName = "Lower Blackrock Spire",
        details = { "En-Ay-Es-Tee-Why: Burning Steppes far north camp, Kibler (level 55).", "Kibler's Exotic Pets: Burning Steppes far north camp, Kibler (level 55).", "The Final Tablets of Mosh'aru: Tanaris, Yeh'kinya.", "Put Her Down: Burning Steppes SE, Helendis Riverhorn.", "CRUCIAL: Use the cage item on a Bloodaxe Worg Pup during the Halycon encounter while the pup is still alive!" },
        note = "",
        links = {},
        mapID = 32,
        x = 0.3550,
        y = 0.8400,
    },
    {
        id = "ally-42",
        stepNumber = 42,
        levelBadge = "56–60",
        title = "Get Scholomance Quests & Run Scholomance",
        type = "dungeon",
        location = "Western Plaguelands (Caer Darrow)",
        dungeonName = "Scholomance",
        details = { "Plagued Hatchlings: Light's Hope Chapel, Betina Bigglezink.", "Doctor Theolen Krastinov: Caer Darrow, Eva Sarkhoff.", "Barov Family Fortune: Chillwind Camp, Weldon Barov.", "4 Barov Deed Locations: (1) Large room after bridge next to bookshelf on desk; (2) Desk in right corner before dragon whelps; (3) Ras Frostwhisper room; (4) Alexi Barov room." },
        note = "",
        links = {},
        mapID = 22,
        x = 0.6920,
        y = 0.7300,
    },
    {
        id = "ally-43",
        stepNumber = 43,
        levelBadge = "58–60",
        title = "Get Stratholme Quests & Run Living & Undead Wings",
        type = "dungeon",
        location = "Eastern Plaguelands",
        dungeonName = "Stratholme",
        details = { "Houses of the Holy: Light's Hope Chapel, Leonid Barthalomew.", "The Restless Souls: Light's Hope Chapel, Caretaker Alen.", "The Great Fras Siabi: Light's Hope Chapel, Smokey LaRue.", "The Archivist: Light's Hope Chapel, Duke Nicholas Zverenhoff.", "Strategy: Pick up Medallion of Faith from Aurius at entrance of UD church side. Run living side first, turn in Medallion, then push Undead Baron Rivendare side." },
        note = "",
        links = {},
        mapID = 23,
        x = 0.2720,
        y = 0.1160,
    },
    {
        id = "ally-44",
        stepNumber = 44,
        levelBadge = "60",
        title = "GRATS ON 60! Endgame Raids & Pre-BiS Unlocked",
        type = "milestone",
        location = "Azeroth",
        dungeonName = "",
        details = {},
        note = "Congratulations on reaching Level 60 in World of Warcraft: Forever! Check out our Molten Core & Onyxia raid guides and Phase 1 BiS lists.",
        links = {},
        mapID = 0,
        x = 0.0000,
        y = 0.0000,
    }
    },
}

local CADBERRY_HORDE_GUIDE = {
    faction = "horde",
    title = "Horde 1–60 Leveling & Dungeon Path",
    description = "Complete 1–60 leveling progression for Horde, covering RestedXP zone routes, Sleeping Bag quest pickup, dungeon prerequisite quest chains, and endgame attunements.",
    steps = {
    {
        id = "horde-1",
        stepNumber = 1,
        levelBadge = "1–12",
        title = "Starter Zone Leveling All The Way to RFC",
        type = "leveling",
        location = "Durotar / Mulgore / Tirisfal Glades",
        dungeonName = "",
        details = { "Follow RestedXP leveling guide all the way through starter zones until Ragefire Chasm preparation." },
        note = "",
        links = {},
        mapID = 18,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "horde-2",
        stepNumber = 2,
        levelBadge = "12–13",
        title = "Wailing Caverns & Ratchet Prerequisites",
        type = "prep",
        location = "Ratchet & The Crossroads",
        dungeonName = "",
        details = { "Raptor Horns in Ratchet from Mebok Mizzyrix.", "5-quest chain starting at The Forgotten Pools, Crossroads (Tonga Runetotem), ending at Leaders of the Fang." },
        note = "",
        links = {},
        mapID = 10,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "horde-3",
        stepNumber = 3,
        levelBadge = "~13",
        title = "Go Get Cozy Sleeping Bag Starting in Westfall",
        type = "quest",
        location = "Westfall / Barrens Cross-Faction Run",
        dungeonName = "",
        details = { "Must-have leveling tool: +3% stacking rested XP anywhere in the world.", "Guide covers both Horde and Alliance pathing." },
        note = "",
        links = { { text = "Sleeping Bag Quest Chain (Wowhead Guide)", url = "https://www.wowhead.com/forever/quest=79976/this-must-be-the-place" } },
        mapID = 52,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "horde-4",
        stepNumber = 4,
        levelBadge = "13–15",
        title = "Get Ragefire Chasm (RFC) Quests",
        type = "quest",
        location = "Orgrimmar / Thunder Bluff / Undercity",
        dungeonName = "",
        details = { "Hidden Enemies: Orgrimmar, Thrall (5-part chain).", "Slaying the Beast: Orgrimmar Cleft of Shadow, Neeru Fireblade.", "Searching for the Lost Satchel: Thunder Bluff Elder Rise, Rahaur (must be lvl 13).", "Testing an Enemy's Strength: Thunder Bluff Elder Rise, Rahaur (must be lvl 13).", "The Power to Destroy...: Undercity Royal Quarter, Varimathras." },
        note = "Character must be level 13 to pick up the Thunder Bluff quests.",
        links = {},
        mapID = 85,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "horde-5",
        stepNumber = 5,
        levelBadge = "13–16",
        title = "Do Ragefire Chasm (RFC)",
        type = "dungeon",
        location = "Orgrimmar",
        dungeonName = "Ragefire Chasm",
        details = {},
        note = "",
        links = {},
        mapID = 85,
        x = 0.5280,
        y = 0.4950,
    },
    {
        id = "horde-6",
        stepNumber = 6,
        levelBadge = "15–18",
        title = "Get Ruins of Lordaeron (RoL) Quests & Do RoL",
        type = "dungeon",
        location = "Tirisfal Glades / Undercity",
        dungeonName = "Ruins of Lordaeron",
        details = { "A Frightened Request: Undercity, Tabitha Heartweaver.", "Wrath of Rath'mael: Brill, Deathguard Kristof.", "New Plague: Undercity, Theodore Griffs.", "Light's Justice: Undercity, Morbin Lightbane." },
        note = "",
        links = {},
        mapID = 18,
        x = 0.6120,
        y = 0.6720,
    },
    {
        id = "horde-7",
        stepNumber = 7,
        levelBadge = "17–20",
        title = "Get Wailing Caverns (WC) Quests",
        type = "quest",
        location = "Thunder Bluff / Ratchet / WC Entrance",
        dungeonName = "",
        details = { "Serpentbloom: Thunder Bluff Pools of Vision, Apothecary Zamah.", "Smart Drinks: Ratchet, Mebok Mizzyrix.", "Trouble at the Docks: Ratchet, Crane Operator Bigglefuzz.", "Deviate Hides: Outside WC instance entrance, Nalpak.", "Deviate Eradication: Outside WC instance entrance, Ebru.", "Leaders of the Fang: Thunder Bluff Elder Rise, Nara Wildmane." },
        note = "",
        links = {},
        mapID = 88,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "horde-8",
        stepNumber = 8,
        levelBadge = "18–22",
        title = "Do Wailing Caverns (WC)",
        type = "dungeon",
        location = "The Barrens",
        dungeonName = "Wailing Caverns",
        details = {},
        note = "",
        links = {},
        mapID = 10,
        x = 0.4220,
        y = 0.6660,
    },
    {
        id = "horde-9",
        stepNumber = 9,
        levelBadge = "22–23",
        title = "Quest Until Level 23",
        type = "leveling",
        location = "The Barrens & Stonetalon Mountains",
        dungeonName = "",
        details = {},
        note = "",
        links = {},
        mapID = 10,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "horde-10",
        stepNumber = 10,
        levelBadge = "22–26",
        title = "Get Shadowfang Keep (SFK) Quests & Do SFK",
        type = "dungeon",
        location = "Silverpine Forest",
        dungeonName = "Shadowfang Keep",
        details = { "The Book of Ur: Undercity Apothecarium, Keeper Bel'dugur.", "Deathstalkers in Shadowfang: The Sepulcher, High Executor Hadrec.", "Arugal Must Die: The Sepulcher, Dalar Dawnweaver." },
        note = "",
        links = {},
        mapID = 21,
        x = 0.4480,
        y = 0.6780,
    },
    {
        id = "horde-11",
        stepNumber = 11,
        levelBadge = "25–28",
        title = "Questing Transition (Levels 25–28)",
        type = "leveling",
        location = "Ashenvale, Hillsbrad Foothills, Thousand Needles",
        dungeonName = "",
        details = {},
        note = "Bridge XP gap with RestedXP quest lines across Ashenvale and Hillsbrad Foothills.",
        links = {},
        mapID = 63,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "horde-12",
        stepNumber = 12,
        levelBadge = "~28",
        title = "Get Blackfathom Deeps (BFD) Quests & Do BFD",
        type = "dungeon",
        location = "Ashenvale",
        dungeonName = "Blackfathom Deeps",
        details = { "Essence of Aku'Mai: Ashenvale Zoram'gar Outpost, Je'neu Sancrea.", "Amongst the Ruins: Ashenvale Zoram'gar Outpost, Je'neu Sancrea.", "Crucial Tip: Make sure to turn right after the Gelihast turtle boss to pick up the campfire quest.", "Summon and defeat Baron Aquanis for the water globe quest item." },
        note = "",
        links = {},
        mapID = 63,
        x = 0.1420,
        y = 0.1440,
    },
    {
        id = "horde-13",
        stepNumber = 13,
        levelBadge = "28–30",
        title = "Get Wetlands Excavation Site Quests & Do ESW",
        type = "dungeon",
        location = "Wetlands",
        dungeonName = "Wetlands Excavation Site",
        details = {},
        note = "",
        links = {},
        mapID = 56,
        x = 0.3540,
        y = 0.4760,
    },
    {
        id = "horde-14",
        stepNumber = 14,
        levelBadge = "~30",
        title = "Get City of Dalaran Quests & Do Dalaran",
        type = "dungeon",
        location = "Alterac Mountains / Dalaran",
        dungeonName = "City of Dalaran",
        details = { "The Grave Knight: Melisara in Tarren Mill, Hillsbrad Foothills (level 24)." },
        note = "",
        links = {},
        mapID = 94,
        x = 0.2010,
        y = 0.7320,
    },
    {
        id = "horde-15",
        stepNumber = 15,
        levelBadge = "29–34",
        title = "Gnomeregan Prerequisites & Run",
        type = "dungeon",
        location = "Dun Morogh (Via Booty Bay Teleporter)",
        dungeonName = "Gnomeregan",
        details = { "Prereq Rig Wars: Orgrimmar Valley of Honor, Nogg.", "Use the Goblin Transporter in Booty Bay to teleport straight into Gnomeregan.", "Inside instance escort quest: Kernobee after the Clean Room.", "Cleanse Grime-Encrusted Object at the Sparklematic 5200.", "Grime-Encrusted Ring." },
        note = "",
        links = {},
        mapID = 27,
        x = 0.2450,
        y = 0.3950,
    },
    {
        id = "horde-16",
        stepNumber = 16,
        levelBadge = "30–35",
        title = "Razorfen Kraul (RFK) Quests & Run",
        type = "dungeon",
        location = "Southern Barrens",
        dungeonName = "Razorfen Kraul",
        details = { "A Vengeful Fate: Thunder Bluff near Main Lift, Auld Stonespire.", "Going, Going, Guano: Undercity Apothecarium, Master Apothecary Faranell.", "Blueleaf Tubers: Ratchet, Mebok Mizzyrix.", "Don't forget the Willix the Importer escort quest under the final boss platform." },
        note = "",
        links = {},
        mapID = 10,
        x = 0.4080,
        y = 0.8980,
    },
    {
        id = "horde-17",
        stepNumber = 17,
        levelBadge = "32–36",
        title = "Scarlet Monastery: Graveyard & Library",
        type = "dungeon",
        location = "Tirisfal Glades",
        dungeonName = "Scarlet Monastery (GY & Library)",
        details = { "Test of Faith: 6-part chain starting at Thousand Needles northeast cliff jump (unlocks Test of Lore in SM).", "Hearts of Zeal: Undercity Apothecarium.", "Check for Vorrel Sengrim cell in Graveyard after killing Interrogator Vishas.", "Into the Scarlet Monastery: Undercity Royal Quarter, Varimathras (level 33).", "Test of Lore: Undercity Apothecarium, Parqual Fintallas." },
        note = "Expect to be level ~36 upon finishing Library.",
        links = {},
        mapID = 18,
        x = 0.8520,
        y = 0.3160,
    },
    {
        id = "horde-18",
        stepNumber = 18,
        levelBadge = "36–40",
        title = "SM Armory & Cathedral",
        type = "dungeon",
        location = "Tirisfal Glades",
        dungeonName = "Scarlet Monastery (Armory & Cathedral)",
        details = { "No additional quests needed — turn in and continue the chain obtained from Library at level 34." },
        note = "",
        links = {},
        mapID = 18,
        x = 0.8540,
        y = 0.3160,
    },
    {
        id = "horde-19",
        stepNumber = 19,
        levelBadge = "~39",
        title = "Get Drowned City Quests & Do Drowned City",
        type = "dungeon",
        location = "",
        dungeonName = "Drowned City",
        details = {},
        note = "Expect to be around level 39.",
        links = {},
        mapID = 51,
        x = 0.6500,
        y = 0.3500,
    },
    {
        id = "horde-20",
        stepNumber = 20,
        levelBadge = "39–41",
        title = "Quest Until Level 41",
        type = "leveling",
        location = "Badlands & Stranglethorn Vale",
        dungeonName = "",
        details = {},
        note = "",
        links = {},
        mapID = 15,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "horde-21",
        stepNumber = 21,
        levelBadge = "41–43",
        title = "Get Krol'dok Quests & Do Krol'Dok",
        type = "dungeon",
        location = "",
        dungeonName = "Krol'dok",
        details = {},
        note = "",
        links = {},
        mapID = 66,
        x = 0.5500,
        y = 0.5500,
    },
    {
        id = "horde-22",
        stepNumber = 22,
        levelBadge = "40–44",
        title = "Razorfen Downs (RFD) Quests & Run",
        type = "dungeon",
        location = "Southern Barrens",
        dungeonName = "Razorfen Downs",
        details = { "Bring the End: Undercity Mage Quarter, Andrew Brownell.", "Unholy Alliance: Undercity Royal Quarter, Varimathras.", "A Host of Evil: Outside RFD instance entrance.", "Make sure to do the Belnistrasz escort quest." },
        note = "",
        links = {},
        mapID = 10,
        x = 0.4720,
        y = 0.9250,
    },
    {
        id = "horde-23",
        stepNumber = 23,
        levelBadge = "40–46",
        title = "Uldaman Prerequisites & Quests",
        type = "dungeon",
        location = "Badlands (Kargath)",
        dungeonName = "Uldaman",
        details = { "Badlands Reagent Run: Kargath, Jarkal Mossmeld (gives Uldaman Reagent and Badlands Reagent Run 2 dragons).", "Solution to Doom: Theldurin the Lost (middle south Badlands, outside instance).", "Turn in Sign of Hope right outside instance.", "Power Stones (30): Rigglefuzz in Badlands.", "Reclaimed Treasures: Krom Stoutarm outside instance.", "Agmond's Fate: Urns outside instance." },
        note = "",
        links = {},
        mapID = 15,
        x = 0.4400,
        y = 0.1250,
    },
    {
        id = "horde-24",
        stepNumber = 24,
        levelBadge = "44–48",
        title = "Zul'Farrak (ZF) Prerequisites & Quests",
        type = "dungeon",
        location = "Tanaris (Gadgetzan)",
        dungeonName = "Zul'Farrak",
        details = { "Tran'rek: Booty Bay, Krazek.", "Tabetha's Task: Tabetha in Dustwallow Marsh.", "Screecher Spirits: Steamwheedle Port, Yeh'kinya.", "Mallet of Zul'Farrak: Hinterlands Jintha'Alor elite area, kill Qiaga the Keeper for Sacred Mallet, take to top of pyramid altar.", "Troll Temper: Gadgetzan, Trenton Lighthammer.", "Scarab Shells: Gadgetzan, Tran'rek.", "Prophecy of Mosh'aru: Steamwheedle Port, Yeh'kinya.", "Divino-matic Rod: Gadgetzan, Chief Engineer Bilgewhizzle.", "Gahz'rilla: Shimmering Flats, Wizzle Brassbolts." },
        note = "Expect to be around level 47.",
        links = {},
        mapID = 71,
        x = 0.3920,
        y = 0.2130,
    },
    {
        id = "horde-25",
        stepNumber = 25,
        levelBadge = "46–50",
        title = "Get Maraudon Quests & Do All 3 Wings",
        type = "dungeon",
        location = "Desolace",
        dungeonName = "Maraudon",
        details = { "Twisted Evils: Desolace middle cliffs, Willow.", "The Pariah's Instructions: South Desolace, Centaur Pariah.", "Legends of Maraudon (Scepter): Orange side Maraudon, Cavindra.", "Shadowshard Fragments: Shadowprey Village.", "Vyletongue Corruption & Corruption of Earth and Seed: Shadowprey Village." },
        note = "",
        links = {},
        mapID = 66,
        x = 0.2920,
        y = 0.6250,
    },
    {
        id = "horde-26",
        stepNumber = 26,
        levelBadge = "~52",
        title = "Get Alcaz Prison Quests & Do Alcaz Prison",
        type = "dungeon",
        location = "Dustwallow Marsh",
        dungeonName = "Alcaz Prison",
        details = {},
        note = "Expect to be around level 52.",
        links = {},
        mapID = 70,
        x = 0.7750,
        y = 0.1780,
    },
    {
        id = "horde-27",
        stepNumber = 27,
        levelBadge = "47–55",
        title = "Endgame Prerequisite Quest Chains",
        type = "prep",
        location = "Searing Gorge / Burning Steppes / Tanaris / Feralas",
        dungeonName = "",
        details = { "BRD Taste of Flame: Searing Gorge, Cyrus Therepentous (starts at level 47).", "BRD Incendius!: Burning Steppes SE, Jalinda Sprig.", "BRD Kharan Mighthammer chain.", "ST The Sunken Temple: Stone Circle chain.", "ST The Ancient Eggs: Tanaris, Yeh'kinya -> top of Jintha'Alor -> The God Hakkar.", "ST Haze of Evil: Un'Goro Crater, Muigin -> Feralas." },
        note = "",
        links = {},
        mapID = 32,
        x = 0.5000,
        y = 0.5000,
    },
    {
        id = "horde-28",
        stepNumber = 28,
        levelBadge = "55",
        title = "Hit Level 55 Milestone",
        type = "milestone",
        location = "",
        dungeonName = "",
        details = {},
        note = "Level 55 is the baseline for entering the endgame dungeon cycle.",
        links = {},
        mapID = 0,
        x = 0.0000,
        y = 0.0000,
    },
    {
        id = "horde-29",
        stepNumber = 29,
        levelBadge = "50–55",
        title = "Get Sunken Temple Quests & Do Sunken Temple",
        type = "dungeon",
        location = "Swamp of Sorrows",
        dungeonName = "Sunken Temple",
        details = { "Jammal'an the Prophet: Hinterlands southern troll temple.", "Into the Temple of Atal'Hakkar.", "Shrine order: South, North, Southwest, Southeast, Northwest, Northeast -> then center large snake statue." },
        note = "",
        links = {},
        mapID = 51,
        x = 0.6980,
        y = 0.5360,
    },
    {
        id = "horde-30",
        stepNumber = 30,
        levelBadge = "52–56",
        title = "Get BRD Quests & Run BRD (First Half)",
        type = "dungeon",
        location = "Blackrock Mountain",
        dungeonName = "Blackrock Depths",
        details = { "Heart of the Mountain: Burning Steppes far north camp, Maxwort Uberglint.", "Dark Iron Legacy (Shadowforge Key): Franclorn Forgewright ghost at tomb.", "Incendius!: Burning Steppes, Jalinda Sprig.", "The Good Stuff: Burning Steppes, Jalinda Sprig." },
        note = "Stop halfway through on initial run (Prison, Arena, Key). Save Princess and Emperor runs for second trip.",
        links = {},
        mapID = 32,
        x = 0.3520,
        y = 0.8440,
    },
    {
        id = "horde-31",
        stepNumber = 31,
        levelBadge = "55–58",
        title = "Get LBRS Quests & Run Lower Blackrock Spire",
        type = "dungeon",
        location = "Blackrock Mountain",
        dungeonName = "Lower Blackrock Spire",
        details = { "En-Ay-Es-Tee-Why: Burning Steppes far north camp, Kibler (level 55).", "Kibler's Exotic Pets: Burning Steppes far north camp, Kibler (level 55).", "Final Tablets of Mosh'aru: Tanaris, Yeh'kinya.", "Put Her Down: Burning Steppes Helendis Riverhorn.", "Use the cage on a Worg Pup during Halycon encounter while pup is alive!" },
        note = "",
        links = {},
        mapID = 32,
        x = 0.3550,
        y = 0.8400,
    },
    {
        id = "horde-32",
        stepNumber = 32,
        levelBadge = "56–60",
        title = "Get Scholomance Quests & Run Scholomance",
        type = "dungeon",
        location = "Western Plaguelands (Caer Darrow)",
        dungeonName = "Scholomance",
        details = { "Plagued Hatchlings: Light's Hope Chapel, Betina Bigglezink.", "Doctor Theolen Krastinov: Caer Darrow, Eva Sarkhoff.", "Barov Family Fortune: Bulwark, Alexi Barov.", "Collect all 4 Barov Deeds in their designated rooms." },
        note = "",
        links = {},
        mapID = 22,
        x = 0.6920,
        y = 0.7300,
    },
    {
        id = "horde-33",
        stepNumber = 33,
        levelBadge = "58–60",
        title = "Get Stratholme Quests & Run Living & Undead Wings",
        type = "dungeon",
        location = "Eastern Plaguelands",
        dungeonName = "Stratholme",
        details = { "Houses of the Holy: Light's Hope Chapel, Leonid Barthalomew.", "The Restless Souls: Light's Hope Chapel, Caretaker Alen.", "The Great Fras Siabi: Light's Hope Chapel, Smokey LaRue.", "The Archivist: Light's Hope Chapel, Duke Nicholas Zverenhoff.", "Pick up Medallion of Faith from Aurius at entrance of UD church side. Run living side first, turn in Medallion, then push Undead Baron Rivendare side." },
        note = "",
        links = {},
        mapID = 23,
        x = 0.2720,
        y = 0.1160,
    },
    {
        id = "horde-34",
        stepNumber = 34,
        levelBadge = "60",
        title = "GRATS ON 60! Enter Phase 1 Raids & Endgame Progression",
        type = "milestone",
        location = "Azeroth",
        dungeonName = "",
        details = {},
        note = "Congratulations on reaching Level 60 in World of Warcraft: Forever!",
        links = {},
        mapID = 0,
        x = 0.0000,
        y = 0.0000,
    }
    },
}

WoWEternityAddon.CADBERRY_ALLIANCE_GUIDE = CADBERRY_ALLIANCE_GUIDE
WoWEternityAddon.CADBERRY_HORDE_GUIDE = CADBERRY_HORDE_GUIDE

local QUESTIE_GUIDE_ENRICHMENT = {
    ["ally-2"] = { questId = 2201, questName = "Find the Gems", starter = "Remains of a Paladin" },
    ["ally-3"] = { starter = "Westfall Campfire", custom = true, coords = { x = 37.2, y = 46.6 } },
    ["ally-4"] = { starter = "Old Ironforge Questgivers", custom = true, coords = { x = 50, y = 50 } },
    ["ally-5"] = { starter = "Custom Objective", custom = true, coords = { x = 64.8, y = 58.4 } },
    ["ally-6"] = { starter = "Custom Objective", custom = true, coords = { x = 61.2, y = 67.2 } },
    ["ally-7"] = { questId = 65, questName = "The Defias Brotherhood", starter = "Gryan Stoutmantle", coords = { x = 56.33, y = 47.52 } },
    ["ally-8"] = { questId = 155, questName = "The Defias Brotherhood", starter = "The Defias Traitor", coords = { x = 55.68, y = 47.5 } },
    ["ally-11"] = { questId = 391, questName = "The Stockade Riots", starter = "Warden Thelwater", coords = { x = 41.11, y = 58.09 } },
    ["ally-12"] = { starter = "Custom Objective", custom = true, coords = { x = 38.6, y = 52.4 } },
    ["ally-13"] = { questId = 1200, questName = "Blackfathom Villainy", starter = "Argent Guard Thaelrid" },
    ["ally-14"] = { questId = 1200, questName = "Blackfathom Villainy", starter = "Argent Guard Thaelrid" },
    ["ally-15"] = { starter = "Custom Objective", custom = true, coords = { x = 19.4, y = 78.4 } },
    ["ally-16"] = { questId = 2841, questName = "Rig Wars", starter = "Nogg", coords = { x = 75.99, y = 25.41 } },
    ["ally-17"] = { questId = 2841, questName = "Rig Wars", starter = "Nogg", coords = { x = 75.99, y = 25.41 } },
    ["ally-18"] = { questId = 2841, questName = "Rig Wars", starter = "Nogg", coords = { x = 75.99, y = 25.41 } },
    ["ally-19"] = { questId = 1053, questName = "In the Name of the Light", starter = "Raleigh the Devout", coords = { x = 51.47, y = 58.35 } },
    ["ally-20"] = { questId = 1053, questName = "In the Name of the Light", starter = "Raleigh the Devout", coords = { x = 51.47, y = 58.35 } },
    ["ally-21"] = { questId = 1108, questName = "Indurium", starter = "Martek the Exiled", coords = { x = 42.22, y = 52.69 } },
    ["ally-22"] = { questId = 1108, questName = "Indurium", starter = "Martek the Exiled", coords = { x = 42.22, y = 52.69 } },
    ["ally-23"] = { questId = 1053, questName = "In the Name of the Light", starter = "Raleigh the Devout", coords = { x = 51.47, y = 58.35 } },
    ["ally-24"] = { starter = "Custom Objective", custom = true, coords = { x = 42, y = 70 } },
    ["ally-26"] = { starter = "Custom Objective", custom = true, coords = { x = 71.2, y = 56.4 } },
    ["ally-27"] = { questId = 1104, questName = "Salt Flat Venom", starter = "Fizzle Brassbolts", coords = { x = 78.06, y = 77.13 } },
    ["ally-28"] = { questId = 1104, questName = "Salt Flat Venom", starter = "Fizzle Brassbolts", coords = { x = 78.06, y = 77.13 } },
    ["ally-29"] = { questId = 17, questName = "Uldaman Reagent Run", starter = "Ghak Healtouch", coords = { x = 37.07, y = 49.38 } },
    ["ally-30"] = { questId = 17, questName = "Uldaman Reagent Run", starter = "Ghak Healtouch", coords = { x = 37.07, y = 49.38 } },
    ["ally-31"] = { questId = 17, questName = "Uldaman Reagent Run", starter = "Ghak Healtouch", coords = { x = 37.07, y = 49.38 } },
    ["ally-32"] = { questId = 2768, questName = "Divino-matic Rod", starter = "Chief Engineer Bilgewhizzle", coords = { x = 52.46, y = 28.51 } },
    ["ally-33"] = { questId = 2768, questName = "Divino-matic Rod", starter = "Chief Engineer Bilgewhizzle", coords = { x = 52.46, y = 28.51 } },
    ["ally-34"] = { questId = 2768, questName = "Divino-matic Rod", starter = "Chief Engineer Bilgewhizzle", coords = { x = 52.46, y = 28.51 } },
    ["ally-35"] = { questId = 7044, questName = "Legends of Maraudon", starter = "Cavindra", coords = { x = 32.1, y = 63.96 } },
    ["ally-36"] = { starter = "Custom Objective", custom = true, coords = { x = 77, y = 16 } },
    ["ally-37"] = { questId = 1448, questName = "In Search of The Temple", starter = "Brohann Caskbelly", coords = { x = 64.33, y = 20.63 } },
    ["ally-39"] = { questId = 1448, questName = "In Search of The Temple", starter = "Brohann Caskbelly", coords = { x = 64.33, y = 20.63 } },
    ["ally-40"] = { questId = 3821, questName = "Dreadmaul Rock", starter = "Thal'trak Proudtusk", coords = { x = 3.36, y = 48.06 } },
    ["ally-41"] = { questId = 4722, questName = "Beached Sea Turtle", starter = "Gwennyth Bly'Leggonde", coords = { x = 36.62, y = 45.59 } },
    ["ally-42"] = { questId = 5381, questName = "Hand of Iruxos", starter = "Taiga Wisemane", coords = { x = 25.82, y = 68.21 } },
    ["ally-43"] = { questId = 5123, questName = "The Final Piece", starter = "Donova Snowden", coords = { x = 31.27, y = 45.16 } },
    ["horde-2"] = { questId = 842, questName = "Crossroads Conscription", starter = "Kargal Battlescar", coords = { x = 62.26, y = 19.38 } },
    ["horde-3"] = { starter = "Westfall Campfire", custom = true, coords = { x = 37.2, y = 46.6 } },
    ["horde-4"] = { questId = 5722, questName = "Searching for the Lost Satchel", starter = "Rahauro", coords = { x = 70.14, y = 29.52 } },
    ["horde-5"] = { questId = 5722, questName = "Searching for the Lost Satchel", starter = "Rahauro", coords = { x = 70.14, y = 29.52 } },
    ["horde-6"] = { starter = "Custom Objective", custom = true, coords = { x = 61.2, y = 67.2 } },
    ["horde-7"] = { questId = 903, questName = "Prowlers of the Barrens", starter = "Sergra Darkthorn", coords = { x = 52.23, y = 31.01 } },
    ["horde-8"] = { questId = 903, questName = "Prowlers of the Barrens", starter = "Sergra Darkthorn", coords = { x = 52.23, y = 31.01 } },
    ["horde-10"] = { questId = 1014, questName = "Arugal Must Die", starter = "Dalar Dawnweaver", coords = { x = 44.2, y = 39.81 } },
    ["horde-12"] = { questId = 1205, questName = "Deadmire", starter = "Melor Stonehoof", coords = { x = 61.54, y = 80.92 } },
    ["horde-13"] = { starter = "Custom Objective", custom = true, coords = { x = 38.6, y = 52.4 } },
    ["horde-14"] = { starter = "Custom Objective", custom = true, coords = { x = 19.4, y = 78.4 } },
    ["horde-15"] = { questId = 2841, questName = "Rig Wars", starter = "Nogg", coords = { x = 75.99, y = 25.41 } },
    ["horde-16"] = { questId = 1108, questName = "Indurium", starter = "Martek the Exiled", coords = { x = 42.22, y = 52.69 } },
    ["horde-17"] = { questId = 1053, questName = "In the Name of the Light", starter = "Raleigh the Devout", coords = { x = 51.47, y = 58.35 } },
    ["horde-18"] = { questId = 1053, questName = "In the Name of the Light", starter = "Raleigh the Devout", coords = { x = 51.47, y = 58.35 } },
    ["horde-19"] = { starter = "Custom Objective", custom = true, coords = { x = 42, y = 70 } },
    ["horde-21"] = { starter = "Custom Objective", custom = true, coords = { x = 71.2, y = 56.4 } },
    ["horde-22"] = { questId = 1104, questName = "Salt Flat Venom", starter = "Fizzle Brassbolts", coords = { x = 78.06, y = 77.13 } },
    ["horde-23"] = { questId = 17, questName = "Uldaman Reagent Run", starter = "Ghak Healtouch", coords = { x = 37.07, y = 49.38 } },
    ["horde-24"] = { questId = 2768, questName = "Divino-matic Rod", starter = "Chief Engineer Bilgewhizzle", coords = { x = 52.46, y = 28.51 } },
    ["horde-25"] = { questId = 7044, questName = "Legends of Maraudon", starter = "Cavindra", coords = { x = 32.1, y = 63.96 } },
    ["horde-26"] = { starter = "Custom Objective", custom = true, coords = { x = 77, y = 16 } },
    ["horde-27"] = { questId = 1448, questName = "In Search of The Temple", starter = "Brohann Caskbelly", coords = { x = 64.33, y = 20.63 } },
    ["horde-29"] = { questId = 1448, questName = "In Search of The Temple", starter = "Brohann Caskbelly", coords = { x = 64.33, y = 20.63 } },
    ["horde-30"] = { questId = 3821, questName = "Dreadmaul Rock", starter = "Thal'trak Proudtusk", coords = { x = 3.36, y = 48.06 } },
    ["horde-31"] = { questId = 4722, questName = "Beached Sea Turtle", starter = "Gwennyth Bly'Leggonde", coords = { x = 36.62, y = 45.59 } },
    ["horde-32"] = { questId = 5381, questName = "Hand of Iruxos", starter = "Taiga Wisemane", coords = { x = 25.82, y = 68.21 } },
    ["horde-33"] = { questId = 5123, questName = "The Final Piece", starter = "Donova Snowden", coords = { x = 31.27, y = 45.16 } },
}

function WoWEternityAddon:EnrichGuideWithQuestieData()
    local guides = { self.CADBERRY_ALLIANCE_GUIDE, self.CADBERRY_HORDE_GUIDE }
    for _, guide in ipairs(guides) do
        if guide and guide.steps then
            for _, step in ipairs(guide.steps) do
                local meta = QUESTIE_GUIDE_ENRICHMENT[step.id]
                if meta then
                    step.questieQuestId = meta.questId
                    step.questieQuestName = meta.questName
                    step.questieStarter = meta.starter
                    step.questieCustom = meta.custom
                    step.questieCoords = meta.coords
                    if meta.coords and (step.x == 0.5 and step.y == 0.5) then
                        step.x = meta.coords.x / 100
                        step.y = meta.coords.y / 100
                    end
                end
            end
        end
    end
end
WoWEternityAddon.QUESTIE_GUIDE_ENRICHMENT = QUESTIE_GUIDE_ENRICHMENT
WoWEternityAddon:EnrichGuideWithQuestieData()

local TABS = {
    { id = "Account", label = "Account" },
    { id = "Char", label = "Char" },
    { id = "Gear Planner", label = "Gear Planner" },
    { id = "BIS-Lists", label = "BIS-Lists" },
    { id = "Leveling", label = "Leveling" },
    { id = "Settings", label = "Settings" },
}

function WoWEternityAddon:SelectTab(tabId)
    if not self.mainFrame or not self.tabFrames then return end
    self.currentTab = tabId

    for _, t in ipairs(TABS) do
        local f = self.tabFrames[t.id]
        local btn = self.tabButtons[t.id]
        if f and btn then
            if t.id == tabId then
                f:Show()
                btn.text:SetTextColor(1.0, 0.82, 0.0, 1)
                if btn.SetBackdropColor then
                    btn:SetBackdropColor(0.14, 0.17, 0.26, 1)
                    btn:SetBackdropBorderColor(0.90, 0.80, 0.50, 1)
                end
            else
                f:Hide()
                btn.text:SetTextColor(0.61, 0.64, 0.69, 1)
                if btn.SetBackdropColor then
                    btn:SetBackdropColor(0.06, 0.08, 0.12, 0.85)
                    btn:SetBackdropBorderColor(0.18, 0.22, 0.32, 0.8)
                end
            end
        end
    end

    self:UpdateMainFrameView(tabId)
end

function WoWEternityAddon:ToggleSettingsFrame(targetTab)
    if not CreateFrame then return end
    if not self.mainFrame then
        self:CreateMainFrame()
    end

    if targetTab then
        self:SelectTab(targetTab)
        if not self.mainFrame:IsShown() then
            self.mainFrame:Show()
        end
    else
        if self.mainFrame:IsShown() then
            self.mainFrame:Hide()
        else
            self:UpdateMainFrameView()
            self.mainFrame:Show()
        end
    end
end

-- ----------------------------------------------------------------------------
-- Tab 1: Account
-- ----------------------------------------------------------------------------
function WoWEternityAddon:CreateAccountTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()
    self.tabFrames["Account"] = tab

    -- Card 1: Account Diagnostics
    local diagCard = CreateCard(tab)
    diagCard:SetPoint("TOPLEFT", 0, 0)
    diagCard:SetPoint("TOPRIGHT", 0, 0)
    diagCard:SetHeight(145)

    local title1 = diagCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title1:SetPoint("TOPLEFT", 12, -10)
    title1:SetText("|cffe6cc80Account & Installation Diagnostics|r")

    tab.playerText = diagCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.playerText:SetPoint("TOPLEFT", 12, -30)
    tab.playerText:SetText("")

    tab.charText = diagCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.charText:SetPoint("TOPLEFT", 12, -48)
    tab.charText:SetText("")

    tab.svText = diagCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tab.svText:SetPoint("TOPLEFT", 12, -66)
    tab.svText:SetPoint("TOPRIGHT", -12, -66)
    tab.svText:SetJustifyH("LEFT")
    tab.svText:SetText("")

    tab.checksumText = diagCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.checksumText:SetPoint("TOPLEFT", 12, -84)
    tab.checksumText:SetText("")

    tab.syncInfoText = diagCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.syncInfoText:SetPoint("TOPLEFT", 12, -102)
    tab.syncInfoText:SetText("")

    tab.bisCountText = diagCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.bisCountText:SetPoint("TOPLEFT", 12, -120)
    tab.bisCountText:SetText("")

    -- Card 2: Synchronization Quick Guide
    local guideCard = CreateCard(tab)
    guideCard:SetPoint("TOPLEFT", 0, -153)
    guideCard:SetPoint("TOPRIGHT", 0, -153)
    guideCard:SetHeight(190)

    local title2 = guideCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title2:SetPoint("TOPLEFT", 12, -10)
    title2:SetText("|cffe6cc80How Synchronization Works|r")

    local g1 = guideCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    g1:SetPoint("TOPLEFT", 12, -32)
    g1:SetPoint("TOPRIGHT", -12, -32)
    g1:SetJustifyH("LEFT")
    g1:SetText("|cffffd1001. BiS Tooltips (Desktop -> WoW):|r\nThe desktop client writes BiS lists to SavedVariables/WoW Eternity Addon.lua.\nType |cffffffff/reload|r in WoW to activate color-coded item tags and audio alerts.")

    local g2 = guideCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    g2:SetPoint("TOPLEFT", 12, -82)
    g2:SetPoint("TOPRIGHT", -12, -82)
    g2:SetJustifyH("LEFT")
    g2:SetText("|cffffd1002. Character & Stats (WoW -> Desktop):|r\nClick 'Sync Character Data' in the Char tab (or /wea sync).\nRun |cffffffff/reload|r to flush files to disk for automatic background ingestion.")

    local g3 = guideCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    g3:SetPoint("TOPLEFT", 12, -132)
    g3:SetPoint("TOPRIGHT", -12, -132)
    g3:SetJustifyH("LEFT")
    g3:SetText("|cffffd1003. Automated Addon Hot-Updates:|r\nThe desktop app checks and auto-pushes latest companion addon files to your\nInterface/AddOns folder whenever a new version is released.")

    -- Bottom Actions
    CreateStyledButton(tab, "Verify Database Integrity", 240, 28, function()
        local isValid, calc, decl = WoWEternityAddon:VerifyIntegrity()
        if isValid then
            WoWEternityAddon:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Checksum OK: %d (Adler-32 verified).", calc))
        else
            WoWEternityAddon:Print(string.format("|cffff2020[WoW Eternity Addon] Checksum mismatch! Declared: %d, Calc: %d.|r", decl, calc))
        end
        WoWEternityAddon:UpdateAccountTab()
    end):SetPoint("BOTTOMLEFT", 0, 0)

    CreateStyledButton(tab, "Reload UI (/reload)", 240, 28, function()
        ReloadUI()
    end):SetPoint("BOTTOMRIGHT", 0, 0)
end

function WoWEternityAddon:UpdateAccountTab()
    local tab = self.tabFrames and self.tabFrames["Account"]
    if not tab or not tab:IsShown() then return end

    local name = UnitName("player") or "Unknown"
    local realm = (GetRealmName and GetRealmName()) or "Unknown"
    local localizedClass, classFileName = UnitClass("player")
    local localizedRace = (UnitRace and UnitRace("player")) or ""
    local level = (UnitLevel and UnitLevel("player")) or 60

    local colorCode = "ffffff"
    if RAID_CLASS_COLORS and classFileName and RAID_CLASS_COLORS[classFileName] then
        colorCode = RAID_CLASS_COLORS[classFileName].colorStr:sub(3)
    end

    tab.playerText:SetText(string.format("Player: |cff%s%s|r   Realm: |cffffffff%s|r", colorCode, name, realm))
    tab.charText:SetText(string.format("Character: |cffffffffLevel %d %s %s|r", level, localizedRace, localizedClass or ""))
    tab.svText:SetText(string.format("SavedVariables: |cff9ca3afWTF/Account/<Account>/SavedVariables/WoW Eternity Addon.lua|r"))

    local isValid, calc, decl = self:VerifyIntegrity()
    local count = self:GetItemCount()
    local spec = (WoWEternityAddonDB and WoWEternityAddonDB.active_spec and WoWEternityAddonDB.active_spec ~= "") and WoWEternityAddonDB.active_spec or "All Specs"

    if decl > 0 then
        if isValid then
            tab.checksumText:SetText(string.format("Integrity: |cff00ff00[Verified Valid]|r (Adler-32: %d)", calc))
        else
            tab.checksumText:SetText(string.format("Integrity: |cffff2020[Checksum Mismatch!]|r (Decl: %d, Calc: %d)", decl, calc))
        end
    else
        tab.checksumText:SetText("Integrity: |cffffcc00[Not Yet Synced]|r (Launch desktop app to sync BiS list)")
    end

    local lastSync = WoWEternityAddonDB and WoWEternityAddonDB.last_sync or 0
    if lastSync > 0 and date then
        tab.syncInfoText:SetText(string.format("Last BiS Sync: |cffffffff%s|r (Spec: |cffffd100%s|r)", date("%Y-%m-%d %H:%M:%S", lastSync), spec))
    else
        tab.syncInfoText:SetText(string.format("Active BiS Spec Filter: |cffffd100%s|r", spec))
    end

    local lastExp = WoWEternityAddonDB and WoWEternityAddonDB.character_export and WoWEternityAddonDB.character_export.exported_at_iso
    if lastExp and lastExp ~= "" then
        tab.bisCountText:SetText(string.format("BiS Items: |cffe6cc80%d|r   Last Export: |cff60a5fa%s|r", count, lastExp:sub(1, 16):gsub("T", " ")))
    else
        tab.bisCountText:SetText(string.format("BiS Items Tracked: |cffe6cc80%d|r   Character Export: |cffffcc00None|r", count))
    end
end

-- ----------------------------------------------------------------------------
-- Tab 2: Char
-- ----------------------------------------------------------------------------
function WoWEternityAddon:CreateCharTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()
    self.tabFrames["Char"] = tab

    -- Card 1: Character Header Card
    local headerCard = CreateCard(tab)
    headerCard:SetPoint("TOPLEFT", 0, 0)
    headerCard:SetPoint("TOPRIGHT", 0, 0)
    headerCard:SetHeight(84)

    tab.charNameText = headerCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    tab.charNameText:SetPoint("TOPLEFT", 12, -10)
    tab.charNameText:SetText("")

    tab.charSubText = headerCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tab.charSubText:SetPoint("TOPLEFT", 12, -30)
    tab.charSubText:SetText("")

    tab.charProgressText = headerCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.charProgressText:SetPoint("TOPLEFT", 12, -50)
    tab.charProgressText:SetPoint("TOPRIGHT", -12, -50)
    tab.charProgressText:SetJustifyH("LEFT")
    tab.charProgressText:SetText("")

    tab.charGearText = headerCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.charGearText:SetPoint("TOPRIGHT", -12, -12)
    tab.charGearText:SetText("")

    -- Card 2: Unbuffed Base Stats Grid
    local statsCard = CreateCard(tab)
    statsCard:SetPoint("TOPLEFT", 0, -90)
    statsCard:SetPoint("TOPRIGHT", 0, -90)
    statsCard:SetHeight(160)

    local statsTitle = statsCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsTitle:SetPoint("TOPLEFT", 12, -8)
    statsTitle:SetText("|cffe6cc80Unbuffed Combat Stats (Base + Gear, Buffs Stripped)|r")

    tab.col1Stats = statsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.col1Stats:SetPoint("TOPLEFT", 12, -28)
    tab.col1Stats:SetJustifyH("LEFT")
    tab.col1Stats:SetText("")

    tab.col2Stats = statsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.col2Stats:SetPoint("TOPLEFT", 175, -28)
    tab.col2Stats:SetJustifyH("LEFT")
    tab.col2Stats:SetText("")

    tab.col3Stats = statsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.col3Stats:SetPoint("TOPLEFT", 335, -28)
    tab.col3Stats:SetJustifyH("LEFT")
    tab.col3Stats:SetText("")

    -- Card 3: Professions
    local profCard = CreateCard(tab)
    profCard:SetPoint("TOPLEFT", 0, -250)
    profCard:SetPoint("TOPRIGHT", 0, -250)
    profCard:SetHeight(65)

    local profTitle = profCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profTitle:SetPoint("TOPLEFT", 12, -8)
    profTitle:SetText("|cffe6cc80Professions & Secondary Skills|r")

    tab.profText = profCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.profText:SetPoint("TOPLEFT", 12, -28)
    tab.profText:SetPoint("TOPRIGHT", -12, -28)
    tab.profText:SetJustifyH("LEFT")
    tab.profText:SetText("")

    -- Bottom action & status
    tab.statusText = tab:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tab.statusText:SetPoint("BOTTOMLEFT", 4, 38)
    tab.statusText:SetText("")

    CreateStyledButton(tab, "Sync Character Data to Desktop", 325, 30, function()
        WoWEternityAddon:ExportCharacter()
        WoWEternityAddon:UpdateCharTab()
    end):SetPoint("BOTTOMLEFT", 0, 0)

    CreateStyledButton(tab, "Reload UI (/reload)", 155, 30, function()
        ReloadUI()
    end):SetPoint("BOTTOMRIGHT", 0, 0)
end

function WoWEternityAddon:UpdateCharTab()
    local tab = self.tabFrames and self.tabFrames["Char"]
    if not tab or not tab:IsShown() then return end

    local name = UnitName("player") or "Unknown"
    local localizedClass, classFileName = UnitClass("player")
    local localizedRace = (UnitRace and UnitRace("player")) or ""
    local level = (UnitLevel and UnitLevel("player")) or 60
    local realm = (GetRealmName and GetRealmName()) or ""
    local guild = (GetGuildInfo and GetGuildInfo("player")) or ""

    local colorCode = "ffffff"
    if RAID_CLASS_COLORS and classFileName and RAID_CLASS_COLORS[classFileName] then
        colorCode = RAID_CLASS_COLORS[classFileName].colorStr:sub(3)
    end

    local exp = WoWEternityAddonDB and WoWEternityAddonDB.character_export
    local equippedCount = exp and exp.equipped_count or 0
    local avgIlvl = exp and exp.avg_ilvl or 0.0

    tab.charNameText:SetText(string.format("|cffe6cc80[%.1f]|r |cff%s%s|r  |cffffffffLvl %d %s %s|r", avgIlvl, colorCode, name, level, localizedRace, localizedClass or ""))
    local spec = exp and exp.spec_name or localizedClass or "Spec"
    local talents = exp and exp.talents or "0/0/0"
    tab.charSubText:SetText(string.format("%s  ·  %s  ·  |cffffd100%s (%s)|r", realm, guild ~= "" and ("<" .. guild .. ">") or "No Guild", spec, talents))

    tab.charGearText:SetText(string.format("Avg iLvl: |cffe6cc80%.1f|r\nEquipped: |cffffffff%d / 19|r", avgIlvl, equippedCount))

    if tab.charProgressText then
        tab.charProgressText:SetText(
            string.format("|cffe6cc80iLvl:|r |cffffffff%.1f|r    |cffe6cc80Phase 1:|r |cffffffffBarrow Deeps, Hyjal Summit, Onyxia's Lair|r\n|cffe6cc80Parse:|r |cffffffffRelease Nov. 4th|r    |cffe6cc80Progress:|r |cffffffffRelease Nov. 4th|r", avgIlvl)
        )
    end


    local s = exp and exp.stats
    if s then
        tab.col1Stats:SetText(string.format(
            "|cffffd100Attributes|r\n" ..
            "Health: |cffffffff%d|r\n" ..
            "Power: |cffffffff%d|r\n" ..
            "Strength: |cffffffff%d|r\n" ..
            "Agility: |cffffffff%d|r\n" ..
            "Stamina: |cffffffff%d|r\n" ..
            "Intellect: |cffffffff%d|r\n" ..
            "Spirit: |cffffffff%d|r\n" ..
            "Armor: |cffffffff%d|r",
            s.max_health or 0, s.max_power or 0,
            s.strength or 0, s.agility or 0, s.stamina or 0,
            s.intellect or 0, s.spirit or 0, s.armor or 0
        ))

        tab.col2Stats:SetText(string.format(
            "|cffffd100Offense|r\n" ..
            "Attack Power: |cffffffff%d|r\n" ..
            "Crit Chance: |cffffffff%.2f%%|r\n" ..
            "Ranged AP: |cffffffff%d|r\n" ..
            "Ranged Crit: |cffffffff%.2f%%|r\n" ..
            "Hit Modifier: |cffffffff+%d%%|r\n" ..
            "Spell Damage: |cffffffff%d|r\n" ..
            "Healing Bonus: |cffffffff%d|r\n" ..
            "Spell Crit: |cffffffff%.2f%%|r",
            s.attack_power or 0, s.crit_chance or 0,
            s.ranged_attack_power or 0, s.ranged_crit_chance or 0,
            s.hit_modifier or 0, s.spell_damage or 0,
            s.healing_power or 0, s.spell_crit_chance or 0
        ))

        local res = s.resists or {}
        tab.col3Stats:SetText(string.format(
            "|cffffd100Mitigation & Resists|r\n" ..
            "Dodge / Parry: |cffffffff%.1f%% / %.1f%%|r\n" ..
            "Block: |cffffffff%.1f%%|r\n" ..
            "Fire Resist: |cffffffff%d|r\n" ..
            "Frost Resist: |cffffffff%d|r\n" ..
            "Nature Resist: |cffffffff%d|r\n" ..
            "Shadow Resist: |cffffffff%d|r\n" ..
            "Arcane Resist: |cffffffff%d|r\n" ..
            "Holy Resist: |cffffffff%d|r",
            s.dodge_chance or 0, s.parry_chance or 0,
            s.block_chance or 0,
            res.fire or 0, res.frost or 0, res.nature or 0,
            res.shadow or 0, res.arcane or 0, res.holy or 0
        ))
    else
        tab.col1Stats:SetText("|cff9ca3afClick 'Sync Character Data' below to read live combat stats.|r")
        tab.col2Stats:SetText("")
        tab.col3Stats:SetText("")
    end

    -- Professions
    if exp and exp.professions and #exp.professions > 0 then
        local profLines = {}
        for _, p in ipairs(exp.professions) do
            local tag = p.is_secondary and "|cff9ca3af(Secondary)|r" or "|cff00ff00(Primary)|r"
            table.insert(profLines, string.format("%s: |cffffffff%d/%d|r %s", p.name, p.rank, p.max_rank, tag))
        end
        tab.profText:SetText(table.concat(profLines, "   ·   "))
    else
        tab.profText:SetText("|cff9ca3afNo professions exported yet.|r")
    end

    if exp and exp.exported_at_iso and exp.exported_at_iso ~= "" then
        tab.statusText:SetText(string.format("Last Export: |cffffffff%s|r · Ready for Desktop Sync · Type |cffffd100/reload|r to flush to disk",
            exp.exported_at_iso:sub(1, 16):gsub("T", " ")))
    else
        tab.statusText:SetText("|cffffcc00No character export saved yet. Click Sync Character Data to export.|r")
    end
end

-- ----------------------------------------------------------------------------
-- Tab 3: Gear Planner
-- ----------------------------------------------------------------------------
function WoWEternityAddon:CreateGearPlannerTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()
    self.tabFrames["Gear Planner"] = tab

    -- Top Header Card
    local headerCard = CreateCard(tab)
    headerCard:SetPoint("TOPLEFT", 0, 0)
    headerCard:SetPoint("TOPRIGHT", 0, 0)
    headerCard:SetHeight(28)

    local title = headerCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 12, 0)
    title:SetText("|cffe6cc80Equipped Gear (Mouseover item for full in-game tooltip)|r")

    tab.ilvlSummary = headerCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.ilvlSummary:SetPoint("RIGHT", -12, 0)
    tab.ilvlSummary:SetText("")

    -- ScrollFrame for 19 Equipment Slots
    local scrollFrame = CreateFrame("ScrollFrame", "WoWEternityAddonGearScrollFrame", tab, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 110)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(470, 390)
    scrollFrame:SetScrollChild(scrollChild)
    tab.gearChild = scrollChild

    -- Create 19 slot rows
    tab.slotRows = {}
    for i, slot in ipairs(INVENTORY_SLOTS) do
        local row = CreateFrame("Button", nil, scrollChild, GetBackdropTemplate())
        row:SetSize(465, 19)
        row:SetPoint("TOPLEFT", 2, -(i - 1) * 20)
        ApplyBackdrop(row, 0.04, 0.05, 0.08, 0.6, 0.12, 0.15, 0.22, 0.6)

        local slotLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        slotLabel:SetPoint("LEFT", 8, 0)
        slotLabel:SetWidth(80)
        slotLabel:SetJustifyH("LEFT")
        slotLabel:SetText(slot.name)
        row.slotLabel = slotLabel

        local itemName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemName:SetPoint("LEFT", 92, 0)
        itemName:SetPoint("RIGHT", -80, 0)
        itemName:SetJustifyH("LEFT")
        row.itemName = itemName

        local ilvlBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ilvlBadge:SetPoint("RIGHT", -8, 0)
        ilvlBadge:SetJustifyH("RIGHT")
        row.ilvlBadge = ilvlBadge

        row.slotId = slot.id
        row:SetScript("OnEnter", function(self)
            if not GameTooltip or not self.slotId then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local hasItem = GameTooltip:SetInventoryItem("player", self.slotId)
            if not hasItem and self.itemLink then
                GameTooltip:SetHyperlink(self.itemLink)
            end
            GameTooltip:Show()
            if self.SetBackdropColor then
                self:SetBackdropColor(0.12, 0.15, 0.22, 0.9)
            end
        end)

        row:SetScript("OnLeave", function(self)
            if GameTooltip then GameTooltip:Hide() end
            if self.SetBackdropColor then
                self:SetBackdropColor(0.04, 0.05, 0.08, 0.6)
            end
        end)

        tab.slotRows[slot.name] = row
    end

    -- Bottom URL Export Card
    local urlCard = CreateCard(tab)
    urlCard:SetPoint("BOTTOMLEFT", 0, 0)
    urlCard:SetPoint("BOTTOMRIGHT", 0, 0)
    urlCard:SetHeight(102)

    local urlTitle = urlCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    urlTitle:SetPoint("TOPLEFT", 12, -8)
    urlTitle:SetText("|cffe6cc80Web Gear Planner Link|r")

    local urlSub = urlCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    urlSub:SetPoint("TOPLEFT", 12, -26)
    urlSub:SetText("Click in box below and press |cffffd100Ctrl+C|r to copy your build link to share or open in browser:")

    local editBox = CreateFrame("EditBox", "WoWEternityAddonUrlEditBox", urlCard, GetBackdropTemplate())
    editBox:SetSize(465, 24)
    editBox:SetPoint("TOPLEFT", 12, -44)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    ApplyBackdrop(editBox, 0.02, 0.02, 0.04, 0.95, 0.25, 0.30, 0.42, 1)
    editBox:SetTextInsets(6, 6, 0, 0)

    editBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    tab.urlEditBox = editBox

    CreateStyledButton(urlCard, "Update Build Link", 230, 22, function()
        WoWEternityAddon:UpdateGearPlannerTab()
        WoWEternityAddon:Print("|cffe6cc80[WoW Eternity Addon]|r Gear planner URL updated.")
    end):SetPoint("BOTTOMLEFT", 12, 8)

    CreateStyledButton(urlCard, "Reload UI (/reload)", 225, 22, function()
        ReloadUI()
    end):SetPoint("BOTTOMRIGHT", -12, 8)
end

function WoWEternityAddon:UpdateGearPlannerTab()
    local tab = self.tabFrames and self.tabFrames["Gear Planner"]
    if not tab or not tab:IsShown() then return end

    local exp = WoWEternityAddonDB and WoWEternityAddonDB.character_export
    local equipment = exp and exp.equipment or {}

    local totalIlvl = 0
    local equippedCount = 0

    for _, slot in ipairs(INVENTORY_SLOTS) do
        local row = tab.slotRows[slot.name]
        if row then
            local eq = equipment[slot.name]
            local link = (GetInventoryItemLink and GetInventoryItemLink("player", slot.id)) or (eq and eq.link) or nil
            local itemId = (GetInventoryItemID and GetInventoryItemID("player", slot.id)) or (eq and eq.item_id) or 0

            row.itemLink = link

            if itemId > 0 or link then
                local itemName, itemQuality, itemLevel = self:GetItemInfoSafe(link or itemId, slot.id)
                local qualityColor = "ffffff"
                if ITEM_QUALITY_COLORS and itemQuality and ITEM_QUALITY_COLORS[itemQuality] then
                    qualityColor = ITEM_QUALITY_COLORS[itemQuality].hex or "ffffff"
                    if qualityColor:sub(1, 2) == "|c" then qualityColor = qualityColor:sub(5) end
                end

                row.itemName:SetText(string.format("|cff%s%s|r", qualityColor, itemName))
                row.ilvlBadge:SetText(itemLevel > 0 and string.format("[ilvl %d]", itemLevel) or "")

                totalIlvl = totalIlvl + (itemLevel or 0)
                equippedCount = equippedCount + 1
            else
                row.itemName:SetText("|cff6b7280<Empty Slot>|r")
                row.ilvlBadge:SetText("")
            end
        end
    end

    local avgIlvl = equippedCount > 0 and math.floor((totalIlvl / equippedCount) * 10) / 10 or 0
    tab.ilvlSummary:SetText(string.format("Avg iLvl: |cffe6cc80%.1f|r  ·  Equipped: |cffffffff%d/19|r", avgIlvl, equippedCount))

    if tab.urlEditBox then
        tab.urlEditBox:SetText(self:GetBuildUrl())
    end
end

-- ----------------------------------------------------------------------------
-- Tab 4: BIS-Lists
-- ----------------------------------------------------------------------------
function WoWEternityAddon:CreateBisListsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()
    self.tabFrames["BIS-Lists"] = tab

    -- Top Header Card
    local headerCard = CreateCard(tab)
    headerCard:SetPoint("TOPLEFT", 0, 0)
    headerCard:SetPoint("TOPRIGHT", 0, 0)
    headerCard:SetHeight(32)

    tab.summaryText = headerCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.summaryText:SetPoint("LEFT", 12, 0)
    tab.summaryText:SetText("")

    -- ScrollFrame for BiS Items
    local scrollFrame = CreateFrame("ScrollFrame", "WoWEternityAddonBisScrollFrame", tab, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 38)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(470, 300)
    scrollFrame:SetScrollChild(scrollChild)
    tab.bisChild = scrollChild

    tab.emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.emptyText:SetPoint("TOP", 0, -40)
    tab.emptyText:SetWidth(420)
    tab.emptyText:SetJustifyH("CENTER")
    tab.emptyText:SetText("")

    tab.bisRows = {}

    -- Bottom Action Bar
    CreateStyledButton(tab, "Verify BiS Integrity", 240, 28, function()
        local isValid, calc, decl = WoWEternityAddon:VerifyIntegrity()
        if isValid then
            WoWEternityAddon:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r BiS integrity OK (Adler-32: %d).", calc))
        else
            WoWEternityAddon:Print(string.format("|cffff2020[WoW Eternity Addon] BiS integrity check failed! Declared: %d, Calculated: %d.|r", decl, calc))
        end
    end):SetPoint("BOTTOMLEFT", 0, 0)

    CreateStyledButton(tab, "Reload UI (/reload)", 240, 28, function()
        ReloadUI()
    end):SetPoint("BOTTOMRIGHT", 0, 0)
end

function WoWEternityAddon:UpdateBisListsTab()
    local tab = self.tabFrames and self.tabFrames["BIS-Lists"]
    if not tab or not tab:IsShown() then return end

    local count = self:GetItemCount()
    local spec = (WoWEternityAddonDB and WoWEternityAddonDB.active_spec and WoWEternityAddonDB.active_spec ~= "") and WoWEternityAddonDB.active_spec or "All Specs"
    tab.summaryText:SetText(string.format("Synced BiS Items: |cffe6cc80%d|r  ·  Active Filter: |cffffd100%s|r", count, spec))

    local items = WoWEternityAddonDB and WoWEternityAddonDB.items
    if not items or count == 0 then
        tab.emptyText:SetText("|cffffcc00No BiS items currently synchronized.|r\n\nLaunch the WoW Eternity desktop application and connect your\ncharacter build to automatically sync BiS lists to this addon.")
        tab.emptyText:Show()
        for _, row in ipairs(tab.bisRows) do row:Hide() end
        return
    end

    tab.emptyText:Hide()

    local sortedIds = {}
    for itemId in pairs(items) do
        table.insert(sortedIds, itemId)
    end
    table.sort(sortedIds)

    local rowIndex = 0
    for _, itemId in ipairs(sortedIds) do
        local it = items[itemId]
        rowIndex = rowIndex + 1

        local row = tab.bisRows[rowIndex]
        if not row then
            row = CreateFrame("Button", nil, tab.bisChild, GetBackdropTemplate())
            row:SetSize(465, 22)
            ApplyBackdrop(row, 0.04, 0.05, 0.08, 0.6, 0.12, 0.15, 0.22, 0.6)

            local itemLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            itemLabel:SetPoint("LEFT", 8, 0)
            itemLabel:SetPoint("RIGHT", -180, 0)
            itemLabel:SetJustifyH("LEFT")
            row.itemLabel = itemLabel

            local sourceBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sourceBadge:SetPoint("RIGHT", -90, 0)
            sourceBadge:SetJustifyH("RIGHT")
            row.sourceBadge = sourceBadge

            local ownerBadge = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            ownerBadge:SetPoint("RIGHT", -6, 0)
            ownerBadge:SetJustifyH("RIGHT")
            row.ownerBadge = ownerBadge

            row:SetScript("OnEnter", function(self)
                if not GameTooltip or not self.itemId then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self.itemId)
                GameTooltip:Show()
                if self.SetBackdropColor then
                    self:SetBackdropColor(0.12, 0.15, 0.22, 0.9)
                end
            end)

            row:SetScript("OnLeave", function(self)
                if GameTooltip then GameTooltip:Hide() end
                if self.SetBackdropColor then
                    self:SetBackdropColor(0.04, 0.05, 0.08, 0.6)
                end
            end)

            tab.bisRows[rowIndex] = row
        end

        row.itemId = itemId
        row:SetPoint("TOPLEFT", 2, -(rowIndex - 1) * 24)

        local itemName = it.name or ("Item #" .. itemId)
        local isCustom = (it.source_type == "Custom Profile" or it.is_custom == true)
        local sourceText = isCustom and "|cff00ff00[Custom Profile]|r" or "|cffffd700[Default]|r"

        local isEquipped, slotName = IsItemEquipped(itemId)
        local inBags = not isEquipped and IsItemInBags(itemId)

        local ownerText = "|cff6b7280[NOT OWNED]|r"
        if isEquipped then
            ownerText = string.format("|cff00ff00[EQUIPPED: %s]|r", slotName or "Gear")
        elseif inBags then
            ownerText = "|cff00ffff[IN BAGS]|r"
        end

        row.itemLabel:SetText(string.format("%s |cff9ca3af(%d)|r", itemName, itemId))
        row.sourceBadge:SetText(sourceText)
        row.ownerBadge:SetText(ownerText)
        row:Show()
    end

    -- Hide remaining rows
    for i = rowIndex + 1, #tab.bisRows do
        tab.bisRows[i]:Hide()
    end

    tab.bisChild:SetSize(470, math.max(300, rowIndex * 24 + 10))
end

-- ----------------------------------------------------------------------------
-- Tab 5: Settings
-- ----------------------------------------------------------------------------
function WoWEternityAddon:CreateSettingsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()
    self.tabFrames["Settings"] = tab

    -- Card 1: Preferences
    local prefCard = CreateCard(tab)
    prefCard:SetPoint("TOPLEFT", 0, 0)
    prefCard:SetPoint("TOPRIGHT", 0, 0)
    prefCard:SetHeight(304)

    local title1 = prefCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title1:SetPoint("TOPLEFT", 12, -10)
    title1:SetText("|cffe6cc80Addon Preferences|r")

    tab.cbMinimap = CreateCheckbox(prefCard, "WoWEternityAddonOptMinimap", "Show Minimap Icon", true, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.showMinimap = checked
        WoWEternityAddon:UpdateMinimapVisibility()
    end)
    tab.cbMinimap:SetPoint("TOPLEFT", 14, -32)

    CreateStyledButton(prefCard, "Reset Position", 110, 22, function()
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.minimapPos = 45
        if WoWEternityAddon.RepositionMinimapButton then
            WoWEternityAddon:RepositionMinimapButton()
        end
        WoWEternityAddon:Print("|cffe6cc80[WoW Eternity Addon]|r Minimap button position reset to default.")
    end):SetPoint("LEFT", tab.cbMinimap, "RIGHT", 160, 0)

    tab.cbSound = CreateCheckbox(prefCard, "WoWEternityAddonOptSound", "Play Audio Cue on BiS Loot / Tooltip Hover", true, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.playBiSSound = checked
    end)
    tab.cbSound:SetPoint("TOPLEFT", 14, -64)

    CreateStyledButton(prefCard, "Test Sound", 95, 22, function()
        pcall(PlaySound, SOUND_ID)
    end):SetPoint("LEFT", tab.cbSound, "RIGHT", 270, 0)

    tab.cbAutoExport = CreateCheckbox(prefCard, "WoWEternityAddonOptAutoExport", "Auto-Export Character on Login & Zone Change", true, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.autoExport = checked
    end)
    tab.cbAutoExport:SetPoint("TOPLEFT", 14, -94)

    tab.cbPlayerTooltips = CreateCheckbox(prefCard, "WoWEternityAddonOptPlayerTooltips", "Show Progress & Parse in Player Tooltips", true, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.showPlayerTooltips = checked
    end)
    tab.cbPlayerTooltips:SetPoint("TOPLEFT", 14, -124)

    tab.cbVerbose = CreateCheckbox(prefCard, "WoWEternityAddonOptVerbose", "Verbose Talent Diagnostics in Chat", false, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.verboseLogs = checked
    end)
    tab.cbVerbose:SetPoint("TOPLEFT", 14, -154)

    tab.cbTracker = CreateCheckbox(prefCard, "WoWEternityAddonOptTracker", "Show Floating Quest Tracker HUD (Questie Style)", true, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.tracker = WoWEternityAddonDB.tracker or {}
        WoWEternityAddonDB.tracker.shown = checked
        if WoWEternityAddon.trackerFrame then
            if checked then
                WoWEternityAddon.trackerFrame:Show()
                WoWEternityAddon:UpdateTrackerHUD()
            else
                WoWEternityAddon.trackerFrame:Hide()
            end
        elseif checked then
            WoWEternityAddon:CreateTrackerHUD()
        end
    end)
    tab.cbTracker:SetPoint("TOPLEFT", 14, -184)

    tab.cbAutoAdvance = CreateCheckbox(prefCard, "WoWEternityAddonOptAutoAdvance", "Auto-Advance Guide Upon Quest Turn-In", true, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.autoAdvanceGuide = checked
    end)
    tab.cbAutoAdvance:SetPoint("TOPLEFT", 14, -214)

    tab.cbSkipOutleveled = CreateCheckbox(prefCard, "WoWEternityAddonOptSkipOutleveled", "Auto-Skip Outleveled Guide Steps (>5 Levels Below Character)", true, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.skipOutleveled = checked
        if checked and WoWEternityAddon.ScanAndSyncCompletedQuests then
            WoWEternityAddon:ScanAndSyncCompletedQuests()
        end
    end)
    tab.cbSkipOutleveled:SetPoint("TOPLEFT", 14, -244)

    tab.cbMapOverlays = CreateCheckbox(prefCard, "WoWEternityAddonOptMapOverlays", "Show Map Zone Level Overlays", true, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.showMapOverlays = checked
        if WoWEternityAddon.UpdateMapZoneOverlays then
            WoWEternityAddon:UpdateMapZoneOverlays()
        end
    end)
    tab.cbMapOverlays:SetPoint("TOPLEFT", 330, -214)

    local dbPath = prefCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dbPath:SetPoint("TOPLEFT", 14, -276)
    dbPath:SetText("SavedVariables: |cff9ca3afWTF/Account/<Account>/SavedVariables/WoW Eternity Addon.lua|r")

    -- Card 2: Slash Commands Reference
    local slashCard = CreateCard(tab)
    slashCard:SetPoint("TOPLEFT", 0, -310)
    slashCard:SetPoint("TOPRIGHT", 0, -310)
    slashCard:SetHeight(132)

    local title2 = slashCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title2:SetPoint("TOPLEFT", 12, -8)
    title2:SetText("|cffe6cc80Slash Commands Reference|r")

    local ref = slashCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ref:SetPoint("TOPLEFT", 12, -26)
    ref:SetPoint("TOPRIGHT", -12, -26)
    ref:SetJustifyH("LEFT")
    ref:SetText(
        "|cffffd100/wea|r - Toggle main panel | |cffffd100/wea leveling|r - Open Guide | |cffffd100/wea map|r - Map Overlays\n" ..
        "|cffffd100/wea tracker|r - Toggle Questie HUD | |cffffd100/wea arrow|r - Waypoint Arrow | |cffffd100/wea synclevel|r - Level Sync\n" ..
        "|cffffd100/wea sync|r - Export Character | |cffffd100/wea spec <name>|r - BiS Spec | |cffffd100/wea resetguide|r - Reset Steps\n" ..
        "|cffffd100/wea verify|r - Verify Adler-32 integrity & cryptographic player signatures"
    )

    -- Bottom Actions
    CreateStyledButton(tab, "Reset Settings to Default", 240, 28, function()
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.showMinimap = true
        WoWEternityAddonDB.playBiSSound = true
        WoWEternityAddonDB.autoExport = true
        WoWEternityAddonDB.showPlayerTooltips = true
        WoWEternityAddonDB.verboseLogs = false
        WoWEternityAddonDB.autoAdvanceGuide = true
        WoWEternityAddonDB.skipOutleveled = true
        WoWEternityAddonDB.showMapOverlays = true
        WoWEternityAddonDB.minimapPos = 45
        WoWEternityAddon:UpdateSettingsTab()
        WoWEternityAddon:UpdateMinimapVisibility()
        if WoWEternityAddon.UpdateMapZoneOverlays then
            WoWEternityAddon:UpdateMapZoneOverlays()
        end
        if WoWEternityAddon.RepositionMinimapButton then
            WoWEternityAddon:RepositionMinimapButton()
        end
        WoWEternityAddon:Print("|cffe6cc80[WoW Eternity Addon]|r All preferences reset to default.")
    end):SetPoint("BOTTOMLEFT", 0, 0)

    CreateStyledButton(tab, "Reload UI (/reload)", 240, 28, function()
        ReloadUI()
    end):SetPoint("BOTTOMRIGHT", 0, 0)
end

function WoWEternityAddon:UpdateSettingsTab()
    local tab = self.tabFrames and self.tabFrames["Settings"]
    if not tab or not tab:IsShown() then return end

    if tab.cbMinimap then
        tab.cbMinimap:SetChecked(WoWEternityAddonDB and WoWEternityAddonDB.showMinimap ~= false)
    end
    if tab.cbSound then
        tab.cbSound:SetChecked(WoWEternityAddonDB and WoWEternityAddonDB.playBiSSound ~= false)
    end
    if tab.cbAutoExport then
        tab.cbAutoExport:SetChecked(WoWEternityAddonDB and WoWEternityAddonDB.autoExport ~= false)
    end
    if tab.cbPlayerTooltips then
        tab.cbPlayerTooltips:SetChecked(WoWEternityAddonDB and WoWEternityAddonDB.showPlayerTooltips ~= false)
    end
    if tab.cbVerbose then
        tab.cbVerbose:SetChecked(WoWEternityAddonDB and WoWEternityAddonDB.verboseLogs == true)
    end
    if tab.cbTracker then
        tab.cbTracker:SetChecked(WoWEternityAddonDB and WoWEternityAddonDB.tracker and WoWEternityAddonDB.tracker.shown ~= false)
    end
    if tab.cbAutoAdvance then
        tab.cbAutoAdvance:SetChecked(WoWEternityAddonDB and WoWEternityAddonDB.autoAdvanceGuide ~= false)
    end
    if tab.cbSkipOutleveled then
        tab.cbSkipOutleveled:SetChecked(WoWEternityAddonDB and WoWEternityAddonDB.skipOutleveled ~= false)
    end
    if tab.cbMapOverlays then
        tab.cbMapOverlays:SetChecked(WoWEternityAddonDB and WoWEternityAddonDB.showMapOverlays ~= false)
    end
end

-- ============================================================================
-- Tab 5: Cadberry Leveling Guide Implementation
-- ============================================================================

local function ShowLinkCopyDialog(url, text)
    if StaticPopupDialogs and not StaticPopupDialogs["WEA_COPY_URL"] then
        StaticPopupDialogs["WEA_COPY_URL"] = {
            text = "|cffe6cc80[WoW Eternity]|r Guide Link (Ctrl+C to copy):",
            button1 = "Close",
            hasEditBox = true,
            hasWideEditBox = true,
            editBoxWidth = 350,
            OnShow = function(dialog, data)
                local editBox = dialog.editBox or _G[dialog:GetName().."EditBox"]
                if editBox then
                    editBox:SetText(data or "")
                    editBox:HighlightText()
                    editBox:SetFocus()
                end
            end,
            EditBoxOnEnterPressed = function(dialog)
                dialog:GetParent():Hide()
            end,
            EditBoxOnEscapePressed = function(dialog)
                dialog:GetParent():Hide()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    if StaticPopup_Show then
        StaticPopup_Show("WEA_COPY_URL", nil, nil, url)
    else
        WoWEternityAddon:Print(string.format("|cffe6cc80%s:|r |cff38bdf8%s|r", text or "Guide Link", url))
    end
end

local function MatchesCategory(step, category)
    if not category or category == "All" then
        return true
    elseif category == "Dungeons" then
        return step.type == "dungeon" or (step.dungeonName and step.dungeonName ~= "")
    elseif category == "Quests" then
        return step.type == "quest"
    elseif category == "Prerequisites" then
        return step.type == "prep"
    elseif category == "Leveling" then
        return step.type == "leveling" or step.type == "milestone" or step.type == "info"
    end
    return true
end

function WoWEternityAddon:CreateLevelingTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()
    self.tabFrames["Leveling"] = tab
    self.levelingTab = tab

    -- Auto-detect player faction default
    if not self.levelingFaction then
        self:SyncPlayerFaction()
    end
    self.levelingCategory = self.levelingCategory or "All"

    -- Header Control Card
    local headerCard = CreateCard(tab)
    headerCard:SetPoint("TOPLEFT", 0, 0)
    headerCard:SetPoint("TOPRIGHT", 0, 0)
    headerCard:SetHeight(76)

    -- Faction Selector Buttons
    local allyBtn = CreateFrame("Button", nil, headerCard, GetBackdropTemplate())
    allyBtn:SetSize(95, 24)
    allyBtn:SetPoint("TOPLEFT", 10, -8)
    ApplyBackdrop(allyBtn, 0.08, 0.14, 0.28, 0.9, 0.28, 0.45, 0.75, 1)
    local allyBtnText = allyBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    allyBtnText:SetPoint("CENTER")
    allyBtnText:SetText("|cff38bdf8Alliance|r (44)")
    allyBtn.text = allyBtnText
    allyBtn:SetScript("OnClick", function()
        WoWEternityAddon.levelingFaction = "alliance"
        WoWEternityAddon:UpdateLevelingTab()
        WoWEternityAddon:UpdateWaypointArrow()
        WoWEternityAddon:UpdateWorldMapPins()
    end)
    tab.allyBtn = allyBtn

    local hordeBtn = CreateFrame("Button", nil, headerCard, GetBackdropTemplate())
    hordeBtn:SetSize(95, 24)
    hordeBtn:SetPoint("LEFT", allyBtn, "RIGHT", 6, 0)
    ApplyBackdrop(hordeBtn, 0.22, 0.08, 0.08, 0.9, 0.65, 0.22, 0.22, 1)
    local hordeBtnText = hordeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hordeBtnText:SetPoint("CENTER")
    hordeBtnText:SetText("|cffef4444Horde|r (34)")
    hordeBtn.text = hordeBtnText
    hordeBtn:SetScript("OnClick", function()
        WoWEternityAddon.levelingFaction = "horde"
        WoWEternityAddon:UpdateLevelingTab()
        WoWEternityAddon:UpdateWaypointArrow()
        WoWEternityAddon:UpdateWorldMapPins()
    end)
    tab.hordeBtn = hordeBtn

    -- Progress Bar
    local progressBg = CreateFrame("Frame", nil, headerCard, GetBackdropTemplate())
    progressBg:SetSize(120, 18)
    progressBg:SetPoint("LEFT", hordeBtn, "RIGHT", 8, 0)
    ApplyBackdrop(progressBg, 0.02, 0.03, 0.05, 0.9, 0.18, 0.22, 0.32, 1)
    tab.progressBg = progressBg

    local progressBar = progressBg:CreateTexture(nil, "ARTWORK")
    progressBar:SetPoint("TOPLEFT", 1, -1)
    progressBar:SetPoint("BOTTOMLEFT", 1, 1)
    progressBar:SetWidth(1)
    progressBar:SetColorTexture(0.12, 0.68, 0.38, 0.95)
    tab.progressBar = progressBar

    local progressText = progressBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progressText:SetPoint("CENTER", progressBg, "CENTER", 0, 0)
    progressText:SetText("0 / 44 (0%)")
    tab.progressText = progressText

    -- Quick Level Sync Button
    local syncBtn = CreateStyledButton(headerCard, "Sync Lvl", 62, 22, function()
        WoWEternityAddon:SyncWithPlayerLevel(true)
    end)
    syncBtn:SetPoint("LEFT", progressBg, "RIGHT", 6, 0)
    tab.syncBtn = syncBtn

    -- Quick Arrow Toggle Button
    local arrowBtn = CreateStyledButton(headerCard, "Arrow: ON", 68, 22, function()
        WoWEternityAddon:ToggleWaypointArrow()
    end)
    arrowBtn:SetPoint("TOPRIGHT", -128, -9)
    tab.arrowBtn = arrowBtn

    -- Quick Tracker Toggle Button
    local trackerBtn = CreateStyledButton(headerCard, "Tracker: ON", 72, 22, function()
        WoWEternityAddon:ToggleTrackerHUD()
    end)
    trackerBtn:SetPoint("TOPRIGHT", -52, -9)
    tab.trackerBtn = trackerBtn

    -- Reset Progress Button
    local resetBtn = CreateStyledButton(headerCard, "Reset", 42, 22, function()
        WoWEternityAddon:ResetLevelingGuide()
    end)
    resetBtn:SetPoint("TOPRIGHT", -6, -9)
    tab.resetBtn = resetBtn

    -- Row 2: Category Filter Bar
    local filterCategories = { "All", "Dungeons", "Quests", "Prerequisites", "Leveling" }
    tab.filterButtons = {}
    local startX = 10
    for _, cat in ipairs(filterCategories) do
        local fBtn = CreateFrame("Button", nil, headerCard, GetBackdropTemplate())
        fBtn:SetSize(116, 22)
        fBtn:SetPoint("BOTTOMLEFT", startX, 9)
        ApplyBackdrop(fBtn, 0.06, 0.08, 0.12, 0.85, 0.18, 0.22, 0.32, 0.8)

        local fText = fBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fText:SetPoint("CENTER")
        fText:SetText(cat)
        fBtn.text = fText

        local thisCat = cat
        fBtn:SetScript("OnClick", function()
            WoWEternityAddon.levelingCategory = thisCat
            WoWEternityAddon:UpdateLevelingTab()
        end)

        tab.filterButtons[cat] = fBtn
        startX = startX + 120
    end

    -- ScrollFrame for Step Cards
    local scrollFrame = CreateFrame("ScrollFrame", "WoWEternityAddonLevelingScrollFrame", tab, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -82)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 38)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(590, 400)
    scrollFrame:SetScrollChild(scrollChild)
    tab.scrollChild = scrollChild
    tab.scrollFrame = scrollFrame

    tab.stepCards = {}

    -- Bottom Action Bar
    CreateStyledButton(tab, "Waypoint Arrow Controls", 280, 28, function()
        WoWEternityAddon:ToggleWaypointArrow()
    end):SetPoint("BOTTOMLEFT", 0, 0)

    CreateStyledButton(tab, "Reset Leveling Progress", 280, 28, function()
        WoWEternityAddon:ResetLevelingGuide()
    end):SetPoint("BOTTOMRIGHT", 0, 0)
end

local function GetOrCreateStepCard(tab, index)
    local card = tab.stepCards[index]
    if card then return card end

    card = CreateFrame("Frame", nil, tab.scrollChild, GetBackdropTemplate())
    card:SetWidth(585)
    ApplyBackdrop(card, 0.04, 0.05, 0.08, 0.85, 0.16, 0.20, 0.30, 0.85)

    -- Checkbox
    local cb = CreateFrame("CheckButton", "WEA_StepCB_" .. index, card, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", 8, -8)
    card.cb = cb

    -- Badges & Header
    local badge = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    badge:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    card.badge = badge

    local lvlBadge = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lvlBadge:SetPoint("LEFT", badge, "RIGHT", 8, 0)
    card.lvlBadge = lvlBadge

    local typeBadge = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    typeBadge:SetPoint("LEFT", lvlBadge, "RIGHT", 8, 0)
    card.typeBadge = typeBadge

    -- Title
    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -32)
    title:SetPoint("RIGHT", -12, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    card.title = title

    -- Location
    local location = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    location:SetPoint("TOPLEFT", 12, -48)
    location:SetPoint("RIGHT", -12, 0)
    location:SetJustifyH("LEFT")
    card.location = location

    -- Details container text
    local details = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    details:SetPoint("TOPLEFT", 12, -66)
    details:SetPoint("RIGHT", -12, 0)
    details:SetJustifyH("LEFT")
    details:SetTextColor(0.85, 0.88, 0.92, 1)
    card.details = details

    -- Tactical Note text
    local note = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", details, "BOTTOMLEFT", 0, -4)
    note:SetPoint("RIGHT", -12, 0)
    note:SetJustifyH("LEFT")
    note:SetTextColor(1.0, 0.82, 0.0, 1)
    card.note = note

    -- Links button
    local linkBtn = CreateStyledButton(card, "Guide Link", 160, 18)
    linkBtn:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -4)
    card.linkBtn = linkBtn

    tab.stepCards[index] = card
    return card
end

function WoWEternityAddon:UpdateLevelingTab()
    local tab = self.tabFrames and self.tabFrames["Leveling"]
    if not tab or not tab:IsShown() then return end

    local faction = self.levelingFaction or "alliance"
    local category = self.levelingCategory or "All"
    local guide = (faction == "horde") and self.CADBERRY_HORDE_GUIDE or self.CADBERRY_ALLIANCE_GUIDE
    if not guide or not guide.steps then return end

    -- Update Faction Button Highlights
    if faction == "alliance" then
        ApplyBackdrop(tab.allyBtn, 0.12, 0.25, 0.50, 1, 0.90, 0.80, 0.50, 1)
        ApplyBackdrop(tab.hordeBtn, 0.08, 0.06, 0.08, 0.7, 0.22, 0.18, 0.22, 0.7)
        tab.allyBtn.text:SetTextColor(1.0, 0.85, 0.2, 1)
        tab.hordeBtn.text:SetTextColor(0.6, 0.6, 0.6, 1)
    else
        ApplyBackdrop(tab.allyBtn, 0.06, 0.08, 0.12, 0.7, 0.18, 0.22, 0.32, 0.7)
        ApplyBackdrop(tab.hordeBtn, 0.45, 0.10, 0.10, 1, 0.90, 0.80, 0.50, 1)
        tab.allyBtn.text:SetTextColor(0.6, 0.6, 0.6, 1)
        tab.hordeBtn.text:SetTextColor(1.0, 0.85, 0.2, 1)
    end

    -- Update Category Filter Highlights
    for catName, btn in pairs(tab.filterButtons) do
        if catName == category then
            ApplyBackdrop(btn, 0.18, 0.22, 0.35, 1, 0.90, 0.80, 0.50, 1)
            btn.text:SetTextColor(1.0, 0.82, 0.0, 1)
        else
            ApplyBackdrop(btn, 0.06, 0.08, 0.12, 0.85, 0.18, 0.22, 0.32, 0.8)
            btn.text:SetTextColor(0.61, 0.64, 0.69, 1)
        end
    end

    -- Update Progress Bar
    local completedTable = WoWEternityAddonCharDB and WoWEternityAddonCharDB.cadberryCompleted or {}
    local totalSteps = #guide.steps
    local completedCount = 0
    for _, s in ipairs(guide.steps) do
        if completedTable[s.id] then
            completedCount = completedCount + 1
        end
    end
    local pct = (totalSteps > 0) and math.floor((completedCount / totalSteps) * 100) or 0
    tab.progressText:SetText(string.format("%d / %d Steps (%d%%)", completedCount, totalSteps, pct))
    local barW = math.max(1, math.floor((completedCount / totalSteps) * 218))
    tab.progressBar:SetWidth(barW)

    -- Update Arrow Toggle button text
    if tab.arrowBtn then
        local arrowShown = self.waypointArrow and self.waypointArrow:IsShown()
        tab.arrowBtn:SetText(arrowShown and "Arrow: |cff00ff00ON|r" or "Arrow: |cffff2020OFF|r")
    end
    if tab.trackerBtn then
        local trackerShown = self.trackerFrame and self.trackerFrame:IsShown()
        tab.trackerBtn:SetText(trackerShown and "Tracker: |cff00ff00ON|r" or "Tracker: |cffff2020OFF|r")
    end

    -- Render Step Cards
    local totalOffset = 0
    local cardIndex = 0

    for _, step in ipairs(guide.steps) do
        if MatchesCategory(step, category) then
            cardIndex = cardIndex + 1
            local card = GetOrCreateStepCard(tab, cardIndex)
            local isDone = completedTable[step.id] == true

            -- Completion Checkbox
            card.cb:SetChecked(isDone)
            local stepId = step.id
            card.cb:SetScript("OnClick", function(selfBtn)
                local checked = selfBtn:GetChecked()
                WoWEternityAddonCharDB = WoWEternityAddonCharDB or {}
                WoWEternityAddonCharDB.cadberryCompleted = WoWEternityAddonCharDB.cadberryCompleted or {}
                WoWEternityAddonCharDB.manuallyUnchecked = WoWEternityAddonCharDB.manuallyUnchecked or {}
                if checked then
                    WoWEternityAddonCharDB.cadberryCompleted[stepId] = true
                    WoWEternityAddonCharDB.manuallyUnchecked[stepId] = nil
                else
                    WoWEternityAddonCharDB.cadberryCompleted[stepId] = nil
                    WoWEternityAddonCharDB.manuallyUnchecked[stepId] = true
                end
                WoWEternityAddon:UpdateLevelingTab()
                WoWEternityAddon:UpdateWaypointArrow()
                WoWEternityAddon:UpdateWorldMapPins()
                WoWEternityAddon:UpdateTrackerHUD()
            end)

            -- Header Badges
            card.badge:SetText(string.format("|cffe6cc80Step %d|r", step.stepNumber))
            card.lvlBadge:SetText(string.format("|cff38bdf8[%s]|r", step.levelBadge))

            local typeColor = "|cff9ca3af"
            if step.type == "dungeon" then typeColor = "|cffa855f7"
            elseif step.type == "prep" then typeColor = "|cfff97316"
            elseif step.type == "quest" then typeColor = "|cff38bdf8"
            elseif step.type == "leveling" then typeColor = "|cff22c55e"
            elseif step.type == "milestone" then typeColor = "|cffffd700" end
            card.typeBadge:SetText(string.format("%s[%s]|r", typeColor, step.type:upper()))

            -- Title & Location
            if isDone then
                card.title:SetText(string.format("|cff9ca3af%s (Completed)|r", step.title))
                ApplyBackdrop(card, 0.03, 0.04, 0.05, 0.6, 0.10, 0.14, 0.20, 0.6)
            else
                card.title:SetText(string.format("|cffffffff%s|r", step.title))
                ApplyBackdrop(card, 0.04, 0.05, 0.08, 0.85, 0.16, 0.20, 0.30, 0.85)
            end

            local locStr = ""
            if step.location and step.location ~= "" then
                locStr = string.format("|cff9ca3afLocation:|r |cff38bdf8%s|r", step.location)
            elseif step.dungeonName and step.dungeonName ~= "" then
                locStr = string.format("|cff9ca3afDungeon:|r |cffa855f7%s|r", step.dungeonName)
            end
            card.location:SetText(locStr)

            -- Details & Notes
            local cardHeight = 56
            if locStr ~= "" then cardHeight = cardHeight + 14 end

            if step.details and #step.details > 0 then
                local bullets = {}
                for _, d in ipairs(step.details) do
                    table.insert(bullets, "• " .. d)
                end
                card.details:SetText(table.concat(bullets, "\n"))
                card.details:Show()
                cardHeight = cardHeight + (#step.details * 14) + 6
            else
                card.details:SetText("")
                card.details:Hide()
            end

            if step.note and step.note ~= "" then
                card.note:SetText("|cffe6cc80Tactical Note:|r " .. step.note)
                card.note:Show()
                cardHeight = cardHeight + 22
            else
                card.note:SetText("")
                card.note:Hide()
            end

            if step.links and #step.links > 0 then
                local linkData = step.links[1]
                card.linkBtn:SetText(linkData.text or "Guide Link")
                card.linkBtn:SetScript("OnClick", function()
                    ShowLinkCopyDialog(linkData.url, linkData.text)
                end)
                card.linkBtn:Show()
                cardHeight = cardHeight + 24
            else
                card.linkBtn:Hide()
            end

            card:SetHeight(cardHeight)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", tab.scrollChild, "TOPLEFT", 0, -totalOffset)
            card:SetPoint("TOPRIGHT", tab.scrollChild, "TOPRIGHT", -4, -totalOffset)
            card:Show()

            totalOffset = totalOffset + cardHeight + 8
        end
    end

    -- Hide unused cards
    for k = cardIndex + 1, #tab.stepCards do
        tab.stepCards[k]:Hide()
    end

    tab.scrollChild:SetHeight(math.max(totalOffset, 320))
end

function WoWEternityAddon:GetPlayerFaction()
    if self.levelingFaction then return self.levelingFaction end
    local factionGroup = UnitFactionGroup and UnitFactionGroup("player")
    if factionGroup and factionGroup:lower() == "horde" then
        self.levelingFaction = "horde"
    else
        self.levelingFaction = "alliance"
    end
    return self.levelingFaction
end

function WoWEternityAddon:SyncPlayerFaction()
    local factionGroup = UnitFactionGroup and UnitFactionGroup("player")
    if factionGroup and factionGroup:lower() == "horde" then
        self.levelingFaction = "horde"
    else
        self.levelingFaction = "alliance"
    end
    return self.levelingFaction
end

function WoWEternityAddon:GetStepLevelRange(step)
    if not step or not step.levelBadge then return 1, 60 end
    local b = tostring(step.levelBadge)
    local low, high = b:match("(%d+)%s*[^%d%s]+%s*(%d+)")
    if low and high then
        return tonumber(low), tonumber(high)
    end
    local single = b:match("(%d+)")
    if single then
        local lvl = tonumber(single)
        return lvl, lvl
    end
    return 1, 60
end

function WoWEternityAddon:GetActiveLevelingStep(faction)
    faction = faction or self:GetPlayerFaction()
    local guide = (faction == "horde") and self.CADBERRY_HORDE_GUIDE or self.CADBERRY_ALLIANCE_GUIDE
    if not guide or not guide.steps then return nil end

    local completed = WoWEternityAddonCharDB and WoWEternityAddonCharDB.cadberryCompleted
    for _, step in ipairs(guide.steps) do
        if not (completed and completed[step.id]) then
            return step
        end
    end
    return nil
end

function WoWEternityAddon:GetUpcomingLevelingSteps(faction, count)
    count = count or 2
    faction = faction or self:GetPlayerFaction()
    local guide = (faction == "horde") and self.CADBERRY_HORDE_GUIDE or self.CADBERRY_ALLIANCE_GUIDE
    if not guide or not guide.steps then return {} end

    local completed = WoWEternityAddonCharDB and WoWEternityAddonCharDB.cadberryCompleted
    local upcoming = {}
    local skippedFirst = false
    for _, step in ipairs(guide.steps) do
        if not (completed and completed[step.id]) then
            if not skippedFirst then
                skippedFirst = true
            else
                table.insert(upcoming, step)
                if #upcoming >= count then
                    break
                end
            end
        end
    end
    return upcoming
end

function WoWEternityAddon:GetDistanceToStep(step)
    if not step or not step.x or not step.y or not step.mapID or step.x <= 0 or step.y <= 0 then
        return nil, false
    end
    local playerMap
    if C_Map and C_Map.GetBestMapForUnit then
        playerMap = C_Map.GetBestMapForUnit("player")
    end
    if not playerMap or playerMap ~= step.mapID then
        return nil, false
    end
    if C_Map and C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
        if pos and pos.GetXY then
            local px, py = pos:GetXY()
            if px and py then
                local dx = step.x - px
                local dy = step.y - py
                local distYards = math.sqrt(dx * dx + dy * dy) * 1500
                return distYards, true
            end
        end
    end
    return nil, false
end

-- ============================================================================
-- Waypoint Navigation Arrow (Strict Linear Auto-Tracking)
-- ============================================================================

function WoWEternityAddon:CreateWaypointArrow()
    if not CreateFrame then return end
    if self.waypointArrow then return end

    local frame = CreateFrame("Button", "WoWEternityAddonWaypointArrow", UIParent, GetBackdropTemplate())
    self.waypointArrow = frame

    frame:SetSize(160, 68)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Restore saved position
    local db = WoWEternityAddonDB and WoWEternityAddonDB.waypointArrow
    local pt = (db and db.point) or "CENTER"
    local x = (db and db.x) or 0
    local y = (db and db.y) or 140
    frame:SetPoint(pt, UIParent, pt, x, y)

    ApplyBackdrop(frame, 0.04, 0.05, 0.08, 0.88, 0.22, 0.26, 0.38, 0.95)

    -- Draggable
    frame:SetScript("OnDragStart", function(f)
        if not (WoWEternityAddonDB and WoWEternityAddonDB.waypointArrow and WoWEternityAddonDB.waypointArrow.locked) then
            f:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, _, xOfs, yOfs = f:GetPoint()
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.waypointArrow = WoWEternityAddonDB.waypointArrow or {}
        WoWEternityAddonDB.waypointArrow.point = point or "CENTER"
        WoWEternityAddonDB.waypointArrow.x = xOfs or 0
        WoWEternityAddonDB.waypointArrow.y = yOfs or 140
    end)

    -- Left click opens leveling tab
    frame:SetScript("OnClick", function()
        WoWEternityAddon:ToggleSettingsFrame("Leveling")
    end)

    -- Directional Arrow Texture
    local arrowTex = frame:CreateTexture(nil, "ARTWORK")
    arrowTex:SetSize(36, 36)
    arrowTex:SetPoint("LEFT", 10, 0)
    arrowTex:SetTexture("Interface\Minimap\Minimap_Arrow")
    frame.arrowTex = arrowTex

    -- Header / Step Title
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("TOPLEFT", arrowTex, "TOPRIGHT", 8, -6)
    titleText:SetPoint("RIGHT", -8, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    frame.titleText = titleText

    -- Distance / Zone Readout
    local distText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    distText:SetPoint("BOTTOMLEFT", arrowTex, "BOTTOMRIGHT", 8, 8)
    distText:SetPoint("RIGHT", -8, 0)
    distText:SetJustifyH("LEFT")
    distText:SetWordWrap(false)
    frame.distText = distText

    -- Throttled OnUpdate
    local elapsedTotal = 0
    frame:SetScript("OnUpdate", function(f, elapsed)
        elapsedTotal = elapsedTotal + (elapsed or 0)
        if elapsedTotal >= 0.05 then
            elapsedTotal = 0
            WoWEternityAddon:UpdateWaypointArrow()
        end
    end)

    -- Initial visibility check
    if db and db.shown == false then
        frame:Hide()
    else
        frame:Show()
    end

    self:UpdateWaypointArrow()
end

function WoWEternityAddon:UpdateWaypointArrow()
    local frame = self.waypointArrow
    if not frame or not frame:IsShown() then return end

    local faction = self.levelingFaction or "alliance"
    local step = self:GetActiveLevelingStep(faction)

    if not step then
        frame.titleText:SetText("|cff00ff00All Steps Completed!|r")
        frame.distText:SetText("|cffe6cc80Level 60 Reached|r")
        if frame.arrowTex.SetRotation then frame.arrowTex:SetRotation(0) end
        return
    end

    frame.titleText:SetText(string.format("|cffe6cc80#%d:|r %s", step.stepNumber, step.title))

    -- Target Coordinates & MapID
    local tx, ty, tMap = step.x, step.y, step.mapID
    local px, py, playerMap

    if C_Map and C_Map.GetBestMapForUnit then
        playerMap = C_Map.GetBestMapForUnit("player")
        if playerMap and C_Map.GetPlayerMapPosition then
            local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
            if pos and pos.GetXY then
                px, py = pos:GetXY()
            end
        end
    end

    if px and py and tx and ty and tx > 0 and ty > 0 and playerMap and tMap and playerMap == tMap then
        -- In same zone: calculate dynamic bearing and distance
        local dx = tx - px
        local dy = ty - py
        -- angle = atan2(targetX - px, -(targetY - py)) - GetPlayerFacing()
        local angle = math.atan2(dx, -dy)
        local facing = (GetPlayerFacing and GetPlayerFacing()) or 0
        local bearing = angle - facing

        if frame.arrowTex.SetRotation then
            frame.arrowTex:SetRotation(bearing)
        end

        local mapDist = math.sqrt(dx * dx + dy * dy)
        local distYards = mapDist * 1500 -- approx yards per zone map unit

        if distYards < 15 then
            frame.distText:SetText("|cff00ff00Arrived! (< 15 yds)|r")
        elseif distYards >= 1000 then
            frame.distText:SetText(string.format("|cff38bdf8%.1fk yds|r", distYards / 1000))
        else
            frame.distText:SetText(string.format("|cff38bdf8%d yds|r", math.floor(distYards)))
        end
    else
        -- Different zone or no coords
        if frame.arrowTex.SetRotation then frame.arrowTex:SetRotation(0) end
        local loc = (step.location and step.location ~= "") and step.location or (step.dungeonName and step.dungeonName ~= "" and step.dungeonName) or "Different Zone"
        frame.distText:SetText(string.format("|cff9ca3af%s|r", loc))
    end
end

function WoWEternityAddon:ToggleWaypointArrow()
    if not self.waypointArrow then
        self:CreateWaypointArrow()
    end
    if not self.waypointArrow then return end

    WoWEternityAddonDB = WoWEternityAddonDB or {}
    WoWEternityAddonDB.waypointArrow = WoWEternityAddonDB.waypointArrow or {}

    if self.waypointArrow:IsShown() then
        self.waypointArrow:Hide()
        WoWEternityAddonDB.waypointArrow.shown = false
        self:Print("|cffe6cc80[WoW Eternity Addon]|r Waypoint arrow hidden.")
    else
        self.waypointArrow:Show()
        WoWEternityAddonDB.waypointArrow.shown = true
        self:UpdateWaypointArrow()
        self:Print("|cffe6cc80[WoW Eternity Addon]|r Waypoint arrow shown.")
    end

    if self.levelingTab and self.levelingTab.arrowBtn then
        self.levelingTab.arrowBtn:SetText(self.waypointArrow:IsShown() and "Arrow: |cff00ff00ON|r" or "Arrow: |cffff2020OFF|r")
    end
end

function WoWEternityAddon:ResetLevelingGuide()
    WoWEternityAddonCharDB = WoWEternityAddonCharDB or {}
    WoWEternityAddonCharDB.cadberryCompleted = {}
    WoWEternityAddonCharDB.manuallyUnchecked = {}
    self:Print("|cffe6cc80[WoW Eternity Addon]|r Cadberry Leveling Guide steps reset for this character.")
    if self.UpdateLevelingTab then
        self:UpdateLevelingTab()
    end
    if self.UpdateWaypointArrow then
        self:UpdateWaypointArrow()
    end
    if self.UpdateWorldMapPins then
        self:UpdateWorldMapPins()
    end
    if self.UpdateTrackerHUD then
        self:UpdateTrackerHUD()
    end
end

-- ============================================================================
-- Automated Quest Turn-In & Level Milestone Detection
-- ============================================================================

function WoWEternityAddon:OnQuestTurnedIn(questId)
    if not questId or questId <= 0 then return end
    if WoWEternityAddonDB and WoWEternityAddonDB.autoAdvanceGuide == false then return end

    local faction = self.levelingFaction or self:GetPlayerFaction()
    local guide = (faction == "horde") and self.CADBERRY_HORDE_GUIDE or self.CADBERRY_ALLIANCE_GUIDE
    if not guide or not guide.steps then return end

    WoWEternityAddonCharDB = WoWEternityAddonCharDB or {}
    WoWEternityAddonCharDB.cadberryCompleted = WoWEternityAddonCharDB.cadberryCompleted or {}
    WoWEternityAddonCharDB.manuallyUnchecked = WoWEternityAddonCharDB.manuallyUnchecked or {}

    local matchedStep = nil
    for _, step in ipairs(guide.steps) do
        if not WoWEternityAddonCharDB.cadberryCompleted[step.id] then
            if step.questieQuestId == questId then
                matchedStep = step
                break
            end
        end
    end

    if matchedStep then
        WoWEternityAddonCharDB.cadberryCompleted[matchedStep.id] = true
        WoWEternityAddonCharDB.manuallyUnchecked[matchedStep.id] = nil
        if PlaySound and SOUNDKIT and SOUNDKIT.UI_QUEST_COMPLETE then
            pcall(PlaySound, SOUNDKIT.UI_QUEST_COMPLETE)
        end

        if self.UpdateLevelingTab then self:UpdateLevelingTab() end
        if self.UpdateWaypointArrow then self:UpdateWaypointArrow() end
        if self.UpdateWorldMapPins then self:UpdateWorldMapPins() end
        if self.UpdateTrackerHUD then self:UpdateTrackerHUD() end

        local nextStep = self:GetActiveLevelingStep(faction)
        if nextStep then
            self:Print(string.format("|cff00ff00[WoW Eternity Addon]|r Quest completed! Auto-advancing to Step #%d: |cffffd100%s|r", nextStep.stepNumber, nextStep.title))
        else
            self:Print("|cff00ff00[WoW Eternity Addon]|r All 1–60 steps completed! Level 60 Milestone Reached!")
        end
    end
end

function WoWEternityAddon:ScanAndSyncCompletedQuests()
    if WoWEternityAddonDB and WoWEternityAddonDB.autoAdvanceGuide == false then return end

    local faction = self.levelingFaction or self:GetPlayerFaction()
    local guide = (faction == "horde") and self.CADBERRY_HORDE_GUIDE or self.CADBERRY_ALLIANCE_GUIDE
    if not guide or not guide.steps then return end

    WoWEternityAddonCharDB = WoWEternityAddonCharDB or {}
    WoWEternityAddonCharDB.cadberryCompleted = WoWEternityAddonCharDB.cadberryCompleted or {}
    WoWEternityAddonCharDB.manuallyUnchecked = WoWEternityAddonCharDB.manuallyUnchecked or {}

    local playerLevel = (UnitLevel and UnitLevel("player")) or 1
    local minRelevantLevel = math.max(1, playerLevel - 5)
    local skipOutleveled = (WoWEternityAddonDB and WoWEternityAddonDB.skipOutleveled ~= false)
    local newlyCompleted = 0

    for _, step in ipairs(guide.steps) do
        if not WoWEternityAddonCharDB.cadberryCompleted[step.id] then
            local isDone = false
            -- 1. Check quest completion via API
            if step.questieQuestId and step.questieQuestId > 0 then
                if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(step.questieQuestId) then
                    isDone = true
                elseif _G.IsQuestFlaggedCompleted and _G.IsQuestFlaggedCompleted(step.questieQuestId) then
                    isDone = true
                elseif _G.Questie and _G.Questie.db and _G.Questie.db.char and _G.Questie.db.char.complete and _G.Questie.db.char.complete[step.questieQuestId] then
                    isDone = true
                end
            end

            -- 2. Check milestone levels (e.g. "Hit Level 55 Milestone", "GRATS ON 60!")
            if not isDone and step.type == "milestone" then
                local _, maxLvl = self:GetStepLevelRange(step)
                if maxLvl and playerLevel >= maxLvl then
                    isDone = true
                end
            end

            -- 3. Dynamic Level Skip (>5 levels below character)
            if not isDone and skipOutleveled then
                local minLvl, maxLvl = self:GetStepLevelRange(step)
                if maxLvl and playerLevel > maxLvl and minLvl < minRelevantLevel and not WoWEternityAddonCharDB.manuallyUnchecked[step.id] then
                    isDone = true
                end
            end

            if isDone then
                WoWEternityAddonCharDB.cadberryCompleted[step.id] = true
                newlyCompleted = newlyCompleted + 1
            end
        end
    end

    if newlyCompleted > 0 then
        if self.UpdateLevelingTab then self:UpdateLevelingTab() end
        if self.UpdateWaypointArrow then self:UpdateWaypointArrow() end
        if self.UpdateWorldMapPins then self:UpdateWorldMapPins() end
        if self.UpdateTrackerHUD then self:UpdateTrackerHUD() end
    end
end

function WoWEternityAddon:SyncWithPlayerLevel(verbose)
    self:SyncPlayerFaction()
    self:ScanAndSyncCompletedQuests()
    local lvl = (UnitLevel and UnitLevel("player")) or 1
    local minKeep = math.max(1, lvl - 5)
    local active = self:GetActiveLevelingStep()
    if verbose then
        if active then
            self:Print(string.format("|cff00ff00[WoW Eternity Addon]|r Synced with Level %d (%s): kept objectives within 5-level gap (>= Level %d). Current Active: Step #%d [%s] (|cffffd100%s|r)", lvl, (self.levelingFaction or "alliance"):upper(), minKeep, active.stepNumber, active.levelBadge or "", active.title))
        else
            self:Print(string.format("|cff00ff00[WoW Eternity Addon]|r Synced with Level %d (%s): all steps completed!", lvl, (self.levelingFaction or "alliance"):upper()))
        end
    end
end

function WoWEternityAddon:OnPlayerLevelUp(newLevel)
    self:ScanAndSyncCompletedQuests()
    local faction = self.levelingFaction or self:GetPlayerFaction()
    local active = self:GetActiveLevelingStep(faction)
    if active then
        self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Ding level %d! Current leveling objective: Step #%d (|cffffd100%s|r)", newLevel or 0, active.stepNumber, active.title))
    end
end

-- ============================================================================
-- World Map Pin Overlay
-- ============================================================================

function WoWEternityAddon:InitWorldMapPins()
    if not WorldMapFrame then return end
    if self.worldMapPinsInitialized then return end
    self.worldMapPinsInitialized = true
    self.worldMapPins = {}

    if WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", function()
            WoWEternityAddon:UpdateWorldMapPins()
        end)
    end

    local mapEvents = CreateFrame and CreateFrame("Frame")
    if mapEvents and mapEvents.RegisterEvent then
        mapEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        mapEvents:RegisterEvent("ZONE_CHANGED")
        mapEvents:SetScript("OnEvent", function()
            if WorldMapFrame and WorldMapFrame:IsShown() then
                WoWEternityAddon:UpdateWorldMapPins()
            end
        end)
    end
end

function WoWEternityAddon:UpdateWorldMapPins()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local currentMapID = 0
    if WorldMapFrame.GetMapID then
        currentMapID = WorldMapFrame:GetMapID() or 0
    elseif C_Map and C_Map.GetBestMapForUnit then
        currentMapID = C_Map.GetBestMapForUnit("player") or 0
    end

    self.worldMapPins = self.worldMapPins or {}
    for _, pin in ipairs(self.worldMapPins) do
        pin:Hide()
    end

    if currentMapID == 0 then return end

    local faction = self.levelingFaction or "alliance"
    local guide = (faction == "horde") and self.CADBERRY_HORDE_GUIDE or self.CADBERRY_ALLIANCE_GUIDE
    if not guide or not guide.steps then return end

    local canvas = (WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas())
        or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
        or WorldMapButton
        or WorldMapFrame

    local canvasW, canvasH = 1002, 668
    if canvas.GetSize then
        local w, h = canvas:GetSize()
        if w and w > 0 and h and h > 0 then
            canvasW, canvasH = w, h
        end
    end

    local completed = WoWEternityAddonCharDB and WoWEternityAddonCharDB.cadberryCompleted or {}
    local pinIndex = 0

    for _, step in ipairs(guide.steps) do
        if step.mapID == currentMapID and step.x and step.x > 0 and step.y and step.y > 0 then
            pinIndex = pinIndex + 1
            local pin = self.worldMapPins[pinIndex]
            if not pin then
                pin = CreateFrame("Button", "WEA_MapPin_" .. pinIndex, canvas)
                pin:SetSize(22, 22)

                local icon = pin:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints(pin)
                pin.icon = icon

                local numText = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                numText:SetPoint("CENTER", 0, 0)
                pin.numText = numText

                pin:SetScript("OnEnter", function(p)
                    if not GameTooltip or not p.step then return end
                    GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
                    local s = p.step
                    local isDone = WoWEternityAddonCharDB and WoWEternityAddonCharDB.cadberryCompleted and WoWEternityAddonCharDB.cadberryCompleted[s.id]
                    GameTooltip:AddLine(string.format("|cffe6cc80[Cadberry Step %d]|r %s", s.stepNumber, s.title), 1, 1, 1)
                    GameTooltip:AddLine(string.format("Level: |cff38bdf8%s|r  ·  Type: |cffffd100%s|r", s.levelBadge, s.type:upper()), 0.8, 0.8, 0.8)
                    if s.location and s.location ~= "" then
                        GameTooltip:AddLine(string.format("Location: |cff9ca3af%s|r", s.location), 0.7, 0.7, 0.7)
                    end
                    if s.note and s.note ~= "" then
                        GameTooltip:AddLine(string.format("|cffe6cc80Note:|r %s", s.note), 1, 0.82, 0, true)
                    end
                    if isDone then
                        GameTooltip:AddLine("|cff00ff00✔ Step Completed|r", 0, 1, 0)
                    else
                        GameTooltip:AddLine("|cffffcc00Incomplete (Click to view in guide)|r", 1, 0.8, 0)
                    end
                    GameTooltip:Show()
                end)

                pin:SetScript("OnLeave", function()
                    if GameTooltip then GameTooltip:Hide() end
                end)

                pin:SetScript("OnClick", function()
                    WoWEternityAddon:ToggleSettingsFrame("Leveling")
                end)

                self.worldMapPins[pinIndex] = pin
            end

            pin.step = step
            local isDone = completed[step.id]
            if isDone then
                pin.icon:SetTexture("Interface\RaidFrame\ReadyCheck-Ready")
                pin.numText:SetText("")
            else
                pin.icon:SetTexture("Interface\Minimap\Tracking\None")
                pin.numText:SetText(tostring(step.stepNumber))
            end

            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", step.x * canvasW, -step.y * canvasH)
        end
    end

    if self.UpdateMapZoneOverlays then
        self:UpdateMapZoneOverlays()
    end
end

-- ============================================================================
-- World Map Zone Level Range Overlay (Top-Right Zone Badge & Continent Overlays)
-- ============================================================================

local ZONE_LEVEL_RANGES = {
    -- Kalimdor (18 zones)
    { name = "Teldrassil", continent = "kalimdor", minLvl = 1, maxLvl = 10, x = 0.426, y = 0.084, uiMapID = 1438, faction = "Alliance" },
    { name = "Darkshore", continent = "kalimdor", minLvl = 10, maxLvl = 20, x = 0.452, y = 0.2365, uiMapID = 1439, faction = "Alliance" },
    { name = "Moonglade", continent = "kalimdor", minLvl = 1, maxLvl = 60, x = 0.544, y = 0.170, uiMapID = 1450, faction = "Neutral" },
    { name = "Winterspring", continent = "kalimdor", minLvl = 55, maxLvl = 60, x = 0.577, y = 0.243, uiMapID = 1452, faction = "Contested" },
    { name = "Felwood", continent = "kalimdor", minLvl = 48, maxLvl = 55, x = 0.495, y = 0.268, uiMapID = 1448, faction = "Contested" },
    { name = "Ashenvale", continent = "kalimdor", minLvl = 18, maxLvl = 30, x = 0.512, y = 0.430, uiMapID = 1440, faction = "Contested", dungeons = { "Blackfathom Deeps (24–32)" } },
    { name = "Azshara", continent = "kalimdor", minLvl = 45, maxLvl = 55, x = 0.596, y = 0.387, uiMapID = 1447, faction = "Contested" },
    { name = "Durotar", continent = "kalimdor", minLvl = 1, maxLvl = 10, x = 0.588, y = 0.547, uiMapID = 1411, faction = "Horde", dungeons = { "Ragefire Chasm (13–18)" } },
    { name = "The Barrens", continent = "kalimdor", minLvl = 10, maxLvl = 30, x = 0.526, y = 0.573, uiMapID = 1413, faction = "Horde", dungeons = { "Wailing Caverns (17–24)", "Razorfen Kraul (29–38)", "Razorfen Downs (37–46)" } },
    { name = "Mulgore", continent = "kalimdor", minLvl = 1, maxLvl = 10, x = 0.474, y = 0.613, uiMapID = 1412, faction = "Horde" },
    { name = "Stonetalon Mountains", continent = "kalimdor", minLvl = 15, maxLvl = 25, x = 0.443, y = 0.476, uiMapID = 1442, faction = "Contested" },
    { name = "Desolace", continent = "kalimdor", minLvl = 30, maxLvl = 40, x = 0.416, y = 0.577, uiMapID = 1443, faction = "Contested", dungeons = { "Maraudon (46–55)" } },
    { name = "Dustwallow Marsh", continent = "kalimdor", minLvl = 35, maxLvl = 45, x = 0.565, y = 0.679, uiMapID = 1445, faction = "Contested", dungeons = { "Onyxia's Lair (60+)" } },
    { name = "Thousand Needles", continent = "kalimdor", minLvl = 25, maxLvl = 35, x = 0.571, y = 0.760, uiMapID = 1441, faction = "Contested" },
    { name = "Feralas", continent = "kalimdor", minLvl = 40, maxLvl = 50, x = 0.437, y = 0.703, uiMapID = 1444, faction = "Contested", dungeons = { "Dire Maul (55–60)" } },
    { name = "Tanaris", continent = "kalimdor", minLvl = 40, maxLvl = 50, x = 0.556, y = 0.861, uiMapID = 1446, faction = "Contested", dungeons = { "Zul'Farrak (44–54)" } },
    { name = "Un'Goro Crater", continent = "kalimdor", minLvl = 50, maxLvl = 55, x = 0.496, y = 0.805, uiMapID = 1449, faction = "Contested" },
    { name = "Silithus", continent = "kalimdor", minLvl = 55, maxLvl = 60, x = 0.426, y = 0.863, uiMapID = 1451, faction = "Contested", dungeons = { "Temple of Ahn'Qiraj (60+)", "Ruins of Ahn'Qiraj (60+)" } },

    -- Eastern Kingdoms (22 zones)
    { name = "Tirisfal Glades", continent = "eastern_kingdoms", minLvl = 1, maxLvl = 10, x = 0.447, y = 0.215, uiMapID = 1420, faction = "Horde", dungeons = { "Scarlet Monastery (32–45)" } },
    { name = "Silverpine Forest", continent = "eastern_kingdoms", minLvl = 10, maxLvl = 20, x = 0.397, y = 0.293, uiMapID = 1421, faction = "Horde", dungeons = { "Shadowfang Keep (22–30)" } },
    { name = "Hillsbrad Foothills", continent = "eastern_kingdoms", minLvl = 20, maxLvl = 30, x = 0.479, y = 0.348, uiMapID = 1424, faction = "Contested" },
    { name = "Alterac Mountains", continent = "eastern_kingdoms", minLvl = 30, maxLvl = 40, x = 0.469, y = 0.286, uiMapID = 1416, faction = "Contested" },
    { name = "Western Plaguelands", continent = "eastern_kingdoms", minLvl = 51, maxLvl = 58, x = 0.505, y = 0.232, uiMapID = 1422, faction = "Contested", dungeons = { "Scholomance (58–60)" } },
    { name = "Eastern Plaguelands", continent = "eastern_kingdoms", minLvl = 53, maxLvl = 60, x = 0.556, y = 0.223, uiMapID = 1423, faction = "Contested", dungeons = { "Stratholme (58–60)" } },
    { name = "The Hinterlands", continent = "eastern_kingdoms", minLvl = 40, maxLvl = 50, x = 0.541, y = 0.315, uiMapID = 1425, faction = "Contested" },
    { name = "Arathi Highlands", continent = "eastern_kingdoms", minLvl = 30, maxLvl = 40, x = 0.532, y = 0.379, uiMapID = 1417, faction = "Contested" },
    { name = "Wetlands", continent = "eastern_kingdoms", minLvl = 20, maxLvl = 30, x = 0.526, y = 0.472, uiMapID = 1437, faction = "Contested" },
    { name = "Dun Morogh", continent = "eastern_kingdoms", minLvl = 1, maxLvl = 10, x = 0.436, y = 0.531, uiMapID = 1426, faction = "Alliance", dungeons = { "Gnomeregan (29–38)" } },
    { name = "Loch Modan", continent = "eastern_kingdoms", minLvl = 10, maxLvl = 20, x = 0.552, y = 0.544, uiMapID = 1432, faction = "Alliance" },
    { name = "Badlands", continent = "eastern_kingdoms", minLvl = 35, maxLvl = 45, x = 0.546, y = 0.587, uiMapID = 1418, faction = "Contested", dungeons = { "Uldaman (41–51)" } },
    { name = "Searing Gorge", continent = "eastern_kingdoms", minLvl = 43, maxLvl = 50, x = 0.491, y = 0.608, uiMapID = 1427, faction = "Contested", dungeons = { "Blackrock Depths (52–60)", "Molten Core (60+)" } },
    { name = "Burning Steppes", continent = "eastern_kingdoms", minLvl = 50, maxLvl = 58, x = 0.506, y = 0.656, uiMapID = 1428, faction = "Contested", dungeons = { "Lower Blackrock Spire (55–60)", "Blackwing Lair (60+)" } },
    { name = "Redridge Mountains", continent = "eastern_kingdoms", minLvl = 15, maxLvl = 25, x = 0.532, y = 0.714, uiMapID = 1433, faction = "Contested" },
    { name = "Elwynn Forest", continent = "eastern_kingdoms", minLvl = 1, maxLvl = 10, x = 0.470, y = 0.706, uiMapID = 1429, faction = "Alliance", dungeons = { "Stockade (24–32)" } },
    { name = "Westfall", continent = "eastern_kingdoms", minLvl = 10, maxLvl = 20, x = 0.407, y = 0.774, uiMapID = 1436, faction = "Alliance", dungeons = { "The Deadmines (17–26)" } },
    { name = "Duskwood", continent = "eastern_kingdoms", minLvl = 18, maxLvl = 30, x = 0.468, y = 0.772, uiMapID = 1431, faction = "Contested" },
    { name = "Swamp of Sorrows", continent = "eastern_kingdoms", minLvl = 35, maxLvl = 45, x = 0.548, y = 0.755, uiMapID = 1435, faction = "Contested", dungeons = { "Sunken Temple (50–60)" } },
    { name = "Deadwind Pass", continent = "eastern_kingdoms", minLvl = 55, maxLvl = 60, x = 0.509, y = 0.775, uiMapID = 1430, faction = "Contested", dungeons = { "Karazhan (70+)" } },
    { name = "Blasted Lands", continent = "eastern_kingdoms", minLvl = 45, maxLvl = 55, x = 0.542, y = 0.799, uiMapID = 1419, faction = "Contested" },
    { name = "Stranglethorn Vale", continent = "eastern_kingdoms", minLvl = 30, maxLvl = 45, x = 0.480, y = 0.844, uiMapID = 1434, faction = "Contested", dungeons = { "Zul'Gurub (60+)" } },
}

WoWEternityAddon.ZONE_LEVEL_RANGES = ZONE_LEVEL_RANGES

local ZONE_BY_MAPID = {}
local ZONE_BY_NAME = {}
for _, z in ipairs(ZONE_LEVEL_RANGES) do
    if z.uiMapID then
        ZONE_BY_MAPID[z.uiMapID] = z
    end
    local clean = z.name:lower():gsub("%s+", "")
    ZONE_BY_NAME[clean] = z
end
WoWEternityAddon.ZONE_BY_MAPID = ZONE_BY_MAPID
WoWEternityAddon.ZONE_BY_NAME = ZONE_BY_NAME

function WoWEternityAddon:GetZoneLevelColor(minLvl, maxLvl, playerLevel)
    playerLevel = playerLevel or ((UnitLevel and UnitLevel("player")) or 1)
    minLvl = minLvl or 1
    maxLvl = maxLvl or minLvl
    if playerLevel < minLvl - 4 then
        return "|cffff3333", "Deadly", 1.0, 0.20, 0.20
    elseif playerLevel < minLvl then
        return "|cffff8822", "Challenging", 1.0, 0.53, 0.13
    elseif playerLevel <= maxLvl then
        return "|cff44ff44", "Ideal", 0.27, 1.0, 0.27
    elseif playerLevel <= maxLvl + 4 then
        return "|cffffd100", "Easy", 1.0, 0.82, 0.0
    else
        return "|cff888888", "Trivial", 0.55, 0.55, 0.55
    end
end

function WoWEternityAddon:IsContinentMap(mapID)
    if mapID == 1414 or mapID == 12 then return "kalimdor" end
    if mapID == 1415 or mapID == 13 then return "eastern_kingdoms" end
    if C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        if info and info.name then
            local n = info.name:lower()
            if n:find("kalimdor") then return "kalimdor" end
            if n:find("eastern") or n:find("kingdom") then return "eastern_kingdoms" end
        end
    end
    if GetCurrentMapContinent then
        local c = GetCurrentMapContinent()
        local z = (GetCurrentMapZone and GetCurrentMapZone()) or 0
        if z == 0 then
            if c == 1 then return "kalimdor" end
            if c == 2 then return "eastern_kingdoms" end
        end
    end
    return nil
end

function WoWEternityAddon:GetCurrentZoneData(mapID)
    if not mapID or mapID == 0 then return nil end
    if self.ZONE_BY_MAPID and self.ZONE_BY_MAPID[mapID] then
        return self.ZONE_BY_MAPID[mapID]
    end
    if C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        if info and info.name and self.ZONE_BY_NAME then
            local clean = info.name:lower():gsub("%s+", "")
            if self.ZONE_BY_NAME[clean] then return self.ZONE_BY_NAME[clean] end
        end
    end
    local currentText = (GetZoneText and GetZoneText()) or (GetRealZoneText and GetRealZoneText())
    if currentText and self.ZONE_BY_NAME then
        local clean = currentText:lower():gsub("%s+", "")
        if self.ZONE_BY_NAME[clean] then return self.ZONE_BY_NAME[clean] end
    end
    return nil
end

function WoWEternityAddon:GetOrCreateMapZoneBadge(canvas)
    if self.mapZoneBadge then
        if canvas and self.mapZoneBadge:GetParent() ~= canvas then
            self.mapZoneBadge:SetParent(canvas)
        end
        return self.mapZoneBadge
    end
    if not CreateFrame then return nil end

    local badge = CreateFrame("Button", "WoWEternity_MapZoneBadge", canvas)
    badge:SetSize(72, 28)
    badge:SetFrameStrata("HIGH")

    -- Subtle high-contrast dark backdrop matching continent pills
    local bg = badge:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(badge)
    bg:SetColorTexture(0.04, 0.04, 0.07, 0.88)
    badge.bg = bg

    -- Border accent tinted by difficulty
    local border = badge:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.90, 0.80, 0.50, 0.45)
    badge.border = border

    -- Large bold ##–## level range filling badge face
    local text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    pcall(function()
        local fPath = text:GetFont()
        if fPath then text:SetFont(fPath, 16, "OUTLINE") end
    end)
    text:SetAllPoints(badge)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetShadowOffset(1, -1)
    badge.text = text
    badge.subText = text

    badge:EnableMouse(true)
    badge:SetScript("OnEnter", function(b)
        local br = b.currentBorderR or 0.90
        local bgCol = b.currentBorderG or 0.80
        local bb = b.currentBorderB or 0.50
        if b.border then b.border:SetColorTexture(br, bgCol, bb, 0.85) end
        if not GameTooltip or not b.zoneData then return end
        GameTooltip:SetOwner(b, "ANCHOR_BOTTOMRIGHT", 0, -4)
        local z = b.zoneData
        local playerLvl = (UnitLevel and UnitLevel("player")) or 1
        local hex, diffLabel = WoWEternityAddon:GetZoneLevelColor(z.minLvl, z.maxLvl, playerLvl)
        GameTooltip:AddLine("|cffe6cc80WoW Eternity Addon|r", 1, 1, 1)
        GameTooltip:AddLine(string.format("Level Range: %s%d–%d|r  (%s%s|r)", hex, z.minLvl, z.maxLvl, hex, diffLabel), 1, 1, 1)
        GameTooltip:AddLine(string.format("Your Level: |cffffd100%d|r", playerLvl), 0.9, 0.9, 0.9)
        if z.faction then
            local fHex = (z.faction == "Horde" and "|cffff4444") or (z.faction == "Alliance" and "|cff38bdf8") or "|cffffd100"
            GameTooltip:AddLine(string.format("Territory: %s%s|r", fHex, z.faction), 0.8, 0.8, 0.8)
        end
        if z.dungeons and #z.dungeons > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffd100Dungeons in Zone:|r", 1, 0.82, 0)
            for _, d in ipairs(z.dungeons) do
                GameTooltip:AddLine(string.format("  • |cffffffff%s|r", d), 0.9, 0.9, 0.9)
            end
        end
        local faction = WoWEternityAddon.levelingFaction or WoWEternityAddon:GetPlayerFaction()
        local activeStep = WoWEternityAddon:GetActiveLevelingStep(faction)
        if activeStep and activeStep.location and activeStep.location:lower():find(z.name:lower(), 1, true) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("|cff00ff00Active Guide Objective:|r Step #%d (%s)", activeStep.stepNumber, activeStep.title), 0.2, 1.0, 0.2)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff888888Click to open WoW Eternity Panel (/wea)|r", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)

    badge:SetScript("OnLeave", function(b)
        local br = b.currentBorderR or 0.90
        local bgCol = b.currentBorderG or 0.80
        local bb = b.currentBorderB or 0.50
        if b.border then b.border:SetColorTexture(br, bgCol, bb, 0.45) end
        if GameTooltip then GameTooltip:Hide() end
    end)

    badge:SetScript("OnClick", function()
        WoWEternityAddon:ToggleSettingsFrame()
    end)

    self.mapZoneBadge = badge
    return badge
end

function WoWEternityAddon:InitMapZoneOverlays()
    if not WorldMapFrame then return end
    if self.mapOverlaysInitialized then return end
    self.mapOverlaysInitialized = true
    self.continentZonePills = {}

    if WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", function()
            WoWEternityAddon:UpdateMapZoneOverlays()
        end)
    end

    local overlayWatcher = CreateFrame and CreateFrame("Frame")
    if overlayWatcher and overlayWatcher.SetScript then
        overlayWatcher.elapsed = 0
        overlayWatcher:SetScript("OnUpdate", function(_, dt)
            if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
            overlayWatcher.elapsed = overlayWatcher.elapsed + (dt or 0)
            if overlayWatcher.elapsed >= 0.2 then
                overlayWatcher.elapsed = 0
                local currentMap = 0
                if WorldMapFrame.GetMapID then
                    currentMap = WorldMapFrame:GetMapID() or 0
                elseif C_Map and C_Map.GetBestMapForUnit then
                    currentMap = C_Map.GetBestMapForUnit("player") or 0
                end
                if currentMap ~= WoWEternityAddon.lastMapOverlayMapID then
                    WoWEternityAddon.lastMapOverlayMapID = currentMap
                    WoWEternityAddon:UpdateMapZoneOverlays()
                end
            end
        end)
    end
end

function WoWEternityAddon:UpdateMapZoneOverlays()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local show = (WoWEternityAddonDB and WoWEternityAddonDB.showMapOverlays ~= false)
    if not show then
        if self.mapZoneBadge then self.mapZoneBadge:Hide() end
        if self.continentZonePills then
            for _, p in ipairs(self.continentZonePills) do p:Hide() end
        end
        return
    end

    local canvas = (WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas())
        or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
        or WorldMapButton
        or WorldMapFrame

    local canvasW, canvasH = 1002, 668
    if canvas.GetSize then
        local w, h = canvas:GetSize()
        if w and w > 0 and h and h > 0 then
            canvasW, canvasH = w, h
        end
    end

    local currentMapID = 0
    if WorldMapFrame.GetMapID then
        currentMapID = WorldMapFrame:GetMapID() or 0
    elseif C_Map and C_Map.GetBestMapForUnit then
        currentMapID = C_Map.GetBestMapForUnit("player") or 0
    end

    local playerLevel = (UnitLevel and UnitLevel("player")) or 1
    local contKey = self:IsContinentMap(currentMapID)

    self.continentZonePills = self.continentZonePills or {}

    if contKey then
        -- Continent Map (Kalimdor or Eastern Kingdoms)
        if self.mapZoneBadge then self.mapZoneBadge:Hide() end

        local pIndex = 0
        for _, z in ipairs(ZONE_LEVEL_RANGES) do
            if z.continent == contKey then
                pIndex = pIndex + 1
                local pill = self.continentZonePills[pIndex]
                if not pill then
                    pill = CreateFrame("Button", "WEA_ContZonePill_" .. pIndex, canvas)
                    pill:SetSize(46, 18)
                    pill:SetFrameStrata("HIGH")

                    local bg = pill:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints(pill)
                    bg:SetColorTexture(0.04, 0.04, 0.07, 0.82)
                    pill.bg = bg

                    local border = pill:CreateTexture(nil, "BORDER")
                    border:SetPoint("TOPLEFT", -1, 1)
                    border:SetPoint("BOTTOMRIGHT", 1, -1)
                    border:SetColorTexture(0.90, 0.80, 0.50, 0.30)
                    pill.border = border

                    local text = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    text:SetAllPoints(pill)
                    text:SetJustifyH("CENTER")
                    text:SetJustifyV("MIDDLE")
                    pill.text = text

                    pill:SetScript("OnEnter", function(p)
                        if not GameTooltip or not p.zoneData then return end
                        GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
                        local zd = p.zoneData
                        local pLvl = (UnitLevel and UnitLevel("player")) or 1
                        local hex, diffLabel = WoWEternityAddon:GetZoneLevelColor(zd.minLvl, zd.maxLvl, pLvl)
                        GameTooltip:AddLine("|cffe6cc80WoW Eternity Addon|r", 1, 1, 1)
                        GameTooltip:AddLine(string.format("Zone: |cffffffff%s|r  |cffe6cc80[Level %d–%d]|r", zd.name, zd.minLvl, zd.maxLvl), 1, 1, 1)
                        GameTooltip:AddLine(string.format("Difficulty: %s%s|r  ·  Your Level: |cffffd100%d|r", hex, diffLabel, pLvl), 0.9, 0.9, 0.9)
                        if zd.faction then
                            local fHex = (zd.faction == "Horde" and "|cffff4444") or (zd.faction == "Alliance" and "|cff38bdf8") or "|cffffd100"
                            GameTooltip:AddLine(string.format("Territory: %s%s|r", fHex, zd.faction), 0.8, 0.8, 0.8)
                        end
                        if zd.dungeons and #zd.dungeons > 0 then
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine("|cffffd100Dungeons:|r", 1, 0.82, 0)
                            for _, d in ipairs(zd.dungeons) do
                                GameTooltip:AddLine(string.format("  • |cffffffff%s|r", d), 0.9, 0.9, 0.9)
                            end
                        end
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("|cff38bdf8Click to zoom into zone map|r", 0.4, 0.8, 1.0)
                        GameTooltip:Show()
                    end)

                    pill:SetScript("OnLeave", function()
                        if GameTooltip then GameTooltip:Hide() end
                    end)

                    pill:SetScript("OnClick", function(p)
                        if p.zoneData and p.zoneData.uiMapID then
                            if WorldMapFrame and WorldMapFrame.SetMapID then
                                WorldMapFrame:SetMapID(p.zoneData.uiMapID)
                            elseif SetMapByID then
                                SetMapByID(p.zoneData.uiMapID)
                            end
                        end
                    end)

                    self.continentZonePills[pIndex] = pill
                end

                if pill:GetParent() ~= canvas then
                    pill:SetParent(canvas)
                end

                pill.zoneData = z
                local hex, _, r, g, b = self:GetZoneLevelColor(z.minLvl, z.maxLvl, playerLevel)
                pill.text:SetText(string.format("%s%d–%d|r", hex, z.minLvl, z.maxLvl))
                if pill.border then
                    pill.border:SetColorTexture(r, g, b, 0.45)
                end
                pill:ClearAllPoints()
                pill:SetPoint("CENTER", canvas, "TOPLEFT", z.x * canvasW, -z.y * canvasH)
                pill:Show()
            end
        end

        for i = pIndex + 1, #self.continentZonePills do
            self.continentZonePills[i]:Hide()
        end
    else
        -- Zone Map
        for _, p in ipairs(self.continentZonePills) do
            p:Hide()
        end

        local zoneData = self:GetCurrentZoneData(currentMapID)
        if zoneData then
            local badge = self:GetOrCreateMapZoneBadge(canvas)
            if badge then
                badge.zoneData = zoneData
                local hex, diffLabel, r, g, b = self:GetZoneLevelColor(zoneData.minLvl, zoneData.maxLvl, playerLevel)
                badge.text:SetText(string.format("%s%d–%d|r", hex, zoneData.minLvl, zoneData.maxLvl))
                badge.currentBorderR = r
                badge.currentBorderG = g
                badge.currentBorderB = b
                if badge.border then
                    badge.border:SetColorTexture(r, g, b, 0.45)
                end
                badge:ClearAllPoints()
                badge:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -12, -12)
                badge:Show()
            end
        else
            if self.mapZoneBadge then self.mapZoneBadge:Hide() end
        end
    end
end

function WoWEternityAddon:ToggleMapZoneOverlays()
    WoWEternityAddonDB = WoWEternityAddonDB or {}
    WoWEternityAddonDB.showMapOverlays = not (WoWEternityAddonDB.showMapOverlays ~= false)
    self:UpdateMapZoneOverlays()
    self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Map Zone Level Overlays: %s", WoWEternityAddonDB.showMapOverlays and "|cff00ff00Enabled|r" or "|cffff2020Disabled|r"))
end

function WoWEternityAddon:PrintMapCursorPosition()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        self:Print("|cffff2020[WoW Eternity Addon]|r Please open your World Map first.")
        return
    end

    local canvas = (WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas())
        or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
        or WorldMapButton
        or WorldMapFrame

    if not GetCursorPosition or not canvas.GetLeft or not canvas.GetTop then
        self:Print("|cffff2020[WoW Eternity Addon]|r Cursor position unavailable.")
        return
    end

    local mx, my = GetCursorPosition()
    local scale = (canvas.GetEffectiveScale and canvas:GetEffectiveScale()) or 1
    local left = (canvas.GetLeft and canvas:GetLeft()) or 0
    local top = (canvas.GetTop and canvas:GetTop()) or 0
    local width = (canvas.GetWidth and canvas:GetWidth()) or 1
    local height = (canvas.GetHeight and canvas:GetHeight()) or 1

    mx = mx / scale
    my = my / scale

    local x = (mx - left) / width
    local y = (top - my) / height

    self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Map Cursor: |cff00ff00x = %.2f, y = %.2f|r (Cursor: %.1f, %.1f)", x, y, x * 100, y * 100))
end

-- ============================================================================
-- Questie-Style On-Screen Tracker HUD (Multi-Step Focused)
-- ============================================================================

function WoWEternityAddon:CreateTrackerHUD()
    if not CreateFrame then return end
    if self.trackerFrame then return end

    local frame = CreateFrame("Button", "WoWEternityAddonTrackerFrame", UIParent, GetBackdropTemplate())
    self.trackerFrame = frame

    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(0)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    -- Load saved tracker settings
    local db = WoWEternityAddonDB and WoWEternityAddonDB.tracker
    local pt = (db and db.point) or "TOPRIGHT"
    local x = (db and db.x) or -40
    local y = (db and db.y) or -220
    local width = (db and db.width) or 280
    frame:SetSize(width, 160)
    frame:SetPoint(pt, UIParent, pt, x, y)

    -- Questie-style Semi-Transparent Dark Tooltip Backdrop
    ApplyBackdrop(frame, 0.05, 0.05, 0.08, 0.85, 0.35, 0.38, 0.45, 0.90)

    -- Draggable
    frame:SetScript("OnDragStart", function(f)
        if not (WoWEternityAddonDB and WoWEternityAddonDB.tracker and WoWEternityAddonDB.tracker.locked) then
            f:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, _, xOfs, yOfs = f:GetPoint()
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.tracker = WoWEternityAddonDB.tracker or {}
        WoWEternityAddonDB.tracker.point = point or "TOPRIGHT"
        WoWEternityAddonDB.tracker.x = xOfs or -40
        WoWEternityAddonDB.tracker.y = yOfs or -220
    end)

    -- Header Bar
    local headerBar = CreateFrame("Button", nil, frame)
    headerBar:SetPoint("TOPLEFT", 4, -4)
    headerBar:SetPoint("TOPRIGHT", -4, -4)
    headerBar:SetHeight(22)
    headerBar:EnableMouse(true)
    headerBar:RegisterForDrag("LeftButton")
    headerBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    headerBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, _, xOfs, yOfs = frame:GetPoint()
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.tracker = WoWEternityAddonDB.tracker or {}
        WoWEternityAddonDB.tracker.point = point or "TOPRIGHT"
        WoWEternityAddonDB.tracker.x = xOfs or -40
        WoWEternityAddonDB.tracker.y = yOfs or -220
    end)
    frame.headerBar = headerBar

    -- Icon (Questie / Book style)
    local iconBtn = CreateFrame("Button", nil, headerBar)
    iconBtn:SetSize(16, 16)
    iconBtn:SetPoint("LEFT", 4, 0)
    local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints(iconBtn)
    iconTex:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    iconBtn.tex = iconTex
    iconBtn:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffe6cc80WoW Eternity Quest Tracker|r")
        GameTooltip:AddLine("|cffffffffLeft-Click:|r Open Cadberry Leveling Guide", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffffffRight-Click:|r Toggle Waypoint Navigation Arrow", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    iconBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    iconBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    iconBtn:SetScript("OnClick", function(_, mouseBtn)
        if mouseBtn == "RightButton" then
            WoWEternityAddon:ToggleWaypointArrow()
        else
            WoWEternityAddon:ToggleSettingsFrame("Leveling")
        end
    end)
    frame.iconBtn = iconBtn

    -- Zone / Guide Title in Header
    local zoneTitle = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneTitle:SetPoint("LEFT", iconBtn, "RIGHT", 6, 0)
    zoneTitle:SetPoint("RIGHT", -26, 0)
    zoneTitle:SetJustifyH("LEFT")
    zoneTitle:SetWordWrap(false)
    zoneTitle:SetText("|cffe6cc80Leveling Guide|r")
    frame.zoneTitle = zoneTitle

    -- Collapse / Expand Button [-] / [+]
    local collapseBtn = CreateFrame("Button", nil, headerBar, GetBackdropTemplate())
    collapseBtn:SetSize(16, 16)
    collapseBtn:SetPoint("RIGHT", -4, 0)
    ApplyBackdrop(collapseBtn, 0.08, 0.10, 0.16, 0.9, 0.28, 0.32, 0.45, 0.9)
    local collapseText = collapseBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    collapseText:SetPoint("CENTER", 0, 0)
    collapseText:SetText("[-]")
    collapseBtn.text = collapseText
    collapseBtn:SetScript("OnClick", function()
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.tracker = WoWEternityAddonDB.tracker or {}
        WoWEternityAddonDB.tracker.collapsed = not WoWEternityAddonDB.tracker.collapsed
        WoWEternityAddon:UpdateTrackerHUD()
    end)
    frame.collapseBtn = collapseBtn

    -- Content Container (Collapsible)
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", 8, -26)
    contentFrame:SetPoint("BOTTOMRIGHT", -8, 6)
    frame.contentFrame = contentFrame

    -- === Active Step Section ===
    local activeContainer = CreateFrame("Frame", nil, contentFrame)
    activeContainer:SetPoint("TOPLEFT", 0, 0)
    activeContainer:SetPoint("TOPRIGHT", 0, 0)
    activeContainer:SetHeight(80)
    frame.activeContainer = activeContainer

    -- Active Step Title (Gold with cyan level badge)
    local activeTitle = activeContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    activeTitle:SetPoint("TOPLEFT", 0, -2)
    activeTitle:SetPoint("TOPRIGHT", 0, -2)
    activeTitle:SetJustifyH("LEFT")
    activeTitle:SetWordWrap(true)
    frame.activeTitle = activeTitle

    -- Active Step Subline (Location & Real-time Distance)
    local activeSub = activeContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    activeSub:SetPoint("TOPLEFT", activeTitle, "BOTTOMLEFT", 0, -2)
    activeSub:SetPoint("TOPRIGHT", 0, -2)
    activeSub:SetJustifyH("LEFT")
    activeSub:SetWordWrap(false)
    frame.activeSub = activeSub

    -- Active Step Interactive Checkbox
    local activeCB = CreateFrame("CheckButton", "WEA_TrackerActiveCB", activeContainer, "UICheckButtonTemplate")
    activeCB:SetSize(18, 18)
    activeCB:SetPoint("TOPLEFT", activeSub, "BOTTOMLEFT", 0, -4)
    activeCB:SetScript("OnClick", function(cb)
        local faction = WoWEternityAddon.levelingFaction or WoWEternityAddon:GetPlayerFaction()
        local step = WoWEternityAddon:GetActiveLevelingStep(faction)
        if step then
            WoWEternityAddonCharDB = WoWEternityAddonCharDB or {}
            WoWEternityAddonCharDB.cadberryCompleted = WoWEternityAddonCharDB.cadberryCompleted or {}
            WoWEternityAddonCharDB.manuallyUnchecked = WoWEternityAddonCharDB.manuallyUnchecked or {}
            local isChecked = cb:GetChecked()
            if isChecked then
                WoWEternityAddonCharDB.cadberryCompleted[step.id] = true
                WoWEternityAddonCharDB.manuallyUnchecked[step.id] = nil
            else
                WoWEternityAddonCharDB.cadberryCompleted[step.id] = nil
                WoWEternityAddonCharDB.manuallyUnchecked[step.id] = true
            end
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
            if isChecked then
                WoWEternityAddon:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Completed Step #%d: |cffffd100%s|r", step.stepNumber, step.title))
            end
            if WoWEternityAddon.UpdateLevelingTab then WoWEternityAddon:UpdateLevelingTab() end
            if WoWEternityAddon.UpdateWaypointArrow then WoWEternityAddon:UpdateWaypointArrow() end
            if WoWEternityAddon.UpdateWorldMapPins then WoWEternityAddon:UpdateWorldMapPins() end
            WoWEternityAddon:UpdateTrackerHUD()
        end
    end)
    frame.activeCB = activeCB

    local activeCBText = activeContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    activeCBText:SetPoint("LEFT", activeCB, "RIGHT", 4, 0)
    activeCBText:SetPoint("RIGHT", 0, 0)
    activeCBText:SetJustifyH("LEFT")
    activeCBText:SetWordWrap(false)
    activeCBText:SetText("|cffd1d5dbMark Step Complete|r")
    frame.activeCBText = activeCBText

    -- Objectives / Details (Bullet 1 & 2)
    local activeObj1 = activeContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    activeObj1:SetPoint("TOPLEFT", activeCB, "BOTTOMLEFT", 4, -3)
    activeObj1:SetPoint("TOPRIGHT", 0, -3)
    activeObj1:SetJustifyH("LEFT")
    activeObj1:SetWordWrap(true)
    frame.activeObj1 = activeObj1

    local activeObj2 = activeContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    activeObj2:SetPoint("TOPLEFT", activeObj1, "BOTTOMLEFT", 0, -2)
    activeObj2:SetPoint("TOPRIGHT", 0, -2)
    activeObj2:SetJustifyH("LEFT")
    activeObj2:SetWordWrap(true)
    frame.activeObj2 = activeObj2

    -- Tactical Note
    local activeNote = activeContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    activeNote:SetPoint("TOPLEFT", activeObj2, "BOTTOMLEFT", 0, -2)
    activeNote:SetPoint("TOPRIGHT", 0, -2)
    activeNote:SetJustifyH("LEFT")
    activeNote:SetWordWrap(true)
    frame.activeNote = activeNote

    -- Clicking active step opens leveling tab
    activeContainer:EnableMouse(true)
    activeContainer:SetScript("OnMouseDown", function()
        WoWEternityAddon:ToggleSettingsFrame("Leveling")
    end)

    -- === Upcoming Steps Section ===
    local upcomingContainer = CreateFrame("Frame", nil, contentFrame)
    upcomingContainer:SetPoint("TOPLEFT", activeContainer, "BOTTOMLEFT", 0, -6)
    upcomingContainer:SetPoint("TOPRIGHT", activeContainer, "BOTTOMRIGHT", 0, -6)
    upcomingContainer:SetHeight(48)
    frame.upcomingContainer = upcomingContainer

    local upcomingDivider = upcomingContainer:CreateTexture(nil, "ARTWORK")
    upcomingDivider:SetPoint("TOPLEFT", 0, 0)
    upcomingDivider:SetPoint("TOPRIGHT", 0, 0)
    upcomingDivider:SetHeight(1)
    upcomingDivider:SetColorTexture(0.25, 0.28, 0.35, 0.6)
    frame.upcomingDivider = upcomingDivider

    local upcomingHeader = upcomingContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    upcomingHeader:SetPoint("TOPLEFT", 0, -4)
    upcomingHeader:SetText("|cff6b7280UPCOMING STEPS|r")
    frame.upcomingHeader = upcomingHeader

    local upcomingBtn1 = CreateFrame("Button", nil, upcomingContainer)
    upcomingBtn1:SetPoint("TOPLEFT", 0, -18)
    upcomingBtn1:SetPoint("TOPRIGHT", 0, -18)
    upcomingBtn1:SetHeight(16)
    local upcomingText1 = upcomingBtn1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    upcomingText1:SetAllPoints(upcomingBtn1)
    upcomingText1:SetJustifyH("LEFT")
    upcomingText1:SetWordWrap(false)
    upcomingBtn1.text = upcomingText1
    upcomingBtn1:SetScript("OnClick", function()
        WoWEternityAddon:ToggleSettingsFrame("Leveling")
    end)
    frame.upcomingBtn1 = upcomingBtn1

    local upcomingBtn2 = CreateFrame("Button", nil, upcomingContainer)
    upcomingBtn2:SetPoint("TOPLEFT", upcomingBtn1, "BOTTOMLEFT", 0, -2)
    upcomingBtn2:SetPoint("TOPRIGHT", upcomingBtn1, "BOTTOMRIGHT", 0, -2)
    upcomingBtn2:SetHeight(16)
    local upcomingText2 = upcomingBtn2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    upcomingText2:SetAllPoints(upcomingBtn2)
    upcomingText2:SetJustifyH("LEFT")
    upcomingText2:SetWordWrap(false)
    upcomingBtn2.text = upcomingText2
    upcomingBtn2:SetScript("OnClick", function()
        WoWEternityAddon:ToggleSettingsFrame("Leveling")
    end)
    frame.upcomingBtn2 = upcomingBtn2

    -- Throttled OnUpdate for live distance & coords
    local trackerElapsed = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        trackerElapsed = trackerElapsed + (elapsed or 0)
        if trackerElapsed >= 0.25 then
            trackerElapsed = 0
            if frame.contentFrame:IsShown() and frame.currentStep then
                local distYards, inSameZone = WoWEternityAddon:GetDistanceToStep(frame.currentStep)
                if distYards and inSameZone then
                    local distStr
                    if distYards < 15 then
                        distStr = "|cff00ff00Arrived! (< 15 yds)|r"
                    elseif distYards >= 1000 then
                        distStr = string.format("|cff38bdf8%.1fk yds|r", distYards / 1000)
                    else
                        distStr = string.format("|cff38bdf8%d yds|r", math.floor(distYards))
                    end
                    local loc = (frame.currentStep.location and frame.currentStep.location ~= "") and frame.currentStep.location or (frame.currentStep.dungeonName and frame.currentStep.dungeonName ~= "" and frame.currentStep.dungeonName) or "Current Zone"
                    frame.activeSub:SetText(string.format("|cff9ca3af%s|r  ·  %s", loc, distStr))
                end
            end
        end
    end)

    -- Initial visibility check
    if db and db.shown == false then
        frame:Hide()
    else
        frame:Show()
    end

    self:UpdateTrackerHUD()
end

function WoWEternityAddon:UpdateTrackerHUD()
    local frame = self.trackerFrame
    if not frame then return end

    local db = WoWEternityAddonDB and WoWEternityAddonDB.tracker
    local isCollapsed = db and db.collapsed

    if isCollapsed then
        frame.collapseBtn.text:SetText("[+]")
        frame.contentFrame:Hide()
        frame:SetHeight(28)
        return
    end

    frame.collapseBtn.text:SetText("[-]")
    frame.contentFrame:Show()

    local faction = self.levelingFaction or "alliance"
    local activeStep = self:GetActiveLevelingStep(faction)
    frame.currentStep = activeStep

    if not activeStep then
        -- All steps finished
        frame.zoneTitle:SetText("|cffe6cc80All Steps Complete!|r")
        frame.activeTitle:SetText("|cff00ff00✔ Level 60 Milestone Reached!|r")
        frame.activeSub:SetText("|cffe6cc80Ready for Endgame Raids & Pre-BiS|r")
        frame.activeCB:Hide()
        frame.activeCBText:Hide()
        frame.activeObj1:Hide()
        frame.activeObj2:Hide()
        frame.activeNote:Hide()
        frame.upcomingContainer:Hide()
        frame:SetHeight(75)
        return
    end

    -- Zone in header
    local zone = (activeStep.location and activeStep.location ~= "" and activeStep.location:match("^([^,(/]+)")) or (activeStep.dungeonName and activeStep.dungeonName ~= "" and activeStep.dungeonName) or "Cadberry Guide"
    frame.zoneTitle:SetText(string.format("|cffe6cc80%s|r", zone:match("^%s*(.-)%s*$")))

    -- Active Step Title: [Badge] Title
    frame.activeTitle:SetText(string.format("|cff38bdf8[%s]|r |cffffd100#%d: %s|r", activeStep.levelBadge, activeStep.stepNumber, activeStep.title))

    -- Distance & Subline
    local distYards, inSameZone = self:GetDistanceToStep(activeStep)
    local distStr = ""
    if distYards and inSameZone then
        if distYards < 15 then
            distStr = "  ·  |cff00ff00Arrived! (< 15 yds)|r"
        elseif distYards >= 1000 then
            distStr = string.format("  ·  |cff38bdf8%.1fk yds|r", distYards / 1000)
        else
            distStr = string.format("  ·  |cff38bdf8%d yds|r", math.floor(distYards))
        end
    elseif activeStep.location and activeStep.location ~= "" then
        distStr = ""
    end
    local loc = (activeStep.location and activeStep.location ~= "") and activeStep.location or (activeStep.dungeonName and activeStep.dungeonName ~= "" and activeStep.dungeonName) or "Cadberry Route"
    frame.activeSub:SetText(string.format("|cff9ca3af%s|r%s", loc, distStr))

    -- Checkbox
    frame.activeCB:Show()
    frame.activeCBText:Show()
    local isDone = WoWEternityAddonCharDB and WoWEternityAddonCharDB.cadberryCompleted and WoWEternityAddonCharDB.cadberryCompleted[activeStep.id]
    frame.activeCB:SetChecked(isDone == true)

    -- Objectives / Details
    local contentH = 46
    local details = activeStep.details or {}
    if #details >= 1 then
        frame.activeObj1:SetText(string.format("|cff93c5fd•|r %s", details[1]))
        frame.activeObj1:Show()
        contentH = contentH + 16
    else
        frame.activeObj1:Hide()
    end

    if #details >= 2 then
        frame.activeObj2:SetText(string.format("|cff93c5fd•|r %s", details[2]))
        frame.activeObj2:Show()
        contentH = contentH + 16
    else
        frame.activeObj2:Hide()
    end

    -- Tactical Note
    if activeStep.note and activeStep.note ~= "" then
        frame.activeNote:SetText(string.format("|cffe6cc80Note:|r %s", activeStep.note))
        frame.activeNote:Show()
        contentH = contentH + 16
    else
        frame.activeNote:Hide()
    end

    frame.activeContainer:SetHeight(contentH + 20)

    -- Upcoming Steps
    local upcoming = self:GetUpcomingLevelingSteps(faction, 2)
    if #upcoming > 0 then
        frame.upcomingContainer:Show()
        frame.upcomingContainer:ClearAllPoints()
        frame.upcomingContainer:SetPoint("TOPLEFT", frame.activeContainer, "BOTTOMLEFT", 0, -4)
        frame.upcomingContainer:SetPoint("TOPRIGHT", frame.activeContainer, "BOTTOMRIGHT", 0, -4)

        -- Upcoming 1
        local u1 = upcoming[1]
        local u1Loc = (u1.location and u1.location ~= "" and u1.location:match("^([^,(/]+)")) or (u1.dungeonName and u1.dungeonName ~= "" and u1.dungeonName) or ""
        u1Loc = u1Loc:match("^%s*(.-)%s*$")
        frame.upcomingBtn1.text:SetText(string.format("|cff38bdf8[%s]|r |cffd1d5db#%d %s|r |cff6b7280(%s)|r", u1.levelBadge, u1.stepNumber, u1.title, u1Loc))
        frame.upcomingBtn1:Show()

        if #upcoming >= 2 then
            local u2 = upcoming[2]
            local u2Loc = (u2.location and u2.location ~= "" and u2.location:match("^([^,(/]+)")) or (u2.dungeonName and u2.dungeonName ~= "" and u2.dungeonName) or ""
            u2Loc = u2Loc:match("^%s*(.-)%s*$")
            frame.upcomingBtn2.text:SetText(string.format("|cff38bdf8[%s]|r |cffd1d5db#%d %s|r |cff6b7280(%s)|r", u2.levelBadge, u2.stepNumber, u2.title, u2Loc))
            frame.upcomingBtn2:Show()
            frame.upcomingContainer:SetHeight(48)
            frame:SetHeight(contentH + 20 + 54 + 32)
        else
            frame.upcomingBtn2:Hide()
            frame.upcomingContainer:SetHeight(32)
            frame:SetHeight(contentH + 20 + 38 + 32)
        end
    else
        frame.upcomingContainer:Hide()
        frame:SetHeight(contentH + 20 + 34)
    end
end

function WoWEternityAddon:ToggleTrackerHUD()
    if not self.trackerFrame then
        self:CreateTrackerHUD()
    end
    if not self.trackerFrame then return end

    WoWEternityAddonDB = WoWEternityAddonDB or {}
    WoWEternityAddonDB.tracker = WoWEternityAddonDB.tracker or {}

    if self.trackerFrame:IsShown() then
        self.trackerFrame:Hide()
        WoWEternityAddonDB.tracker.shown = false
        self:Print("|cffe6cc80[WoW Eternity Addon]|r Quest Tracker HUD hidden.")
    else
        self.trackerFrame:Show()
        WoWEternityAddonDB.tracker.shown = true
        self:UpdateTrackerHUD()
        self:Print("|cffe6cc80[WoW Eternity Addon]|r Quest Tracker HUD shown.")
    end

    if self.levelingTab and self.levelingTab.trackerBtn then
        self.levelingTab.trackerBtn:SetText(self.trackerFrame:IsShown() and "Tracker: |cff00ff00ON|r" or "Tracker: |cffff2020OFF|r")
    end
end

function WoWEternityAddon:CreateMainFrame()
    if not CreateFrame then return end
    if self.mainFrame then return end

    local frame = CreateFrame("Frame", "WoWEternityAddonMainFrame", UIParent, GetBackdropTemplate())
    self.mainFrame = frame

    frame:SetSize(640, 520)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)

    ApplyBackdrop(frame, 0.05, 0.06, 0.10, 0.96, 0.23, 0.27, 0.38, 1)

    -- Header Title Bar
    local titleBar = CreateFrame("Frame", nil, frame, GetBackdropTemplate())
    titleBar:SetHeight(38)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    ApplyBackdrop(titleBar, 0.08, 0.10, 0.16, 1, 0.14, 0.17, 0.24, 1)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", 14, 0)
    titleText:SetText("|cffe6cc80WoW Eternity Addon|r |cff9ca3af(/wea)|r  |cff60a5fav" .. self.version .. "|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -4, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Tab Buttons Strip (Anchored directly below title bar)
    self.tabButtons = {}
    self.tabFrames = {}
    self.currentTab = "Char"

    local tabArea = CreateFrame("Frame", nil, frame)
    tabArea:SetHeight(28)
    tabArea:SetPoint("TOPLEFT", 12, -40)
    tabArea:SetPoint("TOPRIGHT", -12, -40)

    for i, t in ipairs(TABS) do
        local btn = CreateFrame("Button", nil, tabArea, GetBackdropTemplate())
        btn:SetSize(98, 26)
        btn:SetPoint("LEFT", (i - 1) * 103, 0)
        ApplyBackdrop(btn, 0.06, 0.08, 0.12, 0.85, 0.18, 0.22, 0.32, 0.8)

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetPoint("CENTER")
        btnText:SetText(t.label)
        btn.text = btnText

        local tabId = t.id
        btn:SetScript("OnClick", function()
            WoWEternityAddon:SelectTab(tabId)
        end)

        self.tabButtons[t.id] = btn
    end

    -- Content Area for Tab Views
    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", 12, -70)
    contentArea:SetPoint("BOTTOMRIGHT", -12, 12)
    self.contentArea = contentArea

    -- Create all 6 Tab Frames inside contentArea
    self:CreateAccountTab(contentArea)
    self:CreateCharTab(contentArea)
    self:CreateGearPlannerTab(contentArea)
    self:CreateBisListsTab(contentArea)
    self:CreateLevelingTab(contentArea)
    self:CreateSettingsTab(contentArea)

    -- Default select Char tab
    self:SelectTab("Char")

    tinsert(UISpecialFrames, "WoWEternityAddonMainFrame")
end

function WoWEternityAddon:UpdateMainFrameView(tabId)
    local target = tabId or self.currentTab or "Char"
    if target == "Account" then
        self:UpdateAccountTab()
    elseif target == "Char" then
        self:UpdateCharTab()
    elseif target == "Gear Planner" then
        self:UpdateGearPlannerTab()
    elseif target == "BIS-Lists" then
        self:UpdateBisListsTab()
    elseif target == "Leveling" then
        self:UpdateLevelingTab()
    elseif target == "Settings" then
        self:UpdateSettingsTab()
    end
end

-- ============================================================================
-- Tooltip Processing & Hook Engine (Classic 1.15+ Forever & Legacy)
-- ============================================================================

function WoWEternityAddon:ProcessItemTooltip(tooltip, itemId)
    if not tooltip or not itemId or itemId <= 0 then return end
    if not WoWEternityAddonDB or not WoWEternityAddonDB.items then return end

    local itemData = WoWEternityAddonDB.items[itemId]
    if not itemData then return end

    local activeSpec = WoWEternityAddonDB.active_spec
    if activeSpec and activeSpec ~= "" and activeSpec ~= "all" then
        if itemData.spec_id and itemData.spec_id ~= "" and itemData.spec_id ~= activeSpec then
            return
        end
    end

    local tag
    if itemData.is_custom or itemData.source_type == "Custom Profile" then
        tag = "|cFF00FF00[BiS Item: Custom Profile]|r"
    else
        tag = "|cFFFFD700[BiS Item: Default]|r"
    end

    local details = ""
    if itemData.slot and itemData.slot ~= "" then
        details = "Slot: " .. itemData.slot
    end
    if itemData.rank and itemData.rank > 0 then
        if details ~= "" then details = details .. ", " end
        details = details .. "Rank: " .. itemData.rank
    end

    if details ~= "" and tooltip.AddDoubleLine then
        tooltip:AddDoubleLine(tag, "|cffffffff" .. details .. "|r", 1, 1, 1, 0.8, 0.8, 0.8)
    elseif tooltip.AddLine then
        tooltip:AddLine(tag, 1, 1, 1)
    end

    WoWEternityAddon:PlayBiSSound()
end

-- ============================================================================
-- Player Unit Tooltip Processing (Progress & Parse Overlay)
-- ============================================================================

-- ============================================================================
-- Item Level Calculation & Inspect Engine
-- ============================================================================

-- ============================================================================
-- Item Level Calculation & Inspect Engine
-- ============================================================================

local GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local function TooltipHasLine(tooltip, textSubstring)
    if not tooltip then return false, nil end
    local search = (textSubstring or ""):lower()
    if tooltip.NumLines and tooltip.GetName then
        local name = tooltip:GetName()
        if name then
            local num = tooltip:NumLines() or 0
            for i = 1, num do
                local line = _G[name .. "TextLeft" .. i]
                if line and line.GetText then
                    local txt = line:GetText()
                    if txt and string.find(txt:lower(), search, 1, true) then
                        return true, line
                    end
                end
            end
        end
    end
    return false, nil
end

function WoWEternityAddon:CalculateUnitItemLevel(unit)
    if not unit then return nil end

    -- 1. Check modern Blizzard inspect item level API if available
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local ok, blizzIlvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if ok and type(blizzIlvl) == "number" and blizzIlvl > 0 then
            return math.floor(blizzIlvl * 10 + 0.5) / 10
        end
    end

    -- 2. For player unit, GetAverageItemLevel may be available
    local isSelf = false
    if UnitIsUnit then
        local ok, selfMatch = pcall(UnitIsUnit, unit, "player")
        if ok and selfMatch then isSelf = true end
    end
    if isSelf and GetAverageItemLevel then
        local ok, _, avgEquipped = pcall(GetAverageItemLevel)
        if ok and type(avgEquipped) == "number" and avgEquipped > 0 then
            return math.floor(avgEquipped * 10 + 0.5) / 10
        end
    end

    -- 3. Scan equipped gear slots directly with safe pcalls
    local totalIlvl = 0
    local count = 0
    local is2H = false

    for _, slotId in ipairs(GEAR_SLOTS) do
        local link = nil
        local itemId = nil
        if GetInventoryItemLink then
            pcall(function() link = GetInventoryItemLink(unit, slotId) end)
        end
        if GetInventoryItemID then
            pcall(function() itemId = GetInventoryItemID(unit, slotId) end)
        end

        if link or itemId then
            local ilvl = nil
            local equipLoc = nil
            if link then
                pcall(function()
                    local _, _, _, iLevel, _, _, _, _, eqLoc = GetItemInfo(link)
                    if iLevel and iLevel > 0 then
                        ilvl = iLevel
                        equipLoc = eqLoc
                    end
                end)
            end
            if not ilvl and (itemId or link) and C_Item and C_Item.GetItemInfo then
                pcall(function()
                    local _, _, _, iLevel, _, _, _, _, eqLoc = C_Item.GetItemInfo(link or itemId)
                    if iLevel and iLevel > 0 then
                        ilvl = iLevel
                        equipLoc = eqLoc
                    end
                end)
            end
            if not ilvl and self.GetItemInfoSafe then
                pcall(function()
                    local _, _, iLevel, _, _, eqLoc = self:GetItemInfoSafe(link or itemId, slotId)
                    if iLevel and iLevel > 0 then
                        ilvl = iLevel
                        equipLoc = eqLoc
                    end
                end)
            end

            if ilvl and ilvl > 0 then
                totalIlvl = totalIlvl + ilvl
                count = count + 1
                if slotId == 16 and (equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT") then
                    is2H = true
                end
            end
        end
    end

    -- If 2H weapon equipped and no off-hand, balance off-hand slot
    if is2H and count > 0 then
        local offHandLink = nil
        local offHandId = 0
        pcall(function()
            if GetInventoryItemLink then offHandLink = GetInventoryItemLink(unit, 17) end
            if GetInventoryItemID then offHandId = GetInventoryItemID(unit, 17) or 0 end
        end)
        if not offHandLink and (not offHandId or offHandId == 0) then
            local mhLink = nil
            local mhId = 0
            pcall(function()
                if GetInventoryItemLink then mhLink = GetInventoryItemLink(unit, 16) end
                if GetInventoryItemID then mhId = GetInventoryItemID(unit, 16) or 0 end
            end)
            if mhLink or (mhId and mhId > 0) then
                local mhIlvl = nil
                if mhLink then
                    pcall(function()
                        local _, _, _, iLevel = GetItemInfo(mhLink)
                        if iLevel and iLevel > 0 then mhIlvl = iLevel end
                    end)
                end
                if not mhIlvl and self.GetItemInfoSafe then
                    pcall(function()
                        local _, _, iLevel = self:GetItemInfoSafe(mhLink or mhId, 16)
                        if iLevel and iLevel > 0 then mhIlvl = iLevel end
                    end)
                end
                if mhIlvl and mhIlvl > 0 then
                    totalIlvl = totalIlvl + mhIlvl
                    count = count + 1
                end
            end
        end
    end

    if count > 0 then
        return math.floor((totalIlvl / count) * 10 + 0.5) / 10
    end

    return nil
end

-- ============================================================================
-- Cross-Session Caching, Addon Communications & Proximity Scanning
-- ============================================================================

local ADDON_COMM_PREFIX = "WoWEternity"

function WoWEternityAddon:CacheUnitIlvl(key, ilvlStr)
    if not key or not ilvlStr then return end
    self.unitIlvlCache = self.unitIlvlCache or {}
    self.unitIlvlCache[key] = ilvlStr
    if WoWEternityAddonDB then
        WoWEternityAddonDB.unitIlvlCache = WoWEternityAddonDB.unitIlvlCache or {}
        WoWEternityAddonDB.unitIlvlCache[key] = ilvlStr
    end
    if type(key) == "string" and not key:find("-") then
        self.unitIlvlCache[key:lower()] = ilvlStr
        if WoWEternityAddonDB and WoWEternityAddonDB.unitIlvlCache then
            WoWEternityAddonDB.unitIlvlCache[key:lower()] = ilvlStr
        end
    end
end

function WoWEternityAddon:InitAddonComms()
    pcall(function()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(ADDON_COMM_PREFIX)
        elseif RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(ADDON_COMM_PREFIX)
        end
    end)
end

function WoWEternityAddon:BroadcastMyIlvl()
    local myIlvl = self:CalculateUnitItemLevel("player")
    if not myIlvl and WoWEternityAddonDB and WoWEternityAddonDB.character_export and WoWEternityAddonDB.character_export.avg_ilvl then
        myIlvl = WoWEternityAddonDB.character_export.avg_ilvl
    end
    if not myIlvl or myIlvl <= 0 then return end

    local myGuid = (UnitGUID and UnitGUID("player")) or "player"
    local msg = string.format("ILVL:%s:%.1f", myGuid, myIlvl)

    local sendMsg = function(prefix, text, channel, target)
        pcall(function()
            if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                C_ChatInfo.SendAddonMessage(prefix, text, channel, target)
            elseif SendAddonMessage then
                SendAddonMessage(prefix, text, channel, target)
            end
        end)
    end

    if IsInRaid and IsInRaid() then
        sendMsg(ADDON_COMM_PREFIX, msg, "RAID")
    elseif IsInGroup and IsInGroup() then
        sendMsg(ADDON_COMM_PREFIX, msg, "PARTY")
    end

    if IsInGuild and IsInGuild() then
        sendMsg(ADDON_COMM_PREFIX, msg, "GUILD")
    end
end

function WoWEternityAddon:RequestPlayerIlvl(targetName)
    if not targetName or targetName == "" then return end
    local now = (GetTime and GetTime()) or 0
    self.lastCommsRequests = self.lastCommsRequests or {}
    local lastReq = self.lastCommsRequests[targetName] or 0
    if now - lastReq < 3.0 then return end
    self.lastCommsRequests[targetName] = now

    local msg = "REQ_ILVL:" .. targetName
    local sendMsg = function(prefix, text, channel, target)
        pcall(function()
            if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                C_ChatInfo.SendAddonMessage(prefix, text, channel, target)
            elseif SendAddonMessage then
                SendAddonMessage(prefix, text, channel, target)
            end
        end)
    end

    if IsInRaid and IsInRaid() then
        sendMsg(ADDON_COMM_PREFIX, msg, "RAID")
    elseif IsInGroup and IsInGroup() then
        sendMsg(ADDON_COMM_PREFIX, msg, "PARTY")
    end

    if IsInGuild and IsInGuild() then
        sendMsg(ADDON_COMM_PREFIX, msg, "GUILD")
    end
end

function WoWEternityAddon:OnAddonMessage(prefix, text, channel, sender)
    if prefix ~= ADDON_COMM_PREFIX or not text then return end

    if text:sub(1, 5) == "ILVL:" then
        local guid, ilvlStr = text:match("^ILVL:([^:]+):([%d%.]+)$")
        if guid and ilvlStr then
            self:CacheUnitIlvl(guid, ilvlStr)
            if sender and sender ~= "" then
                local cleanSender = sender:match("^([^-]+)") or sender
                self:CacheUnitIlvl(cleanSender, ilvlStr)
            end
            if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
                local hasIlvl, ilvlLine = TooltipHasLine(GameTooltip, "iLvl:")
                if not hasIlvl then hasIlvl, ilvlLine = TooltipHasLine(GameTooltip, "ILVL:") end
                if hasIlvl and ilvlLine and ilvlLine.SetText then
                    ilvlLine:SetText(string.format("|cffe6cc80iLvl:|r |cffffffff%s|r", ilvlStr))
                    pcall(function() GameTooltip:Show() end)
                end
            end
        end
    elseif text:sub(1, 9) == "REQ_ILVL:" then
        local target = text:sub(10)
        local myName = (UnitName and UnitName("player")) or ""
        if target and (target == myName or target:lower() == myName:lower()) then
            local myIlvl = self:CalculateUnitItemLevel("player")
            if not myIlvl and WoWEternityAddonDB and WoWEternityAddonDB.character_export and WoWEternityAddonDB.character_export.avg_ilvl then
                myIlvl = WoWEternityAddonDB.character_export.avg_ilvl
            end
            if myIlvl and myIlvl > 0 then
                local myGuid = (UnitGUID and UnitGUID("player")) or "player"
                local reply = string.format("ILVL:%s:%.1f", myGuid, myIlvl)
                pcall(function()
                    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                        C_ChatInfo.SendAddonMessage(ADDON_COMM_PREFIX, reply, channel)
                    elseif SendAddonMessage then
                        SendAddonMessage(ADDON_COMM_PREFIX, reply, channel)
                    end
                end)
            end
        end
    end
end

local function IsInspectFrameShown()
    local shown = false
    pcall(function()
        if InspectFrame then
            if InspectFrame.IsVisible and InspectFrame:IsVisible() then
                shown = true
            elseif InspectFrame.unit ~= nil then
                shown = true
            end
        end
    end)
    return shown
end

function WoWEternityAddon:StartProximityScanner()
    if self.proximityScannerRunning then return end
    self.proximityScannerRunning = true

    local unitsToCheck = {}
    for i = 1, 40 do table.insert(unitsToCheck, "raid" .. i) end
    for i = 1, 4 do table.insert(unitsToCheck, "party" .. i) end
    table.insert(unitsToCheck, "target")
    table.insert(unitsToCheck, "focus")

    local currentIndex = 1

    local function ScanTick()
        if not self.proximityScannerRunning then return end

        -- Never inspect in background if the player is actively using Blizzard's Inspect UI or hovering over a unit!
        local isHovering = (GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() and UnitExists and UnitExists("mouseover"))
        if IsInspectFrameShown() or isHovering or (self.pendingInspectUnit == "mouseover") then
            if C_Timer and C_Timer.After then
                C_Timer.After(2.0, ScanTick)
            end
            return
        end

        if not (InCombatLockdown and InCombatLockdown()) then
            local checked = 0
            while checked < #unitsToCheck do
                local unit = unitsToCheck[currentIndex]
                currentIndex = currentIndex + 1
                if currentIndex > #unitsToCheck then currentIndex = 1 end
                checked = checked + 1

                if UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit) and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
                    local guid = (UnitGUID and UnitGUID(unit))
                    local name = (UnitName and UnitName(unit))
                    local isCached = false
                    if guid and self.unitIlvlCache and self.unitIlvlCache[guid] then
                        isCached = true
                    elseif name and self.unitIlvlCache and (self.unitIlvlCache[name] or self.unitIlvlCache[name:lower()]) then
                        isCached = true
                    elseif WoWEternityAddonDB and WoWEternityAddonDB.unitIlvlCache then
                        if guid and WoWEternityAddonDB.unitIlvlCache[guid] then
                            isCached = true
                        elseif name and (WoWEternityAddonDB.unitIlvlCache[name] or WoWEternityAddonDB.unitIlvlCache[name:lower()]) then
                            isCached = true
                        end
                    end

                    if not isCached then
                        local immediate = self:CalculateUnitItemLevel(unit)
                        if immediate and immediate > 0 then
                            local ilvlStr = string.format("%.1f", immediate)
                            if guid then self:CacheUnitIlvl(guid, ilvlStr) end
                            if name then self:CacheUnitIlvl(name, ilvlStr) end
                        else
                            -- Do NOT call NotifyInspect on background scan ticks!
                            -- Calling NotifyInspect in the background clogs the server inspect queue and blocks manual player inspection.
                            -- Instead, request iLvl from peer addon via hidden comms if name is known:
                            local now = (GetTime and GetTime()) or 0
                            if name and (not self.lastPeerReq or (now - self.lastPeerReq > 5.0)) then
                                self.lastPeerReq = now
                                self:RequestPlayerIlvl(name)
                            end
                        end
                    end
                end
            end
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(2.0, ScanTick)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(2.0, ScanTick)
    end
end

function WoWEternityAddon:GetUnitItemLevel(unit, guid, name)
    if not unit and not guid and not name then return "--" end

    -- For self ("player"), compute or fetch from export
    local isSelf = false
    if unit and UnitIsUnit then
        local ok, sMatch = pcall(UnitIsUnit, unit, "player")
        if ok and sMatch then isSelf = true end
    end
    if not isSelf and guid and UnitGUID then
        local ok, sMatch = pcall(function() return UnitGUID("player") == guid end)
        if ok and sMatch then isSelf = true end
    end
    if isSelf then
        local ilvl = self:CalculateUnitItemLevel("player")
        if not ilvl and WoWEternityAddonDB and WoWEternityAddonDB.character_export and WoWEternityAddonDB.character_export.avg_ilvl then
            ilvl = WoWEternityAddonDB.character_export.avg_ilvl
        end
        if ilvl and ilvl > 0 then
            return string.format("%.1f", ilvl)
        end
        return "--"
    end

    local unitGuid = guid
    if not unitGuid and unit and UnitGUID then
        pcall(function() unitGuid = UnitGUID(unit) end)
    end
    local unitName = name
    if not unitName and unit and UnitName then
        pcall(function() unitName = UnitName(unit) end)
    end
    if not unitGuid then unitGuid = unitName or "unknown" end

    -- 1. Check in-memory cache by GUID or by unit name
    if self.unitIlvlCache then
        if unitGuid and self.unitIlvlCache[unitGuid] then
            return self.unitIlvlCache[unitGuid]
        end
        if unitName then
            if self.unitIlvlCache[unitName] then return self.unitIlvlCache[unitName] end
            if self.unitIlvlCache[unitName:lower()] then return self.unitIlvlCache[unitName:lower()] end
        end
    end

    -- 2. Check persistent SavedVariables cache (survives reloads and game restarts)
    if WoWEternityAddonDB and WoWEternityAddonDB.unitIlvlCache then
        if unitGuid and WoWEternityAddonDB.unitIlvlCache[unitGuid] then
            local cached = WoWEternityAddonDB.unitIlvlCache[unitGuid]
            self.unitIlvlCache = self.unitIlvlCache or {}
            self.unitIlvlCache[unitGuid] = cached
            return cached
        end
        if unitName then
            local cached = WoWEternityAddonDB.unitIlvlCache[unitName] or WoWEternityAddonDB.unitIlvlCache[unitName:lower()]
            if cached then
                self.unitIlvlCache = self.unitIlvlCache or {}
                self.unitIlvlCache[unitName] = cached
                return cached
            end
        end
    end

    -- 3. Check synced roster data from desktop app in WoWEternityAddonDB.players
    if unitName and WoWEternityAddonDB and WoWEternityAddonDB.players then
        local uLower = unitName:lower()
        for _, p in ipairs(WoWEternityAddonDB.players) do
            if p.name and p.name:lower() == uLower and p.avg_ilvl and p.avg_ilvl > 0 then
                local formatted = string.format("%.1f", p.avg_ilvl)
                self:CacheUnitIlvl(unitGuid, formatted)
                self:CacheUnitIlvl(unitName, formatted)
                return formatted
            end
        end
    end

    -- 4. Attempt immediate calculation if unit gear is already in client memory
    if unit then
        local immediate = self:CalculateUnitItemLevel(unit)
        if immediate and immediate > 0 then
            local res = string.format("%.1f", immediate)
            self:CacheUnitIlvl(unitGuid, res)
            if unitName then self:CacheUnitIlvl(unitName, res) end
            return res
        end
    end

    -- 5. Range & Inspect check
    -- If Blizzard's Inspect window is open, only inspect if this unit is the inspected unit
    if IsInspectFrameShown() then
        local inspectUnit = (InspectFrame and InspectFrame.unit) or "target"
        if unit and (unit == inspectUnit or (UnitGUID and UnitGUID(unit) == UnitGUID(inspectUnit))) then
            local immediate = self:CalculateUnitItemLevel(inspectUnit)
            if immediate and immediate > 0 then
                local res = string.format("%.1f", immediate)
                self:CacheUnitIlvl(unitGuid, res)
                if unitName then self:CacheUnitIlvl(unitName, res) end
                return res
            end
        end
        return "..."
    end

    local inRange = false
    local canInspect = false
    pcall(function()
        if unit and CanInspect and CanInspect(unit) then
            if CheckInteractDistance and CheckInteractDistance(unit, 1) then
                inRange = true
                if not InCombatLockdown or not InCombatLockdown() then
                    canInspect = true
                end
            end
        end
    end)

    if inRange and canInspect then
        local now = (GetTime and GetTime()) or 0
        local lastInspect = self.lastInspectTime or 0
        if (now - lastInspect > 2.5) then
            self.lastInspectTime = now
            self.pendingInspectGuid = unitGuid
            self.pendingInspectUnit = unit
            pcall(NotifyInspect, unit)
        end
    elseif not inRange and unitName then
        -- Out of 28yd inspect range: request iLvl from peer addon via comms
        self:RequestPlayerIlvl(unitName)
    end

    return "..."
end

function WoWEternityAddon:OnInspectReady(guid)
    local targetGuid = guid or self.pendingInspectGuid
    if not targetGuid and UnitGUID then
        targetGuid = UnitGUID("mouseover") or UnitGUID("target")
    end

    local function TryUpdateLive(retryCount)
        local unit = nil
        if UnitGUID and targetGuid then
            if UnitGUID("mouseover") == targetGuid then
                unit = "mouseover"
            elseif UnitGUID("target") == targetGuid then
                unit = "target"
            elseif self.pendingInspectUnit and UnitGUID(self.pendingInspectUnit) == targetGuid then
                unit = self.pendingInspectUnit
            end
        end
        if not unit then
            if UnitExists and UnitExists("mouseover") then
                unit = "mouseover"
            elseif UnitExists and UnitExists("target") then
                unit = "target"
            elseif self.pendingInspectUnit and UnitExists and UnitExists(self.pendingInspectUnit) then
                unit = self.pendingInspectUnit
            elseif InspectFrame and InspectFrame.unit and UnitExists and UnitExists(InspectFrame.unit) then
                unit = InspectFrame.unit
            end
        end

        local ilvl = nil
        if unit then
            ilvl = self:CalculateUnitItemLevel(unit)
        end
        if not ilvl and UnitExists and UnitGUID then
            pcall(function()
                if UnitExists("target") then
                    ilvl = self:CalculateUnitItemLevel("target")
                elseif UnitExists("mouseover") then
                    ilvl = self:CalculateUnitItemLevel("mouseover")
                end
            end)
        end

        if ilvl and ilvl > 0 then
            local ilvlStr = string.format("%.1f", ilvl)
            if targetGuid then self:CacheUnitIlvl(targetGuid, ilvlStr) end
            if unit and UnitName and UnitName(unit) then
                local uName = UnitName(unit)
                self:CacheUnitIlvl(uName, ilvlStr)
            end

            -- Live dynamic tooltip update
            local candidateTooltips = { self.activeUnitTooltip, GameTooltip }
            for _, tt in ipairs(candidateTooltips) do
                if tt and tt.IsShown and tt:IsShown() then
                    local hasIlvl, ilvlLine = TooltipHasLine(tt, "iLvl")
                    if hasIlvl and ilvlLine and ilvlLine.SetText then
                        ilvlLine:SetText(string.format("|cffe6cc80iLvl:|r |cffffffff%s|r", ilvlStr))
                        pcall(function() tt:Show() end)
                    end
                end
            end

            if IsInspectFrameShown() and self.UpdateInspectIlvlBadge then
                pcall(function() self:UpdateInspectIlvlBadge() end)
            end
            return true
        end

        -- If items were pending server retrieval, retry shortly
        if (retryCount or 0) < 3 and C_Timer and C_Timer.After then
            local nextDelay = (retryCount == 0 and 0.15) or (retryCount == 1 and 0.3) or 0.5
            C_Timer.After(nextDelay, function()
                TryUpdateLive((retryCount or 0) + 1)
            end)
        end
        return false
    end

    TryUpdateLive(0)

    -- NOTE: DO NOT call ClearInspectPlayer() here!
    -- Calling ClearInspectPlayer() wipes Blizzard's InspectPaperDollFrame gear slots clean!
    -- Blizzard's native InspectFrame manages its own inspect target cleanup on close.
    self.pendingInspectGuid = nil
    self.pendingInspectUnit = nil

    if IsInspectFrameShown() then
        if not self.inspectFrameHooked and self.HookInspectFrame then
            pcall(function() self:HookInspectFrame() end)
        end
        if self.UpdateInspectIlvlBadge then
            pcall(function() self:UpdateInspectIlvlBadge() end)
        end
    end
end

-- ============================================================================
-- Player Unit Tooltip Processing (Progress & Parse Overlay)
-- ============================================================================

function WoWEternityAddon:ProcessUnitTooltip(tooltip, data)
    if not tooltip then return end
    if WoWEternityAddonDB and WoWEternityAddonDB.showPlayerTooltips == false then return end

    -- Safe Unit & GUID Resolution
    local name, unit, guid = nil, nil, nil
    if data and data.guid then
        guid = data.guid
    end
    if TooltipUtil and TooltipUtil.GetDisplayedUnit then
        pcall(function()
            name, unit, guid = TooltipUtil.GetDisplayedUnit(tooltip)
        end)
    end
    if not unit and tooltip.GetUnit then
        pcall(function()
            name, unit = tooltip:GetUnit()
        end)
    end
    if not guid and unit and UnitGUID then
        pcall(function() guid = UnitGUID(unit) end)
    end
    if not guid and data and data.guid then
        guid = data.guid
    end

    if not unit then
        if guid and UnitGUID then
            pcall(function()
                if UnitGUID("mouseover") == guid then
                    unit = "mouseover"
                elseif UnitGUID("target") == guid then
                    unit = "target"
                elseif UnitGUID("player") == guid then
                    unit = "player"
                end
            end)
        end
        if not unit and UnitExists then
            pcall(function()
                if UnitExists("mouseover") then
                    unit = "mouseover"
                elseif UnitExists("target") then
                    unit = "target"
                end
            end)
        end
    end

    -- Validate player unit: must be player guid or player unit
    local isPlayer = false
    if guid and type(guid) == "string" and guid:find("^Player%-") then
        isPlayer = true
    elseif unit and UnitIsPlayer then
        pcall(function()
            if UnitIsPlayer(unit) then isPlayer = true end
        end)
    end
    if not isPlayer then return end

    local unitGuid = guid
    if not unitGuid and unit and UnitGUID then
        pcall(function() unitGuid = UnitGUID(unit) end)
    end
    local playerName = (unit and UnitName and UnitName(unit)) or name
    if not playerName and guid and GetPlayerInfoByGUID then
        pcall(function()
            local _, _, _, _, _, pName = GetPlayerInfoByGUID(guid)
            if pName and pName ~= "" then playerName = pName end
        end)
    end
    if not unitGuid then
        unitGuid = playerName or "unknown"
    end

    self.activeUnitTooltip = tooltip

    -- If the tooltip already has the iLvl line, update in-place if pending resolves, and avoid duplicate
    local hasIlvl, ilvlLine = TooltipHasLine(tooltip, "iLvl")
    if hasIlvl then
        if ilvlLine and ilvlLine.GetText and ilvlLine:GetText():find("%.%.%.") then
            local cached = nil
            if self.unitIlvlCache then
                cached = (unitGuid and self.unitIlvlCache[unitGuid]) or (playerName and (self.unitIlvlCache[playerName] or self.unitIlvlCache[playerName:lower()]))
            end
            if not cached and WoWEternityAddonDB and WoWEternityAddonDB.unitIlvlCache then
                cached = (unitGuid and WoWEternityAddonDB.unitIlvlCache[unitGuid]) or (playerName and (WoWEternityAddonDB.unitIlvlCache[playerName] or WoWEternityAddonDB.unitIlvlCache[playerName:lower()]))
            end
            if not cached and unit then
                local liveIlvl = self:CalculateUnitItemLevel(unit)
                if liveIlvl and liveIlvl > 0 then
                    cached = string.format("%.1f", liveIlvl)
                    if unitGuid then self:CacheUnitIlvl(unitGuid, cached) end
                    if playerName then self:CacheUnitIlvl(playerName, cached) end
                end
            end
            if cached then
                ilvlLine:SetText(string.format("|cffe6cc80iLvl:|r |cffffffff%s|r", cached))
                pcall(function() tooltip:Show() end)
            end
        end
        return
    end

    local progressText = "|cffffffffRelease Nov. 4th|r"
    local parseText = "|cffffffffRelease Nov. 4th|r"

    -- Lookup synced player data from WoWEternityAddonDB.players if present
    if WoWEternityAddonDB and WoWEternityAddonDB.players and playerName then
        local pNameLower = playerName:lower()
        for _, p in ipairs(WoWEternityAddonDB.players) do
            if p.name and p.name:lower() == pNameLower then
                local isVerified, reason = self:VerifyPlayerSignature(p)
                if isVerified then
                    if p.raid_progress and p.raid_progress ~= "" and not p.raid_progress:find("Char: BD 4/4") and not p.raid_progress:find("BD 4/4") and p.raid_progress ~= "0/10" then
                        progressText = string.format("|cffffffff%s|r", p.raid_progress)
                    end
                    if p.parse_ranking and p.parse_ranking > 0 and p.parse_ranking ~= 26 then
                        local col = "ff8000" -- legendary orange default
                        if p.parse_ranking >= 100 then col = "e5cc80"
                        elseif p.parse_ranking >= 99 then col = "e268a8"
                        elseif p.parse_ranking >= 95 then col = "ff8000"
                        elseif p.parse_ranking >= 75 then col = "a335ee"
                        elseif p.parse_ranking >= 50 then col = "0070dd"
                        elseif p.parse_ranking >= 25 then col = "1eff00"
                        else col = "9ca3af" end
                        parseText = string.format("|cff%s%.0f|r, |cff%s%.0f%%|r", col, p.parse_ranking, col, p.parse_percentile or 96)
                    end
                    parseText = parseText .. " |cff00ff00[✔]|r"
                elseif reason == "tampered" then
                    parseText = "|cffff2020[Tampered Data]|r"
                    progressText = "|cffff2020[Tampered Data]|r"
                else
                    if p.raid_progress and p.raid_progress ~= "" and not p.raid_progress:find("Char: BD 4/4") and not p.raid_progress:find("BD 4/4") and p.raid_progress ~= "0/10" then
                        progressText = string.format("|cffffffff%s|r", p.raid_progress)
                    end
                    if p.parse_ranking and p.parse_ranking > 0 and p.parse_ranking ~= 26 then
                        local col = "ff8000"
                        if p.parse_ranking >= 100 then col = "e5cc80"
                        elseif p.parse_ranking >= 99 then col = "e268a8"
                        elseif p.parse_ranking >= 95 then col = "ff8000"
                        elseif p.parse_ranking >= 75 then col = "a335ee"
                        elseif p.parse_ranking >= 50 then col = "0070dd"
                        elseif p.parse_ranking >= 25 then col = "1eff00"
                        else col = "9ca3af" end
                        parseText = string.format("|cff%s%.0f|r, |cff%s%.0f%%|r", col, p.parse_ranking, col, p.parse_percentile or 96)
                    end
                end
                break
            end
        end
    end

    -- Pull unit item level dynamically
    local ilvlStr = self:GetUnitItemLevel(unit or "target", unitGuid, playerName)

    if tooltip.AddLine then
        tooltip:AddLine(" ")
        tooltip:AddLine(string.format("|cffe6cc80iLvl:|r |cffffffff%s|r", ilvlStr), 1, 1, 1)
        tooltip:AddLine(string.format("|cffe6cc80Parse:|r %s", parseText), 1, 1, 1)
        tooltip:AddLine(string.format("|cffe6cc80Progress:|r %s", progressText), 1, 1, 1)
        pcall(function() tooltip:Show() end)
    end
end

-- ============================================================================
-- Character Frame iLvl Display Hook & PaperDoll Badge (Bottom Right)
-- ============================================================================

function WoWEternityAddon:GetOrCreatePaperDollIlvlBadge()
    if self.paperDollIlvlBadge then
        return self.paperDollIlvlBadge
    end

    local parent = PaperDollFrame or CharacterFrame
    if not parent or not CreateFrame then return nil end

    local badge = CreateFrame("Button", "WoWEternity_PaperDollIlvlBadge", parent)
    badge:SetSize(44, 32)
    badge:SetFrameStrata("HIGH")

    -- Subtle dark backdrop for contrast against 3D model
    local bg = badge:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(badge)
    bg:SetColorTexture(0.04, 0.04, 0.07, 0.72)
    badge.bg = bg

    -- Clean gold border accent
    local border = badge:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.9, 0.8, 0.5, 0.28)
    badge.border = border

    local text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetAllPoints(badge)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    badge.text = text

    local function PositionBadge()
        badge:ClearAllPoints()
        if CharacterRangedSlot and CharacterRangedSlot:IsShown() then
            badge:SetPoint("LEFT", CharacterRangedSlot, "RIGHT", 4, 0)
        elseif CharacterTrinket1Slot and CharacterTrinket1Slot:IsShown() then
            badge:SetPoint("TOPLEFT", CharacterTrinket1Slot, "BOTTOMLEFT", 0, -6)
        elseif CharacterSecondaryHandSlot and CharacterSecondaryHandSlot:IsShown() then
            badge:SetPoint("LEFT", CharacterSecondaryHandSlot, "RIGHT", 42, 0)
        elseif CharacterFrameInset then
            badge:SetPoint("BOTTOMRIGHT", CharacterFrameInset, "BOTTOMRIGHT", -12, 12)
        else
            badge:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 215, 75)
        end
    end
    badge.PositionBadge = PositionBadge
    PositionBadge()

    badge:EnableMouse(true)
    badge:SetScript("OnEnter", function(btn)
        if GameTooltip then
            local exp = WoWEternityAddonDB and WoWEternityAddonDB.character_export
            local curIlvl = (exp and exp.avg_ilvl and exp.avg_ilvl > 0 and exp.avg_ilvl)
                or WoWEternityAddon:CalculateUnitItemLevel("player")
                or 0.0
            local equipped = exp and exp.equipped_count or 0

            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cffe6cc80WoW Eternity Addon|r", 1, 1, 1)
            GameTooltip:AddLine(string.format("Average Item Level: |cffffffff%.1f|r", curIlvl), 1, 1, 1)
            if equipped > 0 then
                GameTooltip:AddLine(string.format("Equipped Items: |cffffffff%d / 19|r", equipped), 0.8, 0.8, 0.8)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffe6cc80Phase 1:|r |cffffffffBarrow Deeps, Hyjal Summit, Onyxia's Lair|r", 1, 1, 1)
            GameTooltip:AddLine("|cffe6cc80Parse:|r |cffffffffRelease Nov. 4th|r", 1, 1, 1)
            GameTooltip:AddLine("|cffe6cc80Progress:|r |cffffffffRelease Nov. 4th|r", 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cff888888Click to open WoW Eternity Panel (/wea)|r", 0.5, 0.8, 1)
            GameTooltip:Show()
        end
    end)
    badge:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    badge:SetScript("OnClick", function()
        WoWEternityAddon:ToggleSettingsFrame("Char")
    end)

    self.paperDollIlvlBadge = badge
    return badge
end

function WoWEternityAddon:UpdatePaperDollIlvlBadge(avgIlvl)
    local badge = self:GetOrCreatePaperDollIlvlBadge()
    if not badge then return end

    if not avgIlvl or avgIlvl <= 0 then
        local exp = WoWEternityAddonDB and WoWEternityAddonDB.character_export
        avgIlvl = (exp and exp.avg_ilvl and exp.avg_ilvl > 0 and exp.avg_ilvl)
            or self:CalculateUnitItemLevel("player")
            or 0.0
    end

    if badge.PositionBadge then
        pcall(badge.PositionBadge)
    end

    if avgIlvl and avgIlvl > 0 then
        badge.text:SetText(string.format("|cffe6cc80iLvl|r\n|cffffffff%.1f|r", avgIlvl))
        badge:Show()
    else
        badge:Hide()
    end
end

local function UpdateCharacterFrameIlvl()
    pcall(function()
        local exp = WoWEternityAddonDB and WoWEternityAddonDB.character_export
        local avgIlvl = (exp and exp.avg_ilvl and exp.avg_ilvl > 0 and exp.avg_ilvl)
            or WoWEternityAddon:CalculateUnitItemLevel("player")
            or 0.0
        if not avgIlvl or avgIlvl <= 0 then return end

        local rawName = (UnitPVPName and UnitPVPName("player")) or (UnitName and UnitName("player")) or ""

        -- 1. Update Title / Name Text at top of CharacterFrame across modern 1.15 and legacy clients
        local titleTargets = {
            CharacterFrame and CharacterFrame.TitleText,
            CharacterFrameTitleText,
            CharacterNameText,
        }
        for _, textObj in ipairs(titleTargets) do
            if textObj and textObj.GetText and textObj.SetText then
                local currentText = textObj:GetText() or ""
                local cleanName = currentText:gsub("^|c%x+%[[%d%.]+%]|r%s*", ""):gsub("^%[[%d%.]+%]%s*", "")
                if cleanName == "" then cleanName = rawName end
                if cleanName ~= "" then
                    local formatted = string.format("|cffe6cc80[%.1f]|r %s", avgIlvl, cleanName)
                    if currentText ~= formatted then
                        textObj:SetText(formatted)
                    end
                end
            end
        end

        -- 2. Update dedicated bottom iLvl badge next to weapon slots (where user indicated)
        WoWEternityAddon:UpdatePaperDollIlvlBadge(avgIlvl)

        -- 3. Enable mouseover tooltip on character name/title area at top of character screen
        if not WoWEternityAddon.charTitleHoverBtn and CreateFrame then
            local p = CharacterFrame or PaperDollFrame
            if p then
                local hBtn = CreateFrame("Button", "WoWEternity_CharTitleHover", p)
                hBtn:SetSize(240, 26)
                local anchor = CharacterNameText or CharacterFrameTitleText or (CharacterFrame and CharacterFrame.TitleText)
                if anchor then
                    hBtn:SetPoint("CENTER", anchor, "CENTER", 0, 0)
                else
                    hBtn:SetPoint("TOP", p, "TOP", 0, -18)
                end
                hBtn:SetFrameStrata("HIGH")
                hBtn:EnableMouse(true)
                hBtn:SetScript("OnEnter", function(selfBtn)
                    local badge = WoWEternityAddon.paperDollIlvlBadge
                    if badge and badge:GetScript("OnEnter") then
                        badge:GetScript("OnEnter")(selfBtn)
                    end
                end)
                hBtn:SetScript("OnLeave", function()
                    if GameTooltip then GameTooltip:Hide() end
                end)
                hBtn:SetScript("OnClick", function()
                    WoWEternityAddon:ToggleSettingsFrame("Char")
                end)
                WoWEternityAddon.charTitleHoverBtn = hBtn
            end
        end
    end)
end

function WoWEternityAddon:UpdateCharacterFrameIlvl()
    UpdateCharacterFrameIlvl()
end

if CharacterFrame and CharacterFrame.HookScript then
    pcall(function()
        CharacterFrame:HookScript("OnShow", UpdateCharacterFrameIlvl)
    end)
end

if PaperDollFrame and PaperDollFrame.HookScript then
    pcall(function()
        PaperDollFrame:HookScript("OnShow", UpdateCharacterFrameIlvl)
    end)
end

if hooksecurefunc then
    pcall(function()
        if CharacterFrame and CharacterFrame.SetTitle then
            hooksecurefunc(CharacterFrame, "SetTitle", function()
                UpdateCharacterFrameIlvl()
            end)
        end
        if PaperDollFrame_SetLevel then
            hooksecurefunc("PaperDollFrame_SetLevel", UpdateCharacterFrameIlvl)
        end
        if PaperDollFrame_Update then
            hooksecurefunc("PaperDollFrame_Update", UpdateCharacterFrameIlvl)
        end
    end)
end

-- ============================================================================
-- Inspect Frame iLvl Display Hook & Badge (Bottom Right)
-- ============================================================================

function WoWEternityAddon:GetOrCreateInspectIlvlBadge()
    if self.inspectIlvlBadge then
        local currentParent = InspectPaperDollFrame or InspectFrame
        if currentParent and self.inspectIlvlBadge:GetParent() ~= currentParent then
            self.inspectIlvlBadge:SetParent(currentParent)
        end
        return self.inspectIlvlBadge
    end

    local parent = InspectPaperDollFrame or InspectFrame
    if not parent or not CreateFrame then return nil end

    local badge = CreateFrame("Button", "WoWEternity_InspectIlvlBadge", parent)
    badge:SetSize(44, 32)
    badge:SetFrameStrata("HIGH")

    -- Subtle dark backdrop for contrast against 3D model
    local bg = badge:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(badge)
    bg:SetColorTexture(0.04, 0.04, 0.07, 0.75)
    badge.bg = bg

    -- Clean gold border accent
    local border = badge:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.9, 0.8, 0.5, 0.35)
    badge.border = border

    local text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetAllPoints(badge)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    badge.text = text

    local function PositionBadge()
        badge:ClearAllPoints()
        if InspectRangedSlot and InspectRangedSlot:IsShown() then
            badge:SetPoint("LEFT", InspectRangedSlot, "RIGHT", 4, 0)
        elseif InspectTrinket2Slot and InspectTrinket2Slot:IsShown() then
            badge:SetPoint("RIGHT", InspectTrinket2Slot, "LEFT", -4, 0)
        elseif InspectSecondaryHandSlot and InspectSecondaryHandSlot:IsShown() then
            badge:SetPoint("LEFT", InspectSecondaryHandSlot, "RIGHT", 42, 0)
        elseif InspectFrameInset then
            badge:SetPoint("BOTTOMRIGHT", InspectFrameInset, "BOTTOMRIGHT", -12, 12)
        else
            badge:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 215, 75)
        end
    end
    badge.PositionBadge = PositionBadge
    PositionBadge()

    badge:EnableMouse(true)
    badge:SetScript("OnEnter", function(btn)
        if GameTooltip then
            local unit = (InspectFrame and InspectFrame.unit) or (InspectPaperDollFrame and InspectPaperDollFrame.unit) or "target"
            local name = (unit and UnitName and UnitName(unit)) or "Player"
            local avgIlvl = WoWEternityAddon:CalculateUnitItemLevel(unit)
            if not avgIlvl or avgIlvl <= 0 then
                local guid = (unit and UnitGUID and UnitGUID(unit))
                if guid and WoWEternityAddon.unitIlvlCache and WoWEternityAddon.unitIlvlCache[guid] then
                    avgIlvl = tonumber(WoWEternityAddon.unitIlvlCache[guid])
                elseif name and WoWEternityAddon.unitIlvlCache and (WoWEternityAddon.unitIlvlCache[name] or WoWEternityAddon.unitIlvlCache[name:lower()]) then
                    avgIlvl = tonumber(WoWEternityAddon.unitIlvlCache[name] or WoWEternityAddon.unitIlvlCache[name:lower()])
                end
            end

            local parseText = "|cffffffffRelease Nov. 4th|r"
            local progressText = "|cffffffffRelease Nov. 4th|r"
            if name and WoWEternityAddonDB and WoWEternityAddonDB.players then
                local nLower = name:lower()
                for _, p in ipairs(WoWEternityAddonDB.players) do
                    if p.name and p.name:lower() == nLower then
                        local isVerified, reason = WoWEternityAddon:VerifyPlayerSignature(p)
                        if isVerified then
                            if p.raid_progress and p.raid_progress ~= "" and not p.raid_progress:find("Char: BD 4/4") and not p.raid_progress:find("BD 4/4") and p.raid_progress ~= "0/10" then
                                progressText = string.format("|cffffffff%s|r", p.raid_progress)
                            end
                            if p.parse_ranking and p.parse_ranking > 0 and p.parse_ranking ~= 26 then
                                local col = "ff8000"
                                if p.parse_ranking >= 100 then col = "e5cc80"
                                elseif p.parse_ranking >= 99 then col = "e268a8"
                                elseif p.parse_ranking >= 95 then col = "ff8000"
                                elseif p.parse_ranking >= 75 then col = "a335ee"
                                elseif p.parse_ranking >= 50 then col = "0070dd"
                                elseif p.parse_ranking >= 25 then col = "1eff00"
                                else col = "9ca3af" end
                                parseText = string.format("|cff%s%.0f|r, |cff%s%.0f%%|r", col, p.parse_ranking, col, p.parse_percentile or 96)
                            end
                            parseText = parseText .. " |cff00ff00[✔]|r"
                        elseif reason == "tampered" then
                            parseText = "|cffff2020[Tampered Data]|r"
                            progressText = "|cffff2020[Tampered Data]|r"
                        else
                            if p.raid_progress and p.raid_progress ~= "" and not p.raid_progress:find("Char: BD 4/4") and not p.raid_progress:find("BD 4/4") and p.raid_progress ~= "0/10" then
                                progressText = string.format("|cffffffff%s|r", p.raid_progress)
                            end
                            if p.parse_ranking and p.parse_ranking > 0 and p.parse_ranking ~= 26 then
                                local col = "ff8000"
                                if p.parse_ranking >= 100 then col = "e5cc80"
                                elseif p.parse_ranking >= 99 then col = "e268a8"
                                elseif p.parse_ranking >= 95 then col = "ff8000"
                                elseif p.parse_ranking >= 75 then col = "a335ee"
                                elseif p.parse_ranking >= 50 then col = "0070dd"
                                elseif p.parse_ranking >= 25 then col = "1eff00"
                                else col = "9ca3af" end
                                parseText = string.format("|cff%s%.0f|r, |cff%s%.0f%%|r", col, p.parse_ranking, col, p.parse_percentile or 96)
                            end
                        end
                        break
                    end
                end
            end

            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cffe6cc80WoW Eternity Addon|r", 1, 1, 1)
            GameTooltip:AddLine(string.format("Target: |cffffffff%s|r", name), 1, 1, 1)
            if avgIlvl and avgIlvl > 0 then
                GameTooltip:AddLine(string.format("Average Item Level: |cffffffff%.1f|r", avgIlvl), 1, 1, 1)
            else
                GameTooltip:AddLine("Average Item Level: |cffffffffScanning...|r", 1, 1, 1)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffe6cc80Phase 1:|r |cffffffffBarrow Deeps, Hyjal Summit, Onyxia's Lair|r", 1, 1, 1)
            GameTooltip:AddLine(string.format("|cffe6cc80Parse:|r %s", parseText), 1, 1, 1)
            GameTooltip:AddLine(string.format("|cffe6cc80Progress:|r %s", progressText), 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cff888888Click to open WoW Eternity Panel (/wea)|r", 0.5, 0.8, 1)
            GameTooltip:Show()
        end
    end)
    badge:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    badge:SetScript("OnClick", function()
        WoWEternityAddon:ToggleSettingsFrame("Account")
    end)

    self.inspectIlvlBadge = badge
    return badge
end

function WoWEternityAddon:UpdateInspectIlvlBadge()
    pcall(function()
        if not IsInspectFrameShown() then
            if self.inspectIlvlBadge then self.inspectIlvlBadge:Hide() end
            return
        end
        local badge = self:GetOrCreateInspectIlvlBadge()
        if not badge then return end

        local unit = (InspectFrame and InspectFrame.unit) or (InspectPaperDollFrame and InspectPaperDollFrame.unit) or "target"
        if not (UnitExists and UnitExists(unit)) then
            if UnitExists and UnitExists("target") then
                unit = "target"
            end
        end

        local guid = (UnitGUID and UnitGUID(unit))
        local name = (UnitName and UnitName(unit))

        -- 1. Direct computation from equipped items
        local avgIlvl = self:CalculateUnitItemLevel(unit)

        -- 2. Lookup in-memory or persisted cache
        if not avgIlvl or avgIlvl <= 0 then
            local cachedStr = nil
            if guid and self.unitIlvlCache and self.unitIlvlCache[guid] then
                cachedStr = self.unitIlvlCache[guid]
            elseif name and self.unitIlvlCache and (self.unitIlvlCache[name] or self.unitIlvlCache[name:lower()]) then
                cachedStr = self.unitIlvlCache[name] or self.unitIlvlCache[name:lower()]
            elseif WoWEternityAddonDB and WoWEternityAddonDB.unitIlvlCache then
                if guid and WoWEternityAddonDB.unitIlvlCache[guid] then
                    cachedStr = WoWEternityAddonDB.unitIlvlCache[guid]
                elseif name and (WoWEternityAddonDB.unitIlvlCache[name] or WoWEternityAddonDB.unitIlvlCache[name:lower()]) then
                    cachedStr = WoWEternityAddonDB.unitIlvlCache[name] or WoWEternityAddonDB.unitIlvlCache[name:lower()]
                end
            end
            if cachedStr and tonumber(cachedStr) then
                avgIlvl = tonumber(cachedStr)
            end
        end

        -- 3. Lookup synced roster data
        if (not avgIlvl or avgIlvl <= 0) and name and WoWEternityAddonDB and WoWEternityAddonDB.players then
            local nLower = name:lower()
            for _, p in ipairs(WoWEternityAddonDB.players) do
                if p.name and p.name:lower() == nLower and p.avg_ilvl and p.avg_ilvl > 0 then
                    avgIlvl = p.avg_ilvl
                    break
                end
            end
        end

        -- Update Inspect Title Text if available
        if avgIlvl and avgIlvl > 0 then
            local titleTargets = {
                InspectFrame and InspectFrame.TitleText,
                InspectFrameTitleText,
                InspectNameText,
            }
            for _, textObj in ipairs(titleTargets) do
                if textObj and textObj.GetText and textObj.SetText then
                    local currentText = textObj:GetText() or ""
                    local cleanName = currentText:gsub("^|c%x+%[[%d%.]+%]|r%s*", ""):gsub("^%[[%d%.]+%]%s*", "")
                    if cleanName == "" then cleanName = name or "" end
                    if cleanName ~= "" then
                        local formatted = string.format("|cffe6cc80[%.1f]|r %s", avgIlvl, cleanName)
                        if currentText ~= formatted then
                            textObj:SetText(formatted)
                        end
                    end
                end
            end
        end

        if badge.PositionBadge then
            pcall(badge.PositionBadge)
        end

        if avgIlvl and avgIlvl > 0 then
            badge.text:SetText(string.format("|cffe6cc80iLvl|r\n|cffffffff%.1f|r", avgIlvl))
            badge:Show()
        else
            badge.text:SetText("|cffe6cc80iLvl|r\n|cffffffff...|r")
            badge:Show()
        end
    end)
end

function WoWEternityAddon:HookInspectFrame()
    if not (InspectFrame or InspectPaperDollFrame) then return end
    if self.inspectFrameHooked then return end
    self.inspectFrameHooked = true

    if InspectFrame and InspectFrame.HookScript then
        pcall(function()
            InspectFrame:HookScript("OnShow", function()
                WoWEternityAddon:UpdateInspectIlvlBadge()
            end)
        end)
    end
    if InspectPaperDollFrame and InspectPaperDollFrame.HookScript then
        pcall(function()
            InspectPaperDollFrame:HookScript("OnShow", function()
                WoWEternityAddon:UpdateInspectIlvlBadge()
            end)
        end)
    end

    -- Hook InspectFrame_Show with watchdog:
    -- In WoW Classic, if NotifyInspect is throttled or delayed, InspectFrame_Show sets InspectFrame.unit
    -- but sits waiting for INSPECT_READY. If server drops the packet, InspectFrame never shows.
    -- This 0.35s watchdog detects when InspectFrame.unit is set but window is hidden, and forces ShowUIPanel.
    if hooksecurefunc and rawget(_G, "InspectFrame_Show") then
        pcall(function()
            hooksecurefunc("InspectFrame_Show", function(unit)
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.35, function()
                        if InspectFrame and InspectFrame.unit and not (InspectFrame.IsShown and InspectFrame:IsShown()) then
                            if CanInspect and CanInspect(InspectFrame.unit) then
                                if ShowUIPanel then ShowUIPanel(InspectFrame) end
                                if InspectPaperDollFrame_OnShow then
                                    pcall(InspectPaperDollFrame_OnShow)
                                end
                                WoWEternityAddon:UpdateInspectIlvlBadge()
                            end
                        end
                    end)
                end
            end)
        end)
    end

    if IsInspectFrameShown() then
        self:UpdateInspectIlvlBadge()
    end
end

-- 1. Modern Tooltip Engine (WoW Classic 1.15+ / 10.0+ / Forever client)
local modernUnitHooked = false
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    pcall(function()
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            pcall(function()
                if not tooltip or not data then return end
                local itemId = data.id
                if itemId then
                    WoWEternityAddon:ProcessItemTooltip(tooltip, itemId)
                end
            end)
        end)
    end)
    if Enum.TooltipDataType.Unit then
        pcall(function()
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
                pcall(function()
                    if not tooltip then return end
                    WoWEternityAddon:ProcessUnitTooltip(tooltip, data)
                end)
            end)
            modernUnitHooked = true
        end)
    end
end

-- 2. Legacy Tooltip Fallback (Classic Era 1.12 - 1.14 legacy clients)
if not modernUnitHooked and GameTooltip and GameTooltip.HookScript then
    pcall(function()
        GameTooltip:HookScript("OnTooltipSetUnit", function(self)
            pcall(function()
                WoWEternityAddon:ProcessUnitTooltip(self)
            end)
        end)
    end)
end

if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall then
    local function SafeHookLegacyTooltip(tt)
        if not tt or not tt.HookScript then return end
        pcall(function()
            if not tt.HasScript or tt:HasScript("OnTooltipSetItem") then
                tt:HookScript("OnTooltipSetItem", function(self)
                    pcall(function()
                        if not self or not self.GetItem then return end
                        local _, link = self:GetItem()
                        if link then
                            local itemId = tonumber(link:match("item:(%d+)"))
                            if itemId then
                                WoWEternityAddon:ProcessItemTooltip(self, itemId)
                            end
                        end
                    end)
                end)
            end
        end)
    end
    SafeHookLegacyTooltip(GameTooltip)
    SafeHookLegacyTooltip(ItemRefTooltip)
end


-- ============================================================================
-- Lifecycle & Event Handlers
-- ============================================================================

function WoWEternityAddon:OnInitialize()
    if type(WoWEternityAddonDB) ~= "table" then
        WoWEternityAddonDB = {
            version = 1,
            checksum = 0,
            last_sync = 0,
            active_spec = "",
            players = {},
            items = {},
            unitIlvlCache = {},
            minimapPos = 45,
            showMinimap = true,
            playBiSSound = true,
            autoExport = true,
            verboseLogs = false,
        }
        self:Print("|cffe6cc80[WoW Eternity Addon]|r Initialized. Type |cffffd100/wea|r to open settings.")
    end

    WoWEternityAddonDB.players = WoWEternityAddonDB.players or {}
    WoWEternityAddonDB.items = WoWEternityAddonDB.items or {}
    WoWEternityAddonDB.unitIlvlCache = WoWEternityAddonDB.unitIlvlCache or {}
    self.unitIlvlCache = WoWEternityAddonDB.unitIlvlCache
    WoWEternityAddonDB.minimapPos = WoWEternityAddonDB.minimapPos or 45
    if WoWEternityAddonDB.showMinimap == nil then WoWEternityAddonDB.showMinimap = true end
    if WoWEternityAddonDB.playBiSSound == nil then WoWEternityAddonDB.playBiSSound = true end
    if WoWEternityAddonDB.autoExport == nil then WoWEternityAddonDB.autoExport = true end
    if WoWEternityAddonDB.verboseLogs == nil then WoWEternityAddonDB.verboseLogs = false end
    if WoWEternityAddonDB.showMapOverlays == nil then WoWEternityAddonDB.showMapOverlays = true end

    -- Cadberry Leveling Guide & Navigation Arrow Persistence
    WoWEternityAddonCharDB = WoWEternityAddonCharDB or {}
    WoWEternityAddonCharDB.cadberryCompleted = WoWEternityAddonCharDB.cadberryCompleted or {}
    WoWEternityAddonCharDB.manuallyUnchecked = WoWEternityAddonCharDB.manuallyUnchecked or {}

    WoWEternityAddonDB.waypointArrow = WoWEternityAddonDB.waypointArrow or {
        shown = true,
        locked = false,
        point = "CENTER",
        x = 0,
        y = 140,
    }

    WoWEternityAddonDB.tracker = WoWEternityAddonDB.tracker or {
        shown = true,
        collapsed = false,
        point = "TOPRIGHT",
        x = -40,
        y = -220,
        width = 280,
    }
    if WoWEternityAddonDB.autoAdvanceGuide == nil then WoWEternityAddonDB.autoAdvanceGuide = true end
    if WoWEternityAddonDB.skipOutleveled == nil then WoWEternityAddonDB.skipOutleveled = true end
    self:SyncPlayerFaction()

    self:InitAddonComms()
    self:StartProximityScanner()

    local declared = tonumber(WoWEternityAddonDB.checksum) or 0
    if declared > 0 then
        local isValid, calculated, decl = self:VerifyIntegrity()
        if isValid then
            self.isCorrupted = false
            local count = self:GetItemCount()
            local specStr = (WoWEternityAddonDB.active_spec and WoWEternityAddonDB.active_spec ~= "") and WoWEternityAddonDB.active_spec or "All Specs"
            self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Loaded successfully. %d BiS items synchronized (Spec: |cffffd100%s|r). Type |cffffd100/wea|r for commands.", count, specStr))
        else
            self.isCorrupted = true
            self:Print(string.format("|cffff2020[WoW Eternity Addon] WARNING: Database checksum mismatch or corrupt payload! Declared: %s, Calculated: %s.|r",
                tostring(decl), tostring(calculated)))
        end
    end

    local _, tamperedPlayerCount = self:VerifyAllPlayersIntegrity()
    if tamperedPlayerCount > 0 then
        self:Print(string.format("|cffff2020[WoW Eternity Addon] SECURITY ALERT: %d tampered player record(s) detected! Manipulated stats have been suppressed.|r", tamperedPlayerCount))
    end

    -- Create Minimap Button & Waypoint Navigation & Tracker HUD
    if CreateFrame and Minimap then
        self:CreateMinimapButton()
    end
    if CreateFrame then
        self:CreateWaypointArrow()
        self:InitWorldMapPins()
        self:InitMapZoneOverlays()
        self:CreateTrackerHUD()
    end
end

function WoWEternityAddon:OnPlayerLogin()
    self:SyncPlayerFaction()
    if WoWEternityAddonDB and (not WoWEternityAddonDB.active_spec or WoWEternityAddonDB.active_spec == "") then
        if UnitClass then
            local _, class = UnitClass("player")
            if class then
                WoWEternityAddonDB.active_spec = class:lower()
            end
        end
    end
    self:ScanAndSyncCompletedQuests()
end

function WoWEternityAddon:OnLootOpened()
    if not WoWEternityAddonDB or not WoWEternityAddonDB.items or not GetNumLootItems then return end
    local numItems = GetNumLootItems()
    for slot = 1, numItems do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        if link then
            local itemId = tonumber(link:match("item:(%d+)"))
            if itemId and WoWEternityAddonDB.items[itemId] then
                self:PlayBiSSound()
                break
            end
        end
    end
end

function WoWEternityAddon:OnChatMsgLoot(message)
    if not WoWEternityAddonDB or not WoWEternityAddonDB.items or not message then return end
    local link = message:match("(|c%x+|Hitem:%d+:[^|]+|h%[[^%]]+%]%|h%|r)") or message:match("(item:%d+)")
    if link then
        local itemId = tonumber(link:match("item:(%d+)"))
        if itemId and WoWEternityAddonDB.items[itemId] then
            self:PlayBiSSound()
        end
    end
end

-- ============================================================================
-- Event Frame Registration
-- ============================================================================

local eventFrame = CreateFrame and CreateFrame("Frame", "WoWEternityAddonEventFrame")
if eventFrame then
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("LOOT_OPENED")
    eventFrame:RegisterEvent("CHAT_MSG_LOOT")
    eventFrame:RegisterEvent("INSPECT_READY")
    eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    eventFrame:RegisterEvent("QUEST_TURNED_IN")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ADDON_LOADED" then
            local addon = ...
            if addon == "WoW Eternity Addon" or addon == "WoWEternityAddon" or addon == ADDON_NAME then
                WoWEternityAddon:OnInitialize()
            end
            if addon == "Blizzard_InspectUI" then
                WoWEternityAddon:HookInspectFrame()
            end
        elseif event == "PLAYER_LOGIN" then
            WoWEternityAddon:OnPlayerLogin()
            if not WoWEternityAddon.minimapButton and CreateFrame and Minimap then
                WoWEternityAddon:CreateMinimapButton()
            elseif WoWEternityAddon.RepositionMinimapButton then
                WoWEternityAddon:RepositionMinimapButton()
            end
            if WoWEternityAddon.UpdateMinimapVisibility then
                WoWEternityAddon:UpdateMinimapVisibility()
            end
            WoWEternityAddon:UpdateCharacterFrameIlvl()
            WoWEternityAddon:HookInspectFrame()
            if WoWEternityAddon.ScanAndSyncCompletedQuests then
                WoWEternityAddon:ScanAndSyncCompletedQuests()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            if not WoWEternityAddon.minimapButton and CreateFrame and Minimap then
                WoWEternityAddon:CreateMinimapButton()
            elseif WoWEternityAddon.RepositionMinimapButton then
                WoWEternityAddon:RepositionMinimapButton()
            end
            if WoWEternityAddon.UpdateMinimapVisibility then
                WoWEternityAddon:UpdateMinimapVisibility()
            end
            WoWEternityAddon:UpdateCharacterFrameIlvl()
            WoWEternityAddon:HookInspectFrame()
            if WoWEternityAddon.ScanAndSyncCompletedQuests then
                WoWEternityAddon:ScanAndSyncCompletedQuests()
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(3, function()
                    pcall(function()
                        if WoWEternityAddonDB and WoWEternityAddonDB.autoExport == false then return end
                        local mh = (GetInventoryItemID and GetInventoryItemID("player", 16)) or 0
                        local ch = (GetInventoryItemID and GetInventoryItemID("player", 5)) or 0
                        if mh > 0 or ch > 0 then
                            WoWEternityAddon:ExportCharacter(true)
                        end
                        WoWEternityAddon:BroadcastMyIlvl()
                    end)
                end)
            end
        elseif event == "LOOT_OPENED" then
            WoWEternityAddon:OnLootOpened()
        elseif event == "CHAT_MSG_LOOT" then
            local message = ...
            WoWEternityAddon:OnChatMsgLoot(message)
        elseif event == "INSPECT_READY" then
            local guid = ...
            WoWEternityAddon:OnInspectReady(guid)
        elseif event == "UNIT_INVENTORY_CHANGED" then
            local unit = ...
            if unit == "player" then
                WoWEternityAddon:UpdateCharacterFrameIlvl()
            elseif IsInspectFrameShown() then
                WoWEternityAddon:UpdateInspectIlvlBadge()
            end
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            local tt = WoWEternityAddon.activeUnitTooltip or GameTooltip
            if tt and tt.IsShown and tt:IsShown() then
                local hasIlvl, ilvlLine = TooltipHasLine(tt, "iLvl")
                if hasIlvl and ilvlLine and ilvlLine.GetText and ilvlLine:GetText():find("%.%.%.") then
                    local unit = "mouseover"
                    if not (UnitExists and UnitExists(unit)) then unit = "target" end
                    if UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit) then
                        local liveIlvl = WoWEternityAddon:CalculateUnitItemLevel(unit)
                        if liveIlvl and liveIlvl > 0 then
                            local ilvlStr = string.format("%.1f", liveIlvl)
                            local guid = UnitGUID and UnitGUID(unit)
                            local name = UnitName and UnitName(unit)
                            if guid then WoWEternityAddon:CacheUnitIlvl(guid, ilvlStr) end
                            if name then WoWEternityAddon:CacheUnitIlvl(name, ilvlStr) end
                            ilvlLine:SetText(string.format("|cffe6cc80iLvl:|r |cffffffff%s|r", ilvlStr))
                            pcall(function() tt:Show() end)
                        end
                    end
                end
            end
            if IsInspectFrameShown() and WoWEternityAddon.UpdateInspectIlvlBadge then
                pcall(function() WoWEternityAddon:UpdateInspectIlvlBadge() end)
            end
        elseif event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
            WoWEternityAddon:UpdateCharacterFrameIlvl()
        elseif event == "CHAT_MSG_ADDON" then
            local prefix, text, channel, sender = ...
            WoWEternityAddon:OnAddonMessage(prefix, text, channel, sender)
        elseif event == "GROUP_ROSTER_UPDATE" then
            WoWEternityAddon:BroadcastMyIlvl()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            WoWEternityAddon:BroadcastMyIlvl()
        elseif event == "QUEST_TURNED_IN" then
            local questId, xpReward, moneyReward = ...
            if WoWEternityAddon.OnQuestTurnedIn then
                WoWEternityAddon:OnQuestTurnedIn(questId)
            end
        elseif event == "PLAYER_LEVEL_UP" then
            local newLevel = ...
            if WoWEternityAddon.OnPlayerLevelUp then
                WoWEternityAddon:OnPlayerLevelUp(newLevel)
            end
        elseif event == "QUEST_LOG_UPDATE" then
            if WoWEternityAddon.ScanAndSyncCompletedQuests then
                WoWEternityAddon:ScanAndSyncCompletedQuests()
            end
        end
    end)
end

-- ============================================================================
-- Slash Commands (/wea, /woweternity, /woweternityaddon)
-- ============================================================================

SLASH_WEA1 = "/wea"
SLASH_WEA2 = "/woweternity"
SLASH_WEA3 = "/woweternityaddon"

function WoWEternityAddon:TriggerInspect(unit)
    unit = unit or "target"
    if not (UnitExists and UnitExists(unit)) then
        self:Print("No unit targeted to inspect.")
        return
    end
    if UnitIsUnit and UnitIsUnit(unit, "player") then
        if ToggleCharacter then ToggleCharacter("PaperDollFrame") end
        return
    end
    if not (UnitIsPlayer and UnitIsPlayer(unit)) then
        self:Print("You can only inspect player characters.")
        return
    end
    if CanInspect and not CanInspect(unit) then
        local name = (UnitName and UnitName(unit)) or unit
        self:Print(string.format("Cannot inspect %s (target is too far away or out of range).", name))
        return
    end

    -- Ensure Blizzard_InspectUI is loaded
    if not (InspectFrame or InspectPaperDollFrame) then
        pcall(function()
            if C_AddOns and C_AddOns.LoadAddOn then
                C_AddOns.LoadAddOn("Blizzard_InspectUI")
            elseif UIParentLoadAddOn then
                UIParentLoadAddOn("Blizzard_InspectUI")
            end
        end)
    end

    if InspectFrame_Show then
        InspectFrame_Show(unit)
    elseif InspectUnit then
        InspectUnit(unit)
    end

    -- Resilience watchdog: If server throttles NotifyInspect, force ShowUIPanel after short delay
    if C_Timer and C_Timer.After then
        C_Timer.After(0.35, function()
            if InspectFrame and InspectFrame.unit and not (InspectFrame.IsShown and InspectFrame:IsShown()) then
                if CanInspect and CanInspect(InspectFrame.unit) then
                    if ShowUIPanel then ShowUIPanel(InspectFrame) end
                    if InspectPaperDollFrame_OnShow then
                        pcall(InspectPaperDollFrame_OnShow)
                    end
                    WoWEternityAddon:UpdateInspectIlvlBadge()
                end
            end
        end)
    end
end

function WoWEternityAddon:HandleSlashCommand(msg)
    local args = {}
    for word in (msg or ""):gmatch("%S+") do
        table.insert(args, word)
    end
    local cmd = args[1] and args[1]:lower() or ""

    if cmd == "help" then
        self:Print("|cffe6cc80[WoW Eternity Addon (/wea) Commands]|r")
        self:Print("  |cffffd100/wea|r - Open addon control panel (5 tabs: Account, Char, Gear Planner, BIS-Lists, Settings)")
        self:Print("  |cffffd100/wea sync|r - Export current character data to desktop app")
        self:Print("  |cffffd100/wea spec <spec_id>|r - Set active spec filter (e.g. warrior_prot, all)")
        self:Print("  |cffffd100/wea verify|r - Run Adler-32 integrity check")
        self:Print("  |cffffd100/wea count|r - Show count of synced BiS items")
        self:Print("  |cffffd100/wea minimap|r - Toggle minimap button visibility")
        self:Print("  |cffffd100/wea inspect|r - Inspect currently targeted player character")
        self:Print("  |cffffd100/wea leveling|r - Open Cadberry Leveling Guide")
        self:Print("  |cffffd100/wea synclevel|r - Dynamic sync to player level & faction (keeps steps >= level - 5)")
        self:Print("  |cffffd100/wea arrow|r - Toggle waypoint navigation arrow")
        self:Print("  |cffffd100/wea tracker|r - Toggle Questie-style floating tracker HUD")
        self:Print("  |cffffd100/wea resetguide|r - Reset leveling guide completed steps")
    elseif cmd == "sync" or cmd == "export" then
        self:ExportCharacter()
    elseif cmd == "synclevel" or cmd == "autolevel" or cmd == "skip" then
        self:SyncWithPlayerLevel(true)
    elseif cmd == "inspect" then
        self:TriggerInspect(args[2] or "target")
    elseif cmd == "spec" then
        local newSpec = args[2]
        if newSpec then
            WoWEternityAddonDB.active_spec = newSpec:lower()
            self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Active spec set to: |cffffd100%s|r", WoWEternityAddonDB.active_spec))
        else
            local cur = (WoWEternityAddonDB and WoWEternityAddonDB.active_spec and WoWEternityAddonDB.active_spec ~= "") and WoWEternityAddonDB.active_spec or "All Specs"
            self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Current active spec: |cffffd100%s|r", cur))
        end
        if self.mainFrame and self.mainFrame:IsShown() then
            self:UpdateMainFrameView()
        end
    elseif cmd == "verify" or cmd == "check" then
        local isValid, calc, decl = self:VerifyIntegrity()
        if isValid then
            self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Database integrity verified OK. Checksum: |cffffd100%d|r.", calc))
        else
            self:Print(string.format("|cffff2020[WoW Eternity Addon] Integrity check FAILED! Calc: %s, Decl: %s.|r", tostring(calc), tostring(decl)))
        end
        local vCount, tCount, uCount = self:VerifyAllPlayersIntegrity()
        if tCount > 0 then
            self:Print(string.format("|cffff2020[WoW Eternity Addon] Player Cryptographic Verification: %d TAMPERED, %d verified, %d unsigned.|r", tCount, vCount, uCount))
        else
            self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Player Cryptographic Verification: %d verified, %d unsigned, 0 tampered.", vCount, uCount))
        end
    elseif cmd == "count" then
        self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Tracked BiS items: |cffffd100%d|r", self:GetItemCount()))
    elseif cmd == "minimap" then
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.showMinimap = not (WoWEternityAddonDB.showMinimap ~= false)
        self:UpdateMinimapVisibility()
        self:Print(string.format("|cffe6cc80[WoW Eternity Addon]|r Minimap button: %s", WoWEternityAddonDB.showMinimap and "|cff00ff00Enabled|r" or "|cffff2020Disabled|r"))
    elseif cmd == "account" then
        self:ToggleSettingsFrame("Account")
    elseif cmd == "char" or cmd == "character" then
        self:ToggleSettingsFrame("Char")
    elseif cmd == "gear" or cmd == "planner" then
        self:ToggleSettingsFrame("Gear Planner")
    elseif cmd == "bis" or cmd == "bislist" or cmd == "bislists" then
        self:ToggleSettingsFrame("BIS-Lists")
    elseif cmd == "settings" or cmd == "config" or cmd == "options" then
        self:ToggleSettingsFrame("Settings")
    elseif cmd == "leveling" or cmd == "guide" then
        self:ToggleSettingsFrame("Leveling")
    elseif cmd == "tracker" or cmd == "hud" then
        self:ToggleTrackerHUD()
    elseif cmd == "arrow" then
        self:ToggleWaypointArrow()
    elseif cmd == "map" or cmd == "mapoverlay" or cmd == "zoneoverlay" then
        self:ToggleMapZoneOverlays()
    elseif cmd == "cursor" or cmd == "coord" or cmd == "mapcoord" or cmd == "mappos" then
        self:PrintMapCursorPosition()
    elseif cmd == "resetguide" or cmd == "resetleveling" then
        self:ResetLevelingGuide()
    else
        self:ToggleSettingsFrame()
    end
end

if SlashCmdList then
    SlashCmdList["WEA"] = function(msg)
        WoWEternityAddon:HandleSlashCommand(msg)
    end
end

if not (SlashCmdList and SlashCmdList["INSPECT"]) then
    SLASH_INSPECT1 = "/inspect"
    if SlashCmdList then
        SlashCmdList["INSPECT"] = function(msg)
            local unit = (msg and msg ~= "" and msg) or "target"
            WoWEternityAddon:TriggerInspect(unit)
        end
    end
end
