/*
 **  BookmarkTableController.m
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

#import "BookmarkTableController.h"
#import "BookmarkListView.h"

@implementation BookmarkTableController

- (void)tableView:(NSTableView *)aTableView
    clickedColumn:(NSTableColumn *)aTableColumn {
    
    NSLog (@"function called!");
    
    // The user clicked on a different column than before, thus use normal sorting
    // for this column.
    if ((prevCol == nil) || (prevCol != aTableColumn)) {
        sortOrder = (BOOL)YES;
        
        if (prevCol) {
            [aTableView setIndicatorImage:nil
                            inTableColumn:prevCol];
            [prevCol release];
        }
        
        prevCol = [aTableColumn retain];
        
        // FIXME: implement order-by here.
        [aTableView
            newSorting:
                NSSelectorFromString (
                                        [NSString stringWithFormat:@"%@Comparision:",
                                            [aTableColumn identifier]
                                        ]
                                      )
                
        ];
    }
    else {
        // Current column clicked again, reverse the sort order now.
        sortOrder = !sortOrder;
    }

    [aTableView setIndicatorImage:(sortOrder ? 
                                   [NSImage imageNamed:@"NSAscendingSortIndicator"] :
                                   [NSImage imageNamed:@"NSDescdingSortIndicator"])
                    inTableColumn:aTableColumn];
    [aTableView reloadData];
}

@end
