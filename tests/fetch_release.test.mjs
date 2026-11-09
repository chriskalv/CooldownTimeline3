import { test } from 'node:test';
import assert from 'node:assert/strict';
import { versionOf, pickFile, cdnUrl, parseArgs } from '../tools/fetch_release.mjs';

const files = [
  { id: 9388477, name: 'CooldownTimeline3-v3.0.12.zip', display: 'v3.0.12', type: 'release', filesize: 2235025, uploaded_at: '2026-10-31T20:35:35.083Z' },
  { id: 9378998, name: 'CooldownTimeline3-v3.0.11.zip', display: 'v3.0.11', type: 'release', filesize: 2228816, uploaded_at: '2026-10-31T00:16:31.323Z' },
  { id: 9400001, name: 'CooldownTimeline3-v3.0.13-beta.zip', display: 'v3.0.13 beta', type: 'beta', filesize: 1, uploaded_at: '2026-11-05T00:00:00.000Z' },
];

test('versionOf reads the version from display or name', () => {
  assert.equal(versionOf(files[0]), '3.0.12');
  assert.equal(versionOf({ name: 'CooldownTimeline3-v3.0.9.zip' }), '3.0.9');
  assert.equal(versionOf({ display: 'latest' }), null);
});

test('pickFile takes the newest release, never a beta', () => {
  assert.equal(pickFile(files).id, 9388477);
  assert.equal(pickFile([files[1], files[0], files[2]]).id, 9388477);
});

test('pickFile finds a release by version, with or without v', () => {
  assert.equal(pickFile(files, '3.0.11').id, 9378998);
  assert.equal(pickFile(files, 'v3.0.11').id, 9378998);
  assert.throws(() => pickFile(files, '3.0.13'), /no release 3\.0\.13; known: 3\.0\.12, 3\.0\.11/);
  assert.throws(() => pickFile([], undefined), /no release files/);
});

test('cdnUrl splits the file id into thousands and remainder', () => {
  assert.equal(cdnUrl(files[0]), 'https://edge.forgecdn.net/files/9388/477/CooldownTimeline3-v3.0.12.zip');
  assert.equal(cdnUrl({ id: 9095040, name: 'a b.zip' }), 'https://edge.forgecdn.net/files/9095/40/a%20b.zip');
  assert.throws(() => cdnUrl({ id: 'x', name: 'a.zip' }), /bad file id/);
});

test('parseArgs reads the options', () => {
  assert.deepEqual(parseArgs([]), { list: false, unpack: false, version: null, out: 'dist', project: 1570576 });
  assert.deepEqual(parseArgs(['--list', '--version', '3.0.11', '--out', 'x', '--unpack']),
    { list: true, unpack: true, version: '3.0.11', out: 'x', project: 1570576 });
  assert.throws(() => parseArgs(['--bogus']), /unknown argument/);
  assert.throws(() => parseArgs(['--version']), /missing value/);
});
