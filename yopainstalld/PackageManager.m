//
//  PackageManager.m
//  yopainstalld
//

#import "PackageManager.h"

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
@end



@implementation PackageManager

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

@end
