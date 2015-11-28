#include <Cocoa/Cocoa.h>
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

typedef struct {
    PyObject_HEAD
} GridItem;

typedef struct {
    PyObject_HEAD
    long dimensions[2];
    GridItem** items;
} Grid;

static PyObject*
GridItem_put(GridItem* self, PyObject *args, PyObject *kwds)
{
    PyObject* object;
    if(!PyArg_ParseTuple(args, "O", &object))
        return NULL;
    printf("In put\n");
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef GridItem_methods[] = {
    {"put",
     (PyCFunction)GridItem_put,
     METH_VARARGS,
     "Puts a widget in the grid location"
    },
    {NULL}  /* Sentinel */
};

static PyObject*
GridItem_repr(Grid* self)
{
#if PY3K
    return PyUnicode_FromFormat("GridItem object");
#else
    return PyString_FromFormat("GridItem object");
#endif
}

static char GridItem_doc[] =
"GridItem object.\n";

static void
GridItem_dealloc(Grid* self)
{
    Py_TYPE(self)->tp_free((PyObject*)self);
}

PyTypeObject GridItemType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.GridItem",              /* tp_name */
    sizeof(GridItem),               /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)GridItem_dealloc,   /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)GridItem_repr,        /* tp_repr */
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
    GridItem_doc,               /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    GridItem_methods,           /* tp_methods */
    0,                          /* tp_members */
    0,                          /* tp_getset */
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    0,                          /* tp_init */
    0,                          /* tp_alloc */
    0,                          /* tp_new */
};

static PyObject*
Grid_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    Grid *self = (Grid*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    return (PyObject*)self;
}

static int
Grid_init(Grid *self, PyObject *args, PyObject *kwds)
{
    long nx = 1;
    long ny = 1;
    int i, n;
    GridItem* item;
    if(!PyArg_ParseTuple(args, "ll", &nx, &ny)) return -1;
    n = nx * ny;
    self->items = malloc(sizeof(GridItem*)*n);
    if (!self->items) {
        PyErr_SetString(PyExc_MemoryError, "could not create grid");
        return NULL;
    }
    for (i = 0; i < n; i++) {
        item = (GridItem*) GridItemType.tp_alloc(&GridItemType, 0);
        if (!item) break;
        self->items[i] = item;
    }
    if (i < n) {
        PyErr_SetString(PyExc_MemoryError, "could not create grid item");
        for ( ; i >= 0; i--) Py_DECREF(self->items[i]);
        free(self->items);
        return NULL;
    }
    self->dimensions[0] = nx;
    self->dimensions[1] = ny;
    return 0;
}

static PyObject*
Grid_repr(Grid* self)
{
#if PY3K
    return PyUnicode_FromFormat("Grid layout object with dimensions (%ld, %ld)", self->dimensions[0], self->dimensions[1]);
#else
    return PyString_FromFormat("Grid layout object with dimensions (%ld, %ld)", self->dimensions[0], self->dimensions[1]);
#endif
}

static void
Grid_dealloc(Grid* self)
{
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyMethodDef Grid_methods[] = {
    {NULL}  /* Sentinel */
};

static PyObject*
Grid_getitem(Grid* self, PyObject* key)
{   long int ix, iy;
    long int nx, ny;
    long int index;
    GridItem* item;
    PyObject* object;
    if (!PyTuple_CheckExact(key) || PyTuple_Size(key)!=2)
    {   PyErr_SetString(PyExc_IndexError, "expected two indices");
        return NULL;
    }
    if (!PyArg_ParseTuple(key, "ll", &ix, &iy)) return NULL;
    nx = self->dimensions[0];
    ny = self->dimensions[1];
    if (ix < 0) ix += nx;
    if (iy < 0) iy += ny;
    if (ix < 0 || ix >= nx)
    {   PyErr_SetString(PyExc_IndexError, "first index is out of bounds");
        return NULL;
    }
    if (iy < 0 || iy >= ny)
    {   PyErr_SetString(PyExc_IndexError, "second index is out of bounds");
        return NULL;
    }
    index = ix * ny + iy;
    item = self->items[index];
    object = (PyObject*)item;
    Py_INCREF(object);
    return object;
}

static PyMappingMethods Grid_mapping = {
        NULL,                     /* mp_length */
        (binaryfunc)Grid_getitem, /* mp_subscript */
        NULL,                     /* mp_ass_subscript */
};

static char Grid_doc[] =
"Grid layout object.\n";

PyTypeObject GridType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Grid",              /* tp_name */
    sizeof(Grid),               /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Grid_dealloc,   /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Grid_repr,        /* tp_repr */
    0,                          /* tp_as_number */
    0,                          /* tp_as_sequence */
    &Grid_mapping,              /* tp_as_mapping */
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
    0,                          /* tp_getset */
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Grid_init,        /* tp_init */
    0,                          /* tp_alloc */
    Grid_new,                   /* tp_new */
};
