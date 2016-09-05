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

#import "MBTableGrid.h"
#import "MBTableGridHeaderView.h"
#import "MBTableGridFooterView.h"
#import "MBTableGridHeaderCell.h"
#import "MBTableGridContentView.h"
#import "MBTableGridCell.h"
#import "MBImageCell.h"
#import "MBButtonCell.h"
#import "MBPopupButtonCell.h"

#pragma mark -
#pragma mark Constant Definitions
NSString *MBTableGridDidChangeSelectionNotification     = @"MBTableGridDidChangeSelectionNotification";
NSString *MBTableGridDidMoveColumnsNotification         = @"MBTableGridDidMoveColumnsNotification";
NSString *MBTableGridDidMoveRowsNotification            = @"MBTableGridDidMoveRowsNotification";
CGFloat MBTableHeaderMinimumColumnWidth = 60.0f;

#pragma mark -
#pragma mark Drag Types
NSString *MBTableGridColumnDataType = @"mbtablegrid.pasteboard.column";
NSString *MBTableGridRowDataType = @"mbtablegrid.pasteboard.row";

@interface MBTableGrid (Drawing)
@end

@interface MBTableGrid (DataAccessors)
- (NSString *)_headerStringForColumn:(NSUInteger)columnIndex;
- (NSString *)_headerStringForRow:(NSUInteger)rowIndex;
- (id)_objectValueForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (NSFormatter *)_formatterForColumn:(NSUInteger)columnIndex;
//- (NSCell *)_cellForColumn:(NSUInteger)columnIndex;
- (NSImage *)_accessoryButtonImageForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_accessoryButtonClicked:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (NSArray *)_availableObjectValuesForColumn:(NSUInteger)columnIndex;
- (NSArray *)_autocompleteValuesForEditString:(NSString *)editString column:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setObjectValue:(id)value forColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (float)_widthForColumn:(NSUInteger)columnIndex;
- (void)_setWidth:(float) width forColumn:(NSUInteger)columnIndex;
- (id)_backgroundColorForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (BOOL)_canEditCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_userDidEnterInvalidStringInColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex errorDescription:(NSString *)errorDescription;
- (NSCell *)_footerCellForColumn:(NSUInteger)columnIndex;
- (id)_footerValueForColumn:(NSUInteger)columnIndex;
- (void)_setFooterValue:(id)value forColumn:(NSUInteger)columnIndex;
@end

@interface MBTableGrid (DragAndDrop)
- (void)_dragColumnsWithEvent:(NSEvent *)theEvent;
- (void)_dragRowsWithEvent:(NSEvent *)theEvent;
- (NSImage *)_imageForSelectedColumns;
- (NSImage *)_imageForSelectedRows;
- (NSUInteger)_dropColumnForPoint:(NSPoint)aPoint;
- (NSUInteger)_dropRowForPoint:(NSPoint)aPoint;
@end

@interface MBTableGrid (PrivateAccessors)
- (void)_setStickyColumn:(MBTableGridEdge)stickyColumn row:(MBTableGridEdge)stickyRow;
- (MBTableGridEdge)_stickyColumn;
- (MBTableGridEdge)_stickyRow;
@end

@interface MBTableGridContentView (Private)
- (void)_setDraggingColumnOrRow:(BOOL)flag;
- (void)_setDropColumn:(NSInteger)columnIndex;
- (void)_setDropRow:(NSInteger)rowIndex;
@end

@interface MBTableGrid ()
@property (nonatomic, strong) DMTableGridCellQueue *cellQueue;
//@property (nonatomic, strong) MBTableGridHeaderView *columnHeaderView;
@end

@implementation MBTableGrid

@synthesize allowsMultipleSelection;
@synthesize dataSource;
@synthesize delegate;
@synthesize selectedColumnIndexes;
@synthesize selectedRowIndexes;
@synthesize sortButtons;
@synthesize showsGrabHandles;
@synthesize columnFooterView;
@synthesize singleClickCellEdit;

#pragma mark -
#pragma mark Initialization & Superclass Overrides

- (id)initWithFrame:(NSRect)frameRect {
	if (self = [super initWithFrame:frameRect]) {
		columnIndexNames = [NSMutableArray array];
		_columnWidths = [NSMutableDictionary dictionary];
		self.cellQueue = [[DMTableGridCellQueue alloc] init];
		
		// Post frame changed notifications
		// --------------------------------
		[self setPostsFrameChangedNotifications:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self
												selector:@selector(viewFrameDidChange:)
													name:NSViewFrameDidChangeNotification
												   object:self];

		// Set the default cell
		// --------------------
		MBTableGridCell *defaultCell = [[MBTableGridCell alloc] initTextCell:@""];
		defaultCell.bordered = YES;
		defaultCell.scrollable = YES;
		defaultCell.lineBreakMode = NSLineBreakByTruncatingTail;
		self.cell = defaultCell;

		// Setup the column headers
		// ------------------------
		NSRect columnHeaderFrame = NSMakeRect(MBTableGridRowHeaderWidth, 0,
											  frameRect.size.width - MBTableGridRowHeaderWidth,
											  MBTableGridColumnHeaderHeight);

		columnHeaderScrollView = [[NSScrollView alloc] initWithFrame:columnHeaderFrame];
		columnHeaderScrollView.wantsLayer = YES;
		columnFooterScrollView.contentView.wantsLayer = YES; // [dm]
		columnHeaderScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
		columnHeaderScrollView.verticalScrollElasticity = NSScrollElasticityNone;
		_columnHeaderView = [[MBTableGridHeaderView alloc] initWithFrame:NSMakeRect(0, 0,
																				   columnHeaderFrame.size.width,
																				   columnHeaderFrame.size.height)
														   andTableGrid:self];
		self.columnHeaderView.wantsLayer = YES;
		//	[self.columnHeaderView setAutoresizingMask:NSViewWidthSizable];
		self.columnHeaderView.orientation = MBTableHeaderHorizontalOrientation;
		columnHeaderScrollView.documentView = self.columnHeaderView;
		columnHeaderScrollView.autoresizingMask = NSViewWidthSizable;
		columnHeaderScrollView.drawsBackground = NO;
		[self addSubview:columnHeaderScrollView];

		// Setup the row headers
		// ---------------------
		NSRect rowHeaderFrame = NSMakeRect(0, MBTableGridColumnHeaderHeight, MBTableGridRowHeaderWidth, self.frame.size.height - MBTableGridColumnHeaderHeight * 2);
		rowHeaderScrollView = [[NSScrollView alloc] initWithFrame:rowHeaderFrame];
		rowHeaderScrollView.contentView.wantsLayer = YES; // [dm]
		rowHeaderScrollView.wantsLayer = YES;
		rowHeaderScrollView.horizontalScrollElasticity = NO;
		rowHeaderScrollView.verticalScrollElasticity = NO;
		rowHeaderView = [[MBTableGridHeaderView alloc] initWithFrame:NSMakeRect(0, 0, rowHeaderFrame.size.width, rowHeaderFrame.size.height)
														andTableGrid:self];
		rowHeaderView.wantsLayer = YES;
		//[rowHeaderView setAutoresizingMask:NSViewHeightSizable];
		rowHeaderView.orientation = MBTableHeaderVerticalOrientation;
		rowHeaderScrollView.documentView = rowHeaderView;
		rowHeaderScrollView.autoresizingMask = NSViewHeightSizable;
		rowHeaderScrollView.drawsBackground = NO;
		[self addSubview:rowHeaderScrollView];
		
		// Setup the footer view
		// ---------------------
		NSRect columnFooterFrame = NSMakeRect(MBTableGridRowHeaderWidth,
											  frameRect.size.height - MBTableGridColumnHeaderHeight,
											  frameRect.size.width - MBTableGridRowHeaderWidth,
											  MBTableGridColumnHeaderHeight);
		
		columnFooterScrollView = [[NSScrollView alloc] initWithFrame:columnFooterFrame];
		columnFooterScrollView.wantsLayer = YES;
		columnFooterScrollView.contentView.wantsLayer = YES; // [dm]
		columnFooterScrollView.horizontalScrollElasticity = NO;
		columnFooterScrollView.verticalScrollElasticity = NO;
		columnFooterView = [[MBTableGridFooterView alloc] initWithFrame:NSMakeRect(0, 0,
																				   columnFooterFrame.size.width,
																				   columnFooterFrame.size.height)
														   andTableGrid:self];
		columnFooterView.wantsLayer = YES;
//		[columnFooterView setAutoresizingMask:NSViewWidthSizable];
		columnFooterScrollView.documentView = columnFooterView;
		columnFooterScrollView.autoresizingMask = (NSViewWidthSizable | NSViewMinYMargin);
		columnFooterScrollView.drawsBackground = NO;
		[self addSubview:columnFooterScrollView];

		// Setup the content view
		// ----------------------
		NSRect contentFrame = NSMakeRect(MBTableGridRowHeaderWidth, MBTableGridColumnHeaderHeight,
										 self.frame.size.width - MBTableGridRowHeaderWidth,
										 self.frame.size.height - MBTableGridColumnHeaderHeight - MBTableGridColumnHeaderHeight);
		contentScrollView = [[NSScrollView alloc] initWithFrame:contentFrame];
		contentScrollView.wantsLayer = YES;
		contentScrollView.contentView.wantsLayer = YES; // [dm]
		self.contentView = [[MBTableGridContentView alloc] initWithFrame:NSMakeRect(0, 0, contentFrame.size.width, contentFrame.size.height)
													   andTableGrid:self];
		self.contentView.wantsLayer = YES;
		self.contentView.autoresizesSubviews = NO; // [dm]

		//contentScrollView.autoresizesSubviews = YES; // [dm]
		contentScrollView.documentView = self.contentView;
		contentScrollView.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable);
		contentScrollView.hasHorizontalScroller = YES;
		contentScrollView.hasVerticalScroller = YES;
		contentScrollView.autohidesScrollers = YES;
		contentScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
		contentScrollView.verticalScrollElasticity = NSScrollElasticityNone;

		[self addSubview:contentScrollView];

		// We want to synchronize the scroll views
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(columnHeaderViewDidScroll:)
													 name:NSViewBoundsDidChangeNotification
												   object:columnHeaderScrollView.contentView];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(rowHeaderViewDidScroll:)
													 name:NSViewBoundsDidChangeNotification
												   object:rowHeaderScrollView.contentView];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(columnFooterViewDidScroll:)
													 name:NSViewBoundsDidChangeNotification
												   object:columnFooterScrollView.contentView];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(contentViewDidScroll:)
													 name:NSViewBoundsDidChangeNotification
												   object:contentScrollView.contentView];
        
		// Set the default selection
		//self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:0];
		//self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:0];
		self.allowsMultipleSelection = YES;

		// Set the default sticky edges
		stickyColumnEdge = MBTableGridLeftEdge;
		stickyRowEdge = MBTableGridTopEdge;

		shouldOverrideModifiers = NO;
		singleClickCellEdit = NO;
		
		self.numberOfColumns = 0;
		self.numberOfRows = 0;
		
		self.columnRects = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void) setShowsGrabHandles:(BOOL)s {
	showsGrabHandles = s;
	[self.contentView setShowsGrabHandle:s];
}

