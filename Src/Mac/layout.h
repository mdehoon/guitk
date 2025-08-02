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

Py_LOCAL_SYMBOL void Layout_update(WidgetObject* object);
Py_LOCAL_SYMBOL void Layout_request(WidgetObject* object);
Py_LOCAL_SYMBOL void Layout_notify_window_resized(WidgetObject* object);
