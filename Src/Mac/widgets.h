#include <Python.h>
#include <Cocoa/Cocoa.h>

@class WidgetView;

typedef struct WidgetObject {
    PyObject_HEAD
    WidgetView* view;
    CGSize minimum_size;
    char halign;
    char valign;
    BOOL hexpand;
    BOOL vexpand;
    double margin_left;
    double margin_right;
    double margin_top;
    double margin_bottom;
} WidgetObject;

@interface WidgetView : NSView
{
@public
    WidgetObject* object;
}
- (BOOL)isFlipped;
@end

extern PyTypeObject WidgetType;
extern PyTypeObject LayoutType;
extern PyTypeObject FontType;
extern PyTypeObject SystemFontType;
extern PyTypeObject FrameType;
extern PyTypeObject SeparatorType;
extern PyTypeObject LabelType;
extern PyTypeObject ButtonType;
extern PyTypeObject CheckboxType;
extern PyTypeObject TextboxType;
extern PyTypeObject ListboxType;

void Widget_unset_minimum_size(WidgetObject* self);
PyObject* Widget_get_minimum_size(WidgetObject* self, void* closure);
