#include <Python.h>
#include <Cocoa/Cocoa.h>
#include "graphics.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10100
#define COMPILING_FOR_10_10
#endif


void PyTk_Fill3DRectangle(GraphicsContext* gc, int width, int height)
{
    CGRect rect;
    CGContextRef cr = gc->cr;
    rect.origin.x = 0;
    rect.origin.y = 0;
    rect.size.width = width;
    rect.size.height = height;
    CGContextSetRGBFillColor(cr, 1.0, 0.0, 1.0, 1.0);
    CGContextFillRect(cr, rect);
    printf("In PyTk_Fill3DRectangle for CGContextRef %p\n", cr);
}

static PyObject*
GraphicsContext_repr(GraphicsContext* self)
{
    return PyUnicode_FromFormat("GraphicsContext object %p for native graphics context %p", self, self->cr);
}

static PyMethodDef GraphicsContext_methods[] = {
    {NULL}  /* Sentinel */
};

static PyGetSetDef GraphicsContext_getseters[] = {
    {NULL}  /* Sentinel */
};

static char GraphicsContext_doc[] = "GraphicsContext object.\n";

PyTypeObject GraphicsContextType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.GraphicsContext",   /* tp_name */
    sizeof(GraphicsContext),    /* tp_basicsize */
    0,                          /* tp_itemsize */
    0,                          /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)GraphicsContext_repr,       /* tp_repr */
    0,                          /* tp_as_number */
    0,                          /* tp_as_sequence */
    0,                          /* tp_as_mapping */
    0,                          /* tp_hash */
    0,                          /* tp_call */
    0,                          /* tp_str */
    0,                          /* tp_getattro */
    0,                          /* tp_setattro */
    0,                          /* tp_as_buffer */
    Py_TPFLAGS_HAVE_CLASS,      /* tp_flags */
    GraphicsContext_doc,        /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    GraphicsContext_methods,    /* tp_methods */
    0,                          /* tp_members */
    GraphicsContext_getseters,  /* tp_getset */
};
