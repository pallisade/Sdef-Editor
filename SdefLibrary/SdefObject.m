//
//  SdefObject.m
//  SDef Editor
//
//  Created by Grayfox on 02/01/05.
//  Copyright 2005 Shadow Lab. All rights reserved.
//

#import "SdefObject.h"
#import "SdefDocument.h"
#import "SdefDocumentation.h"
#import "SdefXMLGenerator.h"
#import "ShadowMacros.h"
#import "SKFunctions.h"
#import "SdefComment.h"
#import "SdefXMLNode.h"
#import "SdefSynonym.h"
#import "SdefImplementation.h"

@implementation SdefObject

+ (void)initialize {
  BOOL tooLate = NO;
  if (!tooLate) {
    [self exposeBinding:@"icon"];
    [self exposeBinding:@"name"];
    tooLate = YES;
  }
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
  return ![key isEqualToString:@"children"];
}

+ (SDObjectType)objectType {
  return kSDUndefinedType;
}

+ (NSString *)defaultName {
  return nil;
}

+ (NSString *)defaultIconName {
  return @"Misc";
}

+ (id)emptyNode {
  return [[[self alloc] initEmpty] autorelease];
}

+ (id)nodeWithName:(NSString *)newName {
  return [[[self alloc] initWithName:newName] autorelease];
}

- (id)init {
  if (self = [self initEmpty]) {
    [self setName:[[self class] defaultName]];
    [self createContent];
  }
  return self;
}

- (id)initEmpty {
  if (self = [super init]) {
    [self setIcon:[NSImage imageNamed:[[self class] defaultIconName]]];
    sd_comments = [[NSMutableArray alloc] init];
    [self setRemovable:YES];
    [self setEditable:YES];
  }
  return self;
}

- (id)initWithName:(NSString *)newName {
  if (self = [self init]) {
    [self setName:newName];
  }
  return self;
}

- (id)initWithAttributes:(NSDictionary *)attributes {
  if (self = [self initEmpty]) {
    [self createContent];
    [self setAttributes:attributes];
    if (![self name]) { [self setName:[[self class] defaultName]]; }
  }
  return self;
}

- (void)dealloc {
  [sd_icon release];
  [sd_name release];
  [sd_synonyms release];
  [sd_comments release];
  [sd_documentation release];
  [sd_childComments release];
  [super dealloc];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ %p> {parent: %@, type:%@, name:%@}",
    NSStringFromClass([self class]), self,
    [[self parent] name], NSFileTypeForHFSTypeCode([self objectType]), [self name]];
}

#pragma mark -
#pragma mark Notifications
- (void)appendChild:(SKTreeNode *)child {
  [[[self document] undoManager] registerUndoWithTarget:child selector:@selector(remove) object:nil];
  [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:[self childCount]] forKey:@"children"];
  [super appendChild:child];
  [(SdefObject *)child setEditable:[self isEditable]];
  [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:[self childCount]] forKey:@"children"];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SdefObjectDidAppendChild"
                                                      object:self
                                                    userInfo:[NSDictionary dictionaryWithObject:child forKey:@"NewTreeNode"]];
}

- (void)prependChild:(SKTreeNode *)child {
  [[[self document] undoManager] registerUndoWithTarget:child selector:@selector(remove) object:nil];
  [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:0] forKey:@"children"];
  [super prependChild:child];
  [(SdefObject *)child setEditable:[self isEditable]];
  [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:0] forKey:@"children"];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SdefObjectDidAppendChild"
                                                      object:self
                                                    userInfo:[NSDictionary dictionaryWithObject:child forKey:@"NewTreeNode"]];
}

