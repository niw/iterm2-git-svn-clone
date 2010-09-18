/*
 **  BookmarkTableController.h
 **  iTerm
 **
 **  Copyright (c) 2010, Mihai Moldovan <ionic@ionic.de>
 **  Description: Custom NSTableView controller class for the in the BookmarkListView
 **  embedded TableView.
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
 */

#import <Cocoa/Cocoa.h>


@interface BookmarkTableController : NSObject {
    // The most recent clicked column.
    NSTableColumn* prevCol;
    
    // Defines our sort order. NO (0) will be reverse sorting, YES (1) normal sorting.
    BOOL sortOrder;
    
    // Defines the column we want to sort by.
    SEL sortColumn;
}

- (void)tableView:(NSTableView *)aTableView
    clickedColumn:(NSTableColumn *)aTableColumn;

@end
