#include <Python.h>
#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "window.h"
#include "colors.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
#define COMPILING_FOR_10_6
#endif
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
#define COMPILING_FOR_10_7
#endif

PyTypeObject SeparatorType;

static PyObject*
Separator_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    NSBox* box;
    PyObject* object;
    WidgetObject *self;
    NSRect rect = NSZeroRect;
    NSColor* color = [NSColor lightGrayColor];
    CGFloat gray;
    CGFloat alpha;
    [color getWhite: &gray alpha: &alpha];
    self = (WidgetObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    object = (PyObject*)self;
    box = [[NSBox alloc] initWithFrame:rect];
    box.boxType = NSBoxSeparator;
    box.borderType = NSGrooveBorder;
    box.titlePosition = NSNoTitle;
    self->view = box;
    return object;
}

static PyObject*
Separator_repr(WidgetObject* self)
{
    NSView* view = self->view;
    return PyUnicode_FromFormat("Separator object %p wrapping NSView %p",
                               self, view);
}

static void
Separator_dealloc(WidgetObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    NSView* view = widget->view;
    if (view) [view release];
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyMethodDef Separator_methods[] = {
    {NULL}  /* Sentinel */
};

static PyObject* Separator_get_size(WidgetObject* self, void* closure)
{
    CGFloat width;
    CGFloat height;
    NSRect frame;
    NSView* view = self->view;
    frame = [view frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("dd", width, height);
}

static int Separator_set_size(WidgetObject* self, PyObject* value, void* closure)
{
    double width;
    double height;
    NSSize size;
    NSView* view = self->view;
    NSWindow* window = [view window];
    if (!PyArg_ParseTuple(value, "dd", &width, &height)) return -1;
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

static char Separator_size__doc__[] = "Separator size";

static PyObject* Separator_get_minimum_size(WidgetObject* self, void* closure)
{
    double width;
    double height;
    PyObject* minimum_size;
    WidgetObject* widget = (WidgetObject*)self;
    NSBox* box = (NSBox*) (widget->view);
    NSSize margins = [box contentViewMargins];
    width = margins.width;
    height = margins.height;
    minimum_size = Py_BuildValue("dd", width, height);
    return minimum_size;
}

static char Separator_minimum_size__doc__[] = "minimum size needed to show the frame.";

static PyGetSetDef Separator_getset[] = {
    {"size", (getter)Separator_get_size, (setter)Separator_set_size, Separator_size__doc__, NULL},
    {"minimum_size", (getter)Separator_get_minimum_size, (setter)NULL, Separator_minimum_size__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Separator_doc[] = "Separator.\n";

PyTypeObject SeparatorType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "gui.Separator",               /* tp_name */
    sizeof(WidgetObject),       /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Separator_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Separator_repr,      /* tp_repr */
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
    Separator_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Separator_methods,             /* tp_methods */
    0,                          /* tp_members */
    Separator_getset,              /* tp_getset */
    &WidgetType,                /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    0,                          /* tp_init */
    0,                          /* tp_alloc */
    Separator_new,                 /* tp_new */
};
