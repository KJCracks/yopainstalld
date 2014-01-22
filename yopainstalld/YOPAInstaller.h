//
//  YOPAInstaller.h
//  yopainstalld
//

#import <Foundation/Foundation.h>
#import "YOPAPackage.h"

@interface YOPAInstaller : NSObject {
    NSString* _package;
    FILE* _file;
    YOPAPackage* _yopaPackage;
}

@end
