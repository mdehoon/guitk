#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "colors.h"
#include "text.h"


@interface Textbox : NSTextField
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (Textbox*)initWithObject:(PyObject*)obj;
-(void)command:(id)sender;
@end

typedef struct {
    WidgetObject widget;
    NSFont* font;
    ColorObject* foreground;
    ColorObject* background;
    PyObject* minimum_size;
    PyObject* command;
} TextboxObject;

@implementation Textbox

- (PyObject*)object
{
    return (PyObject*)_object;
}

- (Textbox*)initWithObject:(PyObject*)object
{
    NSRect rect;
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
    [self setTarget: self];
    [self setAction: @selector(command:)];
    _object = object;
    return self;
}

-(void)command:(id)sender
{
    PyGILState_STATE gstate;
    PyObject* result;
    TextboxObject* object = (TextboxObject*)_object;
    PyObject* command = object->command;
    if (command==Py_None) return;
    gstate = PyGILState_Ensure();
    result = PyObject_CallObject(command, NULL);
    if(result)
        Py_DECREF(result);
    else
        PyErr_Print(); 
    PyGILState_Release(gstate);
}
@end

static PyObject*
Textbox_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    TextboxObject *self = (TextboxObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    Py_INCREF(Py_None);
    self->foreground = NULL;
    self->background = NULL;
    self->command = Py_None;;
    self->minimum_size = NULL;
    return (PyObject*)self;
}

