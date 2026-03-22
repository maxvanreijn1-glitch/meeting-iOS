# frozen_string_literal: true
# build/FileIntegration.rb
# Claude-powered local file integration — Ruby build helper
#
# Provides utilities for file discovery, statistics, report generation,
# and batch operations. Works alongside the TypeScript CLI and Shell scripts.

require 'json'
require 'pathname'
require 'fileutils'
require 'time'

module ClaudeFileIntegration
  # ── Constants ──────────────────────────────────────────────────────────

  LANGUAGE_MAP = {
    '.m'          => 'Objective-C',
    '.h'          => 'Objective-C/C',
    '.swift'      => 'Swift',
    '.js'         => 'JavaScript',
    '.ts'         => 'TypeScript',
    '.sh'         => 'Shell',
    '.html'       => 'HTML',
    '.htm'        => 'HTML',
    '.rb'         => 'Ruby',
    '.json'       => 'JSON',
    '.md'         => 'Markdown',
    '.xml'        => 'XML',
    '.plist'      => 'XML/Plist',
    '.xib'        => 'Interface Builder',
    '.storyboard' => 'Interface Builder',
    '.css'        => 'CSS',
  }.freeze

  IGNORED_DIRS = %w[
    node_modules .git Pods DerivedData
    xcuserdata .DS_Store dist .build
  ].to_set.freeze

  # ── FileEntry ─────────────────────────────────────────────────────────

  FileEntry = Struct.new(
    :path, :relative_path, :size, :extension, :language, :last_modified,
    keyword_init: true
  )

  # ── Indexer ────────────────────────────────────────────────────────────

  module Indexer
    # Returns an array of FileEntry objects for all files under root_path.
    def self.index(root_path)
      root = Pathname.new(root_path).expand_path
      entries = []
      traverse(root, root, entries)
      entries
    end

    def self.traverse(dir, root, entries)
      dir.each_child do |child|
        next if IGNORED_DIRS.include?(child.basename.to_s)

        if child.directory?
          traverse(child, root, entries)
        elsif child.file?
          ext = child.extname.downcase
          entries << FileEntry.new(
            path:          child.to_s,
            relative_path: child.relative_path_from(root).to_s,
            size:          child.size,
            extension:     ext,
            language:      LANGUAGE_MAP.fetch(ext, 'Other'),
            last_modified: child.mtime
          )
        end
      rescue Errno::EACCES
        next
      end
    rescue Errno::EACCES
      # Skip unreadable directories
    end
    private_class_method :traverse
  end

  # ── Statistics ─────────────────────────────────────────────────────────

  module Statistics
    # Computes per-language statistics from an array of FileEntry objects.
    # Returns a Hash keyed by language name.
    def self.compute(entries)
      total_bytes = entries.sum(&:size).to_f
      grouped = entries.group_by(&:language)

      grouped.transform_values do |files|
        bytes = files.sum(&:size)
        {
          file_count:  files.size,
          total_bytes: bytes,
          percentage:  total_bytes > 0 ? (bytes / total_bytes * 100).round(1) : 0.0
        }
      end
    end
  end

  # ── FileOperations ─────────────────────────────────────────────────────

  module FileOperations
    # Reads a file relative to root_path; returns the content as a String.
    def self.read(root_path, relative_path)
      File.read(File.join(root_path, relative_path), encoding: 'UTF-8')
    end

    # Writes content to a file relative to root_path, creating dirs as needed.
    def self.write(root_path, relative_path, content)
      full = File.join(root_path, relative_path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, content, encoding: 'UTF-8')
    end

    # Lists files with optional subdirectory and extension filters.
    def self.list(entries, subdir: nil, extension: nil)
      result = entries
      result = result.select { |e| e.relative_path.start_with?(subdir) } if subdir
      if extension
        ext = extension.start_with?('.') ? extension : ".#{extension}"
        result = result.select { |e| e.extension == ext }
      end
      result
    end

    # Copies files, preserving their relative paths under dest_root.
    def self.batch_copy(file_paths, src_root, dest_root)
      file_paths.each do |src|
        rel = Pathname.new(src).relative_path_from(Pathname.new(src_root)).to_s
        dest = File.join(dest_root, rel)
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(src, dest)
      end
    end
  end

  # ── ChangeDetector ─────────────────────────────────────────────────────

  module ChangeDetector
    # Builds a snapshot hash of path => mtime for all files under root_path.
    def self.snapshot(root_path)
      Indexer.index(root_path).each_with_object({}) do |entry, hash|
        hash[entry.path] = entry.last_modified
      end
    end

    # Compares a previous snapshot to the current file-system state.
    # Returns an array of change hashes: { path:, change_type:, size?: }
    def self.detect(snapshot, root_path)
      changes = []

      snapshot.each do |path, old_mtime|
        if File.exist?(path)
          new_mtime = File.mtime(path)
          changes << { path: path, change_type: :modified, size: File.size(path) } if new_mtime != old_mtime
        else
          changes << { path: path, change_type: :deleted }
        end
      end

      Indexer.index(root_path).each do |entry|
        changes << { path: entry.path, change_type: :added, size: entry.size } unless snapshot.key?(entry.path)
      end

      changes
    end
  end

  # ── Reporter ────────────────────────────────────────────────────────────

  module Reporter
    # Generates a plain-text project statistics report.
    def self.text_report(root_path)
      entries = Indexer.index(root_path)
      stats   = Statistics.compute(entries)
      total   = entries.sum(&:size)

      lines = [
        '╔══════════════════════════════════════════════╗',
        '║   Claude Local File Integration — Report     ║',
        '╠══════════════════════════════════════════════╣',
        "  Total files: #{entries.size}",
        format('  Total size : %.1f KB', total / 1024.0),
        '',
        '  Language breakdown:',
      ]

      stats.sort_by { |_, v| -v[:percentage] }.each do |lang, data|
        bar = '█' * (data[:percentage] / 2).round
        lines << format('    %-20s %-25s %.1f%% (%d files)',
                        lang, bar, data[:percentage], data[:file_count])
      end

      lines << '╚══════════════════════════════════════════════╝'
      lines.join("\n")
    end

    # Generates a JSON report and writes it to output_path.
    def self.json_report(root_path, output_path = nil)
      entries = Indexer.index(root_path)
      stats   = Statistics.compute(entries)

      report = {
        generated_at: Time.now.iso8601,
        root_path:    root_path,
        total_files:  entries.size,
        total_bytes:  entries.sum(&:size),
        languages:    stats,
      }

      json = JSON.pretty_generate(report)
      FileOperations.write(root_path, output_path, json) if output_path
      json
    end
  end
end

# ── CLI entry point ────────────────────────────────────────────────────────

if __FILE__ == $PROGRAM_NAME
  root = ARGV[0] || Dir.pwd
  command = ARGV[1] || 'report'

  case command
  when 'stats', 'report'
    puts ClaudeFileIntegration::Reporter.text_report(root)
  when 'json'
    output = ARGV[2]
    puts ClaudeFileIntegration::Reporter.json_report(root, output)
    puts "JSON report written to #{output}" if output
  when 'list'
    entries = ClaudeFileIntegration::Indexer.index(root)
    entries.each do |e|
      printf "  %-55s %-15s %d B\n", e.relative_path, e.language, e.size
    end
  else
    puts 'Usage: ruby build/FileIntegration.rb <root_path> [stats|json|list]'
  end
end
