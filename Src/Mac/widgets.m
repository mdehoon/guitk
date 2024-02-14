#include <Python.h>
#include <Cocoa/Cocoa.h>
#include <string.h>
#include "widgets.h"
#include "window.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
#define COMPILING_FOR_10_6
#endif
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
#define COMPILING_FOR_10_7
#endif

#ifndef CGFloat
#define CGFloat float
#endif


@implementation WidgetView
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
    return PyUnicode_FromFormat("Widget object %p wrapping NSView %p",
                               self, view);
}

static void
Widget_dealloc(WidgetObject* self)
{
    NSView* view = self->view;
    if (view) [view release];
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Widget_place(WidgetObject* self, PyObject *args, PyObject *keywords)
{
    double x;
    double y;
    double width;
    double height;
    static char* kwlist[] = {"x", "y", "width", "height", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "dddd", kwlist,
                                     &x, &y, &width, &height))
        return NULL;

    if (self->halign!='f' || self->valign!='f') {
        CGFloat minimum_width, minimum_height;
        PyObject* item;
        PyObject* object = (PyObject*)self;
        PyObject* minimum_size = PyObject_GetAttrString(object, "minimum_size");
        if (minimum_size == NULL) return NULL;
        if (!PyTuple_Check(minimum_size)) {
            PyErr_SetString(PyExc_ValueError,
                "minimum_size should return a tuple.");
            return NULL;
        }
        if (PyTuple_GET_SIZE(minimum_size) != 2) {
            PyErr_SetString(PyExc_ValueError,
                "minimum_size should return a tuple of size 2.");
            return NULL;
        }
        item = PyTuple_GET_ITEM(minimum_size, 0);
        minimum_width = PyFloat_AsDouble(item);
        if (PyErr_Occurred()) {
            PyErr_SetString(PyExc_ValueError,
                "width returned by minimum_size should be numeric.");
            return NULL;
        }
        item = PyTuple_GET_ITEM(minimum_size, 1);
        minimum_height = PyFloat_AsDouble(item);
        if (PyErr_Occurred()) {
            PyErr_SetString(PyExc_ValueError,
                "height returned by minimum_size should be numeric.");
            return NULL;
        }
        Py_DECREF(minimum_size);

        switch (self->halign) {
            case 'f':
                break;
            case 'l':
                width = minimum_width;
                break;
            case 'c':
                x += 0.5 * (width - minimum_width);
                width = minimum_width;
                break;
            case 'r':
                x += width - minimum_width;
                width = minimum_width;
                break;
            default:
                PyErr_Format(PyExc_RuntimeError,
                             "halign should be 'f', 'l', 'c', or 'r' "
                             "(got '%d')", self->halign);
                return NULL;
        }
        switch (self->valign) {
            case 'f':
                break;
            case 't':
                height = minimum_height;
                break;
            case 'c':
                y += 0.5 * (height - minimum_height);
                height = minimum_height;
                break;
            case 'b':
                y += height - minimum_height;
                height = minimum_height;
                break;
            default:
                PyErr_Format(PyExc_RuntimeError,
                             "valign should be 'f', 't', 'c', or 'b' "
                             "(got '%d')", self->valign);
                return NULL;
        }
    }
    width += x;
    x = floor(x);
    width -= x;
    width = ceil(width);
    height += y;
    y = floor(y);
    height -= y;
    height = ceil(height);
    return Py_BuildValue("dddd", x, y, width, height);
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
    {"place",
     (PyCFunction)Widget_place,
     METH_KEYWORDS | METH_VARARGS,
     "Places the widget within its allocated space, taking halign and valign into account."
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
    if (!PyArg_ParseTuple(value, "ff", &x, &y)) return -1;
/*
    if (view == [[view window] contentView])
    {
        PyErr_SetString(PyExc_RuntimeError, "Top widget cannot be moved.");
        return -1;
    }
*/
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
    NSRect rect;
    NSView* view = self->view;
    if (!PyArg_ParseTuple(value, "dd", &width, &height)) return -1;
/*
    if (view == [[view window] contentView])
    {
        PyErr_SetString(PyExc_RuntimeError, "Top widget cannot be resized.");
        return -1;
    }
*/
    rect = view.frame;
    rect.size.width = width;
    rect.size.height = height;
    view.frame = rect;
    /* Use view.frame instead of [view setSize: size] to avoid listbox glitch */
    return 0;
}

static char Widget_size__doc__[] = "Widget size";

static PyObject* Widget_get_minimum_size(WidgetObject* self, void* closure)
{
    CGSize size = self->minimum_size;
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        PyObject* object = (PyObject*)self;
        PyObject* tuple;
        PyObject* item;
        double width, height;
        tuple = PyObject_CallMethod(object, "calculate_minimum_size", NULL);
        if (!tuple) return NULL;
        if (!PyTuple_Check(tuple)) {
            PyErr_SetString(PyExc_ValueError,
                "calculate_minimum_size must return a tuple.");
            Py_DECREF(tuple);
            return NULL;;
        }
        if (PyTuple_GET_SIZE(tuple) != 2) {
            PyErr_SetString(PyExc_ValueError,
                "calculate_minimum_size must return a tuple of size 2.");
            Py_DECREF(tuple);
            return NULL;;
        }
        item = PyTuple_GET_ITEM(tuple, 0);
        width = PyFloat_AsDouble(item);
        if (PyErr_Occurred()) {
            PyErr_SetString(PyExc_ValueError,
                "width returned by calculate_minimum_size must be numeric.");
            Py_DECREF(tuple);
            return NULL;
        }
        item = PyTuple_GET_ITEM(tuple, 1);
        height = PyFloat_AsDouble(item);
        if (PyErr_Occurred()) {
            PyErr_SetString(PyExc_ValueError,
                "height returned by calculate_minimum_size must be numeric.");
            Py_DECREF(tuple);
            return NULL;
        }
        size.width = width;
        size.height = height;
        self->minimum_size = size;
    }
    return Py_BuildValue("ff", size.width, size.height);
}

