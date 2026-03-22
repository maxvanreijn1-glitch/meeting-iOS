#!/usr/bin/env node

import Anthropic from "@anthropic-ai/sdk";
import * as fs from "fs";
import * as path from "path";
import * as readline from "readline";

interface FileEntry {
  filePath: string;
  relativePath: string;
  size: number;
  extension: string;
  lastModified: Date;
  language: string;
}

interface FileIndex {
  rootPath: string;
  files: FileEntry[];
  indexedAt: Date;
  stats: LanguageStats;
}

interface LanguageStats {
  [language: string]: {
    fileCount: number;
    totalBytes: number;
    percentage: number;
  };
}

interface ChangeRecord {
  filePath: string;
  changeType: "added" | "modified" | "deleted";
  timestamp: Date;
  previousSize?: number;
  currentSize?: number;
}

const LANGUAGE_EXTENSIONS: { [ext: string]: string } = {
  ".m": "Objective-C",
  ".h": "Objective-C/C",
  ".swift": "Swift",
  ".js": "JavaScript",
  ".ts": "TypeScript",
  ".sh": "Shell",
  ".html": "HTML",
  ".htm": "HTML",
  ".rb": "Ruby",
  ".json": "JSON",
  ".md": "Markdown",
  ".xml": "XML",
  ".plist": "XML/Plist",
  ".xib": "Interface Builder",
  ".storyboard": "Interface Builder",
  ".css": "CSS",
  ".py": "Python",
  ".go": "Go",
};

const IGNORED_DIRS = new Set([
  "node_modules",
  ".git",
  "dist",
  "build",
  "Pods",
  ".build",
  "DerivedData",
  "xcuserdata",
  ".DS_Store",
]);

class LocalFileIntegration {
  private client: Anthropic;
  private conversationHistory: Array<{
    role: "user" | "assistant";
    content: string;
  }> = [];
  private fileIndex: FileIndex | null = null;
  private changeHistory: ChangeRecord[] = [];
  private watchedFiles: Map<string, fs.Stats> = new Map();
  private rootPath: string;
  private watchInterval: ReturnType<typeof setInterval> | null = null;

  constructor(rootPath: string = process.cwd()) {
    this.client = new Anthropic();
    this.rootPath = path.resolve(rootPath);
  }

  // ── File Indexing ─────────────────────────────────────────────────────────

  private getLanguage(ext: string): string {
    return LANGUAGE_EXTENSIONS[ext.toLowerCase()] || "Other";
  }

  private shouldIgnore(name: string): boolean {
    return IGNORED_DIRS.has(name);
  }

  private traverseDirectory(dir: string, entries: FileEntry[]): void {
    let items: string[];
    try {
      items = fs.readdirSync(dir);
    } catch {
      return;
    }

    for (const item of items) {
      if (this.shouldIgnore(item)) continue;

      const fullPath = path.join(dir, item);
      let stat: fs.Stats;
      try {
        stat = fs.statSync(fullPath);
      } catch {
        continue;
      }

      if (stat.isDirectory()) {
        this.traverseDirectory(fullPath, entries);
      } else if (stat.isFile()) {
        const ext = path.extname(item);
        entries.push({
          filePath: fullPath,
          relativePath: path.relative(this.rootPath, fullPath),
          size: stat.size,
          extension: ext,
          lastModified: stat.mtime,
          language: this.getLanguage(ext),
        });
      }
    }
  }

  private computeStats(files: FileEntry[]): LanguageStats {
    const totalBytes = files.reduce((sum, f) => sum + f.size, 0);
    const byLang: { [lang: string]: { fileCount: number; totalBytes: number } } =
      {};

    for (const f of files) {
      if (!byLang[f.language]) {
        byLang[f.language] = { fileCount: 0, totalBytes: 0 };
      }
      byLang[f.language].fileCount++;
      byLang[f.language].totalBytes += f.size;
    }

    const stats: LanguageStats = {};
    for (const [lang, data] of Object.entries(byLang)) {
      stats[lang] = {
        ...data,
        percentage:
          totalBytes > 0
            ? Math.round((data.totalBytes / totalBytes) * 1000) / 10
            : 0,
      };
    }
    return stats;
  }

  indexFiles(): FileIndex {
    console.log(`\n📂 Indexing files in: ${this.rootPath}`);
    const entries: FileEntry[] = [];
    this.traverseDirectory(this.rootPath, entries);
    const stats = this.computeStats(entries);

    this.fileIndex = {
      rootPath: this.rootPath,
      files: entries,
      indexedAt: new Date(),
      stats,
    };

    console.log(`✓ Indexed ${entries.length} files`);
    return this.fileIndex;
  }

