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
extern PyTypeObject LabelType;
extern PyTypeObject ButtonType;
