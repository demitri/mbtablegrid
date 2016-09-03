//
//  DMTextLayer.m
//  MBTableGrid
//
//  Created by Demitri Muna on 9/3/16.
//
//

#import "DMTextLayer.h"

@implementation DMTextLayer

- (void)drawInContext:(CGContextRef)ctx
{
	CGFloat height, fontSize;
	
	height = self.bounds.size.height;
	fontSize = self.fontSize;
	
	CGContextSaveGState(ctx);
	CGContextTranslateCTM(ctx, 0.0, (fontSize-height)/2.0 - 1.0); // negative
	[super drawInContext:ctx];
	CGContextRestoreGState(ctx);
}

@end
