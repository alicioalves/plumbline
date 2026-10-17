// Builds the documentation site into _site/ from the skills themselves, so the
// site can't drift from what the plugin ships. No dependencies: the README's
// "What's Inside" tables give the groups and summaries, each SKILL.md is copied
// as-is and rendered in the browser.
import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = new URL("..", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"); // Windows drive paths
const OUT = join(ROOT, "_site");
const REPO = "https://github.com/tomymaritano/plumbline";

const readme = readFileSync(join(ROOT, "README.md"), "utf8");
const version = JSON.parse(readFileSync(join(ROOT, ".claude-plugin/plugin.json"), "utf8")).version;

// Groups and one-line summaries from README "What's Inside".
const inside = readme.slice(readme.indexOf("## What's Inside"), readme.indexOf("## Attribution"));
const groups = [];
for (const line of inside.split("\n")) {
  const h = line.match(/^### (.+)/);
  if (h) groups.push({ title: h[1].trim(), skills: [] });
  const row = line.match(/^\| `([a-z-]+)` \| (.+) \|$/);
  if (row && groups.length) groups.at(-1).skills.push({ name: row[1], summary: row[2] });
}

const skillDirs = readdirSync(join(ROOT, "skills"));
const listed = new Set(groups.flatMap((g) => g.skills.map((s) => s.name)));
const missing = skillDirs.filter((d) => !listed.has(d));
if (missing.length) throw new Error(`skills missing from README "What's Inside": ${missing.join(", ")}`);

const esc = (s) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const inline = (s) => esc(s).replaceAll(/`([^`]+)`/g, "<code>$1</code>");

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
cpSync(join(ROOT, "skills"), join(OUT, "skills"), { recursive: true });
cpSync(join(ROOT, "scripts/site"), OUT, { recursive: true });

const cards = groups
  .map(
    (g) => `
    <section class="group">
      <h2>${esc(g.title)}</h2>
      <div class="grid">${g.skills
        .map(
          (s) => `
        <a class="card" href="skill.html?name=${s.name}">
          <span class="name">${s.name}</span>
          <span class="summary">${inline(s.summary)}</span>
        </a>`,
        )
        .join("")}
      </div>
    </section>`,
  )
  .join("");

const index = readFileSync(join(ROOT, "scripts/site/index.template.html"), "utf8")
  .replaceAll("{{VERSION}}", version)
  .replaceAll("{{REPO}}", REPO)
  .replace("{{SKILLS}}", cards);
writeFileSync(join(OUT, "index.html"), index);
rmSync(join(OUT, "index.template.html"));
writeFileSync(join(OUT, ".nojekyll"), "");

console.log(`site: ${listed.size} skills in ${groups.length} groups, v${version} -> ${OUT}`);
