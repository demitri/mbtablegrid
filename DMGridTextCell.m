//
//  DMGridTextCell.m
//  MBTableGrid
//
//  Created by Demitri Muna on 6/19/16.
//
//

#import "DMGridTextCell.h"
#import <QuartzCore/QuartzCore.h>

@implementation DMGridTextCell

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil)
	{
		self.wantsLayer = YES;
	}
	return self;
}

/*
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}
*/

-(CALayer*)makeBackingLayer
{
	CATextLayer *textLayer = [[CATextLayer alloc] init];
	textLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
	return textLayer;
}

/*
- (BOOL)wantsLayer
{
	return YES;
}
*/
@end
