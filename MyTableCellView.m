//
//  MyTableCellView.m
//  MBTableGrid
//
//  Created by Demitri Muna on 5/24/16.
//
//

#import "MyTableCellView.h"

@implementation MyTableCellView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSLog(@"mouse down from cell view");
}

@end
