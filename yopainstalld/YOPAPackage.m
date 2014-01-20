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
-(struct yopa_segment) findCompatibleSegmentforVersion:(NSInteger) version {
    uint32_t magic, offset;
    struct yopa_segment segment;
    for(int i = 0; i < sizeof(_header.segment_offsets) / sizeof(uint32_t); i++)
    {
        offset = _header.segment_offsets[i];
        fseek(_package, CFSwapInt32(offset), SEEK_SET);
        fread(&magic, sizeof(uint32_t), 1, _package);
        if (magic != YOPA_SEGMENT_MAGIC) {
            DebugLog(@"Rogue segment detected at %u", CFSwapInt32(offset));
            continue;
        }
        fread(&segment, sizeof(struct yopa_segment), 1, _package);
        if (version == segment.required_version) {
            DebugLog(@"Found compatible segment at %u", CFSwapInt32(offset));
            return segment;
        }
    }
    DebugLog(@"Error couldn't find any segment");
    return segment;
}



-(NSString*)lipoPackageFromSegment:(struct yopa_segment)segment {
    fseek(_package, segment.offset, SEEK_SET);
    NSString *lipoPath = [_tmpDir stringByAppendingPathComponent:@"package-lipo"]; // assign a new lipo path
    FILE *lipoOut = fopen([lipoPath UTF8String], "w+"); // prepare the file stream
    void *tmp_b = malloc(0x1000); // allocate a temporary buffer
    
    NSUInteger remain = CFSwapInt32(segment.size);
    while (remain > 0) {
        if (remain > 0x1000) {
            // move over 0x1000
            fread(tmp_b, 0x1000, 1, _package);
            fwrite(tmp_b, 0x1000, 1, lipoOut);
            remain -= 0x1000;
        } else {
            // move over remaining and break
            fread(tmp_b, remain, 1, _package);
            fwrite(tmp_b, remain, 1, lipoOut);
            break;
        }
    }
    fclose(lipoOut);
    return lipoPath;
}


-(NSString*) processPackage {
    switch (_header.segment_offsets[0]){
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