- (void)sortButtonClicked:(id)sender
{
	[self.columnHeaderView toggleSortButtonIcon:(NSButton*)sender];
}

- (void)awakeFromNib {
//	[self reloadData];
	[self unregisterDraggedTypes];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)isFlipped {
	return YES;
}

- (BOOL)canBecomeKeyView {
	return YES;
}

- (BOOL)acceptsFirstResponder {
	return YES;
}

/**
 * @brief		Sets the indicator image for the specified column.
 *				This is used for indicating which direction the
 *				column is being sorted by.
 *
 * @param		anImage			The sort indicator image.
 * @param		reverseImage	The reversed sort indicator image.
 *
 * @return		The header value for the row.
 */
- (void)setIndicatorImage:(NSImage *)anImage reverseImage:(NSImage*)reverseImg inColumns:(NSArray*)columns
{
	MBTableGridHeaderView *headerView = self.columnHeaderView;
	headerView.indicatorImageColumns = columns;
	headerView.indicatorImage = anImage;
	headerView.indicatorReverseImage = reverseImg;


	[headerView placeSortButtons];
}

/**
 * @brief		Returns the sort indicator image
 *				for the specified column.
 *
 * @param		columnIndex		The index of the column.
 *
 * @return		The sort indicator image for the column.
 */
- (NSImage *)indicatorImageInColumn:(NSUInteger)columnIndex {
	NSImage *indicatorImage = nil;

	return indicatorImage;
}

- (void)setAutosaveName:(NSString *)autosaveName {
	_autosaveName = autosaveName;
	self.columnHeaderView.autosaveName = autosaveName;
}

// view optimization, only called in 10.10+
- (BOOL)isOpaque
{
	return NO;
}

- (void)drawRect2:(NSRect)aRect {
	[[NSColor windowBackgroundColor] set];
	NSRectFill(aRect);
}

#pragma mark Resize scrollview content size

- (void) resizeColumnWithIndex:(NSUInteger)columnIndex width:(float)w {
	// Set new width of column
	float currentWidth = w;
	
	[self.columnRects removeAllObjects];
	if (currentWidth < MBTableHeaderMinimumColumnWidth) {
		currentWidth = MBTableHeaderMinimumColumnWidth;
	}
	[self _setWidth:currentWidth forColumn:columnIndex];
	
	// Update views with new sizes
	//[contentView setFrameSize:NSMakeSize(currentWidth, NSHeight(contentView.frame))];
	//[self.columnHeaderView setFrameSize:NSMakeSize(currentWidth, NSHeight(self.columnHeaderView.frame))];
	self.contentView.needsDisplay = YES;
	self.columnHeaderView.needsDisplay = YES;
	self.needsDisplay = YES;
	[self.columnHeaderView setNeedsDisplayInRect:self.columnHeaderView.frame];
	columnFooterView.needsDisplay = YES;
}

- (void)setNeedsDisplay:(BOOL)needsDisplay {
    super.needsDisplay = needsDisplay;
    
	self.contentView.needsDisplay = needsDisplay;
    self.columnHeaderView.needsDisplay = needsDisplay;
    rowHeaderView.needsDisplay = needsDisplay;
    columnFooterView.needsDisplay = needsDisplay;
}

#pragma mark Resize scrollview content size

- (CGFloat)resizeColumnWithIndex:(NSUInteger)columnIndex withDistance:(float)distance location:(NSPoint)location
{
	// Note that we only need this rect for its origin, which won't be changing, otherwise we'd need to flush the column rect cache first
	NSRect columnRect = [self rectOfColumn:columnIndex];

	// Flush rect cache for this column because we're changing its size
	// Note that we're doing this after calling rectOfColumn: because that would cache the rect before we change its width...
	[self.columnRects removeAllObjects];

	// Set new width of column
	CGFloat currentWidth = [self _widthForColumn:columnIndex];
    CGFloat offset = 0.0;
	
    currentWidth += distance;
    
    CGFloat minColumnWidth = MBTableHeaderMinimumColumnWidth;
    
    if (self.columnHeaderView.indicatorImage && [self.columnHeaderView.indicatorImageColumns containsObject:@(columnIndex)]) {
        minColumnWidth += self.columnHeaderView.indicatorImage.size.width + 2.0f;
    }
    
    if (currentWidth < minColumnWidth) {
        currentWidth = minColumnWidth;
    }
	
	[self _setWidth:currentWidth forColumn:columnIndex];
    
    if (currentWidth == minColumnWidth) {
        offset = columnRect.origin.x - location.x + minColumnWidth - self.rowHeaderView.frame.size.width;
        distance = 0.0;
    }
    
    // Update table cell views with new sizes
	[_contentView resetDocumentView];
	
    [self.columnHeaderView setFrameSize:NSMakeSize(NSWidth(self.columnHeaderView.frame) + distance, NSHeight(self.columnHeaderView.frame))];
    [columnFooterView setFrameSize:NSMakeSize(NSWidth(columnFooterView.frame) + distance, NSHeight(columnFooterView.frame))];
    
    NSRect rectOfResizedAndVisibleRightwardColumns = NSMakeRect(columnRect.origin.x - rowHeaderView.bounds.size.width, 0,
																_contentView.bounds.size.width - columnRect.origin.x,
																NSHeight(_contentView.frame));
    [_contentView setNeedsDisplayInRect:rectOfResizedAndVisibleRightwardColumns];
    
    NSRect rectOfResizedAndVisibleRightwardHeaders = NSMakeRect(columnRect.origin.x - rowHeaderView.bounds.size.width, 0,
																_contentView.bounds.size.width - columnRect.origin.x,
																NSHeight(self.columnHeaderView.frame));
    [self.columnHeaderView setNeedsDisplayInRect:rectOfResizedAndVisibleRightwardHeaders];
    
    NSRect rectOfResizedAndVisibleRightwardFooters = NSMakeRect(columnRect.origin.x - rowHeaderView.bounds.size.width, 0,
																_contentView.bounds.size.width - columnRect.origin.x,
																NSHeight(columnFooterView.frame));
    [columnFooterView setNeedsDisplayInRect:rectOfResizedAndVisibleRightwardFooters];
    
    return offset;
}