- (void)insertChild:(id)child atIndex:(unsigned)idx {
  /* Super call prepend or insertsibling, so no need to notify. */
//  [[[self document] undoManager] registerUndoWithTarget:child selector:@selector(remove) object:nil];
//  [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:idx] forKey:@"children"];
  [super insertChild:child atIndex:idx];
//  [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:idx] forKey:@"children"];
//  [[NSNotificationCenter defaultCenter] postNotificationName:@"SdefObjectDidAppendChild"
//                                                      object:self
//                                                    userInfo:[NSDictionary dictionaryWithObject:child forKey:@"NewTreeNode"]];
}

- (void)insertSibling:(SKTreeNode *)newSibling {
  [[[self document] undoManager] registerUndoWithTarget:newSibling selector:@selector(remove) object:nil];
  [super insertSibling:newSibling];
  [(SdefObject *)newSibling setEditable:[self isEditable]];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SdefObjectDidAppendChild"
                                                      object:[self parent]
                                                    userInfo:[NSDictionary dictionaryWithObject:newSibling forKey:@"NewTreeNode"]];
}

- (void)remove {
  id parent = [self parent];
  unsigned idx = [parent indexOfChildren:self];
  [[[[self document] undoManager] prepareWithInvocationTarget:parent] insertChild:self atIndex:idx];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SdefObjectWillRemoveChild"
                                                      object:[self parent]
                                                    userInfo:[NSDictionary dictionaryWithObject:self forKey:@"RemovedTreeNode"]];
  [parent willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:idx] forKey:@"children"];
  [super remove];
  [parent didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:idx] forKey:@"children"];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SdefObjectDidRemoveChild"
                                                      object:parent];
}

- (void)removeChildAtIndex:(unsigned)idx {
  /* Super call -remove, so no need to undo here */
//  id child = [self childAtIndex:idx];
//  [[[[self document] undoManager] prepareWithInvocationTarget:self] insertChild:child atIndex:idx];
//  [[NSNotificationCenter defaultCenter] postNotificationName:@"SdefObjectWillRemoveChild"
//                                                      object:self
//                                                    userInfo:[NSDictionary dictionaryWithObject:child forKey:@"RemovedTreeNode"]];
//  [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:idx] forKey:@"children"];
  [super removeChildAtIndex:idx];
//  [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:idx] forKey:@"children"];
//  [[NSNotificationCenter defaultCenter] postNotificationName:@"SdefObjectDidRemoveChild"
//                                                      object:self];
}

- (void)removeAllChildren {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SdefObjectWillRemoveAllChildren" object:self];
  [super removeAllChildren];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SdefObjectDidRemoveAllChildren" object:self];
}

#pragma mark -
- (SdefDocument *)document {
  id root = [self findRoot];
  return (root != self) ? [root document] : nil;
}

- (SDObjectType)objectType {
  return [[self class] objectType];
}

- (void)createContent {
}

- (void)createSynonyms {
  id synonyms = [SdefCollection nodeWithName:@"Synonyms"];
  [synonyms setContentType:[SdefSynonym class]];
  [synonyms setElementName:@"synonyms"];
  [self setSynonyms:synonyms];
}

#pragma mark -
#pragma mark Accessors
- (NSImage *)icon {
  return sd_icon;
}

- (void)setIcon:(NSImage *)newIcon {
  if (sd_icon != newIcon) {
    [sd_icon release];
    sd_icon = [newIcon retain];
  }
}

- (NSString *)name {
  return sd_name;
}

- (void)setName:(NSString *)newName {
  if (sd_name != newName) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SDTreeNodeWillChangeNameNotification" object:self];
    [[[self document] undoManager] registerUndoWithTarget:self selector:_cmd object:sd_name];
    [sd_name release];
    sd_name = [newName copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SDTreeNodeDidChangeNameNotification" object:self];
  }
}

- (BOOL)isEditable {
  return sd_flags.editable == 1;
}

