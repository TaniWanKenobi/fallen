// Runs git for GitRemote inside a throwaway Vercel Sandbox (a Firecracker microVM with nothing of ours in it), so a
// hostile repository server that breaks git gets an empty VM instead of the worker and its secrets.
//
// Usage: node script/git_sandbox.mjs <host>
// Credentials come from VERCEL_SANDBOX_TOKEN, VERCEL_SANDBOX_TEAM_ID and VERCEL_SANDBOX_PROJECT_ID. The sandbox may
// only reach <host>, and never a private address. GitRemote then sends one JSON request per line on stdin:
//   { "cmd": "git", "args": [...], "cwd": "/tmp/repo", "env": {...}, "timeoutSeconds": 40, "maxFileBytes": 67108864 }
// and gets one JSON line back for each: { "exitCode": 0, "stdout": "<base64>", "stderr": "..." } or { "error": "..." }.
// The first line out is { "ready": true, "dir": "/tmp/repo" } once the sandbox is up, naming an empty folder to work in. Closing stdin stops and deletes the sandbox.
import { createInterface } from 'node:readline'
import { Sandbox } from '@vercel/sandbox'

const PRIVATE_RANGES = [
  '0.0.0.0/8',
  '10.0.0.0/8',
  '100.64.0.0/10',
  '127.0.0.0/8',
  '169.254.0.0/16',
  '172.16.0.0/12',
  '192.0.0.0/24',
  '192.168.0.0/16',
  '198.18.0.0/15',
  '224.0.0.0/4',
  '240.0.0.0/4',
]
const OUT = '/tmp/git-sandbox-stdout'
const WORKDIR = '/tmp/repo'

const host = process.argv[2]
const send = (message) => process.stdout.write(`${JSON.stringify(message)}\n`)

let sandbox
async function shutdown(code) {
  const current = sandbox
  sandbox = null
  if (current) {
    await current.stop().catch(() => {})
    await current.delete({ deleteOrphanSnapshots: true }).catch(() => {})
  }
  process.exit(code)
}

async function run({ cmd, args = [], cwd, env = {}, timeoutSeconds = 40, maxFileBytes }) {
  // `ulimit -f` caps what the command can write (its stdout file included), `timeout` kills it, and its stdout comes
  // back base64'd so binary output (a file read with cat-file) arrives byte for byte: the SDK hands stdout back as
  // text, in the same round trip as the run.
  const script = [
    maxFileBytes ? `ulimit -f ${Math.ceil(maxFileBytes / 1024)}` : null,
    'timeout -s KILL "$0" "$@" > "$OUT_FILE"',
    'code=$?',
    'base64 -w0 "$OUT_FILE"',
    'exit $code',
  ]
  const result = await sandbox.runCommand({
    cmd: 'bash',
    args: ['-c', script.filter(Boolean).join('\n'), String(timeoutSeconds), cmd, ...args],
    cwd,
    env: { ...env, OUT_FILE: OUT },
    signal: AbortSignal.timeout((timeoutSeconds + 15) * 1000),
  })
  const [stdout, stderr] = await Promise.all([result.stdout(), result.stderr()])
  return { exitCode: result.exitCode, stdout: stdout.trim(), stderr }
}

async function main() {
  if (!host || !/^[a-z0-9.-]+$/.test(host)) throw new Error('Pass the repository host')
  sandbox = await Sandbox.create({
    token: process.env.VERCEL_SANDBOX_TOKEN,
    teamId: process.env.VERCEL_SANDBOX_TEAM_ID,
    projectId: process.env.VERCEL_SANDBOX_PROJECT_ID,
    region: process.env.VERCEL_SANDBOX_REGION || 'iad1',
    resources: { vcpus: 1 },
    timeout: 10 * 60 * 1000,
    persistent: false,
    networkPolicy: { allow: [host], subnets: { deny: PRIVATE_RANGES } },
    tags: { app: 'fallen', use: 'git-remote' },
    signal: AbortSignal.timeout(60_000),
  })
  await sandbox.runCommand('mkdir', ['-p', WORKDIR])
  send({ ready: true, dir: WORKDIR })

  // One command at a time, in order: GitRemote waits for each answer before sending the next.
  const lines = createInterface({ input: process.stdin, crlfDelay: Infinity })
  for await (const line of lines) {
    if (!line.trim()) continue
    try {
      send(await run(JSON.parse(line)))
    } catch (error) {
      send({ error: String(error?.message ?? error) })
    }
  }
  await shutdown(0)
}

process.on('SIGTERM', () => shutdown(143))
main().catch(async (error) => {
  send({ error: String(error?.message ?? error) })
  await shutdown(1)
})
