#include <Python.h>
#include <X11/Xlib.h>
#include "graphics.h"


void PyTk_Fill3DRectangle(GraphicsContext* context, int width, int height)
{
    Display* display = NULL;
    Drawable d = 0;
    GC gc = NULL;
    int x = 0;
    int y = 0;
    // CGContextSetRGBFillColor(cr, 1.0, 0.0, 1.0, 1.0);
    XFillRectangle(display, d, gc, x, y, width, height);
}

static PyObject*
GraphicsContext_repr(GraphicsContext* self)
{
    return PyUnicode_FromFormat("GraphicsContext object %p for window %lu", self, self->window);
}


static PyObject*
GraphicsContext_draw_message(GraphicsContext* self, PyObject *args, PyObject *keywords)
{
    const char* message;
    static char* kwlist[] = {"message", NULL};
    Display* display = self->display;
    Window window = self->window;
    GC gc = self->gc;
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "s", kwlist, &message))
        return NULL;
    XClearWindow(display, window);
    XFillRectangle(display, window, gc, 20, 20, 10, 10);
    XDrawString(display, window, gc, 10, 50, message, strlen(message));
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef GraphicsContext_methods[] = {
    {"draw_message",
     (PyCFunction)GraphicsContext_draw_message,
     METH_KEYWORDS | METH_VARARGS,
     "Draws hello world."
    },
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
    Py_TPFLAGS_DEFAULT,         /* tp_flags */
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
