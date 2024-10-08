#include <Cocoa/Cocoa.h>
#include <Python.h>

typedef struct {
    PyObject_HEAD
    NSImage* image;
    Py_ssize_t width;
    Py_ssize_t height;
} ImageObject;

extern PyTypeObject ImageType;

PyObject* _pbm_new(PyTypeObject *type, PyObject *args, PyObject *keywords);
