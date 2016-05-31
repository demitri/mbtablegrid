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

#import "MBTableGridContentView.h"

#import "MBTableGrid.h"
#import "MBTableGridCell.h"
#import "MBPopupButtonCell.h"
#import "MBButtonCell.h"
#import "MBImageCell.h"
#import "MBLevelIndicatorCell.h"
#import "MyTableCellView.h"
#import "DMActiveCellsCache.h"

#define kGRAB_HANDLE_HALF_SIDE_LENGTH 3.0f
#define kGRAB_HANDLE_SIDE_LENGTH 6.0f

NSString * const MBTableGridTrackingPartKey = @"part";

@interface MBTableGrid (Private)
- (id)_objectValueForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (NSFormatter *)_formatterForColumn:(NSUInteger)columnIndex;
- (NSCell *)_cellForColumn:(NSUInteger)columnIndex;
- (NSImage *)_accessoryButtonImageForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_accessoryButtonClicked:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (NSArray *)_availableObjectValuesForColumn:(NSUInteger)columnIndex;
- (NSArray *)_autocompleteValuesForEditString:(NSString *)editString column:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setObjectValue:(id)value forColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (BOOL)_canEditCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setStickyColumn:(MBTableGridEdge)stickyColumn row:(MBTableGridEdge)stickyRow;
- (float)_widthForColumn:(NSUInteger)columnIndex;
- (id)_backgroundColorForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (MBTableGridEdge)_stickyColumn;
- (MBTableGridEdge)_stickyRow;
- (void)_userDidEnterInvalidStringInColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex errorDescription:(NSString *)errorDescription;
- (NSCell *)_footerCellForColumn:(NSUInteger)columnIndex;
- (id)_footerValueForColumn:(NSUInteger)columnIndex;
- (void)_setFooterValue:(id)value forColumn:(NSUInteger)columnIndex;
@end

@interface MBTableGridContentView (Cursors)
- (NSCursor *)_cellSelectionCursor;
- (NSImage *)_cellSelectionCursorImage;
- (NSCursor *)_cellExtendSelectionCursor;
- (NSImage *)_cellExtendSelectionCursorImage;
- (NSImage *)_grabHandleImage;
@end

@interface MBTableGridContentView (DragAndDrop)
- (void)_setDraggingColumnOrRow:(BOOL)flag;
- (void)_setDropColumn:(NSInteger)columnIndex;
- (void)_setDropRow:(NSInteger)rowIndex;
- (void)_timerAutoscrollCallback:(NSTimer *)aTimer;
@end

@interface MBTableGridContentView ()
{
	CGFloat scrollPrefetchPosX;
	CGFloat scrollPrefetchPosY;
	CGFloat scrollPrefetchNegX;
	CGFloat scrollPrefetchNegY;
}
@property (nonatomic, strong) DMActiveCellsCache *activeCellsCache;
//@property (nonatomic, strong) NSMutableDictionary *activeTableCells; // key: indexPath value: {"view":view,"id":cellIdentifier}
@property (nonatomic, strong) NSMutableDictionary *activeTableCells; // key: @(colNum) value: NSMutableArray <key:rowNum value:cellView>
@end

@implementation MBTableGridContentView

@synthesize showsGrabHandle;
@synthesize rowHeight = _rowHeight;

#pragma mark -
#pragma mark Initialization & Superclass Overrides

- (instancetype)initWithFrame:(NSRect)frameRect andTableGrid:(MBTableGrid*)tableGrid
{
	if (self = [super initWithFrame:frameRect]) {
		
		_tableGrid = tableGrid;
		
		showsGrabHandle = NO;
		mouseDownColumn = NSNotFound;
		mouseDownRow = NSNotFound;
		
		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		
		dropColumn = NSNotFound;
		dropRow = NSNotFound;
        
		grabHandleImage = [self _grabHandleImage];
        grabHandleRect = NSZeroRect;
		
		// Cache the cursor image
		cursorImage = [self _cellSelectionCursorImage];
        cursorExtendSelectionImage = [self _cellExtendSelectionCursorImage];
		
        isCompleting = NO;
		isDraggingColumnOrRow = NO;
        shouldDrawFillPart = MBTableGridTrackingPartNone;

		self.activeTableCells = [NSMutableDictionary dictionary];
		self.activeCellsCache = [[DMActiveCellsCache alloc] init];
		
		_rowHeight = 20.0f;
		
		self.wantsLayer = true;
		self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
		[self.layer setDrawsAsynchronously:YES];
		_defaultCell = [[MBTableGridCell alloc] initTextCell:@""];
        [_defaultCell setBordered:YES];
		[_defaultCell setScrollable:YES];
		[_defaultCell setLineBreakMode:NSLineBreakByTruncatingTail];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mylistener:) name:@"NSMenuDidChangeItemNotification" object:nil];
		
		// +[dm]
		//self.canDrawSubviewsIntoLayer = YES;
	}
	return self;
}

- (void)viewDidMoveToSuperview
{
	if (self.superview != nil) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(frameChanged:)
													 name:@"NSViewFrameDidChangeNotification"
												   object:self.superview];
	}
}

- (void)frameChanged:(NSNotification*)notification
{
	NSLog(@"new frame: %@ for %@", NSStringFromRect(self.superview.frame), notification.object);
	
	NSRect visibleRect = [self.superview convertRect:self.superview.bounds toView:self]; // convert clip view rect to this view

	float pad = 1.75;
	scrollPrefetchPosX = visibleRect.size.width * pad;
	scrollPrefetchPosY = visibleRect.size.height * pad;
	scrollPrefetchNegX = visibleRect.size.width * pad;
	scrollPrefetchNegY = visibleRect.size.height * pad;
	
	self.needsDisplay = YES;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self removeObserver:self forKeyPath:@"frame"];
}

- (void)mylistener:(id)sender
{
	NSInteger selectedColumn = [self.tableGrid.selectedColumnIndexes firstIndex];
	NSCell *selectedCell = [self.tableGrid _cellForColumn:selectedColumn];

	MBPopupButtonCell *popupCell = (MBPopupButtonCell *)selectedCell;
	
	if ([popupCell isKindOfClass:[MBPopupButtonCell class]])
	{
		[popupCell synchronizeTitleAndSelectedItem];
		//[popupCell setTitle:[[popupCell selectedItem] title]];
		//[popupCell selectItemWithTitle:[[popupCell selectedItem] title]];
	}
}

// view optimization, only called in 10.10+
- (BOOL)isOpaque
{
	return NO;
}

/*
- (BOOL)wantsDefaultClipping
{
	// return YES if we can guarantee we won't draw outside of drawRect
}
*/

- (void)viewWillDraw
{
	[super viewWillDraw];

	NSRect *rectsBeingDrawn;
	NSInteger count;
	[self getRectsBeingDrawn:&rectsBeingDrawn count:&count];
	
	/*
	NSLog(@"viewWillDraw: Rects being drawn:");
	for (int i=0;i<count;i++) {
		NSRect r = rectsBeingDrawn[i];
		NSLog(@"    %@", NSStringFromRect(r));
	}
	 */
}

- (NSUInteger)numberOfActiveCells
{
	NSUInteger count = 0;
	for (NSNumber *col in self.activeTableCells.allKeys) {
		count = count + [(NSMutableDictionary*)self.activeTableCells[col] allKeys].count;
	}
	return count;
}