- (void)registerForDraggedTypes:(NSArray *)pboardTypes {
	// Add the column and row types to the array
	NSMutableArray *types = [NSMutableArray arrayWithArray:pboardTypes];

	if (!pboardTypes) {
		types = [NSMutableArray array];
	}
	[types addObjectsFromArray:@[MBTableGridColumnDataType, MBTableGridRowDataType]];

	[super registerForDraggedTypes:types];

	// Register the content view for everything
	[_contentView registerForDraggedTypes:types];
}

#pragma mark Mouse Events

- (void)mouseDown:(NSEvent *)theEvent {
	// End editing (if necessary)
	[self.cell endEditing:[self.window fieldEditor:NO forObject:_contentView]];

	// If we're not the first responder, we need to be
	if ([[self window] firstResponder] != self) {
		[[self window] makeFirstResponder:self];
	}
}

#pragma mark Keyboard Events

- (void)keyDown:(NSEvent *)theEvent {
	[self interpretKeyEvents:@[theEvent]];
}

/*- (void)interpretKeyEvents:(NSArray *)eventArray
   {

   }*/

#pragma mark NSResponder Event Handlers

- (void)copy:(id)sender {
	
	NSIndexSet *selectedColumns = [self selectedColumnIndexes];
	NSIndexSet *selectedRows = [self selectedRowIndexes];

    if ([self.delegate respondsToSelector:@selector(tableGrid:copyCellsAtColumns:rows:)]) {
		[self.delegate tableGrid:self copyCellsAtColumns:selectedColumns rows:selectedRows];
	}
}

- (void)paste:(id)sender {
	
    NSIndexSet *selectedColumns = [self selectedColumnIndexes];
    NSIndexSet *selectedRows = [self selectedRowIndexes];
    
    if ([self.delegate respondsToSelector:@selector(tableGrid:pasteCellsAtColumns:rows:)]) {
        [self.delegate tableGrid:self pasteCellsAtColumns:selectedColumns rows:selectedRows];
        [self reloadData];
    }
}

- (void)insertTab:(id)sender {
	// Pressing "Tab" moves to the next column
	[self moveRight:sender];

	if(self.singleClickCellEdit) {
		[self.contentView editSelectedCell:nil text:@""];
	}
}

- (void)insertBacktab:(id)sender {
	// We want to change the selection, not expand it
	shouldOverrideModifiers = YES;

	// Pressing Shift+Tab moves to the previous column
	[self moveLeft:sender];

	if (self.singleClickCellEdit) {
		[self.contentView editSelectedCell:nil text:@""];
	}
}

- (void)insertNewline:(id)sender {
	if ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) {
		// Pressing Shift+Return moves to the previous row
		shouldOverrideModifiers = YES;
		[self moveUp:sender];
	}
	else {
		// Pressing Return moves to the next row
		[self moveDown:sender];
	}

	if (self.singleClickCellEdit) {
		[self.contentView editSelectedCell:nil text:@""];
	}
}

- (void)moveUp:(id)sender {
	NSUInteger column = [self.selectedColumnIndexes firstIndex];
	NSUInteger row = [self.selectedRowIndexes firstIndex];

	// Accomodate for the sticky edges
	if (stickyColumnEdge == MBTableGridRightEdge) {
		column = [self.selectedColumnIndexes lastIndex];
	}
	if (stickyRowEdge == MBTableGridBottomEdge) {
		row = [self.selectedRowIndexes lastIndex];
	}

	// If we're already at the first row, do nothing
	if (row <= 0)
		return;

	// If the Shift key was not held, move the selection
	self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:column];
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:(row - 1)];

	if (row > 0) {
		NSRect cellRect = [self frameOfCellAtColumn:column row:row - 1];
		cellRect = [self convertRect:cellRect toView:self.contentView];
		if (!NSContainsRect(self.contentView.visibleRect, cellRect)) {
			cellRect.origin.x = self.contentView.visibleRect.origin.x;
			[self scrollToArea:cellRect animate:NO];
		}
		else {
			[self setNeedsDisplay:YES];
		}
	}

	if(self.singleClickCellEdit) {
		[self.contentView editSelectedCell:nil text:@""];
	}
}

- (void)moveUpAndModifySelection:(id)sender {
	if (shouldOverrideModifiers) {
		[self moveLeft:sender];
		shouldOverrideModifiers = NO;
		return;
	}

	NSUInteger firstRow = [self.selectedRowIndexes firstIndex];
	NSUInteger lastRow = [self.selectedRowIndexes lastIndex];

	// If there is only one row selected, change the sticky edge to the bottom
	if ([self.selectedRowIndexes count] == 1) {
		stickyRowEdge = MBTableGridBottomEdge;
	}

	// We can't expand past the last row
	if (stickyRowEdge == MBTableGridBottomEdge && firstRow <= 0)
		return;

	if (stickyRowEdge == MBTableGridTopEdge) {
		// If the top edge is sticky, contract the selection
		lastRow--;
	}
	else if (stickyRowEdge == MBTableGridBottomEdge) {
		// If the bottom edge is sticky, expand the contraction
		firstRow--;
	}
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRow, lastRow - firstRow + 1)];

	NSUInteger column = [self.selectedColumnIndexes firstIndex];

	if (firstRow - 1 > 0) {
		NSRect cellRect = [self frameOfCellAtColumn:column row:firstRow - 1];
		cellRect = [self convertRect:cellRect toView:contentScrollView.contentView];
		if (!NSContainsRect(self.contentView.visibleRect, cellRect)) {
			cellRect.origin.x = self.contentView.visibleRect.origin.x;
			[self scrollToArea:cellRect animate:NO];
		}
		else {
			[self setNeedsDisplay:YES];
		}
	}
}

- (void)moveDown:(id)sender {
	NSUInteger column = [self.selectedColumnIndexes firstIndex];
	NSUInteger row = [self.selectedRowIndexes firstIndex];

	// Accomodate for the sticky edges
	if (stickyColumnEdge == MBTableGridRightEdge) {
		column = [self.selectedColumnIndexes lastIndex];
	}
	if (stickyRowEdge == MBTableGridBottomEdge) {
		row = [self.selectedRowIndexes lastIndex];
	}

	// If we're already at the last row, do nothing
	if (row >= (_numberOfRows - 1))
		return;

	// If the Shift key was not held, move the selection
	self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:column];
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:(row + 1)];

}

- (void)moveDownAndModifySelection:(id)sender {
	if (shouldOverrideModifiers) {
		[self moveDown:sender];
		shouldOverrideModifiers = NO;
		return;
	}

	NSUInteger firstRow = [self.selectedRowIndexes firstIndex];
	NSUInteger lastRow = [self.selectedRowIndexes lastIndex];

	// If there is only one row selected, change the sticky edge to the top
	if ([self.selectedRowIndexes count] == 1) {
		stickyRowEdge = MBTableGridTopEdge;
	}

	// We can't expand past the last row
	if (stickyRowEdge == MBTableGridTopEdge && lastRow >= (_numberOfRows - 1))
		return;

	if (stickyRowEdge == MBTableGridTopEdge) {
		// If the top edge is sticky, contract the selection
		lastRow++;
	}
	else if (stickyRowEdge == MBTableGridBottomEdge) {
		// If the bottom edge is sticky, expand the contraction
		firstRow++;
	}
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRow, lastRow - firstRow + 1)];

	NSUInteger column = [self.selectedColumnIndexes lastIndex];

	if (lastRow + 1 < self.numberOfRows) {
		NSRect cellRect = [self frameOfCellAtColumn:column row:lastRow + 1];
		cellRect = [self convertRect:cellRect toView:contentScrollView.contentView];
		if (!NSContainsRect(self.contentView.visibleRect, cellRect)) {
			cellRect.origin.y = cellRect.origin.y - self.contentView.visibleRect.size.height + cellRect.size.height;
			cellRect.origin.x = self.contentView.visibleRect.origin.x;
			[self scrollToArea:cellRect animate:NO];
		}
		else {
            [self setNeedsDisplay:YES];
		}
	}
}

