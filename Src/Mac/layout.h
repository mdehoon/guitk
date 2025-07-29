#include "colors.h"

typedef struct {
    WidgetObject widget;
    ColorObject* background;
} LayoutObject;

@interface LayoutView : WidgetView
- (LayoutView*)initWithFrame:(NSRect)rect;
- (BOOL)isFlipped;
- (void)didAddSubview:(NSView *)subview;
- (void)willRemoveSubview:(NSView *)subview;
- (void)setFrameSize:(NSSize)newSize;
- (void)drawRect:(NSRect)rect;
@end
