//
//  PackageManager.h
//  yopainstalld
//

#include <unistd.h>
#include <sys/types.h>
#include <dirent.h>
#include <stdio.h>
#include <sys/stat.h>

#import <Foundation/Foundation.h>

@interface PackageManager : NSObject {
    NSString* appPlist;
    @public
    NSString* appBundleIdentifier;
    NSDictionary* appInfo;
    NSMutableDictionary* versionDict;
}

+ (instancetype)sharedInstance;

-(id)initWithBundleIdentifier:(NSString*)bundle;
-(NSArray*)getPatchVersions;
-(void)savePackageVersion;
-(NSString*)getSignatureOfBundle:(NSString*)bundle;
-(BOOL)isInstalled:(NSString*)bundle signature:(NSString*)signature;

@end

void listdir(const char *name, int level, NSMutableArray** array);


@interface FileInfo: NSObject<NSCoding> {
    @public
    NSString* fileName;
    NSInteger ctime;
    NSInteger mtime;
    NSInteger uid;
    NSInteger size;
}
-(id)initWithStat:(struct stat)buffer andFileName:(NSString*)name;
-(BOOL)compareWith:(FileInfo*)info;
@end