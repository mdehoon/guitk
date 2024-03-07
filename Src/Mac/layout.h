#include "colors.h"

typedef struct {
    WidgetObject widget;
    ColorObject* background;
} LayoutObject;

@interface LayoutView : WidgetView
@property BOOL layout_requested;
- (LayoutView*)initWithFrame:(NSRect)rect;
- (BOOL)isFlipped;
- (void)viewWillDraw;
- (void)didAddSubview:(NSView *)subview;
- (void)willRemoveSubview:(NSView *)subview;
- (void)setFrameSize:(NSSize)newSize;
- (void)drawRect:(NSRect)rect;
@end
