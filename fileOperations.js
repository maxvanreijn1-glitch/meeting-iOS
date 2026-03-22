/**
 * fileOperations.js
 * Claude-powered local file integration — Node.js utilities
 *
 * Provides helper functions for file discovery, reading, writing,
 * change detection, and statistics computation. Used by the TypeScript
 * CLI and Shell scripts.
 */

"use strict";

const fs = require("fs");
const path = require("path");

// ── Constants ──────────────────────────────────────────────────────────────

const LANGUAGE_MAP = {
  ".m":          "Objective-C",
  ".h":          "Objective-C/C",
  ".swift":      "Swift",
  ".js":         "JavaScript",
  ".ts":         "TypeScript",
  ".sh":         "Shell",
  ".html":       "HTML",
  ".htm":        "HTML",
  ".rb":         "Ruby",
  ".json":       "JSON",
  ".md":         "Markdown",
  ".xml":        "XML",
  ".plist":      "XML/Plist",
  ".xib":        "Interface Builder",
  ".storyboard": "Interface Builder",
  ".css":        "CSS",
};

const IGNORED_DIRS = new Set([
  "node_modules", ".git", "Pods", "DerivedData",
  "xcuserdata", ".DS_Store", "dist", ".build",
]);

// ── Helpers ────────────────────────────────────────────────────────────────

/**
 * Returns the display language name for a file extension.
 * @param {string} ext  e.g. ".swift"
 * @returns {string}
 */
function getLanguage(ext) {
  return LANGUAGE_MAP[ext.toLowerCase()] || "Other";
}

/**
 * Returns true if a directory name should be skipped during traversal.
 * @param {string} name
 * @returns {boolean}
 */
function shouldIgnore(name) {
  return IGNORED_DIRS.has(name);
}

// ── File Indexing ──────────────────────────────────────────────────────────

/**
 * Recursively collects file metadata under `rootPath`.
 * @param {string} rootPath  Absolute path to the project root.
 * @returns {{ filePath: string, relativePath: string, size: number, extension: string, language: string, lastModified: Date }[]}
 */
function indexFiles(rootPath) {
  const entries = [];
  traverse(rootPath, rootPath, entries);
  return entries;
}

function traverse(dir, rootPath, entries) {
  let items;
  try {
    items = fs.readdirSync(dir);
  } catch {
    return;
  }

  for (const item of items) {
    if (shouldIgnore(item)) continue;

    const fullPath = path.join(dir, item);
    let stat;
    try {
      stat = fs.statSync(fullPath);
    } catch {
      continue;
    }

    if (stat.isDirectory()) {
      traverse(fullPath, rootPath, entries);
    } else {
      const ext = path.extname(item);
      entries.push({
        filePath: fullPath,
        relativePath: path.relative(rootPath, fullPath),
        size: stat.size,
        extension: ext,
        language: getLanguage(ext),
        lastModified: stat.mtime,
      });
    }
  }
}

// ── Statistics ─────────────────────────────────────────────────────────────

/**
 * Computes per-language statistics from a list of file entries.
 * @param {{ size: number, language: string }[]} entries
 * @returns {Object.<string, { fileCount: number, totalBytes: number, percentage: number }>}
 */
function computeStatistics(entries) {
  const totalBytes = entries.reduce((sum, e) => sum + e.size, 0);
  const map = {};

  for (const entry of entries) {
    if (!map[entry.language]) {
      map[entry.language] = { fileCount: 0, totalBytes: 0 };
    }
    map[entry.language].fileCount++;
    map[entry.language].totalBytes += entry.size;
  }

  for (const lang of Object.keys(map)) {
    map[lang].percentage =
      totalBytes > 0
        ? Math.round((map[lang].totalBytes / totalBytes) * 1000) / 10
        : 0;
  }
  return map;
}

// ── File Read / Write ──────────────────────────────────────────────────────

/**
 * Reads a file and returns its content as a UTF-8 string.
 * @param {string} filePath  Absolute path.
 * @returns {string}
 */