- (void)setEditable:(BOOL)flag {
  [self setEditable:flag recursive:NO];
}
- (void)setEditable:(BOOL)flag recursive:(BOOL)recu {
  sd_flags.editable = (flag) ? 1 : 0;
  if (recu) {
    [[self documentation] setEditable:flag];
    [[self synonyms] setEditable:flag recursive:recu];
    id nodes = [self childrenEnumerator];
    id node;
    while (node = [nodes nextObject]) {
      [node setEditable:flag recursive:recu];
    }
  }
}

- (BOOL)isRemovable {
  return sd_flags.editable == 1 && sd_flags.removable == 1;
}

- (void)setRemovable:(BOOL)removable {
  sd_flags.removable = (removable) ? 1 : 0;
}

#pragma mark Optionals children
- (BOOL)hasDocumentation {
  return sd_documentation != nil;
}

- (SdefDocumentation *)documentation {
  return sd_documentation;
}

- (void)setDocumentation:(SdefDocumentation *)doc {
  if (sd_documentation != doc) {
    [sd_documentation release];
    sd_documentation = [doc retain];
    [sd_documentation setEditable:[self isEditable]];
  }	
}

- (BOOL)hasSynonyms {
  return sd_synonyms != nil;
}

- (SdefCollection *)synonyms {
  return sd_synonyms;
}

- (void)setSynonyms:(SdefCollection *)synonyms {
  if (sd_synonyms != synonyms) {
    [sd_synonyms release];
    sd_synonyms = [synonyms retain];
    [sd_synonyms setEditable:[self isEditable]];
  }
}


#pragma mark Comments
- (BOOL)hasComments {
  return [sd_comments count] > 0;
}

- (NSArray *)comments {
  return sd_comments;
}

- (void)setComments:(NSArray *)comments {
  if (sd_comments != comments) {
    [sd_comments release];
    sd_comments = [comments mutableCopy];
  }
}

- (void)addComment:(NSString *)comment {
  if (!sd_comments) {
    sd_comments = [[NSMutableArray alloc] init];
  }
  id cmnt = [SdefComment commentWithString:comment];
//  [[[self document] undoManager] registerUndoWithTarget:sd_comments selector:@selector(removeObject:) object:cmnt];
  [sd_comments addObject:cmnt];
}

- (void)removeCommentAtIndex:(unsigned)index {
  [sd_comments removeObjectAtIndex:index];
}

#pragma mark -
#pragma mark Children KVC compliance
- (NSArray *)children {
  return [super children];
}

- (void)setChildren:(NSArray *)objects {
  [self willChangeValueForKey:@"children"];
  [self removeAllChildren];
  id children = [objects objectEnumerator];
  id child;
  while (child = [children nextObject]) {
    [self appendChild:child];
  }
  [self didChangeValueForKey:@"children"];
}

- (unsigned)countOfChildren {
  return [self childCount];
}

- (id)objectInChildrenAtIndex:(unsigned)index {
  return [self childAtIndex:index];
}

- (void)insertObject:(id)object inChildrenAtIndex:(unsigned)index {
  [self insertChild:object atIndex:index];
}

- (void)removeObjectFromChildrenAtIndex:(unsigned)index {
  [self removeChildAtIndex:index];
}

- (void)replaceObjectInChildrenAtIndex:(unsigned)index withObject:(id)object {
  [self replaceChildAtIndex:index withChild:object];
}

#pragma mark -
#pragma mark XML Generation

- (SdefXMLNode *)xmlNode {
  id node = nil;
  id child = nil;
  id children = nil;
  node = [SdefXMLNode nodeWithElementName:[self xmlElementName]];
  if (node) {
    NSAssert1([node elementName] != nil, @"%@ return an invalid node", self);
    if ([self hasComments])
      [node setComments:[self comments]];
    id documentation = [[self documentation] xmlNode];
    if (nil != documentation) {
      [node prependChild:documentation];
    }
    id synonyms = [[self synonyms] xmlNode];
    if (nil != synonyms) {
      [node appendChild:synonyms];
    }
    children = [self childrenEnumerator];
    while (child = [children nextObject]) {
      id childNode = [child xmlNode];
      if (childNode) {
        NSAssert1([childNode elementName] != nil, @"%@ return an invalid node", child);
        [node appendChild:childNode];
      }
    }
  }
  return node;
}

