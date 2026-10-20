// Shared state for the review-on-stop hooks: which code files the current turn
// edited and how many lines it wrote. One JSON file per session under
// CLAUDE_PLUGIN_DATA, written by track-edits.mjs and consumed by review-on-stop.mjs.
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

export function isEnabled(env = process.env) {
  const v = String(env.CLAUDE_PLUGIN_OPTION_REVIEW_ON_STOP ?? "").toLowerCase();
  return v === "true" || v === "1";
}

export function thresholdLines(env = process.env) {
  const n = Number(env.CLAUDE_PLUGIN_OPTION_REVIEW_THRESHOLD_LINES);
  return Number.isFinite(n) && n > 0 ? n : 80;
}

function statePath(sessionId, env) {
  const dir = join(env.CLAUDE_PLUGIN_DATA || join(env.HOME || env.USERPROFILE || ".", ".plumbline"), "turns");
  // session ids are uuids; keep the file name safe whatever arrives on stdin
  return { dir, file: join(dir, `${String(sessionId).replace(/[^A-Za-z0-9_-]/g, "_")}.json`) };
}

export function readState(sessionId, env = process.env) {
  try {
    return JSON.parse(readFileSync(statePath(sessionId, env).file, "utf8"));
  } catch {
    return { files: {} };
  }
}

export function writeState(sessionId, state, env = process.env) {
  const { dir, file } = statePath(sessionId, env);
  mkdirSync(dir, { recursive: true });
  writeFileSync(file, JSON.stringify(state));
}

export function clearState(sessionId, env = process.env) {
  rmSync(statePath(sessionId, env).file, { force: true });
}

export async function readStdinJson() {
  let raw = "";
  for await (const chunk of process.stdin) raw += chunk;
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}
