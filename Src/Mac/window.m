#include <Cocoa/Cocoa.h>
#include "window.h"
#include "widgets.h"
#include "label.h"
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


@interface View : NSView <NSWindowDelegate>
{
}
- (BOOL)isFlipped;
- (BOOL)autoresizesSubviews;
@end

@implementation View
- (BOOL)isFlipped
{
    return YES;
}

- (BOOL)autoresizesSubviews;
{
    return NO;
}
@end



typedef struct {
    PyObject_HEAD
    NSWindow* window;
} Window;

static PyObject*
Window_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    Window *self = (Window*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->window = NULL;
    return (PyObject*)self;
}

static int
Window_init(Window *self, PyObject *args, PyObject *kwds)
{
    NSRect rect;
    NSWindow* window;
    View* view;
    const char* title = "";
    int width = 100;
    int height = 100;

    if(!PyArg_ParseTuple(args, "|iis", &width, &height, &title)) return -1;

    rect.origin.x = 100;
    rect.origin.y = 350;
    rect.size.height = height;
    rect.size.width = width;

    NSApp = [NSApplication sharedApplication];
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    window = [NSWindow alloc];
    if (!window) return -1;
    [window initWithContentRect: rect
                      styleMask: NSTitledWindowMask
                               | NSClosableWindowMask
                               | NSResizableWindowMask
                               | NSMiniaturizableWindowMask
                        backing: NSBackingStoreBuffered
                          defer: YES];
    [window setTitle: [NSString stringWithCString: title
                                         encoding: NSASCIIStringEncoding]];

    [window setAcceptsMouseMovedEvents: YES];
    view = [[View alloc] initWithFrame: rect];
    [window setContentView: view];

    self->window = window;

    [pool release];
    return 0;
}

static PyObject*
Window_repr(Window* self)
{
#if PY3K
    return PyUnicode_FromFormat("Window object %p wrapping NSWindow %p",
                               (void*) self, (void*)(self->window));
#else
    return PyString_FromFormat("Window object %p wrapping NSWindow %p",
                               (void*) self, (void*)(self->window));
#endif
}

