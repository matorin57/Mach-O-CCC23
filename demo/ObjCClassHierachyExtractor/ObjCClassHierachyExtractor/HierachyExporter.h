//
//  HierachyExtractor.h
//  ObjCClassHierachyExtractor
//
//  Created by Garrigan Stafford on 7/12/23.
//

#import "MachOBinary.h"

@interface CCCHierachyExporter : NSObject

+(void) exportHierachy:(CCCMachOBinary*)binary toDirectory:(NSString*)outputDir;

@end