- (void)moveLeft:(id)sender {
	NSUInteger column = [self.selectedColumnIndexes firstIndex];
	NSUInteger row = [self.selectedRowIndexes firstIndex];

	// Accomodate for the sticky edges
	if (stickyColumnEdge == MBTableGridRightEdge) {
		column = [self.selectedColumnIndexes lastIndex];
	}
	if (stickyRowEdge == MBTableGridBottomEdge) {
		row = [self.selectedRowIndexes lastIndex];
	}

	if(column == 0) {
		if(row > 0) {
			column = _numberOfColumns;
			row = row - 1;
		}
		else {
			return;
		}
	}

	if (column > 0) {
		NSRect cellRect = [self frameOfCellAtColumn:column - 1 row:row];
		cellRect = [self convertRect:cellRect toView:contentScrollView.contentView];
		if (!NSContainsRect(self.contentView.visibleRect, cellRect)) {
			cellRect.origin.y = self.contentView.visibleRect.origin.y;
			[self scrollToArea:cellRect animate:NO];
		}
		else {
            [self setNeedsDisplay:YES];
		}
	}

	// If the Shift key was not held, move the selection
	self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:(column - 1)];
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:row];
}

- (void)moveLeftAndModifySelection:(id)sender {
	if (shouldOverrideModifiers) {
		[self moveLeft:sender];
		shouldOverrideModifiers = NO;
		return;
	}

	NSUInteger firstColumn = [self.selectedColumnIndexes firstIndex];
	NSUInteger lastColumn = [self.selectedColumnIndexes lastIndex];

	// If there is only one column selected, change the sticky edge to the right
	if ([self.selectedColumnIndexes count] == 1) {
		stickyColumnEdge = MBTableGridRightEdge;
	}

	NSUInteger row = [self.selectedRowIndexes firstIndex];

	if (firstColumn > 0) {
		NSRect cellRect = [self frameOfCellAtColumn:firstColumn - 1 row:row];
		cellRect = [self convertRect:cellRect toView:contentScrollView.contentView];
		if (!NSContainsRect(self.contentView.visibleRect, cellRect)) {
			cellRect.origin.y = self.contentView.visibleRect.origin.y;
			[self scrollToArea:cellRect animate:NO];
		}
		else {
            [self setNeedsDisplay:YES];
		}
	}


	// We can't expand past the first column
	if (stickyColumnEdge == MBTableGridRightEdge && firstColumn <= 0)
		return;

	if (stickyColumnEdge == MBTableGridLeftEdge) {
		// If the top edge is sticky, contract the selection
		lastColumn--;
	}
	else if (stickyColumnEdge == MBTableGridRightEdge) {
		// If the bottom edge is sticky, expand the contraction
		firstColumn--;
	}
	self.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstColumn, lastColumn - firstColumn + 1)];
}

- (void)moveRight:(id)sender {
	NSUInteger column = [self.selectedColumnIndexes firstIndex];
	NSUInteger row = [self.selectedRowIndexes firstIndex];

	// Accomodate for the sticky edges
	if (stickyColumnEdge == MBTableGridRightEdge) {
		column = [self.selectedColumnIndexes lastIndex];
	}
	if (stickyRowEdge == MBTableGridBottomEdge) {
		row = [self.selectedRowIndexes lastIndex];
	}

	// If we're already at the last column, move down and to the leftmost column
	if (column >= (_numberOfColumns - 1)) {
		if(row < (_numberOfRows - 1)) {
			self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:0];
			self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:row+1];
		}
	}
	else {
		self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:(column + 1)];
		self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:row];
	}

	if (column + 1 < [self numberOfColumns]) {
		NSRect cellRect = [self frameOfCellAtColumn:column + 1 row:row];
		cellRect = [self convertRect:cellRect toView:contentScrollView.contentView];
		if (!NSContainsRect(self.contentView.visibleRect, cellRect)) {
			cellRect.origin.x = cellRect.origin.x - self.contentView.visibleRect.size.width + cellRect.size.width;
			cellRect.origin.y = self.contentView.visibleRect.origin.y;
			[self scrollToArea:cellRect animate:NO];
		}
		else {
            [self setNeedsDisplay:YES];
		}
	}
}

- (void)moveRightAndModifySelection:(id)sender {
	if (shouldOverrideModifiers) {
		[self moveRight:sender];
		shouldOverrideModifiers = NO;
		return;
	}

	NSUInteger firstColumn = [self.selectedColumnIndexes firstIndex];
	NSUInteger lastColumn = [self.selectedColumnIndexes lastIndex];

	// If there is only one column selected, change the sticky edge to the right
	if ([self.selectedColumnIndexes count] == 1) {
		stickyColumnEdge = MBTableGridLeftEdge;
	}

	// We can't expand past the last column
	if (stickyColumnEdge == MBTableGridLeftEdge && lastColumn >= (_numberOfColumns - 1))
		return;

	if (stickyColumnEdge == MBTableGridLeftEdge) {
		// If the top edge is sticky, contract the selection
		lastColumn++;
	}
	else if (stickyColumnEdge == MBTableGridRightEdge) {
		// If the bottom edge is sticky, expand the contraction
		firstColumn++;
	}
	self.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstColumn, lastColumn - firstColumn + 1)];

	NSUInteger row = [self.selectedRowIndexes lastIndex];

	if (lastColumn + 1 < [self numberOfColumns]) {
		NSRect cellRect = [self frameOfCellAtColumn:lastColumn + 1 row:row];
		cellRect = [self convertRect:cellRect toView:contentScrollView.contentView];
		if (!NSContainsRect(self.contentView.visibleRect, cellRect)) {
			cellRect.origin.x = cellRect.origin.x - self.contentView.visibleRect.size.width + cellRect.size.width;
			cellRect.origin.y = self.contentView.visibleRect.origin.y;
			[self scrollToArea:cellRect animate:NO];
		}
		else {
            [self setNeedsDisplay:YES];
		}
	}
}

- (void)scrollToArea:(NSRect)area animate:(BOOL)shouldAnimate {
	if (shouldAnimate) {
		[NSAnimationContext runAnimationGroup: ^(NSAnimationContext *context) {
		    [context setAllowsImplicitAnimation:YES];
		    [self.contentView scrollRectToVisible:area];
		} completionHandler: ^{
		}];
	}
	else {
//		[contentScrollView.contentView scrollRectToVisible:area];
		[contentScrollView.contentView scrollToPoint:area.origin];
        [self setNeedsDisplay:YES];
//		NSLog(@"area: %@", NSStringFromRect(area));
	}
}

- (void)selectAll:(id)sender {
	stickyColumnEdge = MBTableGridLeftEdge;
	stickyRowEdge = MBTableGridTopEdge;

	self.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _numberOfColumns)];
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _numberOfRows)];
}

- (void)deleteBackward:(id)sender {
	// Clear the contents of every selected cell
	NSUInteger column = [self.selectedColumnIndexes firstIndex];
	while (column <= [self.selectedColumnIndexes lastIndex]) {
		NSUInteger row = [self.selectedRowIndexes firstIndex];
		while (row <= [self.selectedRowIndexes lastIndex]) {
			[self _setObjectValue:nil forColumn:column row:row];
			row++;
		}
		column++;
	}
	[self reloadData];
}

/*
- (void)insertText:(id)aString {
	NSUInteger column = [self.selectedColumnIndexes firstIndex];
	NSCell *selectedCell = [self _cellForColumn:column];
	
	if (![selectedCell isKindOfClass:[MBImageCell class]]) {
		[_contentView editSelectedCell:self text:aString];
		
		if ([selectedCell isKindOfClass:[MBTableGridCell class]]) {
			// Insert the typed string into the field editor
			NSText *fieldEditor = [self.window fieldEditor:YES forObject:_contentView];
			fieldEditor.delegate = _contentView;
			[fieldEditor setString:aString];
            
            // The textDidBeginEditing notification isn't sent yet, so invoke a custom method
            [_contentView textDidBeginEditingWithEditor:fieldEditor];
		}
		
	} else {
		NSUInteger row = [self.selectedRowIndexes firstIndex];
		[self _accessoryButtonClicked:column row:row];
	}
	[self setNeedsDisplay:YES];

}
*/

#pragma mark -
#pragma mark Notifications

- (void)viewFrameDidChange:(NSNotification *)aNotification {
	//[self reloadData];
}

- (void)syncronizeScrollView:(NSScrollView *)scrollView withChangedBoundsOrigin:(NSPoint)changedBoundsOrigin horizontal:(BOOL)horizontal {

	// Get the current origin
    NSPoint curOffset = scrollView.contentView.bounds.origin;
    NSPoint newOffset = curOffset;
    
    if (horizontal) {
        newOffset.x = changedBoundsOrigin.x;
    } else {
        newOffset.y = changedBoundsOrigin.y;
    }
    
    // If the synced position is different from our current position, reposition the view
    if (!NSEqualPoints(curOffset, changedBoundsOrigin)) {
        [scrollView.contentView scrollToPoint:newOffset];
        // We have to tell the NSScrollView to update its scrollers
        [scrollView reflectScrolledClipView:scrollView.contentView];
    }

	[_contentView setNeedsDisplayInRect:_contentView.visibleRect];
}

