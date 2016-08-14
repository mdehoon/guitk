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

@interface GridView : NSView <Widget>
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (GridView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object;
@end

typedef struct {
    PyObject_HEAD
    GridView* view;
    unsigned int nrows;
    unsigned int ncols;
    WidgetObject*** objects;
} GridObject;

@implementation GridView
- (PyObject*)object
{
    return (PyObject*)_object;
}

- (GridView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object
{
    self = [super initWithFrame: rect];
    _object = object;
    return self;
}

- (void)doLayout {
    NSSize size;
    NSRect rect;
    Py_ssize_t irow;
    Py_ssize_t icol;
    GridObject* obj = (GridObject*)_object;
    unsigned nrows = obj->nrows;
    unsigned ncols = obj->ncols;
    WidgetObject* widget;
    NSView* view;
    NSPoint origin;
    rect = [self frame];
    size = rect.size;
    size.width /= ncols;
    size.height /= nrows;
    for (irow = 0; irow < nrows; irow++) {
        for (icol = 0; icol < ncols; icol++) {
            widget = obj->objects[irow][icol];
            if (!widget) continue;
            view = widget->view;
            origin.x = icol * size.width;
            origin.y = irow * size.height;
            [view setFrameSize: size];
            [view setFrameOrigin: origin];
        }
    }
}

- (void)viewWillDraw {
    printf("In viewWillDraw\n");
    WidgetObject* o;
    NSView* view;
    Py_ssize_t ii;
    Py_ssize_t jj;
    GridObject* object = _object;
    for (ii = 0; ii < 3; ii++) {
        for (jj = 0; jj < 3; jj++) {
            o = object->objects[ii][jj];
            if (!o) continue;
            view = o->view;
            if (!view) continue;
            printf("In viewWillDraw BEFORE: grid[%d][%d] needs display? %s\n", ii, jj, view.needsDisplay ? "YES" : "NO");
        }
    }
    o = object->objects[0][0];
    view = o->view;
    [view setNeedsDisplay: YES];
    for (ii = 0; ii < 3; ii++) {
        for (jj = 0; jj < 3; jj++) {
            o = object->objects[ii][jj];
            if (!o) continue;
            view = o->view;
            if (!view) continue;
            printf("In viewWillDraw AFTER: grid[%d][%d] needs display? %s\n", ii, jj, view.needsDisplay ? "YES" : "NO");
        }
    }
    [super viewWillDraw];
}

- (void)drawRect:(NSRect)rect {
    printf("In GridView drawRect; rect origin is %f, %f; size is %f, %f\n", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    Py_ssize_t ii;
    Py_ssize_t jj;
    GridObject* object = _object;
    [self doLayout];
    for (ii = 0; ii < 3; ii++) {
        for (jj = 0; jj < 3; jj++) {
            WidgetObject* o = object->objects[ii][jj];
            if (!o) continue;
            NSView* v = o->view;
            if (!v) continue;
            printf("In drawRect: grid[%d][%d] needs display? %s\n", ii, jj, v.needsDisplay ? "YES" : "NO");
            v.needsDisplay = NO;
            printf("In drawRect; checking: grid[%d][%d] needs display? %s\n", ii, jj, v.needsDisplay ? "YES" : "NO");
        }
    }
}

- (BOOL)isFlipped
{
    return YES;
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
    int irow;
    int nrows = 1;
    int ncols = 1;
    GridView* view;
    if(!PyArg_ParseTuple(args, "|ii", &nrows, &ncols)) return -1;
    view = [[GridView alloc] initWithFrame: NSZeroRect
                                withObject: (PyObject*)self];
    self->view = view;
    self->nrows = nrows;
    self->ncols = ncols;
    self->objects = malloc(nrows*sizeof(PyObject**));
    for (irow = 0; irow < nrows; irow++) {
        self->objects[irow] = calloc(ncols,sizeof(PyObject*));
    }
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

static Py_ssize_t Grid_length(GridObject* self) {
    NSView* view;
    const Py_ssize_t size = self->nrows * self->ncols;
    Py_ssize_t ii;
    Py_ssize_t jj;
    printf("BEFORE: grid needs display? %s\n", self->view.needsDisplay ? "YES" : "NO");
    for (ii = 0; ii < 3; ii++) {
        for (jj = 0; jj < 3; jj++) {
            WidgetObject* o = self->objects[ii][jj];
            if (!o) continue;
            view = o->view;
            if (!view) continue;
            printf("BEFORE: grid[%d][%d] needs display? %s\n", ii, jj, view.needsDisplay ? "YES" : "NO");
        }
    }
    view.needsDisplay = YES;
    printf("AFTER: grid needs display? %s\n", self->view.needsDisplay ? "YES" : "NO");
    for (ii = 0; ii < 3; ii++) {
        for (jj = 0; jj < 3; jj++) {
            WidgetObject* o = self->objects[ii][jj];
            if (!o) continue;
            view = o->view;
            if (!view) continue;
            printf("AFTER: grid[%d][%d] needs display? %s\n", ii, jj, view.needsDisplay ? "YES" : "NO");
        }
    }
    return size;
}

static WidgetObject* Grid_get_item(GridObject* self, PyObject* key) {
    Py_ssize_t irow;
    Py_ssize_t icol;
    PyObject* item;
    WidgetObject* object;
    if (!PyTuple_Check(key) || PyTuple_GET_SIZE(key)!=2) {
        PyErr_SetString(PyExc_ValueError, "expected a typle of size 2");
        return NULL;
    }
    item = PyTuple_GET_ITEM(key, 0);
    irow = PyInt_AsSsize_t(item);
    if (PyErr_Occurred()) return NULL;
    item = PyTuple_GET_ITEM(key, 1);
    icol = PyInt_AsSsize_t(item);
    if (PyErr_Occurred()) return NULL;
    object = self->objects[irow][icol];
    Py_INCREF(object);
    return object;
}

static int Grid_set_item(GridObject* self, PyObject* key, PyObject* value) {
    Py_ssize_t irow;
    Py_ssize_t icol;
    PyObject* item;
    PyTypeObject* type;
    WidgetObject* object;
    WidgetObject* widget;
    NSView* view = nil;
    if (!PyTuple_Check(key) || PyTuple_GET_SIZE(key)!=2) {
        PyErr_SetString(PyExc_ValueError, "expected a typle of size 2");
        return -1;
    }
    if (value == Py_None) {
        value = NULL;
    } else {
        type = Py_TYPE(value);
        if (!PyType_IsSubtype(type, &WidgetType)) {
            PyErr_SetString(PyExc_ValueError, "expected a widget or None");
            return -1;
        }
        widget = (WidgetObject*)value;
        view = widget->view;
        if ([view superview]) {
            PyErr_SetString(PyExc_ValueError, "this widget is already in use");
            return -1;
        }
    }
    item = PyTuple_GET_ITEM(key, 0);
    irow = PyInt_AsSsize_t(item);
    if (PyErr_Occurred()) return -1;
    item = PyTuple_GET_ITEM(key, 1);
    icol = PyInt_AsSsize_t(item);
    if (PyErr_Occurred()) return -1;
    object = self->objects[irow][icol];
    if (object) {
        [object->view removeFromSuperview];
        Py_DECREF(object);
    }
    Py_ssize_t ii;
    Py_ssize_t jj;
    for (ii = 0; ii < 2; ii++) {
        for (jj = 0; jj < 2; jj++) {
            WidgetObject* o = self->objects[ii][jj];
            if (!o) continue;
            NSView* v = o->view;
            if (!v) continue;
            printf("DURING: grid[%d][%d] needs display? %s\n", ii, jj, v.needsDisplay ? "YES" : "NO");
        }
    }
    if (value) {
        Py_INCREF(value);
        [self->view addSubview: view];
    }
    self->objects[irow][icol] = widget;
    for (irow = 0; irow < 2; irow++) {
        for (icol = 0; icol < 2; icol++) {
            object = self->objects[irow][icol];
            if (!object) continue;
            view = object->view;
            if (!view) continue;
            printf("AFTER: grid[%d][%d] needs display? %s\n", irow, icol, view.needsDisplay ? "YES" : "NO");
        }
    }
    self->view.needsDisplay = YES;
    return 0;
}

static PyMappingMethods Grid_as_mapping = {
    (lenfunc)Grid_length,               /* mp_length */
    (binaryfunc)Grid_get_item,          /* mp_subscript */
    (objobjargproc)Grid_set_item,       /* mp_ass_subscript */
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
    &Grid_as_mapping,           /* tp_as_mapping */
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
