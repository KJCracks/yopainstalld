//
//  PackageManager.m
//  yopainstalld
//

#import "PackageManager.h"
#import "MobileInstallation.h"
#import "YOPAPackage.h"

uint32_t crc32OfFile(NSString* file) {
    int fd = open(file.UTF8String, O_RDONLY);
    DebugLog(@"file fd %u", fd);
    uint32_t hash;
    off_t clen;
    DebugLog(@"calculating hash");
    crc32(fd, &hash, &clen);
    close(fd);
    DebugLog(@"wow da hash %u", CFSwapInt32(hash));
    return hash;
}

void listdir(const char *name, int level, NSMutableArray** array)
{
    DebugLog(@"wow so wow %s, %u", name, level);
    DIR *dir;
    struct dirent *entry;
    //DebugLog(@"ieterating %s", name);
    if (!(dir = opendir(name)))
        return;
    if (!(entry = readdir(dir)))
        return;
    
    do {
        if (entry->d_type == DT_DIR) {
            char path[1024];
            int len = snprintf(path, sizeof(path)-1, "%s/%s", name, entry->d_name);
            path[len] = 0;
            if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
                continue;
            //DebugLog(@"%*s[%s]\n", level*2, "", entry->d_name);
            listdir(path, level + 1, array);
        }
        else {
            //DebugLog(@"%s/%s", name, entry->d_name);
            [*array addObject:[NSString stringWithFormat:@"%s/%s", name, entry->d_name]];
        }
        
    } while ((entry = readdir(dir)));
    closedir(dir);
    
}

@implementation FileInfo

-(BOOL)compareWith:(FileInfo*)info {
    if (!([checksum isEqualToNumber:info->checksum])) {
        DebugLog(@"checksum mismatch for file %@", info->fileName);
    }
    return true;
}

-(id)initWithFileName:(NSString*)name andChecksum:(NSNumber*)_checksum{
    if (self = [super init]) {
        self->fileName = name;
        self->checksum = _checksum;
    }
    
    //DebugLog(@"file %@ ctime %ld, mtime %ld, size %ld", fileName, (long)ctime, (long)mtime, (long)size);
    return self;
}

@end



@implementation PackageManager

+ (NSDictionary*) appLookup {
    static dispatch_once_t pred;
    static NSDictionary* apps = nil;
    dispatch_once(&pred, ^{
        NSDictionary* options = @{@"ApplicationType":@"User",@"ReturnAttributes":@[@"CFBundleShortVersionString",@"CFBundleVersion",@"Path",@"CFBundleDisplayName",@"CFBundleIdentifier",@"MinimumOSVersion"]};
        apps = MobileInstallationLookup(options);
    });
    return apps;
}

-(NSInteger)appVersion {
    return [[[appInfo objectForKey:@"CFBundleVersion"] stringByReplacingOccurrencesOfString:@"." withString:@""] integerValue];
}

-(id)initWithBundleIdentifier:(NSString*)bundle {
    if (self = [super init]) {
        appBundleIdentifier = bundle;
        for (NSString* _bundle in [[PackageManager appLookup] allKeys]) {
            DebugLog(@"bundle names: %@", _bundle);
            if ([_bundle caseInsensitiveCompare:bundle] == NSOrderedSame) {
                DebugLog(@"wow found bundle: %@", _bundle);
                appInfo = [[PackageManager appLookup] objectForKey:_bundle];
                break;
            }
        }
    
        if (appInfo == nil) {
            DebugLog(@"Couldn't find appInfo for bundle %@!!", bundle);
            return nil;
        }
        DebugLog(@"wow %@", appInfo);
        
        [[NSFileManager defaultManager]createDirectoryAtPath:@"/etc/yopa/" withIntermediateDirectories:YES attributes:nil error:nil];
        
        appArchiveLocation = [@"/etc/yopa/" stringByAppendingPathComponent:[appInfo objectForKey:@"CFBundleIdentifier"]];
        DebugLog(@"applist %@", appArchiveLocation);
        versionDict = [NSMutableDictionary dictionaryWithContentsOfFile:appArchiveLocation];
        if (versionDict == nil) {
            DebugLog(@"versionDict is new wow");
            versionDict = [[NSMutableDictionary alloc] init];
        }
    }
    return self;
}

