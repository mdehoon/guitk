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
- (void)drawRect:(NSRect)rect;
@end

typedef struct {
    WidgetObject widget;
    PyObject* content;
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
    NSBox* box;
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
    box = [[FrameView alloc] initWithFrame:rect withObject:object];
    box.borderType = NSBezelBorder;
    box.title = @"";
    box.titlePosition = NSAtBottom;
    Py_INCREF(Py_None);
    self->content = Py_None;
    self->background = CGColorCreateGenericGray(gray, alpha);
    widget = (WidgetObject*)self;
    widget->view = box;
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
    Py_DECREF(self->content);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyMethodDef Frame_methods[] = {
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
    printf("To be implemented: layout in Frame_set_size\n");
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
    double width;
    double height;
    PyObject* minimum_size;
    PyObject* content;
    WidgetObject* widget = (WidgetObject*)self;
    NSBox* box = (NSBox*) (widget->view);
    NSSize margins = [box contentViewMargins];
    width = margins.width;
    height = margins.height;
    content = self->content;
    if (content != Py_None) {
        PyObject* item;
        minimum_size = PyObject_GetAttrString(content, "minimum_size");
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
        width += PyFloat_AsDouble(item);
        if (PyErr_Occurred()) {
            PyErr_SetString(PyExc_ValueError,
                "width returned by minimum_size should be numeric.");
            return NULL;
        }
        item = PyTuple_GET_ITEM(minimum_size, 1);
        height += PyFloat_AsDouble(item);
        if (PyErr_Occurred()) {
            PyErr_SetString(PyExc_ValueError,
                "height returned by minimum_size should be numeric.");
            return NULL;
        }
        Py_DECREF(minimum_size);
    }
    minimum_size = Py_BuildValue("dd", width, height);
    return minimum_size;
}

static char Frame_minimum_size__doc__[] = "minimum size needed to show the frame.";

static PyObject* Frame_get_content(FrameObject* self, void* closure)
{
    PyObject* object = self->content;
    Py_INCREF(object);
    return object;
}

static int
Frame_set_content(FrameObject* self, PyObject* value, void* closure)
{
    PyTypeObject* type;
    WidgetObject* widget;
    NSBox* box;
    Window* window;
    NSView* view;
    type = Py_TYPE(value);
    if (!PyType_IsSubtype(type, &WidgetType)) {
        PyErr_SetString(PyExc_ValueError, "expected a widget or None");
        return -1;
    }
    widget = (WidgetObject*)value;
    view = widget->view;
    widget = (WidgetObject*)self;
    box = (NSBox*) widget->view;
    box.contentView = view;
    window = (Window*) [box window];
    [window requestLayout];
    Py_DECREF(self->content);
    Py_INCREF(value);
    self->content = value;
    return 0;
}

static char Frame_content__doc__[] = "frame content";

static PyGetSetDef Frame_getset[] = {
    {"size", (getter)Frame_get_size, (setter)Frame_set_size, Frame_size__doc__, NULL},
    {"minimum_size", (getter)Frame_get_minimum_size, (setter)NULL, Frame_minimum_size__doc__, NULL},
    {"content", (getter)Frame_get_content, (setter)Frame_set_content, Frame_content__doc__, NULL},
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
