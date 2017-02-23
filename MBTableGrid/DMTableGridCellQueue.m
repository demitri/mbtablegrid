//
//  DMTableGridCellQueue.m
//  MBTableGrid
//
//  Created by Demitri Muna on 5/25/16.
//
//

#import "DMTableGridCellQueue.h"

@interface DMTableGridCellQueue ()
//@property(nonatomic, strong, readwrite) NSMutableDictionary <NSString *,NSNib *> *registeredNibsByIdentifier;
@property(nonatomic, strong, readwrite) NSMutableDictionary *registeredObjectsByIdentifier;
- (NSView*)_createNewCellWithIdentifier:(NSString*)identifier; // andOwner:(id)owner;
@end

@implementation DMTableGridCellQueue

- (instancetype)init
{
	self = [super init];
	if (self) {
		self.queues = [NSMutableDictionary dictionary];
		//self.registeredNibsByIdentifier = [NSMutableDictionary dictionary];
		self.registeredObjectsByIdentifier = [NSMutableDictionary dictionary];
		//self.registeredOwnersByIdentifier = [NSMutableDictionary dictionary];
		self.minimumCacheSize = 10;
		self.fillCache = NO;
	}
	return self;
}

// object can be a block or an NSNib
- (void)registerViewSource:(NSObject*)nibOrBlock forIdentifier:(nonnull NSString *)identifier
{
	NSAssert(identifier != nil, @"object registered cannot be nil");
	
	if (nibOrBlock == nil) {
		//[self.registeredNibsByIdentifier removeObjectForKey:identifier];
		[self.registeredObjectsByIdentifier removeObjectForKey:identifier];
		[self.queues removeObjectForKey:identifier];
	}
	else {
		//self.registeredNibsByIdentifier[identifier] = nib;
		self.registeredObjectsByIdentifier[identifier] = nibOrBlock;
		if (self.queues[identifier] == nil) {
			self.queues[identifier] = [NSMutableArray array];
		}
	}
}

#pragma mark -
#pragma mark Enqueue/dequeue methods

- (NSView*)dequeueViewWithIdentifier:(nonnull NSString*)identifier //owner:(id)owner
{
	NSParameterAssert(identifier);
	
	NSView *view;
	
	NSMutableArray *cellCache = self.queues[identifier];
	NSAssert(cellCache != nil, @"cell cache not created or unregistered identifier ('%@')", identifier);
	
	/*
	if (self.fillCache) {
		[self fillCacheToCount:self.minimumCacheSize
				withIdentifier:identifier
					  andOwner:self.registeredOwnersByIdentifier[identifier]];
		self.fillCache = NO;
	}
	*/
	
	if (cellCache.count > 0) {
		//NSLog(@"cache hit (%d)", cellCache.count);
		// retrieve cell from cache
		view = cellCache.lastObject;
		[cellCache removeObject:view];
	}
	else {
		//NSLog(@"creating new cell (%d)", cellCache.count);
		// no cell available; make one
		view = [self _createNewCellWithIdentifier:identifier]; // andOwner:self.registeredOwnersByIdentifier[identifier]];
	}
	return view;
}

- (void)enqueueView:(NSView*)cell withIdentifier:(NSString*)identifier
{
	NSMutableArray *cellCache = self.queues[identifier];
	NSAssert(cellCache != nil, @"cell cache not created or unregistered identifier ('%@')", identifier);
	[cellCache addObject:cell];
	//NSLog(@"adding to queue (%d)", cellCache.count);
}

#pragma mark -

- (void)fillCacheToCount:(NSUInteger)count withIdentifier:(NSString*)identifier //andOwner:(id)owner
{
	NSMutableArray *cellCache = self.queues[identifier];

	for (NSUInteger i=cellCache.count; i < count+1; i++) {
		NSView *view = [self _createNewCellWithIdentifier:identifier]; // andOwner:self.registeredOwnersByIdentifier[identifier]];
		[self enqueueView:view withIdentifier:identifier];
	}
}

#pragma mark -

- (NSView*)_createNewCellWithIdentifier:(NSString*)identifier // andOwner:(id)owner
{
	//NSLog(@"creating new cell");
	
	id nibOrBlock = self.registeredObjectsByIdentifier[identifier]; // self.registeredNibsByIdentifier[identifier];
	
	if ([nibOrBlock isKindOfClass:NSNib.class]) {
		NSNib *nib = (NSNib*)nibOrBlock;

		NSArray *topLevelObjects;
	
		//NSNib *nib = self.registeredNibsByIdentifier[identifier];
		//NSAssert(nib != nil, @"lost the nib or it wasn't registered");
		
		//NSViewController *owner = self.registeredOwnersByIdentifier[identifier];
		
		// unarchive nib
		if (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_8) {
			[nib instantiateWithOwner:nil topLevelObjects:&topLevelObjects];
		}
		else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			[nib instantiateNibWithOwner:nil topLevelObjects:&topLevelObjects]; // deprecated in 10.8
#pragma clang diagnostic pop
		}
		
		// find the object that has the requested identifier
		NSUInteger index = [topLevelObjects indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
			return [obj isKindOfClass:NSView.class] && [((NSView*)obj).identifier isEqualToString:identifier];
		}];
		NSAssert(index != NSNotFound, @"The nib '%@' does not contain an NSView object with identifier '%@'.", nib, identifier);
		
		NSView *view = topLevelObjects[index];
		view.wantsLayer = YES;
		//view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
		view.translatesAutoresizingMaskIntoConstraints = YES;
		view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
		
		return view;
	}
	else {
		// block
		NSView*(^block)() = nibOrBlock;
		NSView *view = block();
		view.autoresizingMask = NSViewNotSizable;
		return view;
	}
	
	NSAssert(FALSE, @"unknown object type encountered.");
	return nil;
}

@end