static char Widget_minimum_size__doc__[] = "Minimum size requested by widget";

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
            PyErr_Format(PyExc_RuntimeError,
                         "halign should be 'f', 'l', 'c', or 'r' (got '%d')",
                         c);
            return NULL;
    }
    return PyUnicode_FromString(s);
}

static int Widget_set_halign(WidgetObject* self, PyObject* value, void* closure)
{
    NSView* view;
    Window* window;
    char halign = '\0';
    value = PyUnicode_AsASCIIString(value);
    if (!value) return -1;
    const char* argument = PyBytes_AS_STRING(value);
    if (!argument) return -1;
    if (strcmp(argument, "LEFT")==0) halign = 'l';
    else if (strcmp(argument, "RIGHT")==0) halign = 'r';
    else if (strcmp(argument, "CENTER")==0) halign = 'c';
    else if (strcmp(argument, "FILL")==0) halign = 'f';
    else {
        PyErr_SetString(PyExc_ValueError, "argument should be 'FILL', 'LEFT', 'CENTER', or 'RIGHT'.");
    }
    Py_DECREF(argument);
    if (halign == '\0') return -1;
    if (self->halign == halign) return 0;
    self->halign = halign;
    view = self->view;
    window = (Window*) [view window];
    [window requestLayout];
    view.needsDisplay = YES;
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
            PyErr_Format(PyExc_RuntimeError,
                         "valign should be 'f', 't', 'c', or 'b' (got '%d')",
                         c);
            return NULL;
    }
    return PyUnicode_FromString(s);
}

static int Widget_set_valign(WidgetObject* self, PyObject* value, void* closure)
{
    NSView* view;
    Window* window;
    char valign = '\0';
    value = PyUnicode_AsASCIIString(value);
    if (!value) return -1;
    const char* argument = PyBytes_AS_STRING(value);
    if (!argument) return -1;
    if (strcmp(argument, "TOP")==0) valign = 't';
    else if (strcmp(argument, "BOTTOM")==0) valign = 'b';
    else if (strcmp(argument, "CENTER")==0) valign = 'c';
    else if (strcmp(argument, "FILL")==0) valign = 'f';
    else {
        PyErr_SetString(PyExc_ValueError, "argument should be 'FILL', 'TOP', 'CENTER', or 'BOTTOM'.");
    }
    Py_DECREF(argument);
    if (valign == '\0') return -1;
    if (self->valign == valign) return 0;
    self->valign = valign;
    view = self->view;
    window = (Window*) [view window];
    [window requestLayout];
    view.needsDisplay = YES;
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
    NSView* view;
    Window* window;
    const int flag = PyObject_IsTrue(value);
    if (flag) {
        if (self->hexpand) return 0;
        self->hexpand = YES;
    }
    else {
        if (!self->hexpand) return 0;
        self->hexpand = NO;
    }
    view = self->view;
    window = (Window*) [view window];
    [window requestLayout];
    view.needsDisplay = YES;
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
    NSView* view;
    Window* window;
    const int flag = PyObject_IsTrue(value);
    if (flag) {
        if (self->vexpand) return 0;
        self->vexpand = YES;
    }
    else {
        if (!self->vexpand) return 0;
        self->vexpand = NO;
    }
    view = self->view;
    window = (Window*) [view window];
    [window requestLayout];
    view.needsDisplay = YES;
    return 0;
}

static char Widget_vexpand__doc__[] = "Widget should expand vertically";

static PyGetSetDef Widget_getset[] = {
    {"origin", (getter)Widget_get_origin, (setter)Widget_set_origin, Widget_origin__doc__, NULL},
    {"size", (getter)Widget_get_size, (setter)Widget_set_size, Widget_size__doc__, NULL},
    {"minimum_size", (getter)Widget_get_minimum_size, NULL, Widget_minimum_size__doc__, NULL},
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
