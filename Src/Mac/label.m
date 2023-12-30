#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "window.h"
#include "colors.h"
#include "text.h"
#include "font.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10100
#define COMPILING_FOR_10_10
#endif

@interface LabelView : NSView
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (LabelView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object;
- (BOOL)isFlipped;
- (void)drawRect:(NSRect)rect;
@end

typedef struct {
    WidgetObject widget;
    ColorObject* foreground;
    ColorObject* background;
    CFStringRef text;
    FontObject* font;
    PyObject* minimum_size;
} LabelObject;

@implementation LabelView
- (PyObject*)object
{
    return (PyObject*)_object;
}

- (LabelView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object
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
    short red, green, blue, alpha;
    LabelObject* object = (LabelObject*)_object;
    CFStringRef keys[] = { kCTFontAttributeName,
                           kCTForegroundColorFromContextAttributeName };
    CFTypeRef values[] = { object->font->font,
                           kCFBooleanTrue };
    gc = [NSGraphicsContext currentContext];
#ifdef COMPILING_FOR_10_10
    cr = [gc CGContext];
#else
    cr = (CGContextRef) [gc graphicsPort];
#endif
    red = object->background->rgba[0];
    green = object->background->rgba[1];
    blue = object->background->rgba[2];
    alpha = object->background->rgba[3];
    CGContextSetRGBFillColor(cr, red/255., green/255., blue/255., alpha/255.);
    rect = NSRectToCGRect(dirtyRect);
    CGContextFillRect(cr, rect);
    attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                    (const void**)&keys,
                                    (const void**)&values,
                                    2,
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
    width = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
    height = ascent + descent;
    x -= 0.5 * width;
    y += 0.5 * height;
    y -= descent;
    CGAffineTransform transform = CGAffineTransformMakeScale (1.0, -1.0); 
    CGContextSetTextMatrix(cr, transform);
    CGContextSetTextPosition(cr, x, y);
    red = object->foreground->rgba[0];
    green = object->foreground->rgba[1];
    blue = object->foreground->rgba[2];
    alpha = object->foreground->rgba[3];
    CGContextSetRGBFillColor(cr, red/255., green/255., blue/255., alpha/255.);
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
    WidgetObject* widget;
    LabelObject *self = (LabelObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    widget = (WidgetObject*)self;
    widget->view = nil;
    Py_INCREF(black);
    self->foreground = black;
    self->background = transparent;
    self->text = NULL;
    self->font = NULL;
    self->minimum_size = NULL;
    return (PyObject*)self;
}

static int
Label_init(LabelObject *self, PyObject *args, PyObject *keywords)
{
    WidgetObject* widget;
    LabelView *label;
    CFStringRef text = CFSTR("");
    NSRect rect;
    FontObject* font = default_font_object;

    static char* kwlist[] = {"text", "font", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|O&O!", kwlist, string_converter, &text, &FontType, &font))
        return -1;

    widget = (WidgetObject*)self;
    rect.origin.x = 0;
    rect.origin.y = 0;
    rect.size.width = 100;
    rect.size.height = 100;
    label = [[LabelView alloc] initWithFrame: rect withObject: (PyObject*)self];

    Py_INCREF(font);
    widget->view = label;
    self->text = text;
    self->font = font;

    return 0;
}

static PyObject*
Label_repr(LabelObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    return PyUnicode_FromFormat("Label object %p wrapping NSView %p",
                               self, widget->view);
}

static void
Label_dealloc(LabelObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    LabelView* label = (LabelView*) (widget->view);
    CFStringRef text = self->text;
    FontObject* font = self->font;
    if (label) [label release];
    if (font) Py_DECREF(font);
    if (text) CFRelease(text);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Label_set_position(LabelObject* self, PyObject *args)
{
    float x;
    float y;
    NSPoint position;
    WidgetObject* widget = (WidgetObject*)self;
    LabelView* label = (LabelView*) (widget->view);
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

static PyMethodDef Label_methods[] = {
    {"set_position",
     (PyCFunction)Label_set_position,
     METH_VARARGS,
     "Moves the label to the new position."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Label_get_text(LabelObject* self, void* closure)
{
    return PyString_FromCFString(self->text);
}

static int
Label_set_text(LabelObject* self, PyObject* value, void* closure)
{
    CFStringRef text;
    Window* window;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    text = PyString_AsCFString(value);
    if (!text) return -1;
    if (self->text) CFRelease(self->text);
    self->text = text;
    if (self->minimum_size) {
        Py_DECREF(self->minimum_size);
        self->minimum_size = NULL;
    }
    label.needsDisplay = YES;
    window = (Window*) [label window];
    [window requestLayout];
    return 0;
}

static char Label_text__doc__[] = "label text.";

static PyObject* Label_get_font(LabelObject* self, void* closure)
{
    PyObject* font = (PyObject*) self->font;
    Py_INCREF(font);
    return font;
}

static int
Label_set_font(LabelObject* self, PyObject* value, void* closure)
{
    Window* window;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyObject_IsInstance(value, (PyObject *)&FontType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Font object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->font);
    self->font = (FontObject*) value;
    if (self->minimum_size) {
        Py_DECREF(self->minimum_size);
        self->minimum_size = NULL;
    }
    label.needsDisplay = YES;
    window = (Window*) [label window];
    [window requestLayout];
    return 0;
}

static char Label_font__doc__[] = "font for label";

static PyObject* Label_get_foreground(LabelObject* self, void* closure)
{
    Py_INCREF(self->foreground);
    return (PyObject*) self->foreground;
}

static int
Label_set_foreground(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    self->foreground = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_foreground__doc__[] = "foreground color.";

static PyObject* Label_get_background(LabelObject* self, void* closure)
{
    Py_INCREF(self->background);
    return (PyObject*) self->background;
}

static int
Label_set_background(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    self->background = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_background__doc__[] = "background color.";

static PyObject* Label_calculate_minimum_size(LabelObject* self)
{
    CGFloat ascent;
    CGFloat descent;
    CGFloat width;
    CGFloat height;
    CTLineRef line;
    CFAttributedStringRef string;
    CFDictionaryRef attributes;
    CFStringRef keys[1];
    CFTypeRef values[1];
    keys[0] = kCTFontAttributeName;
    values[0] = self->font->font;
    attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                    (const void**)&keys,
                                    (const void**)&values,
                                    1,
                                    &kCFTypeDictionaryKeyCallBacks,
                                    &kCFTypeDictionaryValueCallBacks);
    if (!attributes) return PyErr_NoMemory();
    string = CFAttributedStringCreate(kCFAllocatorDefault,
                                      self->text,
                                      attributes);
    CFRelease(attributes);
    if (!string) return PyErr_NoMemory();
    line = CTLineCreateWithAttributedString(string);
    CFRelease(string);
    if (!line) return PyErr_NoMemory();
    width = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
    height = ascent + descent;
    return Py_BuildValue("ff", width, height);
}

static PyObject* Label_get_minimum_size(LabelObject* self, void* closure)
{
    PyObject* minimum_size = self->minimum_size;
    if (minimum_size==NULL) {
        minimum_size = Label_calculate_minimum_size(self);
        self->minimum_size = minimum_size;
    }
    Py_INCREF(minimum_size);
    return minimum_size;
}

static char Label_minimum_size__doc__[] = "minimum size needed to show the label.";

static PyGetSetDef Label_getseters[] = {
    {"text", (getter)Label_get_text, (setter)Label_set_text, Label_text__doc__, NULL},
    {"font", (getter)Label_get_font, (setter)Label_set_font, Label_font__doc__, NULL},
    {"foreground", (getter)Label_get_foreground, (setter)Label_set_foreground, Label_foreground__doc__, NULL},
    {"background", (getter)Label_get_background, (setter)Label_set_background, Label_background__doc__, NULL},
    {"minimum_size", (getter)Label_get_minimum_size, (setter)NULL, Label_minimum_size__doc__, NULL},
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
