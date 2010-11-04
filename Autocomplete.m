// -*- mode:objc -*-
/*
 **  Autocomplete.m
 **
 **  Copyright (c) 2010
 **
 **  Author: George Nachman
 **
 **  Project: iTerm2
 **
 **  Description: Implements the Autocomplete UI. It grabs the word behind the
 **      cursor and opens a popup window with likely suffixes. Selecting one
 **      appends it, and you can search the list Quicksilver-style.
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

#include <wctype.h>
#import "Autocomplete.h"
#import "iTerm/iTermController.h"
#import "iTerm/VT100Screen.h"
#import "iTerm/PTYTextView.h"
#import "LineBuffer.h"
@implementation AutocompleteWindow

- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)aStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag
{
    self = [super initWithContentRect:contentRect
                            styleMask:NSBorderlessWindowMask
                              backing:bufferingType
                                defer:flag];
    [self setCollectionBehavior:NSWindowCollectionBehaviorMoveToActiveSpace];

    return self;
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (void)keyDown:(NSEvent *)event
{
    id cont = [self windowController];
    if (cont && [cont respondsToSelector:@selector(keyDown:)]) {
        [cont keyDown:event];
    }
}

@end

@implementation AutocompleteView

- (id)init
{
    self = [super initWithWindowNibName:@"Autocomplete"];
    if (!self) {
        return nil;
    }

    prefix_ = [[NSMutableString alloc] init];
    substring_ = [[NSMutableString alloc] init];
    unfilteredModel_ = [[NSMutableArray alloc] init];
    model_ = [[NSMutableArray alloc] init];
    [self window];
    return self;
}

- (void)updatePrefix
{
    int tx1, ty1, tx2, ty2;
    VT100Screen* screen = [dataSource_ SCREEN];
    int x = [screen cursorX]-2;
    if (x < 0) {
        [prefix_ setString:@""];
    } else {
        NSString* s = [[dataSource_ TEXTVIEW] getWordForX:x
                                                        y:[screen cursorY] + [screen numberOfLines] - [screen height] - 1
                                                   startX:&tx1
                                                   startY:&ty1
                                                     endX:&tx2
                                                     endY:&ty2];
        [prefix_ setString:s];
        startX_ = tx1;
        startY_ = ty1 + [screen scrollbackOverflow];
    }
    [self refresh];
}

- (void)setDataSource:(PTYSession*)dataSource
{
    dataSource_ = dataSource;
}

- (void)dealloc
{
    [unfilteredModel_ release];
    [model_ release];
    [prefix_ release];
    [substring_ release];
    [populateTimer_ invalidate];
    [populateTimer_ release];
    [super dealloc];
}

- (void)refresh
{
    [self _populateUnfilteredModel];
}

- (void)setPosition
{
    BOOL onTop = NO;

    VT100Screen* screen = [dataSource_ SCREEN];
    int cx = [screen cursorX] - 1;
    int cy = [screen cursorY];

    PTYTextView* tv = [dataSource_ TEXTVIEW];

    NSRect frame = [[self window] frame];
    frame.size.height = [[table_ headerView] frame].size.height + [model_ count] * ([table_ rowHeight] + [table_ intercellSpacing].height);

    NSPoint p = NSMakePoint(MARGIN + cx * [tv charWidth], ([screen numberOfLines] - [screen height] + cy) * [tv lineHeight]);
    p = [tv convertPoint:p toView:nil];
    p = [[tv window] convertBaseToScreen:p];
    p.y -= frame.size.height;

    // p.y gives the bottom of the frame relative to the bottom of the screen, assuming it's below the cursor.
    NSRect monitorFrame = [[[self window] screen] visibleFrame];
    float bottomOverflow = monitorFrame.origin.y - p.y;
    float topOverflow = p.y + 2 * frame.size.height + [tv lineHeight] - (monitorFrame.origin.y + monitorFrame.size.height);
    if (topOverflow < bottomOverflow) {
        p.y += frame.size.height + [tv lineHeight];
        onTop = YES;
    }
    float rightX = monitorFrame.origin.x + monitorFrame.size.width;
    if (p.x + frame.size.width > rightX) {
        float excess = p.x + frame.size.width - rightX;
        p.x -= excess;
    }

    frame.origin = p;
    [[self window] setFrame:frame display:NO];
    [self setOnTop:onTop];
}

- (void)_updateFilter
{
    [model_ removeAllObjects];
    for (NSString* s in unfilteredModel_) {
        if ([self _word:s matchesFilter:substring_]) {
            [model_ addObject:s];
        }
    }
    [table_ reloadData];
    [self setPosition];
    [table_ sizeToFit];
    [[table_ enclosingScrollView] setHasHorizontalScroller:NO];

    if ([table_ selectedRow] == -1 && [table_ numberOfRows] > 0) {
        NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:0];
        [table_ selectRowIndexes:indexes byExtendingSelection:NO];
    }
}

- (void)setOnTop:(BOOL)onTop
{
    onTop_ = onTop;
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
    [[self window] close];
    clearFilterOnNextKeyDown_ = NO;
    if (timer_) {
        [timer_ invalidate];
        timer_ = nil;
    }
    [substring_ setString:@""];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    clearFilterOnNextKeyDown_ = NO;
    if (timer_) {
        [timer_ invalidate];
        timer_ = nil;
    }
    [substring_ setString:@""];
    [self refresh];
    if ([table_ numberOfRows] > 0) {
        NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:[table_ numberOfRows] - 1];
        [table_ selectRowIndexes:indexes byExtendingSelection:NO];
    }
}


// DataSource methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    NSLog(@"Table view has %d rows", [model_ count]);
    return [model_ count];
}

- (NSAttributedString*)attributedStringForValue:(NSString*)value
{
    NSMutableAttributedString* as = [[[NSMutableAttributedString alloc] init] autorelease];
    NSDictionary* lightAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont systemFontOfSize:[NSFont systemFontSize]], NSFontAttributeName,
                                     [NSColor grayColor], NSForegroundColorAttributeName,
                                     nil];
    NSDictionary* plainAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont systemFontOfSize:[NSFont systemFontSize]], NSFontAttributeName,
                                     nil];
    NSDictionary* boldAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont boldSystemFontOfSize:[NSFont systemFontSize]], NSFontAttributeName,
                                    nil];
    value = [value stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSAttributedString* attributedSubstr;
    attributedSubstr = [[[NSAttributedString alloc] initWithString:prefix_
                                                        attributes:lightAttributes] autorelease];
    [as appendAttributedString:attributedSubstr];
    NSString* temp = value;
    for (int i = 0; i < [substring_ length]; ++i) {
        unichar wantChar = [substring_ characterAtIndex:i];
        NSRange r = [temp rangeOfString:[NSString stringWithCharacters:&wantChar length:1] options:NSCaseInsensitiveSearch];
        if (r.location == NSNotFound) {
            return nil;
        }
        NSRange prefix;
        prefix.location = 0;
        prefix.length = r.location;
        if (prefix.length > 0) {
            NSString* substr = [temp substringWithRange:prefix];
            attributedSubstr = [[[NSAttributedString alloc] initWithString:substr attributes:plainAttributes] autorelease];
            [as appendAttributedString:attributedSubstr];
        }

        unichar matchChar = [temp characterAtIndex:r.location];
        attributedSubstr = [[[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:&matchChar length:1] attributes:boldAttributes] autorelease];
        [as appendAttributedString:attributedSubstr];

        r.length = [temp length] - r.location - 1;
        ++r.location;
        temp = [temp substringWithRange:r];
    }

    if ([temp length] > 0) {
        attributedSubstr = [[[NSAttributedString alloc] initWithString:temp attributes:plainAttributes] autorelease];
        [as appendAttributedString:attributedSubstr];
    }

    return as;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    return [self attributedStringForValue:[model_ objectAtIndex:rowIndex]];
}

- (void)rowSelected:(id)sender;
{
    if ([table_ selectedRow] >= 0) {
        [dataSource_ insertText:[model_ objectAtIndex:[table_ selectedRow]]];
        [[self window] close];
    }
}

- (void)keyDown:(NSEvent*)event
{
    unichar c = [[event characters] characterAtIndex:0];
    if (c == '\r') {
        [self rowSelected:self];
    } else if (c == 8 || c == 127) {
        // backspace
        if (timer_) {
            [timer_ invalidate];
            timer_ = nil;
        }
        clearFilterOnNextKeyDown_ = NO;
        [substring_ setString:@""];
        [self _updateFilter];
    } else if (!iswcntrl(c)) {
        if (clearFilterOnNextKeyDown_) {
            [substring_ setString:@""];
            clearFilterOnNextKeyDown_ = NO;
        }
        [substring_ appendString:[event characters]];
        [self _updateFilter];
        if (timer_) {
            [timer_ invalidate];
        }
        timer_ = [NSTimer scheduledTimerWithTimeInterval:4
                                                  target:self
                                                selector:@selector(_setClearFilterOnNextKeyDownFlag:)
                                                userInfo:nil
                                                 repeats:NO];
    } else if (c == 27) {
        // Escape
        [[self window] close];
    }
}

- (void)_setClearFilterOnNextKeyDownFlag:(id)sender
{
    clearFilterOnNextKeyDown_ = YES;
    timer_ = nil;
}

- (BOOL)_word:(NSString*)temp matchesFilter:(NSString*)filter
{
    for (int i = 0; i < [filter length]; ++i) {
        unichar wantChar = [filter characterAtIndex:i];
        NSRange r = [temp rangeOfString:[NSString stringWithCharacters:&wantChar length:1] options:NSCaseInsensitiveSearch];
        if (r.location == NSNotFound) {
            return NO;
        }
        r.length = [temp length] - r.location - 1;
        ++r.location;
        temp = [temp substringWithRange:r];
    }
    return YES;
}

- (void)_populateUnfilteredModel
{
    [unfilteredModel_ removeAllObjects];
    context_.substring = nil;
    VT100Screen* screen = [dataSource_ SCREEN];

    x_ = startX_;
    y_ = startY_ - [screen scrollbackOverflow];

    [screen initFindString:prefix_
          forwardDirection:NO
              ignoringCase:YES
               startingAtX:x_
               startingAtY:y_
                withOffset:1
                 inContext:&context_];

    [self _populateMore:nil];
}

- (void)_populateMore:(id)sender
{
    VT100Screen* screen = [dataSource_ SCREEN];

    int x = x_;
    int y = y_ - [screen scrollbackOverflow];
    const int kMaxOptions = 20;
    BOOL found;

    struct timeval begintime;
    gettimeofday(&begintime, NULL);

    do {
        BOOL more;
        int startX;
        int startY;
        int endX;
        int endY;
        found = NO;
        do {
            context_.hasWrapped = YES;
            more = [screen continueFindResultAtStartX:&startX
                                             atStartY:&startY
                                               atEndX:&endX
                                               atEndY:&endY
                                                found:&found
                                            inContext:&context_];
            if (found) {
                int tx1, ty1, tx2, ty2;
                NSString* word = [[dataSource_ TEXTVIEW] getWordForX:endX y:endY startX:&tx1 startY:&ty1 endX:&tx2 endY:&ty2];
                if (tx1 == startX && [word rangeOfString:prefix_ options:(NSCaseInsensitiveSearch | NSAnchoredSearch)].location == 0) {
                    ++endX;
                    if (endX > [screen width]) {
                        endX = 1;
                        ++endY;
                    }

                    // Grab the last part of the word after the prefix.
                    NSString* result = [[dataSource_ TEXTVIEW] contentFromX:endX Y:endY ToX:tx2 Y:ty2 pad:NO];
                    if ([result length] > 0 && [unfilteredModel_ indexOfObject:result] == NSNotFound) {
                        [unfilteredModel_ addObject:result];
                        NSLog(@"Add %@ in context %@ at %d,%d", result, word, startX, startY);
                    }
                }
                x = x_ = startX;
                y = startY;
                y_ = y + [screen scrollbackOverflow];
            }
        } while (more && [unfilteredModel_ count] < kMaxOptions);

        if (found && [unfilteredModel_ count] < kMaxOptions) {
            // Begin search again before the last hit.
            [screen initFindString:prefix_
                  forwardDirection:NO
                      ignoringCase:YES
                       startingAtX:x_
                       startingAtY:y_
                        withOffset:1
                         inContext:&context_];
        } else {
            // All done.
            break;
        }

        // Don't spend more than 100ms outside of event loop.
        struct timeval endtime;
        gettimeofday(&endtime, NULL);
        int ms_diff = (endtime.tv_sec - begintime.tv_sec) * 1000 +
            (endtime.tv_usec - begintime.tv_usec) / 1000;
        if (ms_diff > 100) {
            // Out of time. Reschedule and try again.
            populateTimer_ = [NSTimer scheduledTimerWithTimeInterval:0.01
                                                              target:self
                                                            selector:@selector(_populateMore:)
                                                            userInfo:nil
                                                             repeats:NO];
            break;
        }
    } while (found && [unfilteredModel_ count] < kMaxOptions);
    populateTimer_ = nil;
    [self _updateFilter];
}

@end