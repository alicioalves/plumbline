// PostToolUse (Edit|Write|MultiEdit): record which code files this turn touched
// and how many lines it wrote, so review-on-stop.mjs can decide whether the turn
// changed enough to deserve a design check. Never blocks, never prints.
import { pathToFileURL } from "node:url";
import { isEnabled, readState, readStdinJson, writeState } from "./lib/state.mjs";

const NOT_CODE = /\.(md|mdx|txt|json|jsonc|lock|ya?ml|toml|ini|cfg|csv|svg|png|jpe?g|gif|ico|snap)$/i;
const SKIP_DIRS = /(^|[\\/])(node_modules|target|dist|build|\.next|vendor|__pycache__|\.git)([\\/]|$)/;
const GENERATED = /(\.min\.|\.generated\.|\.pb\.|_pb2\.py$|\.d\.ts$)/i;

export function isCodeFile(path) {
  return Boolean(path) && !NOT_CODE.test(path) && !SKIP_DIRS.test(path) && !GENERATED.test(path);
}

function countLines(text) {
  return text ? String(text).split("\n").length : 0;
}

export function linesWritten(toolName, input) {
  if (toolName === "Write") return countLines(input.content);
  if (toolName === "MultiEdit") return (input.edits ?? []).reduce((n, e) => n + countLines(e.new_string), 0);
  return countLines(input.new_string);
}

export function record(state, toolName, input, response) {
  const path = input?.file_path;
  if (!isCodeFile(path)) return state;
  const entry = state.files[path] ?? { lines: 0, created: false };
  entry.lines += linesWritten(toolName, input);
  if (toolName === "Write" && response?.type === "create") entry.created = true;
  state.files[path] = entry;
  return state;
}

async function main() {
  if (!isEnabled()) return;
  const event = await readStdinJson();
  if (!event.session_id) return;
  const state = record(readState(event.session_id), event.tool_name, event.tool_input ?? {}, event.tool_response);
  writeState(event.session_id, state);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(() => {}); // a tracking failure must never break the user's edit
}
