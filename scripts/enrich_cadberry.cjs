/**
 * scripts/enrich_cadberry.cjs
 * Matches Cadberry guide steps with Questie quest and NPC data
 */

const fs = require("fs");
const path = require("path");
const { parseQuest } = require("./extract_questie_data.cjs");

// Map step IDs to Questie quest IDs or custom markers
const questieStepMap = {
    // Alliance Steps
    "ally-2": { questId: 2201, note: "Gol'Bolar Quarry starter" },
    "ally-3": { custom: true, starter: "Westfall Campfire", coords: { x: 37.2, y: 46.6 } },
    "ally-4": { custom: true, starter: "Old Ironforge Questgivers", coords: { x: 50.0, y: 50.0 } },
    "ally-5": { custom: true, dungeon: "Hall of Thanes", coords: { x: 64.8, y: 58.4 } },
    "ally-6": { custom: true, dungeon: "Ruins of Lordaeron", coords: { x: 61.2, y: 67.2 } },
    "ally-7": { questId: 65 },  // The Defias Brotherhood
    "ally-8": { questId: 155 }, // The Defias Brotherhood (Dungeon)
    "ally-11": { questId: 391 }, // The Stockade Riots
    "ally-12": { custom: true, dungeon: "Excavation Site W", coords: { x: 38.6, y: 52.4 } },
    "ally-13": { questId: 1200 }, // Blackfathom Villainy
    "ally-14": { questId: 1200 },
    "ally-15": { custom: true, dungeon: "City of Dalaran", coords: { x: 19.4, y: 78.4 } },
    "ally-16": { questId: 2841 }, // Rig Wars / Techbot Brain
    "ally-17": { questId: 2841 },
    "ally-18": { questId: 2841 },
    "ally-19": { questId: 1053 }, // In the Name of the Light
    "ally-20": { questId: 1053 },
    "ally-21": { questId: 1108 }, // Going, Going, Guano!
    "ally-22": { questId: 1108 },
    "ally-23": { questId: 1053 },
    "ally-24": { custom: true, dungeon: "Drowned City", coords: { x: 42.0, y: 70.0 } },
    "ally-26": { custom: true, dungeon: "Krol'Dok", coords: { x: 71.2, y: 56.4 } },
    "ally-27": { questId: 1104 }, // Bring the Light
    "ally-28": { questId: 1104 },
    "ally-29": { questId: 17 },   // Uldaman Reagent Run
    "ally-30": { questId: 17 },
    "ally-31": { questId: 17 },
    "ally-32": { questId: 2768 }, // Divino-matic Rod
    "ally-33": { questId: 2768 },
    "ally-34": { questId: 2768 },
    "ally-35": { questId: 7044 }, // Legends of Maraudon
    "ally-36": { custom: true, dungeon: "Alcaz Prison", coords: { x: 77.0, y: 16.0 } },
    "ally-37": { questId: 1448 }, // In Search of The Temple
    "ally-39": { questId: 1448 },
    "ally-40": { questId: 3821 },
    "ally-41": { questId: 4722 },
    "ally-42": { questId: 5381 },
    "ally-43": { questId: 5123 },

    // Horde Steps
    "horde-2": { questId: 842 },  // Trouble at the Docks
    "horde-3": { custom: true, starter: "Westfall Campfire", coords: { x: 37.2, y: 46.6 } },
    "horde-4": { questId: 5722 }, // Hidden Enemies / Satchel
    "horde-5": { questId: 5722 },
    "horde-6": { custom: true, dungeon: "Ruins of Lordaeron", coords: { x: 61.2, y: 67.2 } },
    "horde-7": { questId: 903 },  // Leaders of the Fang
    "horde-8": { questId: 903 },
    "horde-10": { questId: 1014 }, // Arugal Must Die
    "horde-12": { questId: 1205 }, // Allegiance to the Old Gods
    "horde-13": { custom: true, dungeon: "Excavation Site W", coords: { x: 38.6, y: 52.4 } },
    "horde-14": { custom: true, dungeon: "City of Dalaran", coords: { x: 19.4, y: 78.4 } },
    "horde-15": { questId: 2841 },
    "horde-16": { questId: 1108 },
    "horde-17": { questId: 1053 },
    "horde-18": { questId: 1053 },
    "horde-19": { custom: true, dungeon: "Drowned City", coords: { x: 42.0, y: 70.0 } },
    "horde-21": { custom: true, dungeon: "Krol'Dok", coords: { x: 71.2, y: 56.4 } },
    "horde-22": { questId: 1104 },
    "horde-23": { questId: 17 },
    "horde-24": { questId: 2768 },
    "horde-25": { questId: 7044 },
    "horde-26": { custom: true, dungeon: "Alcaz Prison", coords: { x: 77.0, y: 16.0 } },
    "horde-27": { questId: 1448 },
    "horde-29": { questId: 1448 },
    "horde-30": { questId: 3821 },
    "horde-31": { questId: 4722 },
    "horde-32": { questId: 5381 },
    "horde-33": { questId: 5123 },
};

function getEnrichment(stepId) {
    const mapping = questieStepMap[stepId];
    if (!mapping) return null;
    if (mapping.custom) {
        return {
            questieCustom: true,
            questieStarter: mapping.starter || "Custom Objective",
            questieCoords: mapping.coords || null,
        };
    }
    if (mapping.questId) {
        const q = parseQuest(mapping.questId);
        if (q) {
            return {
                questieQuestId: q.questId,
                questieQuestName: q.name,
                questieStarter: q.starter || "Quest Giver",
                questieCoords: q.starterCoords ? { x: q.starterCoords.x, y: q.starterCoords.y } : null,
            };
        }
    }
    return null;
}

module.exports = {
    questieStepMap,
    getEnrichment,
};

if (require.main === module) {
    console.log("Checking sample enrichments:");
    ["ally-7", "ally-8", "ally-3", "horde-4", "horde-10"].forEach(id => {
        console.log(id, getEnrichment(id));
    });
}