  // ── File Watching ─────────────────────────────────────────────────────────

  startWatching(intervalMs = 3000): void {
    if (this.watchInterval) return;

    if (!this.fileIndex) this.indexFiles();

    // Seed the watched map
    for (const entry of this.fileIndex!.files) {
      try {
        this.watchedFiles.set(entry.filePath, fs.statSync(entry.filePath));
      } catch {
        // ignore
      }
    }

    this.watchInterval = setInterval(() => {
      this.checkForChanges();
    }, intervalMs);

    console.log(`👁  Watching for changes every ${intervalMs / 1000}s …`);
  }

  stopWatching(): void {
    if (this.watchInterval) {
      clearInterval(this.watchInterval);
      this.watchInterval = null;
      console.log("⏹  Stopped watching.");
    }
  }

  private checkForChanges(): void {
    const now = new Date();

    // Check existing files
    for (const [filePath, oldStat] of this.watchedFiles.entries()) {
      try {
        const newStat = fs.statSync(filePath);
        if (newStat.mtimeMs !== oldStat.mtimeMs) {
          const record: ChangeRecord = {
            filePath,
            changeType: "modified",
            timestamp: now,
            previousSize: oldStat.size,
            currentSize: newStat.size,
          };
          this.changeHistory.push(record);
          this.watchedFiles.set(filePath, newStat);
          console.log(
            `  📝 Modified: ${path.relative(this.rootPath, filePath)}`
          );
        }
      } catch {
        // File deleted
        const record: ChangeRecord = {
          filePath,
          changeType: "deleted",
          timestamp: now,
          previousSize: oldStat.size,
        };
        this.changeHistory.push(record);
        this.watchedFiles.delete(filePath);
        console.log(`  🗑  Deleted: ${path.relative(this.rootPath, filePath)}`);
      }
    }

    // Check for new files (re-scan)
    const currentEntries: FileEntry[] = [];
    this.traverseDirectory(this.rootPath, currentEntries);
    for (const entry of currentEntries) {
      if (!this.watchedFiles.has(entry.filePath)) {
        try {
          const stat = fs.statSync(entry.filePath);
          this.watchedFiles.set(entry.filePath, stat);
          const record: ChangeRecord = {
            filePath: entry.filePath,
            changeType: "added",
            timestamp: now,
            currentSize: stat.size,
          };
          this.changeHistory.push(record);
          console.log(`  ➕ Added: ${entry.relativePath}`);
        } catch {
          // ignore
        }
      }
    }
  }

  // ── File Operations ───────────────────────────────────────────────────────

  readFile(filePath: string): string {
    const resolved = path.isAbsolute(filePath)
      ? filePath
      : path.join(this.rootPath, filePath);
    return fs.readFileSync(resolved, "utf-8");
  }

  writeFile(filePath: string, content: string): void {
    const resolved = path.isAbsolute(filePath)
      ? filePath
      : path.join(this.rootPath, filePath);
    fs.mkdirSync(path.dirname(resolved), { recursive: true });
    fs.writeFileSync(resolved, content, "utf-8");
  }

  listFiles(subdir?: string, extension?: string): FileEntry[] {
    if (!this.fileIndex) this.indexFiles();
    let files = this.fileIndex!.files;

    if (subdir) {
      const absSubdir = path.join(this.rootPath, subdir);
      files = files.filter((f) => f.filePath.startsWith(absSubdir));
    }
    if (extension) {
      const ext = extension.startsWith(".") ? extension : `.${extension}`;
      files = files.filter((f) => f.extension === ext);
    }
    return files;
  }

  // ── Statistics & Display ──────────────────────────────────────────────────

  showStats(): void {
    if (!this.fileIndex) this.indexFiles();
    const { files, stats } = this.fileIndex!;

    console.log("\n📊 Project Statistics");
    console.log("═".repeat(50));
    console.log(`  Total files : ${files.length}`);
    console.log(
      `  Total size  : ${(
        files.reduce((s, f) => s + f.size, 0) / 1024
      ).toFixed(1)} KB`
    );
    console.log(`  Indexed at  : ${this.fileIndex!.indexedAt.toLocaleString()}`);
    console.log("\n  Language breakdown:");

    const sorted = Object.entries(stats).sort(
      (a, b) => b[1].percentage - a[1].percentage
    );
    for (const [lang, data] of sorted) {
      const bar = "█".repeat(Math.round(data.percentage / 2));
      console.log(
        `    ${lang.padEnd(20)} ${bar.padEnd(25)} ${data.percentage.toFixed(1)}% (${data.fileCount} files)`
      );
    }
    console.log("═".repeat(50));
  }

