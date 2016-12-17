//
//  DMGridTextCell.h
//  MBTableGrid
//
//  Created by Demitri Muna on 6/19/16.
//
//

#import <Cocoa/Cocoa.h>

@interface DMGridTextCell : NSView

// this is just a passthrough to the underlying CATextLayer
@property (nonatomic) NSString *string;

@end
