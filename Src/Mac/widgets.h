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
} WidgetObject;

@interface WidgetView : NSView
{
@public
    WidgetObject* object;
}
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
