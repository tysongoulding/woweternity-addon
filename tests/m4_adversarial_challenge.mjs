/**
 * M4 Challenger 2 Adversarial Stress Test Harness
 * 
 * Target: woweternity-addon/WoWEternityAddon.lua
 * Validates:
 * 1. Mathematical parity between pure Lua ComputeAdler32 and Rust adler32 over:
 *    - Empty strings
 *    - 1,000 random strings of variable lengths
 *    - Unicode / multi-byte UTF-8 payloads (emojis, CJK, Cyrillic, accents)
 *    - Binary bytes (all 0x00-0xFF bytes, repeated nulls, alternating high bytes)
 *    - 100KB payloads (>18 chunk boundaries of MAX_CHUNK=5552)
 * 2. Corrupt payload detection on SavedVariables load (1-byte mutation emits chat warning).
 * 3. Rapid tooltip hover spam (1,000 hovers in < 5ms, PlaySound(888) debounced to exactly 1 call).
 * 4. Invalid / negative item IDs (0, -1, 999999999, nil, non-numeric) handled with zero errors.
 */

import { spawnSync, spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import assert from 'node:assert';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ADDON_DIR = path.resolve(__dirname, '..');
const LUA_FILE = path.join(ADDON_DIR, 'WoWEternityAddon.lua');

assert.ok(fs.existsSync(LUA_FILE), `WoWEternityAddon.lua must exist at ${LUA_FILE}`);

// RFC 1950 Reference Adler-32 implementation (identical chunking & modulo to Rust checksum.rs)
const MOD_ADLER = 65521;
const MAX_CHUNK = 5552;

function rustReferenceAdler32(buf) {
  let a = 1;
  let b = 0;
  for (let i = 0; i < buf.length; i += MAX_CHUNK) {
    const end = Math.min(i + MAX_CHUNK, buf.length);
    for (let j = i; j < end; j++) {
      a += buf[j];
      b += a;
    }
    a %= MOD_ADLER;
    b %= MOD_ADLER;
  }
  // Return unsigned 32-bit integer: (b << 16) | a
  return ((b * 65536) + a) >>> 0;
}

// Helper to spawn interactive Lua process for high-throughput batch Adler-32 queries
class LuaBatchClient {
  constructor() {
    const driverScript = `
dofile([=[${LUA_FILE.replace(/\\/g, '/')}]=])

local function fromHex(str)
  if not str or str == "" then return "" end
  return (str:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
end

while true do
  local line = io.read("*l")
  if not line or line == "QUIT" then break end
  local raw = fromHex(line)
  local cs = WoWEternityAddon:ComputeAdler32(raw)
  print(string.format("%.0f", cs))
  io.flush()
end
`;
    this.proc = spawn('lua', ['-e', driverScript], {
      stdio: ['pipe', 'pipe', 'inherit'],
    });

    this.stdoutBuffer = '';
    this.pendingResolvers = [];

    this.proc.stdout.on('data', (chunk) => {
      this.stdoutBuffer += chunk.toString('utf-8');
      const lines = this.stdoutBuffer.split(/\r?\n/);
      this.stdoutBuffer = lines.pop(); // Keep partial line
      for (const line of lines) {
        if (line.trim() !== '' && this.pendingResolvers.length > 0) {
          const resolve = this.pendingResolvers.shift();
          resolve(Number.parseInt(line.trim(), 10));
        }
      }
    });
  }

  compute(buffer) {
    return new Promise((resolve) => {
      this.pendingResolvers.push(resolve);
      const hexStr = buffer.toString('hex');
      this.proc.stdin.write(hexStr + '\n');
    });
  }

  close() {
    this.proc.stdin.write('QUIT\n');
    this.proc.stdin.end();
  }
}

async function runAdler32ParityTests() {
  console.log('--- Suite 1: Pure Lua vs Rust Adler-32 Checksum Parity ---');
  const luaClient = new LuaBatchClient();

  try {
    // 1. Empty string test
    const emptyBuf = Buffer.alloc(0);
    const emptyRust = rustReferenceAdler32(emptyBuf);
    const emptyLua = await luaClient.compute(emptyBuf);
    assert.strictEqual(emptyRust, 1, 'Rust Adler-32 of empty buffer must be 1');
    assert.strictEqual(emptyLua, 1, 'Lua Adler-32 of empty buffer must be 1');
    assert.strictEqual(emptyLua, emptyRust, 'Empty buffer checksum mismatch');
    console.log('  [PASS] Empty string parity: 1 == 1');

    // 2. RFC 1950 vectors
    const v1 = Buffer.from('123456789');
    const v1Rust = rustReferenceAdler32(v1);
    const v1Lua = await luaClient.compute(v1);
    assert.strictEqual(v1Rust, 152961502);
    assert.strictEqual(v1Lua, 152961502);
    console.log('  [PASS] RFC 1950 vector "123456789": 152961502 == 152961502');

    const v2 = Buffer.from('Wikipedia');
    const v2Rust = rustReferenceAdler32(v2);
    const v2Lua = await luaClient.compute(v2);
    assert.strictEqual(v2Rust, 300286872);
    assert.strictEqual(v2Lua, 300286872);
    console.log('  [PASS] RFC 1950 vector "Wikipedia": 300286872 == 300286872');

    // 3. 1,000 Random strings of variable lengths (1 to 2,048 bytes)
    console.log('  Testing 1,000 random byte payloads (1-2048 bytes)...');
    let mismatches = 0;
    const startTime = performance.now();
    for (let i = 1; i <= 1000; i++) {
      const len = (i * 37) % 2048 + 1;
      const randBuf = crypto.randomBytes(len);
      const expected = rustReferenceAdler32(randBuf);
      const actual = await luaClient.compute(randBuf);
      if (expected !== actual) {
        mismatches++;
        console.error(`  Mismatch on random string #${i} (len=${len}): expected=${expected}, actual=${actual}`);
      }
    }
    const elapsed = performance.now() - startTime;
    assert.strictEqual(mismatches, 0, 'Zero mismatches permitted across 1,000 random strings');
    console.log(`  [PASS] 1,000 random strings: 100% bit-for-bit parity in ${elapsed.toFixed(1)}ms (0 mismatches).`);

    // 4. Unicode / multi-byte UTF-8 payloads
    console.log('  Testing Unicode multi-byte UTF-8 payloads...');
    const unicodeCases = [
      'Hello, 世界! 🌍',
      '霜之哀伤: 12/12 N Heroic [Item: 19019]',
      'Красная Армия — ⚔️🛡️🔥',
      'WoW Classic: Season of Discovery ✨⚡',
      'مرحبا بالعالم - اللغة العربية',
      'Γειά σου Κόσμε - Ελληνικά',
      '🧙‍♂️🧝‍♀️🧟‍♂️🐉 100% Multi-byte UTF-8 Emoji Stream 🎮',
      'Cœur d\'ébène, épée maudite d\'Arthas Menethil',
      'Naglfar / Gjallarhorn: 99.9% parse rank — äöüßéèê',
    ];

    for (const [idx, str] of unicodeCases.entries()) {
      const buf = Buffer.from(str, 'utf-8');
      const expected = rustReferenceAdler32(buf);
      const actual = await luaClient.compute(buf);
      assert.strictEqual(actual, expected, `Unicode case ${idx} failed: "${str}"`);
    }
    console.log(`  [PASS] ${unicodeCases.length} Unicode & emoji test cases passed with 100% parity.`);

    // 5. Binary bytes (all 256 byte values, null bytes, high bytes)
    console.log('  Testing binary bytes and control codes (0x00 to 0xFF)...');
    // All 256 bytes
    const allBytes = Buffer.from(Array.from({ length: 256 }, (_, i) => i));
    assert.strictEqual(await luaClient.compute(allBytes), rustReferenceAdler32(allBytes));

    // Repeated null bytes
    const nulls = Buffer.alloc(4096, 0);
    assert.strictEqual(await luaClient.compute(nulls), rustReferenceAdler32(nulls));

    // Alternating null and 0xFF
    const alternating = Buffer.from(Array.from({ length: 2048 }, (_, i) => (i % 2 === 0 ? 0 : 255)));
    assert.strictEqual(await luaClient.compute(alternating), rustReferenceAdler32(alternating));

    // High bytes 0x80 - 0xFF
    const highBytes = Buffer.from(Array.from({ length: 4096 }, (_, i) => 128 + (i % 128)));
    assert.strictEqual(await luaClient.compute(highBytes), rustReferenceAdler32(highBytes));
    console.log('  [PASS] Binary bytes, null bytes, and high-byte streams passed with 100% parity.');

    // 6. 100KB payloads (>18 chunks of MAX_CHUNK=5552)
    console.log('  Testing 100KB payloads (>18 chunk boundaries)...');
    const uniform100k = Buffer.alloc(102400, 65); // 100KB of 'A'
    assert.strictEqual(await luaClient.compute(uniform100k), rustReferenceAdler32(uniform100k));

    const pattern100k = Buffer.from(Array.from({ length: 102400 }, (_, i) => i % 256));
    assert.strictEqual(await luaClient.compute(pattern100k), rustReferenceAdler32(pattern100k));

    const random128k = crypto.randomBytes(131072);
    assert.strictEqual(await luaClient.compute(random128k), rustReferenceAdler32(random128k));
    console.log('  [PASS] 100KB & 128KB large payloads verified (100% parity across chunk boundaries).');
  } finally {
    luaClient.close();
  }
}

function runHeadlessAddonLuaTests() {
  console.log('\n--- Suite 2: Corrupt Payload Detection & SavedVariables Ingestion ---');

  const luaScript = `
local chatMessages = {}
DEFAULT_CHAT_FRAME = {
    AddMessage = function(self, msg)
        table.insert(chatMessages, msg)
    end
}

dofile([=[${LUA_FILE.replace(/\\/g, '/') }]=])

-- Test 1: Valid SavedVariables database
WoWEternityAddonDB = {
    version = 1,
    checksum = 984434623,
    last_sync = 1726780800,
    players = {
        { name = "Arthas", realm = "Frostmourne", raid_progress = "12/12 N", parse_ranking = 98.4 },
    },
    items = {
        [17182] = { name = "Sulfuras", spec_id = "warrior_arms", source_type = "Default", is_custom = false },
        [19019] = { name = "Thunderfury", spec_id = "warrior_prot", source_type = "Custom Profile", is_custom = true },
    }
}

WoWEternityAddon:OnInitialize()
assert(WoWEternityAddon.isCorrupted == false, "Initial valid load must not be marked corrupted")
local validMsg = chatMessages[#chatMessages] or ""
assert(validMsg:find("Loaded successfully"), "Expected success message on valid load")
assert(validMsg:find("2 BiS items synchronized"), "Expected 2 BiS items reported")
print("  [PASS] Valid SavedVariables load: isCorrupted=false, chat='Loaded successfully'")

-- Test 2: Mutate 1 byte in items table (item name: Sulfuras -> Sulfurat)
WoWEternityAddonDB.items[17182].name = "Sulfurat"
WoWEternityAddon:OnInitialize()
assert(WoWEternityAddon.isCorrupted == true, "Mutated payload must set isCorrupted=true")
local corruptMsg = chatMessages[#chatMessages] or ""
assert(corruptMsg:find("WARNING: Database checksum mismatch or corrupt payload"), "Warning message expected on corrupt payload")
assert(corruptMsg:find("Declared: 984434623"), "Declared checksum should be in warning")
print("  [PASS] 1-byte mutated item name detected: isCorrupted=true, chat warning emitted")

-- Test 3: Mutate declared checksum
WoWEternityAddonDB.items[17182].name = "Sulfuras" -- restore name
WoWEternityAddonDB.checksum = 123456789 -- alter declared checksum
WoWEternityAddon:OnInitialize()
assert(WoWEternityAddon.isCorrupted == true, "Altered declared checksum must set isCorrupted=true")
local csMismatchMsg = chatMessages[#chatMessages] or ""
assert(csMismatchMsg:find("WARNING: Database checksum mismatch"), "Warning expected on checksum alteration")
print("  [PASS] Mutated declared checksum detected: isCorrupted=true, chat warning emitted")

print("\\n--- Suite 3: Rapid Tooltip Hover Spam Debounce & Performance ---")

local soundCalls = 0
local soundIds = {}
PlaySound = function(id)
    soundCalls = soundCalls + 1
    table.insert(soundIds, id)
end

local simulatedClock = 1000.0
GetTime = function()
    return simulatedClock
end

local capturedHandler = nil
GameTooltip = {
    HookScript = function(self, evt, handler)
        if evt == "OnTooltipSetItem" then capturedHandler = handler end
    end
}

-- Reload addon to bind GameTooltip hook
dofile([=[${LUA_FILE.replace(/\\/g, '/') }]=])

WoWEternityAddonDB = {
    version = 1,
    checksum = 984434623,
    last_sync = 1000,
    items = {
        [19019] = { name = "Thunderfury", spec_id = "warrior_prot", source_type = "Custom Profile", is_custom = true },
    }
}

local tooltipLines = {}
local mockTooltip = {
    GetItem = function(self)
        return "Thunderfury", "item:19019:0:0:0:0:0:0:0"
    end,
    AddLine = function(self, line)
        table.insert(tooltipLines, line)
    end,
    AddDoubleLine = function(self, left, right)
        table.insert(tooltipLines, left .. " " .. right)
    end,
    Show = function(self) end,
}

-- Simulate 1,000 consecutive tooltip hovers within 100ms
local tStart = os.clock()
for i = 1, 1000 do
    simulatedClock = 1000.0 + (i * 0.0001) -- total 100ms elapsed
    capturedHandler(mockTooltip)
end
local tTotalMs = (os.clock() - tStart) * 1000

assert(soundCalls == 1, string.format("PlaySound must be called exactly once during 1000 hovers (called %d times)", soundCalls))
assert(soundIds[1] == 888, string.format("Expected PlaySound(888), got %s", tostring(soundIds[1])))
assert(tTotalMs < 5.0, string.format("1000 hovers must execute in < 5ms (took %.3f ms)", tTotalMs))
print(string.format("  [PASS] Rapid hover spam: 1,000 hovers in %.3f ms (< 5ms limit), PlaySound(888) called exactly %d time", tTotalMs, soundCalls))

-- Verify debounce expires after 2.0s
simulatedClock = 1000.0 + 2.5 -- advance beyond 2-second debounce interval
capturedHandler(mockTooltip)
assert(soundCalls == 2, "PlaySound must trigger again after debounce interval has elapsed")
print("  [PASS] Debounce reset after 2.5s: PlaySound triggered second time as expected")

print("\\n--- Suite 4: Invalid and Negative Item IDs on Tooltip Hover ---")

local invalidCases = {
    { name = "Item ID 0", link = "item:0" },
    { name = "Item ID -1", link = "item:-1" },
    { name = "Huge non-existent ID 999999999", link = "item:999999999" },
    { name = "Nil link", link = nil },
    { name = "Non-numeric item ID", link = "item:not_a_number" },
    { name = "Empty string link", link = "" },
    { name = "Corrupt bracket link", link = "|cffffffff|Hitem:corrupt|h[]|h|r" },
    { name = "Nil tooltip", isNil = true },
    { name = "Bare tooltip (no GetItem)", isBare = true },
    { name = "GetItem returning nil, nil", returnNil = true },
}

for _, tc in ipairs(invalidCases) do
    local tt
    if tc.isNil then
        tt = nil
    elseif tc.isBare then
        tt = {}
    elseif tc.returnNil then
        tt = { GetItem = function() return nil, nil end }
    else
        tt = {
            GetItem = function() return "Item", tc.link end,
            AddLine = function() end,
            AddDoubleLine = function() end,
            Show = function() end,
        }
    end

    local ok, err = pcall(capturedHandler, tt)
    assert(ok, string.format("Hover failed on case '%s' with error: %s", tc.name, tostring(err)))
    print(string.format("  [PASS] Case '%s' handled cleanly without Lua script error", tc.name))
end

print("  [PASS] Zero Lua script errors across all invalid / negative item IDs.")

print("\\n--- Suite 5: Anti-Tamper Cryptographic HMAC-SHA256 & Player Verification ---")

-- Test 1: HMAC-SHA256 test vector validation
local testSig = WoWEternityAddon:ComputeHMACSHA256("woweternity-anti-tamper-v1-key", "arthas:frostmourne:0/10:26.0:1726780800")
assert(testSig == "5afbc1ca62a56ec17f5891a29f9e661c7e218b15867f0b552bec3def09856625", "HMAC test vector must match")
print("  [PASS] HMAC-SHA256 test vector parity confirmed")

-- Test 2: Legitimate signed player verification
local legitPlayer = {
    name = "Arthas",
    realm = "Frostmourne",
    raid_progress = "0/10",
    parse_ranking = 26.0,
    timestamp = 1726780800,
    sig = "5afbc1ca62a56ec17f5891a29f9e661c7e218b15867f0b552bec3def09856625",
}
local isVerified, reason = WoWEternityAddon:VerifyPlayerSignature(legitPlayer)
assert(isVerified == true, "Legitimate player record must be verified")
assert(reason == "verified", "Reason must be verified")
print("  [PASS] Legitimate player record verified successfully (isVerified=true)")

-- Test 3: Anti-Tamper: Player attempts to manipulate parse_ranking (26.0 -> 99.9)
local tamperedParsePlayer = {
    name = "Arthas",
    realm = "Frostmourne",
    raid_progress = "0/10",
    parse_ranking = 99.9,
    timestamp = 1726780800,
    sig = "5afbc1ca62a56ec17f5891a29f9e661c7e218b15867f0b552bec3def09856625",
}
local isTamperedParse, parseReason = WoWEternityAddon:VerifyPlayerSignature(tamperedParsePlayer)
assert(isTamperedParse == false, "Tampered parse ranking must fail verification")
assert(parseReason == "tampered", "Tampered parse ranking must return reason 'tampered'")
print("  [PASS] Tampered parse ranking detected and rejected (isVerified=false, reason='tampered')")

-- Test 4: Anti-Tamper: Player attempts to manipulate raid_progress (0/10 -> 10/10)
local tamperedProgressPlayer = {
    name = "Arthas",
    realm = "Frostmourne",
    raid_progress = "10/10",
    parse_ranking = 26.0,
    timestamp = 1726780800,
    sig = "5afbc1ca62a56ec17f5891a29f9e661c7e218b15867f0b552bec3def09856625",
}
local isTamperedProg, progReason = WoWEternityAddon:VerifyPlayerSignature(tamperedProgressPlayer)
assert(isTamperedProg == false, "Tampered raid progress must fail verification")
assert(progReason == "tampered", "Tampered raid progress must return reason 'tampered'")
print("  [PASS] Tampered raid progress detected and rejected (isVerified=false, reason='tampered')")

-- Test 5: VerifyAllPlayersIntegrity detects tampered records in database
WoWEternityAddonDB.players = { legitPlayer, tamperedParsePlayer }
local vCount, tCount = WoWEternityAddon:VerifyAllPlayersIntegrity()
assert(vCount == 1, "Expected 1 verified player")
assert(tCount == 1, "Expected 1 tampered player")
print("  [PASS] Database scan correctly reports 1 verified and 1 tampered player")

print("\\n--- Suite 6: Persistent Caching, Addon Communications & Range-Agnostic iLvl ---")

-- Test 1: CacheUnitIlvl persists to both memory and WoWEternityAddonDB
WoWEternityAddonDB.unitIlvlCache = {}
WoWEternityAddon:CacheUnitIlvl("Player-999-001", "35.5")
WoWEternityAddon:CacheUnitIlvl("Jaina", "35.5")
assert(WoWEternityAddon.unitIlvlCache["Player-999-001"] == "35.5", "In-memory cache must contain GUID")
assert(WoWEternityAddonDB.unitIlvlCache["Player-999-001"] == "35.5", "SavedVariables cache must contain GUID")
assert(WoWEternityAddon.unitIlvlCache["jaina"] == "35.5", "In-memory cache must index lowercased name")
assert(WoWEternityAddonDB.unitIlvlCache["jaina"] == "35.5", "SavedVariables cache must index lowercased name")
print("  [PASS] CacheUnitIlvl populates memory and persistent SavedVariables by GUID and Name")

-- Test 2: Out-of-range inspect fallback with cache hit
CheckInteractDistance = function(unit, distIndex) return false end -- Unit is out of 28yd inspect range
CanInspect = function(unit) return true end
UnitExists = function(unit) return true end
UnitIsPlayer = function(unit) return true end
UnitIsUnit = function(u1, u2) return u1 == u2 end
UnitGUID = function(u) if u == "player" then return "Player-000-000" else return "Player-999-001" end end
UnitName = function(u) if u == "player" then return "MyHero" else return "Jaina" end end

local cachedRes = WoWEternityAddon:GetUnitItemLevel("target", "Player-999-001", "Jaina")
assert(cachedRes == "35.5", "Must return cached iLvl even when out of range (CheckInteractDistance=false)")
print("  [PASS] Out-of-range hover returns cached iLvl immediately without calling inspect")

-- Test 3: Out-of-range uncached unit triggers comms request
local commsSent = {}
C_ChatInfo = {
    SendAddonMessage = function(prefix, text, channel, target)
        table.insert(commsSent, { prefix = prefix, text = text, channel = channel })
    end
}
IsInRaid = function() return true end
UnitGUID = function(u) if u == "player" then return "Player-000-000" else return "Player-999-002" end end
UnitName = function(u) if u == "player" then return "MyHero" else return "Thrall" end end

local uncachedRes = WoWEternityAddon:GetUnitItemLevel("target", "Player-999-002", "Thrall")
assert(uncachedRes == "...", "Uncached out-of-range unit returns '...' while querying comms")
assert(#commsSent > 0, "Must send comms request for out-of-range uncached unit")
assert(commsSent[1].text == "REQ_ILVL:Thrall", "Request message must target player name")
print("  [PASS] Out-of-range uncached unit triggers debounced comms request (REQ_ILVL)")

-- Test 4: Inbound addon message populates cache and updates tooltip
WoWEternityAddon:OnAddonMessage("WoWEternity", "ILVL:Player-999-002:37.2", "RAID", "Thrall-Orgrimmar")
assert(WoWEternityAddon.unitIlvlCache["Player-999-002"] == "37.2", "Cache must ingest iLvl by GUID from message")
assert(WoWEternityAddon.unitIlvlCache["thrall"] == "37.2", "Cache must ingest iLvl by clean sender name")
assert(WoWEternityAddonDB.unitIlvlCache["thrall"] == "37.2", "DB cache must ingest iLvl by clean sender name")

local resolvedRes = WoWEternityAddon:GetUnitItemLevel("target", "Player-999-002", "Thrall")
assert(resolvedRes == "37.2", "Subsequent hover on target returns newly ingested iLvl")
print("  [PASS] Peer addon message ingested into persistent cache and resolves subsequent hovers")
`;

  const tmpScriptPath = path.join(ADDON_DIR, 'tests', '.tmp_test_runner.lua');
  fs.writeFileSync(tmpScriptPath, luaScript, 'utf-8');
  const res = spawnSync('lua', [tmpScriptPath], { encoding: 'utf-8' });
  try { fs.unlinkSync(tmpScriptPath); } catch {}
  if (res.status !== 0) {
    console.error('Lua headless test failed with stderr:\n', res.stderr);
    console.error('stdout was:\n', res.stdout);
    process.exit(1);
  }
  console.log(res.stdout.trim());
}

async function main() {
  console.log('================================================================');
  console.log('M4 Challenger 2: Adversarial Addon Simulation & Parity Gate');
  console.log('================================================================\n');

  await runAdler32ParityTests();
  runHeadlessAddonLuaTests();

  console.log('\n================================================================');
  console.log('[VERDICT] ALL CHALLENGE GATES PASSED (100% EMPIRICAL CONFIRMATION)');
  console.log('================================================================');
}

main().catch((err) => {
  console.error('\n[FATAL TEST FAILURE]:', err);
  process.exit(1);
});
