//
//  main.m
//  yopainstalld
//
//  Created by Zorro on 19.01.14.
//  Copyright (c) 2014 Zorro. All rights reserved.
//

// XPC Service: Lightweight helper tool that performs work on behalf of an application.
// see http://developer.apple.com/library/mac/#documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html

#include <xpc/xpc.h> // Create a symlink to OSX's SDK. For example, in Terminal run: ln -s /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include/xpc /opt/iOSOpenDev/include/xpc
#include <Foundation/Foundation.h>

#import "YOPAPackage.h"
#import "PackageManager.h"
#import "MobileInstallation.h"

typedef struct yopa_connection {
    __unsafe_unretained xpc_connection_t peer;
    
} yopa_connection;


static void yopainstalld_status(xpc_connection_t peer, NSString* statusMessage) {
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "Status", statusMessage.UTF8String);
    xpc_connection_send_message(peer, message);
}

static void yopainstalld_peer_event_handler(xpc_connection_t peer, xpc_object_t event)
{
	xpc_type_t type = xpc_get_type(event);
	if (type == XPC_TYPE_ERROR) {
		if (event == XPC_ERROR_CONNECTION_INVALID) {
			// The client process on the other end of the connection has either
			// crashed or cancelled the connection. After receiving this error,
			// the connection is in an invalid state, and you do not need to
			// call xpc_connection_cancel(). Just tear down any associated state
			// here.
		} else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
			// Handle per-connection termination cleanup.
		}
	} else {
		assert(type == XPC_TYPE_DICTIONARY);
		// Handle the message.
        
        const char * command = xpc_dictionary_get_string(event, "Command");
        
        if (command == NULL) {
            
            xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(message, "Error", "Wrong Command");
            xpc_dictionary_set_string(message, "Status", "Error");
            xpc_connection_send_message(peer, message);
            
            return;
        }
        
        NSString *_command = [NSString stringWithUTF8String:command];

        // Install only for now
        
        if ([_command isEqualToString:@"Install"]) {
            
            const char * packagePath = xpc_dictionary_get_string(event, "PackagePath");
            
            if (packagePath == NULL) {
                
                xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
                xpc_dictionary_set_string(message, "Error", "Wrong PackagePath");
                xpc_dictionary_set_string(message, "Status", "Error");
                xpc_connection_send_message(peer, message);
                
                return;
            }
            
            NSString *_packagePath = [NSString stringWithUTF8String:packagePath];
            
            yopainstalld_status(peer, [@"Processing file at path: " stringByAppendingString:_packagePath]);
            
            /*{
                xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
                xpc_dictionary_set_string(message, "Status", [@"Processing file at path: " stringByAppendingString:_packagePath].UTF8String);
                xpc_connection_send_message(peer, message);
            }*/

            
            YOPAPackage *_yopaPackage = [[YOPAPackage alloc]initWithPackagePath:_packagePath];
            
            if (!_yopaPackage.isYOPA)
            {
                xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
                xpc_dictionary_set_string(message, "Error", [@"PackagePath is not YOPA file" UTF8String]);
                xpc_dictionary_set_string(message, "Status", "Error");
                xpc_connection_send_message(peer, message);
                
                return;
            }
            
            /*{
                xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
                xpc_dictionary_set_string(message, "Status", "Found YOPA file!");
                xpc_connection_send_message(peer, message);
            }*/
            yopainstalld_status(peer, @"Found YOPA file!");
            
            NSString *ipaPath = [_yopaPackage processPackage];
            
            if (ipaPath == nil) {
                xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
                xpc_dictionary_set_string(message, "Error", "Couldn't find .ipa in YOPA file");
                xpc_dictionary_set_string(message, "Status", "Error");
                xpc_connection_send_message(peer, message);
                return;
            }
            
            int ret = MobileInstallationInstall((__bridge CFStringRef)ipaPath, (__bridge CFDictionaryRef)@{@"ApplicationType":@"User"}, 0, (__bridge void *)(ipaPath));
            
            [[NSFileManager defaultManager]removeItemAtPath:[_yopaPackage getTempDir] error:nil];
            
            if (ret) {
                xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
                xpc_dictionary_set_string(message, "Error", [NSString stringWithFormat:@"Failed to install %@",ipaPath].UTF8String);
                xpc_dictionary_set_string(message, "Status", "Error");
                
                xpc_connection_send_message(peer, message);
                return;
            }
            
            
            xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(message, "Status", "Complete");
            xpc_connection_send_message(peer, message);
            
            return;
        }
        else if ([_command isEqualToString:@"SaveVersion"]) {
            NSString* appBundle = [NSString stringWithFormat:@"%s", xpc_dictionary_get_string(event, "AppBundle")];
            PackageManager* manager = [[PackageManager alloc] initWithBundleIdentifier:appBundle];
            if (manager == nil) {
                //todo send error
                return;
            }
            [manager savePackageVersion];
            yopainstalld_status(peer, @"Complete");
        }
        else if ([_command isEqualToString:@"GetPatchVersions"]) {
            NSString* appBundle = [NSString stringWithFormat:@"%s", xpc_dictionary_get_string(event, "AppBundle")];
            PackageManager* manager = [[PackageManager alloc] initWithBundleIdentifier:appBundle];
            NSArray* versions = [manager getPatchVersions];
            
            xpc_object_t array = xpc_array_create(NULL, 0);
            
            for (NSString *version in versions) {
                xpc_array_append_value(array, xpc_string_create(version.UTF8String));
            }
            
            xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(message, "Status", "Complete");
            xpc_dictionary_set_value(message, "PatchVersions", array);
            xpc_connection_send_message(peer, message);
            

        }
        else if ([_command isEqualToString:@"GetPatchFiles"]) {
            NSString* appBundle = [NSString stringWithFormat:@"%s", xpc_dictionary_get_string(event, "AppBundle")];
            NSInteger appVersion = xpc_dictionary_get_int64(event, "Version");
            PackageManager* manager = [[PackageManager alloc] initWithBundleIdentifier:appBundle];
            NSInteger currentVersion = [manager->appInfo objectForKey:@"CFBundleVersion"];
            
            NSArray* addFiles = [manager getFilesToPatch:appVersion newVersion:currentVersion];
            
            
        }
        else {
            xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(message, "Error", "Wrong Command");
            xpc_dictionary_set_string(message, "Status", "Error");
            xpc_connection_send_message(peer, message);
            
            return;
        }
        
	}
}

static void yopainstalld_event_handler(xpc_connection_t peer)
{
	// By defaults, new connections will target the default dispatch concurrent queue.
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		yopainstalld_peer_event_handler(peer, event);
	});
	
	// This will tell the connection to begin listening for events. If you
	// have some other initialization that must be done asynchronously, then
	// you can defer this call until after that initialization is done.
	xpc_connection_resume(peer);
}

int main(int argc, const char *argv[])
{
	xpc_connection_t service = xpc_connection_create_mach_service("zorro.yopainstalld",
                                                                  dispatch_get_main_queue(),
                                                                  XPC_CONNECTION_MACH_SERVICE_LISTENER);
    
    if (!service) {
        NSLog(@"Failed to create service.");
        exit(EXIT_FAILURE);
    }
    
    xpc_connection_set_event_handler(service, ^(xpc_object_t connection) {
        yopainstalld_event_handler(connection);
    });
    
    
    xpc_connection_resume(service);
    
    dispatch_main();
    
    return EXIT_SUCCESS;
}
