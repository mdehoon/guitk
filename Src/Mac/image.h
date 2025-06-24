#include <Cocoa/Cocoa.h>
#include <Python.h>

typedef struct {
    PyObject_HEAD
    Py_buffer data;
} ImageObject;

extern PyTypeObject ImageType;
