//
//  YOPAInstaller.m
//  yopainstalld
//

#import "YOPAInstaller.h"
#import "YOPAPackage.h"

@implementation YOPAInstaller

- (id)initWithPackage:(NSString*)package {
    if (self = [super init]) {
        _package = package;
        _file = fopen(package.UTF8String, "r");
    }
    return self;
}
- (YOPAPackageType) getPackageType {
    fseek(_file, -sizeof(uint32_t), 0);
    uint32_t magic;
    fread(&magic, sizeof(uint32_t), 1, _file);
    if (magic == YOPA_HEADER_MAGIC) {
        
    }
    return UNKNOWN;
}
- (void)processPackage {
    
}


@end