// ---------------------------------------------------------
- (void)prepareContentInRect:(NSRect)rect
{
	CFTimeInterval startTime = CACurrentMediaTime();

	// rect is the overdraw region - use this hook to add/remove NSView cells
	// passed rect is visible rect + overdraw region
	//
	NSRect originalRect = rect;
	NSRect visibleRect = [self.superview convertRect:self.superview.bounds toView:self]; // convert clip view rect to this view
	//NSLog(@"rect: %@", NSStringFromRect(rect));
	if (rect.origin.x < 0) {
		rect.size.width = rect.size.width - rect.origin.x;
		rect.origin.x = 0;
	}
	if (rect.origin.y < 0) {
		rect.size.height = rect.size.height - rect.origin.y;
		rect.origin.y = 0;
	}
	
	// limit rect to visible region to maximum area we are willing to cover (to limit number of subviews)
	//
	NSRect visiblePlusCachedRect = NSMakeRect(MAX(0, visibleRect.origin.x - scrollPrefetchNegX),
											  MAX(0, visibleRect.origin.y - scrollPrefetchNegY),
											  MIN(self.bounds.size.width, visibleRect.size.width + scrollPrefetchNegX + scrollPrefetchPosX),
											  MIN(self.bounds.size.height, visibleRect.size.height + scrollPrefetchNegY + scrollPrefetchPosY));

	if (NSEqualRects(rect, visiblePlusCachedRect) == NO) {
		rect = NSIntersectionRect(rect, visiblePlusCachedRect); // overlap of requested overdraw region with max area we're willing to cache
		rect = NSUnionRect(rect, visibleRect);					// join that rect with union rect
	}
	
	NSPoint diagonalPointFromOrigin = NSMakePoint(rect.origin.x + rect.size.width,
												  rect.origin.y + rect.size.height);
	
	NSUInteger minCol2;
	
	NSUInteger minCol = MAX([self columnAtPoint:rect.origin], 0);
	if (minCol == NSNotFound) // when rect.origin.x < 0, happens when view bounces in elastic NSScrollView... even though I turned the @($& thing off.
		minCol = 0;
	NSUInteger maxCol = MIN([self columnAtPoint:diagonalPointFromOrigin], _tableGrid.numberOfColumns - 1);
	
	NSUInteger minRow = MAX([self rowAtPoint:rect.origin], 0);
	if (minRow == NSNotFound)
		minRow = 0;
	NSUInteger maxRow = MIN([self rowAtPoint:diagonalPointFromOrigin], _tableGrid.numberOfRows - 1);

	//NSLog(@"A: # of active cells: %d | c[%tu:%tu] r[%tu:%tu]", [self numberOfActiveCells], minCol, maxCol, minRow, maxRow);
	
	// remove cells outside of rect
	//
	for (NSNumber *cacheColNumber in self.activeTableCells.allKeys) {
		
		NSMutableDictionary *rowCache = self.activeTableCells[cacheColNumber]; // key: @(rowNum) value: view
		
		if (cacheColNumber.intValue < minCol || cacheColNumber.intValue > maxCol) {
			//
			// remove all cells in column if outside current vis+cached range
			//
			if (rowCache != nil) {
				int n = rowCache.count;
				for (NSNumber *cacheRowNumber in rowCache.allKeys) {
					NSView *view = rowCache[cacheRowNumber];
					[view removeFromSuperview];
					[_tableGrid enqueueView:view forIdentifier:view.identifier];
					[rowCache removeObjectForKey:cacheRowNumber];
				}
				NSLog(@"emptied column %@ (%d rows)", cacheColNumber, n);
			}
			[self.activeTableCells removeObjectForKey:cacheColNumber];
		}
		else {
			//
			// column is in range of updates; check rows
			//
			if (rowCache != nil) {
				for (NSNumber *cacheRowNumber in rowCache.allKeys) {
					if (cacheRowNumber.intValue < minRow || cacheRowNumber.intValue > maxRow) {
						NSView *view = rowCache[cacheRowNumber];
						[view removeFromSuperview];
						[_tableGrid enqueueView:view forIdentifier:view.identifier];
						[rowCache removeObjectForKey:cacheRowNumber];
					}
				}
			}
		}
	}

	
	// populate all cells in this rect (if not already there)
	//
	for (NSUInteger column = minCol; column < maxCol+1; column++) {
		BOOL newRowCache = NO;
		NSMutableDictionary *rowCache = self.activeTableCells[@(column)];
		if (rowCache == nil) {
			rowCache = [NSMutableDictionary dictionary];
			self.activeTableCells[@(column)] = rowCache;
			newRowCache = YES;
		}

		for (NSUInteger row = minRow; row < maxRow+1; row++) {
			
			NSView *tableCellView = rowCache[@(row)];
			if (tableCellView == nil) {
				tableCellView = [_tableGrid.delegate tableGrid:_tableGrid viewForTableColumn:column andRow:row];
				[self addSubview:tableCellView];
				rowCache[@(row)] = tableCellView;
			}
			tableCellView.frame = [self frameOfCellAtColumn:column row:row];
		}
		if (newRowCache)
			NSAssert(rowCache.count > 0, @"empty row cache created");
	}
	
	//NSLog(@"B: # of active cells: %d", self.activeTableCells.count);

	// Must return a rect, CANNOT be smaller than visible rect.
	// Return rect that fully covers all cells in given rect (which should be slightly larger).
	//
	//NSRect r1 = [self frameOfCellAtColumn:minCol row:minRow]; // upper left cell rect
	//NSRect r2 = [self frameOfCellAtColumn:maxCol row:maxRow]; // lower right cell rect
	NSAssert(NSContainsRect(rect, visibleRect), @"bad rect being returned");
	NSLog(@"   prepare, orig: %@, final: %@ (%.9f s)", NSStringFromRect(originalRect), NSStringFromRect(rect), CACurrentMediaTime()-startTime);
	
	[super prepareContentInRect:rect]; //NSUnionRect(r1, r2)];
}

