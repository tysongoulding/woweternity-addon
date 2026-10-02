/**
 * scripts/extract_questie_data.js
 * Extracts quest metadata and NPC starter coordinates from Questie-Forever
 * to enrich Cadberry leveling guide steps in woweternity-addon.
 */

const fs = require("fs");
const path = require("path");

const questDbPath = path.resolve(__dirname, "../../Questie-Forever/Database/Classic/classicQuestDB.lua");
const npcDbPath = path.resolve(__dirname, "../../Questie-Forever/Database/Classic/classicNpcDB.lua");

if (!fs.existsSync(questDbPath) || !fs.existsSync(npcDbPath)) {
    console.error("Questie DB files not found at:", questDbPath);
    process.exit(1);
}

const questDb = fs.readFileSync(questDbPath, "utf8");
const npcDb = fs.readFileSync(npcDbPath, "utf8");

function getQuestRaw(id) {
    const m = questDb.match(new RegExp(`\\[${id}\\]\\s*=\\s*\\{([\\s\\S]*?)\\},?\\n`));
    return m ? m[1] : null;
}

function parseLuaString(raw) {
    if (!raw) return "Unknown";
    if (raw.startsWith("\x27")) {
        const m = raw.match(/^\x27((?:[^\x27\\]|\\.)*)\x27/);
        return m ? m[1].replace(/\\([\\x27"])/g, "$1") : "Unknown";
    } else if (raw.startsWith("\"")) {
        const m = raw.match(/^"((?:[^"\\]|\\.)*)"/);
        return m ? m[1].replace(/\\([\\x27"])/g, "$1") : "Unknown";
    }
    return "Unknown";
}

function getNpcInfo(id) {
    if (!id) return null;
    const m = npcDb.match(new RegExp(`\\[${id}\\]\\s*=\\s*\\{([\\s\\S]*?)\\},?\\n`));
    if (!m) return null;
    const raw = m[1];
    const name = parseLuaString(raw);
    const spawnsMatch = raw.match(/\{\[(\d+)\]\s*=\s*\{\{([0-9.]+),\s*([0-9.]+)\}/);
    return {
        id: parseInt(id, 10),
        name: name,
        zoneId: spawnsMatch ? parseInt(spawnsMatch[1], 10) : null,
        x: spawnsMatch ? parseFloat(spawnsMatch[2]) : null,
        y: spawnsMatch ? parseFloat(spawnsMatch[3]) : null,
    };
}

function parseQuest(id) {
    const raw = getQuestRaw(id);
    if (!raw) return null;
    const name = parseLuaString(raw);
    const starterMatch = raw.match(/,\{\{(\d+)\}\}/);
    const finisherMatch = raw.match(/,\{\{(\d+)\}\},.*?\{\{(\d+)\}\}/);

    const starterId = starterMatch ? starterMatch[1] : null;
    const finisherId = finisherMatch ? finisherMatch[2] : null;

    const starterNpc = getNpcInfo(starterId);
    const finisherNpc = getNpcInfo(finisherId);

    return {
        questId: parseInt(id, 10),
        name: name,
        starter: starterNpc ? starterNpc.name : null,
        starterCoords: starterNpc && starterNpc.x ? { x: starterNpc.x, y: starterNpc.y, zoneId: starterNpc.zoneId } : null,
        finisher: finisherNpc ? finisherNpc.name : null,
        finisherCoords: finisherNpc && finisherNpc.x ? { x: finisherNpc.x, y: finisherNpc.y, zoneId: finisherNpc.zoneId } : null,
    };
}

module.exports = {
    parseQuest,
    getNpcInfo,
};

if (require.main === module) {
    const testIds = [65, 391, 1200, 2841, 1051, 1145, 1104, 17, 2768, 7044, 1448, 4123, 5381, 5123, 5722, 903, 1014, 1205];
    console.log("Testing Questie quest extraction...");
    testIds.forEach(id => {
        const q = parseQuest(id);
        if (q) {
            console.log(`[Quest ${q.questId}] ${q.name} -> Starter: ${q.starter || "None"} (${q.starterCoords ? `${q.starterCoords.x}, ${q.starterCoords.y}` : "no coords"})`);
        }
    });
}