- (NSString *)xmlElementName {
  return nil;
}

#pragma mark -
#pragma mark XML Parsing

- (void)setAttributes:(NSDictionary *)attrs {
  [self setName:[attrs objectForKey:@"name"]];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
  if ([elementName isEqualToString:@"documentation"]) {
    SdefDocumentation *documentation = [(SdefObject *)[SdefDocumentation alloc] initWithAttributes:attributeDict];
    [self setDocumentation:documentation];
    [self appendChild:documentation]; /* Append to parse, and remove after */
    [parser setDelegate:documentation];
    [documentation setComments:sd_childComments];
    [documentation release];
  } else if ([elementName isEqualToString:@"synonyms"]) {
    SdefCollection *synonyms = [self synonyms];
    [self appendChild:synonyms]; /* Append to parse, and remove after */
    [parser setDelegate:synonyms];
    [synonyms setComments:sd_childComments];
  } else if ([elementName isEqualToString:@"cocoa"] && [self respondsToSelector:@selector(setImpl:)]) {
    SdefImplementation *cocoa = [(SdefObject *)[SdefImplementation alloc] initWithAttributes:attributeDict];
    [(id)self setImpl:cocoa];
    [cocoa setComments:sd_childComments];
    [cocoa release];
  }
  [sd_childComments release];
  sd_childComments = nil;
}

// sent when an end tag is encountered. The various parameters are supplied as above.
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
  if (![elementName isEqualToString:@"cocoa"]) { /* cocoa isn't handle as a child node, but as an ivar */
    [parser setDelegate:[self parent]];
  }
}

// A comment (Text in a <!-- --> block) is reported to the delegate as a single string
- (void)parser:(NSXMLParser *)parser foundComment:(NSString *)comment {
  if (nil == sd_childComments) {
    sd_childComments = [[NSMutableArray alloc] init];
  }
  [sd_childComments addObject:[SdefComment commentWithString:[comment stringByUnescapingEntities:nil]]];
}

@end

#pragma mark -
@implementation SdefCollection

+ (SDObjectType)objectType {
  return kSDCollectionType;
}

+ (NSString *)defaultIconName {
  return @"Folder";
}

- (id)initEmpty {
  if (self = [super initEmpty]) {
    [self setRemovable:NO];
  }
  return self;
}

- (Class)contentType {
  return _contentType;
}

- (void)setContentType:(Class)newContentType {
  if (_contentType != newContentType) {
    _contentType = newContentType;
  }
}

- (NSString *)elementName {
  return sd_elementName;
}

- (void)setElementName:(NSString *)aName {
  if (sd_elementName != aName) {
    [sd_elementName release];
    sd_elementName = [aName retain];
  }
}

- (void)dealloc {
  [sd_elementName release];
  [super dealloc];
}

#pragma mark -
#pragma mark XML Generation

- (SdefXMLNode *)xmlNode {
  return [self childCount] ? [super xmlNode] : nil;
}

- (NSString *)xmlElementName {
  return [self elementName];
}

#pragma mark -
#pragma mark XML Parsing

- (void)setAttributes:(NSDictionary *)attrs {
  /* Do nothing */
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
  /* If valid document, can only be collection content element */
  SdefObject *element = [(SdefObject *)[[self contentType] alloc] initWithAttributes:attributeDict];
  [self appendChild:element];
  [parser setDelegate:element];
  [element release];
  if (sd_childComments) {
    [element setComments:sd_childComments];
    [sd_childComments release];
    sd_childComments = nil;
  }
}

// sent when an end tag is encountered. The various parameters are supplied as above.
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
  [super parser:parser didEndElement:elementName namespaceURI:namespaceURI qualifiedName:qName];
  if ([elementName isEqualToString:@"synonyms"]) {
    [self remove];
  }
}

