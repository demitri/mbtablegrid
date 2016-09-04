/*
 Copyright (c) 2008 Matthew Ball - http://www.mattballdesign.com
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MBTableGridHeaderView.h"
#import "MBTableGrid.h"
#import "MBTableGridContentView.h"

NSString* kAutosavedColumnWidthKey = @"AutosavedColumnWidth";
NSString* kAutosavedColumnIndexKey = @"AutosavedColumnIndex";
NSString* kAutosavedColumnHiddenKey = @"AutosavedColumnHidden";

#define kSortIndicatorXInset		4.0  	/* Number of pixels to inset the drawing of the indicator from the right edge */

@interface MBTableGrid (Private)
- (NSString *)_headerStringForColumn:(NSUInteger)columnIndex;
- (NSString *)_headerStringForRow:(NSUInteger)rowIndex;
- (MBTableGridContentView *)_contentView;
- (void)_dragColumnsWithEvent:(NSEvent *)theEvent;
- (void)_dragRowsWithEvent:(NSEvent *)theEvent;
@end

@implementation MBTableGridHeaderView

@synthesize orientation;
@synthesize headerCell;

- (instancetype)initWithFrame:(NSRect)frameRect andTableGrid:(MBTableGrid*)tableGrid
{
	if(self = [super initWithFrame:frameRect]) {
		self.tableGrid = tableGrid;
		self.wantsLayer = YES;
		self.layer.drawsAsynchronously = YES;
		self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
		
		// Setup the header cell
		headerCell = [[MBTableGridHeaderCell alloc] init];
		
		// We haven't clicked any item
		mouseDownItem = -1;
		
		// Initially, we're not dragging anything
		shouldDragItems = NO;
		isInDrag = NO;
        
        // No resize at start
        canResize = NO;
        isResizing = NO;
	}
	return self;
}

- (void)placeSortButtons
{
	NSMutableArray *capturingButtons = [NSMutableArray arrayWithCapacity:0];

	NSButton *sortButton;

	for (NSNumber *cellNumber in self.indicatorImageColumns)
	{
		sortButton = [[NSButton alloc] init];
		sortButton.image = self.indicatorImage;
		sortButton.alternateImage = self.indicatorReverseImage;
		sortButton.bordered = NO;
		sortButton.state = NSOnState;
		sortButton.tag = cellNumber.integerValue;
		sortButton.target = self.tableGrid;
		sortButton.action = @selector(sortButtonClicked:);
		sortButton.wantsLayer = YES;

		[self addSubview:sortButton];
		
		[sortButton setNextState];
		
		[capturingButtons addObject:sortButton];
	}

	self.tableGrid.sortButtons = [[NSArray alloc] initWithArray:capturingButtons];
}

- (void)toggleSortButtonIcon:(NSButton*)btn
{
	btn.image = (btn.image == self.indicatorImage) ? self.indicatorReverseImage : self.indicatorImage;
}

- (void)layoutSortButtonWithRect:(NSRect)rect forColumn:(NSInteger)column
{
	// Set the frames of the sort buttons here
	NSRect indicatorRect = NSZeroRect;
	NSSize sortImageSize = self.indicatorImage.size;
	indicatorRect.size = sortImageSize;
	indicatorRect.origin.x = NSMaxX(rect) - (sortImageSize.width + kSortIndicatorXInset);
	indicatorRect.origin.y = NSMinY(rect) + roundf((NSHeight(rect) - sortImageSize.height) / 2.0);

	MBTableGrid *tableGrid = self.tableGrid;
	
	for (NSButton *button in tableGrid.sortButtons)
	{
		if (button.tag == column)
		{
			button.frame = indicatorRect;
		}
	}
}

- (void)viewWillDraw
{
	[super viewWillDraw];
	
	for (NSNumber *columnNumber in self.indicatorImageColumns)
	{
		NSInteger column = [columnNumber integerValue];
		NSRect headerRect = [self headerRectOfColumn:column];

		[self layoutSortButtonWithRect:headerRect forColumn:column];
	}
}

