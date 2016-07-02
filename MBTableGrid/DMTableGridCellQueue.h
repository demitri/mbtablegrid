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

@property (nonatomic, strong, nonnull) NSMutableDictionary *queues; // key:<NSString*> (cell identifier) value: <NSMutableArray*> (array of cells)
//@property (nonatomic, strong) NSMutableDictionary *cellNibs; // key: <NSString*> (cell identifier) value: <NSString*>

//@property(nonatomic, readonly) NSMutableDictionary <NSString *,NSNib *> *registeredNibsByIdentifier;
@property(nonatomic, readonly, nonnull) NSMutableDictionary *registeredObjectsByIdentifier;
//@property(nonatomic, readonly) NSMutableDictionary <NSString *,NSObject *> *registeredOwnersByIdentifier;

@property(nonatomic, assign) NSUInteger minimumCacheSize;
@property(nonatomic, assign) BOOL fillCache;

- (void)registerViewSource:(nonnull NSObject*)nibOrBlock forIdentifier:(nonnull NSString *)identifier;
//- (void)registerNib:(NSNib *)nib forIdentifier:(nonnull NSString *)identifier; // andOwnerClass:(Class)owner;
//- (void)registerCellWithIdentifier:(NSString*)cellIdentifier fromNibName:(NSString*)nibName;

// enqueue / dequeue methods
- (nullable NSView*)dequeueViewWithIdentifier:(nonnull NSString*)identifier; // owner:(id)owner;
- (void)enqueueView:(nonnull NSView*)view withIdentifier:(nonnull NSString*)identifier;

- (void)fillCacheToCount:(NSUInteger)count withIdentifier:(nonnull NSString*)identifier; // andOwner:(NSViewController*)owner;

@end