static int
Textbox_init(TextboxObject *self, PyObject *args, PyObject *keywords)
{
    Textbox *textbox;
    CFStringRef text = CFSTR("");
    NSColor* color;
    WidgetObject* widget;

    static char* kwlist[] = {"text", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|O&", kwlist, string_converter, &text))
        return -1;


    Py_INCREF(systemTextColor);
    Py_INCREF(systemWindowBackgroundColor);
    Py_XDECREF(self->foreground);
    Py_XDECREF(self->background);
    self->foreground = systemTextColor;
    self->background = systemWindowBackgroundColor;

    textbox = [[Textbox alloc] initWithObject: (PyObject*)self];

    color = [NSColor colorWithCalibratedRed: self->foreground->rgba[0] / 255.
                                      green: self->foreground->rgba[1] / 255.
                                       blue: self->foreground->rgba[2] / 255.
                                      alpha: self->foreground->rgba[3] / 255.];
    [textbox setTextColor: color];

    color = [NSColor colorWithCalibratedRed: self->background->rgba[0] / 255.
                                      green: self->background->rgba[1] / 255.
                                       blue: self->background->rgba[2] / 255.
                                      alpha: self->background->rgba[3] / 255.];
    [[textbox cell] setBackgroundColor: color];

    [textbox setStringValue: (NSString*)text];
    [textbox setBordered: YES];
    [textbox setBezeled: YES];
    widget = (WidgetObject*)self;
    widget->view = textbox;

    return 0;
}

static PyObject*
Textbox_repr(TextboxObject* self)
{
    WidgetObject* widget = (WidgetObject*) self;
    NSView* view = widget->view;
    return PyUnicode_FromFormat("Textbox object %p wrapping NSTextField %p",
                               (void*) self, (void*)view);
}

static void
Textbox_dealloc(TextboxObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    Textbox* textbox = (Textbox*) widget->view;
    if (textbox)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [textbox release];
        [pool release];
    }
    Py_XDECREF(self->foreground);
    Py_XDECREF(self->background);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Textbox_set_frame(TextboxObject* self, PyObject *args)
{
    float x0;
    float y0;
    float x1;
    float y1;
    NSPoint position;
    NSSize size;
    WidgetObject* widget = (WidgetObject*)self;
    NSView* textbox = widget->view;
    if (!textbox) {
        PyErr_SetString(PyExc_RuntimeError, "textbox has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ffff", &x0, &y0, &x1, &y1))
        return NULL;
    printf("Setting frame to %f, %f, %f, %f\n", x0, y0, x1, y1);

    position.x = x0;
    position.y = y0;
    [textbox setFrameOrigin: position];
    size.width = x1 - x0;
    size.height = y1 - y0;
    [textbox setFrameSize: size];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Textbox_get_size(TextboxObject* self, PyObject *args)
{
    float width;
    float height;
    NSRect frame;
    WidgetObject* widget = (WidgetObject*)self;
    NSView* textbox = widget->view;
    if (!textbox) {
        PyErr_SetString(PyExc_RuntimeError, "textbox has not been initialized");
        return NULL;
    }
    frame = [textbox frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("ff", width, height);
}

static PyObject*
Textbox_set_size(TextboxObject* self, PyObject *args)
{
    float width;
    float height;
    NSSize size;
    WidgetObject* widget = (WidgetObject*)self;
    NSView* textbox = widget->view;
    if (!textbox) {
        PyErr_SetString(PyExc_RuntimeError, "textbox has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ff", &width, &height)) return NULL;
    if (width < 0 || height < 0) {
        PyErr_SetString(PyExc_RuntimeError, "width and height should be non-negative");
        return NULL;
    }
    size.width = width;
    size.height = height;
    [textbox setFrameSize: size];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Textbox_methods[] = {
    {"set_frame",
     (PyCFunction)Textbox_set_frame,
     METH_VARARGS,
     "Sets the size and position of the textbox."
    },
    {"get_size",
     (PyCFunction)Textbox_get_size,
     METH_NOARGS,
     "Returns the size of the textbox."
    },
    {"set_size",
     (PyCFunction)Textbox_set_size,
     METH_VARARGS,
     "Sets the size of the textbox."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Textbox_get_minimum_size(TextboxObject* self, void* closure)
{
    PyObject* minimum_size = self->minimum_size;
    if (minimum_size==NULL) {
        WidgetObject* widget = (WidgetObject*)self;
        Textbox* textbox = (Textbox*) widget->view;
        NSSize size = [[textbox cell] cellSize];
        minimum_size = Py_BuildValue("ff", size.width, size.height);
        self->minimum_size = minimum_size;
    }
    Py_INCREF(minimum_size);
    return minimum_size;
}

static char Textbox_minimum_size__doc__[] = "minimum size needed to show the textbox.";

static PyObject* Textbox_get_text(TextboxObject* self, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    Textbox* textbox = (Textbox*)(widget->view);
    CFStringRef text = (CFStringRef) [textbox stringValue];
    return PyString_FromCFString(text);
}

static int
Textbox_set_text(TextboxObject* self, PyObject* value, void* closure)
{
    Textbox* textbox;
    WidgetObject* widget;
    CFStringRef text = PyString_AsCFString(value);
    if (!text) return -1;
    widget = (WidgetObject*) self;
    textbox = (Textbox*)(widget->view);
    CFRelease(textbox.stringValue);
    textbox.stringValue = (NSString*) text;
    return 0;
}

static char Textbox_text__doc__[] = "textbox contents.";

static PyObject* Textbox_get_command(TextboxObject* self, void* closure)
{
    PyObject* command = self->command;
    Py_INCREF(command);
    return command;
}

static int
Textbox_set_command(TextboxObject* self, PyObject* value, void* closure)
{
    if (!PyCallable_Check(value)) {
        PyErr_SetString(PyExc_ValueError, "command should be callable.");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->command);
    self->command = value;
    return 0;
}

static char Textbox_command__doc__[] = "Python command to be executed when the textbox is pressed.";

static PyObject* Textbox_get_background(TextboxObject* self, void* closure)
{
    Py_INCREF(self->background);
    return (PyObject*) self->background;
}

static int
Textbox_set_background(TextboxObject* self, PyObject* value, void* closure)
{
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    NSColor* color;
    BOOL editable;

    WidgetObject* widget = (WidgetObject*)self;
    Textbox* textbox = (Textbox*) widget->view;

    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->background);
    self->background = (ColorObject*) value;
    red = self->background->rgba[0] / 255.;
    green = self->background->rgba[1] / 255.;
    blue = self->background->rgba[2] / 255.;
    alpha = self->background->rgba[3] / 255.;
    color = [NSColor colorWithCalibratedRed: red
                                      green: green
                                       blue: blue
                                      alpha: alpha];
    editable = textbox.editable;
    if (editable) [textbox setEditable: NO];
    [textbox setBackgroundColor: color];
    if (editable) [textbox setEditable: YES];
    textbox.needsDisplay = YES;
    return 0;
}

static char Textbox_background__doc__[] = "background color.";

static PyObject* Textbox_get_foreground(TextboxObject* self, void* closure)
{
    Py_INCREF(self->foreground);
    return (PyObject*) self->foreground;
}

static int
Textbox_set_foreground(TextboxObject* self, PyObject* value, void* closure)
{
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    NSColor* color;

    WidgetObject* widget = (WidgetObject*)self;
    Textbox* textbox = (Textbox*) widget->view;

    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->foreground);
    self->foreground = (ColorObject*) value;
    red = self->foreground->rgba[0] / 255.;
    green = self->foreground->rgba[1] / 255.;
    blue = self->foreground->rgba[2] / 255.;
    alpha = self->foreground->rgba[3] / 255.;
    color = [NSColor colorWithCalibratedRed: red
                                      green: green
                                       blue: blue
                                      alpha: alpha];
    [textbox setTextColor: color];
    textbox.needsDisplay = YES;
    return 0;
}

static char Textbox_foreground__doc__[] = "foreground color.";

static PyGetSetDef Textbox_getseters[] = {
    {"minimum_size", (getter)Textbox_get_minimum_size, (setter)NULL, Textbox_minimum_size__doc__, NULL},
    {"text", (getter)Textbox_get_text, (setter)Textbox_set_text, Textbox_text__doc__, NULL},
    {"command", (getter)Textbox_get_command, (setter)Textbox_set_command, Textbox_command__doc__, NULL},
    {"background", (getter)Textbox_get_background, (setter)Textbox_set_background, Textbox_background__doc__, NULL},
    {"foreground", (getter)Textbox_get_foreground, (setter)Textbox_set_foreground, Textbox_foreground__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Textbox_doc[] =
"A Textbox object wraps a Cocoa NSTextField object.\n";

Py_LOCAL_SYMBOL PyTypeObject TextboxType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Textbox",            /* tp_name */
    sizeof(TextboxObject),       /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Textbox_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Textbox_repr,      /* tp_repr */
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
    Textbox_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Textbox_methods,             /* tp_methods */
    0,                          /* tp_members */
    Textbox_getseters,           /* tp_getset */
    &WidgetType,                /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Textbox_init,      /* tp_init */
    0,                          /* tp_alloc */
    Textbox_new,                 /* tp_new */
};
