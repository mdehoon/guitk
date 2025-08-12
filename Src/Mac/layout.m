#include <Python.h>
#include <Cocoa/Cocoa.h>
#include "layout.h"
#include "window.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10100
#define COMPILING_FOR_10_10
#endif


@interface LayoutView : WidgetView
@end

@implementation LayoutView
- (void)drawRect:(NSRect)dirtyRect
{
    CGContextRef cr;
    NSGraphicsContext* gc;
    short red, green, blue, alpha;
    CGRect rect;
    LayoutObject* layout = (LayoutObject*)self.object;
    gc = [NSGraphicsContext currentContext];
#ifdef COMPILING_FOR_10_10
    cr = gc.CGContext;
#else
    cr = (CGContextRef) [gc graphicsPort];
#endif
    red = layout->background->rgba[0];
    green = layout->background->rgba[1];
    blue = layout->background->rgba[2];
    alpha = layout->background->rgba[3];
    CGContextSetRGBFillColor(cr, red/255., green/255., blue/255., alpha/255.);
    rect = NSRectToCGRect(dirtyRect);
    CGContextFillRect(cr, rect);
    [super drawRect:dirtyRect];
}
@end

static PyObject*
Layout_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    WidgetObject* widget;
    LayoutView* view;
    NSRect rect = NSZeroRect;
    Py_ssize_t index;
    Py_ssize_t length;

    if (!PyArg_ParseTuple(args, "n", &length)) return NULL;

    LayoutObject *self = (LayoutObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    self->status = COREGUI_LAYOUT_VALID;
    view = [[LayoutView alloc] initWithFrame:rect];
    view.autoresizesSubviews = NO;
    widget = (WidgetObject*)self;
    widget->view = view;
    view.object = widget;
    Py_INCREF(systemWindowBackgroundColor);
    self->background = systemWindowBackgroundColor;
    for (index = 0; index < length; index++) {
        WidgetView* subview = [[WidgetView alloc] initWithFrame: NSZeroRect];
        subview.hidden = YES;
        [view addSubview: subview];
    }
    return (PyObject*)self;
}

static PyObject*
Layout_repr(LayoutObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    WidgetView* view = widget->view;
    return PyUnicode_FromFormat("Layout object %p wrapping NSView %p",
                                self, view);
}

