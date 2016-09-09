#include <Python.h>
#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "window.h"

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

@interface LayoutView : NSView
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (LayoutView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object;
- (BOOL)isFlipped;
- (void)viewWillDraw;
@end

typedef struct {
    PyObject_HEAD
    LayoutView* view;
} LayoutObject;

PyTypeObject LayoutType;

@implementation LayoutView
@synthesize object = _object;

- (LayoutView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object
{
    self = [super initWithFrame: rect];
    _object = object;
    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)viewWillDraw
{
    Window* window = (Window*) [self window];
    WindowObject* object = window.object;
    if (object->layout_requested) {
        PyObject* result;
        PyGILState_STATE gstate = PyGILState_Ensure();
        result = PyObject_CallMethod(_object, "layout", NULL);
        if (result)
            Py_DECREF(result);
        else
            PyErr_Print();
        PyGILState_Release(gstate);
        object->layout_requested = NO;
    }
    /* Don't call [super viewWillDraw]; we only want the top view to receive
     * this notification.
     */
}
@end

static PyObject*
Layout_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    PyObject* object;
    NSRect rect = NSZeroRect;
    LayoutObject *self = (LayoutObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    object = (PyObject*)self;
    self->view = [[LayoutView alloc] initWithFrame:rect withObject:object];
    return object;
}

static PyObject*
Layout_repr(LayoutObject* self)
{
    NSView* view = self->view;
#if PY3K
    return PyUnicode_FromFormat("Layout object %p wrapping NSView %p",
                               self, view);
#else
    return PyString_FromFormat("Layout object %p wrapping NSView %p",
                                self, view);
#endif
}

static void
Layout_dealloc(WidgetObject* self)
{
    NSView* view = self->view;
    if (view) [view release];
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Layout_add(LayoutObject* self, PyObject *args)
{
    Window* window;
    NSView* view;
    WidgetObject* widget;
    LayoutView* layout = self->view;
    if (!layout) {
        PyErr_SetString(PyExc_RuntimeError, "layout has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "O!", &WidgetType, &widget))
        return NULL;

    view = widget->view;
    [layout addSubview: view];
    window = (Window*) [view window];
    [window requestLayout];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Layout_methods[] = {
    {"add",
     (PyCFunction)Layout_add,
     METH_VARARGS,
     "Adds a widget to the layout manager."
    },
    {NULL}  /* Sentinel */
};

static PyGetSetDef Layout_getset[] = {
    {NULL}  /* Sentinel */
};

static char Layout_doc[] =
"Layout is the base class for layout managers.\n";

PyTypeObject LayoutType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "gui.Layout",               /* tp_name */
    sizeof(LayoutObject),       /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Layout_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Layout_repr,      /* tp_repr */
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
    Layout_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Layout_methods,             /* tp_methods */
    0,                          /* tp_members */
    Layout_getset,              /* tp_getset */
    &WidgetType,                /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    0,                          /* tp_init */
    0,                          /* tp_alloc */
    Layout_new,                 /* tp_new */
};
