#!/usr/bin/env node
// Pure transforms for GitHub Project single-select option arrays.
// Reads current options (JSON array) on stdin, writes desired options on stdout.
// Invariant: every pre-existing option keeps its id; only `add` emits an id-less entry.
// No network — see board-options.sh for the gh boundary.

const RESERVED = '(none)';

function die(msg) {
  process.stderr.write(`board-options: ${msg}\n`);
  process.exit(1);
}

function parseFlags(argv) {
  const f = {};
  for (let i = 0; i < argv.length; i += 2) {
    if (!argv[i].startsWith('--')) die(`unexpected arg: ${argv[i]}`);
    f[argv[i].slice(2)] = argv[i + 1];
  }
  return f;
}

function readStdin() {
  return new Promise((resolve) => {
    let d = '';
    process.stdin.on('data', (c) => (d += c));
    process.stdin.on('end', () => resolve(d));
  });
}

function findByName(opts, name) {
  return opts.find((o) => o.name === name);
}

function add(opts, f) {
  if (!f.name || !f.color) die('add requires --name and --color');
  if (f.name === RESERVED) die(`cannot create reserved option "${RESERVED}"`);
  if (findByName(opts, f.name)) die(`option "${f.name}" already exists`);
  return [...opts, { name: f.name, color: f.color, description: '' }];
}

function edit(opts, f) {
  if (!f.target) die('edit requires --target');
  if (f.target === RESERVED) die(`cannot edit reserved option "${RESERVED}"`);
  if (f['new-name'] === undefined && f.color === undefined) {
    die('edit requires at least one of --new-name or --color');
  }
  const target = findByName(opts, f.target);
  if (!target) die(`option "${f.target}" not found`);
  if (f['new-name'] && f['new-name'] !== f.target && findByName(opts, f['new-name'])) {
    die(`cannot rename: "${f['new-name']}" collides with an existing option`);
  }
  return opts.map((o) =>
    o.name === f.target
      ? {
          id: o.id, // PRESERVE id — this is what keeps issues linked
          name: f['new-name'] ?? o.name,
          color: f.color ?? o.color,
          description: o.description ?? '',
        }
      : o
  );
}

function drop(opts, f) {
  if (!f.target) die('drop requires --target');
  if (f.target === RESERVED) die(`cannot drop reserved option "${RESERVED}"`);
  if (!findByName(opts, f.target)) die(`option "${f.target}" not found`);
  return opts.filter((o) => o.name !== f.target);
}

const VERBS = { add, edit, drop };

async function main() {
  const [verb, ...rest] = process.argv.slice(2);
  if (!VERBS[verb]) die(`unknown verb "${verb}" (use add|edit|drop)`);
  let opts;
  try {
    opts = JSON.parse(await readStdin());
  } catch {
    die('stdin is not valid JSON');
  }
  if (!Array.isArray(opts)) die('stdin must be a JSON array of options');
  const result = VERBS[verb](opts, parseFlags(rest));
  process.stdout.write(JSON.stringify(result, null, 2) + '\n');
}

main();
