//
//  YOPAPackage.h
//  yopa
//

#import <Foundation/Foundation.h>
#pragma pack(1)

#define YOPA_MAGIC 0xf00dface
#define ZIP_COMPRESSION 0
#define SEVENZIP_COMPRESSION 7

struct YOPA_Header {
    int main_compression_format;
  	uint32_t supported_archs[10];
	fpos_t patch_offsets[50];
	int app_version;
	char app_bundle[100];
  	char cracker_name[100];
	char cracker_message[4096];
	
};

struct YOPA_Patch {
    char old_package_signature;
    int old_package_version;
    int patch_size;
};

@interface YOPAPackage : NSObject
{
    NSString* _packagePath;
    FILE* _package;
    struct YOPA_Header _header;
    NSString* _tmpDir;
}

- (id)initWithPackagePath:(NSString*) packagePath;
- (NSString*) processPackage;
- (BOOL) isYOPA;
- (NSString*)getTempDir;

@end
