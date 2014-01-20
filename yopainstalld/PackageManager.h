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
    NSString* appArchiveLocation;
    @public
    NSString* appBundleIdentifier;
    NSDictionary* appInfo;
    NSMutableDictionary* versionDict;
}

+ (instancetype)sharedInstance;

-(id)initWithBundleIdentifier:(NSString*)bundle;
-(NSInteger)appVersion;
-(NSArray*)getPatchVersions;
-(void)savePackageVersion;
-(NSString*)getSignatureOfBundle:(NSString*)bundle;
-(BOOL)isInstalled:(NSString*)bundle signature:(NSString*)signature;

-(NSArray*)getFilesToRemove:(NSInteger)oldVersion newVersion:(NSInteger)newVersion;
-(NSArray*)getFilesToPatch:(NSInteger)oldVersion newVersion:(NSInteger)newVersion;

@end

void listdir(const char *name, int level, NSMutableArray** array);


@interface FileInfo: NSObject<NSCoding> {
    @public
    NSString* fileName;
    NSString* checksum;
}
-(id)initWithStat:(struct stat)buffer andFileName:(NSString*)name;
-(BOOL)compareWith:(FileInfo*)info;
@end