#include "widgets.h"
#include "colors.h"

typedef struct {
    WidgetObject widget;
    ColorObject* background;
    int status;
} LayoutObject;

@interface LayoutView : WidgetView
- (void)didAddSubview:(NSView *)subview;
- (void)willRemoveSubview:(NSView *)subview;
- (void)drawRect:(NSRect)rect;
@end

Py_LOCAL_SYMBOL void Layout_perform_layout_in_subtree(WidgetObject* object);
Py_LOCAL_SYMBOL void Layout_invalidate_layout(WidgetObject* object);