// ---------------------------------------------------------
- (void)drawRect:(NSRect)rect
{
//	turn on to make view opaque
//	[[NSColor windowBackgroundColor] set];
//	NSRectFill(rect);
	
	NSRect visibleRect = [self.superview convertRect:self.superview.bounds toView:self]; // convert clip view rect to this view
	BOOL overdrawDrequest = NSIntersectsRect(visibleRect, rect) == NO; // don't enqueue cells during a precache rect request

	NSLog(@"draw rect: %@ %@", NSStringFromRect(rect), overdrawDrequest ? @"(overdraw)" : @"");

	//NSRect *rectsBeingDrawn;
	//NSInteger count;
	//[self getRectsBeingDrawn:&rectsBeingDrawn count:&count];
	
	/*
	NSLog(@"drawRect: Rects being drawn:");
	for (int i=0;i<count;i++) {
		NSRect r = rectsBeingDrawn[i];
		NSLog(@"    %@", NSStringFromRect(r));
	}
	*/
	
	/*
	 float pad = 2;
	scrollPrefetchPosX = self.superview.bounds.size.width * pad;
	scrollPrefetchPosY = self.superview.bounds.size.height * pad;
	scrollPrefetchNegX = self.superview.bounds.size.width * pad;
	scrollPrefetchNegY = self.superview.bounds.size.height * pad;
	*/
	
	/*
	self.scrollPrefetchPosX = MAX(self.scrollPrefetchPosX, ((NSMaxX(rect) - NSMaxX(visibleRect))/visibleRect.size.width));
	self.scrollPrefetchPosY = MAX(self.scrollPrefetchPosY, ((NSMaxY(rect) - NSMaxY(visibleRect))/visibleRect.size.height));
	self.scrollPrefetchNegX = MAX(self.scrollPrefetchNegX, ((NSMinX(visibleRect) - NSMinX(rect))/visibleRect.size.width));
	self.scrollPrefetchNegY = MAX(self.scrollPrefetchNegY, ((NSMinY(visibleRect) - NSMinY(rect))/visibleRect.size.height));
	*/
	
	// update prefetched distances based on what the framework is asking for, save the largest seen
	//scrollPrefetchPosX = MAX(scrollPrefetchPosX, (NSMaxX(rect) - NSMaxX(visibleRect)));
	//scrollPrefetchPosY = MAX(scrollPrefetchPosY, (NSMaxY(rect) - NSMaxY(visibleRect)));
	//scrollPrefetchNegX = MAX(scrollPrefetchNegX, (NSMinX(visibleRect) - NSMinX(rect)));
	//scrollPrefetchNegY = MAX(scrollPrefetchNegY, (NSMinY(visibleRect) - NSMinY(rect)));
	
	NSRect visiblePlusCachedRect = NSMakeRect(MAX(0, visibleRect.origin.x - scrollPrefetchNegX),
											  MAX(0, visibleRect.origin.y - scrollPrefetchNegY),
											  MIN(self.bounds.size.width, visibleRect.size.width + scrollPrefetchNegX + scrollPrefetchPosX),
											  MIN(self.bounds.size.height, visibleRect.size.height + scrollPrefetchNegY + scrollPrefetchPosY));
	
	//NSLog(@"v:%@ r:%@ v+c:%@", NSStringFromRect(visibleRect), NSStringFromRect(rect), NSStringFromRect(visiblePlusCachedRect));
	
	//NSLog(@"x:%.2fx y:%.2fx x:%.0f y:%.0f", scrollPrefetchPosX, scrollPrefetchPosY, NSMaxX(rect)-NSMaxX(visibleRect), NSMaxY(rect)-NSMaxY(visibleRect));
	
	//if (NSMinX(visibleRect) >= NSMaxX(rect))
		//NSLog(@"r:%@, v:%@", NSStringFromRect(rect), NSStringFromRect(visibleRect));
//		NSLog(@"beyond: %.2fx (%.0f pix) [%.0f:%.0f] [%.0f:%.0f]", ((NSMaxX(rect) - NSMaxX(visibleRect))/visibleRect.size.width), NSMaxX(rect)-NSMaxX(visibleRect), NSMinX(visibleRect), NSMaxX(visibleRect), NSMinX(rect), NSMaxX(rect));
	
	NSIndexSet *selectedColumns = [_tableGrid selectedColumnIndexes];
    NSIndexSet *selectedRows = [_tableGrid selectedRowIndexes];
	NSUInteger numberOfColumns = _tableGrid.numberOfColumns;
	NSUInteger numberOfRows = _tableGrid.numberOfRows;

	/*
	NSPoint diagonalFromOrigin = NSMakePoint(visiblePlusCachedRect.origin.x + visiblePlusCachedRect.size.width,
											visiblePlusCachedRect.origin.y + visiblePlusCachedRect.size.height);
	
	NSUInteger minCol = MAX([self columnAtPoint:visiblePlusCachedRect.origin], 0);
	NSUInteger maxCol = MIN([self columnAtPoint:diagonalFromOrigin], _tableGrid.numberOfColumns - 1);
	
	NSUInteger minRow = MAX([self rowAtPoint:visiblePlusCachedRect.origin], 0);
	NSUInteger maxRow = MIN([self rowAtPoint:diagonalFromOrigin], _tableGrid.numberOfRows - 1);
	*/
	
	/*
	// build list of cells to draw as a set of  array of index paths
	NSMutableArray *indexPathsToDraw = [NSMutableArray arrayWithCapacity:(maxCol-minCol+1)*(maxRow-minRow+1)];
	for (NSUInteger columnIndex = minCol; columnIndex <= maxCol; columnIndex++) {
		for (NSUInteger rowIndex = minRow; rowIndex <= maxRow; rowIndex++) {
			NSUInteger indices[] = {columnIndex, rowIndex};
			NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indices length:2];
			[indexPathsToDraw addObject:indexPath];
		}
	}
	 */
	
	/*
	NSUInteger minCol = [self columnAtPoint:rect.origin];
	NSUInteger maxCol = [self columnAtPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)];
	maxCol = MIN(maxCol, _tableGrid.numberOfColumns - 1);
	
	NSUInteger minRow = [self rowAtPoint:rect.origin];
	NSUInteger maxRow = [self rowAtPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)];
	maxRow = MIN(maxRow, _tableGrid.numberOfRows - 1);
	
	//NSLog(@"min/max: c[%d:%d] r[%d:%d]", minCol, maxCol, minRow, maxRow);
	
	NSUInteger firstColumn = NSNotFound;
    NSUInteger lastColumn = (numberOfColumns==0) ? 0 : numberOfColumns - 1;
	NSUInteger firstRow = MAX(0, floor(rect.origin.y / self.rowHeight));
    NSUInteger lastRow = (numberOfRows==0) ? 0 : MIN(numberOfRows - 1, ceil((rect.origin.y + rect.size.height)/self.rowHeight));
	
	// Find the columns to draw
	NSUInteger column = 0;
	while (column < numberOfColumns) {
		NSRect columnRect = [self rectOfColumn:column];
		// sometimes visibleRect goes to < 0 (bouncy scrolling?)
		if (firstColumn == NSNotFound && NSMinX(visibleRect) >= NSMinX(columnRect) && MAX(0, NSMinX(visibleRect)) <= NSMaxX(columnRect)) {
			firstColumn = column;
		} else if (firstColumn != NSNotFound && NSMaxX(visibleRect) >= NSMinX(columnRect) && MAX(0, NSMaxX(visibleRect)) <= NSMaxX(columnRect)) {
			lastColumn = column;
			break;
		}
		column++;
	}
	firstColumn = 0; //MAX(0, firstColumn); // make sure it's at least zero
	
	// Build list of index paths based on columns to draw and number of visible rows.
	// This might be a little overkill since whole rows or columns will ever be dropped at once,
	// but at least this allows for the possiblity to expand the API to accept different views
	// within the same column (something expected in a spreadsheet, for example).
	//
	NSMutableArray *indexPathsToDraw = [NSMutableArray arrayWithCapacity:(lastColumn-firstColumn)*(lastRow-firstRow)];
	for (NSUInteger columnIndex = firstColumn; columnIndex <= lastColumn; columnIndex++) {
		for (NSUInteger rowIndex = firstRow; rowIndex <= lastRow; rowIndex++) {
			NSUInteger indices[] = {columnIndex, rowIndex};
			NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indices length:2];
			[indexPathsToDraw addObject:indexPath];
		}
	}
	*/
	
	//NSLog(@"%@", NSStringFromRect(rect));
	//NSLog(@"A: # of active cells: %d | c[%d:%d] r[%d:%d]", self.activeTableCells.count, minCol, maxCol, minRow, maxRow);
	//NSLog(@"A: # of active cells: %d", self.activeTableCells.count);

	// Remove views at index paths that are no longer in visible + cached rect
	//
	//NSLog(@"precache request: %@", overdrawDrequest ? @"True" : @"False");
	/*
	if (overdrawDrequest == NO) {
		
		for (NSNumber *cacheColNumber in self.activeTableCells.allKeys) {
			
			NSMutableDictionary *rowCache = self.activeTableCells[cacheColNumber]; // key: @(rowNum) value: view

			if (cacheColNumber.intValue < minCol || cacheColNumber.intValue > maxCol) {
				//
				// remove all cells in column if outside current vis+cached range
				//
				if (rowCache != nil) {
					for (NSNumber *cacheRowNumber in rowCache.allKeys) {
						NSView *view = rowCache[cacheRowNumber];
						[view removeFromSuperview];
						[_tableGrid enqueueView:view forIdentifier:view.identifier];
						[rowCache removeObjectForKey:cacheRowNumber];
					}
				}
			}
			else {
				//
				// column is in range of updates; check rows
				//
				if (rowCache != nil) {
					for (NSNumber *cacheRowNumber in rowCache.allKeys) {
						if (cacheRowNumber.intValue < minRow || cacheRowNumber.intValue > maxRow) {
							NSView *view = rowCache[cacheRowNumber];
							[view removeFromSuperview];
							[_tableGrid enqueueView:view forIdentifier:view.identifier];
							[rowCache removeObjectForKey:cacheRowNumber];
						}
					}
				}
			}
		}
	}
	*/
	
	/*
	for (NSIndexPath *indexPath in self.activeTableCells.allKeys) {
		// if a view is active but not in the list of paths to draw, enqueue view for reuse
		if (![indexPathsToDraw containsObject:indexPath]) {
			NSView *view = self.activeTableCells[indexPath];
			[view removeFromSuperview];
			[self.activeTableCells removeObjectForKey:indexPath];
			[_tableGrid enqueueView:view forIdentifier:[view identifier]];
			//NSLog(@"removing index path: %@", indexPath);
		}
	}
	 */
	
	NSPoint diagonalFromOrigin = NSMakePoint(rect.origin.x + rect.size.width,
									 rect.origin.y + rect.size.height);

	NSUInteger rectMinCol = MAX([self columnAtPoint:rect.origin], 0);
	NSUInteger rectMaxCol = MIN([self columnAtPoint:diagonalFromOrigin], _tableGrid.numberOfColumns - 1);
	
	NSUInteger rectMinRow = MAX([self rowAtPoint:rect.origin], 0);
	NSUInteger rectMaxRow = MIN([self rowAtPoint:diagonalFromOrigin], _tableGrid.numberOfRows - 1);

	//NSLog(@"c[%d:%d] r[%d:%d] (pre: %@)", minCol, maxCol, minRow, maxRow, overdrawDrequest ? @"Yes" : @"No" );

	NSUInteger firstColumn = rectMinCol;
	NSUInteger lastColumn = rectMaxCol;
	NSUInteger firstRow = rectMinRow;
	NSUInteger lastRow = rectMaxRow;
	
//	NSUInteger column = firstColumn;
	
//	column = firstColumn;
	for (NSUInteger column=firstColumn; column <= lastColumn; column++) {
		
		//if (column < minCol || column > maxCol)
		//	continue;
		
		NSMutableDictionary *columnCellCache = self.activeTableCells[@(column)];
		if (columnCellCache == nil) {
			columnCellCache = [NSMutableDictionary dictionary];
			self.activeTableCells[@(column)] = columnCellCache;
		}
		
		for (NSUInteger row=firstRow; row <= lastRow; row++)
		{
			//if (row < minRow || row > maxRow)
			//	continue;
			
			NSRect cellFrame = [self frameOfCellAtColumn:column row:row];
			// Only draw the cell if we need to
			NSCell *_cell = [_tableGrid _cellForColumn:column];
			
			// If we need to draw then check if we're a popup button. This may be a bit of
			// a hack, but it seems to clear up the problem with the popup button clearing
			// if you don't select a value. It's the editedRow and editedColumn bits that
			// cause the problem. However, if you remove the row and column condition, then
			// if you type into a text field, the text doesn't get cleared first before you
			// start typing. So this seems to make both conditions work.
			
			if ([self needsToDrawRect:cellFrame] && (!(row == editedRow && column == editedColumn) || [_cell isKindOfClass:MBPopupButtonCell.class]))
			{
                NSColor *backgroundColor = [_tableGrid _backgroundColorForColumn:column row:row] ?: NSColor.whiteColor;
				
				if (!_cell) {
					_cell = _defaultCell;
				}
				
				_cell.formatter = nil; // An exception is raised if the formatter is not set to nil before changing at runtime
				_cell.formatter = [_tableGrid _formatterForColumn:column];
				
				id objectValue = nil;
				
				// get the NSCell from the data source
				// -----------------------------------
				if (isFilling && [selectedColumns containsIndex:column] && [selectedRows containsIndex:row]) {
					objectValue = [_tableGrid _objectValueForColumn:mouseDownColumn row:mouseDownRow];
				} else {
					objectValue = [_tableGrid _objectValueForColumn:column row:row];
				}
				
				// Get (and set) the object value of the cell
				// ------------------------------------------
				if ([_cell isKindOfClass:MBPopupButtonCell.class]) {
					MBPopupButtonCell *cell = (MBPopupButtonCell *)_cell;
					NSInteger index = [cell indexOfItemWithTitle:objectValue];
					[_cell setObjectValue:@(index)];
				} else {
					[_cell setObjectValue:objectValue];
				}
				
				if ([_cell isKindOfClass:MBPopupButtonCell.class]) {
					
					MBPopupButtonCell *cell = (MBPopupButtonCell *)_cell;
					[cell drawWithFrame:cellFrame inView:self withBackgroundColor:backgroundColor];// Draw background color
					
				} else if ([_cell isKindOfClass:MBImageCell.class]) {
					
					MBImageCell *cell = (MBImageCell *)_cell;
                    
                    cell.accessoryButtonImage = [_tableGrid _accessoryButtonImageForColumn:column row:row];
					
					[cell drawWithFrame:cellFrame inView:self withBackgroundColor:backgroundColor];// Draw background color
					
				} else if ([_cell isKindOfClass:MBLevelIndicatorCell.class]) {
					
					MBLevelIndicatorCell *cell = (MBLevelIndicatorCell *)_cell;

					cell.target = self;
					cell.action = @selector(updateLevelIndicator:);
					
					[cell drawWithFrame:cellFrame inView:_tableGrid withBackgroundColor:backgroundColor];// Draw background color
					
				} else {
					// bog standard cell...
					
					/*
					MBTableGridCell *cell = (MBTableGridCell *)_cell;
                    
                    cell.accessoryButtonImage = [_tableGrid _accessoryButtonImageForColumn:column row:row];
                    
					[cell drawWithFrame:cellFrame inView:self withBackgroundColor:backgroundColor];// Draw background color
					*/
					
					//NSUInteger indices[] = {column, row};
					//NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indices length:2];
					
					//NSView *tableCellView = self.activeTableCells[indexPath];
					
					/*
					NSView *tableCellView = columnCellCache[@(row)];
					if (tableCellView == nil) {
						tableCellView = [_tableGrid.delegate tableGrid:_tableGrid viewForTableColumn:column andRow:row];
						[self addSubview:tableCellView];
						//self.activeTableCells[indexPath] = tableCellView;
						columnCellCache[@(row)] = tableCellView;
						//NSLog(@"Adding index path: %@", indexPath);
					}
					tableCellView.frame = cellFrame;
					*/
					
				}
			}
		} // end loop over rows
	} // end loop over columns
	
	//NSLog(@"number of subviews: %d", self.subviews.count);
	//NSLog(@"B: # of active cells: %d", self.activeTableCells.count);
//	if (self.activeTableCells.count == 0) {
//		int i;
//	}
	
	// Draw the selection rectangle
	if(selectedColumns.count && selectedRows.count && _tableGrid.numberOfColumns > 0 && _tableGrid.numberOfRows > 0) {
		NSRect selectionTopLeft = [self frameOfCellAtColumn:selectedColumns.firstIndex row:selectedRows.firstIndex];
		NSRect selectionBottomRight = [self frameOfCellAtColumn:selectedColumns.lastIndex row:selectedRows.lastIndex];
		
		NSRect selectionRect;
		selectionRect.origin = selectionTopLeft.origin;
		selectionRect.size.width = NSMaxX(selectionBottomRight)-selectionTopLeft.origin.x;
		selectionRect.size.height = NSMaxY(selectionBottomRight)-selectionTopLeft.origin.y;
		
        NSRect selectionInsetRect = NSInsetRect(selectionRect, 0, 0);
		NSBezierPath *selectionPath = [NSBezierPath bezierPathWithRect:selectionInsetRect];
		NSAffineTransform *translate = [NSAffineTransform transform];
		//[translate translateXBy:-0.5 yBy:-0.5];
		[selectionPath transformUsingAffineTransform:translate];
		
		NSColor *selectionColor = [NSColor alternateSelectedControlColor];
		
		// If the view is not the first responder, then use a gray selection color
		NSResponder *firstResponder = [self.window firstResponder];
		BOOL disabled = (![firstResponder.class isSubclassOfClass:NSView.class] || ![(NSView *)firstResponder isDescendantOf:_tableGrid] || !self.window.isKeyWindow);
		
		if (disabled) {
			selectionColor = [[selectionColor colorUsingColorSpaceName:NSDeviceWhiteColorSpace] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
        } else if (isFilling) {
            selectionColor = [NSColor colorWithCalibratedRed:0.996 green:0.827 blue:0.176 alpha:1.000];
        }
		
		[[selectionColor colorWithAlphaComponent:0.3] set];
		[selectionPath setLineWidth: 1.0];
		[selectionPath stroke];
        
        [[selectionColor colorWithAlphaComponent:0.2f] set];
        [selectionPath fill];
        
		if (!showsGrabHandle || disabled || [selectedColumns count] > 1) {
			grabHandleRect = NSZeroRect;
		}
        else if (shouldDrawFillPart != MBTableGridTrackingPartNone) {
            // Draw grab handle
            grabHandleRect = NSMakeRect(NSMidX(selectionInsetRect) - kGRAB_HANDLE_HALF_SIDE_LENGTH - 2, (shouldDrawFillPart == MBTableGridTrackingPartFillTop ? NSMinY(selectionInsetRect) : NSMaxY(selectionInsetRect)) - kGRAB_HANDLE_HALF_SIDE_LENGTH - 2, kGRAB_HANDLE_SIDE_LENGTH + 4, kGRAB_HANDLE_SIDE_LENGTH + 4);
            [grabHandleImage drawInRect:grabHandleRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        }
		
        // Inavlidate cursors so we use the correct cursor for the selection in the right place
        [[self window] invalidateCursorRectsForView:self];
	}
	
	// Draw the column drop indicator
	if (isDraggingColumnOrRow && dropColumn != NSNotFound && dropColumn <= _tableGrid.numberOfColumns && dropRow == NSNotFound) {
		NSRect columnBorder;
		if(dropColumn < _tableGrid.numberOfColumns) {
			columnBorder = [self rectOfColumn:dropColumn];
		}
		else if(dropColumn == _tableGrid.numberOfColumns && dropColumn>0) {
			columnBorder = [self rectOfColumn:dropColumn-1];
		}
		else {
			columnBorder = [self rectOfColumn:0];
			columnBorder.origin.x += columnBorder.size.width;
		}
		columnBorder.origin.x = NSMinX(columnBorder)-2.0;
		columnBorder.size.width = 4.0;
		
		NSColor *selectionColor = [NSColor alternateSelectedControlColor];
		
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:columnBorder];
		[borderPath setLineWidth:2.0];
		
		[selectionColor set];
		[borderPath stroke];
	}
	
	// Draw the row drop indicator
	if (isDraggingColumnOrRow && dropRow != NSNotFound && dropRow <= _tableGrid.numberOfRows && dropColumn == NSNotFound) {
		NSRect rowBorder;
		if(dropRow < _tableGrid.numberOfRows) {
			rowBorder = [self rectOfRow:dropRow];
		} else {
			rowBorder = [self rectOfRow:dropRow-1];
			rowBorder.origin.y += rowBorder.size.height;
		}
		rowBorder.origin.y = NSMinY(rowBorder)-2.0;
		rowBorder.size.height = 4.0;
		
		NSColor *selectionColor = [NSColor alternateSelectedControlColor];
		
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:rowBorder];
		[borderPath setLineWidth:2.0];
		
		[selectionColor set];
		[borderPath stroke];
	}
	
	// Draw the cell drop indicator
	if (!isDraggingColumnOrRow && dropRow != NSNotFound && dropRow <= _tableGrid.numberOfRows && dropColumn != NSNotFound && dropColumn <= _tableGrid.numberOfColumns) {
		NSRect cellFrame = [self frameOfCellAtColumn:dropColumn row:dropRow];
		cellFrame.origin.x -= 2.0;
		cellFrame.origin.y -= 2.0;
		cellFrame.size.width += 3.0;
		cellFrame.size.height += 3.0;
		
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:NSInsetRect(cellFrame, 2, 2)];
		
		NSColor *dropColor = [NSColor alternateSelectedControlColor];
		[dropColor set];
		
		borderPath.lineWidth = 2.0;
		[borderPath stroke];
	}
}

