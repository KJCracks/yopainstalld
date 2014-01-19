//
//  YOPAPackage.m
//  yopa
//

#import "YOPAPackage.h"
#import "LZMAExtractor.h"

static NSString * genRandStringLength(int len) {
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%c", [letters characterAtIndex: arc4random()%[letters length]]];
    }
    
    return randomString;
}


@implementation YOPAPackage

- (id)initWithPackagePath:(NSString*) packagePath {
    if (self = [super init]) {
        _packagePath = packagePath;
        _package = fopen([packagePath UTF8String], "r");
    }
    return self;
}
- (BOOL) isYOPA {
    
    if (_package == NULL) {
        return NO;
    }
    
    uint32_t magic;
    fseek(_package, -4, SEEK_END);
    fread(&magic, 4, 1, _package);
    if (magic == YOPA_MAGIC) {
        fseek(_package, -4 - sizeof(struct YOPA_Header), SEEK_END);
        fread(&_header, sizeof(struct YOPA_Header), 1, _package);
        NSLog(@"YOPA Magic detected!");
        return true;
    }
    else {
        NSLog(@"Couldn't find YOPA Magic.. huh");
        fclose(_package);
        return false;
    }
}

-(NSString*) processPackage {
    switch(_header.compression_format) {
        case SEVENZIP_COMPRESSION: {
            NSLog(@"7zip compression, extracting");
            _tmpDir = [NSString stringWithFormat:@"/tmp/yopa-%@", genRandStringLength(8)];
            NSLog(@"tmp dir %@", _tmpDir);
            if (![[NSFileManager defaultManager] removeItemAtPath:_tmpDir error:nil]) {
                NSLog(@"Could not remove temporary directory? huh");
            }
            
            [[NSFileManager defaultManager] createDirectoryAtPath:_tmpDir withIntermediateDirectories:YES attributes:nil error:nil];
            
            //BOOL result = [LZMAExtractor extractArchiveEntry:_packagePath archiveEntry:@".ipa" outPath:[_tmpDir stringByAppendingPathComponent:@".ipa"]];
            
            NSArray *result = [LZMAExtractor extract7zArchive:_packagePath dirName:_tmpDir preserveDir:NO];
            
            NSString *item = nil;
            for (NSString *path in result) {
                if ([[[path pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
                    NSLog(@"found IPA in extracted 7z");
                    item = path;
                    break;
                }
            }
            
            return item;
            break;
        }
    }
    return nil;
}

-(NSString*)getTempDir {
    return _tmpDir;
}


@end