#include <Cocoa/Cocoa.h>
#include "label.h"
#include "packed.h"

#if PY_MAJOR_VERSION >= 3
#define PY3K 1
#else
#if PY_MINOR_VERSION < 7
#error Python version should be 2.7 or newer
#else
#define PY3K 0
#endif
#endif

#define FILLX     1
#define FILLY     2
#define EXPAND    4
#define NORTH     8
#define EAST     16
#define SOUTH    32
#define WEST     64
#define TOP     128
#define BOTTOM  256
#define LEFT    512
#define RIGHT  1024



@implementation Label
- (Label*)initWithObject:(PyLabel*)obj
{
    NSRect rect;
    CGFloat fontsize;
    NSControlSize size = 12;
    rect.origin.x = 10;
    rect.origin.y = 10;
    rect.size.width = 100;
    rect.size.height = 100;
    self = [super initWithFrame: rect];
    [self setAutoresizingMask: NSViewMinXMargin
                             | NSViewWidthSizable
                             | NSViewMaxXMargin
                             | NSViewMinYMargin
                             | NSViewHeightSizable
                             | NSViewMaxYMargin];
    fontsize = [NSFont systemFontSizeForControlSize: size];
    fontsize = 50;
    font = [NSFont systemFontOfSize: fontsize];
    object = obj;
    return self;
}

- (void)setString:(const char*)s
{
    text = [[NSString alloc] initWithCString: s encoding: NSUTF8StringEncoding];
}

- (void)drawRect:(NSRect)rect
{
    static int counter = 0;
    if (counter==0) [[NSColor greenColor] setFill];
    else if (counter==1) [[NSColor blueColor] setFill];
    counter++;
    if (counter==2) counter = 0;
    NSRectFill(rect);
    CTLineRef line;
    CFAttributedStringRef string = NULL;
    CFDictionaryRef attributes = NULL;
    CFStringRef keys[1];
    CFTypeRef values[1];
    CGContextRef cr;
    NSGraphicsContext* gc;
    gc = [NSGraphicsContext currentContext];
/* Before 10.10:
    cr = (CGContextRef) [gc graphicsPort];
*/
    cr = [gc CGContext];
    keys[0] = kCTFontAttributeName;
    values[0] = font;
    attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                    (const void**)&keys,
                                    (const void**)&values,
                                    1,
                                    &kCFTypeDictionaryKeyCallBacks,
                                    &kCFTypeDictionaryValueCallBacks);
    if (!attributes) return;
    string = CFAttributedStringCreate(kCFAllocatorDefault,
                                      text,
                                      attributes);
    CFRelease(attributes);
    if (!string) return;
    line = CTLineCreateWithAttributedString(string);
    CFRelease(string);
    CGContextSetTextPosition(cr, position.x, position.y);
    CTLineDraw(line, cr);
    CFRelease(line);
}

- (CGRect)textbounds
{
    char data[8];
    CGRect rect;
    CGPoint point;
    CFStringRef keys[1];
    CFTypeRef values[1];
    CTLineRef line = NULL;
    CGContextRef cr = NULL;
    CFAttributedStringRef string = NULL;
    CFDictionaryRef attributes = NULL;
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
    if (colorspace) {
        cr = CGBitmapContextCreate(data,
                                   1,
                                   1,
                                   8,
                                   1,
                                   colorspace,
                                   0);
        CGColorSpaceRelease(colorspace);
    }
    if (cr) {
        keys[0] = kCTFontAttributeName;
        values[0] = font;
        attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                        (const void**)&keys,
                                        (const void**)&values,
                                        1,
                                        &kCFTypeDictionaryKeyCallBacks,
                                        &kCFTypeDictionaryValueCallBacks);
    }
    if (attributes) {
        string = CFAttributedStringCreate(kCFAllocatorDefault,
                                          text,
                                          attributes);
        CFRelease(attributes);
    }
    if (string) {
       line = CTLineCreateWithAttributedString(string);
       CFRelease(string);
    }
    if (line) {
        point = CGContextGetTextPosition(cr);
        rect = CTLineGetImageBounds(line, cr);
        CFRelease(line);
        CTLineGetTypographicBounds(line, NULL, &rect.origin.y, NULL);
        rect.origin.x = point.x - rect.origin.x; /* bearing */
    }
    CGContextRelease(cr);
    return rect;
}

