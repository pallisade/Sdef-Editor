/*
 *  SdefEditor.m
 *  Sdef Editor
 *
 *  Created by Rainbow Team.
 *  Copyright © 2006 Shadow Lab. All rights reserved.
 */

#import "SdefEditor.h"
#import <ShadowKit/SKFunctions.h>
#import <ShadowKit/SKApplication.h>

#include <Carbon/Carbon.h>

#import "SdefSuite.h"
#import "Preferences.h"
#import "SdefDocument.h"
#import "AeteImporter.h"
#import "SdefDictionary.h"
#import "ImporterWarning.h"
#import "OSASdefImporter.h"
#import "CocoaSuiteImporter.h"
#import "SdefObjectInspector.h"
#import "SdefWindowController.h"
#import "ImportApplicationAete.h"

#if defined (DEBUG)
#import <Foundation/NSDebug.h>
#endif

int main(int argc, const char *argv[]) {
#if defined (DEBUG)  
  NSDebugEnabled = YES;
  NSHangOnUncaughtException = YES;
#endif
  return NSApplicationMain(argc, argv);
}

NSString * ScriptingDefinitionFileType = @"ScriptingDefinition";
const OSType kScriptingDefinitionHFSType = 'Sdef';
NSString * CocoaSuiteDefinitionFileType = @"AppleScriptSuiteDefinition";
const OSType kCocoaSuiteDefinitionHFSType = 'ScSu';

NSString *TigerScriptingDefinitionFileType = @"TigerScriptingDefinition";
NSString *PantherScriptingDefinitionFileType = @"PantherScriptingDefinition";

#if defined (DEBUG)
@interface SdefEditor (DebugFacility)
- (void)createDebugMenu;
@end
#endif

@interface SdefDocumentController : NSDocumentController {
}
@end

@implementation SdefEditor

+ (void)initialize {
  if ([SdefEditor class] == self) {
    if (SKSystemMajorVersion() == 10 && SKSystemMinorVersion() >= 5) {
      /* Redefine type using UTI */
      ScriptingDefinitionFileType = @"com.apple.scripting-definition";
      CocoaSuiteDefinitionFileType = @"org.shadowlab.cocoa-scripting";
      
      TigerScriptingDefinitionFileType = @"org.shadowlab.sdef.tiger";
      PantherScriptingDefinitionFileType = @"org.shadowlab.sdef.panther";
    }
  }
}

- (id)init {
  if (self = [super init]) {
    NSString *sdp = @"/usr/bin/sdp";
    /* Pre-Tiger versions */
    if (SKSystemMajorVersion() == 10 && SKSystemMinorVersion() < 4) {
      sdp = @"/Developer/Tools/sdp";
    }
    NSString *rez = @"/Developer/Tools/Rez";
    [[SdefDocumentController alloc] init];
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
      SKBool(YES), @"SdefOpenAtStartup",
      SKBool(![[NSFileManager defaultManager] fileExistsAtPath:sdp]), @"SdefBuildInSdp",
      SKBool(![[NSFileManager defaultManager] fileExistsAtPath:rez]), @"SdefBuildInRez",
      SKBool(YES), @"SdefAutoSelectItem",
      sdp, @"SdefSdpToolPath",
      rez, @"SdefRezToolPath",
      nil]];
    [NSApp setDelegate:self];
#if defined (DEBUG)
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
      // @"YES", @"NSShowNonLocalizedStrings",
      // @"NO", @"NSShowAllViews",
      // @"6", @"NSDragManagerLogLevel",
      // @"YES", @"NSShowNonLocalizableStrings",
      // @"1", @"NSScriptingDebugLogLevel",
      nil]];
#endif
  } 
  return self;
}

- (void)awakeFromNib {
#if defined (DEBUG)
  [self createDebugMenu];
#endif
  NSMenu *file = [[[NSApp mainMenu] itemWithTag:1] submenu];
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_4
  // If Panther, remove open application sdef menu
  if (!OSACopyScriptingDefinition) {
    [file removeItem:[file itemWithTag:1]];
  }
#endif
#if __LP64__
  NSMenuItem *export = [file itemWithTag:2];
  if (export) {
    NSMenuItem *item  = [[export submenu] itemAtIndex:0];
    if (item) {
      [item retain];
      [[export submenu] removeItem:item];
      [item setTitle:NSLocalizedString(@"Create Dictionary...", @"Create dictionary 64 bits title")];
      NSInteger idx = [file indexOfItem:export];
      [file removeItem:export];
      [file insertItem:item atIndex:idx];
      [item release];
    }
  }
#endif
}

