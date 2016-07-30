#include <Python.h>
#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "grid.h"

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

@implementation GridView
@synthesize object;

- (void)frameDidChange:(NSNotification *)notification {
    printf("Grid frame changed\n");
}
@end

static PyObject*
Grid_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    GridObject *self = (GridObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->view = NULL;
    return (PyObject*)self;
}

static int
Grid_init(GridObject *self, PyObject *args, PyObject *kwds)
{
    int nrows = 1;
    int ncols = 1;
    GridView* view;
    NSNotificationCenter* notificationCenter;
    if(!PyArg_ParseTuple(args, "|ii", &nrows, &ncols)) return -1;
    view = [[GridView alloc] initWithFrame: NSZeroRect];
    notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver: view
                           selector: @selector(frameDidChange:)
                               name: NSViewFrameDidChangeNotification 
                             object: view];
    self->view = view;
    self->nrows = nrows;
    self->ncols = ncols;
    
    return 0;
}

static PyObject*
Grid_repr(GridObject* self)
{
    GridView* view = self->view;
    unsigned int nrows = self->nrows;
    unsigned int ncols = self->ncols;
    const char message[] = "Grid object %p with grid (%u,%u) wrapping NSView %p of size %f, %f";
    NSRect rect = [view bounds];
    NSSize size = rect.size;
    printf("size = %g, %g\n", size.width, size.height);
#if PY3K
    return PyUnicode_FromFormat(message, self, nrows, ncols, view, size.width, size.height);
#else
    return PyString_FromFormat(message, self, nrows, ncols, view, size.width, size.height);
#endif
}

static void
Grid_dealloc(GridObject* self)
{
    GridView* view = self->view;
    if (view) [view release];
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Grid_resize(GridObject* self, PyObject *args, PyObject *keywords)

{
    PyErr_SetString(PyExc_RuntimeError,
                    "derived class should implement resize");
    return NULL;
}

static PyMethodDef Grid_methods[] = {
    {"resize",
     (PyCFunction)Grid_resize,
     METH_KEYWORDS | METH_VARARGS,
     "Resizes the grid."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Grid_get_origin(GridObject* self, void* closure)
{
    CGFloat x;
    CGFloat y;
    GridView* view = self->view;
    NSRect frame = view.frame;
    x = NSMinX(frame);
    y = NSMinY(frame);
    return Py_BuildValue("ii", (int) round(x), (int) round(y));
}

static int Grid_set_origin(GridObject* self, PyObject* value, void* closure)
{
    int x;
    int y;
    NSPoint point;
    GridView* view = self->view;
    NSWindow* window = [view window];
    if (!PyArg_ParseTuple(value, "ii", &x, &y)) return -1;
    if (view == [window contentView])
    {
        PyErr_SetString(PyExc_RuntimeError, "Grid cannot be moved.");
        return -1;
    }
    point.x = x;
    point.y = y;
    [view setFrameOrigin: point];
    return 0;
}

static char Grid_origin__doc__[] = "position of the top-left corner of the grid";

static PyObject* Grid_get_size(GridObject* self, void* closure)
{
    int width;
    int height;
    NSRect frame;
    GridView* view = self->view;
    frame = [view frame];
    width = round(frame.size.width);
    height = round(frame.size.height);
    return Py_BuildValue("ii", width, height);
}

static int Grid_set_size(GridObject* self, PyObject* value, void* closure)
{
    int width;
    int height;
    NSSize size;
    GridView* view = self->view;
    NSWindow* window = [view window];
    if (!PyArg_ParseTuple(value, "ii", &width, &height)) return -1;
    if (view == [window contentView])
    {
        PyErr_SetString(PyExc_RuntimeError, "Grid cannot be resized.");
        return -1;
    }
    size.width = width;
    size.height = height;
    [view setFrameSize: size];
    return 0;
}

static char Grid_size__doc__[] = "Grid size";

static PyGetSetDef Grid_getset[] = {
    {"origin", (getter)Grid_get_origin, (setter)Grid_set_origin, Grid_origin__doc__, NULL},
    {"size", (getter)Grid_get_size, (setter)Grid_set_size, Grid_size__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Grid_doc[] =
"Grid is the layout manager for a grid layout.\n";

PyTypeObject GridType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "gui.Grid",                 /* tp_name */
    sizeof(GridObject),         /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Grid_dealloc,   /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Grid_repr,        /* tp_repr */
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
    Grid_doc,                   /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Grid_methods,               /* tp_methods */
    0,                          /* tp_members */
    Grid_getset,                /* tp_getset */
    &WidgetType,                /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Grid_init,        /* tp_init */
    0,                          /* tp_alloc */
    Grid_new,                   /* tp_new */
};