- (void)drawRect:(NSRect)rect
{
	if (self.orientation == MBTableHeaderHorizontalOrientation) {
 
        // Remove all tracking areas
		for (NSTrackingArea *trackingArea in self.trackingAreas) {
			[self removeTrackingArea:trackingArea];
		}

		// Draw the column headers
		NSUInteger numberOfColumns = self.tableGrid.numberOfColumns;
		[headerCell setOrientation:self.orientation];
		NSUInteger column = 0;
		while (column < numberOfColumns) {
			NSRect headerRect = [self headerRectOfColumn:column];
			
			// Only draw the header if we need to
			if ([self needsToDrawRect:headerRect]) {
				// Check if any part of the selection is in this column
				NSIndexSet *selectedColumns = [self.tableGrid selectedColumnIndexes];
				headerCell.state = [selectedColumns containsIndex:column] ? NSOnState : NSOffState;
				
				if ([self.indicatorImageColumns containsObject:[NSNumber numberWithInteger:column]]) {
					[headerCell setSortIndicatorImage:self.indicatorImage];
				} else {
					[headerCell setSortIndicatorImage:nil];
				}
				
				headerCell.stringValue = [self.tableGrid _headerStringForColumn:column];
				[headerCell drawWithFrame:headerRect inView:self];
                
			}
			
			// Create new tracking area for resizing columns
			NSRect resizeRect = NSMakeRect(NSMinX(headerRect) + NSWidth(headerRect) - 2,
										   NSMinY(headerRect),
										   5, // width
										   NSHeight(headerRect));
			NSTrackingArea *resizeTrackingArea = [[NSTrackingArea alloc] initWithRect:resizeRect
																			  options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways)
																				owner:self
																			 userInfo:nil];
			
			// keep track of tracking areas and add tracking to view
			[self addTrackingArea:resizeTrackingArea];
			
			column++;
		}
        
	} else if (self.orientation == MBTableHeaderVerticalOrientation) {
		
		// Draw the row headers
		NSUInteger numberOfRows = self.tableGrid.numberOfRows;
		[headerCell setOrientation:self.orientation];

		CGFloat rowHeight = self.tableGrid.contentView.rowHeight;
		NSUInteger row = MAX(0, floor(rect.origin.y / rowHeight));
		NSUInteger endRow = MIN(numberOfRows, ceil((rect.origin.y + rect.size.height) / rowHeight));

		while(row < endRow) {
			NSRect headerRect = [self headerRectOfRow:row];
			
			// Only draw the header if we need to
			if ([self needsToDrawRect:headerRect]) {
				// Check if any part of the selection is in this column
				NSIndexSet *selectedRows = [self.tableGrid selectedRowIndexes];
				headerCell.state = [selectedRows containsIndex:row] ? NSOnState : NSOffState;
				
				headerCell.stringValue = [self.tableGrid _headerStringForRow:row];
				[headerCell drawWithFrame:headerRect inView:self];
			}
			row++;
		}
	}
	
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)_mouseDown:(NSEvent *)theEvent right:(BOOL)rightMouse
{
	// Get the location of the click
	NSPoint loc = [self convertPoint:theEvent.locationInWindow fromView:nil];
	mouseDownLocation = loc;
	NSInteger column = [self.tableGrid columnAtPoint:[self convertPoint:loc toView:self.tableGrid]];
	NSInteger row = [self.tableGrid rowAtPoint:loc];

	if([theEvent clickCount] == 2 && !rightMouse) {
		[self.tableGrid.delegate tableGrid:self.tableGrid didDoubleClickColumn:column];
	}
	else {
		if (canResize) {
			// Set resize column index
			draggingColumnIndex = [self.tableGrid columnAtPoint:[self convertPoint:NSMakePoint(loc.x - 3, loc.y) toView:self.tableGrid]];
			lastMouseDraggingLocation = loc;
			isResizing = YES;
			
		} else {
		
			// For single clicks,
			if (theEvent.clickCount == 1) {
				if ((theEvent.modifierFlags & NSShiftKeyMask) && self.tableGrid.allowsMultipleSelection) {
					// If the shift key was held down, extend the selection
				} else {
					// No modifier keys, so change the selection
					if(self.orientation == MBTableHeaderHorizontalOrientation) {
						mouseDownItem = column;
						
						if([self.tableGrid.selectedColumnIndexes containsIndex:column] && self.tableGrid.selectedRowIndexes.count == self.tableGrid.numberOfRows) {
							// Allow the user to drag the column
							shouldDragItems = YES;
						} else {
							self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:column];
							// Select every row
							self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,self.tableGrid.numberOfRows)];
						}
					} else if(self.orientation == MBTableHeaderVerticalOrientation) {
						mouseDownItem = row;
						
						if([self.tableGrid.selectedRowIndexes containsIndex:row] && self.tableGrid.selectedColumnIndexes.count == self.tableGrid.numberOfColumns) {
							// Allow the user to drag the row
							shouldDragItems = YES;
						} else {
							self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndex:row];
							// Select every column
							self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,self.tableGrid.numberOfColumns)];
						}
					}
				}
			} else if ([theEvent clickCount] == 2) {
				
			}
			
			// Pass the event back to the MBTableGrid (Used to give First Responder status)
			[self.tableGrid mouseDown:theEvent];
			
		}
	}
}

