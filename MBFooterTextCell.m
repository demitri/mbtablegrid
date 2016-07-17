//
//  MBFooterTextCell.m
//  MBTableGrid
//
//  Created by David Sinclair on 2015-02-27.
//

#import "MBFooterTextCell.h"

@interface MBFooterTextCell ()

@property (nonatomic, strong) NSShadow *textShadow;
@property (nonatomic, strong) NSFont *attributedTitleFont;

@end

#pragma mark -

@implementation MBFooterTextCell

- (NSAttributedString *)attributedTitle
{
    NSColor *color = [NSColor controlTextColor];
    NSDictionary *attributes = @{NSFontAttributeName : self.attributedTitleFont, NSForegroundColorAttributeName : color};
    
    return [[NSAttributedString alloc] initWithString:self.title attributes:attributes];
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView withBackgroundColor:(NSColor *)backgroundColor {
	
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    static CGFloat TEXT_PADDING = 6;
    NSRect textFrame;
    CGSize stringSize = self.attributedTitle.size;
    textFrame = NSMakeRect(cellFrame.origin.x + TEXT_PADDING,
						   cellFrame.origin.y + (cellFrame.size.height - stringSize.height)/2,
						   cellFrame.size.width - TEXT_PADDING,
						   stringSize.height);
    
    [[NSGraphicsContext currentContext] saveGraphicsState];
    
    [self.textShadow set];
    
    [self.attributedTitle drawWithRect:textFrame options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin];
    
    [[NSGraphicsContext currentContext] restoreGraphicsState];
    
}

- (NSFont*)attributedTitleFont
{
	if (_attributedTitleFont == nil) {
		_attributedTitleFont = [NSFont labelFontOfSize:NSFont.labelFontSize];
	}
	return _attributedTitleFont;
}

- (NSShadow*)textShadow
{
	if (_textShadow == nil) {
		_textShadow = [[NSShadow alloc] init];
		_textShadow.shadowOffset = NSMakeSize(0,-1);
		_textShadow.shadowBlurRadius = 0.0;
		_textShadow.shadowColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.8];
	}
	return _textShadow;
}

@end
