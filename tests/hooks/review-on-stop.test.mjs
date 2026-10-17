import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readdirSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import { decide } from "../../hooks/review-on-stop.mjs";
import { isCodeFile, record } from "../../hooks/track-edits.mjs";

const HOOKS = fileURLToPath(new URL("../../hooks/", import.meta.url));

function run(script, event, env) {
  const res = spawnSync(process.execPath, [join(HOOKS, script)], {
    input: JSON.stringify(event),
    env: { ...process.env, ...env },
    encoding: "utf8",
  });
  assert.equal(res.status, 0, res.stderr);
  return res.stdout;
}

function sandbox(extra = {}) {
  const data = mkdtempSync(join(tmpdir(), "plumbline-hook-"));
  return { CLAUDE_PLUGIN_DATA: data, CLAUDE_PLUGIN_OPTION_REVIEW_ON_STOP: "true", ...extra };
}

const write = (path, lines, type = "update") => ({
  session_id: "s1",
  tool_name: "Write",
  tool_input: { file_path: path, content: Array(lines).fill("x").join("\n") },
  tool_response: { filePath: path, type },
});
const stop = (active = false) => ({ session_id: "s1", stop_hook_active: active });

test("isCodeFile skips docs, config, generated and vendored paths", () => {
  assert.ok(isCodeFile("src/api.ts"));
  assert.ok(isCodeFile("crates/core/src/lib.rs"));
  for (const p of ["README.md", "package.json", "Cargo.lock", "ci.yml", "dist/app.js", "node_modules/x/i.js", "types.d.ts", "a.min.js"]) {
    assert.ok(!isCodeFile(p), p);
  }
});

test("record sums lines per file and marks created files", () => {
  let s = { files: {} };
  s = record(s, "Edit", { file_path: "a.py", new_string: "1\n2\n3" });
  s = record(s, "Edit", { file_path: "a.py", new_string: "4" });
  s = record(s, "Write", { file_path: "b.py", content: "x" }, { type: "create" });
  s = record(s, "MultiEdit", { file_path: "c.py", edits: [{ new_string: "1\n2" }, { new_string: "3" }] });
  assert.deepEqual(s.files["a.py"], { lines: 4, created: false });
  assert.deepEqual(s.files["b.py"], { lines: 1, created: true });
  assert.equal(s.files["c.py"].lines, 3);
});

test("decide stays quiet below the threshold and asks above it or on a new file", () => {
  assert.equal(decide({ files: {} }, 80), null);
  assert.equal(decide({ files: { "a.py": { lines: 79, created: false } } }, 80), null);
  const big = decide({ files: { "a.py": { lines: 80, created: false } } }, 80);
  assert.equal(big.decision, "block");
  assert.match(big.reason, /red-flags/);
  assert.match(big.reason, /a\.py/);
  assert.equal(decide({ files: { "n.py": { lines: 3, created: true } } }, 80).decision, "block");
});

test("disabled option: tracks nothing and never blocks", () => {
  const env = sandbox({ CLAUDE_PLUGIN_OPTION_REVIEW_ON_STOP: "false" });
  run("track-edits.mjs", write("big.py", 500, "create"), env);
  assert.ok(!existsSync(join(env.CLAUDE_PLUGIN_DATA, "turns")));
  assert.equal(run("review-on-stop.mjs", stop(), env), "");
});

test("enabled: a large turn blocks once, then state is cleared", () => {
  const env = sandbox();
  run("track-edits.mjs", write("big.py", 120), env);
  const out = JSON.parse(run("review-on-stop.mjs", stop(), env));
  assert.equal(out.decision, "block");
  assert.match(out.reason, /big\.py/);
  assert.equal(readdirSync(join(env.CLAUDE_PLUGIN_DATA, "turns")).length, 0);
  assert.equal(run("review-on-stop.mjs", stop(), env), "", "second Stop in the same turn must not block again");
});

test("enabled: stop_hook_active never blocks and still clears state", () => {
  const env = sandbox();
  run("track-edits.mjs", write("big.py", 120), env);
  assert.equal(run("review-on-stop.mjs", stop(true), env), "");
  assert.equal(readdirSync(join(env.CLAUDE_PLUGIN_DATA, "turns")).length, 0);
});

test("enabled: small edits and non-code files do not block", () => {
  const env = sandbox();
  run("track-edits.mjs", write("small.py", 10), env);
  run("track-edits.mjs", write("README.md", 400), env);
  assert.equal(run("review-on-stop.mjs", stop(), env), "");
});

test("threshold option is honored", () => {
  const env = sandbox({ CLAUDE_PLUGIN_OPTION_REVIEW_THRESHOLD_LINES: "10" });
  run("track-edits.mjs", write("mid.py", 12), env);
  assert.equal(JSON.parse(run("review-on-stop.mjs", stop(), env)).decision, "block");
});

test("garbage on stdin is ignored", () => {
  const env = sandbox();
  const res = spawnSync(process.execPath, [join(HOOKS, "review-on-stop.mjs")], { input: "not json", env: { ...process.env, ...env }, encoding: "utf8" });
  assert.equal(res.status, 0);
  assert.equal(res.stdout, "");
});