- (void)columnHeaderViewDidScroll:(NSNotification *)aNotification {
    
	NSView *changedView = aNotification.object;
	NSPoint changedBoundsOrigin = changedView.bounds.origin;

    [self syncronizeScrollView:contentScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:YES];
    [self syncronizeScrollView:rowHeaderScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:NO];
    [self syncronizeScrollView:columnFooterScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:YES];
    
}

- (void)rowHeaderViewDidScroll:(NSNotification *)aNotification {
    
    NSView *changedView = aNotification.object;
    NSPoint changedBoundsOrigin = changedView.bounds.origin;
    
    [self syncronizeScrollView:contentScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:NO];
    
}

- (void)columnFooterViewDidScroll:(NSNotification *)aNotification {
    
    NSView *changedView = aNotification.object;
    NSPoint changedBoundsOrigin = changedView.bounds.origin;
    
    [self syncronizeScrollView:contentScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:YES];
    [self syncronizeScrollView:columnHeaderScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:YES];
    [self syncronizeScrollView:rowHeaderScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:NO];
    
}

- (void)contentViewDidScroll:(NSNotification *)aNotification {
    
    NSView *changedView = aNotification.object;
    NSPoint changedBoundsOrigin = changedView.bounds.origin;
    
    [self syncronizeScrollView:columnHeaderScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:YES];
    [self syncronizeScrollView:rowHeaderScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:NO];
    [self syncronizeScrollView:columnFooterScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:YES];
    
}

#pragma mark -
#pragma mark Protocol Methods

#pragma mark NSDraggingSource

-(NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    
    switch(context) {
        case NSDraggingContextOutsideApplication:
            return NSDragOperationNone;
            break;
            
        case NSDraggingContextWithinApplication:
        default:
            return NSDragOperationMove;
            break;
    }
}

#pragma mark NSDraggingDestination

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo> )sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSData *columnData = [pboard dataForType:MBTableGridColumnDataType];
	NSData *rowData = [pboard dataForType:MBTableGridRowDataType];

	// Do not accept drag if this doesn't come from us
	if ([sender draggingSource] != self) {
		return NO;
	}

	if (columnData) {
		return NSDragOperationMove;
	}
	else if (rowData) {
		return NSDragOperationMove;
	}
	else {
		if ([self.dataSource respondsToSelector:@selector(tableGrid:validateDrop:proposedColumn:row:)]) {
			NSPoint mouseLocation = [self convertPoint:[sender draggingLocation] fromView:nil];
			NSUInteger dropColumn = [self columnAtPoint:mouseLocation];
			NSUInteger dropRow = [self rowAtPoint:mouseLocation];

			NSDragOperation dragOperation = [self.dataSource tableGrid:self validateDrop:sender proposedColumn:dropColumn row:dropRow];

			// If the drag is okay, highlight the appropriate cell
			if (dragOperation != NSDragOperationNone) {
				[_contentView _setDropColumn:dropColumn];
				[_contentView _setDropRow:dropRow];
			}

			return dragOperation;
		}
	}

	return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo> )sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSData *columnData = [pboard dataForType:MBTableGridColumnDataType];
	NSData *rowData = [pboard dataForType:MBTableGridRowDataType];
	NSPoint mouseLocation = [self convertPoint:[sender draggingLocation] fromView:nil];

	if (columnData) {
		// If we're dragging a column

		NSUInteger dropColumn = [self _dropColumnForPoint:mouseLocation];

		if (dropColumn == NSNotFound) {
			return NSDragOperationNone;
		}

		NSIndexSet *draggedColumns = (NSIndexSet *)[NSKeyedUnarchiver unarchiveObjectWithData:columnData];

		BOOL canDrop = NO;
		if ([self.dataSource respondsToSelector:@selector(tableGrid:canMoveColumns:toIndex:)]) {
			canDrop = [self.dataSource tableGrid:self canMoveColumns:draggedColumns toIndex:dropColumn];
		}

		[_contentView _setDraggingColumnOrRow:YES];

		if (canDrop) {
			[_contentView _setDropColumn:dropColumn];
			return NSDragOperationMove;
		}
		else {
			[_contentView _setDropColumn:NSNotFound];
		}
	}
	else if (rowData) {
		// If we're dragging a row

		NSUInteger dropRow = [self _dropRowForPoint:mouseLocation];

		if (dropRow == NSNotFound) {
			return NSDragOperationNone;
		}

		NSIndexSet *draggedRows = (NSIndexSet *)[NSKeyedUnarchiver unarchiveObjectWithData:rowData];

		BOOL canDrop = NO;
		if ([self.dataSource respondsToSelector:@selector(tableGrid:canMoveRows:toIndex:)]) {
			canDrop = [self.dataSource tableGrid:self canMoveRows:draggedRows toIndex:dropRow];
		}

		[_contentView _setDraggingColumnOrRow:YES];

		if (canDrop) {
			[_contentView _setDropRow:dropRow];
			return NSDragOperationMove;
		}
		else {
			[_contentView _setDropRow:NSNotFound];
		}
	}
	else {
		if ([self.dataSource respondsToSelector:@selector(tableGrid:validateDrop:proposedColumn:row:)]) {
			NSUInteger dropColumn = [self columnAtPoint:mouseLocation];
			NSUInteger dropRow = [self rowAtPoint:mouseLocation];

			[_contentView _setDraggingColumnOrRow:NO];

			NSDragOperation dragOperation = [self.dataSource tableGrid:self validateDrop:sender proposedColumn:dropColumn row:dropRow];

			// If the drag is okay, highlight the appropriate cell
			if (dragOperation != NSDragOperationNone) {
				[_contentView _setDropColumn:dropColumn];
				[_contentView _setDropRow:dropRow];
			}

			return dragOperation;
		}
	}
	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo> )sender {
	[_contentView _setDropColumn:NSNotFound];
	[_contentView _setDropRow:NSNotFound];
}

- (void)draggingEnded:(id <NSDraggingInfo> )sender {
	[_contentView _setDropColumn:NSNotFound];
	[_contentView _setDropRow:NSNotFound];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo> )sender {
	// Do not accept drag if this doesn't come from us
	if([sender draggingSource] != self) {
		return NO;
	}
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo> )sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSData *columnData = [pboard dataForType:MBTableGridColumnDataType];
	NSData *rowData = [pboard dataForType:MBTableGridRowDataType];
	NSPoint mouseLocation = [self convertPoint:[sender draggingLocation] fromView:nil];

	// Do not accept drag if this doesn't come from us
	if([sender draggingSource] != self) {
		return NO;
	}

	if (columnData) {
		// If we're dragging a column
		if ([self.dataSource respondsToSelector:@selector(tableGrid:moveColumns:toIndex:)]) {
			// Get which columns are being dragged
			NSIndexSet *draggedColumns = (NSIndexSet *)[NSKeyedUnarchiver unarchiveObjectWithData:columnData];

			// Get the index to move the columns to
			NSUInteger dropColumn = [self _dropColumnForPoint:mouseLocation];

			// Tell the data source to move the columns
			BOOL didDrag = [self.dataSource tableGrid:self moveColumns:draggedColumns toIndex:dropColumn];

			if (didDrag) {
				NSUInteger startIndex = dropColumn;
				NSUInteger length = [draggedColumns count];

				if (dropColumn > [draggedColumns firstIndex]) {
					startIndex -= [draggedColumns count];
				}

				NSIndexSet *newColumns = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(startIndex, length)];

				// Post the notification
				[[NSNotificationCenter defaultCenter] postNotificationName:MBTableGridDidMoveColumnsNotification object:self userInfo:@{ @"OldColumns": draggedColumns, @"NewColumns": newColumns }];

				// Change the selection to reflect the newly-dragged columns
				self.selectedColumnIndexes = newColumns;
			}

			return didDrag;
		}
	}
	else if (rowData) {
		// If we're dragging a row
		if ([self.dataSource respondsToSelector:@selector(tableGrid:moveRows:toIndex:)]) {
			// Get which rows are being dragged
			NSIndexSet *draggedRows = (NSIndexSet *)[NSKeyedUnarchiver unarchiveObjectWithData:rowData];

			// Get the index to move the rows to
			NSUInteger dropRow = [self _dropRowForPoint:mouseLocation];

			// Tell the data source to move the rows
			BOOL didDrag = [self.dataSource tableGrid:self moveRows:draggedRows toIndex:dropRow];

			if (didDrag) {
				NSUInteger startIndex = dropRow;
				NSUInteger length = [draggedRows count];

				if (dropRow > [draggedRows firstIndex]) {
					startIndex -= [draggedRows count];
				}

				NSIndexSet *newRows = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(startIndex, length)];

				// Post the notification
				[[NSNotificationCenter defaultCenter] postNotificationName:MBTableGridDidMoveRowsNotification object:self userInfo:@{ @"OldRows": draggedRows, @"NewRows": newRows }];

				// Change the selection to reflect the newly-dragged rows
				self.selectedRowIndexes = newRows;
			}

			return didDrag;
		}
	}
	else {
		if ([self.dataSource respondsToSelector:@selector(tableGrid:acceptDrop:column:row:)]) {
			NSUInteger dropColumn = [self columnAtPoint:mouseLocation];
			NSUInteger dropRow = [self rowAtPoint:mouseLocation];

			// Pass the drag to the data source
			BOOL didPerformDrag = [self.dataSource tableGrid:self acceptDrop:sender column:dropColumn row:dropRow];

			return didPerformDrag;
		}
	}

	return NO;
}

