'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = fs.readFileSync(path.join(__dirname, '..', 'moba-random.html'), 'utf8');
for (const requiredMarkup of [
    'id="mainPage"',
    'id="weightPage"',
    'id="weightRows"',
    'onclick="openWeightSettings()"',
    'onclick="saveWeightSettings()"',
    'id="avoidPrevious"',
]) assert.ok(html.includes(requiredMarkup), `missing web interaction markup: ${requiredMarkup}`);
assert.ok(!html.includes('id="lastGameInput"'), 'manual previous-game input should be removed');
const script = html.match(/<script>([\s\S]*)<\/script>/)?.[1];
assert.ok(script, 'inline application script must exist');

const storage = new Map();
const sandbox = {
    window: {},
    localStorage: {
        getItem: key => storage.has(key) ? storage.get(key) : null,
        setItem: (key, value) => storage.set(key, String(value)),
    },
    console,
    Set,
    Map,
    Date,
    Math,
    JSON,
};
vm.createContext(sandbox);
vm.runInContext(script, sandbox);
const api = sandbox.window.MobaWeights;

assert.equal(api.previousRolesTextFromResult(null), '');
assert.equal(api.previousRolesTextFromResult({ rolesA: ['A', 'B'], rolesB: ['C', 'D'] }), 'A，B，C，D');

assert.deepEqual(
    Array.from(api.normalizeToHundred([90, 20, 0, 0])),
    [82, 18, 0, 0],
);
assert.deepEqual(Array.from(api.normalizeToHundred([120, 0, 0, 0])), [100, 0, 0, 0]);
assert.deepEqual(Array.from(api.normalizeToHundred([101, 101, 101])), [34, 33, 33]);
assert.equal(api.normalizeToHundred([-1, 101]), null);

const duplicatePool = api.parseRolePool('射手：A、B\n中路：A、C');
const defaults = api.reconcileWeights(duplicatePool, null);
assert.deepEqual(Array.from(defaults.characters, entry => entry.character), ['A', 'B', 'C']);
assert.deepEqual({ ...defaults.characters[0].laneWeights }, { 射手: 100, 中路: 0 });
assert.equal(defaults.characters[0].sourceLane, '射手');

const moved = api.reconcileWeights(
    api.parseRolePool('射手：B\n中路：A'),
    {
        version: 1,
        characters: [
            { character: 'A', sourceLane: '射手', laneWeights: { 射手: 80, 中路: 20 } },
            { character: 'B', sourceLane: '射手', laneWeights: { 射手: 70, 中路: 30 } },
        ],
    },
);
assert.deepEqual({ ...moved.characters.find(entry => entry.character === 'A').laneWeights }, { 射手: 0, 中路: 100 });
assert.equal(moved.characters.find(entry => entry.character === 'A').sourceLane, '中路');
assert.deepEqual({ ...moved.characters.find(entry => entry.character === 'B').laneWeights }, { 射手: 70, 中路: 30 });

const legacy = api.reconcileWeights(
    api.parseRolePool('射手：A\n中路：B'),
    { version: 1, characters: [{ character: 'A', laneWeights: { 射手: 35, 中路: 65 } }] },
);
assert.deepEqual({ ...legacy.characters[0].laneWeights }, { 射手: 35, 中路: 65 });
assert.equal(legacy.characters[0].sourceLane, '射手');

const reconciled = api.reconcileWeights(
    api.parseRolePool('射手：A、D\n打野：C'),
    {
        version: 1,
        characters: [
            { character: 'A', laneWeights: { 射手: 80, 中路: 20 } },
            { character: 'B', laneWeights: { 射手: 100, 中路: 0 } },
            { character: 'C', laneWeights: { 射手: 0, 中路: 100 } },
        ],
    },
);
assert.deepEqual(Array.from(reconciled.characters, entry => entry.character), ['A', 'D', 'C']);
assert.deepEqual({ ...reconciled.characters.find(entry => entry.character === 'A').laneWeights }, { 射手: 100, 打野: 0 });
assert.deepEqual({ ...reconciled.characters.find(entry => entry.character === 'C').laneWeights }, { 射手: 0, 打野: 100 });

storage.set('moba_role_weights_v1', JSON.stringify({
    version: 1,
    characters: [
        { character: 'A', laneWeights: { 射手: 80, 中路: 20 } },
        { character: 'B', laneWeights: { 射手: 100, 中路: 0 } },
        { character: 'C', laneWeights: { 射手: 0, 中路: 100 } },
    ],
}));
const reloaded = api.loadWeights('射手：A、B\n中路：C');
assert.deepEqual({ ...reloaded.characters[0].laneWeights }, { 射手: 80, 中路: 20 });
assert.deepEqual(
    JSON.parse(storage.get('moba_role_weights_v1')).characters[0].laneWeights,
    { 射手: 80, 中路: 20 },
);

const result = api.generateResult(
    api.DEFAULT_POOL_TEXT,
    '温迪, 胡桃, 钟离, 行秋',
    false,
    null,
    1700000000123,
);
assert.deepEqual(Array.from(result.rolesA), ['提纳里', '绫华', '神子', '女仆']);
assert.deepEqual(Array.from(result.rolesB), ['公子', '胡桃', '纳西妲', '点刀']);
assert.deepEqual(Array.from(result.playersA), [8, 2, 1, 6]);
assert.deepEqual(Array.from(result.playersB), [7, 4, 5, 3]);

const multiLaneConfig = {
    version: 1,
    characters: ['A', 'B', 'C', 'D'].map(character => ({
        character,
        laneWeights: { 射手: 50, 中路: 50 },
    })),
};
const normal = api.generateResult('射手：A、B、C、D\n中路：A、B、C、D', '', false, multiLaneConfig, 77);
assert.equal(new Set([...normal.rolesA, ...normal.rolesB]).size, 4);
const mirror = api.generateResult('射手：A、B、C、D\n中路：A、B、C、D', '', true, multiLaneConfig, 91);
assert.equal(new Set(mirror.rolesA).size, 2);
assert.equal(new Set(mirror.rolesB).size, 2);

const replacementPool = '射手：A、B、C\n中路：D、E、F';
const replacementConfig = api.reconcileWeights(api.parseRolePool(replacementPool), null);
replacementConfig.characters.find(entry => entry.character === 'D').laneWeights = { 射手: 0, 中路: 100 };
const candidates = api.replacementCandidates(
    { rolesA:['A','D'], rolesB:['B','E'] },
    'A',
    0,
    replacementPool,
    false,
    replacementConfig,
);
assert.deepEqual(Array.from(candidates), ['C']);

assert.throws(
    () => api.generateResult(
        '射手：A、B\n中路：A、B',
        '',
        false,
        {
            version: 1,
            characters: ['A', 'B'].map(character => ({
                character,
                laneWeights: { 射手: 50, 中路: 50 },
            })),
        },
        1,
    ),
    /无法组成完整/,
);

assert.ok(Math.abs(api.effectiveWeight(
    { version:1, characters:[{ character:'A', laneWeights:{ 射手:80, 中路:20 } }] },
    'A',
    '射手',
    new Set(['A']),
) - 0.08) < 0.000001);

console.log('Web weight behavior checks passed.');