- (BOOL)pack:(NSRect*)cavity
{
    static int counter = 0;
    float coordinates[4];
    float padx = 20;
    float pady = 20;
    float ipadx = 80;
    float ipady = 30;
    CGRect rect = [self textbounds];
    CGSize size = rect.size;
    CGFloat bearing = rect.origin.x;
    CGFloat descent = rect.origin.y;
    NSRect frame;
    int flags = 0;
    flags |= TOP;
    flags |= EAST;
/*
    if (counter==0) flags |= TOP;
    else if (counter==1) flags |= LEFT;
    if (counter==2) counter = 0;
*/
    counter++;
    if (counter==2) { flags |= FILLX; counter = 0;}
    printf("drawing %s with flags %d\n", [text cString], flags);
    coordinates[0] = cavity->origin.x;
    coordinates[1] = cavity->origin.y;
    coordinates[2] = cavity->origin.x + cavity->size.width;
    coordinates[3] = cavity->origin.y + cavity->size.height;
    if ((flags & TOP) || (flags & BOTTOM)) {
        rect.origin.x = cavity->origin.x;
        if (flags & FILLX) {
            rect.origin.x += padx;
            rect.size.width = cavity->size.width - 2 * padx;
        }
        else {
            rect.origin.x += 0.5 * (cavity->size.width - rect.size.width) - ipadx;
            rect.size.width += 2 * ipadx;
        }
        rect.size.height += pady + ipady;
        cavity->size.height -= rect.size.height;
        if (cavity->size.height < 0) {
            rect.size.height += cavity->size.height;
            cavity->size.height = 0;
        }
        if (flags & TOP) {
            rect.origin.y = cavity->origin.y;
            cavity->origin.y += rect.size.height;
        } else { /* BOTTOM */
            rect.origin.y = cavity->origin.y + cavity->size.height;
        }
    }
    if ((flags & LEFT) || (flags & RIGHT)) {
        rect.origin.x = cavity->origin.y;
        if (flags & FILLY) {
            rect.origin.y += pady;
            rect.size.height = cavity->size.height - 2 * padx;
        }
        else {
            rect.origin.y += 0.5 * (cavity->size.height - rect.size.height) - ipady;
            rect.size.height += 2 * ipady;
        }
        cavity->size.width -= rect.size.width;
        if (cavity->size.width < 0) {
            rect.size.width += cavity->size.width;
            cavity->size.width = 0;
        }
        rect.origin.y = cavity->origin.y;
        if (flags & LEFT) {
            rect.origin.x = cavity->origin.x;
            cavity->origin.x += rect.size.width;
        } else { /* RIGHT */
            rect.origin.x = cavity->origin.x + cavity->size.width;
        }
    }
    switch (flags & (NORTH | SOUTH)) {
        case NORTH: position.y = rect.size.height - size.height; break;
        case SOUTH: position.y = 0; break;
        default   : position.y = 0.5 * (rect.size.height - size.height); break;
    }
    position.y += descent;
    switch (flags & (WEST | EAST)) {
        case WEST: position.x = ipadx; break;
        case EAST: position.x = rect.size.width - size.width - ipadx; break;
        default  : position.x = 0.5 * (rect.size.width - size.width); break;
    }
    position.x += bearing;
    frame.origin.x = rect.origin.x;
    frame.origin.y = rect.origin.y;
    frame.size.width = rect.size.width;
    frame.size.height = rect.size.height;
    [self setFrameOrigin: frame.origin];
    [self setFrameSize: frame.size];
    return true;
}
@end

