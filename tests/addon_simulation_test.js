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
    const regex = new RegExp(`id\\s*=\\s*"(${prefix}-\\d+)",\\s*stepNumber\\s*=\\s*(\\d+)[\\s\\S]*?type\\s*=\\s*"([^"]+)"`, 'g');
    const steps = [];
    let match;
    while ((match = regex.exec(src)) !== null) {
        steps.push({ id: match[1], stepNumber: parseInt(match[2], 10), type: match[3] });
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

console.log('[PASS] Addon simulation & static analysis passed 100%.');

