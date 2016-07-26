#include <Cocoa/Cocoa.h>
#include <Python.h>

typedef struct {
    PyObject_HEAD
    NSImage* image;
} ImageObject;

extern PyTypeObject ImageType;
