/*
 *  SdefType.h
 *  Sdef Editor
 *
 *  Created by Rainbow Team.
 *  Copyright © 2006 - 2007 Shadow Lab. All rights reserved.
 */

#import "SdefLeaf.h"

/*
 <!-- TYPES -->
 <!ELEMENT type EMPTY>
 <!ATTLIST type
 %common.attrib;
 type       %Typename;      #REQUIRED
 list       %yorn;          #IMPLIED
 hidden     %yorn;          #IMPLIED
 >
 */

@interface SdefType : SdefLeaf <NSCopying, NSCoding> {

}

@property(nonatomic, getter = isList) BOOL list;

@end
