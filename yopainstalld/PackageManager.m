//
//  PackageManager.m
//  yopainstalld
//

#import "PackageManager.h"
#import "MobileInstallation.h"

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
            DebugLog(@"%s/%s", name, entry->d_name);
            [*array addObject:[NSString stringWithFormat:@"%s/%s", name, entry->d_name]];
        }
        
    } while ((entry = readdir(dir)));
    closedir(dir);
    
}

@implementation FileInfo

-(BOOL)compareWith:(FileInfo*)info {
    if ((self->ctime != info->ctime) || (self->mtime != info->mtime) || (self->size != info->size)) {
        return false;
    }
    return true;
}

-(id)initWithStat:(struct stat)buffer andFileName:(NSString*)name {
    if (self = [super init]) {
        self->fileName = name;
        self->ctime = buffer.st_ctimespec.tv_nsec;
        self->mtime = buffer.st_mtimespec.tv_nsec;
        self->size = buffer.st_size;
        self->uid = buffer.st_uid;
    }
    return self;
}

-(void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:fileName forKey:@"FileName"];
    [encoder encodeObject:ctime forKey:@"ctime"];
    [encoder encodeObject:mtime forKey:@"mtime"];
    [encoder encodeObject:size forKey:@"size"];
    [encoder encodeObject:uid forKey:@"uid"];
}

-(id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self->fileName = [decoder decodeObjectForKey:@"FileName"];
        self->ctime = [decoder decodeObjectForKey:@"ctime"];
        self->mtime = [decoder decodeObjectForKey:@"mtime"];
        self->size = [decoder decodeObjectForKey:@"size"];
        self->uid = [decoder decodeObjectForKey:@"uid"];
    }
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
        appArchiveLocation = [@"/etc/yopa/" stringByAppendingPathComponent:[appInfo objectForKey:@"CFBundleIdentifier"]];
        DebugLog(@"applist %@", appArchiveLocation);
        versionDict = [NSKeyedUnarchiver unarchiveObjectWithFile:appArchiveLocation];
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
        //[[file lastPathComponent] stringByDeletingPathExtension];
        struct stat buffer;
        int ret = lstat(_file.UTF8String, &buffer);
        if (ret == -1){
            DebugLog(@"Error could not stat file %@", _file);
            break;
        }
        FileInfo* info = [[FileInfo alloc] initWithStat:buffer andFileName:_file];
        [dict setObject:info forKey:_file];
    }
    DebugLog(@"da dictionary %@", dict);
    return dict;
}
-(NSArray*)getPatchVersions {
    return [versionDict allKeys];
}

-(NSArray*)getFilesToPatch:(NSInteger)oldVersion newVersion:(NSInteger)newVersion {
    NSMutableArray* files = [NSMutableArray new];
    
    NSDictionary* oldVersionDict = [versionDict objectForKey:oldVersion];
    NSDictionary* newVersionDict = [versionDict objectForKey:newVersion];
    
    //loop through all the files in the new version
    for (NSString* filePath in [newVersionDict allKeys]) {
        
        //get the fileinfo of the file in the new version
        FileInfo* newInfo = (FileInfo*)[newVersionDict objectForKey:filePath];
        //get the fileinfo of the file in the old version
        FileInfo* oldInfo = (FileInfo*)[oldVersionDict objectForKey:filePath];
        
        if (oldInfo == nil) { //new file in new version wow
            DebugLog(@"New file %@ detected in version %ld, not present in version %ld", filePath, (long)newVersion, (long)oldVersion);
            [files addObject:filePath];
            continue;
        }
        if (![newInfo compareWith:oldInfo]) {
            DebugLog(@"File %@ has been modifed in new version", filePath);
            [files addObject:filePath];
            continue;
        }
        
    }
    return files;
}

-(NSArray*)getFilesToRemove:(NSInteger)oldVersion newVersion:(NSInteger)newVersion {
    NSMutableArray* files = [NSMutableArray new];
    NSDictionary* oldVersionDict = [versionDict objectForKey:oldVersion];
    NSDictionary* newVersionDict = [versionDict objectForKey:newVersion];
    //loop through all the files in the old version
    for (NSString* filePath in [oldVersionDict allKeys]) {
        if ([newVersionDict objectForKey:filePath] == nil) {
            DebugLog(@"File %@ has been deleted in new version", filePath);
            [files addObject:filePath];
            continue;
        }
    }
    return files;
}

-(void) savePackageVersion {
    NSDictionary *directoryInfo = [self getDirectoryInfo:[appInfo objectForKey:@"Path"]];
    DebugLog(@"hello 1234");
    [versionDict setObject:directoryInfo forKey:appBundleIdentifier];
    DebugLog(@"hello 4321");
    DebugLog(@"oh hello there! %@", appArchiveLocation);
    [NSKeyedArchiver archiveRootObject:versionDict toFile:appArchiveLocation];
    
}
@end
