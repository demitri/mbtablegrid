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
	{
		// change origin of the user coordinate system
		//
		CGContextTranslateCTM(ctx,							// context
							  -3.0,							// amount to move x-axis - give a bit of padding instead of drawing at edge
							  (fontSize-height)/2.0 - 1.0); // amount to move y-axis to vertically center text (negative)

		[super drawInContext:ctx];
	}
	CGContextRestoreGState(ctx);
}

@end