- (void) mouseDown:(NSEvent *)theEvent {
	[self _mouseDown:theEvent right:FALSE];
}

- (void) rightMouseDown:(NSEvent *)theEvent {
	[self _mouseDown:theEvent right:TRUE];
}

- (void) rightMouseUp:(NSEvent *)theEvent {
	[NSMenu popUpContextMenu:self.menu withEvent:theEvent forView:self];
}

- (void)mouseDragged:(NSEvent *)theEvent
{	
	// Get the location of the mouse
	NSPoint loc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	CGFloat deltaX = fabs(loc.x - mouseDownLocation.x);
	CGFloat deltaY = fabs(loc.y - mouseDownLocation.y);
	    
    if (canResize) {
        
        [[NSCursor resizeLeftRightCursor] set];
        [[self window] disableCursorRects];
        
        // Set drag distance
        CGFloat dragDistance = loc.x - lastMouseDraggingLocation.x;
        
        lastMouseDraggingLocation = loc;
        
        // Resize column and resize views
		
        CGFloat offset = [self.tableGrid resizeColumnWithIndex:draggingColumnIndex withDistance:dragDistance location:loc];
        lastMouseDraggingLocation.x += offset;
        
        if (offset != 0.0) {
            [[NSCursor resizeRightCursor] set];
        } else {
            [[NSCursor resizeLeftRightCursor] set];
        }
               
    } else {
    
        // Drag operation doesn't start until the mouse has moved more than 5 points
        CGFloat dragThreshold = 5.0;
        
        // If we've met the conditions for a drag operation,
        if (shouldDragItems && mouseDownItem >= 0 && (deltaX >= dragThreshold || deltaY >= dragThreshold)) {
            if (self.orientation == MBTableHeaderHorizontalOrientation) {
                [self.tableGrid _dragColumnsWithEvent:theEvent];
            } else if (self.orientation == MBTableHeaderVerticalOrientation) {
                [self.tableGrid _dragRowsWithEvent:theEvent];
            }
            
            // We've responded to the drag, so don't respond again during this drag session
            shouldDragItems = NO;
            
            // Flag that we are currently dragging items
            isInDrag = YES;
        }
        // Otherwise, extend the selection (if possible)
        else if (mouseDownItem >= 0 && !isInDrag && !shouldDragItems) {
            // Determine which item is under the mouse
            NSInteger itemUnderMouse = -1;
            if (self.orientation == MBTableHeaderHorizontalOrientation) {
                itemUnderMouse = [self.tableGrid columnAtPoint:[self convertPoint:loc toView:self.tableGrid]];
            } else if(self.orientation == MBTableHeaderVerticalOrientation) {
				itemUnderMouse = [self.tableGrid rowAtPoint:loc];
            }
            
            // If there's nothing under the mouse, bail out (something went wrong)
            if (itemUnderMouse < 0)
                return;
            
            // Calculate the range of items to select
            NSInteger firstItemToSelect = mouseDownItem;
            NSInteger numberOfItemsToSelect = itemUnderMouse - mouseDownItem + 1;
            if(itemUnderMouse < mouseDownItem) {
                firstItemToSelect = itemUnderMouse;
                numberOfItemsToSelect = mouseDownItem - itemUnderMouse + 1;
            }
            
            // Set the selected items
            if (self.orientation == MBTableHeaderHorizontalOrientation) {
                self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstItemToSelect, numberOfItemsToSelect)];
            } else if (self.orientation == MBTableHeaderVerticalOrientation) {
                self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstItemToSelect, numberOfItemsToSelect)];
            }
        }
        
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (canResize) {
		
		// if we have an autosaveName, store a dictionary of column widths.
		
		if (self.autosaveName) {
			[self autoSaveColumnProperties];
		}
		
        isResizing = NO;
		
        [self.window enableCursorRects];
        [self.window resetCursorRects];
        
		// update cache of column rects
		
		[self.tableGrid.columnRects removeAllObjects];
		
    } else {
        
        // If we only clicked on a header that was part of a bigger selection, select it
        if(shouldDragItems && !isInDrag) {
            if (self.orientation == MBTableHeaderHorizontalOrientation) {
                self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:mouseDownItem];
                // Select every row
                self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,self.tableGrid.numberOfRows)];
            } else if (self.orientation == MBTableHeaderVerticalOrientation) {
                self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndex:mouseDownItem];
                // Select every column
                self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,self.tableGrid.numberOfColumns)];
            }
        }
        // Reset the pressed item
        mouseDownItem = -1;
        
        // In case it didn't already happen, reset the drag flags
        shouldDragItems = NO;
        isInDrag = NO;
        
        // Reset the location
        mouseDownLocation = NSZeroPoint;
        
    }
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    // Change to resize cursor
    [[NSCursor resizeLeftRightCursor] set];
    canResize = YES;
    
}

