#include <Cocoa/Cocoa.h>
#include "window.h"
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
Window_pack(Window* self)
{
    id object;
    NSView* view = [self->window contentView];
    NSRect cavity = [view frame];
    printf("Starting cavity = %f, %f; %f, %f\n", cavity.origin.x, cavity.origin.y, cavity.size.width, cavity.size.height);
    NSArray* subviews = [view subviews];
    NSEnumerator *enumerator = [subviews objectEnumerator];
    while (object = [enumerator nextObject]) {
        Label* label = (Label*)object;
        if ([label pack: &cavity]==false) return NULL;
        printf("cavity = %f, %f; %f, %f\n", cavity.origin.x, cavity.origin.y, cavity.size.width, cavity.size.height);
    }
    Py_INCREF(Py_None);
    return Py_None;
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
Window_destroy(Window* self)
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
Window_set_window_title(Window* self, PyObject *args, PyObject *kwds)
{
    char* title;
    if(!PyArg_ParseTuple(args, "es", "UTF-8", &title))
        return NULL;

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
    PyMem_Free(title);
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_get_window_title(Window* self)
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

static PyObject*
Window_add(Window* self, PyObject *args, PyObject *kwds)
{
    PyObject* object;
    View* view;
    PyLabel* label;

    NSWindow* window = self->window;
    if(!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }

    view = [window contentView];
    if(!PyArg_ParseTuple(args, "O", &object))
        return NULL;

    if (!PyObject_IsInstance(object, (PyObject*) &LabelType))
    {
        PyErr_SetString(PyExc_TypeError, "windows can only add labels");
        return NULL;
    }
    label = (PyLabel*)object;
    Py_INCREF(label);

    [view addSubview: label->label];

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
    {"pack",
     (PyCFunction)Window_pack,
     METH_NOARGS,
     "Uses the layout manager to position each widget in the window."
    },
    {"destroy",
     (PyCFunction)Window_destroy,
     METH_NOARGS,
     "Closes the window."
    },
    {"set_window_title",
     (PyCFunction)Window_set_window_title,
     METH_VARARGS,
     "Sets the title of the window."
    },
    {"get_window_title",
     (PyCFunction)Window_get_window_title,
     METH_NOARGS,
     "Returns the title of the window."
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
    0,                          /* tp_getset */
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
