const assert = require('node:assert/strict')
const childProcess = require('node:child_process')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const test = require('node:test')

const Model = require('../ComposeModel.js')
const headerPaths = ['keysymdef.h', 'XF86keysym.h', 'Sunkeysym.h', 'DECkeysym.h', 'HPkeysym.h'].map(name => path.join('/usr/include/X11', name))
const compiler = childProcess.spawnSync('cc', ['--version'], { encoding: 'utf8' })
const available = compiler.status === 0 && headerPaths.every(header => fs.existsSync(header))

test('keysym-only UTF-8 conversion matches libxkbcommon', { skip: !available }, t => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'omarchy-compose-keysym-'))
  t.after(() => fs.rmSync(scratch, { recursive: true, force: true }))
  const source = path.join(scratch, 'reference.c')
  const binary = path.join(scratch, 'reference')
  fs.writeFileSync(source, [
    '#include <stdio.h>',
    '#include <string.h>',
    '#include <xkbcommon/xkbcommon.h>',
    'int main(void) {',
    '  char name[256], utf8[64];',
    '  while (fgets(name, sizeof name, stdin)) {',
    '    name[strcspn(name, "\\r\\n")] = 0;',
    '    xkb_keysym_t symbol = xkb_keysym_from_name(name, XKB_KEYSYM_NO_FLAGS);',
    '    int size = xkb_keysym_to_utf8(symbol, utf8, sizeof utf8);',
    '    printf("%s\\t", name);',
    '    if (size > 0) for (size_t i = 0; i < strlen(utf8); i++) printf("%02x", (unsigned char) utf8[i]);',
    '    putchar(10);',
    '  }',
    '  return 0;',
    '}'
  ].join('\n'))
  const built = childProcess.spawnSync('cc', [source, '-lxkbcommon', '-o', binary], { encoding: 'utf8' })
  assert.equal(built.status, 0, built.stderr)

  const header = headerPaths.map(header => fs.readFileSync(header, 'utf8')).join('\n')
  const definitions = Model.parseKeysymDefinitions(header)
  const names = Object.keys(definitions)
  const input = path.join(scratch, 'names')
  const output = path.join(scratch, 'reference.tsv')
  fs.writeFileSync(input, names.join('\n') + '\n')
  const reference = childProcess.spawnSync('/bin/sh', ['-c', '"$1" < "$2" > "$3"', 'keysym-reference', binary, input, output], { encoding: 'utf8', timeout: 5000 })
  assert.equal(reference.status, 0, reference.stderr)
  const expected = new Map(fs.readFileSync(output, 'utf8').split('\n').filter(line => line.includes('\t')).map(line => line.split('\t')))
  const mismatches = []
  for (const name of names) {
    const actualHex = Buffer.from(Model.keysymToUtf8(name, definitions), 'utf8').toString('hex')
    if (actualHex !== expected.get(name)) mismatches.push({ name, actualHex, expectedHex: expected.get(name) })
  }
  assert.deepEqual(mismatches, [])
  assert.equal(Model.knownKeysym('XF86AudioMute', definitions), true)
  assert.equal(Model.knownKeysym('XF86MediaPlayPause', definitions), true)
})
