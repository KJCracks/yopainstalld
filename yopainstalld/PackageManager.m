//
//  PackageManager.m
//  yopainstalld
//

#import "PackageManager.h"
#import "MobileInstallation.h"

void listdir(const char *name, int level, NSMutableArray** array)
{
    DIR *dir;
    struct dirent *entry;
    //printf("ieterating %s", name);
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
            //printf("%*s[%s]\n", level*2, "", entry->d_name);
            listdir(path, level + 1, array);
        }
        else {
            printf("%*s- %s%s\n", level*2, "", name, entry->d_name);
            [*array addObject:[NSString stringWithFormat:@"%s%s", name, entry->d_name]];
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
        NSDictionary* options = @{@"ApplicationType":@"User",@"ReturnAttributes":@[@"CFBundleShortVersionString",@"CFBundleVersion",@"Path",@"CFBundleDisplayName",@"CFBundleIdentifier",@"ApplicationSINF",@"MinimumOSVersion"]};
        apps = MobileInstallationLookup(options);
    });
    return apps;
}

-(id)initWithBundleIdentifier:(NSString*)bundle {
    if (self = [super init]) {
        appBundleIdentifier = bundle;
        appInfo = [[PackageManager appLookup] objectForKey:bundle];
        if (appInfo == nil) {
            DebugLog(@"Couldn't find appInfo for bundle %@!!", bundle);
            return nil;
        }
         appPlist = [@"/etc/yopa/" stringByAppendingPathComponent:[appInfo objectForKey:@"CFBundleIdentifier"]];
        versionDict = [[NSMutableDictionary alloc]initWithContentsOfFile:appPlist];
        if (versionDict == nil) {
            versionDict = [NSMutableDictionary new];
        }
    }
    return self;
}

-(NSDictionary*)getDirectoryInfo:(NSString*)dir {
    NSMutableArray* array;
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    chdir([dir UTF8String]);
    listdir(".", 0, &array);
    for (NSString* file in array) {
        struct stat buffer;
        if (!lstat(file.UTF8String, &buffer)) {
            DebugLog(@"Error could not stat file %@", file);
            FileInfo* info = [[FileInfo alloc] initWithStat:buffer andFileName:file];
            [dict setObject:info forKey:file];
        }
    }
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
    [versionDict setObject:directoryInfo forKey:[appInfo objectForKey:@"CFBundleVersion"]];
    [versionDict writeToFile:appPlist atomically:YES];
    
}
@end
