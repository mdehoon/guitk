#include <Python.h>
#include <Cocoa/Cocoa.h>

typedef struct {
    PyObject_HEAD
    NSView* view;
} Widget;

extern PyTypeObject GridItemType;
extern PyTypeObject GridType;

extern PyObject* widgets;

void initialize_widgets(void);
