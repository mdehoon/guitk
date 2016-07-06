#include <Cocoa/Cocoa.h>
#include "button.h"

#if PY_MAJOR_VERSION >= 3
#define PY3K 1
#else
#if PY_MINOR_VERSION < 7
#error Python version should be 2.7 or newer
#else
#define PY3K 0
#endif
#endif

#define FILLX     1
#define FILLY     2
#define EXPAND    4
#define NORTH     8
#define EAST     16
#define SOUTH    32
#define WEST     64
#define TOP     128
#define BOTTOM  256
#define LEFT    512
#define RIGHT  1024


void dopack(CGRect* rect, CGRect* cavity)
{
    int flags;
    float padx = 20;
    float pady = 20;
    float ipadx = 80;
    float ipady = 30;
    if ((flags & TOP) || (flags & BOTTOM)) {
        rect->origin.x = cavity->origin.x;
        if (flags & FILLX) {
            rect->origin.x += padx;
            rect->size.width = cavity->size.width - 2 * padx;
        }
        else {
            rect->origin.x += 0.5 * (cavity->size.width - rect->size.width) - ipadx;
            rect->size.width += 2 * ipadx;
        }
        rect->size.height += pady + ipady;
        cavity->size.height -= rect->size.height;
        if (cavity->size.height < 0) {
            rect->size.height += cavity->size.height;
            cavity->size.height = 0;
        }
        if (flags & TOP) {
            rect->origin.y = cavity->origin.y;
            cavity->origin.y += rect->size.height;
        } else { /* BOTTOM */
            rect->origin.y = cavity->origin.y + cavity->size.height;
        }
    }
    if ((flags & LEFT) || (flags & RIGHT)) {
        rect->origin.x = cavity->origin.y;
        if (flags & FILLY) {
            rect->origin.y += pady;
            rect->size.height = cavity->size.height - 2 * padx;
        }
        else {
            rect->origin.y += 0.5 * (cavity->size.height - rect->size.height) - ipady;
            rect->size.height += 2 * ipady;
        }
        cavity->size.width -= rect->size.width;
        if (cavity->size.width < 0) {
            rect->size.width += cavity->size.width;
            cavity->size.width = 0;
        }
        rect->origin.y = cavity->origin.y;
        if (flags & LEFT) {
            rect->origin.x = cavity->origin.x;
            cavity->origin.x += rect->size.width;
        } else { /* RIGHT */
            rect->origin.x = cavity->origin.x + cavity->size.width;
        }
    }
}

@implementation Button
- (Button*)initWithObject:(PyButton*)obj
{
    NSRect rect;
    rect.origin.x = 10;
    rect.origin.y = 10;
    rect.size.width = 100;
    rect.size.height = 100;
    self = [super initWithFrame: rect];
    [self setAutoresizingMask: NSViewMinXMargin
                             | NSViewWidthSizable
                             | NSViewMaxXMargin
                             | NSViewMinYMargin
                             | NSViewHeightSizable
                             | NSViewMaxYMargin];
[[self cell] setBackgroundColor:[NSColor redColor]];
    object = obj;
    return self;
}

- (void)setString:(const char*)s
{
    text = [[NSString alloc] initWithCString: s encoding: NSUTF8StringEncoding];
    [self setTitle: text];
}

- (BOOL)pack:(NSRect*)cavity
{
    static int counter = 0;
    float coordinates[4];
    float padx = 20;
    float pady = 20;
    float ipadx = 80;
    float ipady = 30;
    PyObject* layout;
    int flags = 0;
    flags |= TOP;
    CGRect rect;
    CGSize size;
    NSRect frame;
    [self sizeToFit];
    frame = [self frame];
    size.width = frame.size.width;
    size.height = frame.size.height;
    rect.size = size;
    coordinates[0] = cavity->origin.x;
    coordinates[1] = cavity->origin.y;
    coordinates[2] = cavity->origin.x + cavity->size.width;
    coordinates[3] = cavity->origin.y + cavity->size.height;
    layout = PyObject_GetAttrString(object, "layout");
    PyObject* result = PyObject_CallMethod(layout, "arrange", "ffff",
                                                   cavity->origin.x,
                                                   cavity->origin.y,
                                                   cavity->size.width,
                                                   cavity->size.height);
    if (result==NULL) {
        PyErr_SetString(PyExc_RuntimeError,
                        "calling 'arrange' on layout manager failed");
        return false;
    }
    PyArg_ParseTuple(result, "dddd", &rect.origin.x, &rect.origin.y, &rect.size.width, &rect.size.height);
    printf("rect.origin.x = %f\n", rect.origin.x);
    printf("rect.origin.y = %f\n", rect.origin.y);
    printf("rect.size.height = %f\n", rect.size.height);
    printf("rect.size.width = %f\n", rect.size.width);
    return true;
}
@end

