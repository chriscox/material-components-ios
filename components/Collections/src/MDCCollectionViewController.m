/*
 Copyright 2016-present the Material Components for iOS authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MDCCollectionViewController.h"

#import "MDCCollectionViewFlowLayout.h"
#import "MaterialCollectionCells.h"
#import "MaterialInk.h"
#import "private/MDCCollectionStringResources.h"
#import "private/MDCCollectionViewEditor.h"
#import "private/MDCCollectionViewStyler.h"

#import <tgmath.h>

@interface MDCCollectionViewController () <MDCInkTouchControllerDelegate>
@property(nonatomic, assign) BOOL currentlyActiveInk;
@end

@implementation MDCCollectionViewController {
  MDCInkTouchController *_inkTouchController;
  BOOL _headerInfoBarDismissed;
  CGPoint _inkTouchLocation;
}

@synthesize collectionViewLayout = _collectionViewLayout;

- (instancetype)init {
  MDCCollectionViewFlowLayout *defaultLayout = [[MDCCollectionViewFlowLayout alloc] init];
  return [self initWithCollectionViewLayout:defaultLayout];
}

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout {
  self = [super initWithCollectionViewLayout:layout];
  if (self) {
    _collectionViewLayout = layout;
  }
  return self;
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self != nil) {
    // TODO(#): Why is this nil, the decoder should have created it
    if (!_collectionViewLayout) {
      _collectionViewLayout = [[MDCCollectionViewFlowLayout alloc] init];
    }
  }

  return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self != nil) {
    // TODO(#): Why is this nil, the decoder should have created it
    if (!_collectionViewLayout) {
      _collectionViewLayout = [[MDCCollectionViewFlowLayout alloc] init];
    }
  }

  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  [self.collectionView setCollectionViewLayout:self.collectionViewLayout];
  self.collectionView.backgroundColor = [UIColor whiteColor];
  self.collectionView.alwaysBounceVertical = YES;

  _styler = [[MDCCollectionViewStyler alloc] initWithCollectionView:self.collectionView];
  _styler.delegate = self;

  _editor = [[MDCCollectionViewEditor alloc] initWithCollectionView:self.collectionView];
  _editor.delegate = self;

  // Set up ink touch controller.
  _inkTouchController = [[MDCInkTouchController alloc] initWithView:self.collectionView];
  _inkTouchController.delegate = self;
}

- (void)viewWillLayoutSubviews {
  [super viewWillLayoutSubviews];

  // Add header/footer infoBars if editing is allowed.
  if ([self collectionViewAllowsEditing:self.collectionView]) {
    if (!_headerInfoBar) {
      _headerInfoBar =
          [[MDCCollectionInfoBarView alloc] initWithStyle:MDCInfoBarStyleHUD
                                                     kind:MDCInfoBarKindHeader
                                           collectionView:self.collectionView];
      _headerInfoBar.message = MDCCollectionStringResources(infoBarGestureHintString);
      _headerInfoBar.delegate = self;
      [self.view addSubview:_headerInfoBar];
    }

    if (!_footerInfoBar) {
      _footerInfoBar =
          [[MDCCollectionInfoBarView alloc] initWithStyle:MDCInfoBarStyleActionable
                                                     kind:MDCInfoBarKindFooter
                                           collectionView:self.collectionView];
      _footerInfoBar.message = MDCCollectionStringResources(deleteButtonString);
      _footerInfoBar.delegate = self;
      [self.view addSubview:_footerInfoBar];
    }
  }
}

- (void)setCollectionView:(__kindof UICollectionView *)collectionView {
  [super setCollectionView:collectionView];

  // Reset editor and ink to provided collection view.
  _editor = [[MDCCollectionViewEditor alloc] initWithCollectionView:collectionView];
  _editor.delegate = self;
  _inkTouchController = [[MDCInkTouchController alloc] initWithView:collectionView];
  _inkTouchController.delegate = self;
}

#pragma mark - <MDCCollectionInfoBarViewDelegate>

- (void)didTapInfoBar:(MDCCollectionInfoBarView *)infoBar {
  if ([infoBar isEqual:_footerInfoBar]) {
    [self deleteIndexPaths:self.collectionView.indexPathsForSelectedItems];
  }
}

- (BOOL)infoBar:(MDCCollectionInfoBarView *)infoBar shouldShowAnimated:(BOOL)animated {
  // Show the header HUD infoBar only once if editing and SwipeToDismiss allowed.
  if (infoBar.kind == MDCInfoBarKindHeader && infoBar.style == MDCInfoBarStyleHUD) {
    BOOL allowsSwipeToDismissItem = NO;
    if ([self respondsToSelector:@selector(collectionViewAllowsSwipeToDismissItem:)]) {
      allowsSwipeToDismissItem = [self collectionViewAllowsSwipeToDismissItem:self.collectionView];
    }
    return (_editor.isEditing
            && allowsSwipeToDismissItem
            && !_headerInfoBar.isVisible
            && !_headerInfoBarDismissed);
  }

  // Show the footer Actionable infoBar only if editing and items selected for deletion.
  if (infoBar.kind == MDCInfoBarKindFooter && infoBar.style == MDCInfoBarStyleActionable) {
    NSInteger selectedItemCount = [self.collectionView.indexPathsForSelectedItems count];
    return (_editor.isEditing
            && selectedItemCount > 0
            && !_footerInfoBar.isVisible);
  }

  return NO;
}

- (void)infoBar:(MDCCollectionInfoBarView *)infoBar
    willShowAnimated:(BOOL)animated
     willAutoDismiss:(BOOL)willAutoDismiss {
  if (infoBar.kind == MDCInfoBarKindFooter) {
    [self updateContentWithBottomInset:CGRectGetHeight(infoBar.bounds)];
  }
}

- (void)infoBar:(MDCCollectionInfoBarView *)infoBar
    willDismissAnimated:(BOOL)animated
        willAutoDismiss:(BOOL)willAutoDismiss {
  if (infoBar.kind == MDCInfoBarKindHeader) {
    _headerInfoBarDismissed = willAutoDismiss;
  }
}

- (void)infoBar:(MDCCollectionInfoBarView *)infoBar
    didDismissAnimated:(BOOL)animated
        didAutoDismiss:(BOOL)didAutoDismiss {
  if (infoBar.kind == MDCInfoBarKindFooter) {
    [self updateContentWithBottomInset:-CGRectGetHeight(infoBar.bounds)];
  }
}


- (void)updateContentWithBottomInset:(CGFloat)inset {
  // Update bottom inset to account for footer info bar.
  UIEdgeInsets contentInset = self.collectionView.contentInset;
  contentInset.bottom += inset;
  [UIView animateWithDuration:MDCCollectionInfoBarAnimationDuration
                   animations:^{
                     self.collectionView.contentInset = contentInset;
                   }];
}


#pragma mark - <MDCCollectionViewStylingDelegate>

- (MDCCollectionViewCellStyle)collectionView:(UICollectionView *)collectionView
                         cellStyleForSection:(NSInteger)section {
  return _styler.cellStyle;
}

#pragma mark - <UICollectionViewDelegateFlowLayout>

- (CGSize)collectionView:(UICollectionView *)collectionView
                    layout:(UICollectionViewLayout *)collectionViewLayout
    sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  UICollectionViewLayoutAttributes *attr =
      [collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
  CGSize size = [self sizeWithAttribute:attr];
  size = [self inlaidSizeAtIndexPath:indexPath withSize:size];
  return size;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section {
  return [self insetsAtSectionIndex:section];
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                                 layout:(UICollectionViewLayout *)collectionViewLayout
    minimumLineSpacingForSectionAtIndex:(NSInteger)section {
  if ([collectionViewLayout isKindOfClass:[UICollectionViewFlowLayout class]]) {
    if (_styler.cellLayoutType == MDCCollectionViewCellLayoutTypeGrid) {
      return _styler.gridPadding;
    }
    return [(UICollectionViewFlowLayout *)collectionViewLayout minimumLineSpacing];
  }
  return 0;
}

- (CGSize)sizeWithAttribute:(UICollectionViewLayoutAttributes *)attr {
  CGFloat height = MDCCellDefaultOneLineHeight;
  if ([_styler.delegate respondsToSelector:@selector(collectionView:cellHeightAtIndexPath:)]) {
    height =
        [_styler.delegate collectionView:self.collectionView cellHeightAtIndexPath:attr.indexPath];
  }

  CGFloat width = [self cellWidthAtSectionIndex:attr.indexPath.section];
  return CGSizeMake(width, height);
}

- (CGFloat)cellWidthAtSectionIndex:(NSInteger)section {
  CGFloat bounds = CGRectGetWidth(
      UIEdgeInsetsInsetRect(self.collectionView.bounds, self.collectionView.contentInset));
  UIEdgeInsets sectionInsets = [self insetsAtSectionIndex:section];
  CGFloat insets = sectionInsets.left + sectionInsets.right;
  if (_styler.cellLayoutType == MDCCollectionViewCellLayoutTypeGrid) {
    CGFloat cellWidth = bounds - insets - (_styler.gridPadding * (_styler.gridColumnCount - 1));
    return cellWidth / _styler.gridColumnCount;
  }
  return bounds - insets;
}

- (UIEdgeInsets)insetsAtSectionIndex:(NSInteger)section {
  // Determine insets based on cell style.
  CGFloat inset = (CGFloat)floor(MDCCollectionViewCellStyleCardSectionInset);
  UIEdgeInsets insets = UIEdgeInsetsZero;
  NSInteger numberOfSections = self.collectionView.numberOfSections;
  BOOL isTop = (section == 0);
  BOOL isBottom = (section == numberOfSections - 1);
  MDCCollectionViewCellStyle cellStyle = [_styler cellStyleAtSectionIndex:section];
  BOOL isCardStyle = cellStyle == MDCCollectionViewCellStyleCard;
  BOOL isGroupedStyle = cellStyle == MDCCollectionViewCellStyleGrouped;
  // Set left/right insets.
  if (isCardStyle) {
    insets.left = inset;
    insets.right = inset;
  }
  // Set top/bottom insets.
  if (isCardStyle || isGroupedStyle) {
    insets.top = (CGFloat)floor((isTop) ? inset : inset / 2.0f);
    insets.bottom = (CGFloat)floor((isBottom) ? inset : inset / 2.0f);
  }
  return insets;
}

- (CGSize)inlaidSizeAtIndexPath:(NSIndexPath *)indexPath withSize:(CGSize)size {
  // If object is inlaid, return its adjusted size.
  UICollectionView *collectionView = self.collectionView;
  if ([_styler isItemInlaidAtIndexPath:indexPath]) {
    CGFloat inset = MDCCollectionViewCellStyleCardSectionInset;
    UIEdgeInsets inlayInsets = UIEdgeInsetsZero;
    BOOL prevCellIsInlaid = NO;
    BOOL nextCellIsInlaid = NO;

    BOOL hasSectionHeader = NO;
    if ([self
            respondsToSelector:@selector(collectionView:layout:referenceSizeForHeaderInSection:)]) {
      CGSize headerSize = [self collectionView:collectionView
                                        layout:_collectionViewLayout
               referenceSizeForHeaderInSection:indexPath.section];
      hasSectionHeader = !CGSizeEqualToSize(headerSize, CGSizeZero);
    }

    BOOL hasSectionFooter = NO;
    if ([self
            respondsToSelector:@selector(collectionView:layout:referenceSizeForFooterInSection:)]) {
      CGSize footerSize = [self collectionView:collectionView
                                        layout:_collectionViewLayout
               referenceSizeForFooterInSection:indexPath.section];
      hasSectionFooter = !CGSizeEqualToSize(footerSize, CGSizeZero);
    }

    // Check if previous cell is inlaid.
    if (indexPath.item > 0 || hasSectionHeader) {
      NSIndexPath *prevIndexPath =
          [NSIndexPath indexPathForItem:(indexPath.item - 1) inSection:indexPath.section];
      prevCellIsInlaid = [_styler isItemInlaidAtIndexPath:prevIndexPath];
      inlayInsets.top = prevCellIsInlaid ? inset / 2 : inset;
    }

    // Check if next cell is inlaid.
    if (indexPath.item < [collectionView numberOfItemsInSection:indexPath.section] - 1 ||
        hasSectionFooter) {
      NSIndexPath *nextIndexPath =
          [NSIndexPath indexPathForItem:(indexPath.item + 1) inSection:indexPath.section];
      nextCellIsInlaid = [_styler isItemInlaidAtIndexPath:nextIndexPath];
      inlayInsets.bottom = nextCellIsInlaid ? inset / 2 : inset;
    }

    // Apply top/bottom height adjustments to inlaid object.
    size.height += inlayInsets.top + inlayInsets.bottom;
  }
  return size;
}

#pragma mark - <MDCInkTouchControllerDelegate>

- (BOOL)inkTouchController:(MDCInkTouchController *)inkTouchController
    shouldProcessInkTouchesAtTouchLocation:(CGPoint)location {
  // Only store touch location and do not allow ink processing. This ink location will be used when
  // manually starting/stopping the ink animation during cell highlight/unhighlight states.
  if (!self.currentlyActiveInk) {
    _inkTouchLocation = location;
  }
  return NO;
}

- (MDCInkView *)inkTouchController:(MDCInkTouchController *)inkTouchController
            inkViewAtTouchLocation:(CGPoint)location {
  NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
  UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
  MDCInkView *ink = nil;

  if ([_styler.delegate
          respondsToSelector:@selector(collectionView:inkTouchController:inkViewAtIndexPath:)]) {
    return [_styler.delegate collectionView:self.collectionView
                         inkTouchController:inkTouchController
                         inkViewAtIndexPath:indexPath];
  }
  if ([cell isKindOfClass:[MDCCollectionViewCell class]]) {
    MDCCollectionViewCell *inkCell = (MDCCollectionViewCell *)cell;
    if ([inkCell respondsToSelector:@selector(inkView)]) {
      // Set cell ink.
      ink = [cell performSelector:@selector(inkView)];
    }
  }

  return ink;
}

#pragma mark - <UICollectionViewDelegate>

- (BOOL)collectionView:(UICollectionView *)collectionView
    shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
  if ([_styler.delegate respondsToSelector:@selector(collectionView:hidesInkViewAtIndexPath:)]) {
    return ![_styler.delegate collectionView:collectionView hidesInkViewAtIndexPath:indexPath];
  }
  return YES;
}

- (void)collectionView:(UICollectionView *)collectionView
    didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
  UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
  CGPoint location = [collectionView convertPoint:_inkTouchLocation toView:cell];

  // Start cell ink show animation.
  MDCInkView *inkView;
  if ([cell respondsToSelector:@selector(inkView)]) {
    inkView = [cell performSelector:@selector(inkView)];
  } else {
    return;
  }

  // Update ink color if necessary.
  if ([_styler.delegate respondsToSelector:@selector(collectionView:inkColorAtIndexPath:)]) {
    inkView.inkColor =
        [_styler.delegate collectionView:collectionView inkColorAtIndexPath:indexPath];
    if (!inkView.inkColor) {
      inkView.inkColor = inkView.defaultInkColor;
    }
  }
  self.currentlyActiveInk = YES;
  [inkView startTouchBeganAnimationAtPoint:location completion:nil];
}

- (void)collectionView:(UICollectionView *)collectionView
    didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
  UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
  CGPoint location = [collectionView convertPoint:_inkTouchLocation toView:cell];

  // Start cell ink evaporate animation.
  MDCInkView *inkView;
  if ([cell respondsToSelector:@selector(inkView)]) {
    inkView = [cell performSelector:@selector(inkView)];
  } else {
    return;
  }

  self.currentlyActiveInk = NO;
  [inkView startTouchEndedAnimationAtPoint:location completion:nil];
}

- (BOOL)collectionView:(UICollectionView *)collectionView
    shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  if (_editor.isEditing) {
    if ([self collectionView:collectionView canEditItemAtIndexPath:indexPath]) {
      return [self collectionView:collectionView canSelectItemDuringEditingAtIndexPath:indexPath];
    }
    return NO;
  }
  return YES;
}

- (BOOL)collectionView:(UICollectionView *)collectionView
    shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
  return collectionView.allowsMultipleSelection;
}

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  [_footerInfoBar showAnimated:YES];
}

- (void)collectionView:(UICollectionView *)collectionView
    didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
  [_footerInfoBar dismissAnimated:YES];
}

#pragma mark - <MDCCollectionViewEditingDelegate>

- (BOOL)collectionViewAllowsEditing:(UICollectionView *)collectionView {
  return NO;
}

- (void)collectionViewWillBeginEditing:(UICollectionView *)collectionView {
  if (self.currentlyActiveInk) {
    MDCInkView *activeInkView =
        [self inkTouchController:_inkTouchController inkViewAtTouchLocation:_inkTouchLocation];
    [activeInkView startTouchEndedAnimationAtPoint:_inkTouchLocation completion:nil];
  }
  // Inlay all items and show header infoBar if applicable.
  _styler.allowsItemInlay = YES;
  _styler.allowsMultipleItemInlays = YES;
  [_styler applyInlayToAllItemsAnimated:YES];
  [_headerInfoBar showAnimated:YES];
}

- (void)collectionViewWillEndEditing:(UICollectionView *)collectionView {
  // Remove inlay of all items and hide footer infoBar if applicable.
  [_styler removeInlayFromAllItemsAnimated:YES];
  [_footerInfoBar dismissAnimated:YES];
}

- (BOOL)collectionView:(UICollectionView *)collectionView
    canEditItemAtIndexPath:(NSIndexPath *)indexPath {
  return [self collectionViewAllowsEditing:collectionView];
}

- (BOOL)collectionView:(UICollectionView *)collectionView
    canSelectItemDuringEditingAtIndexPath:(NSIndexPath *)indexPath {
  if ([self collectionViewAllowsEditing:collectionView]) {
    return [self collectionView:collectionView canEditItemAtIndexPath:indexPath];
  }
  return NO;
}

#pragma mark - Item Moving

- (BOOL)collectionViewAllowsReordering:(UICollectionView *)collectionView {
  return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView
    canMoveItemAtIndexPath:(NSIndexPath *)indexPath {
  return ([self collectionViewAllowsEditing:collectionView] &&
          [self collectionViewAllowsReordering:collectionView]);
}

- (BOOL)collectionView:(UICollectionView *)collectionView
    canMoveItemAtIndexPath:(NSIndexPath *)indexPath
               toIndexPath:(NSIndexPath *)newIndexPath {
  // First ensure both source and target items can be moved.
  return ([self collectionView:collectionView canMoveItemAtIndexPath:indexPath] &&
          [self collectionView:collectionView canMoveItemAtIndexPath:newIndexPath]);
}

- (void)collectionView:(UICollectionView *)collectionView
    didMoveItemAtIndexPath:(NSIndexPath *)indexPath
               toIndexPath:(NSIndexPath *)newIndexPath {
  [collectionView moveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
}

#pragma mark - Swipe-To-Dismiss-Items

- (BOOL)collectionViewAllowsSwipeToDismissItem:(UICollectionView *)collectionView {
  return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView
    canSwipeToDismissItemAtIndexPath:(NSIndexPath *)indexPath {
  return [self collectionViewAllowsSwipeToDismissItem:collectionView];
}

- (void)collectionView:(UICollectionView *)collectionView
    didEndSwipeToDismissItemAtIndexPath:(NSIndexPath *)indexPath {
  [self deleteIndexPaths:@[ indexPath ]];
}

#pragma mark - Swipe-To-Dismiss-Sections

- (BOOL)collectionViewAllowsSwipeToDismissSection:(UICollectionView *)collectionView {
  return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView
    canSwipeToDismissSection:(NSInteger)section {
  return [self collectionViewAllowsSwipeToDismissSection:collectionView];
}

- (void)collectionView:(UICollectionView *)collectionView
    didEndSwipeToDismissSection:(NSInteger)section {
  [self deleteSections:[NSIndexSet indexSetWithIndex:section]];
}

#pragma mark - Private

- (void)deleteIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
  if ([self respondsToSelector:@selector(collectionView:willDeleteItemsAtIndexPaths:)]) {
    void (^batchUpdates)() = ^{
      // Notify delegate to delete data.
      [self collectionView:self.collectionView willDeleteItemsAtIndexPaths:indexPaths];

      // Delete index paths.
      [self.collectionView deleteItemsAtIndexPaths:indexPaths];
    };

    void (^completionBlock)(BOOL finished) = ^(BOOL finished) {
      [_footerInfoBar dismissAnimated:YES];

      // Notify delegate of deletion.
      if ([self respondsToSelector:@selector(collectionView:didDeleteItemsAtIndexPaths:)]) {
        [self collectionView:self.collectionView didDeleteItemsAtIndexPaths:indexPaths];
      }
    };

    // Animate deletion.
    [self.collectionView performBatchUpdates:batchUpdates completion:completionBlock];
  }
}

- (void)deleteSections:(NSIndexSet *)sections {
  if ([self respondsToSelector:@selector(collectionView:willDeleteSections:)]) {
    void (^batchUpdates)() = ^{
      // Notify delegate to delete data.
      [self collectionView:self.collectionView willDeleteSections:sections];

      // Delete sections.
      [self.collectionView deleteSections:sections];
    };

    void (^completionBlock)(BOOL finished) = ^(BOOL finished) {
      [_footerInfoBar dismissAnimated:YES];

      // Notify delegate of deletion.
      if ([self respondsToSelector:@selector(collectionView:didDeleteSections:)]) {
        [self collectionView:self.collectionView didDeleteSections:sections];
      }
    };

    // Animate deletion.
    [self.collectionView performBatchUpdates:batchUpdates completion:completionBlock];
  }
}

@end
