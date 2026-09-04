const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')

const Model = require('../ComposeModel.js')
const fixtures = name => fs.readFileSync(path.join(__dirname, 'fixtures', name), 'utf8')

test('normalizes shortcut aliases and preserves disabled state', () => {
  assert.equal(Model.normalizeShortcut(' control+mod4+; '), 'SUPER + CTRL + SEMICOLON')
  assert.equal(Model.normalizeShortcut('shift + alt + q'), 'ALT + SHIFT + Q')
  assert.equal(Model.normalizeShortcut(''), '')
  assert.equal(Model.normalizeShortcut(null), Model.DEFAULT_SHORTCUT)
})

test('parses mode payload defensively', () => {
  assert.equal(Model.parseModePayload('{"mode":"studio"}'), 'studio')
  assert.equal(Model.parseModePayload({ mode: 'quick' }), 'quick')
  assert.equal(Model.parseModePayload('{broken'), 'quick')
  assert.equal(Model.parseModePayload('{"mode":"unknown"}'), 'quick')
})

test('settings are inline on the plugins entry without implicit writes', () => {
  const config = { plugins: [{ id: 'melonamin.compose', shortcut: '' }] }
  assert.equal(Model.settingsFrom(Model.findPluginEntry(config, 'melonamin.compose')).shortcut, '')
  assert.deepEqual(config, { plugins: [{ id: 'melonamin.compose', shortcut: '' }] })
  Model.writePluginSetting(config, 'melonamin.compose', 'shortcut', 'SUPER + A')
  assert.equal(config.plugins[0].shortcut, 'SUPER + A')
})

test('tokenizes losslessly with raw spans, CRLF, includes, and unknown syntax', () => {
  const raw = fixtures('lossless.compose')
  const doc = Model.parseDocument(raw, { sourceId: 'mine' })
  assert.equal(doc.nodes.map(node => node.raw).join(''), raw)
  assert.equal(doc.newlineStyle, '\r\n')
  assert.deepEqual(doc.nodes.map(node => node.type), ['comment', 'include', 'blank', 'rule', 'rule', 'rule', 'unknown'])
  assert.equal(doc.nodes[1].includePath, '%H/.config/compose/base')
  assert.equal(doc.nodes[3].line, 4)
  assert.equal(raw.slice(doc.nodes[3].start, doc.nodes[3].end), doc.nodes[3].raw)
  assert.deepEqual(doc.nodes[3].sequence, ['Multi_key', 'apostrophe', 'e'])
  assert.equal(doc.nodes[3].modifiers, 'None')
  assert.deepEqual(doc.nodes[3].eventModifiers, ['None', '', ''])
})

test('parses and re-encodes modifiers independently for every event', () => {
  const raw = 'None <Multi_key> Shift <a> ~Ctrl Alt <b> : "x"\n'
  const node = Model.parseDocument(raw).nodes[0]
  assert.equal(node.type, 'rule')
  assert.deepEqual(node.sequence, ['Multi_key', 'a', 'b'])
  assert.deepEqual(node.eventModifiers, ['None', 'Shift', '~Ctrl Alt'])
  assert.equal(Model.encodeRule(node, '\n'), raw)
})

test('models string-only, keysym-only, combined, and non-insertable results', () => {
  const doc = Model.parseDocument(fixtures('results.compose'))
  const rules = doc.nodes.filter(node => node.type === 'rule')
  assert.equal(rules[0].resultString, 'string')
  assert.equal(rules[0].resultKeysym, '')
  assert.equal(rules[1].resultString, null)
  assert.equal(rules[1].resultKeysym, 'eacute')
  assert.equal(rules[1].output, 'é')
  assert.equal(rules[2].resultString, 'ú')
  assert.equal(rules[2].resultKeysym, 'uacute')
  assert.equal(rules[3].insertable, false)
  assert.equal(rules[4].output, 'quote: " slash: \\ tab: \t newline: \n')
})

test('an explicit empty string remains distinct from a keysym-only result', () => {
  const node = Model.parseDocument('<Multi_key> <e> : "" eacute\n').nodes[0]
  assert.equal(node.resultStringRaw, '')
  assert.equal(node.resultString, '')
  assert.equal(Model.encodeRule({
    sequence: node.sequence,
    resultString: node.resultString,
    resultKeysym: node.resultKeysym
  }), '<Multi_key> <e> : "" eacute')
})

