#include <Cocoa/Cocoa.h>
#include "widgets.h"

#if PY_MAJOR_VERSION >= 3
#define PY3K 1
#else
#if PY_MINOR_VERSION < 7
#error Python version should be 2.7 or newer
#else
#define PY3K 0
#endif
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10100
#define COMPILING_FOR_10_10
#endif

@interface Label : NSView <Widget>
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (Label*)initWithFrame:(NSRect)rect withObject:(PyObject*)object;
- (BOOL)isFlipped;
- (void)drawRect:(NSRect)rect;
@end

typedef struct {
    PyObject_HEAD
    Label* label;
    CGColorRef background;
    CFStringRef text;
    NSFont* font;
} LabelObject;

@implementation Label
- (PyObject*)object
{
    return (PyObject*)_object;
}

- (Label*)initWithFrame:(NSRect)rect withObject:(PyObject*)object
{
    self = [super initWithFrame: rect];
    _object = object;
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    CTLineRef line;
    CFAttributedStringRef string = NULL;
    CFDictionaryRef attributes = NULL;
    CFStringRef keys[1];
    CFTypeRef values[1];
    CGContextRef cr;
    NSGraphicsContext* gc;
    CGFloat x;
    CGFloat y;
    CGSize size;
    CGRect rect;
    CGFloat ascent;
    CGFloat descent;
    double width;
    CGFloat height;
    LabelObject* object = (LabelObject*)_object;
    gc = [NSGraphicsContext currentContext];
#ifdef COMPILING_FOR_10_10
    cr = [gc CGContext];
#else
    cr = (CGContextRef) [gc graphicsPort];
#endif
    CGContextSetFillColorWithColor(cr, object->background);
    rect = NSRectToCGRect(dirtyRect);
    CGContextFillRect(cr, rect);
    keys[0] = kCTFontAttributeName;
    values[0] = object->font;
    values[0] = [NSFont systemFontOfSize: 13.0];
    attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                    (const void**)&keys,
                                    (const void**)&values,
                                    1,
                                    &kCFTypeDictionaryKeyCallBacks,
                                    &kCFTypeDictionaryValueCallBacks);
    if (!attributes) return;
    string = CFAttributedStringCreate(kCFAllocatorDefault,
                                      object->text,
                                      attributes);
    CFRelease(attributes);
    if (!string) return;
    line = CTLineCreateWithAttributedString(string);
    CFRelease(string);
    rect = NSRectToCGRect(self.frame);
    size = rect.size;
    y = 0.5 * size.height;
    x = 0.5 * size.width;
    rect = CTLineGetImageBounds(line, cr);
    width = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
    height = ascent + descent;
    x -= 0.5 * width;
    y += 0.5 * height;
    y -= descent;
    CGAffineTransform transform = CGAffineTransformMakeScale (1.0, -1.0); 
    CGContextSetTextMatrix(cr, transform);
    CGContextSetTextPosition(cr, x, y);
    CTLineDraw(line, cr);
    CFRelease(line);
}

- (BOOL)isFlipped
{
    return YES;
}
@end

static PyObject*
Label_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    LabelObject *self = (LabelObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->label = NULL;
    return (PyObject*)self;
}

static int
Label_init(LabelObject *self, PyObject *args, PyObject *kwds)
{
    Label *label;
    const char* string = "";
    CGColorRef background;
    CFStringRef text;
    NSRect rect;
    NSFont* font;

    if(!PyArg_ParseTuple(args, "|s", &string)) return -1;

    rect.origin.x = 0;
    rect.origin.y = 0;
    rect.size.width = 100;
    rect.size.height = 100;
    label = [[Label alloc] initWithFrame: rect withObject: (PyObject*)self];
    font = [NSFont systemFontOfSize: 13.0];
    text = CFStringCreateWithCString(kCFAllocatorDefault, string, kCFStringEncodingUTF8);
    background = CGColorGetConstantColor(kCGColorClear);
    /* CGColorGetConstantColor returns the color with a reference count of 1 */
    [font retain];
    self->text = text;
    self->label = label;
    self->background = background;
    self->font = font;

    return 0;
}

static PyObject*
Label_repr(LabelObject* self)
{
#if PY3K
    return PyUnicode_FromFormat("Label object %p wrapping NSView %p",
                               (void*) self, (void*)(self->label));
#else
    return PyString_FromFormat("Label object %p wrapping NSView %p",
                               (void*) self, (void*)(self->label));
#endif
}

static void
Label_dealloc(LabelObject* self)
{
    [self->label release];
    [self->font release];
    CFRelease(self->text);
    CGColorRelease(self->background);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Label_set_position(LabelObject* self, PyObject *args)
{
    float x;
    float y;
    NSPoint position;
    Label* label = self->label;
    if (!label) {
        PyErr_SetString(PyExc_RuntimeError, "label has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ff", &x, &y))
        return NULL;

    position.x = x;
    position.y = y;
    [label setFrameOrigin: position];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Label_get_size(LabelObject* self, PyObject *args)
{
    float width;
    float height;
    NSRect frame;
    Label* label = self->label;
    if (!label) {
        PyErr_SetString(PyExc_RuntimeError, "label has not been initialized");
        return NULL;
    }
    frame = [label frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("ff", width, height);
}

static PyMethodDef Label_methods[] = {
    {"set_position",
     (PyCFunction)Label_set_position,
     METH_VARARGS,
     "Moves the label to the new position."
    },
    {"get_size",
     (PyCFunction)Label_get_size,
     METH_NOARGS,
     "Returns the size of the label."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Label_get_background(LabelObject* self, void* closure)
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
Label_set_background(LabelObject* self, PyObject* value, void* closure)
{
    Py_ssize_t i;
    PyObject* item;
    CGFloat rgba[4];
    CGColorRef background;
    CGColorSpaceRef colorspace;
    Label* label = self->label;
    if (!PyTuple_Check(value)) {
        PyErr_SetString(PyExc_TypeError, "expected a tuple");
        return -1;
    }
    if (PyTuple_GET_SIZE(value) != 4) {
        PyErr_SetString(PyExc_RuntimeError, "expected a tuple with 4 components");
        return -1;
    }
    for (i = 0; i < 4; i++) {
        item = PyTuple_GET_ITEM(value, i);
        rgba[i] = PyFloat_AsDouble(item);
        if (PyErr_Occurred()) {
            PyErr_SetString(PyExc_RuntimeError, "expected a tuple with 4 values");
            return -1;
        }
    }
    CGColorRelease(self->background);
    colorspace = CGColorSpaceCreateDeviceRGB();
    background = CGColorCreate(colorspace, rgba);
    CGColorSpaceRelease(colorspace);
    self->background = background;
    label.needsDisplay = YES;
    return 0;
}

static char Label_background__doc__[] = "background color.";

static PyGetSetDef Label_getseters[] = {
    {"background", (getter)Label_get_background, (setter)Label_set_background, Label_background__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Label_doc[] =
"A Label object wraps a Cocoa NSTextField object.\n";

PyTypeObject LabelType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Label",             /* tp_name */
    sizeof(LabelObject),        /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Label_dealloc,  /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Label_repr,       /* tp_repr */
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
    Label_doc,                  /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Label_methods,              /* tp_methods */
    0,                          /* tp_members */
    Label_getseters,            /* tp_getset */
    &WidgetType,                /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Label_init,       /* tp_init */
    0,                          /* tp_alloc */
    Label_new,                  /* tp_new */
};