function readFile(filePath) {
  return fs.readFileSync(filePath, "utf-8");
}

/**
 * Writes content to a file, creating parent directories as needed.
 * @param {string} filePath  Absolute path.
 * @param {string} content
 */
function writeFile(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, "utf-8");
}

// ── Change Detection ───────────────────────────────────────────────────────

/**
 * Builds a snapshot map of path → {size, mtime} for all files under rootPath.
 * @param {string} rootPath
 * @returns {Map<string, { size: number, mtime: number }>}
 */
function buildSnapshot(rootPath) {
  const entries = indexFiles(rootPath);
  const snapshot = new Map();
  for (const entry of entries) {
    snapshot.set(entry.filePath, {
      size: entry.size,
      mtime: entry.lastModified.getTime(),
    });
  }
  return snapshot;
}

/**
 * Compares a previous snapshot to the current file system state.
 * @param {Map<string, { size: number, mtime: number }>} snapshot
 * @param {string} rootPath
 * @returns {{ filePath: string, changeType: 'added'|'modified'|'deleted', size?: number }[]}
 */
function detectChanges(snapshot, rootPath) {
  const changes = [];

  // Check existing entries
  for (const [filePath, old] of snapshot.entries()) {
    let stat;
    try {
      stat = fs.statSync(filePath);
    } catch {
      changes.push({ filePath, changeType: "deleted" });
      continue;
    }
    if (stat.mtimeMs !== old.mtime) {
      changes.push({ filePath, changeType: "modified", size: stat.size });
    }
  }

  // Detect additions
  const current = indexFiles(rootPath);
  for (const entry of current) {
    if (!snapshot.has(entry.filePath)) {
      changes.push({ filePath: entry.filePath, changeType: "added", size: entry.size });
    }
  }

  return changes;
}

// ── Batch Operations ───────────────────────────────────────────────────────

/**
 * Copies multiple files, preserving relative paths under destRoot.
 * @param {string[]} filePaths  Absolute source paths.
 * @param {string} srcRoot      Common root of the source files.
 * @param {string} destRoot     Destination root directory.
 */
function batchCopy(filePaths, srcRoot, destRoot) {
  for (const src of filePaths) {
    const rel = path.relative(srcRoot, src);
    const dest = path.join(destRoot, rel);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(src, dest);
  }
}

// ── Report Generation ──────────────────────────────────────────────────────

/**
 * Generates a plain-text statistics report.
 * @param {string} rootPath
 * @returns {string}
 */
function generateTextReport(rootPath) {
  const entries = indexFiles(rootPath);
  const stats = computeStatistics(entries);
  const totalBytes = entries.reduce((s, e) => s + e.size, 0);

  const lines = [
    "╔══════════════════════════════════════════════╗",
    "║   Claude Local File Integration — Report     ║",
    "╠══════════════════════════════════════════════╣",
    `  Total files: ${entries.length}`,
    `  Total size : ${(totalBytes / 1024).toFixed(1)} KB`,
    "",
    "  Language breakdown:",
  ];

  const sorted = Object.entries(stats).sort((a, b) => b[1].percentage - a[1].percentage);
  for (const [lang, data] of sorted) {
    const bar = "█".repeat(Math.round(data.percentage / 2));
    lines.push(
      `    ${lang.padEnd(20)} ${bar.padEnd(25)} ${data.percentage.toFixed(1)}% (${data.fileCount} files)`
    );
  }
  lines.push("╚══════════════════════════════════════════════╝");
  return lines.join("\n");
}

// ── Exports ────────────────────────────────────────────────────────────────

module.exports = {
  getLanguage,
  shouldIgnore,
  indexFiles,
  computeStatistics,
  readFile,
  writeFile,
  buildSnapshot,
  detectChanges,
  batchCopy,
  generateTextReport,
  LANGUAGE_MAP,
  IGNORED_DIRS,
};

// ── CLI usage ──────────────────────────────────────────────────────────────

if (require.main === module) {
  const rootPath = process.argv[2] || process.cwd();
  console.log(generateTextReport(rootPath));
}