-(NSDictionary*)getDirectoryInfo:(NSString*)dir {
    DebugLog(@"setting directory %@", dir);
    NSMutableArray* array = [[NSMutableArray alloc] init];
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    chdir([dir UTF8String]);
    char* cwd;
    char buff[PATH_MAX + 1];
    
    cwd = getcwd( buff, PATH_MAX + 1 );
    if( cwd != NULL ) {
        DebugLog(@"My working directory is %s", cwd );
    }
    listdir(".", 0, &array);
    for (NSString* file in array) {
        NSString* _file = [file substringFromIndex:2];
        NSString* path = [dir stringByAppendingPathComponent:_file];
        DebugLog(@"checksum of file %@", path);

        [dict setObject:[NSString stringWithFormat:@"%u",crc32OfFile(path)] forKey:_file];
    }
    return dict;
}
-(NSArray*)getPatchVersions {
    return [versionDict allKeys];
}

-(NSDictionary *)diffOldVersion:(NSInteger)oldVersion newVersion:(NSInteger)newVersion {
    DebugLog(@"get files to patch %ld %ld", (long)oldVersion, (long)newVersion);
    NSMutableArray* files = [NSMutableArray new];
    
    NSDictionary* oldVersionDict = [versionDict objectForKey:[NSNumber numberWithInteger:oldVersion]];
    NSDictionary* newVersionDict = [versionDict objectForKey:[NSNumber numberWithInteger:newVersion]];
    
    NSArray *oldFiles = oldVersionDict.allKeys;
    
    NSMutableSet *filesToRemove = [NSMutableSet setWithArray:oldFiles];
    NSMutableSet *oldSet = [filesToRemove mutableCopy];
    NSMutableSet *newSet = [NSMutableSet setWithArray:oldFiles];
    
    [filesToRemove minusSet:newSet]; // yo
    [oldSet minusSet:filesToRemove]; // yo[2]
    
    //loop through all the files in the new version
    for (NSString* filePath in oldSet) {
        
        NSNumber *oldChecksum = [NSNumber numberWithUnsignedInteger:[[oldVersionDict objectForKey:filePath]integerValue]];
        
        NSNumber *newChecksum = [NSNumber numberWithUnsignedInteger:[[newVersionDict objectForKey:filePath]integerValue]];

        //get the fileinfo of the file in the new version
        FileInfo* newInfo = [[FileInfo alloc]initWithFileName:filePath andChecksum:newChecksum];
        //get the fileinfo of the file in the old version
        FileInfo* oldInfo = [[FileInfo alloc]initWithFileName:filePath andChecksum:oldChecksum];
        
        if (oldInfo == nil) { //new file in new version wow
            DebugLog(@"New file %@ detected in version %ld, not present in version %ld", filePath, (long)newVersion, (long)oldVersion);
            [files addObject:filePath];
        }else if (![newInfo compareWith:oldInfo]) {
            DebugLog(@"File %@ has been modifed in new version", filePath);
            [files addObject:filePath];
        }
        
    }
    return @{@"Remove":filesToRemove.allObjects,@"Patch":files};
}

- (void)savePackageVersion
{
    NSDictionary *directoryInfo = [self getDirectoryInfo:[appInfo objectForKey:@"Path"]];
    //DebugLog(@"dictionary info ok %@", directoryInfo);
    [versionDict setObject:directoryInfo forKey:[NSString stringWithFormat:@"%ld",(long)[self appVersion]]];
    
    DebugLog(@"versionDict %@", versionDict);
   
    [versionDict writeToFile:appArchiveLocation atomically:YES];

    DebugLog(@"save archive root object ok");
}

@end
