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
assert.ok(luaSource.includes('cmd == "cursor"'), 'Must handle /wea cursor slash command');
assert.ok(luaSource.includes('function WoWEternityAddon:PrintMapCursorPosition'), 'Must implement PrintMapCursorPosition');

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

assert.strictEqual(zones.length, 39, 'Must define 39 zones in ZONE_LEVEL_RANGES (18 Kalimdor, 21 Eastern Kingdoms)');
const kalimdorZones = zones.filter(z => z.continent === 'kalimdor');
const ekZones = zones.filter(z => z.continent === 'eastern_kingdoms');
assert.strictEqual(kalimdorZones.length, 18, 'Must define 18 Kalimdor zones');
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
const simulateIsContinentMap = (mapID) => {
    if (mapID === 1414 || mapID === 12) return 'kalimdor';
    if (mapID === 1415 || mapID === 13) return 'eastern_kingdoms';
    return null;
};

assert.strictEqual(simulateIsContinentMap(1414), 'kalimdor', 'Map 1414 must be Kalimdor');
assert.strictEqual(simulateIsContinentMap(1415), 'eastern_kingdoms', 'Map 1415 must be Eastern Kingdoms');
assert.strictEqual(simulateIsContinentMap(1413), null, 'Barrens (1413) is a zone map, not continent');

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

// Subzone Overlay (Skywatcher Plateau: level 28 at 45.7, 54.0 on Kalimdor, 50% transparent area overlay in Mulgore)
assert.ok(luaSource.includes('SUBZONE_LEVEL_OVERLAYS'), 'Must define SUBZONE_LEVEL_OVERLAYS');
assert.ok(luaSource.includes('name = "Skywatcher Plateau"'), 'Must define Skywatcher Plateau in SUBZONE_LEVEL_OVERLAYS');
assert.ok(luaSource.includes('contX = 0.457') && luaSource.includes('contY = 0.540'), 'Skywatcher Plateau dot marker must be at 45.7, 54.0');
assert.ok(luaSource.includes('area_overlay_oval'), 'Must use area_overlay_oval texture');
assert.ok(luaSource.includes('areaFrame.bg:SetVertexColor(r, g, b, 0.50)'), 'Must render 50% transparent area overlay');
assert.ok(luaSource.includes('circleBorder:SetVertexColor'), 'Must dynamically tint circleBorder with level difficulty color');

const mediaFiles = [
    'circle_bg.png', 'circle_bg.tga',
    'circle_border.png', 'circle_border.tga',
    'circle_dot.png', 'circle_dot.tga',
    'area_overlay_oval.png', 'area_overlay_oval.tga',
    'area_border_oval.png', 'area_border_oval.tga',
    'icon.png', 'icon.tga'
];
for (const mf of mediaFiles) {
    assert.ok(fs.existsSync(path.join(ADDON_DIR, 'media', mf)), `Media file ${mf} must exist`);
}

console.log('[PASS] Addon simulation & static analysis passed 100%.');



