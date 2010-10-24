/*
 **  PTYSession.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
 **
 **  Project: iTerm
 **
 **  Description: Implements the model class for a terminal session.
 **
 **  This program is free software; you can redistribute it and/or modify
 **  it under the terms of the GNU General Public License as published by
 **  the Free Software Foundation; either version 2 of the License, or
 **  (at your option) any later version.
 **
 **  This program is distributed in the hope that it will be useful,
 **  but WITHOUT ANY WARRANTY; without even the implied warranty of
 **  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 **  GNU General Public License for more details.
 **
 **  You should have received a copy of the GNU General Public License
 **  along with this program; if not, write to the Free Software
 **  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <iTerm/BookmarkModel.h>
#import "DVR.h"
#import "WindowControllerInterface.h"

#include <sys/time.h>

@class PTYTask;
@class PTYTextView;
@class PTYScrollView;
@class VT100Screen;
@class VT100Terminal;
@class PreferencePanel;
@class iTermController;
@class iTermGrowlDelegate;
@class FakeWindow;
@class PseudoTerminal;

@interface PTYSession : NSResponder
{
    // Owning tab view item
    NSTabViewItem* tabViewItem;

    // tty device
    NSString* tty;

    id<WindowControllerInterface> parent;  // Parent controller. Always set. Equals one of realParent or fakeParent.
    PseudoTerminal* realParent;  // non-nil only if parent is PseudoTerminal*
    FakeWindow* fakeParent;  // non-nil only if parent is FakeWindow*
    NSString* name;
    NSString* defaultName;
    NSString* windowTitle;

    PTYTask* SHELL;
    VT100Terminal* TERMINAL;
    NSString* TERM_VALUE;
    NSString* COLORFGBG_VALUE;
    VT100Screen* SCREEN;
    BOOL EXIT;
    NSView* view;
    PTYScrollView* SCROLLVIEW;
    PTYTextView* TEXTVIEW;
    NSTimer *updateTimer;

    // anti-idle
    NSTimer* antiIdleTimer;
    char ai_code;

    BOOL autoClose;

    // True if ambiguous-width characters are double-width.
    BOOL doubleWidth;
    BOOL xtermMouseReporting;
    int bell;

    NSString* backgroundImagePath;
    NSDictionary* addressBookEntry;
    Bookmark* originalAddressBookEntry;

    // Growl stuff
    iTermGrowlDelegate* gd;

    // Status reporting
    struct timeval lastInput, lastOutput, lastBlink;
    int objectCount;
    NSImage* icon;
    BOOL isProcessing;
    BOOL newOutput;
    BOOL growlIdle, growlNewOutput;
    bool isDivorced;
    DVR* dvr_;
    DVRDecoder* dvrDecoder_;

    // Set only if this is not a live session. Is a pointer to the hidden live
    // session while looking at the past.
    PTYSession* liveSession_;
}

// init/dealloc
- (id)init;
- (void)dealloc;

// accessor
- (DVR*)dvr;

// accessor
- (DVRDecoder*)dvrDecoder;

// Jump to a particular point in time.
- (long long)irSeekToAtLeast:(long long)timestamp;

// accessor. nil if this session is live.
- (PTYSession*)liveSession;

// test if we're at the beginning/end of time.
- (BOOL)canInstantReplayPrev;
- (BOOL)canInstantReplayNext;

// Disable all timers.
- (void)cancelTimers;

// Begin showing DVR frames from some live session.
- (void)setDvr:(DVR*)dvr liveSession:(PTYSession*)liveSession;

// Go forward/back in time. Must call setDvr:liveSession: first.
- (void)irAdvance:(int)dir;

+ (NSImage*)loadBackgroundImage:(NSString*)imageFilePath;

// Session specific methods
- (BOOL)initScreen:(NSRect)aRect vmargin:(float)vmargin;
- (void)startProgram:(NSString *)program
           arguments:(NSArray *)prog_argv
         environment:(NSDictionary *)prog_env
              isUTF8:(BOOL)isUTF8;
- (void)terminate;
- (BOOL)isActiveSession;

// Preferences
- (void)setPreferencesFromAddressBookEntry: (NSDictionary *)aePrefs;

// PTYTask
- (void)writeTask:(NSData*)data;
- (void)readTask:(NSData*)data;
- (void)brokenPipe;

// PTYTextView
- (BOOL)hasKeyMappingForEvent: (NSEvent *)event highPriority: (BOOL)priority;
- (void)keyDown:(NSEvent *)event;
- (BOOL)willHandleEvent: (NSEvent *)theEvent;
- (void)handleEvent: (NSEvent *)theEvent;
- (void)insertText:(NSString *)string;
- (void)insertNewline:(id)sender;
- (void)insertTab:(id)sender;
- (void)moveUp:(id)sender;
- (void)moveDown:(id)sender;
- (void)moveLeft:(id)sender;
- (void)moveRight:(id)sender;
- (void)pageUp:(id)sender;
- (void)pageDown:(id)sender;
- (void)paste:(id)sender;
- (void)pasteString: (NSString *)aString;
- (void)deleteBackward:(id)sender;
- (void)deleteForward:(id)sender;
- (void)textViewDidChangeSelection: (NSNotification *)aNotification;
- (void)textViewResized: (NSNotification *)aNotification;
- (void)tabViewWillRedraw: (NSNotification *)aNotification;


// misc
- (void)handleOptionClick: (NSEvent *)theEvent;
- (void)setWidth:(int)width height:(int)height;


// Contextual menu
- (void)menuForEvent:(NSEvent *)theEvent menu: (NSMenu *)theMenu;


// get/set methods
- (id<WindowControllerInterface>)parent;
- (void)setParent:(PseudoTerminal*)theParent;
- (void)setFakeParent: (FakeWindow*)theParent;
- (FakeWindow*)fakeWindow;
- (NSTabViewItem *)tabViewItem;
- (void)setTabViewItem: (NSTabViewItem *)theTabViewItem;
- (NSString *)name;
- (void)setName: (NSString *)theName;
- (NSString *)defaultName;
- (void)setDefaultName: (NSString *)theName;
- (NSString *)uniqueID;
- (void)setUniqueID: (NSString *)uniqueID;
- (NSString *)windowTitle;
- (void)setWindowTitle: (NSString *)theTitle;
- (PTYTask *)SHELL;
- (void)setSHELL: (PTYTask *)theSHELL;
- (VT100Terminal *)TERMINAL;
- (void)setTERMINAL: (VT100Terminal *)theTERMINAL;
- (NSString *)TERM_VALUE;
- (void)setTERM_VALUE: (NSString *)theTERM_VALUE;
- (NSString *)COLORFGBG_VALUE;
- (void)setCOLORFGBG_VALUE: (NSString *)theCOLORFGBG_VALUE;
- (VT100Screen *)SCREEN;
- (void)setSCREEN: (VT100Screen *)theSCREEN;
- (NSImage *)image;
- (NSView *)view;
- (PTYTextView *)TEXTVIEW;
- (void)setTEXTVIEW: (PTYTextView *)theTEXTVIEW;
- (PTYScrollView *)SCROLLVIEW;
- (void)setSCROLLVIEW: (PTYScrollView *)theSCROLLVIEW;
- (NSStringEncoding)encoding;
- (void)setEncoding:(NSStringEncoding)encoding;
- (BOOL)antiIdle;
- (int)antiCode;
- (void)setAntiIdle:(BOOL)set;
- (void)setAntiCode:(int)code;
- (BOOL)autoClose;
- (void)setAutoClose:(BOOL)set;
- (BOOL)doubleWidth;
- (void)setDoubleWidth:(BOOL)set;
- (BOOL)xtermMouseReporting;
- (void)setXtermMouseReporting:(BOOL)set;
- (NSDictionary *)addressBookEntry;

// Return the address book that the session was originally created with.
- (Bookmark *)originalAddressBookEntry;
- (void)setAddressBookEntry:(NSDictionary*)entry;
- (int)number;
- (int)objectCount;
- (int)realObjectCount;
- (void)setObjectCount:(int)value;
- (NSString *)tty;
- (NSString *)contents;
- (NSImage *)icon;
- (void)setIcon: (NSImage *)anIcon;
- (iTermGrowlDelegate*)growlDelegate;


- (void)clearBuffer;
- (void)clearScrollbackBuffer;
- (BOOL)logging;
- (void)logStart;
- (void)logStop;
- (NSString *)backgroundImagePath;
- (void)setBackgroundImagePath: (NSString *)imageFilePath;
- (NSColor *)foregroundColor;
- (void)setForegroundColor:(NSColor*)color;
- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor*)color;
- (NSColor *)selectionColor;
- (void)setSelectionColor: (NSColor *)color;
- (NSColor *)boldColor;
- (void)setBoldColor:(NSColor*)color;
- (NSColor *)cursorColor;
- (void)setCursorColor:(NSColor*)color;
- (NSColor *)selectedTextColor;
- (void)setSelectedTextColor: (NSColor *)aColor;
- (NSColor *)cursorTextColor;
- (void)setCursorTextColor: (NSColor *)aColor;
- (float)transparency;
- (void)setTransparency:(float)transparency;
- (BOOL)disableBold;
- (void)setDisableBold: (BOOL)boldFlag;
- (BOOL)disableBold;
- (void)setDisableBold: (BOOL)boldFlag;
- (void)setColorTable:(int)index color:(NSColor *)c;
- (int)optionKey;

// Session status

- (void)resetStatus;
- (BOOL)exited;
- (void)setLabelAttribute;
- (BOOL)bell;
- (void)setBell: (BOOL)flag;
- (BOOL)isProcessing;
- (void)setIsProcessing: (BOOL)aFlag;

- (void)sendCommand: (NSString *)command;

// Display timer stuff
- (void)updateDisplay;
- (void)doAntiIdle;
- (NSString*)ansiColorsMatchingForeground:(NSDictionary*)fg andBackground:(NSDictionary*)bg inBookmark:(Bookmark*)aDict;
- (void)updateScroll;

- (int)columns;
- (int)rows;
- (void)changeFontSizeDirection:(int)dir;
- (void)setFont:(NSFont*)font nafont:(NSFont*)nafont horizontalSpacing:(float)horizontalSpacing verticalSpacing:(float)verticalSpacing;

// Assigns a new GUID to the session so that changes to the bookmark will not
// affect it. Returns the GUID of a divorced bookmark. Does nothing if already
// divorced, but still returns the divorced GUID.
- (NSString*)divorceAddressBookEntryFromPreferences;

// Schedule the screen update timer to run in a specified number of seconds.
- (void)scheduleUpdateIn:(NSTimeInterval)timeout;

@end

@interface PTYSession (ScriptingSupport)

// Object specifier
- (NSScriptObjectSpecifier *)objectSpecifier;
-(void)handleExecScriptCommand: (NSScriptCommand *)aCommand;
-(void)handleTerminateScriptCommand: (NSScriptCommand *)command;
-(void)handleSelectScriptCommand: (NSScriptCommand *)command;
-(void)handleWriteScriptCommand: (NSScriptCommand *)command;

@end

@interface PTYSession (Private)

- (NSString*)_getLocale;
- (void)setDvrFrame;

@end
