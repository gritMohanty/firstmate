#!/usr/bin/env node
// Usage: node fm-subscription-exec.mjs EXECUTABLE [ARG...]
// Reapply the managed environment policy inside the terminal daemon boundary.
// A daemon may have inherited Cursor's memory-only credential store and worker
// identity from an unrelated session; the supervisor's preflight cannot see it.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { spawn } from 'node:child_process';
try {
  const file = process.env.GRIT_SUBSCRIPTION_POLICY_FILE;
  if (!path.isAbsolute(file || '')) throw new Error('Managed launch requires an absolute policy file');
  const policy = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!path.isAbsolute(policy.module || '')) throw new Error('Managed launch requires an absolute policy module');
  const { firstmateEnvironment } = await import(pathToFileURL(policy.module).href);
  const [executable, ...args] = process.argv.slice(2);
  if (!executable) throw new Error('Managed launch requires an executable');
  const child = spawn(executable, args, { env: firstmateEnvironment(process.env), stdio: 'inherit' });
  for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(signal, () => child.kill(signal));
  child.on('error', error => { process.stderr.write(`Managed launch: ${error.message}\n`); process.exitCode = 1; });
  child.on('exit', (code, signal) => { process.exitCode = code ?? (signal === 'SIGINT' ? 130 : 1); });
} catch (error) {
  process.stderr.write(`Managed launch: ${error.message}\n`);
  process.exitCode = 1;
}