test('decodes octal and hexadecimal result escapes as UTF-8 bytes', () => {
  assert.equal(Model.decodeComposeString('\\303\\251').value, 'é')
  assert.equal(Model.decodeComposeString('\\xC3\\xA9').value, 'é')
  assert.equal(Model.decodeComposeString('literal ú').value, 'literal ú')
  assert.equal(Model.decodeComposeString('\\q\\n\\t').value, 'qnt')
})

test('keysym definition parsing supplies Unicode fallback', () => {
  const definitions = Model.parseKeysymDefinitions([
    '#define XK_EuroSign 0x20ac /* U+20AC EURO SIGN */',
    '#define XK_Return 0xff0d /* U+000D CARRIAGE RETURN */',
    '#define XK_KP_1 0xffb1 /*<U+0031 DIGIT ONE>*/',
    '#define XK_KP_Add 0xffab /*<U+002B PLUS SIGN>*/',
    '#define XK_Oslash 0x00d8 /* U+00D8 LATIN CAPITAL LETTER O WITH STROKE */',
    '#define XK_Ooblique 0x00d8',
    '#define XK_Multi_key 0xff20',
    '#define XF86XK_MediaPlayPause _EVDEVK(0x0a4)',
    '#define XF86XK_Numeric0 _EVDEVK(0x200)'
  ].join('\n'))
  assert.equal(Model.keysymToUtf8('EuroSign', definitions), '€')
  assert.equal(Model.keysymToUtf8('Return', definitions), '\r')
  assert.equal(Model.keysymToUtf8('KP_1', definitions), '1')
  assert.equal(Model.keysymToUtf8('KP_Add', definitions), '+')
  assert.equal(Model.keysymToUtf8('Ooblique', definitions), 'Ø')
  assert.equal(Model.knownKeysym('Multi_key', definitions), true)
  assert.equal(Model.knownKeysym('XF86MediaPlayPause', definitions), true)
  assert.equal(Model.keysymToUtf8('XF86MediaPlayPause', definitions), '')
  assert.equal(Model.keysymToUtf8('XF86Numeric0', definitions), '0')
  assert.equal(Model.keysymToUtf8('U1F642'), '🙂')
  assert.equal(Model.keysymToUtf8('U2dd'), '˝')
  assert.equal(Model.knownKeysym('U37a', definitions), true)
  assert.equal(Model.keysymToUtf8('VoidSymbol'), '')
})

test('candidate validation rejects unknown event and result keysyms', () => {
  const definitions = Model.parseKeysymDefinitions('#define XK_Multi_key 0xff20\n#define XK_a 0x0061 /* U+0061 LATIN SMALL LETTER A */\n#define XF86XK_MediaPlayPause _EVDEVK(0x0a4)\n')
  assert.equal(Model.validateCandidate('<Multi_key> <a> : "ok"\n', { keysymDefinitions: definitions }).valid, true)
  assert.equal(Model.validateCandidate('<Multi_key> <DefinitelyNotAKeysym> : "x"\n', { keysymDefinitions: definitions }).valid, false)
  assert.equal(Model.validateCandidate('<Multi_key> <a> : DefinitelyNotAKeysym\n', { keysymDefinitions: definitions }).valid, false)
  assert.equal(Model.validateCandidate('<Multi_key> <XF86MediaPlayPause> : "media"\n', { keysymDefinitions: definitions }).valid, true)
  assert.equal(Model.validateCandidate('garbage <Multi_key> <a> : "x"\n', { keysymDefinitions: definitions }).valid, false)
  assert.equal(Model.validateCandidate('! ~Shift Ctrl <Multi_key> <a> : "x"\n', { keysymDefinitions: definitions }).valid, true)
  assert.equal(Model.validateCandidate('<Multi_key> <a> : "ok"\n', { keysymDefinitions: {} }).valid, true)
})

test('candidate validation preserves unknown future syntax', () => {
  const raw = 'future compose directive\n<Multi_key> <a> : "changed"\n'
  const checked = Model.validateCandidate(raw)
  assert.equal(checked.valid, true)
  assert.equal(checked.document.nodes[0].type, 'unknown')
  assert.equal(checked.document.nodes.map(node => node.raw).join(''), raw)
})

