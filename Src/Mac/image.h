#include <Cocoa/Cocoa.h>
#include <Python.h>

typedef struct {
    PyObject_HEAD
    CGImageRef data;
} ImageObject;

extern PyTypeObject ImageType;
