//
//  DMTableGridCellQueue.h
//  MBTableGrid
//
//  Created by Demitri Muna on 5/25/16.
//
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface DMTableGridCellQueue : NSObject

@property (nonatomic, strong) NSMutableDictionary *queues; // key:<NSString*> (cell identifier) value: <NSMutableArray*> (array of cells)
//@property (nonatomic, strong) NSMutableDictionary *cellNibs; // key: <NSString*> (cell identifier) value: <NSString*>

@property(nonatomic, readonly) NSMutableDictionary <NSString *,NSNib *> *registeredNibsByIdentifier;

@property(nonatomic, assign) NSUInteger minimumCacheSize;
@property(nonatomic, assign) BOOL fillCache;

- (void)registerNib:(NSNib *)nib forIdentifier:(NSString *)identifier andOwner:(id)owner;
//- (void)registerCellWithIdentifier:(NSString*)cellIdentifier fromNibName:(NSString*)nibName;

// enqueue / dequeue methods
- (NSView*)dequeueViewWithIdentifier:(NSString*)identifier owner:(id)owner;
- (void)enqueueView:(NSView*)view withIdentifier:(NSString*)identifier;

- (void)fillCacheToCount:(NSUInteger)count withIdentifier:(NSString*)identifier andOwner:(id)owner;

@end