- (void)updateCell:(id)sender {
	// This is here just to satisfy NSLevelIndicatorCell because
	// when this view is the controlView for the NSLevelIndicatorCell,
	// it calls updateCell on this controlView.
}

- (void)updateLevelIndicator:(NSNumber *)value {
	NSInteger selectedColumn = [self.tableGrid.selectedColumnIndexes firstIndex];
	NSInteger selectedRow = [self.tableGrid.selectedRowIndexes firstIndex];
	// sanity check to make sure we have an NSNumber.
	// I've observed that when the user lets go of the mouse,
	// the value parameter becomes the MBTableGridContentView
	// object for some reason.
	if ([value isKindOfClass:[NSNumber class]]) {
		[self.tableGrid _setObjectValue:value forColumn:selectedColumn row:selectedRow];
		NSRect cellFrame = [self.tableGrid frameOfCellAtColumn:selectedColumn row:selectedRow];
		[self.tableGrid setNeedsDisplayInRect:cellFrame];
	}
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	// Setup the timer for autoscrolling
	// (the simply calling autoscroll: from mouseDragged: only works as long as the mouse is moving)
	autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(_timerAutoscrollCallback:) userInfo:nil repeats:YES];
	
	NSPoint mouseLocationInContentView = [self convertPoint:theEvent.locationInWindow fromView:nil];
	mouseDownColumn = [self columnAtPoint:mouseLocationInContentView];
	mouseDownRow = [self rowAtPoint:mouseLocationInContentView];
    
    // If the column wasn't found, probably need to flush the cached column rects
    if (mouseDownColumn == NSNotFound) {
        [self.tableGrid.columnRects removeAllObjects];
        
        mouseDownColumn = [self columnAtPoint:mouseLocationInContentView];
    }
    
	NSCell *cell = [self.tableGrid _cellForColumn:mouseDownColumn];
	BOOL cellEditsOnFirstClick = [cell respondsToSelector:@selector(editOnFirstClick)] ? ([(id<MBTableGridEditable>)cell editOnFirstClick]==YES) : self.tableGrid.singleClickCellEdit;
    isFilling = NO;
    
	if (theEvent.clickCount == 1) {
		// Pass the event back to the MBTableGrid (Used to give First Responder status)
		[self.tableGrid mouseDown:theEvent];
		
		NSUInteger selectedColumn = [self.tableGrid.selectedColumnIndexes firstIndex];
		NSUInteger selectedRow = [self.tableGrid.selectedRowIndexes firstIndex];

        isFilling = showsGrabHandle && NSPointInRect(mouseLocationInContentView, grabHandleRect);
        
        if (isFilling) {
            numberOfRowsWhenStartingFilling = self.tableGrid.numberOfRows;
            
            if (mouseDownRow == selectedRow - 1 || mouseDownRow == selectedRow + 1) {
                mouseDownRow = selectedRow;
            }
        }
        
		// Edit an already selected cell if it doesn't edit on first click
		if (selectedColumn == mouseDownColumn && selectedRow == mouseDownRow && !cellEditsOnFirstClick && !isFilling) {
			
			if ([self.tableGrid _accessoryButtonImageForColumn:mouseDownColumn row:mouseDownRow]) {
				NSRect cellFrame = [self frameOfCellAtColumn:mouseDownColumn row:mouseDownRow];
				NSCellHitResult hitResult = [cell hitTestForEvent:theEvent inRect:cellFrame ofView:self];
				if (hitResult != NSCellHitNone) {
					[self.tableGrid _accessoryButtonClicked:mouseDownColumn row:mouseDownRow];
				}
			} else if ([cell isKindOfClass:[MBLevelIndicatorCell class]]) {
				NSRect cellFrame = [self frameOfCellAtColumn:mouseDownColumn row:mouseDownRow];
				
				[cell trackMouse:theEvent inRect:cellFrame ofView:self untilMouseUp:YES];
				
			} else {
				[self editSelectedCell:self text:nil];
			}
			
		// Expand a selection when the user holds the shift key
		} else if (([theEvent modifierFlags] & NSShiftKeyMask) && self.tableGrid.allowsMultipleSelection && !isFilling) {
			// If the shift key was held down, extend the selection
			NSUInteger stickyColumn = [self.tableGrid.selectedColumnIndexes firstIndex];
			NSUInteger stickyRow = [self.tableGrid.selectedRowIndexes firstIndex];
			
			MBTableGridEdge stickyColumnEdge = [self.tableGrid _stickyColumn];
			MBTableGridEdge stickyRowEdge = [self.tableGrid _stickyRow];
			
			// Compensate for sticky edges
			if (stickyColumnEdge == MBTableGridRightEdge) {
				stickyColumn = [self.tableGrid.selectedColumnIndexes lastIndex];
			}
			if (stickyRowEdge == MBTableGridBottomEdge) {
				stickyRow = [self.tableGrid.selectedRowIndexes lastIndex];
			}
			
			NSRange selectionColumnRange = NSMakeRange(stickyColumn, mouseDownColumn-stickyColumn+1);
			NSRange selectionRowRange = NSMakeRange(stickyRow, mouseDownRow-stickyRow+1);
			
			if (mouseDownColumn < stickyColumn) {
				selectionColumnRange = NSMakeRange(mouseDownColumn, stickyColumn-mouseDownColumn+1);
				stickyColumnEdge = MBTableGridRightEdge;
			} else {
				stickyColumnEdge = MBTableGridLeftEdge;
			}
			
			if (mouseDownRow < stickyRow) {
				selectionRowRange = NSMakeRange(mouseDownRow, stickyRow-mouseDownRow+1);
				stickyRowEdge = MBTableGridBottomEdge;
			} else {
				stickyRowEdge = MBTableGridTopEdge;
			}
			
			// Select the proper cells
			self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:selectionColumnRange];
			self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:selectionRowRange];
			
			// Set the sticky edges
			[self.tableGrid _setStickyColumn:stickyColumnEdge row:stickyRowEdge];
		// First click on a cell without shift key modifier
		} else {
			// No modifier keys, so change the selection
			// Only notify observers once even though we change the selection twice
			[self.tableGrid setSelectedColumnIndexes:[NSIndexSet indexSetWithIndex:mouseDownColumn] notify: NO];
			self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndex:mouseDownRow];
			[self.tableGrid _setStickyColumn:MBTableGridLeftEdge row:MBTableGridTopEdge];
		}
    // Edit cells on double click if they don't already edit on first click
	} else if (theEvent.clickCount == 2 && !cellEditsOnFirstClick && ![cell isKindOfClass:[MBLevelIndicatorCell class]]) {
		// Double click
		[self editSelectedCell:self text:nil];
	}

	// Any cells that should edit on first click are handled here
	if (cellEditsOnFirstClick) {
		[self editSelectedCell:self text:nil];
	}

	[self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if (mouseDownColumn != NSNotFound && mouseDownRow != NSNotFound && self.tableGrid.allowsMultipleSelection) {
		NSPoint loc = [self convertPoint:theEvent.locationInWindow fromView:nil];
		NSInteger column = [self columnAtPoint:loc];
		NSInteger row = [self rowAtPoint:loc];
        NSInteger numberOfRows = self.tableGrid.numberOfRows;
        
        // While filling, if dragging beyond the size of the table, add more rows
        if (isFilling && loc.y > 0.0 && row == NSNotFound && [self.tableGrid.dataSource respondsToSelector:@selector(tableGrid:addRows:)]) {
            NSRect rowRect = [self rectOfRow:numberOfRows];
            NSInteger numberOfRowsToAdd = ((loc.y - rowRect.origin.y) / rowRect.size.height) + 1;
            
            if (numberOfRowsToAdd > 0 && [self.tableGrid.dataSource tableGrid:self.tableGrid addRows:numberOfRowsToAdd]) {
                row = [self rowAtPoint:loc];
            }
            
            [self resetCursorRects];
        }
        
        // While filling, if dragging upwards, remove any rows added during the fill operation
        if (isFilling && row < numberOfRows && [self.tableGrid.dataSource respondsToSelector:@selector(tableGrid:removeRows:)]) {
            NSInteger firstRowToRemove = row + 1;
            
            if (firstRowToRemove < numberOfRowsWhenStartingFilling) {
                firstRowToRemove = numberOfRowsWhenStartingFilling;
            }
            
            NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRowToRemove, numberOfRows - firstRowToRemove)];
            
            [self.tableGrid.dataSource tableGrid:self.tableGrid removeRows:rowIndexes];
            
            [self resetCursorRects];
        }
		
		MBTableGridEdge columnEdge = MBTableGridLeftEdge;
		MBTableGridEdge rowEdge = MBTableGridTopEdge;
		
		// Select the appropriate number of columns
		if(column != NSNotFound && !isFilling) {
			NSInteger firstColumnToSelect = mouseDownColumn;
			NSInteger numberOfColumnsToSelect = column-mouseDownColumn+1;
			if(column < mouseDownColumn) {
				firstColumnToSelect = column;
				numberOfColumnsToSelect = mouseDownColumn-column+1;
				
				// Set the sticky edge to the right
				columnEdge = MBTableGridRightEdge;
			}
			
			self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstColumnToSelect,numberOfColumnsToSelect)];
			
		}
		
		// Select the appropriate number of rows
		if(row != NSNotFound) {
			NSInteger firstRowToSelect = mouseDownRow;
			NSInteger numberOfRowsToSelect = row-mouseDownRow+1;
			if(row < mouseDownRow) {
				firstRowToSelect = row;
				numberOfRowsToSelect = mouseDownRow-row+1;
				
				// Set the sticky row to the bottom
				rowEdge = MBTableGridBottomEdge;
			}
			
			self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRowToSelect,numberOfRowsToSelect)];
			
		}
		
		// Set the sticky edges
		[self.tableGrid _setStickyColumn:columnEdge row:rowEdge];
		
        [self setNeedsDisplay:YES];
	}
	