- (void)concludeDragOperation:(id <NSDraggingInfo> )sender {
	[_contentView _setDropColumn:NSNotFound];
	[_contentView _setDropRow:NSNotFound];
}

#pragma mark -
#pragma mark Subclass Methods

#pragma mark Dimensions


#pragma mark Reloading the Grid

- (void)populateColumnInfo {
    if (columnIndexNames.count < _numberOfColumns) {
        for (NSUInteger columnIndex = columnIndexNames.count; columnIndex < _numberOfColumns; columnIndex++) {
            NSString *column = [NSString stringWithFormat:@"column%lu", columnIndex];
            columnIndexNames[columnIndex] = column;
        }
    }
}

- (void)reloadData
{
	CGRect visibleRect = contentScrollView.contentView.documentVisibleRect;
	
	// Set number of columns
	if ([self.dataSource respondsToSelector:@selector(numberOfColumnsInTableGrid:)]) {
		self.numberOfColumns =  [self.dataSource numberOfColumnsInTableGrid:self];
	}
	else {
		self.numberOfColumns = 0;
	}

	// Set number of rows
	if ([self.dataSource respondsToSelector:@selector(numberOfRowsInTableGrid:)]) {
		self.numberOfRows =  [self.dataSource numberOfRowsInTableGrid:self];
	}
	else {
		self.numberOfRows = 0;
	}
    
    [self populateColumnInfo];

	[self.columnRects removeAllObjects];
	[self.contentView resetDocumentView];
	
	// Update the content view's size
    NSUInteger lastColumn = (_numberOfColumns > 0) ? _numberOfColumns-1 : 0;
    NSUInteger lastRow = (_numberOfRows > 0) ? _numberOfRows-1 : 0;
	NSRect bottomRightCellFrame = [_contentView frameOfCellAtColumn:lastColumn row:lastRow];

	NSRect contentRect = NSMakeRect(_contentView.frame.origin.x, _contentView.frame.origin.y,
									NSMaxX(bottomRightCellFrame), NSMaxY(bottomRightCellFrame));
	[_contentView setFrameSize:contentRect.size];

	// Update the column header view's size
	NSRect columnHeaderFrame = self.columnHeaderView.frame;
	columnHeaderFrame.size.width = contentRect.size.width;
	if(![[contentScrollView verticalScroller] isHidden]) {
		columnHeaderFrame.size.width += [NSScroller scrollerWidthForControlSize:NSRegularControlSize scrollerStyle:NSScrollerStyleLegacy];	}
	[self.columnHeaderView setFrameSize:columnHeaderFrame.size];

	// Update the row header view's size
	NSRect rowHeaderFrame = [rowHeaderView frame];
	rowHeaderFrame.size.height = contentRect.size.height;
	if(![[contentScrollView horizontalScroller] isHidden]) {
		columnHeaderFrame.size.height += [NSScroller scrollerWidthForControlSize:NSRegularControlSize scrollerStyle:NSScrollerStyleLegacy];
	}
	[rowHeaderView setFrameSize:rowHeaderFrame.size];

	NSRect columnFooterFrame = [columnFooterView frame];
	columnFooterFrame.size.width = contentRect.size.width;
	if (![[contentScrollView verticalScroller] isHidden]) {
		columnFooterFrame.size.width += [NSScroller scrollerWidthForControlSize:NSRegularControlSize
																  scrollerStyle:NSScrollerStyleOverlay];
	}
	[columnFooterView setFrameSize:columnHeaderFrame.size];

	if(_numberOfRows > 0) {
		if((visibleRect.size.height + visibleRect.origin.y) > contentRect.size.height) {
			visibleRect.size.height = MIN(contentRect.size.height, visibleRect.size.height);
			visibleRect.origin.y = MAX(0, contentRect.size.height - visibleRect.size.height);
		}
	}

	// Restore original visible rectangle of scroller
	[self scrollToArea:visibleRect animate:NO];
	
	[self.contentView reloadTable];
	
	[self setNeedsDisplay:YES];
	[self.contentView setNeedsDisplay:YES];
	[self.columnHeaderView setNeedsDisplay:YES];
	[self.rowHeaderView setNeedsDisplay:YES];
}

#pragma mark Layout Support

- (NSRect)rectOfColumn:(NSUInteger)columnIndex {
	NSRect rect = [self convertRect:[_contentView rectOfColumn:columnIndex] fromView:_contentView];
	rect.origin.y = 0;
	rect.size.height += MBTableGridColumnHeaderHeight;
	if (rect.size.height > [self frame].size.height) {
		rect.size.height = [self frame].size.height;

		// If the scrollbar is visible, don't include it in the rect
		if(![[contentScrollView horizontalScroller] isHidden]) {
			rect.size.height -= [NSScroller scrollerWidthForControlSize:NSRegularControlSize scrollerStyle:NSScrollerStyleLegacy];
		}
	}

	return rect;
}

- (NSRect)rectOfRow:(NSUInteger)rowIndex {
	NSRect rect = [self convertRect:[_contentView rectOfRow:rowIndex] fromView:_contentView];
	rect.origin.x = 0;
	rect.size.width += MBTableGridRowHeaderWidth;

	return rect;
}

- (NSRect)frameOfCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	return [self convertRect:[_contentView frameOfCellAtColumn:columnIndex row:rowIndex] fromView:_contentView];
}

- (NSRect)headerRectOfColumn:(NSUInteger)columnIndex {
	return [self convertRect:[self.columnHeaderView headerRectOfColumn:columnIndex] fromView:self.columnHeaderView];
}

- (NSRect)headerRectOfRow:(NSUInteger)rowIndex {
	return [self convertRect:[rowHeaderView headerRectOfColumn:rowIndex] fromView:rowHeaderView];
}

- (NSRect)headerRectOfCorner {
	NSRect rect = NSMakeRect(0, 0, MBTableGridRowHeaderWidth, MBTableGridColumnHeaderHeight);
	return rect;
}

- (NSRect)footerRectOfCorner {
	NSRect rect = NSMakeRect(0, [self frame].size.height - MBTableGridColumnHeaderHeight, MBTableGridRowHeaderWidth, MBTableGridColumnHeaderHeight);
	return rect;
}

- (NSInteger)columnAtPoint:(NSPoint)aPoint
{
	// account for row header
	aPoint.x -= self.rowHeaderView.frame.size.width;
	
	NSUInteger column = 0;
	while (column < _numberOfColumns) {
		NSRect columnFrame = [self rectOfColumn:column];
		if (floor(aPoint.x) <= columnFrame.origin.x + columnFrame.size.width) // TODO account for grid lines?
			return column;
		else
			column++;
	}
	
	// check that the point is only a few pixels from the right edge
	// - this can happen when resizing the last column
	//if (aPoint.x > self.contentView.frame.size.width - 1 && aPoint.x < self.contentView.frame.size.width + 5)
	//	return _numberOfColumns - 1;
	
	NSAssert(FALSE, @"column not found");
	return NSNotFound;
	
	// This fails when the point value lies between pixels.
	/*
	NSInteger column = 0;
	while (column < _numberOfColumns) {
		NSRect columnFrame = [self rectOfColumn:column];
		if (NSPointInRect(aPoint, columnFrame)) {
			return column;
		}
		column++;
	}

	 NSAssert(FALSE, @"column not found");
	return NSNotFound;
	 */
}

