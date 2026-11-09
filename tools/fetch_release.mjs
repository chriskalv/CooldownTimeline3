// Fetches a CDTL3 release zip from CurseForge without a browser.
//
// The project page (www.curseforge.com) refuses automated requests, but the
// public widget API (api.cfwidget.com) lists the project's files, and the
// files themselves are served by the CurseForge CDN (edge.forgecdn.net).
//
//   node tools/fetch_release.mjs --list              list the released files
//   node tools/fetch_release.mjs                     download the newest release to dist/
//   node tools/fetch_release.mjs --version 3.0.11    download that release
//   node tools/fetch_release.mjs --out <dir>         download to another directory
//   node tools/fetch_release.mjs --unpack            also unpack it to <out>/<version>/
//
// Node 22, built-ins only. The downloaded file is checked against the size
// the API reports; its SHA-256 is printed so the commit on branch `upstream`
// can cite it. Behind an HTTPS proxy the script restarts itself once with
// NODE_USE_ENV_PROXY=1, because fetch ignores HTTPS_PROXY otherwise.

import { createHash } from 'node:crypto';
import { mkdir, writeFile, rm } from 'node:fs/promises';
import { execFileSync, spawnSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const PROJECT_ID = 1570576; // Cooldown Timeline 3 (CDTL3)
export const WIDGET_API = 'https://api.cfwidget.com/';
export const CDN = 'https://edge.forgecdn.net/files/';

/** Version "3.0.12" from a file name "CooldownTimeline3-v3.0.12.zip" or display "v3.0.12". */
export function versionOf(file) {
  for (const text of [file.display, file.name]) {
    const m = /v(\d+(?:\.\d+)+)/.exec(text ?? '');
    if (m) return m[1];
  }
  return null;
}

/** The newest release, or the release with the given version. Throws when nothing matches. */
export function pickFile(files, version) {
  const releases = (files ?? []).filter((f) => f.type === 'release');
  if (version) {
    const wanted = version.replace(/^v/, '');
    const hit = releases.find((f) => versionOf(f) === wanted);
    if (!hit) throw new Error(`no release ${wanted}; known: ${releases.map(versionOf).join(', ')}`);
    return hit;
  }
  if (releases.length === 0) throw new Error('the project has no release files');
  return releases.reduce((a, b) => (Date.parse(b.uploaded_at) > Date.parse(a.uploaded_at) ? b : a));
}

/** Direct CDN URL of a file: files/<id div 1000>/<id mod 1000>/<name>. */
export function cdnUrl(file) {
  const id = Number(file.id);
  if (!Number.isInteger(id) || id <= 0) throw new Error(`bad file id ${file.id}`);
  return `${CDN}${Math.floor(id / 1000)}/${id % 1000}/${encodeURIComponent(file.name)}`;
}

export function parseArgs(argv) {
  const opts = { list: false, unpack: false, version: null, out: 'dist', project: PROJECT_ID };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--list') opts.list = true;
    else if (a === '--unpack') opts.unpack = true;
    else if (a === '--version') opts.version = argv[++i];
    else if (a === '--out') opts.out = argv[++i];
    else if (a === '--project') opts.project = Number(argv[++i]);
    else throw new Error(`unknown argument ${a}`);
  }
  if (opts.version === undefined || opts.out === undefined) throw new Error('missing value');
  return opts;
}

async function fetchJson(url) {
  const res = await fetch(url, { headers: { accept: 'application/json' } });
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return res.json();
}

export async function main(argv = process.argv.slice(2)) {
  const opts = parseArgs(argv);
  const project = await fetchJson(`${WIDGET_API}${opts.project}`);
  if (opts.list) {
    for (const f of project.files ?? []) {
      console.log(`${versionOf(f) ?? '?'}\t${f.type}\t${f.uploaded_at}\t${f.filesize}\t${f.name}`);
    }
    return;
  }
  const file = pickFile(project.files, opts.version);
  const version = versionOf(file);
  const url = cdnUrl(file);
  console.log(`${project.title}: release ${version}, file ${file.id} (${file.uploaded_at})`);
  console.log(url);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  const bytes = Buffer.from(await res.arrayBuffer());
  if (bytes.length !== file.filesize) {
    throw new Error(`size mismatch: got ${bytes.length} bytes, the API reports ${file.filesize}`);
  }
  await mkdir(opts.out, { recursive: true });
  const target = path.join(opts.out, file.name);
  await writeFile(target, bytes);
  const sha = createHash('sha256').update(bytes).digest('hex');
  console.log(`${target}: ${bytes.length} bytes, sha256 ${sha}`);
  if (opts.unpack) {
    const dir = path.join(opts.out, version);
    await rm(dir, { recursive: true, force: true });
    await mkdir(dir, { recursive: true });
    execFileSync('unzip', ['-q', '-o', target, '-d', dir], { stdio: 'inherit' });
    console.log(`unpacked to ${dir}/`);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  // Node's fetch ignores HTTPS_PROXY unless NODE_USE_ENV_PROXY=1 (Node >= 22.21):
  // behind a proxy, run once more with it set.
  if (process.env.HTTPS_PROXY && !process.env.NODE_USE_ENV_PROXY && !process.env.FETCH_RELEASE_NO_REEXEC) {
    const run = spawnSync(process.execPath, process.argv.slice(1), {
      stdio: 'inherit',
      env: { ...process.env, NODE_USE_ENV_PROXY: '1', FETCH_RELEASE_NO_REEXEC: '1' },
    });
    process.exit(run.status ?? 1);
  }
  main().catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}
