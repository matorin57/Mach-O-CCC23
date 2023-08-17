//
//  HierachyExtractor.m
//  ObjCClassHierachyExtractor
//
//  Created by Garrigan Stafford on 7/12/23.
//

#import <Foundation/Foundation.h>
#import "MachOBinary.h"
#import "HierachyExporter.h"

@interface CCCGraphNode : NSObject
@property(readonly) NSInteger identifier;
@property(readonly) NSString* name;

-(instancetype) initWithIdentifier:(NSInteger)identifier andName:(NSString*)name;
-(NSString*) toJavascriptElementString;

@end

@implementation CCCGraphNode

-(instancetype) initWithIdentifier:(NSInteger)identifier andName:(NSString*)name
{
    self = [super init];
    if(!self)
        return nil;
    _identifier = identifier;
    _name = name;
    return self;
}

-(NSString*) toJavascriptElementString
{
    return [NSString stringWithFormat:@"{ id: %ld, label: \"%@\" },", (long)_identifier, _name];
}

@end

@interface CCCGraphEdge : NSObject
@property(readonly) NSInteger source;
@property(readonly) NSInteger destination;

-(instancetype) initWithSource:(NSInteger)source andDestination:(NSInteger)destination;
-(NSString*) toJavascriptElementString;
@end

@implementation CCCGraphEdge

-(instancetype) initWithSource:(NSInteger)source andDestination:(NSInteger)destination
{
    self = [super init];
    if(!self)
        return nil;
    _source = source;
    _destination = destination;
    return self;
}

-(NSString*) toJavascriptElementString
{
    return [NSString stringWithFormat:@"{ from: %ld, to: %ld },", (long)_source, (long)_destination];
}

@end

@interface CCCGraph : NSObject

@property(readonly) NSArray<CCCGraphNode*>* nodeList;
@property(readonly) NSArray<CCCGraphEdge*>* edgeList;

-(instancetype) initWithNodes:(NSArray<CCCGraphNode*>*)nodes andEdges:(NSArray<CCCGraphEdge*>*)edges;

@end

@implementation CCCGraph

-(instancetype) initWithNodes:(NSArray<CCCGraphNode*>*)nodes andEdges:(NSArray<CCCGraphEdge*>*)edges
{
    self  = [super init];
    if(!self)
        return nil;
    _nodeList = nodes;
    _edgeList = edges;
    return self;
}

@end

static NSString* HTML_FILE_PREAMBLE = @"\
<!DOCTYPE html>\
<html lang=\"en\">\
  <head>\
    <title>Vis Network | Basic usage</title>\
    <script\
      type=\"text/javascript\"\
      src=\"https://visjs.github.io/vis-network/standalone/umd/vis-network.min.js\"\
    ></script>\
    <style type=\"text/css\">\
      #mynetwork {\
        width: 1200px;\
        height: 800px;\
        border: 1px solid lightgray;\
      }\
    </style>\
  </head>\
  <body>\
    <div id=\"mynetwork\"></div>\
    <script type=\"text/javascript\">";

static NSString* HTML_FILE_ENDING = @"\
      var container = document.getElementById(\"mynetwork\");\
      var data = {\
        nodes: nodes,\
        edges: edges,\
      };\
      var options = {edges:{arrows:\"to\"}};\
      var network = new vis.Network(container, data, options);\
    </script>\
  </body>\
</html>";

static NSString* HTML_NODE_LIST_BEGIN = @" var nodes = new vis.DataSet([";
static NSString* HTML_NODE_LIST_END = @"]);";

static NSString* HTML_EDGE_LIST_BEGIN = @"var edges = new vis.DataSet([";
static NSString* HTML_EDGE_LIST_END = @"]);";


@implementation CCCHierachyExporter


+(CCCGraph*) _constructNodeAndEdgeList:(CCCMachOBinary*)binary
{
    NSMutableDictionary<NSString*,NSNumber*>* nameToIdentifierMap = [NSMutableDictionary dictionaryWithCapacity:binary.classList.count];
    NSMutableArray<CCCGraphNode*>* nodes = [NSMutableArray arrayWithCapacity:binary.classList.count];
    NSMutableArray<CCCGraphEdge*>* edges = [NSMutableArray arrayWithCapacity:binary.classList.count];
    NSInteger __block identifier = 1;
    [binary.classList enumerateObjectsUsingBlock:^(CCCObjCClass * _Nonnull cls, NSUInteger idx, BOOL * _Nonnull stop)
     {
        // If nodes don't exist yet create them
        if(nameToIdentifierMap[cls.name] == nil)
        {
            nameToIdentifierMap[cls.name] = [NSNumber numberWithInteger:identifier];
            [nodes addObject:[[CCCGraphNode alloc] initWithIdentifier:identifier andName:cls.name]];
            identifier++;
        }
        if(nameToIdentifierMap[cls.superClassName] == nil)
        {
            nameToIdentifierMap[cls.superClassName] = [NSNumber numberWithInteger:identifier];
            [nodes addObject:[[CCCGraphNode alloc] initWithIdentifier:identifier andName:cls.superClassName]];
            identifier++;
        }
        // Add edge
        [edges addObject:[[CCCGraphEdge alloc] initWithSource:nameToIdentifierMap[cls.superClassName].integerValue
                                               andDestination:nameToIdentifierMap[cls.name].integerValue]];
    }];
    return [[CCCGraph alloc] initWithNodes:[NSArray arrayWithArray:nodes]
                                  andEdges:[NSArray arrayWithArray:edges]];
}

+(void) exportHierachy:(CCCMachOBinary*)binary toDirectory:(NSString*)outputDir
{
    CCCGraph* graph =  [self _constructNodeAndEdgeList:binary];
    if([binary.name containsString:@"Foundation"])
        NSLog(@"%@", [graph.nodeList debugDescription]);
    if(graph.nodeList.count == 0)
        return;
    // Binary path name only want last componenet
    NSString* binaryName = [binary.name lastPathComponent];
    NSString* filePath = [outputDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.html", binaryName]];
    NSMutableString* outputString = [NSMutableString stringWithString:HTML_FILE_PREAMBLE];

    // Output nodes to html file
    [outputString appendString:HTML_NODE_LIST_BEGIN];
    [graph.nodeList enumerateObjectsUsingBlock:^(CCCGraphNode * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
     {
        [outputString appendString:[obj toJavascriptElementString]];
    }];
    [outputString appendString:HTML_NODE_LIST_END];

    // Output Edges
    [outputString appendString:HTML_EDGE_LIST_BEGIN];
    [graph.edgeList enumerateObjectsUsingBlock:^(CCCGraphEdge * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
     {
        [outputString appendString:[obj toJavascriptElementString]];
    }];
    [outputString appendString:HTML_EDGE_LIST_END];

    // Finish up file
    [outputString appendString:HTML_FILE_ENDING];

    // Flush to disk
    NSError* err = nil;
    [outputString writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&err];
    assert(err == nil);
}

@end
