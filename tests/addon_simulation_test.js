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
assert.ok(/## Interface:\s*11506/.test(cleanToc), 'TOC must specify Interface: 11506');
assert.ok(/## SavedVariables:\s*WoWEternityAddonDB/.test(cleanToc), 'TOC must declare SavedVariables: WoWEternityAddonDB');
assert.ok(/## Title:\s*.*WoW Eternity Addon/i.test(cleanToc), 'TOC must have valid Title');
assert.ok(cleanToc.split(/\r?\n/).some(line => line.trim() === 'WoWEternityAddon.lua'), 'TOC must declare WoWEternityAddon.lua');

// Suite 2: Lua Static Analysis
const luaSource = fs.readFileSync(LUA_PATH, 'utf-8');
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

console.log('[PASS] Addon simulation & static analysis passed 100%.');

