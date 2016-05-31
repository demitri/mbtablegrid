//
//  DMActiveCellsCache.m
//  MBTableGrid
//
//  Created by Demitri Muna on 5/30/16.
//
//

#import "DMActiveCellsCache.h"

@implementation DMActiveCellsCache

- (instancetype)init
{
	self = [super init];
	if (self) {
		self.columns = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)fillRowsFrom:(NSUInteger)startRow to:(NSUInteger)endRow inColumn:(NSUInteger)column
{
//	NSMutableArray *columnViews =
}

@end
