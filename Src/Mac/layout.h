#include "widgets.h"
#include "colors.h"


typedef enum {COREGUI_LAYOUT_VALID,
              COREGUI_LAYOUT_INVALID,
              COREGUI_LAYOUT_CHILDREN_INVALID} LayoutStatus;


typedef struct {
    WidgetObject widget;
    ColorObject* background;
    LayoutStatus status;
} LayoutObject;

Py_LOCAL_SYMBOL void Layout_update(WidgetObject* object);
Py_LOCAL_SYMBOL void Layout_request(WidgetObject* object);
Py_LOCAL_SYMBOL void Layout_notify_window_resized(WidgetObject* object);