- (IBAction)openInspector:(id)sender {
  [[SdefObjectInspector sharedInspector] showWindow:sender];
}

- (IBAction)preferences:(id)sender {
  static Preferences *preferences = nil;
  if (!preferences) {
    preferences = [[Preferences alloc] init];
  }
  [preferences showWindow:sender];
}

- (IBAction)releaseNotes:(id)sender {
  [[NSHelpManager sharedHelpManager] openHelpAnchor:@"SdefReleaseNotes" inBook:@"Sdef Editor Help"];
}

- (IBAction)openSuite:(id)sender {
  NSString *suite = nil;
  switch ([sender tag]) {
    case 1:
      suite = @"NSCoreSuite";
      break;
    case 2:
      suite = @"NSTextSuite";
      break;
    case 3:
      suite = @"AppleScriptKit";
      break;
    case 4:
      suite = @"Skeleton";
      break;
  }
  NSString *suitePath = [[NSBundle mainBundle] pathForResource:suite ofType:@"sdef"];
  if (suitePath) {
    NSDocumentController *ctrl = [NSDocumentController sharedDocumentController];
    NSDocument *doc = [ctrl openDocumentWithContentsOfFile:suitePath
                                                    display:NO];
    if (doc) {
      [doc setFileName:nil];
      [doc showWindows];
    }
  }
}

#pragma mark -
#pragma mark Importation
- (IBAction)openApplicationTerminology:(id)sender {
// Don't check weak ref in Tiger
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_4
  if (!OSACopyScriptingDefinition) {
    NSBeep();
    return;
  }
#endif
  
  ImportApplicationAete *panel = [[ImportApplicationAete alloc] initWithWindowNibName:@"ImportApplicationSdef"];
  [panel showWindow:sender];
  [NSApp runModalForWindow:[panel window]];
  SKApplication *appli = [panel selection];
  if (appli) {
    NSString *path = [appli path];
    
    SdefImporter *importer = [[OSASdefImporter alloc] initWithFile:path];
    [self importWithImporter:importer];
    [importer release];
  }
  [panel release];
}

- (void)importWithImporter:(SdefImporter *)importer {
  @try {
    NSArray *suites = [importer sdefSuites];
    SdefDictionary *dico = [importer sdefDictionary];
    if ([dico hasChildren] || [suites count]) {
      SdefDocument *doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:ScriptingDefinitionFileType display:NO];
      
      if (dico) {
        [doc setDictionary:dico];
      } else if ([suites count]) {
        [[doc dictionary] removeAllChildren];
        
        SdefSuite *suite;
        NSEnumerator *items = [suites objectEnumerator];
        while (suite = [items nextObject]) {
          [[doc dictionary] appendChild:suite];
        }
        [[doc undoManager] removeAllActions];
        [doc updateChangeCount:NSChangeCleared];
      }
      
      [doc showWindows];
      
      if ([importer warnings]) {
        ImporterWarning *alert = [[ImporterWarning alloc] init];
        [alert setWarnings:[importer warnings]];
        [alert setReleasedWhenClosed:YES];
        [alert showWindow:nil];
      }
    } else {
      NSRunAlertPanel(@"Importation failed!", @"Sdef Editor cannot import this file. Is it in a valid format?", @"OK", nil, nil);
    }
  } @catch (id exception) {
    SKLogException(exception);
    NSBeep();
  }
}

- (void)importCocoaScriptFile:(NSString *)file {
  CocoaSuiteImporter *importer = [[CocoaSuiteImporter alloc] initWithContentsOfFile:file];
  if (![importer terminology]) {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanCreateDirectories:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setTreatsFilePackagesAsDirectories:YES];
    [openPanel setPrompt:@"Open Terminology"];
    [openPanel setMessage:[NSString stringWithFormat:@"Where is %@.scriptTerminology?",
      [[file lastPathComponent] stringByDeletingPathExtension]]];
    switch([openPanel runModalForTypes:[NSArray arrayWithObject:@"scriptTerminology"]]) {
      case NSCancelButton:
        [importer release];
        return;
    }
    if (![[openPanel filenames] count]) {
      [importer release];
      return;
    }
    [importer setTerminology:[NSDictionary dictionaryWithContentsOfFile:[[openPanel filenames] objectAtIndex:0]]];
  }
  [self importWithImporter:importer];
  [importer release];
}

