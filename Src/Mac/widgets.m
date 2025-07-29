#include <Python.h>
#include <Cocoa/Cocoa.h>
#include <string.h>
#include "widgets.h"
#include "layout.h"
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
- (BOOL)isFlipped
{
    return YES;
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
    self->margin_left = 0;
    self->margin_right = 0;
    self->margin_top = 0;
    self->margin_bottom = 0;
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
    CGRect frame;

    static char* kwlist[] = {"x", "y", "width", "height", NULL};

    if (!PyArg_ParseTupleAndKeywords(args, keywords, "dddd", kwlist,
                                     &x, &y, &width, &height))
        return NULL;

    frame.origin.x = x;
    frame.origin.y = y;
    frame.size.width = width;
    frame.size.height = height;

    self->view.frame = frame;

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Widget_remove(WidgetObject* self)
{
    WidgetView* view = self->view;
    [view removeFromSuperview];
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

PyObject* Widget_get_minimum_size(WidgetObject* self, void* closure)
{
    CGSize size = self->minimum_size;
    if (size.width == 0 && size.height == 0) {
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

void Widget_unset_minimum_size(WidgetObject* widget)
{
    WidgetView* view = widget->view;
    WidgetView* top = (WidgetView*) view.window.contentView;
    while (true) {
        if (widget->minimum_size.width == 0
         && widget->minimum_size.height == 0) break;
        widget->minimum_size = CGSizeZero;
        if (view == top) break;
        view = (WidgetView *)view.superview;
        widget = view->object;
    }
}

static int
Widget_set_minimum_size(WidgetObject* self, PyObject* value, void* closure)
{
    if (value != Py_None) {
        PyErr_SetString(PyExc_ValueError, "value must be None.");
        return -1;
    }
    Widget_unset_minimum_size(self);
    return 0;
}

static char Widget_minimum_size__doc__[] = "Minimum size requested by widget. Setting the minimum size to None discards the cached minimum size on the widget and its ancestors, triggering a recalculation when the minimum size is requested.";

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
    WidgetView* view;
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
    WidgetView* view;
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
    WidgetView* view;
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
    WidgetView* view;
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
    view.needsDisplay = YES;
    return 0;
}

static char Widget_vexpand__doc__[] = "Widget should expand vertically";

static PyObject* Widget_get_margin_left(WidgetObject* self, void* closure)
{
    return PyFloat_FromDouble(self->margin_left);
}

static int
Widget_set_margin_left(WidgetObject* self, PyObject* value, void* closure)
{
    WidgetView* view;
    const CGFloat margin_left = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    if (margin_left < 0) {
        PyErr_SetString(PyExc_ValueError,
                        "margin_left must be non-negative");
        return -1;
    }
    self->margin_left = margin_left;
    Widget_unset_minimum_size(self);
    view = self->view;
    view.needsDisplay = YES;
    return 0;
}

static char Widget_margin_left__doc__[] = "margin on the left side of the widget.";

static PyObject* Widget_get_margin_right(WidgetObject* self, void* closure)
{
    return PyFloat_FromDouble(self->margin_right);
}

static int
Widget_set_margin_right(WidgetObject* self, PyObject* value, void* closure)
{
    WidgetView* view;
    const CGFloat margin_right = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    if (margin_right < 0) {
        PyErr_SetString(PyExc_ValueError,
                        "margin_right must be non-negative");
        return -1;
    }
    self->margin_right = margin_right;
    Widget_unset_minimum_size(self);
    view = self->view;
    view.needsDisplay = YES;
    return 0;
}

static char Widget_margin_right__doc__[] = "margin on the right side of the widget.";

static PyObject* Widget_get_margin_top(WidgetObject* self, void* closure)
{
    return PyFloat_FromDouble(self->margin_top);
}

static int
Widget_set_margin_top(WidgetObject* self, PyObject* value, void* closure)
{
    WidgetView* view;
    const CGFloat margin_top = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    if (margin_top < 0) {
        PyErr_SetString(PyExc_ValueError,
                        "margin_top must be non-negative");
        return -1;
    }
    self->margin_top = margin_top;
    Widget_unset_minimum_size(self);
    view = self->view;
    view.needsDisplay = YES;
    return 0;
}

static char Widget_margin_top__doc__[] = "margin on the top side of the widget.";

static PyObject* Widget_get_margin_bottom(WidgetObject* self, void* closure)
{
    return PyFloat_FromDouble(self->margin_bottom);
}

static int
Widget_set_margin_bottom(WidgetObject* self, PyObject* value, void* closure)
{
    WidgetView* view;
    const CGFloat margin_bottom = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    if (margin_bottom < 0) {
        PyErr_SetString(PyExc_ValueError,
                        "margin_bottom must be non-negative");
        return -1;
    }
    self->margin_bottom = margin_bottom;
    Widget_unset_minimum_size(self);
    view = self->view;
    view.needsDisplay = YES;
    return 0;
}

static char Widget_margin_bottom__doc__[] = "margin on the bottom side of the widget.";


static PyGetSetDef Widget_getset[] = {
    {"origin", (getter)Widget_get_origin, (setter)Widget_set_origin, Widget_origin__doc__, NULL},
    {"size", (getter)Widget_get_size, (setter)Widget_set_size, Widget_size__doc__, NULL},
    {"minimum_size", (getter)Widget_get_minimum_size, (setter)Widget_set_minimum_size, Widget_minimum_size__doc__, NULL},
    {"halign", (getter)Widget_get_halign, (setter)Widget_set_halign, Widget_halign__doc__, NULL},
    {"valign", (getter)Widget_get_valign, (setter)Widget_set_valign, Widget_valign__doc__, NULL},
    {"hexpand", (getter)Widget_get_hexpand, (setter)Widget_set_hexpand, Widget_hexpand__doc__, NULL},
    {"vexpand", (getter)Widget_get_vexpand, (setter)Widget_set_vexpand, Widget_vexpand__doc__, NULL},
    {"margin_left", (getter)Widget_get_margin_left, (setter)Widget_set_margin_left, Widget_margin_left__doc__, NULL},
    {"margin_right", (getter)Widget_get_margin_right, (setter)Widget_set_margin_right, Widget_margin_right__doc__, NULL},
    {"margin_top", (getter)Widget_get_margin_top, (setter)Widget_set_margin_top, Widget_margin_top__doc__, NULL},
    {"margin_bottom", (getter)Widget_get_margin_bottom, (setter)Widget_set_margin_bottom, Widget_margin_bottom__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Widget_doc[] =
"Widget is the base class for objects wrapping a Cocoa NSView.\n";

Py_LOCAL_SYMBOL PyTypeObject WidgetType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "gui.Widget",
    .tp_basicsize = sizeof(WidgetObject),
    .tp_dealloc = (destructor)Widget_dealloc,
    .tp_repr = (reprfunc)Widget_repr,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_doc = Widget_doc,
    .tp_methods = Widget_methods,
    .tp_getset = Widget_getset,
    .tp_new = Widget_new,
};
