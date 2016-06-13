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

#import "MBTableGridFooterView.h"
#import "MBTableGrid.h"
#import "MBTableGridContentView.h"
#import "MBFooterTextCell.h"
#import "MBLevelIndicatorCell.h"

@interface MBTableGrid ()
- (MBTableGridContentView *)_contentView;
- (NSCell *)_footerCellForColumn:(NSUInteger)columnIndex;
- (id)_footerValueForColumn:(NSUInteger)columnIndex;
- (void)_setFooterValue:(id)value forColumn:(NSUInteger)columnIndex;
@end

@implementation MBTableGridFooterView

- (instancetype)initWithFrame:(NSRect)frameRect andTableGrid:(MBTableGrid *)tableGrid
{
    if(self = [super initWithFrame:frameRect]) {
		self.tableGrid = tableGrid;
        _defaultCell = [[MBFooterTextCell alloc] initTextCell:@""];
        [_defaultCell setBordered:NO];
		self.wantsLayer = YES;
		self.layer.drawsAsynchronously = YES;
		self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
	
	// Draw the column footers
	NSUInteger numberOfColumns = self.tableGrid.numberOfColumns;
	NSUInteger column = 0;
    NSColor *backgroundColor = [NSColor colorWithCalibratedWhite:0.91 alpha:1.0];
    
	while (column < numberOfColumns) {
		NSRect cellFrame = [self footerRectOfColumn:column];
		
		// Only draw the header if we need to
		if ([self needsToDrawRect:cellFrame]) {
            NSCell *_cell = [self.tableGrid _footerCellForColumn:column];
            
            if (!_cell) {
                _cell = _defaultCell;
            }
            
            id objectValue = [self.tableGrid _footerValueForColumn:column];
            
            if ([_cell isKindOfClass:[MBFooterPopupButtonCell class]]) {
                MBFooterPopupButtonCell *cell = (MBFooterPopupButtonCell *)_cell;
                NSInteger index = [cell indexOfItemWithTitle:objectValue];
                [_cell setObjectValue:@(index)];
            } else {
                [_cell setObjectValue:objectValue];
            }
            
            if ([_cell isKindOfClass:[MBFooterPopupButtonCell class]]) {
                
                MBFooterPopupButtonCell *cell = (MBFooterPopupButtonCell *)_cell;
                [cell drawWithFrame:cellFrame inView:self withBackgroundColor:backgroundColor];// Draw background color
                
            } else if ([_cell isKindOfClass:[MBLevelIndicatorCell class]]) {
                
                MBLevelIndicatorCell *cell = (MBLevelIndicatorCell *)_cell;
                
                cell.target = self;
                cell.action = @selector(updateLevelIndicator:);
                
                [cell drawWithFrame:cellFrame inView:self.tableGrid withBackgroundColor:backgroundColor];// Draw background color
                
            } else {
                
                MBTableGridCell *cell = (MBTableGridCell *)_cell;
                
                [cell drawWithFrame:cellFrame inView:self withBackgroundColor:backgroundColor];// Draw background color
                
            }
		}
		
		column++;
	}
	
}

- (void)updateLevelIndicator:(NSNumber *)value {
    NSInteger selectedColumn = [self.tableGrid.selectedColumnIndexes firstIndex];
    // sanity check to make sure we have an NSNumber.
    // I've observed that when the user lets go of the mouse,
    // the value parameter becomes the MBTableGridContentView
    // object for some reason.
    if ([value isKindOfClass:[NSNumber class]]) {
        [self.tableGrid _setFooterValue:value forColumn:selectedColumn];
        NSRect cellFrame = [self footerRectOfColumn:selectedColumn];
        [self.tableGrid setNeedsDisplayInRect:cellFrame];
    }
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint mouseLocationInContentView = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger mouseDownColumn = [self footerColumnAtPoint:mouseLocationInContentView];
    
    if (theEvent.clickCount == 1) {
        // Pass the event back to the MBTableGrid (Used to give First Responder status)
        [self.tableGrid mouseDown:theEvent];
        
        editedColumn = mouseDownColumn;
        
        NSCell *cell = [self.tableGrid _footerCellForColumn:mouseDownColumn];
        id currentValue = [self.tableGrid _footerValueForColumn:editedColumn];
        
        if ([cell isKindOfClass:[MBFooterPopupButtonCell class]]) {
            editedPopupCell = [cell copy];
            NSRect cellFrame = [self footerRectOfColumn:editedColumn];
            
            editedPopupCell.menu.font = cell.menu.font;
            editedPopupCell.editable = YES;
            editedPopupCell.selectable = YES;
            
            NSMenu *menu = editedPopupCell.menu;
            
            for (NSMenuItem *item in menu.itemArray) {
                item.action = @selector(cellPopupMenuItemSelected:);
                item.target = self;
                
                if ([item.title isEqualToString:currentValue])
                {
                    [editedPopupCell selectItem:item];
                }
            }
            
            [editedPopupCell.menu popUpMenuPositioningItem:editedPopupCell.selectedItem atLocation:cellFrame.origin inView:self];
            
        }
		else {
			[self.tableGrid.delegate tableGrid:self.tableGrid footerCellClicked:cell forColumn:mouseDownColumn withEvent:theEvent];
		}
    }
    
    [self setNeedsDisplay:YES];
}

- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    NSRect modifiedRect = proposedVisibleRect;
    
    modifiedRect.origin.y = 0.0;
    
    return modifiedRect;
}

- (void)cellPopupMenuItemSelected:(NSMenuItem *)menuItem {
//    MBFooterPopupButtonCell *cell = (MBFooterPopupButtonCell *)[self.tableGrid _footerCellForColumn:editedColumn];
    [editedPopupCell selectItemWithTitle:menuItem.title];
    [editedPopupCell synchronizeTitleAndSelectedItem];
    
    [self.tableGrid _setFooterValue:menuItem.title forColumn:editedColumn];
    
    NSRect cellFrame = [self footerRectOfColumn:editedColumn];
    [self.tableGrid setNeedsDisplayInRect:cellFrame];
    
    editedColumn = NSNotFound;
    editedPopupCell = nil;
}

#pragma mark Layout Support

- (NSRect)footerRectOfColumn:(NSUInteger)columnIndex
{
	NSRect rect = [self.tableGrid.contentView rectOfColumn:columnIndex];
	rect.size.height = MBTableGridColumnHeaderHeight;
	
	return rect;
}

- (NSInteger)footerColumnAtPoint:(NSPoint)aPoint
{
    return [self.tableGrid.contentView columnAtPoint:aPoint];
}

@end
