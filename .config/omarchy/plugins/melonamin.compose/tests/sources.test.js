const assert = require('node:assert/strict')
const childProcess = require('node:child_process')
const crypto = require('node:crypto')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const test = require('node:test')

const helper = path.join(__dirname, '..', 'scripts', 'compose-sources')
const Model = require('../ComposeModel.js')

test('readable root digest identifies the exact captured bytes', t => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'omarchy-compose-digest-'))
  t.after(() => fs.rmSync(scratch, { recursive: true, force: true }))
  const root = path.join(scratch, '.XCompose')
  const content = '<Multi_key> <a> : "α"\n'
  fs.writeFileSync(root, content)
  const result = childProcess.spawnSync(helper, ['--root', root, '--omarchy', '/usr/share/omarchy'], {
    encoding: 'utf8',
    env: { ...process.env, LC_ALL: 'en_US.UTF-8' }
  })
  assert.equal(result.status, 0, result.stderr)
  const source = JSON.parse(result.stdout).sources[0]
  assert.equal(Buffer.from(source.contentB64, 'base64').toString(), content)
  assert.equal(source.digest, crypto.createHash('sha256').update(content).digest('hex'))
})

test('bundled keysyms preserve conversion and validation without development headers', t => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'omarchy-compose-bundled-keysyms-'))
  t.after(() => fs.rmSync(scratch, { recursive: true, force: true }))
  const root = path.join(scratch, '.XCompose')
  fs.writeFileSync(root, '<Multi_key> <e> : EuroSign\n')
  const result = childProcess.spawnSync(helper, ['--root', root, '--omarchy', '/usr/share/omarchy'], {
    encoding: 'utf8',
    env: { ...process.env, LC_ALL: 'en_US.UTF-8', COMPOSE_X11_INCLUDE_DIR: path.join(scratch, 'no-headers') }
  })
  assert.equal(result.status, 0, result.stderr)
  const definitions = Model.parseKeysymDefinitions(Buffer.from(JSON.parse(result.stdout).keysymB64, 'base64').toString())
  assert.equal(Model.keysymToUtf8('EuroSign', definitions), '€')
  assert.equal(Model.knownKeysym('XF86AudioMute', definitions), true)
  assert.equal(Model.knownKeysym('DefinitelyNotAKeysym', definitions), false)
})

test('missing include targets remain in the resolved include graph', t => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'omarchy-compose-includes-'))
  t.after(() => fs.rmSync(scratch, { recursive: true, force: true }))
  const root = path.join(scratch, '.XCompose')
  const missing = path.join(scratch, 'later.compose')
  fs.writeFileSync(root, 'include "later.compose"\n')
  const result = childProcess.spawnSync(helper, ['--root', root, '--omarchy', '/usr/share/omarchy'], {
    encoding: 'utf8',
    env: { ...process.env, LC_ALL: 'en_US.UTF-8' }
  })
  assert.equal(result.status, 0, result.stderr)
  const payload = JSON.parse(result.stdout)
  assert.deepEqual(payload.includes[0], { from: root, template: 'later.compose', resolved: missing })
  assert.equal(payload.sources.some(source => source.path === missing), false)
})

test('escaped include paths are decoded before their sources are loaded', t => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'omarchy-compose-escaped-includes-'))
  t.after(() => fs.rmSync(scratch, { recursive: true, force: true }))
  const root = path.join(scratch, '.XCompose')
  const backslashPath = path.join(scratch, 'dir\\name')
  const quotePath = path.join(scratch, 'say"hi')
  fs.writeFileSync(backslashPath, '<Multi_key> <b> : "backslash"\n')
  fs.writeFileSync(quotePath, '<Multi_key> <q> : "quote"\n')
  fs.writeFileSync(root, 'include "dir\\\\name"\ninclude "say\\\"hi"\n')
  const result = childProcess.spawnSync(helper, ['--root', root, '--omarchy', '/usr/share/omarchy'], {
    encoding: 'utf8',
    env: { ...process.env, LC_ALL: 'en_US.UTF-8' }
  })
  assert.equal(result.status, 0, result.stderr)
  const payload = JSON.parse(result.stdout)
  assert.deepEqual(payload.includes.map(item => item.template), ['dir\\name', 'say"hi'])
  assert.ok(payload.sources.some(source => source.path === backslashPath))
  assert.ok(payload.sources.some(source => source.path === quotePath))
})

test('missing roots inherit the aliased locale Compose table', t => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'omarchy-compose-sources-'))
  t.after(() => fs.rmSync(scratch, { recursive: true, force: true }))
  const root = path.join(scratch, '.XCompose')
  const result = childProcess.spawnSync(helper, ['--root', root, '--omarchy', '/usr/share/omarchy'], {
    encoding: 'utf8',
    env: { ...process.env, LC_ALL: 'en_US.utf8' }
  })
  assert.equal(result.status, 0, result.stderr)
  const payload = JSON.parse(result.stdout)
  assert.equal(payload.localeCompose, '/usr/share/X11/locale/en_US.UTF-8/Compose')
  assert.equal(payload.sources[0].path, root)
  assert.equal(payload.sources[0].missingRoot, true)
  assert.equal(payload.sources[0].digest, 'missing')
  assert.equal(Buffer.from(payload.sources[0].contentB64, 'base64').toString(), 'include "%L"\n')
  assert.ok(payload.sources.some(source => source.path === payload.localeCompose))
  assert.deepEqual(payload.includes[0], { from: root, template: '%L', resolved: payload.localeCompose })
})

test('existing unreadable roots are never reported as missing', t => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'omarchy-compose-unreadable-'))
  const root = path.join(scratch, '.XCompose')
  fs.writeFileSync(root, '<Multi_key> <a> : "private"\n')
  fs.chmodSync(root, 0o000)
  t.after(() => {
    fs.chmodSync(root, 0o600)
    fs.rmSync(scratch, { recursive: true, force: true })
  })

  const result = childProcess.spawnSync(helper, ['--root', root, '--omarchy', '/usr/share/omarchy'], {
    encoding: 'utf8',
    env: { ...process.env, LC_ALL: 'en_US.UTF-8' }
  })
  assert.equal(result.status, 0, result.stderr)
  const payload = JSON.parse(result.stdout)
  assert.equal(payload.sources[0].path, root)
  assert.equal(payload.sources[0].unreadableRoot, true)
  assert.notEqual(payload.sources[0].missingRoot, true)
  assert.equal(payload.sources[0].digest, 'unreadable')
  assert.equal(Buffer.from(payload.sources[0].contentB64, 'base64').toString(), 'include "%L"\n')
})
