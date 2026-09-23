-- ============================================================================
-- WoW Eternity Addon (WEA) - /wea
-- WoW Eternity Client BiS Tooltip Sync & In-Game Character Exporter
-- Version: 1.1.0 (Interface: 11506)
-- ============================================================================

local ADDON_NAME = "WoW Eternity Addon"
local SOUND_ID = 888
local SOUND_DEBOUNCE_INTERVAL = 2.0

-- Root addon namespace
local WoWEternityAddon = {
    name = "WoW Eternity Addon",
    version = "1.1.0",
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
-- Client Compatibility Patch (Classic 1.15.6 / Camelot Beta)
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

local TABS = {
    { id = "Account", label = "Account" },
    { id = "Char", label = "Char" },
    { id = "Gear Planner", label = "Gear Planner" },
    { id = "BIS-Lists", label = "BIS-Lists" },
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
    prefCard:SetHeight(205)

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
    tab.cbSound:SetPoint("TOPLEFT", 14, -66)

    CreateStyledButton(prefCard, "Test Sound", 95, 22, function()
        pcall(PlaySound, SOUND_ID)
    end):SetPoint("LEFT", tab.cbSound, "RIGHT", 270, 0)

    tab.cbAutoExport = CreateCheckbox(prefCard, "WoWEternityAddonOptAutoExport", "Auto-Export Character on Login & Zone Change", true, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.autoExport = checked
    end)
    tab.cbAutoExport:SetPoint("TOPLEFT", 14, -98)

    tab.cbPlayerTooltips = CreateCheckbox(prefCard, "WoWEternityAddonOptPlayerTooltips", "Show Progress & Parse in Player Tooltips", true, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.showPlayerTooltips = checked
    end)
    tab.cbPlayerTooltips:SetPoint("TOPLEFT", 14, -130)

    tab.cbVerbose = CreateCheckbox(prefCard, "WoWEternityAddonOptVerbose", "Verbose Talent Diagnostics in Chat", false, function(checked)
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.verboseLogs = checked
    end)
    tab.cbVerbose:SetPoint("TOPLEFT", 14, -162)

    local dbPath = prefCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dbPath:SetPoint("TOPLEFT", 14, -192)
    dbPath:SetText("SavedVariables: |cff9ca3afWTF/Account/<Account>/SavedVariables/WoW Eternity Addon.lua|r")

    -- Card 2: Slash Commands Reference
    local slashCard = CreateCard(tab)
    slashCard:SetPoint("TOPLEFT", 0, -225)
    slashCard:SetPoint("TOPRIGHT", 0, -225)
    slashCard:SetHeight(120)

    local title2 = slashCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title2:SetPoint("TOPLEFT", 12, -10)
    title2:SetText("|cffe6cc80Slash Commands Reference|r")

    local ref = slashCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ref:SetPoint("TOPLEFT", 12, -30)
    ref:SetPoint("TOPRIGHT", -12, -30)
    ref:SetJustifyH("LEFT")
    ref:SetText(
        "|cffffd100/wea|r - Toggle this 5-tab main control window\n" ..
        "|cffffd100/wea sync|r - Export gear, unbuffed stats, and talents to desktop client\n" ..
        "|cffffd100/wea spec <name>|r - Set active BiS spec filter (e.g. paladin_ret, all)\n" ..
        "|cffffd100/wea verify|r - Verify database Adler-32 checksum integrity\n" ..
        "|cffffd100/wea minimap|r - Toggle minimap button visibility"
    )

    -- Bottom Actions
    CreateStyledButton(tab, "Reset Settings to Default", 240, 28, function()
        WoWEternityAddonDB = WoWEternityAddonDB or {}
        WoWEternityAddonDB.showMinimap = true
        WoWEternityAddonDB.playBiSSound = true
        WoWEternityAddonDB.autoExport = true
        WoWEternityAddonDB.showPlayerTooltips = true
        WoWEternityAddonDB.verboseLogs = false
        WoWEternityAddonDB.minimapPos = 45
        WoWEternityAddon:UpdateSettingsTab()
        WoWEternityAddon:UpdateMinimapVisibility()
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
end

function WoWEternityAddon:CreateMainFrame()
    if not CreateFrame then return end
    if self.mainFrame then return end

    local frame = CreateFrame("Frame", "WoWEternityAddonMainFrame", UIParent, GetBackdropTemplate())
    self.mainFrame = frame

    frame:SetSize(520, 480)
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
        btn:SetSize(95, 26)
        btn:SetPoint("LEFT", (i - 1) * 99, 0)
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

    -- Create all 5 Tab Frames inside contentArea
    self:CreateAccountTab(contentArea)
    self:CreateCharTab(contentArea)
    self:CreateGearPlannerTab(contentArea)
    self:CreateBisListsTab(contentArea)
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

    -- Create Minimap Button
    if CreateFrame and Minimap then
        self:CreateMinimapButton()
    end
end

function WoWEternityAddon:OnPlayerLogin()
    if WoWEternityAddonDB and (not WoWEternityAddonDB.active_spec or WoWEternityAddonDB.active_spec == "") then
        if UnitClass then
            local _, class = UnitClass("player")
            if class then
                WoWEternityAddonDB.active_spec = class:lower()
            end
        end
    end
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
    elseif cmd == "sync" or cmd == "export" then
        self:ExportCharacter()
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
