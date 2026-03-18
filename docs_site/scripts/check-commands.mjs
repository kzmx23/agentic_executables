import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const docsRoot = path.resolve(process.cwd(), "docs");
const requiredCommands = [
  "ae definition",
  "ae doctor",
  "ae instructions --context",
  "ae hub init",
  "ae know build",
];

const requiredSectionsByRoute = new Map([
  ["/get-started/agent.md", ["## Step 1", "## Step 2", "## Step 3"]],
  ["/install/index.md", ["## macOS and Linux", "## Common failure modes"]],
  ["/hub/index.md", ["## Initialize a hub", "## Check hub status", "## Common failure modes"]],
  ["/know/index.md", ["## Build a knowledge pack", "## Common failure modes"]],
]);

async function collectMarkdownFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== ".vitepress") {
        files.push(...(await collectMarkdownFiles(full)));
      }
      continue;
    }
    if (entry.isFile() && entry.name.endsWith(".md")) {
      files.push(full);
    }
  }
  return files;
}

function routeKey(filePath) {
  const rel = path.relative(docsRoot, filePath).replace(/\\/g, "/");
  return `/${rel}`;
}

async function main() {
  const files = await collectMarkdownFiles(docsRoot);
  let joined = "";
  for (const file of files) {
    joined += `${await readFile(file, "utf8")}\n`;
  }

  const missingCommands = requiredCommands.filter((snippet) => !joined.includes(snippet));
  if (missingCommands.length > 0) {
    throw new Error(`Missing required command snippets: ${missingCommands.join(", ")}`);
  }

  for (const file of files) {
    const route = routeKey(file);
    const requirements = requiredSectionsByRoute.get(route);
    if (!requirements) {
      continue;
    }
    const content = await readFile(file, "utf8");
    const missing = requirements.filter((section) => !content.includes(section));
    if (missing.length > 0) {
      throw new Error(
        `Missing required sections in ${route}: ${missing.join(", ")}`,
      );
    }
  }

  process.stdout.write("Command docs validation passed.\n");
}

await main();