static void
Layout_dealloc(LayoutObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    NSView* view = widget->view;
fprintf(stderr, "Deallocating layout %p with view %p\n", widget, view);
    /* FIXME deallocate subviews */
    if (view) [view release];
    Py_DECREF(self->background);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static Py_ssize_t Layout_length(LayoutObject* self)
{
    Py_ssize_t length;
    WidgetObject* widget = (WidgetObject*)self;
    WidgetView* view = widget->view;
    if (!view) {
        PyErr_SetString(PyExc_RuntimeError, "layout has not been initialized");
        return -1;
    }
    length = view.subviews.count;
    return length;
}

static PyObject*
Layout_subscript(LayoutObject* self, PyObject* key)
{
    Py_ssize_t length;
    WidgetObject* widget = (WidgetObject*)self;
    WidgetView* view = widget->view;
    if (!view) {
        PyErr_SetString(PyExc_RuntimeError, "layout has not been initialized");
        return NULL;
    }
    length = view.subviews.count;
    if (PyIndex_Check(key)) {
        Py_ssize_t index = PyNumber_AsSsize_t(key, PyExc_IndexError);
        if (index == -1 && PyErr_Occurred())
            return NULL;
        if (index < 0)
            index += length;
        if (index < 0 || index >= length) {
            PyErr_SetString(PyExc_IndexError, "index out of range");
            return NULL;
        }
        view = (WidgetView*) [view.subviews objectAtIndex: index];
        if (view.isHidden) widget = (WidgetObject *)Py_None;
        else widget = view.object;
        Py_INCREF((PyObject*)widget);
        return (PyObject*) widget;
    }
    else if (PySlice_Check(key)) {
        Py_ssize_t i, index;
        Py_ssize_t start, stop, step, slicelength;
        if (PySlice_GetIndicesEx(key, length, &start, &stop, &step,
                                 &slicelength) == -1) return NULL;
        if (slicelength == 0) return PyList_New(0);
        else {
            PyObject* result = PyList_New(slicelength);
            if (!result) return PyErr_NoMemory();
            for (i = 0, index = start; i < slicelength; i++, index += step) {
                view = (WidgetView*) [view.subviews objectAtIndex: index];
                if (view.isHidden) widget = (WidgetObject *)Py_None;
                else widget = view.object;
                Py_INCREF((PyObject*) widget);
                PyList_SET_ITEM(result, i, (PyObject*)widget);
            }
            return result;
        }
    }
    else {
        PyErr_Format(PyExc_TypeError,
                     "indices must be integers, not %S",
                     Py_TYPE(key));
        return NULL;
    }
}


static int _set_widget(NSView* view, Py_ssize_t index, PyObject* value)
{
    WidgetObject* widget = NULL;
    NSView *old_view, *new_view;
    if (PyType_IsSubtype(Py_TYPE(value), &WidgetType)) {
        widget = (WidgetObject *)value;
        new_view = (NSView*) widget->view;
        if (new_view.superview) {
            PyErr_SetString(PyExc_ValueError,
                "widget is already used in a layout; "
                "remove it before using it in a different layout");
            return -1;
        }
    }
    else if (value == Py_None) {
        new_view = [[NSView alloc] initWithFrame: NSZeroRect];
        new_view.hidden = YES;
    }
    else {
        PyErr_SetString(PyExc_ValueError,
                        "value must be a widget or None");
        return -1;
    }
    old_view = [view.subviews objectAtIndex: index];
    if (old_view.isHidden) {
        Py_DECREF(Py_None);
        [view replaceSubview: old_view with: new_view];
        if (widget) Layout_request(widget);
    }
    else {
        widget = ((WidgetView*)old_view).object;
        Layout_request(widget);
        [view replaceSubview: old_view with: new_view];
        Py_DECREF(widget);
    }
    new_view.needsDisplay = YES;
    Py_INCREF(value);
    return 0;
}

static int
Layout_ass_subscript(LayoutObject* self, PyObject* key, PyObject* value)
{
    Py_ssize_t index, length;
    LayoutView* view = (LayoutView*) self->widget.view;
    if (!view) {
        PyErr_SetString(PyExc_RuntimeError, "layout has not been initialized");
        return -1;
    }
    length = view.subviews.count;
    if (PyIndex_Check(key)) {
        Py_ssize_t index = PyNumber_AsSsize_t(key, PyExc_IndexError);
        if (index == -1 && PyErr_Occurred())
            return -1;
        if (index < 0)
            index += length;
        if (index < 0 || index >= length) {
            PyErr_SetString(PyExc_IndexError, "index out of range");
            return -1;
        }
        if (_set_widget(view, index, value) == -1) return -1;
    }
    else if (PySlice_Check(key)) {
        Py_ssize_t start, stop, step, slicelength;
        PyObject *iterator;
        if (PySlice_GetIndicesEx(key, length, &start, &stop, &step,
                                 &slicelength) == -1) return -1;
        iterator = PyObject_GetIter(value);
        if (iterator == NULL) {
            PyErr_SetString(PyExc_TypeError, "can only assign an iterable");
            return -1;
        }
        for (index = start; index < slicelength; index += step) {
            PyObject* object = PyIter_Next(iterator);
            if (object == NULL) {
                if (!PyErr_Occurred())
                    PyErr_SetString(PyExc_ValueError, "insufficient widgets");
                Py_DECREF(iterator);
                return -1;
            }
            if (_set_widget(view, index, object) == -1) {
                Py_DECREF(iterator);
                return -1;
            }
        }
    }
    else {
        PyErr_Format(PyExc_TypeError,
                     "indices must be integers or slices, not %S",
                     Py_TYPE(key));
        return -1;
    }
    return 0;
}

static PyMappingMethods Layout_mapping = {
    (lenfunc)Layout_length,           /* mp_length */
    (binaryfunc)Layout_subscript,     /* mp_subscript */
    (objobjargproc)Layout_ass_subscript,     /* mp_ass_subscript */
};

Py_LOCAL_SYMBOL void Layout_request(WidgetObject* object)
{
    LayoutObject* layout;
    WidgetView* view = object->view;
    NSView* contentView = view.window.contentView;
fprintf(stderr, "In Layout_request, view = %p, contentView = %p, superview = %p\n", view, contentView, view.superview);
    if (view == contentView) return;
    view = (WidgetView*) view.superview;
    if (!view) return;
    layout = (LayoutObject*) view.object;
    if (layout->status == COREGUI_LAYOUT_INVALID) {
        fprintf(stderr, "Layout_request, in begin, found layout %p with view %p already marked\n", layout, view);
        return;
    }
    layout->status = COREGUI_LAYOUT_INVALID;
fprintf(stderr, "In Layout_request, setting COREGUI_LAYOUT_INVALID for layout %p with view = %p\n", layout, view);
    while (view != contentView) {
        view = (WidgetView*) view.superview;
        if (!view) break;
        layout = (LayoutObject*) view.object;
        if (layout->status == COREGUI_LAYOUT_CHILDREN_INVALID) {
            fprintf(stderr, "Layout_request, in loop, found layout %p already marked COREGUI_LAYOUT_CHILDREN_INVALID\n", layout);
            break;
        }
fprintf(stderr, "In Layout_request, setting COREGUI_LAYOUT_CHILDREN_INVALID for layout %p with view = %p\n", layout, view);
        layout->status = COREGUI_LAYOUT_CHILDREN_INVALID;
    }
}

Py_LOCAL_SYMBOL void Layout_notify_window_resized(WidgetObject* object)
{
fprintf(stderr, "In Layout_notify_window_resized, widget = %p\n", object); fflush(stderr);
    PyGILState_STATE gstate = PyGILState_Ensure();
    int is_layout = PyType_IsSubtype(Py_TYPE(object), &LayoutType);
    PyGILState_Release(gstate);
    if (is_layout) {
fprintf(stderr, "In Layout_notify_window_resized, widget is a layout\n"); fflush(stderr);
        LayoutObject* layout = (LayoutObject*)object;
        layout->status = COREGUI_LAYOUT_INVALID;
    }
    else
fprintf(stderr, "In Layout_notify_window_resized, widget is not a layout\n"); fflush(stderr);
}




static void walk(LayoutObject* self)
{
fprintf(stderr, "In walk for layout %p with view %p; status = %d\n", self, ((WidgetObject*)self)->view, self->status);
    if (self->status == COREGUI_LAYOUT_VALID) return;
    else if (self->status == COREGUI_LAYOUT_INVALID) {
        WidgetView* view = ((WidgetObject*)self)->view;
        CGFloat x = view.frame.origin.x;
        CGFloat y = view.frame.origin.y;
        CGFloat width = view.frame.size.width;
        CGFloat height = view.frame.size.height;
fprintf(stderr, "In walk for layout %p with view %p; setting status from %d to COREGUI_LAYOUT_VALID\n", self, ((WidgetObject*)self)->view, self->status);
        self->status = COREGUI_LAYOUT_VALID;
        PyGILState_STATE gstate = PyGILState_Ensure();
        PyObject* result = PyObject_CallMethod((PyObject *)self, "place", "dddd",
                                               x, y, width, height, NULL);
        if (result) Py_DECREF(result);
        else PyErr_Print();
        PyGILState_Release(gstate);
    }
    else if (self->status == COREGUI_LAYOUT_CHILDREN_INVALID) {
        NSView* view;
        WidgetObject* widget = (WidgetObject*)self;
fprintf(stderr, "In walk for layout %p with view %p; setting status from %d to COREGUI_LAYOUT_VALID\n", self, ((WidgetObject*)self)->view, self->status);
        self->status = COREGUI_LAYOUT_VALID;
        for (view in widget->view.subviews) {
            WidgetObject* object = ((WidgetView*)view).object;
            walk((LayoutObject*) object);
        }
    }
}

Py_LOCAL_SYMBOL void Layout_update(WidgetObject* object)
{
    int is_layout;
    PyGILState_STATE gstate = PyGILState_Ensure();
    is_layout = PyType_IsSubtype(Py_TYPE(object), &LayoutType);
    PyGILState_Release(gstate);
    if (!is_layout) return;
    walk((LayoutObject*)object);
}

static PyObject* Layout_place(LayoutObject* self, PyObject* args, PyObject* keywords)
{
    fprintf(stderr, "In Layout_place for layout object %p wrapping view %p; status is %d\n", self, ((WidgetObject*)self)->view, self->status);
    self->status = COREGUI_LAYOUT_VALID;
    return Widget_place((WidgetObject*)self, args, keywords);
}

static PyMethodDef Layout_methods[] = {
    {"place",
     (PyCFunction)Layout_place,
     METH_KEYWORDS | METH_VARARGS,
     "Places the layout in its assigned space, calculates the position and size of its subviews in the assigned space, and calls place on each subview. This method must be implemented in the derived class."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Layout_get_status(LayoutObject* self, void* closure)
{
    if (self->status == COREGUI_LAYOUT_VALID) return PyUnicode_FromString("COREGUI_LAYOUT_VALID");
    if (self->status == COREGUI_LAYOUT_INVALID) return PyUnicode_FromString("COREGUI_LAYOUT_INVALID");
    if (self->status == COREGUI_LAYOUT_CHILDREN_INVALID) return PyUnicode_FromString("COREGUI_LAYOUT_CHILDREN_INVALID");
    return NULL;
}

static PyObject* Layout_get_size(WidgetObject* self, void* closure)
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

static int Layout_set_size(LayoutObject* self, PyObject* value, void* closure)
{
    double width;
    double height;
    NSSize size;
    WidgetObject* widget = (WidgetObject*)self;
    if (!PyArg_ParseTuple(value, "dd", &width, &height)) return -1;
/*
    Window* window = (Window*) [view window];
    if (view == [window contentView])
    {
        PyErr_SetString(PyExc_RuntimeError, "Top widget cannot be resized.");
        return -1;
    }
*/
    size.width = width;
    size.height = height;
    [widget->view setFrameSize: size];
    return 0;
}

static char Layout_size__doc__[] = "Layout size";

static PyObject* Layout_get_background(LayoutObject* self, void* closure)
{
    Py_INCREF(self->background);
    return (PyObject*) self->background;
}

static int
Layout_set_background(LayoutObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LayoutView* layout = (LayoutView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    self->background = (ColorObject*) value;
    layout.needsDisplay = YES;
    return 0;
}

static char Layout_background__doc__[] = "background color.";

static PyGetSetDef Layout_getset[] = {
    {"status", (getter)Layout_get_status, NULL, NULL, NULL},
    {"size", (getter)Layout_get_size, (setter)Layout_set_size, Layout_size__doc__, NULL},
    {"background", (getter)Layout_get_background, (setter)Layout_set_background, Layout_background__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Layout_doc[] =
"Layout is the base class for layout managers.\n";

Py_LOCAL_SYMBOL PyTypeObject LayoutType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "gui.Layout",
    .tp_basicsize = sizeof(LayoutObject),
    .tp_dealloc = (destructor)Layout_dealloc,
    .tp_repr = (reprfunc)Layout_repr,
    .tp_as_mapping = &Layout_mapping,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_doc = Layout_doc,
    .tp_methods = Layout_methods,
    .tp_getset = Layout_getset,
    .tp_base = &WidgetType,
    .tp_new = Layout_new,
};
