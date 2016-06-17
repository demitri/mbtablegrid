//
//  DMGridStackView.h
//  MBTableGrid
//
//  Created by Demitri Muna on 6/14/16.
//
//

#import <Cocoa/Cocoa.h>

@interface DMGridStackView : NSStackView

@property (nonatomic, assign) BOOL visible;
@property (nonatomic, assign) NSUInteger column;

@property (nonatomic, assign) NSRange rowsInStack;

// constraints to enclosing view
@property (nonatomic, weak) NSLayoutConstraint *widthConstraint;
@property (nonatomic, weak) NSLayoutConstraint *leftConstraint;

- (void)_printCellMap;

@end
