#include <Python.h>
#include <X11/Xlib.h>


typedef struct {
    PyObject_HEAD
    GC gc;
    Display* display;
    Window window;
} GraphicsContext;

extern PyTypeObject GraphicsContextType;
