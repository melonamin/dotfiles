const test = require('node:test')
const assert = require('node:assert/strict')
const Model = require('../Model.js')

test('normalizes behavior settings and supported item types', () => {
  const config = Model.normalizeConfig({
    version: 1,
    screens: ['*', '*', 'DP-1'],
    openDelay: -3,
    closeDelay: 9000,
    layer: 'overlay',
    iconSize: 99,
    items: [
      { type: 'app', desktopId: 'firefox.desktop' },
      { type: 'separator' },
      { type: 'folder', path: '~/Downloads' }
    ]
  })

  assert.deepEqual(config.screens, ['*', 'DP-1'])
  assert.equal(config.openDelay, 0)
  assert.equal(config.closeDelay, 3000)
  assert.equal(config.layer, 'overlay')
  assert.equal(config.iconSize, 64)
  assert.equal(config.items[0].desktopId, 'firefox')
  assert.equal(config.items[2].path, '~/Downloads')
})

test('keeps invalid individual entries as disabled placeholders', () => {
  const config = Model.normalizeConfig({
    version: 1,
    items: [null, { type: 'app' }, { type: 'folder' }, { type: 'mystery', name: 'Odd' }]
  })

  assert.deepEqual(config.items.map(item => item.type), ['invalid', 'invalid', 'invalid', 'invalid'])
  assert.match(config.items[1].reason, /requires desktopId/)
  assert.match(config.items[2].reason, /requires path/)
  assert.equal(config.items[3].name, 'Odd')
})

test('retains the last valid model when a reload is malformed', () => {
  const lastValid = Model.normalizeConfig({ version: 1, items: [{ type: 'app', desktopId: 'firefox' }] })
  const result = Model.loadConfig('{broken', lastValid, Model.safeDefaultConfig('/home/test'))

  assert.equal(result.valid, false)
  assert.match(result.error, /JSON/)
  assert.deepEqual(result.value, lastValid)
})

test('uses a safe folder-only default on malformed cold start', () => {
  const fallback = Model.safeDefaultConfig('/home/test')
  const result = Model.loadConfig('{}', null, fallback)

  assert.equal(result.valid, false)
  assert.match(result.error, /version must be 1/)
  assert.deepEqual(result.value.items.map(item => item.type), ['folder', 'folder'])
})

test('starter configuration chooses at most one installed app per role', () => {
  const result = Model.starterConfig([
    { id: 'com.mitchellh.ghostty' },
    { id: 'kitty' },
    { id: 'firefox' },
    { id: 'org.gnome.Nautilus' },
    { id: 'dev.zed.Zed' }
  ], '/home/test')

  assert.deepEqual(result.items.slice(0, 4).map(item => item.desktopId), [
    'com.mitchellh.ghostty',
    'firefox',
    'org.gnome.Nautilus',
    'dev.zed.Zed'
  ])
  assert.equal(result.items[4].type, 'separator')
  assert.deepEqual(result.items.slice(-2).map(item => item.path), ['~', '~/Downloads'])
})

test('resolves desktop metadata and home-relative folder paths', () => {
  const config = Model.normalizeConfig({
    version: 1,
    items: [
      { type: 'app', desktopId: 'firefox' },
      { type: 'app', desktopId: 'missing' },
      { type: 'folder', path: '~/Downloads' }
    ]
  })
  const resolved = Model.resolveItems(config, [
    { id: 'firefox', name: 'Firefox', icon: 'firefox', startupClass: 'firefox' }
  ], '/home/test')

  assert.deepEqual(resolved[0], {
    type: 'app', desktopId: 'firefox', name: 'Firefox', icon: '', key: 'app:0',
    available: true, entryIcon: 'firefox', startupClass: 'firefox'
  })
  assert.equal(resolved[1].available, false)
  assert.match(resolved[1].reason, /not installed/)
  assert.equal(resolved[2].path, '/home/test/Downloads')
})

test('matches running applications by desktop ID or startup class only', () => {
  const item = { type: 'app', desktopId: 'dev.zed.Zed', startupClass: 'zed' }
  assert.equal(Model.toplevelMatches(item, 'dev.zed.Zed'), true)
  assert.equal(Model.toplevelMatches(item, 'zed'), true)
  assert.equal(Model.toplevelMatches(item, 'zed-preview'), false)
  assert.equal(Model.toplevelMatches({ type: 'folder' }, 'zed'), false)
})

test('applies explicit monitor selection', () => {
  assert.equal(Model.screenEnabled(['*'], 'DP-1'), true)
  assert.equal(Model.screenEnabled(['DP-1'], 'DP-1'), true)
  assert.equal(Model.screenEnabled(['DP-1'], 'HDMI-A-1'), false)
})
