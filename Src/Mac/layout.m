#include <Python.h>
#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "window.h"
#include "colors.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10100
#define COMPILING_FOR_10_10
#endif


@interface LayoutView : NSView
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (LayoutView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object;
- (BOOL)isFlipped;
- (void)viewWillDraw;
- (void)drawRect:(NSRect)rect;
@end

typedef struct {
    WidgetObject widget;
    CGColorRef background;
} LayoutObject;

PyTypeObject LayoutType;

@implementation LayoutView
@synthesize object = _object;

- (LayoutView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object
{
    self = [super initWithFrame: rect];
    self.autoresizesSubviews = NO;
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
    LayoutObject* object = (LayoutObject*)_object;
    gc = [NSGraphicsContext currentContext];
#ifdef COMPILING_FOR_10_10
    cr = gc.CGContext;
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
Layout_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    PyObject* object;
    WidgetObject* widget;
    NSRect rect = NSZeroRect;
    NSColor* color = [NSColor lightGrayColor];
    CGFloat gray;
    CGFloat alpha;
    [color getWhite: &gray alpha: &alpha];
    LayoutObject *self = (LayoutObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    object = (PyObject*)self;
    widget = (WidgetObject*)self;
    widget->view = [[LayoutView alloc] initWithFrame:rect withObject:object];
    self->background = CGColorCreateGenericGray(gray, alpha);
    
    return object;
}

static PyObject*
Layout_repr(LayoutObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    NSView* view = widget->view;
    return PyUnicode_FromFormat("Layout object %p wrapping NSView %p",
                               self, view);
}

static void
Layout_dealloc(LayoutObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    NSView* view = widget->view;
    if (view) [view release];
    CGColorRelease(self->background);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Layout_add(LayoutObject* self, PyObject *args)
{
    Window* window;
    NSView* view;
    WidgetObject* widget = (WidgetObject*)self;
    NSView* layout = widget->view;
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

static PyObject* Layout_layout(LayoutObject* self)
{
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Layout_methods[] = {
    {"add",
     (PyCFunction)Layout_add,
     METH_VARARGS,
     "Adds a widget to the layout manager."
    },
    {"layout",
     (PyCFunction)Layout_layout,
     METH_NOARGS,
     "Default method (no-op)."
    },
    {NULL}  /* Sentinel */
};

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
    PyObject* result;
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
    PyGILState_STATE gstate;
    gstate = PyGILState_Ensure();
    result = PyObject_CallMethod((PyObject*)self, "layout", NULL);
    if (result)
        Py_DECREF(result);
    else
        PyErr_Print();
    PyGILState_Release(gstate);
    return 0;
}

static char Layout_size__doc__[] = "Layout size";

static PyObject* Layout_get_background(LayoutObject* self, void* closure)
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
Layout_set_background(LayoutObject* self, PyObject* value, void* closure)
{
    short rgba[4];
    CGFloat components[4];
    CGColorRef background;
    CGColorSpaceRef colorspace;
    WidgetObject* widget = (WidgetObject*) self;
    NSView* layout = widget->view;
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
    layout.needsDisplay = YES;
    return 0;
}

static char Layout_background__doc__[] = "background color.";

static PyGetSetDef Layout_getset[] = {
    {"size", (getter)Layout_get_size, (setter)Layout_set_size, Layout_size__doc__, NULL},
    {"background", (getter)Layout_get_background, (setter)Layout_set_background, Layout_background__doc__, NULL},
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