test('later exact and both prefix orderings shadow earlier rules', () => {
  const doc = Model.parseDocument(fixtures('conflicts.compose'), { sourceId: 'mine' })
  const library = Model.resolveEffectiveLibrary([{ kind: 'Mine', path: '/tmp/.XCompose', document: doc }])
  assert.deepEqual(library.activeRules.map(rule => rule.output), ['long-last', 'short-last', 'new'])
  assert.deepEqual(library.diagnostics.map(item => item.kind), ['prefix', 'prefix', 'override'])
  assert.equal(library.rules[0].shadowedBy, library.rules[1].id)
  assert.equal(library.rules[2].shadowedBy, library.rules[3].id)
})

test('trie conflict resolution matches the original ordered semantics', () => {
  let seed = 0x5eed1234
  const random = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0
    return seed / 0x100000000
  }
  const symbols = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']
  const nodes = []
  for (let index = 0; index < 600; index++) {
    const sequence = ['Multi_key']
    const length = 1 + Math.floor(random() * 4)
    for (let event = 0; event < length; event++) sequence.push(symbols[Math.floor(random() * symbols.length)])
    nodes.push({
      type: 'rule', sourceId: 'mine', start: index, line: index + 1,
      sequence, output: String(index), insertable: true,
      displaySequence: sequence.map(key => `<${key}>`).join(' ')
    })
  }

  const expected = nodes.map((node, index) => ({ active: true, shadowedBy: null, shadows: [], id: `mine:${index}` }))
  const expectedDiagnostics = []
  for (let next = 0; next < nodes.length; next++) {
    for (let previous = 0; previous < next; previous++) {
      if (!expected[previous].active) continue
      const relation = Model.sequenceRelation(nodes[previous].sequence, nodes[next].sequence)
      if (relation === 'none') continue
      expected[previous].active = false
      expected[previous].shadowedBy = expected[next].id
      expected[next].shadows.push(expected[previous].id)
      expectedDiagnostics.push(relation === 'exact' ? 'override' : 'prefix')
    }
  }

  const actual = Model.resolveEffectiveLibrary([{ kind: 'Mine', document: { nodes } }])
  assert.deepEqual(actual.rules.map(rule => ({
    active: rule.active,
    shadowedBy: rule.shadowedBy,
    shadows: rule.shadows,
    id: rule.id
  })), expected)
  assert.deepEqual(actual.diagnostics.map(item => item.kind), expectedDiagnostics)
})

test('span replacement and deletion touch only the selected rule', () => {
  const raw = fixtures('lossless.compose')
  const doc = Model.parseDocument(raw)
  const target = doc.nodes.find(node => node.type === 'rule')
  const replacement = '<Multi_key> <e> : "E"\r\n'
  const replaced = Model.replaceSpan(doc, target, replacement)
  assert.equal(replaced, raw.slice(0, target.start) + replacement + raw.slice(target.end))
  assert.equal(Model.deleteRule(doc, target), raw.slice(0, target.start) + raw.slice(target.end))
})

test('multiple span edits replace one rule and remove a colliding rule without offset drift', () => {
  const raw = '<Multi_key> <a> : "first"\n<Multi_key> <b> : "middle"\n<Multi_key> <c> : "last"\n'
  const doc = Model.parseDocument(raw)
  const rules = doc.nodes.filter(node => node.type === 'rule')
  assert.equal(Model.applySpanEdits(doc, [
    { node: rules[2], replacement: '<Multi_key> <b> : "edited"\n' },
    { node: rules[1], replacement: '' }
  ]), '<Multi_key> <a> : "first"\n<Multi_key> <b> : "edited"\n')
  assert.equal(Model.applySpanEdits(doc, [
    { node: rules[0], replacement: '<Multi_key> <b> : "edited"\n' },
    { node: rules[1], replacement: '' }
  ]), '<Multi_key> <b> : "edited"\n<Multi_key> <c> : "last"\n')
})

test('local replacement removes inactive duplicates and moves the winner after later conflicts', () => {
  const raw = '<Multi_key> <a> : "first"\n<Multi_key> <a> : "second"\ninclude "later.compose"\n'
  const doc = Model.parseDocument(raw)
  const duplicates = doc.nodes.filter(node => node.type === 'rule')
  const replaced = Model.replaceLocalDefinitions(doc, duplicates, null, '<Multi_key> <a> : "saved"')
  assert.equal(replaced,
    'include "later.compose"\n\n# --- Omarchy Compose: local rules ---\n<Multi_key> <a> : "saved"\n')
  assert.equal(Model.parseDocument(replaced).nodes.filter(node => node.type === 'rule').length, 1)
})

