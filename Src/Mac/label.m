#include <Cocoa/Cocoa.h>
#include "label.h"

#if PY_MAJOR_VERSION >= 3
#define PY3K 1
#else
#if PY_MINOR_VERSION < 7
#error Python version should be 2.7 or newer
#else
#define PY3K 0
#endif
#endif

static PyObject*
Label_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    Label *self = (Label*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->label = NULL;
    return (PyObject*)self;
}

static int
Label_init(Label *self, PyObject *args, PyObject *kwds)
{
    NSRect rect;
    NSTextField *textField;
    const char* text = "";
    CGFloat fontsize;
    NSControlSize size;
    NSFont* font;
    NSCell* cell;

    if(!PyArg_ParseTuple(args, "|s", &text)) return -1;

    NSString* s = [[NSString alloc]
                         initWithCString: text
                                encoding: NSUTF8StringEncoding];

    rect.origin.x = 10;
    rect.origin.y = 10;
    rect.size.width = 100;
    rect.size.height = 100;

    NSApp = [NSApplication sharedApplication];
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    textField = [[NSTextField alloc] initWithFrame: rect];
    [textField setStringValue:s];
    [textField setBezeled:NO];
    [textField setDrawsBackground:NO];
    [textField setEditable:NO];
    [textField setSelectable:NO];
    [textField setAutoresizingMask: NSViewMinXMargin
                                  | NSViewWidthSizable
                                  | NSViewMaxXMargin
                                  | NSViewMinYMargin
                                  | NSViewHeightSizable
                                  | NSViewMaxYMargin];
    cell = [textField cell];
    size = [cell controlSize];
    fontsize = [NSFont systemFontSizeForControlSize: size];
    font = [NSFont systemFontOfSize: fontsize];
    [textField setFont: font];
    [s release];
    [textField sizeToFit];

    [pool release];

    self->label = textField;

    return 0;
}

static PyObject*
Label_repr(Label* self)
{
#if PY3K
    return PyUnicode_FromFormat("Label object %p wrapping NSTextField %p",
                               (void*) self, (void*)(self->label));
#else
    return PyString_FromFormat("Label object %p wrapping NSTextField %p",
                               (void*) self, (void*)(self->label));
#endif
}

static void
Label_dealloc(Label* self)
{
    NSTextField* label = self->label;
    if (label)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [label release];
        [pool release];
    }
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Label_set_position(Label* self, PyObject *args)
{
    float x;
    float y;
    NSPoint position;
    NSTextField* label = self->label;
    if (!label) {
        PyErr_SetString(PyExc_RuntimeError, "label has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ff", &x, &y))
        return NULL;

    position.x = x;
    position.y = y;
    [label setFrameOrigin: position];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Label_get_size(Label* self, PyObject *args)
{
    float width;
    float height;
    NSRect frame;
    NSTextField* label = self->label;
    if (!label) {
        PyErr_SetString(PyExc_RuntimeError, "label has not been initialized");
        return NULL;
    }
    frame = [label frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("ff", width, height);
}

static PyObject*
Label_pack(Label* self, PyObject *args)
{
    int i;
    double values[4];
    NSPoint origin;
    NSPoint corner;
    NSPoint position;
    NSRect frame;
    NSSize size;
    PyObject* item;
    PyObject* cavity;
    NSTextField* label = self->label;
    if (!label) {
        PyErr_SetString(PyExc_RuntimeError, "label has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "O", &cavity))
        return NULL;
    if(!PyList_Check(cavity)) {
        PyErr_SetString(PyExc_RuntimeError, "cavity argument should be a list");
        return NULL;
    }
    if(PyList_GET_SIZE(cavity)!=4) {
        PyErr_SetString(PyExc_RuntimeError, "cavity argument should be a list of four elements");
        return NULL;
    }
    for (i = 0; i < 4; i++) {
        item = PyList_GET_ITEM(cavity, i);
        values[i] = PyFloat_AsDouble(item);
        if (values[i] < 0 && PyErr_Occurred()) {
            PyErr_SetString(PyExc_RuntimeError, "cavity argument should be a list of four numbers");
            return NULL;
        }
    }

    origin.x = values[0];
    origin.y = values[1];
    corner.x = values[2];
    corner.y = values[3];
    frame = [label frame];
    size = frame.size;
    position.y = origin.y;
    position.x = 0.5 * (origin.x + corner.x - size.width);
    origin.y += size.height;

    [label setFrameOrigin: position];

    values[0] = origin.x;
    values[1] = origin.y;
    values[2] = corner.x;
    values[3] = corner.y;
    for (i = 0; i < 4; i++) {
        item = PyFloat_FromDouble(values[i]);
        if (!item) return NULL;
        if (PyList_SetItem(cavity, i, item)==-1) {
            Py_DECREF(item);
            return NULL;
        }
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Label_methods[] = {
    {"set_position",
     (PyCFunction)Label_set_position,
     METH_VARARGS,
     "Moves the label to the new position."
    },
    {"get_size",
     (PyCFunction)Label_get_size,
     METH_NOARGS,
     "Returns the size of the label."
    },
    {"pack",
     (PyCFunction)Label_pack,
     METH_VARARGS,
     "Pack the label into the available cavity."
    },
    {NULL}  /* Sentinel */
};

static char Label_doc[] =
"A Label object wraps a Cocoa NSTextField object.\n";

PyTypeObject LabelType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Label",             /* tp_name */
    sizeof(Label),              /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Label_dealloc,  /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Label_repr,       /* tp_repr */
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
    Label_doc,                  /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Label_methods,              /* tp_methods */
    0,                          /* tp_members */
    0,                          /* tp_getset */
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Label_init,       /* tp_init */
    0,                          /* tp_alloc */
    Label_new,                  /* tp_new */
};
