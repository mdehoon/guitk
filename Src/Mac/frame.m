#include <Python.h>
#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "window.h"
#include "colors.h"


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

@interface FrameView : NSBox
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (FrameView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object;
- (BOOL)isFlipped;
- (void)viewWillDraw;
- (void)drawRect:(NSRect)rect;
@end

typedef struct {
    WidgetObject widget;
    CGColorRef background;
} FrameObject;

PyTypeObject FrameType;

@implementation FrameView
@synthesize object = _object;

- (FrameView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object
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

- (void)drawRect:(NSRect)dirtyRect
{
    CGContextRef cr;
    NSGraphicsContext* gc;
    CGRect rect;
    FrameObject* object = (FrameObject*)_object;
    gc = [NSGraphicsContext currentContext];
#ifdef COMPILING_FOR_10_10
    cr = [gc CGContext];
#else
    cr = (CGContextRef) [gc graphicsPort];
#endif
    CGContextSetFillColorWithColor(cr, object->background);
    rect = NSRectToCGRect(dirtyRect);
    CGContextFillRect(cr, rect);
    [super drawRect:dirtyRect];
}
@end

static PyObject*
Frame_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    PyObject* object;
    WidgetObject* widget;
    NSRect rect = NSZeroRect;
    NSColor* color = [NSColor lightGrayColor];
    CGFloat gray;
    CGFloat alpha;
    [color getWhite: &gray alpha: &alpha];
    FrameObject *self = (FrameObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    object = (PyObject*)self;
    widget = (WidgetObject*)self;
    widget->view = [[FrameView alloc] initWithFrame:rect withObject:object];
    self->background = CGColorCreateGenericGray(gray, alpha);
    return object;
}

static PyObject*
Frame_repr(FrameObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    NSView* view = widget->view;
#if PY3K
    return PyUnicode_FromFormat("Frame object %p wrapping NSView %p",
                               self, view);
#else
    return PyString_FromFormat("Frame object %p wrapping NSView %p",
                                self, view);
#endif
}

static void
Frame_dealloc(FrameObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    NSView* view = widget->view;
    if (view) [view release];
    CGColorRelease(self->background);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Frame_add(FrameObject* self, PyObject *args)
{
    Window* window;
    NSView* view;
    WidgetObject* widget = (WidgetObject*)self;
    NSView* frame = widget->view;
    if (!frame) {
        PyErr_SetString(PyExc_RuntimeError, "frame has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "O!", &WidgetType, &widget))
        return NULL;

    view = widget->view;
    [frame addSubview: view];
    window = (Window*) [view window];
    [window requestLayout];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject* Frame_layout(FrameObject* self)
{
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Frame_methods[] = {
    {"add",
     (PyCFunction)Frame_add,
     METH_VARARGS,
     "Adds a widget to the layout manager."
    },
    {"layout",
     (PyCFunction)Frame_layout,
     METH_NOARGS,
     "Default method (no-op)."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Frame_get_size(WidgetObject* self, void* closure)
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

static int Frame_set_size(FrameObject* self, PyObject* value, void* closure)
{
    PyObject* result;
    PyGILState_STATE gstate;
    double width;
    double height;
    NSSize size;
    WidgetObject* widget = (WidgetObject*)self;
    NSView* view = widget->view;
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
    gstate = PyGILState_Ensure();
    result = PyObject_CallMethod((PyObject*)self, "layout", NULL);
    if (result)
        Py_DECREF(result);
    else
        PyErr_Print();
    PyGILState_Release(gstate);
    return 0;
}

static char Frame_size__doc__[] = "Frame size";

static PyObject* Frame_get_background(FrameObject* self, void* closure)
{
    const CGFloat* components = CGColorGetComponents(self->background);
    double red, green, blue, alpha;
    red = components[0];
    green = components[1];
    blue = components[2];
    alpha = components[3];
    return Py_BuildValue("ffff", red, green, blue, alpha);
}

static int
Frame_set_background(FrameObject* self, PyObject* value, void* closure)
{
    short rgba[4];
    CGFloat components[4];
    CGColorRef background;
    CGColorSpaceRef colorspace;
    WidgetObject* widget = (WidgetObject*) self;
    NSView* view = widget->view;
    if (!Color_converter(value, rgba)) return -1;
    CGColorRelease(self->background);
    colorspace = CGColorSpaceCreateDeviceRGB();
    components[0] = rgba[0] / 255.;
    components[1] = rgba[1] / 255.;
    components[2] = rgba[2] / 255.;
    components[3] = rgba[3] / 255.;
    background = CGColorCreate(colorspace, components);
    CGColorSpaceRelease(colorspace);
    self->background = background;
    view.needsDisplay = YES;
    return 0;
}

static char Frame_background__doc__[] = "background color.";

static PyObject* Frame_get_minimum_size(FrameObject* self, void* closure)
{
    PyObject* minimum_size = Py_BuildValue("ff", 0, 0);
    return minimum_size;
}

static char Frame_minimum_size__doc__[] = "minimum size needed to show the frame.";

static PyGetSetDef Frame_getset[] = {
    {"size", (getter)Frame_get_size, (setter)Frame_set_size, Frame_size__doc__, NULL},
    {"minimum_size", (getter)Frame_get_minimum_size, (setter)NULL, Frame_minimum_size__doc__, NULL},
    {"background", (getter)Frame_get_background, (setter)Frame_set_background, Frame_background__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Frame_doc[] = "Frame.\n";

PyTypeObject FrameType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "gui.Frame",               /* tp_name */
    sizeof(FrameObject),       /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Frame_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Frame_repr,      /* tp_repr */
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
    Frame_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Frame_methods,             /* tp_methods */
    0,                          /* tp_members */
    Frame_getset,              /* tp_getset */
    &WidgetType,                /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    0,                          /* tp_init */
    0,                          /* tp_alloc */
    Frame_new,                 /* tp_new */
};
