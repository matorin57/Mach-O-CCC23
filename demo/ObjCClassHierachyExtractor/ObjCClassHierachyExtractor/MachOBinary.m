//
//  MachOBinary.m
//  ObjCClassHierachyExtractor
//
//  Created by Garrigan Stafford on 7/12/23.
//

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>
#import "MachOBinary.h"

//struct ObjcClassObject
//{
//             _OBJC_METACLASS_$_ADALTelemetry,     // metaclass
//             _OBJC_CLASS_$_NSObject,              // superclass
//             __objc_empty_cache,                  // cache
//             0x0,                                 // vtable
//             __OBJC_CLASS_RO_$_ADALTelemetry      // data

@implementation CCCObjCClass

-(instancetype) initWithName:(NSString*)name andSuperClassName:(NSString*)superClassName
{
    self  = [super init];
    if(!self)
        return nil;
    _name = name;
    _superClassName = superClassName;
    return self;
}

@end

@implementation CCCMachOBinary
{
    NSMutableArray<CCCObjCClass*>* _classList;
    const struct mach_header_64* _mh;
    intptr_t _slide;
}

-(instancetype) initWithHeader:(const struct mach_header*)machHeader andSlide:(intptr_t)vmaddr_slide
{
    self = [super init];
    if(!self) return nil;

    _name = nil;
    _classList = [NSMutableArray array];
    // Assume 64bit
    _mh = (const struct mach_header_64*)machHeader;
    _slide = vmaddr_slide;

    //NOTE: Don't need to check for endianness since the images are loaded into memory. So they must have the same as us
    // We only want to analyze Dynamically loaded libraries
    if(_mh->filetype != MH_DYLIB)
        return nil;

    // If we can't parse return nil
    if(![self parseBinary])
        return nil;

    return self;
}

-(NSArray<CCCObjCClass*>*) classList
{
    return [NSArray arrayWithArray:_classList];
}

// Could combine these into one pass that would be more efficient and not double loop the

-(bool) parseBinary
{
    // Load commands start directly after the mach header
    struct load_command* currentCmd = (struct load_command*)(_mh+1);
    while((intptr_t)currentCmd < ((intptr_t)(_mh+1))+_mh->sizeofcmds)
    {
        switch(currentCmd->cmd)
        {
            // Grab the name
            case LC_ID_DYLIB:
            {
                struct dylib_command* dylibCmd = (struct dylib_command*)currentCmd;
                _name = [NSString stringWithUTF8String:(const char*)((intptr_t)dylibCmd+dylibCmd->dylib.name.offset)];
                break;
            }
            // Grab the Class list
            // The class list is a section of the __DATA_CONST Segment
            case LC_SEGMENT_64:
            {
                struct segment_command_64* segCmd = (struct segment_command_64*)currentCmd;
                if(![[NSString stringWithUTF8String:segCmd->segname] isEqualToString:@"__DATA_CONST"])
                    break;
                // Iterate through sections looking for objc class list
                struct section_64* currentSect = (struct section_64*)(segCmd+1);
                while((intptr_t)currentSect < (intptr_t)segCmd+segCmd->cmdsize)
                {
                    // If we found the section parse it and break our loop
                    if(strncmp("__objc_classlist", currentSect->sectname, 16) == 0)
                    {
                        [self parseClasslistSection:currentSect];
                        break;
                    }
                    currentSect = currentSect + 1;
                }
                break;
            }
            default:
                break;
        }
        // Iterate to next command
        currentCmd = (struct load_command*)((intptr_t)currentCmd  + currentCmd->cmdsize);
    }
    // We succesfully parsed if we found a name. It could be possible the module has no Obj-C and therefore no classes.
    return _name != nil;
}

-(void) parseClasslistSection:(struct section_64*)section
{
    // The section is a list of pointers to class object
    // Need to account for slize
    uint64_t* currentClass = (uint64_t*)(section->addr+_slide);
    while((intptr_t)currentClass < section->addr+section->size+_slide)
    {
        // If we couldn't get a name skip this class
        const char* cStrClassName = class_getName((__bridge Class _Nullable)((void*)(*currentClass)));
        if(!cStrClassName)
            continue;
        NSString* className = [NSString stringWithUTF8String:cStrClassName];

        // If we couldn't get a super then skip this class, every class other than NSObject will have a super and we don't care about NSObject
        Class superClass = class_getSuperclass((__bridge Class _Nullable)((void*)(*currentClass)));
        if(!superClass)
            continue;
        const char* cStrSuperClassName = class_getName(superClass);
        if(!cStrSuperClassName)
            continue;
        NSString* superClassName = [NSString stringWithUTF8String:cStrSuperClassName];

        [_classList addObject:[[CCCObjCClass alloc] initWithName:className
                                               andSuperClassName:superClassName]];
        currentClass = currentClass+1;
    }
}

@end
