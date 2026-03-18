import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const docsRoot = path.resolve(process.cwd(), "docs");
const publicRoot = path.join(docsRoot, ".vitepress", "public");

const skipDirs = new Set([".vitepress", "node_modules"]);

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

  const llmsIndexLines = [
    "# Agentic Executables Docs Index",
    "",
    "This is a compact index for AI agents.",
    "",
    "## Pages",
  ];

  const llmsFullLines = [
    "# Agentic Executables Full Docs",
    "",
    "This file contains consolidated docs content for AI agents.",
    "",
  ];

  for (const file of sortedFiles) {
    const route = toRoute(file);
    const markdown = await readFile(file, "utf8");
    const body = stripFrontmatter(markdown).trim();
    llmsIndexLines.push(`- ${route}`);

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
    `Generated llms files from ${sortedFiles.length} markdown pages.\n`,
  );
}

await main();
