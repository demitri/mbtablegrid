//
//  DMGridColumn.m
//  MBTableGrid
//
//  Created by Demitri Muna on 6/14/16.
//
//

#import "DMGridColumn.h"

@implementation DMGridColumn

- (instancetype)initWithColumn:(NSUInteger)column
{
	self = [super init];
	if (self != nil) {
		self.column = column;
		self.cellViews = [NSMutableArray array];
		self.range = NSMakeRange(0,0);
	}
	return self;
}



@end