//	[self autoscroll:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	[autoscrollTimer invalidate];
	autoscrollTimer = nil;
	
	if (isFilling) {
		id value = [self.tableGrid _objectValueForColumn:mouseDownColumn row:mouseDownRow];
		
		[self.tableGrid.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
			[self.tableGrid _setObjectValue:[value copy] forColumn:mouseDownColumn row:idx];
		}];
		
        NSInteger numberOfRows = self.tableGrid.numberOfRows;
        
        // If rows were added, tell the delegate
        if (isFilling && numberOfRows > numberOfRowsWhenStartingFilling && [self.tableGrid.delegate respondsToSelector:@selector(tableGrid:didAddRows:)]) {
            NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(numberOfRowsWhenStartingFilling, numberOfRows - numberOfRowsWhenStartingFilling)];
            
            [self.tableGrid.delegate tableGrid:self.tableGrid didAddRows:rowIndexes];
        }
        
		isFilling = NO;
        
        [self.tableGrid setNeedsDisplay:YES];
	}
	
	mouseDownColumn = NSNotFound;
	mouseDownRow = NSNotFound;
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    NSDictionary *dict = theEvent.userData;
    MBTableGridTrackingPart part = [dict[MBTableGridTrackingPartKey] integerValue];
    
    if (shouldDrawFillPart != part) {
//        NSLog(@"mouseEntered: %@", part == MBTableGridTrackingPartFillTop ? @"top" : @"bottom");  // log
        
        shouldDrawFillPart = part;
        self.needsDisplay = YES;
    }
}