- (IBAction)importCocoaTerminology:(id)sender {
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  [openPanel setPrompt:@"Import"];
  [openPanel setMessage:@"Choose a Cocoa .scriptSuite File"];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanCreateDirectories:NO];
  [openPanel setCanChooseDirectories:NO];
  [openPanel setAllowsMultipleSelection:NO];
  [openPanel setTreatsFilePackagesAsDirectories:YES];
  switch([openPanel runModalForTypes:[NSArray arrayWithObject:@"scriptSuite"]]) {
    case NSCancelButton:
      return;
  }
  if (![[openPanel filenames] count]) return;
  
  NSString *file = [[openPanel filenames] objectAtIndex:0];
  [self importCocoaScriptFile:file];
}

- (IBAction)importAete:(id)sender {
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  [openPanel setPrompt:@"Import"];
  [openPanel setMessage:@"Choose an aete Rsrc File"];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanCreateDirectories:NO];
  [openPanel setCanChooseDirectories:NO];
  [openPanel setAllowsMultipleSelection:NO];
  [openPanel setTreatsFilePackagesAsDirectories:YES];
  switch([openPanel runModalForTypes:nil]) {
    case NSCancelButton:
      return;
  }
  if (![[openPanel filenames] count]) return;
  
  NSString *file = [[openPanel filenames] objectAtIndex:0];
  AeteImporter *aete = [[AeteImporter alloc] initWithContentsOfFile:file];
  [self importWithImporter:aete];
  [aete release];
}

- (IBAction)importApplicationAete:(id)sender {
  ImportApplicationAete *panel = [[ImportApplicationAete alloc] init];
  [panel showWindow:sender];
  [NSApp runModalForWindow:[panel window]];
  SKApplication *appli = [panel selection];
  if (appli) {
    if (![appli isRunning]) {
      [appli launch];
    }
    AeteImporter *aete = nil;
    switch ([appli idType]) {
      case kSKApplicationOSType:
        aete = [[AeteImporter alloc] initWithApplicationSignature:[appli signature]]; 
        break;
      case kSKApplicationBundleIdentifier:
        aete = [[AeteImporter alloc] initWithApplicationBundleIdentifier:[appli identifier]];
        break;
      default:
        aete = nil;
    }
    if (aete) {
      [self importWithImporter:aete];
      [aete release];
    } else {
      NSBeep();
    }
  }
  [panel release];
}

#pragma mark -
#pragma mark Application Delegate

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
  NSString *type = [[NSDocumentController sharedDocumentController] typeFromFileExtension:[filename pathExtension]];
  if ([type isEqualToString:CocoaSuiteDefinitionFileType]) {
    [self importCocoaScriptFile:filename];
    return YES;
  }
  /* lets document manager handle it */
  return NO;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"SdefOpenAtStartup"];
}

#pragma mark -
#pragma mark Debug Menu
#if defined (DEBUG)
- (void)createDebugMenu {
//  id debugMenu = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
//  id menu = [[NSMenu alloc] initWithTitle:@"Debug"];
//  [menu addItemWithTitle:@"Create XHTML dictionary" action:@selector(SdtplExporter:) keyEquivalent:@""];
//  [debugMenu setSubmenu:menu];
//  [menu release];
//  [[NSApp mainMenu] insertItem:debugMenu atIndex:[[NSApp mainMenu] numberOfItems] -1];
//  [debugMenu release];
}

#endif

@end

@implementation SdefDocumentController

- (NSString *)typeFromFileExtension:(NSString *)fileExtensionOrHFSFileType {
  if ([fileExtensionOrHFSFileType isEqualToString:@"sdef"] || 
      [fileExtensionOrHFSFileType isEqualToString:NSFileTypeForHFSTypeCode(kScriptingDefinitionHFSType)])
    return ScriptingDefinitionFileType;
  return [super typeFromFileExtension:fileExtensionOrHFSFileType];
}

- (void)noteNewRecentDocument:(NSDocument *)aDocument {
  NSString *path = [aDocument fileName];
  if (![path hasPrefix:[[NSBundle mainBundle] bundlePath]]) {
    [super noteNewRecentDocument:aDocument];
  }
}

@end
