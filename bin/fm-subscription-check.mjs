#!/usr/bin/env node
// Usage: node bin/fm-subscription-check.mjs HARNESS MODEL EFFORT RAW_LAUNCH
// A configured subscription home validates each concrete spawn through Captain.
// Homes without this opt-in retain upstream behavior. A managed launcher sets
// GRIT_SUBSCRIPTION_POLICY=1 so a missing policy file fails closed.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const config = process.env.GRIT_SUBSCRIPTION_POLICY_FILE || path.join(process.env.FM_HOME || root, 'config', 'subscription-policy.json');
try {
  if (!path.isAbsolute(config)) throw new Error('Subscription policy path must be absolute');
  if (!fs.existsSync(config)) {
    if (process.env.GRIT_SUBSCRIPTION_POLICY === '1') throw new Error('Subscription policy is missing');
  } else {
    const policy = JSON.parse(fs.readFileSync(config, 'utf8'));
    if (!path.isAbsolute(policy.module || '') || !path.isAbsolute(policy.registry || '')) throw new Error('Subscription policy needs absolute module and registry paths');
    const { checkFirstmateSubscription } = await import(pathToFileURL(policy.module).href);
    const registry = JSON.parse(fs.readFileSync(policy.registry, 'utf8'));
    const [harness, model, effort, raw] = process.argv.slice(2);
    checkFirstmateSubscription(registry, { harness, model, effort, raw: raw === '1' });
  }
} catch (error) {
  process.stderr.write(`Firstmate subscription policy: ${error.message}\n`);
  process.exitCode = 1;
}
