#include <Python.h>
#include <Cocoa/Cocoa.h>
#include <string.h>
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
Widget_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    WidgetObject *self = (WidgetObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->view = NULL;
    self->halign = 'f';
    self->valign = 'f';
    self->hexpand = NO;
    self->vexpand = NO;
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


static PyObject*
Widget_remove(WidgetObject* self)
{
    Window* window;
    NSView* view = self->view;
    [view removeFromSuperview];
    window = (Window*) [view window];
    [window requestLayout];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Widget_methods[] = {
    {"resize",
     (PyCFunction)Widget_resize,
     METH_KEYWORDS | METH_VARARGS,
     "Resizes the widget."
    },
    {"remove",
     (PyCFunction)Widget_remove,
     METH_NOARGS,
     "Removes the widget from its superview."
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
    CGFloat x;
    CGFloat y;
    NSPoint point;
    NSView* view = self->view;
    NSWindow* window = [view window];
    if (!PyArg_ParseTuple(value, "ff", &x, &y)) return -1;
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
    CGFloat width;
    CGFloat height;
    NSRect frame;
    NSView* view = self->view;
    frame = [view frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("dd", width, height);
}

static int Widget_set_size(WidgetObject* self, PyObject* value, void* closure)
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

static char Widget_size__doc__[] = "Widget size";

static PyObject* Widget_get_halign(WidgetObject* self, void* closure)
{
    const char* s;
    const char c = self->halign;
    switch (c) {
        case 'c': s = "CENTER"; break;
        case 'l': s = "LEFT"; break;
        case 'r': s = "RIGHT"; break;
        case 'f': s = "FILL"; break;
        default:
            PyErr_SetString(PyExc_SystemError, "unexpected alignment value.");
            return NULL;
    }
    return PyString_FromString(s);
}

static int Widget_set_halign(WidgetObject* self, PyObject* value, void* closure)
{
    const char* argument = PyString_AsString(value);
    if (!argument) return -1;
    if (strcmp(argument, "LEFT")==0) self->halign = 'l';
    else if (strcmp(argument, "RIGHT")==0) self->halign = 'r';
    else if (strcmp(argument, "CENTER")==0) self->halign = 'c';
    else if (strcmp(argument, "FILL")==0) self->halign = 'f';
    else {
        PyErr_SetString(PyExc_ValueError, "argument should be 'FILL', 'LEFT', 'CENTER', or 'RIGHT'.");
        return -1;
    }
    return 0;
}

static char Widget_halign__doc__[] = "Widget horizontal alignment";

static PyObject* Widget_get_valign(WidgetObject* self, void* closure)
{
    const char* s;
    const char c = self->valign;
    switch (c) {
        case 'c': s = "CENTER"; break;
        case 't': s = "TOP"; break;
        case 'b': s = "BOTTOM"; break;
        case 'f': s = "FILL"; break;
        default:
            PyErr_SetString(PyExc_SystemError, "unexpected alignment value.");
            return NULL;
    }
    return PyString_FromString(s);
}

static int Widget_set_valign(WidgetObject* self, PyObject* value, void* closure)
{
    const char* argument = PyString_AsString(value);
    if (!argument) return -1;
    if (strcmp(argument, "TOP")==0) self->valign = 't';
    else if (strcmp(argument, "BOTTOM")==0) self->valign = 'b';
    else if (strcmp(argument, "CENTER")==0) self->valign = 'c';
    else if (strcmp(argument, "FILL")==0) self->valign = 'f';
    else {
        PyErr_SetString(PyExc_ValueError, "argument should be 'FILL', 'TOP', 'CENTER', or 'BOTTOM'.");
        return -1;
    }
    return 0;
}

static char Widget_valign__doc__[] = "Widget vertical alignment";

static PyObject* Widget_get_hexpand(WidgetObject* self, void* closure)
{
    if (self->hexpand) Py_RETURN_TRUE;
    Py_RETURN_FALSE;
}

static int Widget_set_hexpand(WidgetObject* self, PyObject* value, void* closure)
{
    const int flag = PyObject_IsTrue(value);
    if (flag) self->hexpand = YES;
    else self->hexpand = NO;
    return 0;
}

static char Widget_hexpand__doc__[] = "Widget should expand horizontally";

static PyObject* Widget_get_vexpand(WidgetObject* self, void* closure)
{
    if (self->vexpand) Py_RETURN_TRUE;
    Py_RETURN_FALSE;
}

static int Widget_set_vexpand(WidgetObject* self, PyObject* value, void* closure)
{
    const int flag = PyObject_IsTrue(value);
    if (flag) self->vexpand = YES;
    else self->vexpand = NO;
    return 0;
}

static char Widget_vexpand__doc__[] = "Widget should expand vertically";

static PyGetSetDef Widget_getset[] = {
    {"origin", (getter)Widget_get_origin, (setter)Widget_set_origin, Widget_origin__doc__, NULL},
    {"size", (getter)Widget_get_size, (setter)Widget_set_size, Widget_size__doc__, NULL},
    {"halign", (getter)Widget_get_halign, (setter)Widget_set_halign, Widget_halign__doc__, NULL},
    {"valign", (getter)Widget_get_valign, (setter)Widget_set_valign, Widget_valign__doc__, NULL},
    {"hexpand", (getter)Widget_get_hexpand, (setter)Widget_set_hexpand, Widget_hexpand__doc__, NULL},
    {"vexpand", (getter)Widget_get_vexpand, (setter)Widget_set_vexpand, Widget_vexpand__doc__, NULL},
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
