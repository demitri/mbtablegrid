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

#import "MBTableGridHeaderCell.h"

@interface MBTableGridHeaderCell ()

@property (nonatomic, strong) NSShadow *textShadow;

@end

#pragma mark -

@implementation MBTableGridHeaderCell

@synthesize orientation;
//@synthesize labelFont;

- (NSColor*)borderColor
{
	if (_borderColor == nil)
		_borderColor = [[NSColor gridColor] colorWithAlphaComponent:0.5];
	return _borderColor;
}

- (NSShadow*)textShadow
{
	if (_textShadow == nil) {
		_textShadow = [[NSShadow alloc] init];
		_textShadow.shadowOffset = NSMakeSize(0,-1);
		_textShadow.shadowBlurRadius = 0.0;
		_textShadow.shadowColor = NSColor.controlHighlightColor;
	}
	return _textShadow;
}

- (NSFont*)labelFont
{
	if (_labelFont == nil)
		_labelFont = [NSFont labelFontOfSize:[NSFont labelFontSize]];
	return _labelFont;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect cellFrameRect = cellFrame;
	
	[[NSColor windowBackgroundColor] set];
	NSRectFill(cellFrame);
		
	if(self.orientation == MBTableHeaderHorizontalOrientation) {
		// Draw the right border
		NSRect borderLine = NSMakeRect(NSMaxX(cellFrameRect)-1, NSMinY(cellFrameRect) + 4.0, 1.0, NSHeight(cellFrameRect) - 4.0);
		[self.borderColor set];
		NSRectFill(borderLine);
		
		// Draw the bottom border
		NSRect bottomLine = NSMakeRect(NSMinX(cellFrameRect), NSMaxY(cellFrameRect)-1.0, NSWidth(cellFrameRect), 1.0);
		NSRectFill(bottomLine);
		
	} else if(self.orientation == MBTableHeaderVerticalOrientation) {
		// Draw the right border
		[self.borderColor set];
		NSRect borderLine = NSMakeRect(NSMaxX(cellFrameRect)-1, NSMinY(cellFrameRect), 1.0, NSHeight(cellFrameRect)-1);
		NSRectFill(borderLine);
		
		// Draw the bottom border
		NSRect bottomLine = NSMakeRect(NSMinX(cellFrameRect) + 4.0, NSMaxY(cellFrameRect)-1.0, NSWidth(cellFrameRect) - 4.0, 1.0);
		NSRectFill(bottomLine);
	}
	
	if([self state] == NSOnState) {
		NSRect fillRect = cellFrameRect;
		if(self.orientation == MBTableHeaderVerticalOrientation) {
			fillRect.origin.y -= 1.0;
			fillRect.origin.x += 2.0;
			fillRect.size.height += 2.0;
			fillRect.size.width += 4.0;
		}
		else if(self.orientation == MBTableHeaderHorizontalOrientation) {
			fillRect.size.height += 4.0;
			fillRect.origin.x -= 1.0;
			fillRect.size.width += 2.0;
		}
		NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:4.0 yRadius:4.0];

		NSColor* overlayWhite = [NSColor whiteColor];
		[overlayWhite set];
		[path fill];

		NSColor *overlayColor = [[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.26];
		[overlayColor set];
		[path fill];
	}
	
	// Draw the text
	[self drawInteriorWithFrame:cellFrameRect inView:controlView];
}

- (NSAttributedString *)attributedStringValue {
	NSDictionary *attributes = @{ NSFontAttributeName: self.labelFont,
								  NSForegroundColorAttributeName: [NSColor controlTextColor] };
	return [[NSAttributedString alloc] initWithString:self.stringValue attributes:attributes];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect cellFrameRect = cellFrame;

	static CGFloat TEXT_PADDING = 4;
	NSRect textFrame;
	CGSize stringSize = self.attributedStringValue.size;
	
	NSAttributedString *stringToDraw;
	
	if (self.orientation == MBTableHeaderHorizontalOrientation)
	{
		if (stringSize.width < cellFrame.size.width) {
			textFrame = NSMakeRect(cellFrameRect.origin.x + (cellFrameRect.size.width - stringSize.width)/2,
								   cellFrameRect.origin.y + (cellFrameRect.size.height - stringSize.height)/2,
								   cellFrameRect.size.width - TEXT_PADDING,
								   stringSize.height);
			stringToDraw = self.attributedStringValue;
		}
		else {
			textFrame = NSMakeRect(cellFrameRect.origin.x + TEXT_PADDING, // + (cellFrameRect.size.width - stringSize.width)/2,
								   cellFrameRect.origin.y + (cellFrameRect.size.height - stringSize.height)/2,
								   cellFrameRect.size.width - 2*TEXT_PADDING,
								   stringSize.height);
			stringToDraw = [self string:self.attributedStringValue byTruncatingToWidth:cellFrame.size.width];
		}

	} else {
		textFrame = NSMakeRect(cellFrameRect.origin.x + (cellFrameRect.size.width - stringSize.width)/2,
							   cellFrameRect.origin.y + (cellFrameRect.size.height - stringSize.height)/2,
							   stringSize.width,
							   stringSize.height);
	}

	[[NSGraphicsContext currentContext] saveGraphicsState];

	[self.textShadow set];

	[stringToDraw drawWithRect:textFrame options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin];
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (NSAttributedString*)string:(NSAttributedString*)string byTruncatingToWidth:(CGFloat)width
{
	// Create copy that will be the returned result
	NSAttributedString *truncatedString = [[NSAttributedString alloc] initWithAttributedString:string];
 
	NSDictionary *fontAttributes = [string fontAttributesInRange:NSMakeRange(0, 1)];
	
	// Make sure string is longer than requested width
	if (string.size.width > width)
	{
		// Accommodate for ellipsis we'll tack on the end
		width -= [@"…" sizeWithAttributes:fontAttributes].width;
		
		// Loop, deleting characters until string fits within width
		NSRange range = NSMakeRange(0, truncatedString.length-1);
		while (truncatedString.size.width > width) {
			range.length--;
			truncatedString = [truncatedString attributedSubstringFromRange:range];
		}
		
		// Append ellipsis
		truncatedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@…", truncatedString.string]
														  attributes:fontAttributes];
		
	}
	
	return truncatedString;
}

@end
