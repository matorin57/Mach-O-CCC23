//
//  MachOBinary.h
//  ObjCClassHierachyExtractor
//
//  Created by Garrigan Stafford on 7/12/23.
//

@interface CCCObjCClass : NSObject

-(instancetype) initWithName:(NSString*)name andSuperClassName:(NSString*)superClassName;

@property (readonly) NSString* name;
@property (readonly) NSString* superClassName;

@end

@interface CCCMachOBinary : NSObject

-(instancetype) initWithHeader:(const struct mach_header*)machHeadr andSlide:(intptr_t)vmaddr_slide;

@property (readonly) NSString* name;
@property (readonly) NSArray<CCCObjCClass*>* classList;

@end