static PyObject*
Label_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    PyLabel *self = (PyLabel*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->label = NULL;
    self->layout = NULL;
    return (PyObject*)self;
}

static int
Label_init(PyLabel *self, PyObject *args, PyObject *kwds)
{
    Label *label;
    const char* text = "";

    if(!PyArg_ParseTuple(args, "|s", &text)) return -1;

    label = [[Label alloc] initWithObject: self];
    [label setString: text];
    self->label = label;

    return 0;
}

static PyObject*
Label_repr(PyLabel* self)
{
#if PY3K
    return PyUnicode_FromFormat("Label object %p wrapping NSTextField %p",
                               (void*) self, (void*)(self->label));
#else
    return PyString_FromFormat("Label object %p wrapping NSTextField %p",
                               (void*) self, (void*)(self->label));
#endif
}

static void
Label_dealloc(PyLabel* self)
{
    NSTextField* label = self->label;
    if (label)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [label release];
        [pool release];
    }
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Label_set_position(PyLabel* self, PyObject *args)
{
    float x;
    float y;
    NSPoint position;
    NSTextField* label = self->label;
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
Label_get_size(PyLabel* self, PyObject *args)
{
    float width;
    float height;
    NSRect frame;
    NSTextField* label = self->label;
    if (!label) {
        PyErr_SetString(PyExc_RuntimeError, "label has not been initialized");
        return NULL;
    }
    frame = [label frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("ff", width, height);
}

static PyObject*
Label_pack(PyLabel* self, PyObject *args)
{
    int i;
    double values[4];
    NSPoint origin;
    NSPoint corner;
    NSPoint position;
    NSRect frame;
    NSSize size;
    PyObject* item;
    PyObject* cavity;
    NSTextField* label = self->label;
    if (!label) {
        PyErr_SetString(PyExc_RuntimeError, "label has not been initialized");
        return NULL;
    }
/*
    if(!PyArg_ParseTuple(args, "O", &cavity))
        return NULL;
    if(!PyList_Check(cavity)) {
        PyErr_SetString(PyExc_RuntimeError, "cavity argument should be a list");
        return NULL;
    }
    if(PyList_GET_SIZE(cavity)!=4) {
        PyErr_SetString(PyExc_RuntimeError, "cavity argument should be a list of four elements");
        return NULL;
    }
    for (i = 0; i < 4; i++) {
        item = PyList_GET_ITEM(cavity, i);
        values[i] = PyFloat_AsDouble(item);
        if (values[i] < 0 && PyErr_Occurred()) {
            PyErr_SetString(PyExc_RuntimeError, "cavity argument should be a list of four numbers");
            return NULL;
        }
    }

    origin.x = values[0];
    origin.y = values[1];
    corner.x = values[2];
    corner.y = values[3];
    frame = [label frame];
    size = frame.size;
    position.y = origin.y;
    position.x = 0.5 * (origin.x + corner.x - size.width);
    origin.y += size.height;

    [label setFrameOrigin: position];

    values[0] = origin.x;
    values[1] = origin.y;
    values[2] = corner.x;
    values[3] = corner.y;
    for (i = 0; i < 4; i++) {
        item = PyFloat_FromDouble(values[i]);
        if (!item) return NULL;
        if (PyList_SetItem(cavity, i, item)==-1) {
            Py_DECREF(item);
            return NULL;
        }
    }
*/
    Py_INCREF(Py_None);
    return Py_None;
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
    {"pack",
     (PyCFunction)Label_pack,
     METH_VARARGS,
     "Pack the label into the available cavity."
    },
    {NULL}  /* Sentinel */
};

static PyGetSetDef Label_getseters[] = {
    {NULL}  /* Sentinel */
};

static char Label_doc[] =
"A Label object wraps a Cocoa NSTextField object.\n";

PyTypeObject LabelType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Label",             /* tp_name */
    sizeof(PyLabel),            /* tp_basicsize */
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
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Label_init,       /* tp_init */
    0,                          /* tp_alloc */
    Label_new,                  /* tp_new */
};
