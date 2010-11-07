//
//  Popup.h
//  iTerm
//
//  Created by George Nachman on 11/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PTYSession.h"

@interface PopupWindow : NSWindow {
}
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)aStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag;

- (BOOL)canBecomeKeyWindow;
- (void)keyDown:(NSEvent *)event;

@end

@interface PopupEntry : NSObject
{
    NSString* s_;
}

+ (PopupEntry*)entryWithString:(NSString*)s;
- (void)setMainValue:(NSString*)s;
- (NSString*)mainValue;
- (BOOL)isEqual:(id)o;

@end

@interface PopupModel : NSObject
{
    @private
    NSMutableArray* values_;
}

- (id)init;
- (void)dealloc;
- (NSUInteger)count;
- (void)removeAllObjects;
- (void)addObject:(id)object;
- (id)objectAtIndex:(NSUInteger)index;
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len;
- (NSUInteger)indexOfObject:(id)o;

@end


@interface Popup : NSWindowController {
    @private
    // Backing session.
    PTYSession* session_;
    
    // Subclass-owned tableview.
    NSTableView* tableView_;

    // Results currently being displayed.
    PopupModel* model_;
    
    // All candidate results, including those not matching filter. Subclass-owend.
    PopupModel* unfilteredModel_;

    // Timer to set clearFilterOnNextKeyDown_.
    NSTimer* timer_;

    // If set, then next time a key is pressed erase substring_ before appending.
    BOOL clearFilterOnNextKeyDown_;
    // What the user has typed so far to filter result set.
    NSMutableString* substring_;

    // If true then window is above cursor.
    BOOL onTop_;
}

- (id)initWithWindowNibName:(NSString*)nibName tablePtr:(NSTableView**)table model:(PopupModel*)model;
- (void)dealloc;

// Called by clients to open window.
- (void)popInSession:(PTYSession*)session;

// Subclasses may override these methods.
// Begin populating the unfiltered model.
- (void)refresh;

// Notify that a row was selected. Call this method when subclass has accepted
// the selection.
- (void)rowSelected:(id)sender;

// Handle key presses.
- (void)keyDown:(NSEvent*)event;

// Window is closing. Call this method when subclass is done.
- (void)onClose;

// Window is opening
- (void)onOpen;

// Get a value for a table cell. Always returns a value from the model.
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

- (void)setSession:(PTYSession*)session;
- (void)setOnTop:(BOOL)onTop;
- (PTYSession*)session;
- (PopupModel*)unfilteredModel;
- (PopupModel*)model;
- (void)setPosition:(BOOL)canChangeSide;
- (void)reloadData:(BOOL)canChangeSide;
- (void)_setClearFilterOnNextKeyDownFlag:(id)sender;
- (int)convertIndex:(int)i;
- (NSAttributedString*)attributedStringForValue:(NSString*)value;
- (void)windowDidResignKey:(NSNotification *)aNotification;
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (BOOL)_word:(NSString*)temp matchesFilter:(NSString*)filter;


@end