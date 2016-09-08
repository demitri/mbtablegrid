//
//  DMGridColumn.h
//  MBTableGrid
//
//  Created by Demitri Muna on 6/14/16.
//
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface DMGridColumn : NSObject

#if __has_feature(objc_generics)
@property (nonatomic, strong) NSMutableArray<NSView*> *cellViews;	// visible cells views
#else
@property (nonatomic, strong) NSMutableArray *cellViews;	// visible cells views
#endif
@property (nonatomic, assign) NSRange range;						// range of visible cells
@property (nonatomic, assign) NSUInteger column;					// column number

- (instancetype)initWithColumn:(NSUInteger)column;

@end
