import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const SCRIPT = join(dirname(fileURLToPath(import.meta.url)), 'board-options.mjs');

// Run the transform: returns {code, out, err}. Never throws on non-zero exit.
function run(args, inputJson) {
  try {
    const out = execFileSync('node', [SCRIPT, ...args], {
      input: JSON.stringify(inputJson),
      encoding: 'utf8',
    });
    return { code: 0, out: JSON.parse(out), err: '' };
  } catch (e) {
    return { code: e.status ?? 1, out: null, err: String(e.stderr || '') };
  }
}

const SAMPLE = [
  { id: '83dce863', name: '(none)', color: 'GRAY', description: '' },
  { id: 'cc88c1ed', name: 'dev/security', color: 'RED', description: '' },
  { id: '9b9950de', name: 'dev/daily-call-quality', color: 'PURPLE', description: '' },
];

test('add appends id-less new option and preserves existing ids', () => {
  const r = run(['add', '--name', 'dev/new', '--color', 'BLUE'], SAMPLE);
  assert.equal(r.code, 0);
  assert.equal(r.out.length, 4);
  for (const o of SAMPLE) {
    assert.deepEqual(r.out.find(x => x.name === o.name).id, o.id);
  }
  const added = r.out.find(x => x.name === 'dev/new');
  assert.equal(added.color, 'BLUE');
  assert.ok(!('id' in added), 'new option must omit id');
});

test('add rejects duplicate name', () => {
  const r = run(['add', '--name', 'dev/security', '--color', 'BLUE'], SAMPLE);
  assert.equal(r.code, 1);
  assert.match(r.err, /already/i);
});

test('add rejects (none)', () => {
  const r = run(['add', '--name', '(none)', '--color', 'GRAY'], SAMPLE);
  assert.equal(r.code, 1);
});

test('edit preserves target id while changing name and color', () => {
  const r = run(['edit', '--target', 'dev/daily-call-quality',
                 '--new-name', 'dev/daily-call-polish', '--color', 'GREEN'], SAMPLE);
  assert.equal(r.code, 0);
  const t = r.out.find(x => x.name === 'dev/daily-call-polish');
  assert.equal(t.id, '9b9950de'); // SAME id => issues stay linked
  assert.equal(t.color, 'GREEN');
  assert.equal(r.out.length, 3);
});

test('edit --new-name only keeps existing color', () => {
  const r = run(['edit', '--target', 'dev/security', '--new-name', 'dev/sec'], SAMPLE);
  assert.equal(r.code, 0);
  const t = r.out.find(x => x.name === 'dev/sec');
  assert.equal(t.id, 'cc88c1ed');
  assert.equal(t.color, 'RED');
});

test('edit rejects rename into an existing name', () => {
  const r = run(['edit', '--target', 'dev/security', '--new-name', 'dev/daily-call-quality'], SAMPLE);
  assert.equal(r.code, 1);
  assert.match(r.err, /collid|exist/i);
});

test('edit rejects missing target and (none)', () => {
  assert.equal(run(['edit', '--target', 'nope', '--color', 'BLUE'], SAMPLE).code, 1);
  assert.equal(run(['edit', '--target', '(none)', '--color', 'BLUE'], SAMPLE).code, 1);
});

test('edit requires at least one change flag', () => {
  const r = run(['edit', '--target', 'dev/security'], SAMPLE);
  assert.equal(r.code, 1);
});

test('drop removes target and preserves survivor ids', () => {
  const r = run(['drop', '--target', 'dev/security'], SAMPLE);
  assert.equal(r.code, 0);
  assert.equal(r.out.length, 2);
  assert.equal(r.out.find(x => x.name === '(none)').id, '83dce863');
  assert.equal(r.out.find(x => x.name === 'dev/daily-call-quality').id, '9b9950de');
  assert.ok(!r.out.find(x => x.name === 'dev/security'));
});

test('drop rejects missing target and (none)', () => {
  assert.equal(run(['drop', '--target', 'nope'], SAMPLE).code, 1);
  assert.equal(run(['drop', '--target', '(none)'], SAMPLE).code, 1);
});

test('REGRESSION: editing one option in a full 10-option set preserves all other ids', () => {
  const TEN = [
    { id: '83dce863', name: '(none)', color: 'GRAY', description: '' },
    { id: 'cc88c1ed', name: 'dev/security', color: 'RED', description: '' },
    { id: '08f3e9ff', name: 'dev/voice-testing-environment', color: 'ORANGE', description: '' },
    { id: 'ce264776', name: 'dev/daily-call-features', color: 'GREEN', description: '' },
    { id: '263f2d65', name: 'dev/voice-ux', color: 'PURPLE', description: '' },
    { id: '13e17c9a', name: 'dev/transcript-fix', color: 'YELLOW', description: '' },
    { id: 'c5dd867b', name: 'dev/state-management-bugs', color: 'BLUE', description: '' },
    { id: '35b2235e', name: 'dev/radial-menu', color: 'PINK', description: '' },
    { id: 'ea093667', name: 'dev/bugs-state-refresh', color: 'ORANGE', description: '' },
    { id: '9b9950de', name: 'dev/daily-call-quality', color: 'PURPLE', description: '' },
  ];
  const r = run(['edit', '--target', 'dev/radial-menu', '--new-name', 'dev/radial', '--color', 'PINK'], TEN);
  assert.equal(r.code, 0);
  assert.equal(r.out.length, 10);
  for (const o of TEN) {
    const match = r.out.find(x => x.id === o.id);
    assert.ok(match, `id ${o.id} (${o.name}) must survive`);
  }
  assert.ok(r.out.find(x => x.name === 'dev/radial'));
  assert.ok(!r.out.find(x => x.name === 'dev/radial-menu'));
});

test('add rejects an unknown color', () => {
  const r = run(['add', '--name', 'dev/x', '--color', 'PURPEL'], SAMPLE);
  assert.equal(r.code, 1);
  assert.match(r.err, /unknown color/i);
});

test('edit rejects an unknown color (but allows a valid one)', () => {
  assert.equal(run(['edit', '--target', 'dev/security', '--color', 'NEON'], SAMPLE).code, 1);
  assert.equal(run(['edit', '--target', 'dev/security', '--color', 'BLUE'], SAMPLE).code, 0);
});

test('names with special chars (quote/backslash/newline) survive the transform verbatim', () => {
  // The .sh layer feeds transform output to JSON.stringify when building the
  // GraphQL literal; this asserts the transform itself does not mangle the name,
  // so the downstream escaping has correct input to work from.
  const tricky = 'dev/has "quote" and \\back and \nnewline';
  const r = run(['edit', '--target', 'dev/security', '--new-name', tricky], SAMPLE);
  assert.equal(r.code, 0);
  const t = r.out.find(x => x.id === 'cc88c1ed');
  assert.equal(t.name, tricky); // exact round-trip, id preserved
});
