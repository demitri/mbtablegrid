//
//  DMGridStackView.m
//  MBTableGrid
//
//  Created by Demitri Muna on 6/14/16.
//
//

#import "DMGridStackView.h"

@implementation DMGridStackView

/*
- (NSSize)intrinsicContentSize
{
	return NSMakeSize(60,3000);
}
*/

- (void)drawRect:(NSRect)dirtyRect
{
	CGFloat wireframeLineWidth = 2;
	NSColor *wireframeLineColor = [[NSColor orangeColor] colorWithAlphaComponent:0.5];
	NSColor *wireframeDotColor = [[NSColor greenColor] colorWithAlphaComponent:0.5];
	CGFloat wireframeDotDiameter = 8;
	
	// Draw an outline of our frame.
	NSRect outlineRect = NSInsetRect([self bounds], wireframeLineWidth/2., wireframeLineWidth/2.);
	NSBezierPath *outlinePath = [NSBezierPath bezierPathWithRect:outlineRect];
	
	[wireframeLineColor set];
	[outlinePath setLineWidth:wireframeLineWidth];
	[outlinePath stroke];
	
	// Draw the diagonals.
	NSBezierPath *diagonalsPath = [NSBezierPath bezierPath];
	[diagonalsPath moveToPoint:NSMakePoint(NSMinX([self bounds]), NSMinY([self bounds]))];
	[diagonalsPath lineToPoint:NSMakePoint(NSMaxX([self bounds]), NSMaxY([self bounds]))];
	[diagonalsPath moveToPoint:NSMakePoint(NSMinX([self bounds]), NSMaxY([self bounds]))];
	[diagonalsPath lineToPoint:NSMakePoint(NSMaxX([self bounds]), NSMinY([self bounds]))];
	
	[wireframeLineColor set];
	[diagonalsPath setLineWidth:wireframeLineWidth];
	[diagonalsPath stroke];
	
	// Draw a dot at the lower left corner.
	NSRect dotRect = NSMakeRect(NSMinX([self bounds]), NSMinY([self bounds]),
								wireframeDotDiameter, wireframeDotDiameter);
	NSBezierPath *dotPath = [NSBezierPath bezierPathWithOvalInRect:dotRect];
	
	[wireframeDotColor set];
	[dotPath fill];
}

- (void)_printCellMap
{
	NSMutableArray *indices = [NSMutableArray array];
	for (NSView *view in self.views) {
		[indices addObject:[[view.subviews objectAtIndex:0] stringValue]];
	}
	//NSLog(@"indices: %@", [indices componentsJoinedByString:@","]);
}

@end
