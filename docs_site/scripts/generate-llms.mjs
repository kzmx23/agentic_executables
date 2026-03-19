import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const docsRoot = path.resolve(process.cwd(), "docs");
const publicRoot = path.join(docsRoot, ".vitepress", "public");

const skipDirs = new Set([".vitepress", "node_modules"]);

/** Curated order for agents: onboarding → workflows → integration → reference. */
const recommendedOrder = [
  "/",
  "/overview/",
  "/get-started/",
  "/get-started/beginner",
  "/get-started/developer",
  "/get-started/agent",
  "/install/",
  "/use/",
  "/know/",
  "/hub/",
  "/mcp/",
  "/develop/",
  "/troubleshooting/",
  "/reference/",
  "/reference/agent-contract",
  "/reference/ia-ux-strategy",
  "/reference/metrics",
  "/reference/governance",
  "/reference/acknowledgments",
];

async function walkMarkdownFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (!skipDirs.has(entry.name)) {
        files.push(...(await walkMarkdownFiles(fullPath)));
      }
      continue;
    }
    if (entry.isFile() && entry.name.endsWith(".md")) {
      files.push(fullPath);
    }
  }
  return files;
}

function toRoute(filePath) {
  const relative = path.relative(docsRoot, filePath).replace(/\\/g, "/");
  if (relative === "index.md") {
    return "/";
  }
  return `/${relative.replace(/\.md$/, "").replace(/\/index$/, "/")}`;
}

function stripFrontmatter(markdownText) {
  if (!markdownText.startsWith("---\n")) {
    return markdownText;
  }
  const end = markdownText.indexOf("\n---\n", 4);
  if (end === -1) {
    return markdownText;
  }
  return markdownText.slice(end + 5);
}

async function main() {
  const mdFiles = await walkMarkdownFiles(docsRoot);
  const sortedFiles = mdFiles.sort();

  await mkdir(publicRoot, { recursive: true });

  const routeSet = new Set(sortedFiles.map((f) => toRoute(f)));
  const recommendedPresent = recommendedOrder.filter((r) => routeSet.has(r));
  const allRoutes = sortedFiles.map((f) => toRoute(f));
  const restRoutes = allRoutes
    .filter((r) => !recommendedPresent.includes(r))
    .sort();
  const fullOrder = [...recommendedPresent, ...restRoutes];

  const filesByRoute = new Map(sortedFiles.map((f) => [toRoute(f), f]));

  const llmsIndexLines = [
    "# Agentic Executables Docs Index",
    "",
    "This is a compact index for AI agents.",
    "",
    "## Recommended order",
    "",
    "Traverse these routes first for onboarding and integration:",
    "",
    ...recommendedPresent.map((r) => `- ${r}`),
    "",
    "## All pages",
    "",
    ...fullOrder.map((r) => `- ${r}`),
  ];

  const llmsFullLines = [
    "# Agentic Executables Full Docs",
    "",
    "This file contains consolidated docs content for AI agents.",
    "",
    "## Recommended order",
    "",
    ...recommendedPresent.map((r) => `- ${r}`),
    "",
  ];

  for (const route of fullOrder) {
    const file = filesByRoute.get(route);
    if (!file) continue;
    const markdown = await readFile(file, "utf8");
    const body = stripFrontmatter(markdown).trim();
    llmsFullLines.push(`## Route: ${route}`);
    llmsFullLines.push("");
    llmsFullLines.push(body);
    llmsFullLines.push("");
  }

  await writeFile(path.join(publicRoot, "llms.txt"), `${llmsIndexLines.join("\n")}\n`);
  await writeFile(
    path.join(publicRoot, "llms-full.txt"),
    `${llmsFullLines.join("\n")}\n`,
  );

  process.stdout.write(
    `Generated llms files from ${sortedFiles.length} markdown pages (${recommendedPresent.length} recommended).\n`,
  );
}

await main();
