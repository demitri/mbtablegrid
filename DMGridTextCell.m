//
//  DMGridTextCell.m
//  MBTableGrid
//
//  Created by Demitri Muna on 6/19/16.
//
//

#import "DMGridTextCell.h"
#import "DMTextLayer.h"
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

-(CALayer*)makeBackingLayer
{
	//CATextLayer *textLayer = [[CATextLayer alloc] init];
	CATextLayer *textLayer = [[DMTextLayer alloc] init];
	textLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
	return textLayer;
}

- (NSString*)string
{
	return [(CATextLayer*)self.layer string];
}

- (void)setString:(NSString*)newString
{
	[(CATextLayer*)self.layer setString:newString];
}

@end
