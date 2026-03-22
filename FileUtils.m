//
//  FileUtils.m
//  Claude-powered local file integration — Objective-C utilities
//

#import "FileUtils.h"

@implementation FileUtils

// MARK: - Language Detection

+ (NSString *)languageForExtension:(NSString *)ext {
    static NSDictionary<NSString *, NSString *> *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @".m":          @"Objective-C",
            @".h":          @"Objective-C/C",
            @".swift":      @"Swift",
            @".js":         @"JavaScript",
            @".ts":         @"TypeScript",
            @".sh":         @"Shell",
            @".html":       @"HTML",
            @".htm":        @"HTML",
            @".rb":         @"Ruby",
            @".json":       @"JSON",
            @".md":         @"Markdown",
            @".xml":        @"XML",
            @".plist":      @"XML/Plist",
            @".xib":        @"Interface Builder",
            @".storyboard": @"Interface Builder",
            @".css":        @"CSS",
        };
    });
    return map[ext.lowercaseString] ?: @"Other";
}

+ (BOOL)shouldIgnoreDirectoryNamed:(NSString *)name {
    static NSSet<NSString *> *ignored;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ignored = [NSSet setWithObjects:
            @"node_modules", @".git", @"Pods", @"DerivedData",
            @"xcuserdata", @".DS_Store", @"dist", @".build", nil];
    });
    return [ignored containsObject:name];
}

// MARK: - Directory Traversal

+ (NSArray<NSDictionary *> *)indexFilesAtPath:(NSString *)rootPath {
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    [self traverseDirectory:rootPath rootPath:rootPath into:entries];
    return [entries copy];
}

+ (void)traverseDirectory:(NSString *)directory
                 rootPath:(NSString *)rootPath
                     into:(NSMutableArray<NSDictionary *> *)entries {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:directory error:&error];
    if (error || !items) return;

    for (NSString *item in items) {
        if ([self shouldIgnoreDirectoryNamed:item]) continue;

        NSString *fullPath = [directory stringByAppendingPathComponent:item];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        if (!attrs) continue;

        NSString *type = attrs[NSFileType];
        if ([type isEqualToString:NSFileTypeDirectory]) {
            [self traverseDirectory:fullPath rootPath:rootPath into:entries];
        } else {
            NSString *ext = [@"." stringByAppendingString:fullPath.pathExtension.lowercaseString];
            NSString *language = [self languageForExtension:ext];
            NSString *relativePath = [fullPath stringByReplacingOccurrencesOfString:[rootPath stringByAppendingString:@"/"]
                                                                         withString:@""];
            [entries addObject:@{
                @"path":         fullPath,
                @"relativePath": relativePath,
                @"extension":    ext,
                @"language":     language,
                @"size":         attrs[NSFileSize] ?: @0,
                @"modified":     attrs[NSFileModificationDate] ?: [NSDate distantPast],
            }];
        }
    }
}

// MARK: - Language Statistics

+ (NSDictionary<NSString *, NSDictionary *> *)statisticsForEntries:(NSArray<NSDictionary *> *)entries {
    long long totalBytes = 0;
    NSMutableDictionary<NSString *, NSMutableDictionary *> *map = [NSMutableDictionary dictionary];

    for (NSDictionary *entry in entries) {
        NSString *lang = entry[@"language"];
        long long size = [entry[@"size"] longLongValue];
        totalBytes += size;

        if (!map[lang]) {
            map[lang] = [@{ @"fileCount": @0, @"totalBytes": @0 } mutableCopy];
        }
        map[lang][@"fileCount"] = @([map[lang][@"fileCount"] intValue] + 1);
        map[lang][@"totalBytes"] = @([map[lang][@"totalBytes"] longLongValue] + size);
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *lang in map) {
        long long langBytes = [map[lang][@"totalBytes"] longLongValue];
        double percentage = totalBytes > 0 ? (double)langBytes / (double)totalBytes * 100.0 : 0.0;
        result[lang] = @{
            @"fileCount":  map[lang][@"fileCount"],
            @"totalBytes": map[lang][@"totalBytes"],
            @"percentage": @(round(percentage * 10) / 10),
        };
    }
    return [result copy];
}

// MARK: - File Read / Write

+ (nullable NSString *)readFileAtPath:(NSString *)filePath error:(NSError **)outError {
    return [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:outError];
}

+ (BOOL)writeContent:(NSString *)content toPath:(NSString *)filePath error:(NSError **)outError {
    NSString *directory = [filePath stringByDeletingLastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:directory]) {
        if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:outError]) {
            return NO;
        }
    }
    return [content writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:outError];
}

// MARK: - Change Detection

+ (NSArray<NSDictionary *> *)detectChangesFrom:(NSDictionary<NSString *, NSDate *> *)snapshot
                                          inPath:(NSString *)rootPath {
    NSMutableArray<NSDictionary *> *changes = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    // Check existing
    for (NSString *path in snapshot) {
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        if (!attrs) {
            [changes addObject:@{ @"path": path, @"changeType": @"deleted" }];
        } else {
            NSDate *oldDate = snapshot[path];
            NSDate *newDate = attrs[NSFileModificationDate];
            if (newDate && [newDate compare:oldDate] != NSOrderedSame) {
                [changes addObject:@{ @"path": path, @"changeType": @"modified",
                                      @"newSize": attrs[NSFileSize] ?: @0 }];
            }
        }
    }

    // Detect additions (re-index and compare)
    NSArray<NSDictionary *> *current = [self indexFilesAtPath:rootPath];
    for (NSDictionary *entry in current) {
        NSString *path = entry[@"path"];
        if (!snapshot[path]) {
            [changes addObject:@{ @"path": path, @"changeType": @"added",
                                  @"size": entry[@"size"] ?: @0 }];
        }
    }

    return [changes copy];
}

// MARK: - Report Generation

+ (NSString *)generateTextReport:(NSArray<NSDictionary *> *)entries {
    NSDictionary *stats = [self statisticsForEntries:entries];
    NSMutableString *report = [NSMutableString string];

    [report appendString:@"╔══════════════════════════════════════════════╗\n"];
    [report appendString:@"║   Claude Local File Integration — Report     ║\n"];
    [report appendString:@"╠══════════════════════════════════════════════╣\n"];
    [report appendFormat:@"  Total files: %lu\n", (unsigned long)entries.count];

    long long total = 0;
    for (NSDictionary *e in entries) total += [e[@"size"] longLongValue];
    [report appendFormat:@"  Total size : %.1f KB\n\n", (double)total / 1024.0];
    [report appendString:@"  Language breakdown:\n"];

    NSArray *sorted = [stats.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        double pa = [stats[a][@"percentage"] doubleValue];
        double pb = [stats[b][@"percentage"] doubleValue];
        return pa > pb ? NSOrderedAscending : NSOrderedDescending;
    }];

    for (NSString *lang in sorted) {
        double pct = [stats[lang][@"percentage"] doubleValue];
        NSInteger count = [stats[lang][@"fileCount"] integerValue];
        NSMutableString *bar = [NSMutableString string];
        for (NSInteger i = 0; i < (NSInteger)(pct / 2); i++) [bar appendString:@"█"];
        [report appendFormat:@"    %-20@ %-25@ %.1f%% (%ld files)\n", lang, bar, pct, (long)count];
    }

    [report appendString:@"╚══════════════════════════════════════════════╝\n"];
    return [report copy];
}

@end
