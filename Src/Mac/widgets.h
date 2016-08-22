#include <Python.h>
#include <Cocoa/Cocoa.h>


typedef struct {
    PyObject_HEAD
    NSView* view;
} WidgetObject;

extern PyTypeObject WidgetType;
extern PyTypeObject LabelType;
extern PyTypeObject ButtonType;
extern PyTypeObject GridType;
