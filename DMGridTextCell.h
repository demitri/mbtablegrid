//
//  DMGridTextCell.h
//  MBTableGrid
//
//  Created by Demitri Muna on 6/19/16.
//
//  An NSView that has a DMTextLayer (subclass of CATextLayer) as its backing layer.

#import <Cocoa/Cocoa.h>

@interface DMGridTextCell : NSView

@property (nonatomic) NSString *string;

@end