@end

#pragma mark -
@implementation SdefTerminologyElement

- (id)init {
  if (self = [super init]) {
    [self setImpl:[SdefImplementation node]];
  }
  return self;
}

- (void)dealloc {
  [sd_impl release];
  [sd_code release];
  [sd_desc release];
  [super dealloc];
}

- (void)setEditable:(BOOL)flag recursive:(BOOL)recu {
  if (recu) {
    [sd_impl setEditable:flag];
  }
  [super setEditable:flag recursive:recu];
}

- (SdefImplementation *)impl {
  return sd_impl;
}

- (void)setImpl:(SdefImplementation *)newImpl {
  if (sd_impl != newImpl) {
    [sd_impl release];
    sd_impl = [newImpl retain];
    [sd_impl setEditable:[self isEditable]];
  }
}

- (BOOL)isHidden {
  return sd_hidden;
}

- (void)setHidden:(BOOL)newHidden {
  if (sd_hidden != newHidden) {
    [[[[self document] undoManager] prepareWithInvocationTarget:self] setHidden:sd_hidden];
    sd_hidden = newHidden;
  }
}

- (OSType)code {
  return NSHFSTypeCodeFromFileType(sd_code);
}

- (void)setCode:(OSType)newCode {
  [self setCodeStr:NSFileTypeForHFSTypeCode(newCode)];
}

- (NSString *)codeStr {
  return sd_code;
}

- (BOOL)validateCodeStr:(id *)ioValue error:(NSError **)error {
  NSString *str = *ioValue;
  if ([str length] < 4) {
    *ioValue = @"****";
  } else if ([str length] > 4) {
    str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([str length] > 4)
      *ioValue = [str substringToIndex:4];
    else 
      *ioValue = str;
  }
  return YES;
}

- (void)setCodeStr:(NSString *)str {
  if (sd_code != str) {
    [[[self document] undoManager] registerUndoWithTarget:self selector:_cmd object:sd_code];
    [sd_code release];
    sd_code = [str copy];
  }
}

- (NSString *)desc {
  return sd_desc;
}

- (void)setDesc:(NSString *)newDesc {
  if (sd_desc != newDesc) {
    [[[self document] undoManager] registerUndoWithTarget:self selector:_cmd object:sd_desc];
    [sd_desc release];
    sd_desc = [newDesc copy];
  }
}

#pragma mark -
#pragma mark XML Generation
- (SdefXMLNode *)xmlNode {
  id node = [super xmlNode];
  id attr = [self name];
  if (nil != attr)
    [node setAttribute:attr forKey:@"name"];
  attr = [self codeStr];
  if (nil != attr)
    [node setAttribute:attr forKey:@"code"];
  if ([self isHidden])
    [node setAttribute:@"hidden" forKey:@"hidden"];
  attr = [self desc];
  if (nil != attr)
    [node setAttribute:attr forKey:@"description"];
  id impl = [[self impl] xmlNode];
  if (nil != impl) {
    if ([[[node firstChild] elementName] isEqualToString:@"documentation"]) {
      [node insertChild:impl atIndex:1];
    } else {
      [node prependChild:impl];
    }
  }
  [node setEmpty:![node hasChildren]];
  return node;
}

#pragma mark -
#pragma mark XML Parsing

- (void)setAttributes:(NSDictionary *)attrs {
  [super setAttributes:attrs];
  [self setCodeStr:[attrs objectForKey:@"code"]];
  [self setDesc:[attrs objectForKey:@"description"]];
  [self setHidden:[attrs objectForKey:@"hidden"] != nil];
}

@end

@implementation SdefImports  

+ (SDObjectType)objectType {
  return kSDImportsType;
}

+ (NSString *)defaultName {
  return @"Imports";
}

+ (NSString *)defaultIconName {
  return @"Misc";
}

@end
