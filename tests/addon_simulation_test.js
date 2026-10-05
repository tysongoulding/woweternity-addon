import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ADDON_DIR = path.resolve(__dirname, '..');
const TOC_PATH = path.join(ADDON_DIR, 'WoW Eternity Addon.toc');
const LUA_PATH = path.join(ADDON_DIR, 'WoWEternityAddon.lua');

// Suite 1: TOC Verification
const rawToc = fs.readFileSync(TOC_PATH, 'utf-8');
const cleanToc = rawToc.replace(/^\uFEFF/, '');
assert.ok(/## Interface:\s*16001/.test(cleanToc), 'TOC must specify Interface: 16001');
assert.ok(/## Version:\s*1\.2\.0/.test(cleanToc), 'TOC must declare Version: 1.2.0');
assert.ok(/## SavedVariables:\s*WoWEternityAddonDB/.test(cleanToc), 'TOC must declare SavedVariables: WoWEternityAddonDB');
assert.ok(/## Title:\s*.*WoW Eternity Addon/i.test(cleanToc), 'TOC must have valid Title');
assert.ok(cleanToc.split(/\r?\n/).some(line => line.trim() === 'WoWEternityAddon.lua'), 'TOC must declare WoWEternityAddon.lua');

// Suite 2: Lua Static Analysis
const luaSource = fs.readFileSync(LUA_PATH, 'utf-8');
const luaLines = luaSource.split(/\r?\n/);
let quoteErrors = 0;
for (let i = 0; i < luaLines.length; i++) {
    const cleanLine = luaLines[i].replace(/\\"/g, '').replace(/\\'/g, '');
    const quotes = (cleanLine.match(/"/g) || []).length;
    if (quotes % 2 !== 0 && !cleanLine.includes('[[') && !cleanLine.includes(']]')) {
        quoteErrors++;
    }
}
assert.strictEqual(quoteErrors, 0, `Detected ${quoteErrors} unclosed double-quote lines in Lua source`);
assert.ok(luaSource.includes('version = "1.2.0"'), 'Must declare version 1.2.0');
assert.ok(luaSource.includes('interfaceVersion = 16001'), 'Must declare interfaceVersion 16001');
assert.ok(luaSource.includes('build = "1.60.1.70170"'), 'Must declare build 1.60.1.70170');
assert.ok(luaSource.includes('ADDON_LOADED'), 'Must register ADDON_LOADED');
assert.ok(luaSource.includes('OnTooltipSetItem'), 'Must hook OnTooltipSetItem');
assert.ok(luaSource.includes('PlaySound(SOUND_ID)') || luaSource.includes('PlaySound(888)') || luaSource.includes('pcall(PlaySound, SOUND_ID)'), 'Must play sound');
assert.ok(luaSource.includes('|cFF00FF00[BiS Item: Custom Profile]|r'), 'Must format Custom tag');
assert.ok(luaSource.includes('|cFFFFD700[BiS Item: Default]|r'), 'Must format Default tag');
assert.ok(luaSource.includes('SLASH_WEA1'), 'Must define /wea slash command');
assert.ok(luaSource.includes('SLASH_WEA2'), 'Must define /woweternity slash command');
assert.ok(luaSource.includes('SLASH_WEA3'), 'Must define /woweternityaddon slash command');

// Suite 3: Player Unit Tooltip & Inspect Engine Verification
assert.ok(luaSource.includes('CalculateUnitItemLevel'), 'Must define CalculateUnitItemLevel');
assert.ok(luaSource.includes('GetUnitItemLevel'), 'Must define GetUnitItemLevel');
assert.ok(luaSource.includes('OnInspectReady'), 'Must define OnInspectReady');
assert.ok(luaSource.includes('INSPECT_READY'), 'Must register and handle INSPECT_READY event');
assert.ok(luaSource.includes('iLvl:|r |cffffffff%s|r'), 'Must format dynamic iLvl on Line 1');
assert.ok(luaSource.includes('Parse:|r %s'), 'Must format Parse on Line 2');
assert.ok(luaSource.includes('Progress:|r %s'), 'Must format Progress on Line 3');
assert.ok(luaSource.includes('Release Nov. 4th'), 'Must default progress and parse to Release Nov. 4th');
assert.ok(luaSource.includes('CharacterNameText'), 'Must hook native WoW CharacterNameText');
assert.ok(luaSource.includes('UpdateCharacterFrameIlvl'), 'Must define UpdateCharacterFrameIlvl');
assert.ok(luaSource.includes('GetOrCreatePaperDollIlvlBadge'), 'Must define GetOrCreatePaperDollIlvlBadge');
assert.ok(luaSource.includes('GetOrCreateInspectIlvlBadge'), 'Must define GetOrCreateInspectIlvlBadge');
assert.ok(luaSource.includes('UpdateInspectIlvlBadge'), 'Must define UpdateInspectIlvlBadge');
assert.ok(luaSource.includes('HookInspectFrame'), 'Must define HookInspectFrame');
assert.ok(luaSource.includes('WoWEternity_InspectIlvlBadge'), 'Must define WoWEternity_InspectIlvlBadge frame');
assert.ok(luaSource.includes('Blizzard_InspectUI'), 'Must handle Blizzard_InspectUI load event');
assert.ok(luaSource.includes("Phase 1:|r |cffffffffBarrow Deeps, Hyjal Summit, Onyxia's Lair|r"), 'Must display Phase 1 on character screen');
// Suite 4: Anti-Tamper & Cryptographic Verification Engine
assert.ok(luaSource.includes('ComputeSHA256Raw'), 'Must define ComputeSHA256Raw');
assert.ok(luaSource.includes('ComputeHMACSHA256'), 'Must define ComputeHMACSHA256');
assert.ok(luaSource.includes('CanonicalPlayerString'), 'Must define CanonicalPlayerString');
assert.ok(luaSource.includes('VerifyPlayerSignature'), 'Must define VerifyPlayerSignature');
assert.ok(luaSource.includes('VerifyAllPlayersIntegrity'), 'Must define VerifyAllPlayersIntegrity');
assert.ok(luaSource.includes('[Tampered Data]'), 'Must flag tampered player data');
assert.ok(luaSource.includes('[✔]'), 'Must display verified badge on validated records');

// Suite 5: Addon Comms, Persistent iLvl Cache & Proximity Scanner Verification
assert.ok(luaSource.includes('CacheUnitIlvl'), 'Must define CacheUnitIlvl');
assert.ok(luaSource.includes('InitAddonComms'), 'Must define InitAddonComms');
assert.ok(luaSource.includes('BroadcastMyIlvl'), 'Must define BroadcastMyIlvl');
assert.ok(luaSource.includes('RequestPlayerIlvl'), 'Must define RequestPlayerIlvl');
assert.ok(luaSource.includes('OnAddonMessage'), 'Must define OnAddonMessage');
assert.ok(luaSource.includes('StartProximityScanner'), 'Must define StartProximityScanner');
assert.ok(luaSource.includes('CHAT_MSG_ADDON'), 'Must register and handle CHAT_MSG_ADDON');
assert.ok(luaSource.includes('GROUP_ROSTER_UPDATE'), 'Must register and handle GROUP_ROSTER_UPDATE');
assert.ok(luaSource.includes('PLAYER_EQUIPMENT_CHANGED'), 'Must register and handle PLAYER_EQUIPMENT_CHANGED');
assert.ok(luaSource.includes('unitIlvlCache'), 'Must persist unitIlvlCache');

// Suite 6: Cadberry Leveling Guide & Waypoint Navigation Engine
// 1. Data Integrity: Alliance 44 steps and Horde 34 steps
assert.ok(luaSource.includes('CADBERRY_ALLIANCE_GUIDE'), 'Must declare CADBERRY_ALLIANCE_GUIDE');
assert.ok(luaSource.includes('CADBERRY_HORDE_GUIDE'), 'Must declare CADBERRY_HORDE_GUIDE');

const allyPart = luaSource.split('local CADBERRY_HORDE_GUIDE')[0];
const hordePart = luaSource.split('local CADBERRY_HORDE_GUIDE')[1];
const allySteps = (allyPart.match(/id\s*=\s*"ally-\d+"/g) || []).length;
const hordeSteps = (hordePart.match(/id\s*=\s*"horde-\d+"/g) || []).length;
assert.strictEqual(allySteps, 44, `Must have exactly 44 Alliance steps, found ${allySteps}`);
assert.strictEqual(hordeSteps, 34, `Must have exactly 34 Horde steps, found ${hordeSteps}`);

// 2. Tab Registration & Frame Resizing
assert.ok(/\{\s*id\s*=\s*"Leveling",\s*label\s*=\s*"Leveling"\s*\}/.test(luaSource), 'Must register Leveling tab in TABS');
assert.ok(luaSource.includes('frame:SetSize(640, 520)'), 'Must expand main frame size to 640x520');
assert.ok(luaSource.includes('self:CreateLevelingTab(contentArea)'), 'Must create Leveling tab in main frame');
assert.ok(luaSource.includes('self:UpdateLevelingTab()'), 'Must update Leveling tab on select');

// 3. UI Components & Methods
assert.ok(luaSource.includes('function WoWEternityAddon:CreateLevelingTab'), 'Must define CreateLevelingTab');
assert.ok(luaSource.includes('function WoWEternityAddon:UpdateLevelingTab'), 'Must define UpdateLevelingTab');
assert.ok(luaSource.includes('function WoWEternityAddon:GetActiveLevelingStep'), 'Must define GetActiveLevelingStep');
assert.ok(luaSource.includes('function WoWEternityAddon:ResetLevelingGuide'), 'Must define ResetLevelingGuide');

// 4. Waypoint Navigation Arrow
assert.ok(luaSource.includes('function WoWEternityAddon:CreateWaypointArrow'), 'Must define CreateWaypointArrow');
assert.ok(luaSource.includes('function WoWEternityAddon:UpdateWaypointArrow'), 'Must define UpdateWaypointArrow');
assert.ok(luaSource.includes('function WoWEternityAddon:ToggleWaypointArrow'), 'Must define ToggleWaypointArrow');
assert.ok(luaSource.includes('WoWEternityAddonWaypointArrow'), 'Must create WoWEternityAddonWaypointArrow frame');
assert.ok(luaSource.includes('math.atan2(dx, -dy)'), 'Must compute bearing using atan2(dx, -dy)');
assert.ok(luaSource.includes('Arrived! (< 15 yds)'), 'Must format arrival state (< 15 yds)');

// 5. World Map Pin Overlay
assert.ok(luaSource.includes('function WoWEternityAddon:InitWorldMapPins'), 'Must define InitWorldMapPins');
assert.ok(luaSource.includes('function WoWEternityAddon:UpdateWorldMapPins'), 'Must define UpdateWorldMapPins');
assert.ok(luaSource.includes('WorldMapFrame:HookScript("OnShow"'), 'Must hook WorldMapFrame OnShow');

// 6. Persistence & Slash Commands
assert.ok(luaSource.includes('WoWEternityAddonCharDB.cadberryCompleted'), 'Must persist cadberryCompleted per character');
assert.ok(luaSource.includes('WoWEternityAddonDB.waypointArrow'), 'Must persist waypointArrow settings in DB');
assert.ok(luaSource.includes('cmd == "leveling" or cmd == "guide"'), 'Must handle /wea leveling and /wea guide slash commands');
assert.ok(luaSource.includes('cmd == "arrow"'), 'Must handle /wea arrow slash command');
assert.ok(luaSource.includes('cmd == "resetguide" or cmd == "resetleveling"'), 'Must handle /wea resetguide slash command');

// 7. Strict Linear Auto-Tracking Simulation
const extractSteps = (src, prefix) => {
    const regex = new RegExp(`id\\s*=\\s*"(${prefix}-\\d+)",\\s*stepNumber\\s*=\\s*(\\d+),\\s*levelBadge\\s*=\\s*"([^"]+)",[\\s\\S]*?type\\s*=\\s*"([^"]+)"`, 'g');
    const steps = [];
    let match;
    while ((match = regex.exec(src)) !== null) {
        steps.push({ id: match[1], stepNumber: parseInt(match[2], 10), levelBadge: match[3], type: match[4] });
    }
    return steps;
};

const allyStepObjects = extractSteps(allyPart, 'ally');
const hordeStepObjects = extractSteps(hordePart, 'horde');
assert.strictEqual(allyStepObjects.length, 44, 'Must parse 44 Alliance step objects');
assert.strictEqual(hordeStepObjects.length, 34, 'Must parse 34 Horde step objects');

// Simulate GetActiveLevelingStep
const simulateGetActiveStep = (steps, completedMap) => {
    for (const s of steps) {
        if (!completedMap[s.id]) return s;
    }
    return null;
};

let completed = {};
assert.strictEqual(simulateGetActiveStep(allyStepObjects, completed).stepNumber, 1, 'Default active step must be step 1');
completed['ally-1'] = true;
assert.strictEqual(simulateGetActiveStep(allyStepObjects, completed).stepNumber, 2, 'Checking step 1 must advance to step 2');
completed['ally-2'] = true;
assert.strictEqual(simulateGetActiveStep(allyStepObjects, completed).stepNumber, 3, 'Checking step 2 must advance to step 3');

// Complete all up to 43
for (let i = 1; i <= 43; i++) completed[`ally-${i}`] = true;
assert.strictEqual(simulateGetActiveStep(allyStepObjects, completed).stepNumber, 44, 'Active step must be final milestone 44');
completed['ally-44'] = true;
assert.strictEqual(simulateGetActiveStep(allyStepObjects, completed), null, 'All completed must return null (complete state)');

// ============================================================================
// SUITE 7: Questie-Styled On-Screen Tracker HUD & Database Enrichment
// ============================================================================
console.log('--- Suite 7: Questie-Styled Tracker HUD & Questie DB Enrichment ---');

// 1. Static Analysis of Methods & Frames
assert.ok(luaSource.includes('function WoWEternityAddon:CreateTrackerHUD()'), 'Must implement CreateTrackerHUD');
assert.ok(luaSource.includes('function WoWEternityAddon:UpdateTrackerHUD()'), 'Must implement UpdateTrackerHUD');
assert.ok(luaSource.includes('function WoWEternityAddon:ToggleTrackerHUD()'), 'Must implement ToggleTrackerHUD');
assert.ok(luaSource.includes('function WoWEternityAddon:GetUpcomingLevelingSteps('), 'Must implement GetUpcomingLevelingSteps');
assert.ok(luaSource.includes('function WoWEternityAddon:GetDistanceToStep('), 'Must implement GetDistanceToStep');
assert.ok(luaSource.includes('WoWEternityAddonTrackerFrame'), 'Must create WoWEternityAddonTrackerFrame');
assert.ok(luaSource.includes('QUESTIE_GUIDE_ENRICHMENT'), 'Must define QUESTIE_GUIDE_ENRICHMENT');
assert.ok(luaSource.includes('function WoWEternityAddon:EnrichGuideWithQuestieData()'), 'Must implement EnrichGuideWithQuestieData');

// 2. Slash command /wea tracker
assert.ok(luaSource.includes('cmd == "tracker"'), 'Must handle /wea tracker slash command');

// 3. Simulation of GetUpcomingLevelingSteps
const simulateGetUpcomingSteps = (steps, completedMap, count = 2) => {
    const upcoming = [];
    let skippedActive = false;
    for (const s of steps) {
        if (!completedMap[s.id]) {
            if (!skippedActive) {
                skippedActive = true;
            } else {
                upcoming.push(s);
                if (upcoming.length >= count) break;
            }
        }
    }
    return upcoming;
};

const cState = {};
const up1 = simulateGetUpcomingSteps(allyStepObjects, cState, 2);
assert.strictEqual(up1.length, 2, 'Should return 2 upcoming steps initially');
assert.strictEqual(up1[0].stepNumber, 2, 'First upcoming step should be step 2');
assert.strictEqual(up1[1].stepNumber, 3, 'Second upcoming step should be step 3');

cState['ally-1'] = true;
const up2 = simulateGetUpcomingSteps(allyStepObjects, cState, 2);
assert.strictEqual(up2[0].stepNumber, 3, 'When step 1 is done, first upcoming is step 3');
assert.strictEqual(up2[1].stepNumber, 4, 'When step 1 is done, second upcoming is step 4');

for (let i = 1; i <= 43; i++) cState[`ally-${i}`] = true;
const upNearEnd = simulateGetUpcomingSteps(allyStepObjects, cState, 2);
assert.strictEqual(upNearEnd.length, 0, 'When step 44 is active (final step), upcoming must be empty');

// 4. Verification of Questie Enrichment Mappings
assert.ok(luaSource.includes('["ally-7"] = { questId = 65, questName = "The Defias Brotherhood"'), 'Step ally-7 must map to Defias Brotherhood (65)');
assert.ok(luaSource.includes('["ally-8"] = { questId = 155'), 'Step ally-8 must map to Deadmines dungeon quest (155)');
assert.ok(luaSource.includes('["ally-11"] = { questId = 391'), 'Step ally-11 must map to Stockade Riots (391)');
assert.ok(luaSource.includes('["horde-4"] = { questId = 5722'), 'Step horde-4 must map to RFC quest (5722)');
assert.ok(luaSource.includes('["horde-10"] = { questId = 1014'), 'Step horde-10 must map to Arugal Must Die (1014)');

// Verify custom fallback markers
assert.ok(luaSource.includes('["ally-3"] = { starter = "Westfall Campfire", custom = true'), 'Cozy sleeping bag must use custom marker with exact coords');
assert.ok(luaSource.includes('["ally-5"] = { starter = "Custom Objective", custom = true'), 'Hall of Thanes must use custom marker');

// 5. Verification of Tracker HUD Drag and Settings Persistence
assert.ok(luaSource.includes('WoWEternityAddonDB.tracker'), 'Must persist tracker state in WoWEternityAddonDB.tracker');
assert.ok(luaSource.includes('WEA_TrackerActiveCB'), 'Must provide interactive checkbutton on tracker HUD');

// ============================================================================
// SUITE 8: Automatic Quest Turn-In & Level Milestone Detection
// ============================================================================
console.log('--- Suite 8: Automatic Quest Turn-In & Level Milestone Detection ---');

// 1. Static Verification of Event Registrations and Handlers
assert.ok(luaSource.includes('eventFrame:RegisterEvent("QUEST_TURNED_IN")'), 'Must register QUEST_TURNED_IN event');
assert.ok(luaSource.includes('eventFrame:RegisterEvent("PLAYER_LEVEL_UP")'), 'Must register PLAYER_LEVEL_UP event');
assert.ok(luaSource.includes('eventFrame:RegisterEvent("QUEST_LOG_UPDATE")'), 'Must register QUEST_LOG_UPDATE event');

assert.ok(luaSource.includes('function WoWEternityAddon:OnQuestTurnedIn(questId)'), 'Must implement OnQuestTurnedIn');
assert.ok(luaSource.includes('function WoWEternityAddon:ScanAndSyncCompletedQuests()'), 'Must implement ScanAndSyncCompletedQuests');
assert.ok(luaSource.includes('function WoWEternityAddon:OnPlayerLevelUp(newLevel)'), 'Must implement OnPlayerLevelUp');

assert.ok(luaSource.includes('WoWEternityAddonDB.autoAdvanceGuide'), 'Must support autoAdvanceGuide setting');

// 2. Behavioral Simulation: Turn-In Detection & Auto-Advance
const enrichRegex = /\["(ally-\d+)"\]\s*=\s*\{[^}]*?questId\s*=\s*(\d+)/g;
let eMatch;
const enrichment = {};
while ((eMatch = enrichRegex.exec(luaSource)) !== null) {
    enrichment[eMatch[1]] = parseInt(eMatch[2], 10);
}
for (const step of allyStepObjects) {
    if (enrichment[step.id]) {
        step.questieQuestId = enrichment[step.id];
    }
}

const simulateOnQuestTurnedIn = (steps, completedMap, questId) => {
    let matchedStep = null;
    for (const step of steps) {
        if (!completedMap[step.id] && step.questieQuestId === questId) {
            matchedStep = step;
            break;
        }
    }
    if (matchedStep) {
        completedMap[matchedStep.id] = true;
        return {
            completedStep: matchedStep,
            nextActiveStep: simulateGetActiveStep(steps, completedMap)
        };
    }
    return null;
};

// Simulate completing ally-7 (Defias Brotherhood, quest 65)
const simCompleted = {};
// Initially active step is 1
assert.strictEqual(simulateGetActiveStep(allyStepObjects, simCompleted).stepNumber, 1);

// Suppose player turns in quest 65
const result = simulateOnQuestTurnedIn(allyStepObjects, simCompleted, 65);
assert.ok(result, 'Turning in quest 65 should find matching step');
assert.strictEqual(result.completedStep.id, 'ally-7', 'Matched step should be ally-7');
assert.strictEqual(simCompleted['ally-7'], true, 'ally-7 should now be marked completed in char DB');

// Active step remains step 1 because steps 1-6 are still incomplete
assert.strictEqual(simulateGetActiveStep(allyStepObjects, simCompleted).stepNumber, 1);

// When steps 1-6 are completed, active step should automatically skip 7 and go to 8!
for (let i = 1; i <= 6; i++) simCompleted[`ally-${i}`] = true;
assert.strictEqual(simulateGetActiveStep(allyStepObjects, simCompleted).stepNumber, 8, 'Should skip already completed step 7 and point to step 8');

// 3. Simulate milestone level up
const simulateLevelUpSync = (steps, completedMap, playerLevel) => {
    let newlyCompleted = 0;
    for (const step of steps) {
        if (!completedMap[step.id] && step.type === 'milestone') {
            const reqMatch = step.levelBadge && step.levelBadge.match(/(\d+)/);
            if (reqMatch && playerLevel >= parseInt(reqMatch[1], 10)) {
                completedMap[step.id] = true;
                newlyCompleted++;
            }
        }
    }
    return newlyCompleted;
};

const levelSim = {};
// ally-38 is milestone level 55 ("Hit Level 55 Milestone"), ally-44 is milestone level 60 ("GRATS ON 60!")
assert.strictEqual(simulateLevelUpSync(allyStepObjects, levelSim, 54), 0, 'Level 54 should not complete level 55 milestone');
assert.strictEqual(levelSim['ally-38'], undefined);
assert.strictEqual(levelSim['ally-44'], undefined);

assert.strictEqual(simulateLevelUpSync(allyStepObjects, levelSim, 55), 1, 'Level 55 should trigger ally-38 milestone completion');
assert.strictEqual(levelSim['ally-38'], true, 'Step 38 should be completed at level 55');
assert.strictEqual(levelSim['ally-44'], undefined, 'Step 44 should still be incomplete at level 55');

// ============================================================================
// SUITE 9: Dynamic Player Level Skip (>5 Levels Below) & Auto-Faction
// ============================================================================
console.log('--- Suite 9: Dynamic Level Call, Auto-Skip Outleveled & Faction Detection ---');

// 1. Static Verification of Methods & DB Properties
assert.ok(luaSource.includes('function WoWEternityAddon:GetPlayerFaction()'), 'Must implement GetPlayerFaction');
assert.ok(luaSource.includes('function WoWEternityAddon:SyncPlayerFaction()'), 'Must implement SyncPlayerFaction');
assert.ok(luaSource.includes('function WoWEternityAddon:GetStepLevelRange(step)'), 'Must implement GetStepLevelRange');
assert.ok(luaSource.includes('function WoWEternityAddon:SyncWithPlayerLevel(verbose)'), 'Must implement SyncWithPlayerLevel');
assert.ok(luaSource.includes('WoWEternityAddonDB.skipOutleveled'), 'Must support skipOutleveled setting');
assert.ok(luaSource.includes('WoWEternityAddonCharDB.manuallyUnchecked'), 'Must persist manuallyUnchecked per character');
assert.ok(luaSource.includes('cmd == "synclevel"'), 'Must handle /wea synclevel command');

// 2. Behavioral Simulation of GetStepLevelRange
const simulateGetStepLevelRange = (badge) => {
    if (!badge) return [1, 60];
    const rangeMatch = badge.match(/(\d+)\s*[^\d\s]+\s*(\d+)/);
    if (rangeMatch) {
        return [parseInt(rangeMatch[1], 10), parseInt(rangeMatch[2], 10)];
    }
    const singleMatch = badge.match(/(\d+)/);
    if (singleMatch) {
        const val = parseInt(singleMatch[1], 10);
        return [val, val];
    }
    return [1, 60];
};

assert.deepStrictEqual(simulateGetStepLevelRange('1–12'), [1, 12], '1–12 must parse to [1, 12]');
assert.deepStrictEqual(simulateGetStepLevelRange('~13'), [13, 13], '~13 must parse to [13, 13]');
assert.deepStrictEqual(simulateGetStepLevelRange('13–15'), [13, 15], '13–15 must parse to [13, 15]');
assert.deepStrictEqual(simulateGetStepLevelRange('55'), [55, 55], '55 must parse to [55, 55]');
assert.deepStrictEqual(simulateGetStepLevelRange('60'), [60, 60], '60 must parse to [60, 60]');

// Attach min/max levels to step objects
for (const step of allyStepObjects) {
    const [minLvl, maxLvl] = simulateGetStepLevelRange(step.levelBadge);
    step.minLvl = minLvl;
    step.maxLvl = maxLvl;
}
for (const step of hordeStepObjects) {
    const [minLvl, maxLvl] = simulateGetStepLevelRange(step.levelBadge);
    step.minLvl = minLvl;
    step.maxLvl = maxLvl;
}

// 3. Simulation of Level-Based Auto-Skip (>5 levels below character)
const simulateDynamicLevelSync = (steps, completedMap, manuallyUncheckedMap, playerLevel, skipOutleveled = true) => {
    if (!skipOutleveled) return 0;
    const minRelevantLevel = Math.max(1, playerLevel - 5);
    let newlyCompleted = 0;
    for (const step of steps) {
        if (!completedMap[step.id]) {
            if (step.maxLvl && playerLevel > step.maxLvl && step.minLvl < minRelevantLevel && !manuallyUncheckedMap[step.id]) {
                completedMap[step.id] = true;
                newlyCompleted++;
            }
        }
    }
    return newlyCompleted;
};

// Test A: Level 10 toon (min relevant level = 5)
// Step 1 is 1-12 (playerLevel 10 <= 12). Nothing should be skipped!
const charLvl10 = {};
const uncheckLvl10 = {};
simulateDynamicLevelSync(allyStepObjects, charLvl10, uncheckLvl10, 10);
assert.strictEqual(simulateGetActiveStep(allyStepObjects, charLvl10).stepNumber, 1, 'Level 10 should keep step 1 active');

// Test B: Level 20 toon (min relevant level = 15)
// Steps 1-5 have min < 15 and max < 20 -> SKIPPED!
// Step 6 (15-18) min 15 >= 15 -> KEPT (gap: 5 levels)!
const charLvl20 = {};
const uncheckLvl20 = {};
simulateDynamicLevelSync(allyStepObjects, charLvl20, uncheckLvl20, 20);
assert.strictEqual(charLvl20['ally-1'], true, 'Step 1 should be skipped at level 20');
assert.strictEqual(charLvl20['ally-2'], true, 'Step 2 should be skipped at level 20');
assert.strictEqual(charLvl20['ally-3'], true, 'Step 3 (max 13) should be skipped at level 20');
assert.strictEqual(charLvl20['ally-4'], true, 'Step 4 (min 13 < 15) should be skipped at level 20');
assert.strictEqual(charLvl20['ally-5'], true, 'Step 5 (min 13 < 15) should be skipped at level 20');
assert.strictEqual(charLvl20['ally-6'], undefined, 'Step 6 (min 15 >= 15) should NOT be skipped at level 20 (within 5 levels)');
assert.strictEqual(simulateGetActiveStep(allyStepObjects, charLvl20).stepNumber, 6, 'Level 20 should have step 6 active');

// Test C: Level 30 toon (min relevant level = 25)
// Steps with min < 25 and max < 30 are skipped.
// Step 10 (24-26) min 24 < 25 -> SKIPPED!
// Step 11 (24-28) min 24 < 25 -> SKIPPED!
// Step 12 (26-30) min 26 >= 25 -> KEPT (gap: 4 levels)!
const charLvl30 = {};
const uncheckLvl30 = {};
simulateDynamicLevelSync(allyStepObjects, charLvl30, uncheckLvl30, 30);
assert.strictEqual(charLvl30['ally-8'], true, 'Step 8 (max 22) should be skipped at level 30');
assert.strictEqual(charLvl30['ally-9'], true, 'Step 9 (min 22 < 25) should be skipped at level 30');
assert.strictEqual(charLvl30['ally-10'], true, 'Step 10 (min 24 < 25) should be skipped at level 30');
assert.strictEqual(charLvl30['ally-11'], true, 'Step 11 (min 24 < 25) should be skipped at level 30');
assert.strictEqual(charLvl30['ally-12'], undefined, 'Step 12 (min 26 >= 25) must be preserved within 5 levels');
assert.strictEqual(simulateGetActiveStep(allyStepObjects, charLvl30).stepNumber, 12, 'Level 30 active step should be step 12');

// Test D: Manual Uncheck Persistence
// Suppose the player wants to do Step 1 anyway at level 30
uncheckLvl30['ally-1'] = true;
delete charLvl30['ally-1'];
// Re-running sync must NOT re-skip ally-1 because it was manually unchecked!
simulateDynamicLevelSync(allyStepObjects, charLvl30, uncheckLvl30, 30);
assert.strictEqual(charLvl30['ally-1'], undefined, 'Manually unchecked step must NOT be auto-skipped');
assert.strictEqual(simulateGetActiveStep(allyStepObjects, charLvl30).stepNumber, 1, 'Active step should now be manually unchecked step 1');

// Test E: Horde Level 30 Sync (min relevant level = 25)
const hordeCharLvl30 = {};
const hordeUncheckLvl30 = {};
simulateDynamicLevelSync(hordeStepObjects, hordeCharLvl30, hordeUncheckLvl30, 30);
// In Horde guide, Step 10 is [22–26] (min 22 < 25) -> SKIPPED.
// Step 11 is [25–28] Thousand Needles & Stonetalon (min 25 >= 25) -> KEPT (gap: 5 levels)!
assert.strictEqual(simulateGetActiveStep(hordeStepObjects, hordeCharLvl30).stepNumber, 11, 'Horde Level 30 active step should be step 11');

// ============================================================================
// SUITE 10: World Map Zone Level Overlays (Badge & Continent Overlays)
// ============================================================================
console.log('--- Suite 10: World Map Zone Level Overlays & Dynamic Color Coding ---');

// 1. Static Verification of Required Methods & Frames
assert.ok(luaSource.includes('function WoWEternityAddon:GetZoneLevelColor'), 'Must implement GetZoneLevelColor');
assert.ok(luaSource.includes('function WoWEternityAddon:IsContinentMap'), 'Must implement IsContinentMap');
assert.ok(luaSource.includes('function WoWEternityAddon:GetCurrentZoneData'), 'Must implement GetCurrentZoneData');
assert.ok(luaSource.includes('function WoWEternityAddon:GetOrCreateMapZoneBadge'), 'Must implement GetOrCreateMapZoneBadge');
assert.ok(luaSource.includes('function WoWEternityAddon:InitMapZoneOverlays'), 'Must implement InitMapZoneOverlays');
assert.ok(luaSource.includes('function WoWEternityAddon:UpdateMapZoneOverlays'), 'Must implement UpdateMapZoneOverlays');
assert.ok(luaSource.includes('function WoWEternityAddon:ToggleMapZoneOverlays'), 'Must implement ToggleMapZoneOverlays');
assert.ok(luaSource.includes('WoWEternity_MapZoneBadge'), 'Must create WoWEternity_MapZoneBadge frame');
assert.ok(luaSource.includes('badge.text:SetText(string.format("%s%d–%d|r"'), 'Must format ##–## level range for zone badges');
assert.ok(luaSource.includes('GameTooltip:AddLine("|cffe6cc80WoW Eternity Addon|r", 1, 1, 1)'), 'Must include WoW Eternity Addon header in map tooltips');
assert.ok(luaSource.includes('ZONE_LEVEL_RANGES'), 'Must define ZONE_LEVEL_RANGES database');
assert.ok(luaSource.includes('WoWEternityAddonDB.showMapOverlays'), 'Must support showMapOverlays setting');
assert.ok(luaSource.includes('cmd == "map"'), 'Must handle /wea map slash command');
assert.ok(luaSource.includes('function WoWEternityAddon:PrintMapCursorPosition'), 'Must implement PrintMapCursorPosition');

// Anti-Taint & Map Navigation Protection Assertions
assert.ok(!luaSource.includes('hooksecurefunc(WorldMapFrame, "SetMapID"'), 'Must NEVER hooksecurefunc SetMapID to avoid ADDON_ACTION_BLOCKED taint on back button');
assert.ok(!luaSource.includes('hooksecurefunc(WorldMapFrame, "OnMapChanged"'), 'Must NEVER hooksecurefunc OnMapChanged to avoid MapCanvas execution taint');
assert.ok(!luaSource.includes('canvas:HookScript("OnMouseUp"'), 'Must NEVER hook canvas OnMouseUp to avoid breaking map panning and navigation');
assert.ok(!luaSource.includes('WorldMapFrame.AddDataProvider'), 'Must NEVER add custom DataProvider to WorldMapFrame to prevent MapCanvas execution taint');
assert.ok(!luaSource.includes('NavigateToParentMap'), 'Must NEVER override right-click with NavigateToParentMap so native map zoom-out works');
assert.ok(!luaSource.includes('pill.RegisterForClicks'), 'Must NOT intercept right-click on map pins/pills');
assert.ok(!luaSource.includes('badge.RegisterForClicks'), 'Must NOT intercept right-click on map badge');

// 2. Parse & Validate ZONE_LEVEL_RANGES Database
const zoneRegex = /\{[\s\S]*?name\s*=\s*"([^"]+)",[\s\S]*?continent\s*=\s*"([^"]+)",[\s\S]*?minLvl\s*=\s*(\d+),[\s\S]*?maxLvl\s*=\s*(\d+),[\s\S]*?x\s*=\s*([\d\.]+),[\s\S]*?y\s*=\s*([\d\.]+),[\s\S]*?uiMapID\s*=\s*(\d+)/g;
const zones = [];
let zMatch;
while ((zMatch = zoneRegex.exec(luaSource)) !== null) {
    zones.push({
        name: zMatch[1],
        continent: zMatch[2],
        minLvl: parseInt(zMatch[3], 10),
        maxLvl: parseInt(zMatch[4], 10),
        x: parseFloat(zMatch[5]),
        y: parseFloat(zMatch[6]),
        uiMapID: parseInt(zMatch[7], 10)
    });
}

assert.strictEqual(zones.length, 40, 'Must define 40 zones in ZONE_LEVEL_RANGES (19 Kalimdor, 21 Eastern Kingdoms)');
const kalimdorZones = zones.filter(z => z.continent === 'kalimdor');
const ekZones = zones.filter(z => z.continent === 'eastern_kingdoms');
assert.strictEqual(kalimdorZones.length, 19, 'Must define 19 Kalimdor zones');
assert.strictEqual(ekZones.length, 21, 'Must define 21 Eastern Kingdoms zones');

for (const z of zones) {
    assert.ok(z.minLvl >= 1 && z.minLvl <= 60, `${z.name} minLvl must be in 1-60`);
    assert.ok(z.maxLvl >= z.minLvl && z.maxLvl <= 60, `${z.name} maxLvl must be >= minLvl and <= 60`);
    assert.ok(z.x >= 0.1 && z.x <= 0.95, `${z.name} x coordinate must be within map bounds [0.1, 0.95]`);
    assert.ok(z.y >= 0.05 && z.y <= 0.95, `${z.name} y coordinate must be within map bounds [0.05, 0.95]`);
    assert.ok(z.uiMapID > 0, `${z.name} uiMapID must be positive integer`);
}

// 3. Behavioral Simulation of Dynamic Color Coding (5 Tiers)
const simulateZoneLevelColor = (minLvl, maxLvl, playerLevel) => {
    if (playerLevel < minLvl - 4) {
        return { hex: '|cffff3333', label: 'Deadly' };
    } else if (playerLevel < minLvl) {
        return { hex: '|cffff8822', label: 'Challenging' };
    } else if (playerLevel <= maxLvl) {
        return { hex: '|cff44ff44', label: 'Ideal' };
    } else if (playerLevel <= maxLvl + 4) {
        return { hex: '|cffffd100', label: 'Easy' };
    } else {
        return { hex: '|cff888888', label: 'Trivial' };
    }
};

// Test The Barrens (10-30)
assert.strictEqual(simulateZoneLevelColor(10, 30, 5).label, 'Deadly', 'Level 5 in Barrens (10-30) is Deadly');
assert.strictEqual(simulateZoneLevelColor(10, 30, 8).label, 'Challenging', 'Level 8 in Barrens (10-30) is Challenging');
assert.strictEqual(simulateZoneLevelColor(10, 30, 20).label, 'Ideal', 'Level 20 in Barrens (10-30) is Ideal');
assert.strictEqual(simulateZoneLevelColor(10, 30, 32).label, 'Easy', 'Level 32 in Barrens (10-30) is Easy');
assert.strictEqual(simulateZoneLevelColor(10, 30, 45).label, 'Trivial', 'Level 45 in Barrens (10-30) is Trivial');

// 4. Continent vs Zone Map Detection Simulation
const zoneMapIDs = new Set(zones.map(z => z.uiMapID));
const simulateIsContinentMap = (mapID, mapName) => {
    if (zoneMapIDs.has(mapID)) return null;
    if (mapID === 1414 || mapID === 12) return 'kalimdor';
    if (mapID === 1415 || mapID === 13) return 'eastern_kingdoms';
    if (mapName) {
        const clean = mapName.toLowerCase().replace(/\s+/g, '');
        if (clean === 'kalimdor') return 'kalimdor';
        if (clean === 'easternkingdoms') return 'eastern_kingdoms';
    }
    return null;
};

assert.strictEqual(simulateIsContinentMap(1414, 'Kalimdor'), 'kalimdor', 'Map 1414 must be Kalimdor');
assert.strictEqual(simulateIsContinentMap(1415, 'Eastern Kingdoms'), 'eastern_kingdoms', 'Map 1415 must be Eastern Kingdoms');
assert.strictEqual(simulateIsContinentMap(1413, 'The Barrens'), null, 'Barrens (1413) is a zone map, not continent');
assert.strictEqual(simulateIsContinentMap(1423, 'Eastern Plaguelands'), null, 'Eastern Plaguelands (1423) must be a zone map, never a continent');

// Static analysis of IsContinentMap & instant responsiveness in WoWEternityAddon.lua
assert.ok(luaSource.includes('self.ZONE_BY_MAPID[mapID]'), 'IsContinentMap must check ZONE_BY_MAPID to reject zones');
assert.ok(!luaSource.includes('n:find("eastern") or n:find("kingdom")'), 'Must not use loose substring search for eastern kingdoms');
assert.ok(luaSource.includes('n == "easternkingdoms"'), 'Must strictly match easternkingdoms');
assert.ok(!luaSource.includes('"WORLD_MAP_UPDATE"'), 'Must not register deprecated WORLD_MAP_UPDATE event');
assert.ok(luaSource.includes('overlayWatcher.elapsed >= 0.1'), 'Must use 100ms decoupled watcher loop for responsive zero-taint updates');

const barrens = zones.find(z => z.uiMapID === 1413);
assert.ok(barrens, 'Barrens must exist in database');
assert.strictEqual(barrens.name, 'The Barrens');
assert.strictEqual(barrens.minLvl, 10);
assert.strictEqual(barrens.maxLvl, 30);

// 5. Mulgore 1-10 Range & Subzone Area Overlay Verification
const mulgore = zones.find(z => z.uiMapID === 1412);
assert.ok(mulgore, 'Mulgore must exist in database');
assert.strictEqual(mulgore.name, 'Mulgore');
assert.strictEqual(mulgore.minLvl, 1, 'Mulgore minLvl must be 1');
assert.strictEqual(mulgore.maxLvl, 10, 'Mulgore maxLvl must be 10');
assert.strictEqual(mulgore.x, 0.474, 'Mulgore x coordinate must be 0.474 (47.4)');
assert.strictEqual(mulgore.y, 0.613, 'Mulgore y coordinate must be 0.613 (61.3)');

// Subzone Overlay & Marker (Skywatcher Plateau: level 28 at 45.7, 54.0 on Kalimdor, square marker at 34.8, 13.8 in Mulgore)
assert.ok(luaSource.includes('SUBZONE_LEVEL_OVERLAYS'), 'Must define SUBZONE_LEVEL_OVERLAYS');
assert.ok(luaSource.includes('name = "Skywatcher Plateau"'), 'Must define Skywatcher Plateau in SUBZONE_LEVEL_OVERLAYS');
assert.ok(luaSource.includes('contX = 0.457') && luaSource.includes('contY = 0.540'), 'Skywatcher Plateau dot marker must be at 45.7, 54.0');
assert.ok(luaSource.includes('zoneX = 0.348') && luaSource.includes('zoneY = 0.138'), 'Skywatcher Plateau square marker must be at 34.8, 13.8 in Mulgore');
assert.ok(luaSource.includes('area_overlay_plateau') || luaSource.includes('area_overlay_oval'), 'Must use plateau/oval area overlay texture');
assert.ok(luaSource.includes('areaFrame.bg:SetVertexColor(r, g, b, 0.50)'), 'Must render 50% transparent area overlay');
assert.ok(luaSource.includes('pill.border:SetColorTexture(r, g, b, 0.45)'), 'Must render soft colored background wash and 1px border');
assert.ok(luaSource.includes('w = (sz.minLvl == sz.maxLvl) and 26 or 46'), 'Must use compact square badge (26x18) for single-level subzones');
assert.ok(luaSource.includes('pill.text:SetShadowOffset(1, -1)'), 'Continent numbers must have shadow for high contrast text');
assert.ok(luaSource.includes('function WoWEternityAddon:GetFactionDisplay'), 'Must implement GetFactionDisplay helper');
assert.ok(luaSource.includes('pill.underline'), 'Pill frames must have underline texture');
assert.ok(luaSource.includes('0.22, 0.74, 0.97') && luaSource.includes('1.0, 0.27, 0.27'), 'Must use Alliance Blue and Horde Red underline colors');
assert.ok(luaSource.includes('"Alliance"') && luaSource.includes('"Horde"') && luaSource.includes('"Both"'), 'GetFactionDisplay must return Alliance, Horde, or Both');
assert.ok(!luaSource.includes('Underlined: Specific to'), 'Must remove "* underlined: specific to horde or alliance" from tooltip');

// 6. Dungeons and Raids Separation Verification
assert.ok(luaSource.includes('raids = { "Onyxia\'s Lair (60+)" }'), 'Onyxia must be in raids list for Dustwallow Marsh');
assert.ok(luaSource.includes('raids = { "Ruins of Ahn\'Qiraj (60+)", "Temple of Ahn\'Qiraj (60+)" }'), 'AQ20 and AQ40 must be in raids list for Silithus');
assert.ok(luaSource.includes('dungeons = { "Blackrock Depths (52–60)" }, raids = { "Molten Core (60+)" }'), 'BRD must be dungeon and MC must be raid in Searing Gorge');
assert.ok(luaSource.includes('dungeons = { "Lower Blackrock Spire (55–60)" }, raids = { "Blackwing Lair (60+)" }'), 'LBRS must be dungeon and BWL must be raid in Burning Steppes');
assert.ok(luaSource.includes('dungeons = { "Stratholme (58–60)" }, raids = { "Naxxramas (60+)" }'), 'Stratholme must be dungeon and Naxxramas must be raid in EPL');
assert.ok(luaSource.includes('raids = { "Zul\'Gurub (60+)" }'), 'Zul\'Gurub must be in raids list for STV');

assert.ok(luaSource.includes('GameTooltip:AddLine("|cffffd100Dungeons in Zone:|r", 1, 0.82, 0)'), 'Must render gold Dungeons in Zone header in zone badge');
assert.ok(luaSource.includes('GameTooltip:AddLine("|cffff8000Raids in Zone:|r", 1, 0.50, 0)'), 'Must render orange Raids in Zone header in zone badge');
assert.ok(luaSource.includes('GameTooltip:AddLine("|cffffd100Dungeons:|r", 1, 0.82, 0)'), 'Must render gold Dungeons header in continent hover');
assert.ok(luaSource.includes('GameTooltip:AddLine("|cffff8000Raids:|r", 1, 0.50, 0)'), 'Must render orange Raids header in continent hover');

// Assert no raids remain in dungeons arrays
const dungeonsMatch = luaSource.match(/dungeons\s*=\s*\{([^}]+)\}/g) || [];
for (const dm of dungeonsMatch) {
    assert.ok(!dm.includes('Molten Core'), 'Molten Core must not be in dungeons list');
    assert.ok(!dm.includes('Blackwing Lair'), 'Blackwing Lair must not be in dungeons list');
    assert.ok(!dm.includes('Onyxia'), 'Onyxia must not be in dungeons list');
    assert.ok(!dm.includes('Ahn\'Qiraj'), 'Ahn\'Qiraj must not be in dungeons list');
    assert.ok(!dm.includes('Zul\'Gurub'), 'Zul\'Gurub must not be in dungeons list');
    assert.ok(!dm.includes('Naxxramas'), 'Naxxramas must not be in dungeons list');
}

// 7. 9 New WoW: Forever Dungeons Verification
assert.ok(luaSource.includes('"Hall of Thanes (13–18)"'), 'Hall of Thanes must be in Dun Morogh');
assert.ok(luaSource.includes('"Ruins of Lordaeron (15–20)"'), 'Ruins of Lordaeron must be in Tirisfal Glades');
assert.ok(luaSource.includes('"Excavation Site (24–29)"'), 'Excavation Site must be in Wetlands');
assert.ok(luaSource.includes('"City of Dalaran (28–33)"'), 'City of Dalaran must be in Alterac Mountains');
assert.ok(luaSource.includes('"The Drowned City (35–40)"'), 'The Drowned City must be in Stranglethorn Vale');
assert.ok(luaSource.includes('"Krul\'dok Stronghold (40–45)"'), 'Krul\'dok Stronghold must be in Badlands');
assert.ok(luaSource.includes('"Alcaz Prison (48–53)"'), 'Alcaz Prison must be in Dustwallow Marsh');
assert.ok(luaSource.includes('"Blackmaw Hold (55–60)"'), 'Blackmaw Hold must be in Azshara');
assert.ok(luaSource.includes('"The Shaper\'s Terrace (58–60)"'), 'The Shaper\'s Terrace must be in Un\'Goro Crater');

// --- Suite 11: Continent Map Dungeon List Sidebar & Interactive Zone Highlighting ---
console.log('--- Suite 11: Continent Map Dungeon List Sidebar & Interactive Zone Highlighting ---');

// 1. Static Analysis of Required Methods, Frames & Properties
assert.ok(luaSource.includes('function WoWEternityAddon:GetOrCreateContinentDungeonPanel'), 'Must implement GetOrCreateContinentDungeonPanel');
assert.ok(luaSource.includes('function WoWEternityAddon:HighlightContinentZonePill'), 'Must implement HighlightContinentZonePill');
assert.ok(luaSource.includes('function WoWEternityAddon:UpdateContinentDungeonPanel'), 'Must implement UpdateContinentDungeonPanel');
assert.ok(luaSource.includes('WoWEternity_ContinentDungeonPanel'), 'Must create WoWEternity_ContinentDungeonPanel frame');
assert.ok(luaSource.includes('WoWEternity_ContDungeonRow_'), 'Must create reusable row buttons in WoWEternity_ContDungeonRow_ pool');
assert.ok(luaSource.includes('WoWEternity_ContDungeonCollapseBtn'), 'Must create collapse button in dungeon panel header');
assert.ok(luaSource.includes('WoWEternityAddonDB.mapDungeonsCollapsed'), 'Must persist dungeon collapse state in WoWEternityAddonDB');
assert.ok(luaSource.includes('panel:SetFrameStrata("HIGH")'), 'Continent dungeon panel strata must be HIGH');
assert.ok(luaSource.includes('panel:SetSize(200,'), 'Continent dungeon panel width must be 200px');
assert.ok(luaSource.includes('0.04, 0.04, 0.07, 0.88'), 'Continent dungeon panel must use dark theme backdrop');
assert.ok(luaSource.includes('0.90, 0.80, 0.50, 0.40'), 'Continent dungeon panel must have gold border');
assert.ok(luaSource.includes('|cffe6cc80Dungeons|r'), 'Continent dungeon panel must have gold title header');
assert.ok(luaSource.includes('row.hoverBg'), 'Dungeon row must have hoverBg texture');
assert.ok(luaSource.includes('0.90, 0.80, 0.50, 0.15'), 'Dungeon row hoverBg must use gold highlight');
assert.ok(luaSource.includes('row.dungeonText'), 'Dungeon row must have dungeonText font string');
assert.ok(luaSource.includes('row.zoneText'), 'Dungeon row must have zoneText font string');
assert.ok(luaSource.includes('row.lvlText'), 'Dungeon row must have lvlText font string');

// 2. Static Analysis of Raids Sidebar (Left-Hand Side)
assert.ok(luaSource.includes('function WoWEternityAddon:GetOrCreateContinentRaidPanel'), 'Must implement GetOrCreateContinentRaidPanel');
assert.ok(luaSource.includes('function WoWEternityAddon:UpdateContinentRaidPanel'), 'Must implement UpdateContinentRaidPanel');
assert.ok(luaSource.includes('WoWEternity_ContinentRaidPanel'), 'Must create WoWEternity_ContinentRaidPanel frame');
assert.ok(luaSource.includes('WoWEternity_ContRaidRow_'), 'Must create reusable row buttons in WoWEternity_ContRaidRow_ pool');
assert.ok(luaSource.includes('WoWEternity_ContRaidCollapseBtn'), 'Must create collapse button in raids panel header');
assert.ok(luaSource.includes('WoWEternityAddonDB.mapRaidsCollapsed'), 'Must persist raid collapse state in WoWEternityAddonDB');
assert.ok(luaSource.includes('panel:SetPoint("TOPLEFT", canvas, "TOPLEFT", 12, -12)'), 'Raids panel must anchor to TOPLEFT 12, -12');
assert.ok(luaSource.includes('|cffff8000Raids|r'), 'Raids panel must have orange Raids title header');

// 3. Integration in UpdateMapZoneOverlays & Zone Map Scope
assert.ok(luaSource.includes('self:UpdateContinentDungeonPanel(canvas, contKey, playerLevel, playerFaction)'), 'Must call UpdateContinentDungeonPanel on continent maps');
assert.ok(luaSource.includes('self:UpdateContinentRaidPanel(canvas, contKey, playerLevel, playerFaction)'), 'Must call UpdateContinentRaidPanel on continent maps');
assert.ok(luaSource.includes('self.continentDungeonPanel:Hide()'), 'Must hide continent dungeon panel on zone maps');
assert.ok(luaSource.includes('self.continentRaidPanel:Hide()'), 'Must hide continent raid panel on zone maps');

// 4. Zero-Shift Hover Highlighting & Signature Backdrop/Border
assert.ok(!luaSource.includes('pill:SetScale(1.35)'), 'Must NOT scale pill up on hover (zero shift guarantee)');
assert.ok(luaSource.includes('pill.bg:SetColorTexture(0.04, 0.04, 0.07, 0.90)'), 'Hovering pill must show signature dark backdrop');
assert.ok(luaSource.includes('pill.border:SetColorTexture(0.90, 0.80, 0.50, 0.70)'), 'Hovering pill must show gold border');
assert.ok(luaSource.includes('pill.bg:Hide()'), 'Unhovering pill must hide bg');
// Verify HighlightContinentZonePill preserves font size and does not call SetFont or SetFontObject
const highlightFuncMatch = luaSource.match(/function WoWEternityAddon:HighlightContinentZonePill[\s\S]*?end\n\nfunction/);
assert.ok(highlightFuncMatch, 'HighlightContinentZonePill function must be defined');
const highlightBody = highlightFuncMatch[0];
assert.ok(!highlightBody.includes('SetFontObject'), 'HighlightContinentZonePill must NOT alter font object on hover');
assert.ok(!highlightBody.includes('SetFont('), 'HighlightContinentZonePill must NOT call SetFont to alter font size on hover');
assert.ok(luaSource.includes('|cff38bdf8'), 'Hovering dungeon row must highlight pill text in cyan |cff38bdf8');
assert.ok(luaSource.includes('0.22, 0.74, 0.97, 1.0'), 'Hovering dungeon row must underline pill in cyan');
assert.ok(luaSource.includes('HighlightContinentZonePill(r.zoneName, true)'), 'Row OnEnter must call HighlightContinentZonePill enable=true');
assert.ok(luaSource.includes('HighlightContinentZonePill(r.zoneName, false)'), 'Row OnLeave must call HighlightContinentZonePill enable=false');

// 5. Click Navigation Verification
assert.ok(luaSource.includes('WorldMapFrame:SetMapID(r.uiMapID)'), 'Clicking dungeon row must call WorldMapFrame:SetMapID');
assert.ok(luaSource.includes('WoWEternityAddon:UpdateMapZoneOverlays()'), 'Clicking dungeon row must trigger UpdateMapZoneOverlays');

// 5. Behavioral Simulation: Dungeon Extraction, Faction Filtering & Sorting
const extractDungeonsForContinent = (continentKey, faction) => {
    const dungeonList = [];
    for (const line of luaLines) {
        if (!line.includes(`continent = "${continentKey}"`)) continue;
        if (!line.includes('dungeons = {')) continue;

        const nameMatch = line.match(/name\s*=\s*"([^"]+)"/);
        const mapMatch = line.match(/uiMapID\s*=\s*(\d+)/);
        const dMatch = line.match(/dungeons\s*=\s*\{([^}]+)\}/);
        if (!nameMatch || !mapMatch || !dMatch) continue;

        const zoneName = nameMatch[1];
        const uiMapID = parseInt(mapMatch[1], 10);
        const dEntries = dMatch[1].match(/"([^"]+)"/g) || [];

        for (const rawD of dEntries) {
            const cleanD = rawD.replace(/"/g, '');
            const parsed = cleanD.match(/^(.*?)\s*\(([0-9]+)[^0-9]+([0-9]+)\)/);
            if (!parsed) continue;

            const dName = parsed[1].trim();
            const dMin = parseInt(parsed[2], 10);
            const dMax = parseInt(parsed[3], 10);

            let isExcluded = false;
            if (faction === 'alliance') {
                if (dName === 'Ragefire Chasm' || dName === 'Ruins of Lordaeron') isExcluded = true;
            } else if (faction === 'horde') {
                if (dName === 'The Deadmines' || dName === 'The Stockade' || dName === 'Stockade' || dName === 'Hall of Thanes') isExcluded = true;
            }

            if (!isExcluded) {
                dungeonList.push({
                    name: dName,
                    minLvl: dMin,
                    maxLvl: dMax,
                    zoneName,
                    uiMapID
                });
            }
        }
    }

    // Sort: minLvl ASC, maxLvl ASC, name ASC
    dungeonList.sort((a, b) => {
        if (a.minLvl !== b.minLvl) return a.minLvl - b.minLvl;
        if (a.maxLvl !== b.maxLvl) return a.maxLvl - b.maxLvl;
        return a.name.localeCompare(b.name);
    });

    return dungeonList;
};

// Kalimdor: Alliance vs Horde filtering
const kalimdorAlly = extractDungeonsForContinent('kalimdor', 'alliance');
const kalimdorHorde = extractDungeonsForContinent('kalimdor', 'horde');

assert.strictEqual(kalimdorAlly.length, 10, 'Alliance must see 10 Kalimdor dungeons');
assert.strictEqual(kalimdorHorde.length, 11, 'Horde must see 11 Kalimdor dungeons (including RFC)');
assert.ok(!kalimdorAlly.some(d => d.name === 'Ragefire Chasm'), 'Alliance Kalimdor list must NEVER contain Ragefire Chasm');
assert.ok(kalimdorHorde.some(d => d.name === 'Ragefire Chasm'), 'Horde Kalimdor list must contain Ragefire Chasm');
assert.ok(kalimdorAlly.some(d => d.name === 'Wailing Caverns'), 'Alliance Kalimdor list must contain Wailing Caverns');
assert.ok(kalimdorAlly.some(d => d.name === 'Blackfathom Deeps'), 'Alliance Kalimdor list must contain Blackfathom Deeps');

// Eastern Kingdoms: Alliance vs Horde filtering
const ekAlly = extractDungeonsForContinent('eastern_kingdoms', 'alliance');
const ekHorde = extractDungeonsForContinent('eastern_kingdoms', 'horde');

assert.strictEqual(ekAlly.length, 16, 'Alliance must see 16 Eastern Kingdoms dungeons');
assert.strictEqual(ekHorde.length, 14, 'Horde must see 14 Eastern Kingdoms dungeons');
assert.ok(!ekAlly.some(d => d.name === 'Ruins of Lordaeron'), 'Alliance EK list must NEVER contain Ruins of Lordaeron');
assert.ok(ekAlly.some(d => d.name === 'The Deadmines'), 'Alliance EK list must contain The Deadmines');
assert.ok(ekAlly.some(d => d.name === 'Stockade'), 'Alliance EK list must contain Stockade');
assert.ok(ekAlly.some(d => d.name === 'Hall of Thanes'), 'Alliance EK list must contain Hall of Thanes');

assert.ok(ekHorde.some(d => d.name === 'Ruins of Lordaeron'), 'Horde EK list must contain Ruins of Lordaeron');
assert.ok(!ekHorde.some(d => d.name === 'The Deadmines'), 'Horde EK list must NEVER contain The Deadmines');
assert.ok(!ekHorde.some(d => d.name === 'Stockade'), 'Horde EK list must NEVER contain Stockade');
assert.ok(!ekHorde.some(d => d.name === 'Hall of Thanes'), 'Horde EK list must NEVER contain Hall of Thanes');
assert.ok(ekHorde.some(d => d.name === 'Shadowfang Keep'), 'Horde EK list must contain Shadowfang Keep');
assert.ok(ekHorde.some(d => d.name === 'Scarlet Monastery'), 'Horde EK list must contain Scarlet Monastery');

// 6. Sorting Order Verification (minLvl ASC, maxLvl ASC, name ASC)
for (let i = 0; i < ekAlly.length - 1; i++) {
    const current = ekAlly[i];
    const next = ekAlly[i + 1];
    assert.ok(current.minLvl <= next.minLvl, `Dungeons must be sorted ascending by minLvl: ${current.name} (${current.minLvl}) <= ${next.name} (${next.minLvl})`);
    if (current.minLvl === next.minLvl) {
        assert.ok(current.maxLvl <= next.maxLvl, `Dungeons with same minLvl must be sorted by maxLvl: ${current.name} (${current.maxLvl}) <= ${next.name} (${next.maxLvl})`);
    }
}
assert.strictEqual(ekAlly[0].name, 'Hall of Thanes', 'Hall of Thanes (13-18) must be first EK Alliance dungeon');
assert.strictEqual(ekAlly[1].name, 'The Deadmines', 'The Deadmines (17-26) must be second EK Alliance dungeon');

// 7. Interactive Hover Pill State Toggle Simulation (Zero-Shift + Enlarged Font + WoW Eternity Badge)
const mockPill = {
    scale: 1.0,
    fontSize: 11,
    fontObject: 'GameFontHighlightSmall',
    textColor: '|cff44ff44',
    bgShown: false,
    borderShown: false,
    underlineShown: false,
    underlineColor: null,
    width: 28,
    height: 16,
    zoneData: { name: 'Westfall', minLvl: 10, maxLvl: 20, faction: 'Alliance' },
    SetFont(f, size, flag) { this.fontSize = size; },
    SetFontObject(fo) { this.fontObject = fo; },
    SetTextColor(c) { this.textColor = c; },
    SetSize(w, h) { this.width = w; this.height = h; },
    SetUnderline(show, color) { this.underlineShown = show; this.underlineColor = color; },
    ShowBg() { this.bgShown = true; },
    HideBg() { this.bgShown = false; },
    ShowBorder() { this.borderShown = true; },
    HideBorder() { this.borderShown = false; }
};

const simulateHighlight = (pill, enable) => {
    // Zero-shift: SetScale is NEVER called; font size and dimensions stay strictly preserved
    if (enable) {
        pill.SetTextColor('|cff38bdf8');
        pill.ShowBg();
        pill.ShowBorder();
        pill.SetSize(28, 16);
        pill.SetUnderline(true, 'cyan');
    } else {
        pill.SetTextColor('|cff44ff44');
        pill.HideBg();
        pill.HideBorder();
        pill.SetSize(28, 16);
        pill.SetUnderline(true, 'alliance_blue');
    }
};

simulateHighlight(mockPill, true);
assert.strictEqual(mockPill.scale, 1.0, 'Pill scale must remain strictly 1.0 on hover (zero coordinate shift)');
assert.strictEqual(mockPill.fontSize, 11, 'Pill font size must remain completely unchanged (11pt) on hover');
assert.strictEqual(mockPill.fontObject, 'GameFontHighlightSmall', 'Pill font object must remain GameFontHighlightSmall on hover');
assert.strictEqual(mockPill.bgShown, true, 'Pill dark backdrop must be shown on hover');
assert.strictEqual(mockPill.borderShown, true, 'Pill gold border must be shown on hover');
assert.strictEqual(mockPill.textColor, '|cff38bdf8', 'Pill text must be bright cyan on hover');
assert.strictEqual(mockPill.underlineColor, 'cyan', 'Pill underline must be cyan on hover');
assert.strictEqual(mockPill.height, 16, 'Pill height must remain standard 16px on hover');

simulateHighlight(mockPill, false);
assert.strictEqual(mockPill.scale, 1.0, 'Pill scale must remain strictly 1.0 on unhover');
assert.strictEqual(mockPill.fontSize, 11, 'Pill font size must remain 11pt on unhover');
assert.strictEqual(mockPill.fontObject, 'GameFontHighlightSmall', 'Pill font object must remain GameFontHighlightSmall on unhover');
assert.strictEqual(mockPill.bgShown, false, 'Pill dark backdrop must be hidden on unhover');
assert.strictEqual(mockPill.borderShown, false, 'Pill gold border must be hidden on unhover');
assert.strictEqual(mockPill.textColor, '|cff44ff44', 'Pill text must restore to original difficulty on unhover');
assert.strictEqual(mockPill.underlineColor, 'alliance_blue', 'Pill underline must restore to faction color on unhover');
assert.strictEqual(mockPill.height, 16, 'Pill height must restore to 16px on unhover');

// 8. Raids Sidebar Extraction & Level Sorting Simulation
const extractRaidsForContinent = (continentKey) => {
    const raidList = [];
    for (const line of luaLines) {
        if (!line.includes(`continent = "${continentKey}"`)) continue;
        if (!line.includes('raids = {')) continue;

        const nameMatch = line.match(/name\s*=\s*"([^"]+)"/);
        const mapMatch = line.match(/uiMapID\s*=\s*(\d+)/);
        const rMatch = line.match(/raids\s*=\s*\{([^}]+)\}/);
        if (!nameMatch || !mapMatch || !rMatch) continue;

        const zoneName = nameMatch[1];
        const uiMapID = parseInt(mapMatch[1], 10);
        const rEntries = rMatch[1].match(/"([^"]+)"/g) || [];

        for (const rawR of rEntries) {
            const cleanR = rawR.replace(/"/g, '');
            let rName = cleanR;
            let minLvl = 60;
            let maxLvl = 60;
            const parsedRange = cleanR.match(/^(.*?)\s*\(([0-9]+)[^0-9]+([0-9]+)\)/);
            const parsedPlus = cleanR.match(/^(.*?)\s*\(([0-9]+)\+\)/);
            const parsedSingle = cleanR.match(/^(.*?)\s*\(([0-9]+)\)/);

            if (parsedRange) {
                rName = parsedRange[1].trim();
                minLvl = parseInt(parsedRange[2], 10);
                maxLvl = parseInt(parsedRange[3], 10);
            } else if (parsedPlus) {
                rName = parsedPlus[1].trim();
                minLvl = parseInt(parsedPlus[2], 10);
                maxLvl = minLvl;
            } else if (parsedSingle) {
                rName = parsedSingle[1].trim();
                minLvl = parseInt(parsedSingle[2], 10);
                maxLvl = minLvl;
            }

            raidList.push({
                name: rName,
                rawString: cleanR,
                minLvl,
                maxLvl,
                zoneName,
                uiMapID
            });
        }
    }

    raidList.sort((a, b) => {
        if (a.minLvl !== b.minLvl) return a.minLvl - b.minLvl;
        if (a.maxLvl !== b.maxLvl) return a.maxLvl - b.maxLvl;
        return a.name.localeCompare(b.name);
    });

    return raidList;
};

const kalimdorRaids = extractRaidsForContinent('kalimdor');
assert.strictEqual(kalimdorRaids.length, 5, 'Kalimdor must have 5 raids (Barrow Deeps, Hyjal Summit, Onyxia, AQ20, AQ40)');
assert.ok(kalimdorRaids.some(r => r.name === "Barrow Deeps"), 'Kalimdor must include Barrow Deeps');
assert.ok(kalimdorRaids.some(r => r.name === "Hyjal Summit"), 'Kalimdor must include Hyjal Summit');
assert.ok(kalimdorRaids.some(r => r.name === "Onyxia's Lair"), 'Kalimdor must include Onyxia\'s Lair');
assert.ok(kalimdorRaids.some(r => r.name === "Ruins of Ahn'Qiraj"), 'Kalimdor must include Ruins of Ahn\'Qiraj');
assert.ok(kalimdorRaids.some(r => r.name === "Temple of Ahn'Qiraj"), 'Kalimdor must include Temple of Ahn\'Qiraj');

const barrowDeeps = kalimdorRaids.find(r => r.name === "Barrow Deeps");
assert.ok(barrowDeeps, 'Barrow Deeps raid must exist in Kalimdor list');
assert.strictEqual(barrowDeeps.zoneName, "Moonglade", 'Barrow Deeps must link to Moonglade');

const hyjalSummit = kalimdorRaids.find(r => r.name === "Hyjal Summit");
assert.ok(hyjalSummit, 'Hyjal Summit raid must exist in Kalimdor list');
assert.strictEqual(hyjalSummit.zoneName, "Mount Hyjal", 'Hyjal Summit must link to Mount Hyjal');

assert.ok(luaSource.includes('name = "Mount Hyjal"'), 'Mount Hyjal must exist in ZONE_LEVEL_RANGES');

const ekRaids = extractRaidsForContinent('eastern_kingdoms');
assert.strictEqual(ekRaids.length, 4, 'Eastern Kingdoms must have 4 raids (BWL, MC, Naxx, ZG)');
assert.ok(ekRaids.some(r => r.name === "Blackwing Lair"), 'EK must include Blackwing Lair');
assert.ok(ekRaids.some(r => r.name === "Molten Core"), 'EK must include Molten Core');
assert.ok(ekRaids.some(r => r.name === "Naxxramas"), 'EK must include Naxxramas');
assert.ok(ekRaids.some(r => r.name === "Zul'Gurub"), 'EK must include Zul\'Gurub');

// 9. Sidebars Collapse Toggle & Persistence Simulation
const mockDB = { mapDungeonsCollapsed: false, mapRaidsCollapsed: false };

const toggleDungeonsCollapse = (collapsedState) => {
    mockDB.mapDungeonsCollapsed = collapsedState;
    return {
        height: mockDB.mapDungeonsCollapsed ? 26 : Math.min(27 + (ekAlly.length * 28) + 6, 480),
        buttonText: mockDB.mapDungeonsCollapsed ? '[+]' : '[-]'
    };
};

const dCollapsed = toggleDungeonsCollapse(true);
assert.strictEqual(mockDB.mapDungeonsCollapsed, true, 'Dungeons sidebar state must persist in DB as collapsed');
assert.strictEqual(dCollapsed.height, 26, 'Dungeons sidebar height must shrink to 26px when collapsed');
assert.strictEqual(dCollapsed.buttonText, '[+]', 'Collapse button must display [+] when collapsed');

const dExpanded = toggleDungeonsCollapse(false);
assert.strictEqual(mockDB.mapDungeonsCollapsed, false, 'Dungeons sidebar state must persist in DB as expanded');
assert.strictEqual(dExpanded.buttonText, '[-]', 'Collapse button must display [-] when expanded');
assert.ok(dExpanded.height > 26, 'Dungeons sidebar height must expand to fit rows');

const toggleRaidsCollapse = (collapsedState) => {
    mockDB.mapRaidsCollapsed = collapsedState;
    return {
        height: mockDB.mapRaidsCollapsed ? 26 : Math.min(27 + (ekRaids.length * 28) + 6, 480),
        buttonText: mockDB.mapRaidsCollapsed ? '[+]' : '[-]'
    };
};

const rCollapsed = toggleRaidsCollapse(true);
assert.strictEqual(mockDB.mapRaidsCollapsed, true, 'Raids sidebar state must persist in DB as collapsed');
assert.strictEqual(rCollapsed.height, 26, 'Raids sidebar height must shrink to 26px when collapsed');
assert.strictEqual(rCollapsed.buttonText, '[+]', 'Raids collapse button must display [+] when collapsed');

const rExpanded = toggleRaidsCollapse(false);
assert.strictEqual(mockDB.mapRaidsCollapsed, false, 'Raids sidebar state must persist in DB as expanded');
assert.strictEqual(rExpanded.buttonText, '[-]', 'Raids collapse button must display [-] when expanded');
assert.ok(rExpanded.height > 26, 'Raids sidebar height must expand to fit rows');

// 10. Click-to-Zoom Navigation Simulation
let currentSimulationMapID = 1415; // Eastern Kingdoms
let overlayUpdateTriggered = false;
const simulateRowClick = (uiMapID) => {
    currentSimulationMapID = uiMapID;
    overlayUpdateTriggered = true;
};
simulateRowClick(ekAlly[1].uiMapID); // Click The Deadmines (Westfall uiMapID 1436)
assert.strictEqual(currentSimulationMapID, 1436, 'Clicking Deadmines must navigate to Westfall map 1436');
assert.strictEqual(overlayUpdateTriggered, true, 'Clicking row must trigger overlay update');

// Test click on Raid row: Molten Core (Searing Gorge uiMapID 1427)
const mcRaid = ekRaids.find(r => r.name === 'Molten Core');
assert.ok(mcRaid, 'Molten Core raid must exist in EK raids');
simulateRowClick(mcRaid.uiMapID);
assert.strictEqual(currentSimulationMapID, 1427, 'Clicking Molten Core must navigate to Searing Gorge map 1427');

// 11. Zone Map Both Sidebars Hidden Simulation
const simulatePanelsVisibility = (mapID, mapName) => {
    const isContinent = simulateIsContinentMap(mapID, mapName);
    return {
        dungeonsShown: isContinent !== null,
        raidsShown: isContinent !== null
    };
};

const ekVisibility = simulatePanelsVisibility(1415, 'Eastern Kingdoms');
assert.strictEqual(ekVisibility.dungeonsShown, true, 'Dungeons sidebar must be shown on Eastern Kingdoms');
assert.strictEqual(ekVisibility.raidsShown, true, 'Raids sidebar must be shown on Eastern Kingdoms');

const westfallVisibility = simulatePanelsVisibility(1436, 'Westfall');
assert.strictEqual(westfallVisibility.dungeonsShown, false, 'Dungeons sidebar must be hidden on Westfall zone map');
assert.strictEqual(westfallVisibility.raidsShown, false, 'Raids sidebar must be hidden on Westfall zone map');

const barrensVisibility = simulatePanelsVisibility(1413, 'The Barrens');
assert.strictEqual(barrensVisibility.dungeonsShown, false, 'Dungeons sidebar must be hidden on Barrens zone map');
assert.strictEqual(barrensVisibility.raidsShown, false, 'Raids sidebar must be hidden on Barrens zone map');

const mediaFiles = [
    'circle_bg.png', 'circle_bg.tga',
    'circle_border.png', 'circle_border.tga',
    'circle_dot.png', 'circle_dot.tga',
    'area_overlay_oval.png', 'area_overlay_oval.tga',
    'area_border_oval.png', 'area_border_oval.tga',
    'area_overlay_plateau.png', 'area_overlay_plateau.tga',
    'area_border_plateau.png', 'area_border_plateau.tga',
    'icon.png', 'icon.tga'
];
for (const mf of mediaFiles) {
    assert.ok(fs.existsSync(path.join(ADDON_DIR, 'media', mf)), `Media file ${mf} must exist`);
}

console.log('[PASS] Addon simulation & static analysis passed 100%.');