- (void)mouseExited:(NSEvent *)theEvent
{
    if (shouldDrawFillPart != MBTableGridTrackingPartNone) {
//        NSLog(@"mouseExited: %@", shouldDrawFillPart == MBTableGridTrackingPartFillTop ? @"top" : @"bottom");  // log
        
        shouldDrawFillPart = MBTableGridTrackingPartNone;
		self.needsDisplay = YES;
    }
}

/*
- (void)scrollWheel:(NSEvent *)event
{
	CGFloat deltaX = event.scrollingDeltaX;
	CGFloat deltaY = event.scrollingDeltaY;

	NSLog(@"x:y [%.0f:%.0f]", deltaX, deltaY);
	
	[super scrollWheel:event];
}
*/

#pragma mark Cursor Rects

- (void)resetCursorRects
{
    //NSLog(@"%s - %f %f %f %f", __func__, grabHandleRect.origin.x, grabHandleRect.origin.y, grabHandleRect.size.width, grabHandleRect.size.height);
	// The main cursor should be the cell selection cursor
	
	NSIndexSet *selectedColumns = self.tableGrid.selectedColumnIndexes;
	NSIndexSet *selectedRows = self.tableGrid.selectedRowIndexes;

	if (selectedColumns.count > 0 && selectedRows.count > 0) {
		NSRect selectionTopLeft = [self frameOfCellAtColumn:[selectedColumns firstIndex] row:[selectedRows firstIndex]];
		NSRect selectionBottomRight = [self frameOfCellAtColumn:[selectedColumns lastIndex] row:[selectedRows lastIndex]];
		
		NSRect selectionRect;
		selectionRect.origin = selectionTopLeft.origin;
		selectionRect.size.width = NSMaxX(selectionBottomRight)-selectionTopLeft.origin.x;
		selectionRect.size.height = NSMaxY(selectionBottomRight)-selectionTopLeft.origin.y;

		[self addCursorRect:selectionRect cursor:[NSCursor arrowCursor]];

		[self addCursorRect:[self visibleRect] cursor:[self _cellSelectionCursor]];
		
		if (showsGrabHandle) {
			[self addCursorRect:grabHandleRect cursor:[self _cellExtendSelectionCursor]];
		}
		
		// Update tracking areas here, to leverage the selection variables
		for (NSTrackingArea *trackingArea in self.trackingAreas) {
			[self removeTrackingArea:trackingArea];
		}
		
		if (selectedColumns.count == 1) {
			NSRect fillTrackingRect = [self rectOfColumn:[selectedColumns firstIndex]];
			fillTrackingRect.size.height = self.frame.size.height;
			NSRect topFillTrackingRect, bottomFillTrackingRect;
			
			NSDivideRect(fillTrackingRect, &topFillTrackingRect, &bottomFillTrackingRect, selectionRect.origin.y + (selectionRect.size.height / 2.0), NSRectEdgeMinY);
			
			[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:topFillTrackingRect
															   options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
																 owner:self
															  userInfo:@{MBTableGridTrackingPartKey : @(MBTableGridTrackingPartFillTop)}]];
			
			[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:bottomFillTrackingRect
															   options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
																 owner:self
															  userInfo:@{MBTableGridTrackingPartKey : @(MBTableGridTrackingPartFillBottom)}]];
		}
	}
}

