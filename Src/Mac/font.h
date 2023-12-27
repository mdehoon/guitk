#include <Cocoa/Cocoa.h>
#include <Python.h>

typedef struct {
    PyObject_HEAD
    CTFontRef font;
} FontObject;

extern PyTypeObject FontType;
