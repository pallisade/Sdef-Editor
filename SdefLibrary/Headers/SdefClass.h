//
//  SdefClass.h
//  SDef Editor
//
//  Created by Grayfox on 02/01/05.
//  Copyright 2005 Shadow Lab. All rights reserved.
//

#import "SdefObject.h"

/*
 <!-- CLASS DEFINITION -->
 <!ELEMENT class (documentation?, %implementation;?, synonyms?, contents?, elements?, properties?, responds-to-commands?, responds-to-events?)>
 <!ATTLIST class
 name       %Classname;     #REQUIRED
 code       %OSType;        #IMPLIED 
 hidden     (hidden)        #IMPLIED 
 plural     %Classname;     #IMPLIED 
 inherits   %Classname;     #IMPLIED 
 description  %Text;        #IMPLIED 
 >
 
 <!-- contents -->
 <!ELEMENT contents (%implementation;?)>
 <!ATTLIST contents
 name       %Classname;     #IMPLIED
 code       %OSType;        #IMPLIED 
 type       %Classname;     #REQUIRED
 access     (r | w | rw)    "rw"     
 hidden     (hidden)        #IMPLIED 
 description  %Text;        #IMPLIED 
 >
 
 <!-- element access -->
 <!ELEMENT elements (element+)>
 <!ELEMENT element (%implementation;?, accessor*)>
 <!ATTLIST element
 type       %Classname;     #REQUIRED
 access     (r | w | rw)    "rw"     
 hidden     (hidden)        #IMPLIED 
 description  %Text;        #IMPLIED 
 >
 
 <!ENTITY % accessor-type "(index | name | id | range | relative | test)">
 <!ELEMENT accessor EMPTY>
 <!ATTLIST accessor
 style      %accessor-type;  #REQUIRED
 >
 
 <!-- properties -->
 <!ELEMENT properties (property+)>
 <!ELEMENT property (documentation?, %implementation;?, synonyms?)>
 <!ATTLIST property
 name       %Term;          #REQUIRED
 code       %OSType;        #IMPLIED 
 hidden     (hidden)        #IMPLIED 
 type       %Typename;      #REQUIRED 
 access     (r | w | rw)    "rw"     
 not-in-properties  (not-in-properties)  #IMPLIED 
 description  %Text;        #IMPLIED 
 >
 
 <!-- supported verbs -->
 <!ELEMENT responds-to-commands (responds-to+)>
 <!ELEMENT responds-to-events (responds-to+)>
 <!ELEMENT responds-to (%implementation;?)>
 <!ATTLIST responds-to
 name       %Verbname;      #REQUIRED
 hidden     (hidden)        #IMPLIED 
 >
*/

enum {
  kSDElementRead = 1 << 0,
  kSDElementWrite = 1 << 1,
};

extern NSString *SDAccessStringFromFlag(unsigned flag);
extern unsigned SDAccessFlagFromString(NSString *str);

/* class, property, and contents */
@class SdefDocumentation, SdefContents;
@interface SdefClass : SdefTerminologyElement {
  SdefContents *sd_contents;
  /* Attributes */
  NSString *sd_plural; 
  NSString *sd_inherits;
}

- (SdefContents *)contents;
- (void)setContents:(SdefContents *)contents;

- (SdefCollection *)properties;
- (SdefCollection *)elements;
- (SdefCollection *)commands;
- (SdefCollection *)events;

- (NSString *)plural;
- (void)setPlural:(NSString *)newPlural;

- (NSString *)inherits;
- (void)setInherits:(NSString *)newInherits;


@end

@interface SdefElement : SdefObject {
  SdefImplementation *sd_impl;
  unsigned int accessors; /* index | name | id | range | relative | test */
  
  /* Attributs */
  unsigned access; /* ( kSDElementRead | kSDElementWrite ) */
  BOOL hidden;
  NSString *desc;
}

- (SdefImplementation *)impl;
- (void)setImpl:(SdefImplementation *)anImpl;

- (unsigned)access;
- (void)setAccess:(unsigned)newAccess;

- (BOOL)isHidden;
- (void)setHidden:(BOOL)flag;

- (NSString *)desc;
- (void)setDesc:(NSString *)newDesc;

@end

@interface SdefProperty : SdefTerminologyElement {
  NSString *sd_type;
  unsigned sd_access;
  BOOL sd_notInProperties; 
}

- (NSString *)type;
- (void)setType:(NSString *)aType;

- (unsigned)access;
- (void)setAccess:(unsigned)newAccess;

- (BOOL)isNotInProperties;
- (void)setNotInProperties:(BOOL)flag;

@end

@interface SdefRespondsTo : SdefObject {
  SdefImplementation *sd_impl;
  BOOL sd_hidden;
}

- (SdefImplementation *)impl;
- (void)setImpl:(SdefImplementation *)anImpl;

- (BOOL)isHidden;
- (void)setHidden:(BOOL)flag;

@end