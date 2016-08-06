#include <Python.h>
#include <Cocoa/Cocoa.h>
#include "widgets.h"

#if PY_MAJOR_VERSION >= 3
#define PY3K 1
#else
#if PY_MINOR_VERSION < 7
#error Python version should be 2.7 or newer
#else
#define PY3K 0
#endif
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
#define COMPILING_FOR_10_6
#endif
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
#define COMPILING_FOR_10_7
#endif

#ifndef CGFloat
#define CGFloat float
#endif

@interface WidgetView : NSView <Widget>
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (WidgetView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object;
- (BOOL)isFlipped;
@end

@implementation WidgetView

@synthesize object = _object;

- (WidgetView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object
{
    self = [super initWithFrame: rect];
    _object = object;
    return self;
}


- (BOOL)isFlipped
{
    return YES;
}
@end

static PyObject*
Widget_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    WidgetObject *self = (WidgetObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->view = NULL;
    return (PyObject*)self;
}

static PyObject*
Widget_repr(WidgetObject* self)
{
    NSView* view = self->view;
#if PY3K
    return PyUnicode_FromFormat("Widget object %p wrapping NSView %p",
                               self, view);
#else
    return PyString_FromFormat("Widget object %p wrapping NSView %p",
                                self, view);
#endif
}

static void
Widget_dealloc(WidgetObject* self)
{
    NSView* view = self->view;
    if (view) [view release];
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Widget_resize(WidgetObject* self, PyObject *args, PyObject *keywords)

{
    PyErr_SetString(PyExc_RuntimeError,
                    "derived class should implement resize");
    return NULL;
}

static PyMethodDef Widget_methods[] = {
    {"resize",
     (PyCFunction)Widget_resize,
     METH_KEYWORDS | METH_VARARGS,
     "Resizes the widget."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Widget_get_origin(WidgetObject* self, void* closure)
{
    CGFloat x;
    CGFloat y;
    NSView* view = self->view;
    NSRect frame = view.frame;
    x = NSMinX(frame);
    y = NSMinY(frame);
    return Py_BuildValue("ii", (int) round(x), (int) round(y));
}

static int Widget_set_origin(WidgetObject* self, PyObject* value, void* closure)
{
    int x;
    int y;
    NSPoint point;
    NSView* view = self->view;
    NSWindow* window = [view window];
    if (!PyArg_ParseTuple(value, "ii", &x, &y)) return -1;
    if (view == [window contentView])
    {
        PyErr_SetString(PyExc_RuntimeError, "Top widget cannot be moved.");
        return -1;
    }
    point.x = x;
    point.y = y;
    [view setFrameOrigin: point];
    return 0;
}

static char Widget_origin__doc__[] = "position of the top-left corner of the widget";

static PyObject* Widget_get_size(WidgetObject* self, void* closure)
{
    int width;
    int height;
    NSRect frame;
    NSView* view = self->view;
    frame = [view frame];
    width = round(frame.size.width);
    height = round(frame.size.height);
    return Py_BuildValue("ii", width, height);
}

static int Widget_set_size(WidgetObject* self, PyObject* value, void* closure)
{
    int width;
    int height;
    NSSize size;
    NSView* view = self->view;
    NSWindow* window = [view window];
    if (!PyArg_ParseTuple(value, "ii", &width, &height)) return -1;
    if (view == [window contentView])
    {
        PyErr_SetString(PyExc_RuntimeError, "Top widget cannot be resized.");
        return -1;
    }
    size.width = width;
    size.height = height;
    [view setFrameSize: size];
    return 0;
}

static char Widget_size__doc__[] = "Widget size";

static PyGetSetDef Widget_getset[] = {
    {"origin", (getter)Widget_get_origin, (setter)Widget_set_origin, Widget_origin__doc__, NULL},
    {"size", (getter)Widget_get_size, (setter)Widget_set_size, Widget_size__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Widget_doc[] =
"Widget is the base class for objects wrapping a Cocoa NSView.\n";

PyTypeObject WidgetType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "gui.Widget",               /* tp_name */
    sizeof(WidgetObject),       /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Widget_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Widget_repr,      /* tp_repr */
    0,                          /* tp_as_number */
    0,                          /* tp_as_sequence */
    0,                          /* tp_as_mapping */
    0,                          /* tp_hash */
    0,                          /* tp_call */
    0,                          /* tp_str */
    0,                          /* tp_getattro */
    0,                          /* tp_setattro */
    0,                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,        /* tp_flags */
    Widget_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Widget_methods,             /* tp_methods */
    0,                          /* tp_members */
    Widget_getset,              /* tp_getset */
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    0,                          /* tp_init */
    0,                          /* tp_alloc */
    Widget_new,                 /* tp_new */
};
