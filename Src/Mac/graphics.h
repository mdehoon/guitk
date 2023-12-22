#include <Python.h>
#include <CoreGraphics/CGContext.h>

typedef struct {
    PyObject_HEAD
    CGContextRef cr;
} GraphicsContext;

extern PyTypeObject GraphicsContextType;