#pragma mark -
#pragma mark Notifications

#pragma mark Field Editor

- (void)textDidBeginEditingWithEditor:(NSText *)editor
{
    isAutoEditing = YES;
    [self showCompletionsForTextView:(NSTextView *)editor];
}

- (void)textDidBeginEditing:(NSNotification *)notification
{
    if (!isAutoEditing) {
        [self showCompletionsForTextView:notification.object];
    }
    
    isAutoEditing = NO;
}

- (void)textDidChange:(NSNotification *)notification
{
    isAutoEditing = NO;
    [self showCompletionsForTextView:notification.object];
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
    isAutoEditing = NO;
	NSInteger movementType = [aNotification.userInfo[@"NSTextMovement"] integerValue];

	// Give focus back to the table grid (the field editor took it)
	[[self window] makeFirstResponder:self.tableGrid];

	if(movementType != NSCancelTextMovement) {
		NSString *stringValue = [[[aNotification object] string] copy];
		id objectValue;
		NSString *errorDescription;
		NSFormatter *formatter = [self.tableGrid _formatterForColumn:editedColumn];
		BOOL success = [formatter getObjectValue:&objectValue forString:stringValue errorDescription:&errorDescription];
		if (formatter && success) {
			[self.tableGrid _setObjectValue:objectValue forColumn:editedColumn row:editedRow];
		}
		else if (!formatter) {
			[self.tableGrid _setObjectValue:stringValue forColumn:editedColumn row:editedRow];
		}
		else {
			[self.tableGrid _userDidEnterInvalidStringInColumn:editedColumn row:editedRow errorDescription:errorDescription];
		}
	}

	editedColumn = NSNotFound;
	editedRow = NSNotFound;
	
	// End the editing session
	NSText* fe = [[self window] fieldEditor:NO forObject:self];
	[[self.tableGrid cell] endEditing:fe];


	switch (movementType) {
		case NSBacktabTextMovement:
			[self.tableGrid moveLeft:self];
			break;

		case NSTabTextMovement:
			[self.tableGrid moveRight:self];
			break;

		case NSReturnTextMovement:
			if([NSApp currentEvent].modifierFlags & NSShiftKeyMask) {
				[self.tableGrid moveUp:self];
			}
			else {
				[self.tableGrid moveDown:self];
			}
			break;

		case NSUpTextMovement:
			[self.tableGrid moveUp:self];
			break;

		default:
			break;
	}
}

- (void)showCompletionsForTextView:(NSTextView *)textView;
{
    if (!isCompleting) {
        isCompleting = YES;
        [textView complete:nil];
        isCompleting = NO;
    }
}

- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
{
    *index = -1;
    
    NSString *string = textView.string;
    NSArray *completions = [self.tableGrid _autocompleteValuesForEditString:string column:editedColumn row:editedRow];
    
    if (string.length && completions.count && [string isEqualToString:[completions firstObject]]) {
        *index = 0;
    }
    
    return completions;
}

#pragma mark -
#pragma mark Protocol Methods

#pragma mark NSDraggingDestination