- (void)mouseExited:(NSEvent *)theEvent
{
	if (!isResizing) {
        
        // Revert to normal cursor
        [[NSCursor arrowCursor] set];
        canResize = NO;
    }
}

- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    NSRect modifiedRect = proposedVisibleRect;
    
    if (self.orientation == MBTableHeaderHorizontalOrientation) {
        modifiedRect.origin.y = 0.0;
    }
    
    return modifiedRect;
}

- (void)autoSaveColumnProperties {
	if (!columnAutoSaveProperties) {
		columnAutoSaveProperties = [NSMutableDictionary dictionary];
	}
	
	[self.tableGrid.columnRects enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		NSValue *rectValue = obj;
		NSRect rect = [rectValue rectValue];
		NSDictionary *columnDict = @{kAutosavedColumnWidthKey : @(rect.size.width),
									 kAutosavedColumnHiddenKey : @NO};
		columnAutoSaveProperties[[NSString stringWithFormat:@"C-%@", key]] = columnDict;
	}];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:columnAutoSaveProperties forKey:self.autosaveName];
}

#pragma mark Layout Support

- (NSRect)headerRectOfColumn:(NSUInteger)columnIndex
{
	NSRect rect = [self.tableGrid.contentView rectOfColumn:columnIndex];
	rect.size.height = MBTableGridColumnHeaderHeight;
	
	return rect;
}

- (NSRect)headerRectOfRow:(NSUInteger)rowIndex
{
	NSRect rect = [self.tableGrid.contentView rectOfRow:rowIndex];
	rect.size.width = MBTableGridRowHeaderWidth;
	
	return rect;
}

@end