  showChanges(): void {
    if (this.changeHistory.length === 0) {
      console.log("\n  No changes tracked yet.");
      return;
    }
    console.log(`\n📋 Change History (${this.changeHistory.length} records)`);
    console.log("─".repeat(50));
    const recent = this.changeHistory.slice(-20);
    for (const record of recent) {
      const icon =
        record.changeType === "added"
          ? "➕"
          : record.changeType === "deleted"
          ? "🗑"
          : "📝";
      const rel = path.relative(this.rootPath, record.filePath);
      console.log(
        `  ${icon} ${record.changeType.padEnd(10)} ${rel} @ ${record.timestamp.toLocaleTimeString()}`
      );
    }
  }

  // ── Claude Integration ────────────────────────────────────────────────────

  private buildSystemPrompt(): string {
    const index = this.fileIndex;
    const statsText = index
      ? Object.entries(index.stats)
          .sort((a, b) => b[1].percentage - a[1].percentage)
          .map(
            ([lang, s]) =>
              `  ${lang}: ${s.percentage}% (${s.fileCount} files)`
          )
          .join("\n")
      : "  (not yet indexed)";

    return `You are a Claude-powered local file integration assistant for the project at: ${this.rootPath}

Project languages:
${statsText}

You can help with:
- Analyzing source files (Objective-C, Swift, JavaScript, TypeScript, Shell, Ruby, HTML)
- Suggesting refactoring improvements
- Generating documentation
- Explaining code patterns
- Performing code quality analysis
- Recommending file organization
- Answering questions about specific files

When asked to read a file, ask for the relative path and use the provided content.
Keep responses clear, concise, and actionable.`;
  }

  async askClaude(userMessage: string): Promise<string> {
    this.conversationHistory.push({ role: "user", content: userMessage });

    const response = await this.client.messages.create({
      model: "claude-opus-4-5",
      max_tokens: 2048,
      system: this.buildSystemPrompt(),
      messages: this.conversationHistory,
    });

    const text =
      response.content[0].type === "text" ? response.content[0].text : "";
    this.conversationHistory.push({ role: "assistant", content: text });
    return text;
  }

  async analyzeFile(relPath: string): Promise<string> {
    let content: string;
    try {
      content = this.readFile(relPath);
    } catch {
      return `Error: Cannot read file "${relPath}"`;
    }

    const language = this.getLanguage(path.extname(relPath));
    const prompt = `Analyze the following ${language} file (${relPath}) and provide:
1. A brief summary of what it does
2. Code quality observations
3. Potential improvements or refactoring suggestions
4. Any notable patterns or concerns

\`\`\`${language.toLowerCase()}
${content.slice(0, 8000)}
\`\`\``;

    return this.askClaude(prompt);
  }

  async generateDocumentation(relPath: string): Promise<string> {
    let content: string;
    try {
      content = this.readFile(relPath);
    } catch {
      return `Error: Cannot read file "${relPath}"`;
    }

    const language = this.getLanguage(path.extname(relPath));
    const prompt = `Generate comprehensive documentation for this ${language} file (${relPath}).
Include:
- File overview
- Class/function descriptions
- Parameter explanations
- Usage examples

\`\`\`${language.toLowerCase()}
${content.slice(0, 8000)}
\`\`\``;

    return this.askClaude(prompt);
  }

  async analyzeBatch(pattern?: string): Promise<void> {
    if (!this.fileIndex) this.indexFiles();

    let files = this.fileIndex!.files;
    if (pattern) {
      files = files.filter((f) => f.relativePath.includes(pattern));
    }

    // Limit to first 5 for batch analysis
    const toAnalyze = files.slice(0, 5);
    console.log(`\n🔍 Analyzing ${toAnalyze.length} files…\n`);

    for (const file of toAnalyze) {
      console.log(`\n── ${file.relativePath} ──`);
      const result = await this.analyzeFile(file.relativePath);
      console.log(result);
    }
  }

  // ── Interactive REPL ──────────────────────────────────────────────────────

