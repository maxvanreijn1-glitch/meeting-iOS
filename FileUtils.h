//
//  FileUtils.h
//  Claude-powered local file integration — Objective-C utilities header
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Utility class providing local file operations, indexing, and statistics
/// for the Claude-powered file integration system.
@interface FileUtils : NSObject

// MARK: - Language Detection

/// Returns the display language name for a given file extension (e.g. ".swift" → "Swift").
+ (NSString *)languageForExtension:(NSString *)ext;

/// Returns YES if a directory with the given name should be skipped during traversal.
+ (BOOL)shouldIgnoreDirectoryNamed:(NSString *)name;

// MARK: - Directory Traversal & Indexing

/// Recursively indexes all files under rootPath, returning an array of dictionaries.
/// Each dictionary contains: path, relativePath, extension, language, size, modified.
+ (NSArray<NSDictionary *> *)indexFilesAtPath:(NSString *)rootPath;

// MARK: - Language Statistics

/// Computes per-language statistics from an array of file-entry dictionaries.
/// Returns a dictionary keyed by language name, each value containing fileCount,
/// totalBytes, and percentage.
+ (NSDictionary<NSString *, NSDictionary *> *)statisticsForEntries:(NSArray<NSDictionary *> *)entries;

// MARK: - File Read / Write

/// Reads the file at filePath as a UTF-8 string. Returns nil and populates outError on failure.
+ (nullable NSString *)readFileAtPath:(NSString *)filePath error:(NSError **)outError;

/// Writes content to filePath as UTF-8, creating intermediate directories as needed.
/// Returns YES on success.
+ (BOOL)writeContent:(NSString *)content toPath:(NSString *)filePath error:(NSError **)outError;

// MARK: - Change Detection

/// Compares a snapshot dictionary (path → NSDate) to the current file system under rootPath.
/// Returns an array of change dictionaries with keys: path, changeType, and optionally size/newSize.
+ (NSArray<NSDictionary *> *)detectChangesFrom:(NSDictionary<NSString *, NSDate *> *)snapshot
                                          inPath:(NSString *)rootPath;

// MARK: - Report Generation

/// Generates a plain-text statistics report from an array of file-entry dictionaries.
+ (NSString *)generateTextReport:(NSArray<NSDictionary *> *)entries;

@end

NS_ASSUME_NONNULL_END