static void
Window_dealloc(Window* self)
{
    NSWindow* window = self->window;
    if (window)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [window close];
        [pool release];
    }
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Window_show(Window* self)
{
    NSWindow* window = self->window;
    if(window)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [window makeKeyAndOrderFront: nil];
        [window orderFrontRegardless];
        [pool release];
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_close(Window* self)
{
    NSWindow* window = self->window;
    if(window)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [window close];
        [pool release];
        self->window = NULL;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_iconify(Window* self)
{
    NSWindow* window = self->window;
    if(!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    [window miniaturize: NSApp];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_deiconify(Window* self)
{
    NSWindow* window = self->window;
    if(!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    [window deminiaturize: NSApp];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_maximize(Window* self)
{
    NSWindow* window = self->window;
    if(!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if (![window isZoomed]) [window zoom: NSApp];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_put(Window* self, PyObject *args, PyObject *kwds)
{
    PyObject* object;
    PyObject* item;
    PyObject* items;
    Py_ssize_t i;
    Py_ssize_t n;
    View* view;

    NSWindow* window = self->window;
    if(!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }

    view = [window contentView];
    if(!PyArg_ParseTuple(args, "O", &object))
        return NULL;
    if (!PyMapping_Check(object)) {
        PyErr_SetString(PyExc_RuntimeError, "argument is not a layout manager");
        return NULL;
    }
    items = PyMapping_Values(object);
    n = PyMapping_Length(object);
    for (i = 0; i < n; i++) {
        item = PyList_GET_ITEM(items, i);
        if (!PyObject_IsInstance(item, widgets)) break;
        printf("Item %ld OK\n", i);
    }

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_add(Window* self, PyObject *args, PyObject *kwds)
{
    PyObject* object;
    View* view;

    NSWindow* window = self->window;
    if(!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }

    view = [window contentView];
    if(!PyArg_ParseTuple(args, "O", &object))
        return NULL;

    if (PyObject_IsInstance(object, (PyObject*) &LabelType)) {
        PyLabel* label = (PyLabel*)object;
        Py_INCREF(label);
        [view addSubview: label->label];
    } else
    if (PyObject_IsInstance(object, (PyObject*) &ButtonType)) {
        PyButton* button = (PyButton*)object;
        Py_INCREF(button);
        [view addSubview: button->button];
    } else {
        PyErr_SetString(PyExc_TypeError, "windows can only add labels or buttons");
        return NULL;
    }

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_get_size(Window* self, PyObject *args)
{
    float width;
    float height;
    NSRect frame;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    frame = [[window contentView] frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("ff", width, height);
}

static PyMethodDef Window_methods[] = {
    {"show",
     (PyCFunction)Window_show,
     METH_NOARGS,
     "Shows the window."
    },
    {"close",
     (PyCFunction)Window_close,
     METH_NOARGS,
     "Closes the window."
    },
    {"iconify",
     (PyCFunction)Window_iconify,
     METH_NOARGS,
     "Attempts to iconify the window."
    },
    {"deiconify",
     (PyCFunction)Window_deiconify,
     METH_NOARGS,
     "Attempts to deiconify the window."
    },
    {"maximize",
     (PyCFunction)Window_maximize,
     METH_NOARGS,
     "Attempts to maximize the window."
    },
    {"put",
     (PyCFunction)Window_put,
     METH_VARARGS,
     "Sets the layout manager."
    },
    {"add",
     (PyCFunction)Window_add,
     METH_VARARGS,
     "Adds a control to the window."
    },
    {"get_size",
     (PyCFunction)Window_get_size,
     METH_NOARGS,
     "Returns the size of the window."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Window_get_title(Window* self, void* closure)
{
    NSWindow* window = self->window;
    PyObject* result = NULL;
    if(window)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        NSString* title = [window title];
        if (title) {
            const char* cTitle = [title UTF8String];
#if PY3K || (PY_MAJOR_VERSION == 2 && PY_MINOR_VERSION >= 6)
            result = PyUnicode_FromString(cTitle);
#else
            result = PyString_FromString(cTitle);
#endif
        }
        [pool release];
    }
    if (result) {
        return result;
    } else {
        Py_INCREF(Py_None);
        return Py_None;
    }
}

static int
Window_set_title(Window* self, PyObject* value, void* closure)
{
    char* title;
    title = PyString_AsString(value);
    if (!title) return -1;

    NSWindow* window = self->window;
    if(window)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        NSString* s = [[NSString alloc] initWithCString: title
                                               encoding: NSUTF8StringEncoding];
        [window setTitle: s];
        [s release];
        [pool release];
    }
    return 0;
}

static char Window_title__doc__[] = "window title";

static PyObject* Window_get_resizable(Window* self, void* closure)
{
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if (window.styleMask & NSResizableWindowMask) Py_RETURN_TRUE;
    Py_RETURN_FALSE;
}

static int
Window_set_resizable(Window* self, PyObject* value, void* closure)
{
    int flag;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    flag = PyObject_IsTrue(value);
    switch (flag) {
        case 1: window.styleMask |= NSResizableWindowMask; break;
        case 0: window.styleMask &= ~NSResizableWindowMask; break;
        case -1: return -1;
    }
    return 0;
}

static char Window_resizable__doc__[] = "specifies whether the window can be resized by the user";

static PyObject* Window_get_min_width(Window* self, void* closure)
{
    long width;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    width = (int) window.minSize.width;
    return PyInt_FromLong(width);
}

static int
Window_set_min_width(Window* self, PyObject* value, void* closure)
{
    long width;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    width = PyInt_AsLong(value);
    if (PyErr_Occurred()) return -1;
    size = window.minSize;
    size.width = width;
    window.minSize = size;
    return 0;
}

static char Window_min_width__doc__[] = "the minimum width to which the window can be resized by the user";

static PyObject* Window_get_max_width(Window* self, void* closure)
{
    long width;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    width = (int) window.maxSize.width;
    return PyInt_FromLong(width);
}

static int
Window_set_max_width(Window* self, PyObject* value, void* closure)
{
    long width;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    width = PyInt_AsLong(value);
    if (PyErr_Occurred()) return -1;
    size = window.maxSize;
    size.width = width;
    window.maxSize = size;
    return 0;
}

static char Window_max_width__doc__[] = "the maximum width to which the window can be resized by the user";

static PyObject* Window_get_min_height(Window* self, void* closure)
{
    long height;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    height = (int) window.minSize.height;
    return PyInt_FromLong(height);
}

static int
Window_set_min_height(Window* self, PyObject* value, void* closure)
{
    long height;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    height = PyInt_AsLong(value);
    if (PyErr_Occurred()) return -1;
    size = window.minSize;
    size.height = height;
    window.minSize = size;
    return 0;
}

static char Window_min_height__doc__[] = "the minimum height to which the window can be resized by the user";

static PyObject* Window_get_max_height(Window* self, void* closure)
{
    long height;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    height = (int) window.maxSize.height;
    return PyInt_FromLong(height);
}

static int
Window_set_max_height(Window* self, PyObject* value, void* closure)
{
    long height;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    height = PyInt_AsLong(value);
    if (PyErr_Occurred()) return -1;
    size = window.maxSize;
    size.height = height;
    window.maxSize = size;
    return 0;
}

static char Window_max_height__doc__[] = "the maximum height to which the window can be resized by the user";

static PyObject* Window_get_iconified(Window* self, void* closure)
{
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if ([window isMiniaturized]) Py_RETURN_TRUE;
    Py_RETURN_FALSE;
}

static char Window_iconified__doc__[] = "True if the window is iconified; False otherwise";

static PyGetSetDef Window_getset[] = {
    {"title", (getter)Window_get_title, (setter)Window_set_title, Window_title__doc__, NULL},
    {"resizable", (getter)Window_get_resizable, (setter)Window_set_resizable, Window_resizable__doc__, NULL},
    {"min_width", (getter)Window_get_min_width, (setter)Window_set_min_width, Window_min_width__doc__, NULL},
    {"max_width", (getter)Window_get_max_width, (setter)Window_set_max_width, Window_max_width__doc__, NULL},
    {"min_height", (getter)Window_get_min_height, (setter)Window_set_min_height, Window_min_height__doc__, NULL},
    {"max_height", (getter)Window_get_max_height, (setter)Window_set_max_height, Window_max_height__doc__, NULL},
    {"iconified", (getter)Window_get_iconified, (setter)NULL, Window_iconified__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Window_doc[] =
"A Window object wraps a Cocoa NSWindow object.\n";

static PyTypeObject WindowType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Window",            /* tp_name */
    sizeof(Window),             /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Window_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Window_repr,      /* tp_repr */
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
    Window_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Window_methods,             /* tp_methods */
    0,                          /* tp_members */
    Window_getset,              /* tp_getset */
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Window_init,      /* tp_init */
    0,                          /* tp_alloc */
    Window_new,                 /* tp_new */
};

int initialize_window(PyObject* module) {
    if (PyType_Ready(&WindowType) < 0) return -1;
    Py_INCREF(&WindowType);
    return PyModule_AddObject(module, "Window", (PyObject*) &WindowType);
}