- (NSInteger)rowAtPoint:(NSPoint)aPoint {
	CGFloat y = aPoint.y - self.contentView.rowHeight;
	NSInteger row = ceil(y / self.contentView.rowHeight);
	if(row >= 0 && row <= _numberOfRows) {
		return row;
	}

	return NSNotFound;
}

#pragma mark Auxiliary Views

- (MBTableGridHeaderView *)rowHeaderView {
	return rowHeaderView;
}

- (MBTableGridContentView *)contentView {
	return _contentView;
}

#pragma mark - Overridden Property Accessors

- (void)setSelectedColumnIndexes:(NSIndexSet *)anIndexSet {
	[self setSelectedColumnIndexes:anIndexSet notify:YES];
}

- (void)setSelectedColumnIndexes:(NSIndexSet *)anIndexSet notify:(BOOL)notify {
	if (anIndexSet == selectedColumnIndexes)
		return;

	// Allow the delegate to validate the selection
	if ([self.delegate respondsToSelector:@selector(tableGrid:willSelectColumnsAtIndexPath:)]) {
		anIndexSet = [self.delegate tableGrid:self willSelectColumnsAtIndexPath:anIndexSet];
	}

	selectedColumnIndexes = anIndexSet;

	[self setNeedsDisplay:YES];
	[self.contentView setNeedsDisplay:YES];
	[self.columnHeaderView setNeedsDisplay:YES];
	[self.rowHeaderView setNeedsDisplay:YES];

	// Post the notification
	if(notify) {
		[[NSNotificationCenter defaultCenter] postNotificationName:MBTableGridDidChangeSelectionNotification object:self];
	}
}

- (void)setSelectedRowIndexes:(NSIndexSet *)anIndexSet {
	[self setSelectedRowIndexes:anIndexSet notify:YES];
}

- (void)setSelectedRowIndexes:(NSIndexSet *)anIndexSet notify:(BOOL)notify {
	// Allow the delegate to validate the selection
	if ([self.delegate respondsToSelector:@selector(tableGrid:willSelectRowsAtIndexPath:)]) {
		anIndexSet = [self.delegate tableGrid:self willSelectRowsAtIndexPath:anIndexSet];
	}

	selectedRowIndexes = anIndexSet;

	[self setNeedsDisplay:YES];
	[self.contentView setNeedsDisplay:YES];
	[self.columnHeaderView setNeedsDisplay:YES];
	[self.rowHeaderView setNeedsDisplay:YES];
	
	// Post the notification
	if(notify) {
		[[NSNotificationCenter defaultCenter] postNotificationName:MBTableGridDidChangeSelectionNotification object:self];
	}
}

- (void)setDelegate:(id <MBTableGridDelegate> )anObject {
	if (anObject == delegate)
		return;

	if (delegate) {
		// Unregister the delegate for relevant notifications
		[[NSNotificationCenter defaultCenter] removeObserver:delegate name:MBTableGridDidChangeSelectionNotification object:self];
		[[NSNotificationCenter defaultCenter] removeObserver:delegate name:MBTableGridDidMoveColumnsNotification object:self];
		[[NSNotificationCenter defaultCenter] removeObserver:delegate name:MBTableGridDidMoveRowsNotification object:self];
	}

	delegate = anObject;

	// Register the new delegate for relevant notifications
	if ([delegate respondsToSelector:@selector(tableGridDidChangeSelection:)]) {
		[[NSNotificationCenter defaultCenter] addObserver:delegate selector:@selector(tableGridDidChangeSelection:) name:MBTableGridDidChangeSelectionNotification object:self];
	}
	if ([delegate respondsToSelector:@selector(tableGridDidMoveColumns:)]) {
		[[NSNotificationCenter defaultCenter] addObserver:delegate selector:@selector(tableGridDidMoveColumns:) name:MBTableGridDidMoveColumnsNotification object:self];
	}
	if ([delegate respondsToSelector:@selector(tableGridDidMoveRows:)]) {
		[[NSNotificationCenter defaultCenter] addObserver:delegate selector:@selector(tableGridDidMoveRows:) name:MBTableGridDidMoveRowsNotification object:self];
	}
}

#pragma mark -
#pragma mark View-based cell methods
// [dm]

//- (void)registerNib:(NSNib *)nib forIdentifier:(NSString *)identifier andOwner:(id)owner
- (void)registerViewWithIdentifier:(NSString*)identifier fromNib:(NSNib*)nib // andOwnerClass:(Class)ownerClass
{
	// pass through to queue object
	[self.cellQueue registerViewSource:nib forIdentifier:identifier];
//	[self.cellQueue registerNib:nib forIdentifier:identifier]; // andOwnerClass:ownerClass];
}

- (void)registerViewWithIdentifier:(NSString *)identifier fromBlock:(NSView *(^)())block
{
	[self.cellQueue registerViewSource:block forIdentifier:identifier];
}

- (NSView*)makeViewWithIdentifier:(NSString*)identifier // ownerClass:(Class)ownerClass
{
	NSAssert(identifier != nil, @"cell identifier cannot be nil.");
	return [self.cellQueue dequeueViewWithIdentifier:identifier]; // owner:owner];
}

- (NSView*)makeViewWithIdentifier:(NSString*)identifier fromBlock:(NSView* (^)())block
{
	NSView* cell = [self.cellQueue dequeueViewWithIdentifier:identifier]; //owner:nil];
	if (cell == nil) {
		cell = block();
	}
	return cell;
}

- (void)enqueueView:(NSView*)view forIdentifier:(NSString *)identifier
{
	// pass through to queue object
	[self.cellQueue enqueueView:view withIdentifier:identifier];
}

@end


#pragma mark -

@implementation MBTableGrid (Drawing)

- (BOOL) opaque {
	return YES;
}

@end

@implementation MBTableGrid (DataAccessors)

- (NSString *)_headerStringForColumn:(NSUInteger)columnIndex {
	// Ask the data source
	if ([self.dataSource respondsToSelector:@selector(tableGrid:headerStringForColumn:)]) {
		return [self.dataSource tableGrid:self headerStringForColumn:columnIndex];
	}

	char alphabetChar = columnIndex + 'A';
	return [NSString stringWithFormat:@"%c", alphabetChar];
}

- (NSString *)_headerStringForRow:(NSUInteger)rowIndex {
	// Ask the data source
	if ([self.dataSource respondsToSelector:@selector(tableGrid:headerStringForRow:)]) {
		return [self.dataSource tableGrid:self headerStringForRow:rowIndex];
	}

	return [NSString stringWithFormat:@"%lu", (rowIndex + 1)];
}

- (id)_objectValueForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	if ([self.dataSource respondsToSelector:@selector(tableGrid:objectValueForColumn:row:)]) {
		id value = [self.dataSource tableGrid:self objectValueForColumn:columnIndex row:rowIndex];
		return value;
	}
	else {
		NSLog(@"WARNING: MBTableGrid data source does not implement tableGrid:objectValueForColumn:row:");
	}
	return nil;
}

- (NSImage *)_accessoryButtonImageForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	if ([self.dataSource respondsToSelector:@selector(tableGrid:accessoryButtonImageForColumn:row:)]) {
		return [self.dataSource tableGrid:self accessoryButtonImageForColumn:columnIndex row:rowIndex];
	}
	return nil;
}

- (NSFormatter *)_formatterForColumn:(NSUInteger)columnIndex {
    if ([self.dataSource respondsToSelector:@selector(tableGrid:formatterForColumn:)]) {
        return [self.dataSource tableGrid:self formatterForColumn:columnIndex];
    }
    return nil;
}

/*
- (NSCell *)_cellForColumn:(NSUInteger)columnIndex {
	if ([self.dataSource respondsToSelector:@selector(tableGrid:cellForColumn:)]) {
		return [self.dataSource tableGrid:self cellForColumn:columnIndex];
	}
	return nil;
}
*/

- (NSArray *)_availableObjectValuesForColumn:(NSUInteger)columnIndex {
	if ([self.dataSource respondsToSelector:@selector(tableGrid:availableObjectValuesForColumn:)]) {
		return [self.dataSource tableGrid:self availableObjectValuesForColumn:columnIndex];
	}
	return nil;
}

- (NSArray *)_autocompleteValuesForEditString:(NSString *)editString column:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
    if ([self.dataSource respondsToSelector:@selector(tableGrid:autocompleteValuesForEditString:column:row:)]) {
        return [self.dataSource tableGrid:self autocompleteValuesForEditString:editString column:columnIndex row:rowIndex];
    }
    return nil;
}

- (id)_backgroundColorForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	if ([self.dataSource respondsToSelector:@selector(tableGrid:backgroundColorForColumn:row:)]) {
		return [self.dataSource tableGrid:self backgroundColorForColumn:columnIndex row:rowIndex];
	}
	else {
		NSLog(@"WARNING: MBTableGrid data source does not implement tableGrid:backgroundColorForColumn:row:");
	}
	return nil;
}

