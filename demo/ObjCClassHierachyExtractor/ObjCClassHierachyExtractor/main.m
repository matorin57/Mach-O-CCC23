//
//  main.m
//  ObjCClassHierachyExtractor
//
//  Created by Garrigan Stafford on 7/12/23.
//

#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import "MachOBinary.h"
#import "HierachyExporter.h"
#import <Intents/Intents.h>
static NSOperationQueue* opQueue = nil;
static NSString* outputDir = nil;
void parseLoadedBinary(const struct mach_header* mh, intptr_t vmaddr_slide)
{
    static int count = 0;
    [opQueue addOperationWithBlock:^{
        [CCCHierachyExporter exportHierachy:[[CCCMachOBinary alloc] initWithHeader:mh
                                                                          andSlide:vmaddr_slide]
                                  toDirectory:outputDir];
        count++;
        NSLog(@"Finished an Image %d", count);
    }];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Initalize our queue and output directory
        opQueue = [[NSOperationQueue alloc] init];
        opQueue.maxConcurrentOperationCount = 5;
        if([[[NSProcessInfo processInfo] arguments] count] >= 2)
        {
            outputDir = [[NSProcessInfo processInfo] arguments][1];
            BOOL isDirectory = false;
            if(![[NSFileManager defaultManager] fileExistsAtPath:outputDir isDirectory:&isDirectory] || !isDirectory)
            {
                NSLog(@"Error: Either the passed in directory does not exist or is not a directory.");
                return 1;
            }
        }
        else
        {
            NSLog(@"Error: No output directory passed in");
            return 1;
        }
        // Parse all binaries loaded into memory
        NSLog(@"Parsing Loaded Binaries");
        _dyld_register_func_for_add_image(parseLoadedBinary);
        [opQueue waitUntilAllOperationsAreFinished];
        static INReservation* someReservation = nil;
    }
    return 0;
}