test('local replacement keeps an active anchor position while removing older duplicates', () => {
  const raw = '<Multi_key> <a> : "first"\n# keep\n<Multi_key> <a> : "second"\n'
  const doc = Model.parseDocument(raw)
  const duplicates = doc.nodes.filter(node => node.type === 'rule')
  const replaced = Model.replaceLocalDefinitions(doc, duplicates, duplicates[1], '<Multi_key> <a> : "saved"')
  assert.equal(replaced, '# keep\n<Multi_key> <a> : "saved"\n')
})

test('moving a shadowed edit to the local section places it after a winning include', () => {
  const doc = Model.parseDocument('<Multi_key> <a> : "shadowed"\ninclude "later.compose"\n')
  const moved = Model.moveRuleToLocalSection(doc, doc.nodes[0], '<Multi_key> <a> : "override"')
  assert.equal(moved, 'include "later.compose"\n\n# --- Omarchy Compose: local rules ---\n<Multi_key> <a> : "override"\n')
})

test('appends into one marked local section using the document newline style', () => {
  const base = Model.parseDocument('include "%L"\r\n')
  const once = Model.appendLocalRule(base, '<Multi_key> <z> : "Ω"')
  assert.match(once, /# --- Omarchy Compose: local rules ---\r\n/)
  assert.equal((once.match(/Omarchy Compose: local rules/g) || []).length, 1)
  const twice = Model.appendLocalRule(Model.parseDocument(once), '<Multi_key> <y> : "¥"')
  assert.equal((twice.match(/Omarchy Compose: local rules/g) || []).length, 1)
  assert.ok(twice.endsWith('<Multi_key> <y> : "¥"\r\n'))
})

test('encodes result strings and validates complete candidates', () => {
  const rule = Model.encodeRule({ sequence: ['Multi_key', 'q'], resultString: '"\\\t\n', comment: 'symbols' }, '\n')
  assert.equal(rule, '<Multi_key> <q> : "\\"\\\\\\x09\\x0a" # symbols\n')
  assert.equal(Model.validateCandidate(rule).valid, true)
  assert.equal(Model.validateCandidate('<Multi_key> <q> : "unterminated\n').valid, false)
})

test('search ranking is deterministic and respects active/source filters', () => {
  const doc = Model.parseDocument([
    '<Multi_key> <a> : "alpha" # first',
    '<Multi_key> <b> : "alphabet" # second',
    '<Multi_key> <c> : "beta" # alpha label'
  ].join('\n') + '\n', { sourceId: 'mine' })
  const library = Model.resolveEffectiveLibrary([{ kind: 'Mine', name: 'Personal', document: doc }])
  assert.deepEqual(Model.searchRules(library.rules, 'alpha').map(rule => rule.output), ['alpha', 'alphabet', 'beta'])
  assert.deepEqual(Model.searchRules(library.rules, 'mka').map(rule => rule.output), ['alpha'])
  assert.equal(Model.searchRules(library.rules, '', { limit: 2 }).length, 2)
  assert.equal(Model.searchRules(library.rules, '', { source: 'System' }).length, 0)
  library.rules[0].resultKeysym = 'eacute'
  assert.equal(Model.searchRules(library.rules, 'eacute')[0], library.rules[0])
})

test('Quick grouping collapses identical outputs but retains all Studio rules', () => {
  const rule = (index, output, sourceKind, sequence) => ({
    id: `rule:${index}`, order: index, active: true, insertable: true,
    output, sourceKind, sourceName: sourceKind, sequence,
    displaySequence: sequence.map(key => `<${key}>`).join(' '),
    comment: '', resultKeysym: '', path: `/${sourceKind.toLowerCase()}`
  })
  const rules = [
    rule(0, 'ä', 'System', ['Multi_key', 'a']),
    rule(1, 'ä', 'Omarchy', ['Multi_key', 'b']),
    rule(2, 'ä', 'Mine', ['Multi_key', 'c']),
    rule(3, 'Ω', 'System', ['Multi_key', 'o'])
  ]

  const studio = Model.searchRules(rules, '', { limit: 20 })
  assert.equal(studio.length, 4)

  const quick = Model.searchRules(rules, '', { groupOutputs: true, limit: 20 })
  assert.equal(quick.length, 2)
  assert.equal(quick[0].output, 'ä')
  assert.equal(quick[0].sourceKind, 'Mine')
  assert.equal(quick[0].alternativeCount, 2)
  assert.equal(rules[2].alternativeCount, undefined)

  const sequenceMatch = Model.searchRules(rules, 'Multi_key b', { groupOutputs: true, limit: 20 })
  assert.equal(sequenceMatch[0].sourceKind, 'Omarchy')
  assert.equal(sequenceMatch[0].alternativeCount, 2)
})

test('Quick grouping applies its result limit after collapsing outputs', () => {
  const rules = []
  for (let index = 0; index < 205; index++) rules.push({
    id: `same:${index}`, order: index, active: true, insertable: true,
    output: 'same', sourceKind: 'System', sourceName: 'System',
    sequence: ['Multi_key', `U${index.toString(16)}`], displaySequence: `<Multi_key> <U${index.toString(16)}>`,
    comment: '', resultKeysym: '', path: '/system'
  })
  rules.push({
    id: 'other', order: 205, active: true, insertable: true,
    output: 'other', sourceKind: 'System', sourceName: 'System',
    sequence: ['Multi_key', 'o'], displaySequence: '<Multi_key> <o>',
    comment: '', resultKeysym: '', path: '/system'
  })
  const quick = Model.searchRules(rules, '', { groupOutputs: true, limit: 2 })
  assert.deepEqual(quick.map(rule => rule.output), ['same', 'other'])
  assert.equal(quick[0].alternativeCount, 204)
})

test('Quick can exclude outputs owned by Omarchy emoji picker without affecting Studio', () => {
  const emojiOutputs = Model.parseEmojiOutputs(JSON.stringify([
    { e: '😀', k: 'grinning face' },
    { e: '👨‍👩‍👧‍👦', k: 'family' },
    { e: '__proto__', k: 'lookup edge case' }
  ]))
  const rules = [
    { id: 'emoji', active: true, insertable: true, output: '😀', sourceKind: 'System', sequence: ['Multi_key', 'e'] },
    { id: 'family', active: true, insertable: true, output: '👨‍👩‍👧‍👦', sourceKind: 'System', sequence: ['Multi_key', 'f'] },
    { id: 'symbol', active: true, insertable: true, output: '©', sourceKind: 'System', sequence: ['Multi_key', 'c'] },
    { id: 'edge', active: true, insertable: true, output: '__proto__', sourceKind: 'System', sequence: ['Multi_key', 'p'] }
  ]

  assert.deepEqual(Model.searchRules(rules, '', { excludeOutputs: emojiOutputs }).map(rule => rule.output), ['©'])
  assert.deepEqual(Model.searchRules(rules, '').map(rule => rule.output), ['😀', '👨‍👩‍👧‍👦', '©', '__proto__'])
  assert.deepEqual(Model.parseEmojiOutputs('{broken'), {})
})

test('shadow filtering defaults active and can reveal conflicts', () => {
  const doc = Model.parseDocument('<Multi_key> <d> : "old"\n<Multi_key> <d> : "new"\n')
  const library = Model.resolveEffectiveLibrary([{ kind: 'Mine', document: doc }])
  assert.deepEqual(Model.searchRules(library.rules, '').map(rule => rule.output), ['new'])
  assert.deepEqual(Model.searchRules(library.rules, '', { includeShadowed: true }).map(rule => rule.output), ['new', 'old'])
  assert.equal(Model.searchRules(library.rules, '', { includeShadowed: true, source: 'Conflicts' }).length, 2)
})

test('renders invisible outputs without changing their insertion value', () => {
  const exact = ' \t\n\u200b\u00a0'
  assert.equal(Model.invisiblePreview(exact), '␠⇥↵\nZWSPNBSP')
  assert.equal(exact, ' \t\n\u200b\u00a0')
  assert.equal(Model.invisiblePreview(''), '∅')
})

test('include substitution and source classification cover all origins', () => {
  assert.equal(Model.expandIncludePath('%%/%H/%L/%S', { home: '/home/me', localeCompose: '/locale/Compose', system: '/system' }), '%//home/me//locale/Compose//system')
  assert.equal(Model.classifySource('/home/me/.XCompose', '/home/me/.XCompose', '/opt/omarchy'), 'Mine')
  assert.equal(Model.classifySource('/opt/omarchy/default/xcompose', '/home/me/.XCompose', '/opt/omarchy'), 'Omarchy')
  assert.equal(Model.classifySource('/usr/share/X11/locale/en_US.UTF-8/Compose', '/home/me/.XCompose', '/opt/omarchy'), 'System')
  assert.equal(Model.classifySource('/home/me/shared.compose', '/home/me/.XCompose', '/opt/omarchy'), 'Included')
})

test('resolves nested includes in place while isolating missing files and cycles', () => {
  const rootPath = path.join(__dirname, 'fixtures/root.compose')
  const firstPath = path.join(__dirname, 'fixtures/nested/first.compose')
  const secondPath = path.join(__dirname, 'fixtures/nested/second.compose')
  const sources = [rootPath, firstPath, secondPath].map(sourcePath => ({ path: sourcePath, raw: fs.readFileSync(sourcePath, 'utf8') }))
  const graph = Model.resolveSourceGraph(sources, rootPath, { home: '/home/test', localeCompose: '/locale/Compose', system: '/system' })
  assert.deepEqual(graph.activeRules.map(rule => rule.output), ['included-override', 'second', 'root-after'])
  assert.ok(graph.diagnostics.some(item => item.kind === 'include-cycle'))
  assert.ok(graph.diagnostics.some(item => item.kind === 'missing-include'))
  assert.ok(graph.diagnostics.some(item => item.kind === 'override'))
  assert.equal(graph.sources.length, 3)
})

test('unreadable root metadata becomes a blocking source diagnostic', () => {
  const rootPath = '/home/test/.XCompose'
  const graph = Model.resolveSourceGraph([
    { path: rootPath, raw: 'include "%L"\n', unreadableRoot: true },
    { path: '/locale/Compose', raw: '<Multi_key> <a> : "a"\n' }
  ], rootPath, { home: '/home/test', localeCompose: '/locale/Compose', system: '/system' })
  assert.ok(graph.diagnostics.some(item => item.kind === 'unreadable-root' && item.severity === 'error'))
})

test('graph reload conflicts depend on root bytes, not included-source changes', () => {
  const rootPath = '/home/test/.XCompose'
  const graph = (digest, includedDigest) => ({
    rootPath,
    sources: [
      { path: rootPath, digest },
      { path: '/home/test/included.compose', digest: includedDigest }
    ]
  })
  assert.equal(Model.rootContentChanged(graph('same', 'included-before'), graph('same', 'included-after')), false)
  assert.equal(Model.rootContentChanged(graph('before', 'included'), graph('after', 'included')), true)
  assert.equal(Model.rootContentChanged(graph('', 'included'), graph('', 'included')), true)
  assert.equal(Model.rootContentChanged(graph('same', 'included'), { ...graph('same', 'included'), rootPath: '/home/test/retargeted' }), true)
})

test('maps recorder keys and chooses replacement/override actions', () => {
  assert.deepEqual(Model.mapQtKey(0x01000004, '', 0), { keysym: 'Return', modifiers: 0, valid: true })
  assert.equal(Model.mapQtKey(0, ';', 0).keysym, 'semicolon')
  assert.equal(Model.mapQtKey(0, '/', 0).keysym, 'slash')
  assert.equal(Model.mapQtKey(0, 'é', 0).keysym, 'eacute')
  assert.deepEqual(Model.mapQtKey(0x41, '\x01', 0x04000000), { keysym: 'a', modifiers: 0x04000000, valid: true })
  assert.equal(Model.qtModifiersToCompose(0x04000000 | 0x02000000 | 0x08000000), 'Ctrl Shift Alt')
  assert.equal(Model.qtModifiersToCompose(0x10000000), 'Meta')
  const mine = { sequence: ['Multi_key', 'a'], sourceKind: 'Mine' }
  const included = { sequence: ['Multi_key', 'b'], sourceKind: 'System' }
  const shadowed = { sequence: ['Multi_key', 'c'], sourceKind: 'Mine', active: false }
  mine.active = true
  included.active = true
  assert.equal(Model.findSequenceConflict([mine], mine.sequence).action, 'replace')
  assert.equal(Model.findSequenceConflict([included], included.sequence).action, 'override')
  assert.equal(Model.findSequenceConflict([mine], ['Multi_key', 'z']).action, 'append')
  assert.equal(Model.findSequenceConflict([shadowed], shadowed.sequence).action, 'append')
})

test('normalizes shortcuts into Hyprland chord identities', () => {
  assert.deepEqual(Model.shortcutChord('SUPER + CTRL + SEMICOLON'), { modmask: 68, key: 'SEMICOLON' })
  assert.deepEqual(Model.shortcutChord(''), { modmask: 0, key: '' })
})