- (void)_setObjectValue:(id)value forColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	if ([self.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumn:row:)]) {
		[self.dataSource tableGrid:self setObjectValue:value forColumn:columnIndex row:rowIndex];
	}
}

- (float)_widthForColumn:(NSUInteger)columnIndex {
	if (columnIndexNames.count > columnIndex) {
		NSNumber* width = [_columnWidths objectForKey:@(columnIndex)];
		return width == nil ? MBTableHeaderMinimumColumnWidth : width.floatValue;
	}
	
	return 0.0f;
}

- (void) _setWidth:(float)width forColumn:(NSUInteger)columnIndex
{
	[_columnWidths setObject:@(width) forKey:@(columnIndex)];
	
	if ([self.dataSource respondsToSelector:@selector(tableGrid:setWidth:forColumn:)]) {
		[self.dataSource tableGrid:self setWidth:width forColumn:columnIndex];
    }
}

- (BOOL)_canEditCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	// Can't edit if the data source doesn't implement the method
	if (![self.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumn:row:)]) {
		return NO;
	}

	// Ask the delegate if the cell is editable
	if ([self.delegate respondsToSelector:@selector(tableGrid:shouldEditColumn:row:)]) {
		return [self.delegate tableGrid:self shouldEditColumn:columnIndex row:rowIndex];
	}

	return YES;
}

- (void)_userDidEnterInvalidStringInColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex errorDescription:(NSString *)errorDescription {
    if ([self.delegate respondsToSelector:@selector(tableGrid:userDidEnterInvalidStringInColumn:row:errorDescription:)]) {
        [self.delegate tableGrid:self userDidEnterInvalidStringInColumn:columnIndex row:rowIndex errorDescription:errorDescription];
    }
}

- (void)_accessoryButtonClicked:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	if ([self.delegate respondsToSelector:@selector(tableGrid:accessoryButtonClicked:row:)]) {
		[self.delegate tableGrid:self accessoryButtonClicked:columnIndex row:rowIndex];
	}
}

#pragma mark Footer

- (NSCell *)_footerCellForColumn:(NSUInteger)columnIndex {
    if ([self.dataSource respondsToSelector:@selector(tableGrid:footerCellForColumn:)]) {
        return [self.dataSource tableGrid:self footerCellForColumn:columnIndex];
    }
    return nil;
}

- (id)_footerValueForColumn:(NSUInteger)columnIndex {
    if ([self.dataSource respondsToSelector:@selector(tableGrid:footerValueForColumn:)]) {
        id value = [self.dataSource tableGrid:self footerValueForColumn:columnIndex];
        return value;
    }
    return nil;
}

- (void)_setFooterValue:(id)value forColumn:(NSUInteger)columnIndex {
    if ([self.dataSource respondsToSelector:@selector(tableGrid:setFooterValue:forColumn:)]) {
        [self.dataSource tableGrid:self setFooterValue:value forColumn:columnIndex];
    }
}

@end

@implementation MBTableGrid (PrivateAccessors)

- (void)_setStickyColumn:(MBTableGridEdge)stickyColumn row:(MBTableGridEdge)stickyRow {
	stickyColumnEdge = stickyColumn;
	stickyRowEdge = stickyRow;
}

- (MBTableGridEdge)_stickyColumn {
	return stickyColumnEdge;
}

- (MBTableGridEdge)_stickyRow {
	return stickyRowEdge;
}

@end

@implementation MBTableGrid (DragAndDrop)

- (void)_dragColumnsWithEvent:(NSEvent *)theEvent {
	NSImage *dragImage = [self _imageForSelectedColumns];

	NSRect firstSelectedColumn = [self rectOfColumn:[self.selectedColumnIndexes firstIndex]];
	NSPoint location = firstSelectedColumn.origin;
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.selectedColumnIndexes];
    NSPasteboardItem *pbItem = [[NSPasteboardItem alloc] initWithPasteboardPropertyList:data ofType:MBTableGridColumnDataType];
    NSDraggingItem *item = [[NSDraggingItem alloc] initWithPasteboardWriter:pbItem];
    
    NSRect dragImageFrame = NSMakeRect(location.x, location.y, dragImage.size.width, dragImage.size.height);
    [item setDraggingFrame:dragImageFrame contents:dragImage];
    id source = (id <NSDraggingSource>) self;

    [self beginDraggingSessionWithItems:@[item] event:theEvent source:source];
}

- (void)_dragRowsWithEvent:(NSEvent *)theEvent {
	NSImage *dragImage = [self _imageForSelectedRows];
    
	NSRect firstSelectedRow = [self rectOfRow:[self.selectedRowIndexes firstIndex]];
	NSPoint location = firstSelectedRow.origin;
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.selectedRowIndexes];
    NSPasteboardItem *pbItem = [[NSPasteboardItem alloc] initWithPasteboardPropertyList:data ofType:MBTableGridRowDataType];
    NSDraggingItem *item = [[NSDraggingItem alloc] initWithPasteboardWriter:pbItem];
    
    NSRect dragImageFrame = NSMakeRect(location.x, location.y, dragImage.size.width, dragImage.size.height);
    [item setDraggingFrame:dragImageFrame contents:dragImage];
    id source = (id <NSDraggingSource>) self;
    
    [self beginDraggingSessionWithItems:@[item] event:theEvent source:source];
}

- (NSImage *)_imageForSelectedColumns {
	NSRect firstColumnFrame = [self rectOfColumn:self.selectedColumnIndexes.firstIndex];
	NSRect lastColumnFrame = [self rectOfColumn:self.selectedColumnIndexes.lastIndex];
	NSRect columnsFrame = NSMakeRect(NSMinX(firstColumnFrame), NSMinY(firstColumnFrame), NSMaxX(lastColumnFrame) - NSMinX(firstColumnFrame), NSHeight(firstColumnFrame));
	// Extend the frame to show the left border
	columnsFrame.origin.x -= 1.0;
	columnsFrame.size.width += 1.0;

	// Take a snapshot of the view
	NSImage *opaqueImage = [[NSImage alloc] initWithData:[self dataWithPDFInsideRect:columnsFrame]];

	// Create the translucent drag image
	NSImage *finalImage = [[NSImage alloc] initWithSize:[opaqueImage size]];
	[finalImage lockFocus];
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_8
	[opaqueImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
#else
	[opaqueImage drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.7];
#endif
	[finalImage unlockFocus];

	return finalImage;
}

- (NSImage *)_imageForSelectedRows {
	NSRect firstRowFrame = [self rectOfRow:self.selectedRowIndexes.firstIndex];
	NSRect lastRowFrame = [self rectOfRow:self.selectedRowIndexes.lastIndex];
	NSRect rowsFrame = NSMakeRect(NSMinX(firstRowFrame), NSMinY(firstRowFrame), NSWidth(firstRowFrame), NSMaxY(lastRowFrame) - NSMinY(firstRowFrame));
	// Extend the frame to show the top border
	rowsFrame.origin.y -= 1.0;
	rowsFrame.size.height += 1.0;

	// Take a snapshot of the view
	NSImage *opaqueImage = [[NSImage alloc] initWithData:[self dataWithPDFInsideRect:rowsFrame]];

	// Create the translucent drag image
	NSImage *finalImage = [[NSImage alloc] initWithSize:[opaqueImage size]];
	[finalImage lockFocus];
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_8
	[opaqueImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
#else
	[opaqueImage drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.7];
#endif
	[finalImage unlockFocus];

	return finalImage;
}

- (NSUInteger)_dropColumnForPoint:(NSPoint)aPoint {
	NSUInteger column = [self columnAtPoint:aPoint];

	if (column == NSNotFound) {
		return NSNotFound;
	}

	// If we're in the right half of the column, we intent to drop on the right side
	NSRect columnFrame = [self rectOfColumn:column];
	columnFrame.size.width /= 2;
	if (!NSPointInRect(aPoint, columnFrame)) {
		column++;
	}

	return column;
}

- (NSUInteger)_dropRowForPoint:(NSPoint)aPoint {
	NSUInteger row = [self rowAtPoint:aPoint];

	if (row == NSNotFound) {
		return NSNotFound;
	}

	// If we're in the bottom half of the row, we intent to drop on the bottom side
	NSRect rowFrame = [self rectOfRow:row];
	rowFrame.size.height /= 2;

	if (!NSPointInRect(aPoint, rowFrame)) {
		row++;
	}

	return row;
}

@end
