#include <Python.h>
#include <X11/Xlib.h>

extern PyTypeObject WindowType;

typedef struct {
    PyObject_HEAD
    Window window;
    PyObject* content;
    Bool layout_requested;
} WindowObject;
