/*
 * Copyright (c) 2012 Mario Negro Martín
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
 */

#import "MNMBottomPullToRefreshManager.h"
#import "MNMBottomPullToRefreshView.h"

CGFloat const kAnimationDuration = 0.2f;

@interface MNMBottomPullToRefreshManager()

/*
 * Pull-to-refresh view
 */
@property (nonatomic, readwrite, strong) MNMBottomPullToRefreshView *pullToRefreshView;

/*
 * Table view which p-t-r view will be added
 */
@property (nonatomic, readwrite, weak) UITableView *table;

/*
 * Client object that observes changes
 */
@property (nonatomic, readwrite, weak) id<MNMBottomPullToRefreshManagerClient> client;


@property (nonatomic) BOOL hideAnimationInProgress;

/*
 * Returns the correct offset to apply to the pull-to-refresh view, depending on contentSize
 *
 * @return The offset
 * @private
 */
- (CGFloat)tableScrollOffset;

@end

@implementation MNMBottomPullToRefreshManager

@synthesize pullToRefreshView = pullToRefreshView_;
@synthesize table = table_;
@synthesize client = client_;

#pragma mark -
#pragma mark Instance initialization

/*
 * Initializes the manager object with the information to link view and table
 */
- (id)initWithPullToRefreshViewHeight:(CGFloat)height tableView:(UITableView *)table withClient:(id<MNMBottomPullToRefreshManagerClient>)client {

    if (self = [super init]) {
		 _hideAnimationInProgress = NO;
        client_ = client;
        table_ = table;        
        pullToRefreshView_ = [[MNMBottomPullToRefreshView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, CGRectGetWidth([table_ frame]), height)];
    }
    
    return self;
}

#pragma mark -
#pragma mark Visuals

/*
 * Returns the correct offset to apply to the pull-to-refresh view, depending on contentSize
 */
- (CGFloat)tableScrollOffset {
    
    CGFloat offset = 0.0f;        
    
    if ([table_ contentSize].height < CGRectGetHeight([table_ frame])) {
        
        offset = -[table_ contentOffset].y;
        
    } else {
        
        offset = ([table_ contentSize].height - [table_ contentOffset].y) - CGRectGetHeight([table_ frame]);
    }
    
    return offset;
}

/*
 * Relocate pull-to-refresh view
 */
- (void)relocatePullToRefreshView {
    
    CGFloat yOrigin = 0.0f;
    
    if ([table_ contentSize].height >= CGRectGetHeight([table_ frame])) {
        
        yOrigin = [table_ contentSize].height;
        
    } else {
        
        yOrigin = CGRectGetHeight([table_ frame]);
    }
    
    CGRect frame = [pullToRefreshView_ frame];
    frame.origin.y = yOrigin;
    [pullToRefreshView_ setFrame:frame];
    
    [table_ addSubview:pullToRefreshView_];
}

/*
 * Sets the pull-to-refresh view visible or not. Visible by default
 */
- (void)setPullToRefreshViewVisible:(BOOL)visible {
    
    [pullToRefreshView_ setHidden:!visible];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == table_ && [keyPath isEqualToString:@"contentOffset"])
	{
		NSValue* oldValue = [change objectForKey:NSKeyValueChangeOldKey];
		NSValue* newValue = [change objectForKey:NSKeyValueChangeNewKey];
		
		CGFloat diff = [oldValue CGPointValue].y - [newValue CGPointValue].y;
		CGPoint refreshViewCenter = pullToRefreshView_.center;
		refreshViewCenter.y -= diff;
		pullToRefreshView_.center = refreshViewCenter;
	}
}

#pragma mark -
#pragma mark Table view scroll management

/*
 * Checks state of control depending on tableView scroll offset
 */
- (void)tableViewScrolled {
    
    if (![pullToRefreshView_ isHidden] && ![pullToRefreshView_ isLoading]) {
        
        CGFloat offset = [self tableScrollOffset];

        if (offset >= 0.0f) {
            
            [pullToRefreshView_ changeStateOfControl:MNMBottomPullToRefreshViewStateIdle offset:offset];
            
        } else if (offset <= 0.0f && offset >= -[pullToRefreshView_ fixedHeight]) {
                
            [pullToRefreshView_ changeStateOfControl:MNMBottomPullToRefreshViewStatePull offset:offset];
            
        } else {
            
            [pullToRefreshView_ changeStateOfControl:MNMBottomPullToRefreshViewStateRelease offset:offset];
        }
    }
}

/*
 * Checks releasing of the tableView
 */
- (void)tableViewReleased {
    
    if (![pullToRefreshView_ isHidden] && ![pullToRefreshView_ isLoading]) {
        
        CGFloat offset = [self tableScrollOffset];
        CGFloat height = -[pullToRefreshView_ fixedHeight];
        
        if (offset <= 0.0f && offset < height) {
            
            [client_ bottomPullToRefreshTriggered:self];
            
            [pullToRefreshView_ changeStateOfControl:MNMBottomPullToRefreshViewStateLoading offset:offset];
            
            [UIView animateWithDuration:kAnimationDuration animations:^{
                
                if ([self->table_ contentSize].height >= CGRectGetHeight([self->table_ frame])) {
                
                    [self->table_ setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, -height, 0.0f)];
                    
                } else {
                    
                    [self->table_ setContentInset:UIEdgeInsetsMake(height, 0.0f, 0.0f, 0.0f)];
                }
            }];
        }
    }
}

/*
 * The reload of the table is completed
 */
- (void)tableViewReloadFinished {
	if (!_hideAnimationInProgress)
	{
		[self relocatePullToRefreshView];
	}
}


- (void)tableViewFinishedLoadData
{
	if (!UIEdgeInsetsEqualToEdgeInsets(table_.contentInset, UIEdgeInsetsZero))
	{
		[pullToRefreshView_ changeStateOfControl:MNMBottomPullToRefreshViewStateIdle offset:CGFLOAT_MAX];
		[UIView animateWithDuration:0.3
							  animations:^{
            self->_hideAnimationInProgress = YES;
            [self->table_ setContentInset:UIEdgeInsetsZero];
            [self->table_ addObserver:self forKeyPath:@"contentOffset" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
							  } completion:^(BOOL finished) {
                                  [self->table_ removeObserver:self forKeyPath:@"contentOffset"];
                                  self->_hideAnimationInProgress = NO;
								  [self relocatePullToRefreshView];
							  }];
	}
}

#pragma mark -
#pragma mark properties
- (void)setPullText:(NSString *)pullText {
    pullToRefreshView_.pullText = pullText;
}

- (void)setReleaseText:(NSString *)releaseText {
    pullToRefreshView_.releaseText = releaseText;
}

- (void)setLoadingText:(NSString *)loadingText {
    pullToRefreshView_.loadingText = loadingText;
}

-(void)setCustomBackgroundColor:(UIColor *)customBackgroundColor{
    pullToRefreshView_.customBackgroundColor = customBackgroundColor;
}

- (NSString *)pullText {
    return pullToRefreshView_.pullText;
}

- (NSString *)releaseText {
    return pullToRefreshView_.releaseText;
}

- (NSString *)loadingText {
    return pullToRefreshView_.loadingText;
}

- (UIColor *)customBackgroundColor {
    return pullToRefreshView_.customBackgroundColor;
}

@end
