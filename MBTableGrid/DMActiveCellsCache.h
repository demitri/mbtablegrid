//
//  DMActiveCellsCache.h
//  MBTableGrid
//
//  Created by Demitri Muna on 5/30/16.
//
//

#import <Foundation/Foundation.h>

@interface DMActiveCellsCache : NSObject

@property (nonatomic, strong) NSMutableArray *columns;

- (void)fillRowsFrom:(NSUInteger)startRow to:(NSUInteger)endRow inColumn:(NSUInteger)column;

@end