/*
 * These methods simply pass the drag event back to the table grid.
 * They are only required for autoscrolling.
 */

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	// Setup the timer for autoscrolling 
	// (the simply calling autoscroll: from mouseDragged: only works as long as the mouse is moving)
	autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(_timerAutoscrollCallback:) userInfo:nil repeats:YES];
	
	return [self.tableGrid draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	return [self.tableGrid draggingUpdated:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[autoscrollTimer invalidate];
	autoscrollTimer = nil;
	
	[self.tableGrid draggingExited:sender];
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
	[self.tableGrid draggingEnded:sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return [self.tableGrid prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return [self.tableGrid performDragOperation:sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[self.tableGrid concludeDragOperation:sender];
}

#pragma mark -
#pragma mark Subclass Methods

/*
- (MBTableGrid *)tableGrid
{
	return (MBTableGrid *)[[self enclosingScrollView] superview];
}
*/

- (void)editSelectedCell:(id)sender text:(NSString *)aString
{
	NSInteger selectedColumn = [self.tableGrid.selectedColumnIndexes firstIndex];
	NSInteger selectedRow = [self.tableGrid.selectedRowIndexes firstIndex];
	NSCell *selectedCell = [self.tableGrid _cellForColumn:selectedColumn];

	// Check if the cell can be edited
	if(![self.tableGrid _canEditCellAtColumn:selectedColumn row:selectedColumn]) {
		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		return;
	}

	// Select it and only it
	if([self.tableGrid.selectedColumnIndexes count] > 1 && editedColumn != NSNotFound) {
		self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:editedColumn];
	}
	if([self.tableGrid.selectedRowIndexes count] > 1 && editedRow != NSNotFound) {
		self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndex:editedRow];
	}

	// Editing a button cell involves simply toggling its state, we don't need to change the edited column and row or enter an editing state
	if ([selectedCell isKindOfClass:[MBButtonCell class]]) {
		id currentValue = [self.tableGrid _objectValueForColumn:selectedColumn row:selectedRow];
		selectedCell.objectValue = @(![currentValue boolValue]);
		[self.tableGrid _setObjectValue:selectedCell.objectValue forColumn:selectedColumn row:selectedRow];

		return;
		
	} else if ([selectedCell isKindOfClass:[MBImageCell class]]) {
		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		
		return;
	} else if ([selectedCell isKindOfClass:[MBLevelIndicatorCell class]]) {
		
		MBLevelIndicatorCell *cell = (MBLevelIndicatorCell *)selectedCell;
		
		id currentValue = [self.tableGrid _objectValueForColumn:selectedColumn row:selectedRow];
		
		if ([aString isEqualToString:@" "]) {
			if ([currentValue integerValue] >= cell.maxValue) {
				cell.objectValue = @0;
			} else {
				cell.objectValue = @([currentValue integerValue] + 1);
			}
		} else {
			NSInteger ratingValue = [aString integerValue];
			if (ratingValue <= cell.maxValue) {
				cell.objectValue = @([aString integerValue]);
			} else {
				cell.objectValue = @([currentValue integerValue]);
			}
		}
		
		[self.tableGrid _setObjectValue:cell.objectValue forColumn:selectedColumn row:selectedRow];

		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		
		return;
	}

	// Get the top-left selection
	editedColumn = selectedColumn;
	editedRow = selectedRow;

	NSRect cellFrame = [self frameOfCellAtColumn:editedColumn row:editedRow];

	[selectedCell setEditable:YES];
	[selectedCell setSelectable:YES];
	
	id currentValue = [self.tableGrid _objectValueForColumn:editedColumn row:editedRow];

	if ([selectedCell isKindOfClass:[MBPopupButtonCell class]]) {
		MBPopupButtonCell *popupCell = (MBPopupButtonCell *)selectedCell;

		NSMenu *menu = selectedCell.menu;
		menu.delegate = self;
		
		for (NSMenuItem *item in menu.itemArray) {
			item.action = @selector(cellPopupMenuItemSelected:);
			item.target = self;

			if ([item.title isEqualToString:currentValue])
			{
				[popupCell selectItem:item];
			}
		}

		[selectedCell.menu popUpMenuPositioningItem:popupCell.selectedItem atLocation:cellFrame.origin inView:self];

	} else {
		NSFormatter *formatter = [self.tableGrid _formatterForColumn:selectedColumn];
		if (formatter && ![currentValue isEqual:@""]) {
			currentValue = [formatter stringForObjectValue:currentValue];
		}

		NSText *editor = [self.window fieldEditor:YES forObject:self];
		editor.delegate = self;
		editor.alignment = selectedCell.alignment;
		editor.font = selectedCell.font;
		selectedCell.stringValue = currentValue;
		editor.string = currentValue;
		NSEvent* event = [NSApp currentEvent];
		if(event != nil && event.type == NSLeftMouseDown) {
			[selectedCell editWithFrame:cellFrame inView:self editor:editor delegate:self event:[NSApp currentEvent]];
		}
		else {
			[selectedCell selectWithFrame:cellFrame inView:self editor:editor delegate:self start:0 length:[currentValue length]];
		}
	}
}

- (void)cellPopupMenuItemSelected:(NSMenuItem *)menuItem {
	MBPopupButtonCell *cell = (MBPopupButtonCell *)[self.tableGrid _cellForColumn:editedColumn];
	[cell selectItem:menuItem];

	[self.tableGrid _setObjectValue:menuItem.title forColumn:editedColumn row:editedRow];
	
	editedColumn = NSNotFound;
	editedRow = NSNotFound;
}

#pragma mark Layout Support

- (NSRect)rectOfColumn:(NSUInteger)columnIndex
{
	NSRect rect = NSZeroRect;
	BOOL foundRect = NO;
	if (columnIndex < self.tableGrid.numberOfColumns) {
		NSValue *cachedRectValue = self.tableGrid.columnRects[@(columnIndex)];
		if (cachedRectValue) {
			rect = [cachedRectValue rectValue];
			foundRect = YES;
		}
	
		if (!foundRect) {
			float width = [self.tableGrid _widthForColumn:columnIndex];
			
			rect = NSMakeRect(0, 0, width, [self frame].size.height);
			//rect.origin.x += 60.0 * columnIndex;
			
			NSUInteger i = 0;
			while(i < columnIndex) {
				float headerWidth = [self.tableGrid _widthForColumn:i];
				rect.origin.x += headerWidth;
				i++;
			}
		
			self.tableGrid.columnRects[@(columnIndex)] = [NSValue valueWithRect:rect];

		}
	}
	
	return rect;
}

- (NSRect)rectOfRow:(NSUInteger)rowIndex
{
	NSRect rect = NSMakeRect(0, 0, self.frame.size.width, self.rowHeight);
	rect.origin.y += self.rowHeight * rowIndex;
	return rect;
}

- (NSRect)frameOfCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex
{
	NSRect columnRect = [self rectOfColumn:columnIndex];
	NSRect rowRect = [self rectOfRow:rowIndex];
	return NSMakeRect(columnRect.origin.x, rowRect.origin.y, columnRect.size.width, rowRect.size.height);
}

- (NSUInteger)columnAtPoint:(NSPoint)aPoint
{
	NSUInteger column = NSNotFound;
	NSUInteger c = 0;
	while(column == NSNotFound && c < self.tableGrid.numberOfColumns) {
		NSRect columnFrame = [self rectOfColumn:c];
		if(aPoint.x >= columnFrame.origin.x && aPoint.x <= (columnFrame.origin.x + columnFrame.size.width)) {
			column = c;
		}
		c++;
	}
	return column;
}

- (NSUInteger)rowAtPoint:(NSPoint)aPoint
{
	NSUInteger row = aPoint.y / self.rowHeight;
	if(row >= 0 && row < self.tableGrid.numberOfRows) {
		return row;
	}
	return NSNotFound;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
	if (object == self.superview) { // clip view
		NSLog(@" changed");
		if ([keyPath isEqualToString:@"frame"]) {
			// the amount of view prefetching seems to depend on the window bounds; reset when those change
			CGFloat pad = 3.0;
			scrollPrefetchPosX = self.bounds.size.width * pad;
			scrollPrefetchPosY = self.bounds.size.height * pad;
			scrollPrefetchNegX = self.bounds.size.width * pad;
			scrollPrefetchNegY = self.bounds.size.height * pad;
		}
	}
}

@end

@implementation MBTableGridContentView (Cursors)

- (NSCursor *)_cellSelectionCursor
{
	NSCursor *cursor = [[NSCursor alloc] initWithImage:cursorImage hotSpot:NSMakePoint(8, 8)];
	return cursor;
}

/**
 * @warning		This method is not as efficient as it could be, but
 *				it should only be called once, at initialization.
 *				TODO: Make it faster
 */
- (NSImage *)_cellSelectionCursorImage
{
	NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(20, 20)];
	[image lockFocusFlipped:YES];
	
	NSRect horizontalInner = NSMakeRect(7.0, 2.0, 2.0, 12.0);
	NSRect verticalInner = NSMakeRect(2.0, 7.0, 12.0, 2.0);
	
	NSRect horizontalOuter = NSInsetRect(horizontalInner, -1.0, -1.0);
	NSRect verticalOuter = NSInsetRect(verticalInner, -1.0, -1.0);
	
	// Set the shadow
	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.8]];
	[shadow setShadowBlurRadius:2.0];
	[shadow setShadowOffset:NSMakeSize(0, -1.0)];
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	[shadow set];
	
	[[NSColor blackColor] set];
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	// Fill them again to compensate for the shadows
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSColor whiteColor] set];
	NSRectFill(horizontalInner);
	NSRectFill(verticalInner);
	
	[image unlockFocus];
	
	return image;
}

- (NSCursor *)_cellExtendSelectionCursor
{
	NSCursor *cursor = [[NSCursor alloc] initWithImage:cursorExtendSelectionImage hotSpot:NSMakePoint(8, 8)];
	return cursor;
}

/**
 * @warning		This method is not as efficient as it could be, but
 *				it should only be called once, at initialization.
 *				TODO: Make it faster
 */
- (NSImage *)_cellExtendSelectionCursorImage
{
	NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(20, 20)];
	[image lockFocusFlipped:YES];
	
	NSRect horizontalInner = NSMakeRect(7.0, 1.0, 0.5, 12.0);
	NSRect verticalInner = NSMakeRect(1.0, 6.0, 12.0, 0.5);
	
	NSRect horizontalOuter = NSInsetRect(horizontalInner, -1.0, -1.0);
	NSRect verticalOuter = NSInsetRect(verticalInner, -1.0, -1.0);
	
	// Set the shadow
//	NSShadow *shadow = [[NSShadow alloc] init];
//	[shadow setShadowColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.8]];
//	[shadow setShadowBlurRadius:1.0];
//	[shadow setShadowOffset:NSMakeSize(0, -1.0)];
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
//	[shadow set];
	
	[[NSColor whiteColor] set];
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	// Fill them again to compensate for the shadows
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSColor blackColor] set];
	NSRectFill(horizontalInner);
	NSRectFill(verticalInner);
	
	[image unlockFocus];
	
	return image;
}

- (NSImage *)_grabHandleImage;
{
	NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(kGRAB_HANDLE_SIDE_LENGTH, kGRAB_HANDLE_SIDE_LENGTH)];
	[image lockFocusFlipped:YES];
	
	NSGraphicsContext *gc = [NSGraphicsContext currentContext];
	
	// Save the current graphics context
	[gc saveGraphicsState];
	
	// Set the color in the current graphics context
	
	[[NSColor darkGrayColor] setStroke];
	[[NSColor colorWithCalibratedRed:0.996 green:0.827 blue:0.176 alpha:1.000] setFill];
	
	// Create our circle path
	NSRect rect = NSMakeRect(1.0, 1.0, kGRAB_HANDLE_SIDE_LENGTH - 2.0, kGRAB_HANDLE_SIDE_LENGTH - 2.0);
	NSBezierPath *circlePath = [NSBezierPath bezierPath];
	[circlePath setLineWidth:0.5];
	[circlePath appendBezierPathWithOvalInRect: rect];
	
	// Outline and fill the path
	[circlePath fill];
	[circlePath stroke];
	
	// Restore the context
	[gc restoreGraphicsState];
	[image unlockFocus];
	
	return image;
}

@end

@implementation MBTableGridContentView (DragAndDrop)

- (void)_setDraggingColumnOrRow:(BOOL)flag
{
	isDraggingColumnOrRow = flag;
}

- (void)_setDropColumn:(NSInteger)columnIndex
{
	dropColumn = columnIndex;
	[self setNeedsDisplay:YES];
}

- (void)_setDropRow:(NSInteger)rowIndex
{
	dropRow = rowIndex;
	[self setNeedsDisplay:YES];
}

- (void)_timerAutoscrollCallback:(NSTimer *)aTimer
{
	NSEvent* event = [NSApp currentEvent];
    if ([event type] == NSLeftMouseDragged )
        [self autoscroll:event];
}

@end
