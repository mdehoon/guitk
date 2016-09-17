#include <Python.h>
#include <Cocoa/Cocoa.h>

typedef struct {
    PyObject_HEAD
    NSView* view;
    char halign;
    char valign;
    BOOL hexpand;
    BOOL vexpand;
} WidgetObject;

extern PyTypeObject WidgetType;
extern PyTypeObject LayoutType;
extern PyTypeObject FrameType;
extern PyTypeObject SeparatorType;
extern PyTypeObject LabelType;
extern PyTypeObject ButtonType;
extern PyTypeObject CheckboxType;
extern PyTypeObject TextboxType;
