#!/usr/bin/env node
// 版本一致性检查：确保 package.json.version、lib/index.js PLUGIN_VERSION、
// lib/client.js PLUGIN_VERSION 三者一致，防止 0.5.1→0.5.2 那种"只改 package.json
// 漏改 PLUGIN_VERSION"的发布事故。任一不一致即退出码 1。
// 用法：node scripts/check-version.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// 1) package.json version
const pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
const pkgVersion = pkg.version;

// 2) lib/index.js PLUGIN_VERSION
function extractPluginVersion(file) {
  const text = fs.readFileSync(path.join(root, file), "utf8");
  const m = text.match(/PLUGIN_VERSION\s*=\s*["']([^"']+)["']/);
  if (!m) throw new Error(`${file}: cannot find PLUGIN_VERSION`);
  return m[1];
}

const indexVersion = extractPluginVersion("lib/index.js");
const clientVersion = extractPluginVersion("lib/client.js");

const entries = [
  ["package.json", pkgVersion],
  ["lib/index.js", indexVersion],
  ["lib/client.js", clientVersion],
];

const allMatch = new Set(entries.map(([, v]) => v)).size === 1;
console.log("Version check:");
for (const [name, v] of entries) console.log(`  ${name}: ${v}`);

if (!allMatch) {
  console.error("\nFAIL: version mismatch detected — please sync all three to the same version before publishing.");
  process.exit(1);
}
if (!/^\d+\.\d+\.\d+$/.test(pkgVersion)) {
  console.error(`\nFAIL: package.json version "${pkgVersion}" is not valid semver x.y.z`);
  process.exit(1);
}
console.log(`\nOK: all versions consistent (${pkgVersion})`);