static PyObject*
Button_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    PyButton *self = (PyButton*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->button = NULL;
    self->layout = NULL;
    return (PyObject*)self;
}

static int
Button_init(PyButton *self, PyObject *args, PyObject *kwds)
{
    Button *button;
    PyObject* layout;
    PyObject* arguments;
    const char* text = "";

    if(!PyArg_ParseTuple(args, "|s", &text)) return -1;

    button = [[Button alloc] initWithObject: self];
    [button setString: text];
    self->button = button;

    return 0;
}

static PyObject*
Button_repr(PyButton* self)
{
#if PY3K
    return PyUnicode_FromFormat("Button object %p wrapping NSButton %p",
                               (void*) self, (void*)(self->button));
#else
    return PyString_FromFormat("Button object %p wrapping NSButton %p",
                               (void*) self, (void*)(self->button));
#endif
}

static void
Button_dealloc(PyButton* self)
{
    NSButton* button = self->button;
    if (button)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [button release];
        [pool release];
    }
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Button_set_frame(PyButton* self, PyObject *args)
{
    float x0;
    float y0;
    float x1;
    float y1;
    NSPoint position;
    NSSize size;
    NSButton* button = self->button;
    if (!button) {
        PyErr_SetString(PyExc_RuntimeError, "button has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ffff", &x0, &y0, &x1, &y1))
        return NULL;
    printf("Setting frame to %f, %f, %f, %f\n", x0, y0, x1, y1);

    position.x = x0;
    position.y = y0;
    [button setFrameOrigin: position];
    size.width = x1 - x0;
    size.height = y1 - y0;
    [button setFrameSize: size];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Button_get_size(PyButton* self, PyObject *args)
{
    float width;
    float height;
    NSRect frame;
    NSButton* button = self->button;
    if (!button) {
        PyErr_SetString(PyExc_RuntimeError, "button has not been initialized");
        return NULL;
    }
    frame = [button frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("ff", width, height);
}

static PyObject*
Button_set_size(PyButton* self, PyObject *args)
{
    float width;
    float height;
    NSSize size;
    NSButton* button = self->button;
    if (!button) {
        PyErr_SetString(PyExc_RuntimeError, "button has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ff", &width, &height)) return NULL;
    if (width < 0 || height < 0) {
        PyErr_SetString(PyExc_RuntimeError, "width and height should be non-negative");
        return NULL;
    }
    size.width = width;
    size.height = height;
    [button setFrameSize: size];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Button_pack(PyButton* self, PyObject *args)
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
    NSButton* button = self->button;
    if (!button) {
        PyErr_SetString(PyExc_RuntimeError, "button has not been initialized");
        return NULL;
    }
/*
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
    frame = [button frame];
    size = frame.size;
    position.y = origin.y;
    position.x = 0.5 * (origin.x + corner.x - size.width);
    origin.y += size.height;

    [button setFrameOrigin: position];

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
*/
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Button_methods[] = {
    {"set_frame",
     (PyCFunction)Button_set_frame,
     METH_VARARGS,
     "Sets the size and position of the button."
    },
    {"get_size",
     (PyCFunction)Button_get_size,
     METH_NOARGS,
     "Returns the size of the button."
    },
    {"set_size",
     (PyCFunction)Button_set_size,
     METH_VARARGS,
     "Sets the size of the button."
    },
    {"pack",
     (PyCFunction)Button_pack,
     METH_VARARGS,
     "Pack the button into the available cavity."
    },
    {NULL}  /* Sentinel */
};

static char Button_layout__doc__[] =
"layout manager associated with this button";

static PyObject*
Button_getlayout(PyButton* self, void* closure)
{
    PyObject* layout = self->layout;
    Py_INCREF(layout);
    return layout;
}

static int
Button_setlayout(PyButton* self, PyObject* value, void* closure)
{
    Py_INCREF(value);
    self->layout = value;
    return 0;
}

static PyGetSetDef Button_getseters[] = {
    {"layout", (getter)Button_getlayout, (setter)Button_setlayout, Button_layout__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Button_doc[] =
"A Button object wraps a Cocoa NSButton object.\n";

PyTypeObject ButtonType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Button",            /* tp_name */
    sizeof(PyButton),           /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Button_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Button_repr,      /* tp_repr */
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
    Button_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Button_methods,             /* tp_methods */
    0,                          /* tp_members */
    Button_getseters,           /* tp_getset */
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Button_init,      /* tp_init */
    0,                          /* tp_alloc */
    Button_new,                 /* tp_new */
};