  async startREPL(): Promise<void> {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    // Initial indexing
    this.indexFiles();

    console.log("\n🚀 Claude Local File Integration CLI");
    console.log('   Type "help" for available commands, "quit" to exit.\n');

    const prompt = (): void => {
      rl.question("local-file> ", async (input) => {
        const trimmed = input.trim();

        if (!trimmed) {
          prompt();
          return;
        }

        if (trimmed === "quit" || trimmed === "exit") {
          this.stopWatching();
          console.log("👋 Goodbye!");
          rl.close();
          return;
        }

        await this.handleCommand(trimmed);
        prompt();
      });
    };

    prompt();
  }

  async handleCommand(input: string): Promise<void> {
    const [cmd, ...args] = input.split(" ");

    switch (cmd.toLowerCase()) {
      case "help":
        this.printHelp();
        break;

      case "index":
        this.indexFiles();
        break;

      case "stats":
        this.showStats();
        break;

      case "list": {
        const files = this.listFiles(args[0], args[1]);
        console.log(`\n📁 ${files.length} file(s):`);
        for (const f of files.slice(0, 50)) {
          console.log(
            `  ${f.relativePath.padEnd(55)} ${f.language} (${(f.size / 1024).toFixed(1)} KB)`
          );
        }
        if (files.length > 50) console.log(`  … and ${files.length - 50} more`);
        break;
      }

      case "read": {
        if (!args[0]) {
          console.log("  Usage: read <relative-path>");
          break;
        }
        try {
          const content = this.readFile(args[0]);
          console.log(`\n── ${args[0]} ──\n${content.slice(0, 3000)}`);
          if (content.length > 3000) {
            console.log(`\n  … (${content.length - 3000} more chars)`);
          }
        } catch (e) {
          console.log(`  Error: ${e}`);
        }
        break;
      }

      case "analyze": {
        if (!args[0]) {
          console.log("  Usage: analyze <relative-path>");
          break;
        }
        console.log(`\n🤖 Analyzing ${args[0]} …`);
        const result = await this.analyzeFile(args[0]);
        console.log(`\n${result}`);
        break;
      }

      case "docs": {
        if (!args[0]) {
          console.log("  Usage: docs <relative-path>");
          break;
        }
        console.log(`\n🤖 Generating documentation for ${args[0]} …`);
        const result = await this.generateDocumentation(args[0]);
        console.log(`\n${result}`);
        break;
      }

      case "batch": {
        await this.analyzeBatch(args[0]);
        break;
      }

      case "watch": {
        this.startWatching();
        break;
      }

      case "unwatch": {
        this.stopWatching();
        break;
      }

      case "changes": {
        this.showChanges();
        break;
      }

      case "ask": {
        if (!args.length) {
          console.log("  Usage: ask <your question>");
          break;
        }
        console.log("\n🤖 Claude:");
        const answer = await this.askClaude(args.join(" "));
        console.log(answer);
        break;
      }

      default: {
        // Treat as a free-form question to Claude
        console.log("\n🤖 Claude:");
        const answer = await this.askClaude(input);
        console.log(answer);
      }
    }
  }

  private printHelp(): void {
    console.log(`
╔══════════════════════════════════════════════════════════╗
║        Claude Local File Integration — Commands          ║
╠══════════════════════════════════════════════════════════╣
║  index                  Re-index all project files       ║
║  stats                  Show language statistics         ║
║  list [subdir] [ext]    List files (optional filters)    ║
║  read <path>            Read and display a file          ║
║  analyze <path>         AI code analysis of a file       ║
║  docs <path>            Generate documentation           ║
║  batch [pattern]        Analyze up to 5 files            ║
║  watch                  Start file watching              ║
║  unwatch                Stop file watching               ║
║  changes                Show tracked changes             ║
║  ask <question>         Ask Claude anything              ║
║  quit / exit            Exit the CLI                     ║
╚══════════════════════════════════════════════════════════╝
Or just type any question and Claude will answer it.
`);
  }
}

// ── Entry point ───────────────────────────────────────────────────────────────

const projectPath = process.argv[2] || process.cwd();
const cli = new LocalFileIntegration(projectPath);

if (process.argv[3]) {
  // Single-command mode: node claude-local-file-cli.js <path> <command> [args…]
  cli.indexFiles();
  cli.handleCommand(process.argv.slice(3).join(" ")).then(() => process.exit(0));
} else {
  cli.startREPL();
}
