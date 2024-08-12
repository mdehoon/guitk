#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "colors.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10120
#define COMPILING_FOR_10_12
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10130
#define COMPILING_FOR_10_13
#endif


@interface Checkbox : NSButton
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (Checkbox*)initWithObject:(PyObject*)obj;
-(void)command:(id)sender;
@end

typedef struct {
    PyObject_HEAD
    Checkbox* checkbox;
    NSString* text;
    NSFont* font;
    ColorObject* foreground;
    ColorObject* background;
    PyObject* minimum_size;
    PyObject* command;
} CheckboxObject;

@implementation Checkbox

- (PyObject*)object
{
    return (PyObject*)_object;
}

- (Checkbox*)initWithObject:(PyObject*)object
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
    CheckboxObject* object = (CheckboxObject*)_object;
    PyObject* command = object->command;
    if (command==Py_None) return;
    gstate = PyGILState_Ensure();
    result = PyObject_CallFunction(command, "O", object);
    if(result)
        Py_DECREF(result);
    else
        PyErr_Print(); 
    PyGILState_Release(gstate);
}
@end

static PyObject*
Checkbox_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    CheckboxObject *self = (CheckboxObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    Py_INCREF(Py_None);
    self->command = Py_None;;
    self->minimum_size = NULL;
    self->foreground = NULL;
    self->background = NULL;
    return (PyObject*)self;
}

static int
Checkbox_init(CheckboxObject *self, PyObject *args, PyObject *keywords)
{
    Checkbox *checkbox;
    const char* text = "";
    NSString* s;
    NSColor* color;
    static char* kwlist[] = {"text", NULL};

    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|s", kwlist, &text))
        return -1;

    checkbox = [[Checkbox alloc] initWithObject: (PyObject*)self];

    Py_INCREF(systemTextColor);
    Py_INCREF(systemWindowBackgroundColor);
    Py_XDECREF(self->foreground);
    Py_XDECREF(self->background);
    self->foreground = systemTextColor;
    self->background = systemWindowBackgroundColor;

    color = [NSColor colorWithCalibratedRed: self->background->rgba[0] / 255.
                                      green: self->background->rgba[1] / 255.
                                       blue: self->background->rgba[2] / 255.
                                      alpha: self->background->rgba[3] / 255.];
#ifdef COMPILING_FOR_10_12
    [checkbox setButtonType: NSButtonTypeSwitch];
#else
    [checkbox setButtonType: NSSwitchButton];
#endif
    s = [[NSString alloc] initWithCString: text encoding: NSUTF8StringEncoding];
    [checkbox setTitle: s];
    [s release];
    [[checkbox cell] setBackgroundColor: color];
    self->checkbox = checkbox;

    return 0;
}

static PyObject*
Checkbox_repr(CheckboxObject* self)
{
    return PyUnicode_FromFormat("Checkbox object %p wrapping NSButton %p",
                               (void*) self, (void*)(self->checkbox));
}

static void
Checkbox_dealloc(CheckboxObject* self)
{
    Checkbox* checkbox = self->checkbox;
    if (checkbox)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [checkbox release];
        [pool release];
    }
    Py_XDECREF(self->foreground);
    Py_XDECREF(self->background);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Checkbox_set_frame(CheckboxObject* self, PyObject *args)
{
    float x0;
    float y0;
    float x1;
    float y1;
    NSPoint position;
    NSSize size;
    Checkbox* checkbox = self->checkbox;
    if (!checkbox) {
        PyErr_SetString(PyExc_RuntimeError, "checkbox has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ffff", &x0, &y0, &x1, &y1))
        return NULL;
    printf("Setting frame to %f, %f, %f, %f\n", x0, y0, x1, y1);

    position.x = x0;
    position.y = y0;
    [checkbox setFrameOrigin: position];
    size.width = x1 - x0;
    size.height = y1 - y0;
    [checkbox setFrameSize: size];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Checkbox_get_size(CheckboxObject* self, PyObject *args)
{
    float width;
    float height;
    NSRect frame;
    Checkbox* checkbox = self->checkbox;
    if (!checkbox) {
        PyErr_SetString(PyExc_RuntimeError, "checkbox has not been initialized");
        return NULL;
    }
    frame = [checkbox frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("ff", width, height);
}

static PyObject*
Checkbox_set_size(CheckboxObject* self, PyObject *args)
{
    float width;
    float height;
    NSSize size;
    Checkbox* checkbox = self->checkbox;
    if (!checkbox) {
        PyErr_SetString(PyExc_RuntimeError, "checkbox has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ff", &width, &height)) return NULL;
    if (width < 0 || height < 0) {
        PyErr_SetString(PyExc_RuntimeError, "width and height should be non-negative");
        return NULL;
    }
    size.width = width;
    size.height = height;
    [checkbox setFrameSize: size];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Checkbox_methods[] = {
    {"set_frame",
     (PyCFunction)Checkbox_set_frame,
     METH_VARARGS,
     "Sets the size and position of the checkbox."
    },
    {"get_size",
     (PyCFunction)Checkbox_get_size,
     METH_NOARGS,
     "Returns the size of the checkbox."
    },
    {"set_size",
     (PyCFunction)Checkbox_set_size,
     METH_VARARGS,
     "Sets the size of the checkbox."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Checkbox_get_minimum_size(CheckboxObject* self, void* closure)
{
    PyObject* minimum_size = self->minimum_size;
    if (minimum_size==NULL) {
        Checkbox* checkbox = self->checkbox;
        NSSize size = [[checkbox cell] cellSize];
        minimum_size = Py_BuildValue("ff", size.width, size.height);
        self->minimum_size = minimum_size;
    }
    Py_INCREF(minimum_size);
    return minimum_size;
}

static char Checkbox_minimum_size__doc__[] = "minimum size needed to show the checkbox.";

static PyObject* Checkbox_get_command(CheckboxObject* self, void* closure)
{
    PyObject* command = self->command;
    Py_INCREF(command);
    return command;
}

static int
Checkbox_set_command(CheckboxObject* self, PyObject* value, void* closure)
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

static char Checkbox_command__doc__[] = "Python command to be executed when the checkbox is pressed.";

static PyObject* Checkbox_get_state(CheckboxObject* self, void* closure)
{
    Checkbox* checkbox = self->checkbox;
    NSInteger state = [checkbox state];
#ifdef COMPILING_FOR_10_13
    if (state == NSControlStateValueOn) Py_RETURN_TRUE;
    if (state == NSControlStateValueOff) Py_RETURN_FALSE;
#else
    if (state == NSOnState) Py_RETURN_TRUE;
    if (state == NSOffState) Py_RETURN_FALSE;
#endif
    PyErr_SetString(PyExc_RuntimeError, "checkbox state is unknown.");
    return NULL;
}

static int
Checkbox_set_state(CheckboxObject* self, PyObject* value, void* closure)
{
    Checkbox* checkbox = self->checkbox;
    int flag = PyObject_IsTrue(value);
    switch (flag) {
        case 1: checkbox.state = 1; break;
        case 0: checkbox.state = 0; break;
        case -1: return -1;
    }
    return 0;
}

static char Checkbox_state__doc__[] = "checkbox state.";

static PyObject* Checkbox_get_text(CheckboxObject* self, void* closure)
{
    PyObject* result = NULL;
    Checkbox* checkbox = self->checkbox;
    NSString* text = [checkbox title];
    if (text) {
        const char* s = [text UTF8String];
        result = PyUnicode_FromString(s);
    }
    return result;
}

static int
Checkbox_set_text(CheckboxObject* self, PyObject* value, void* closure)
{
    NSString* s;
    const char* text;
    value = PyUnicode_AsUTF8String(value);
    if (!value) return -1;
    text = PyBytes_AS_STRING(value);
    s = [[NSString alloc] initWithCString: text
                                 encoding: NSUTF8StringEncoding];
    [self->checkbox setTitle: s];
    [s release];
    Py_DECREF(value);
    return 0;
}

static char Checkbox_text__doc__[] = "checkbox text.";

static PyObject* Checkbox_get_background(CheckboxObject* self, void* closure)
{
    Py_INCREF(self->background);
    return (PyObject*) self->background;
}

static int
Checkbox_set_background(CheckboxObject* self, PyObject* value, void* closure)
{
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    NSColor* color;
    Checkbox* checkbox = self->checkbox;

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
    [[checkbox cell] setBackgroundColor: color];
    checkbox.needsDisplay = YES;
    return 0;
}

static char Checkbox_background__doc__[] = "background color.";

static PyObject* Checkbox_get_foreground(CheckboxObject* self, void* closure)
{
    Py_INCREF(self->foreground);
    return (PyObject*) self->foreground;
}

static int
Checkbox_set_foreground(CheckboxObject* self, PyObject* value, void* closure)
{
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    NSColor* color;
    NSMutableAttributedString *text;
    NSRange range;
    Checkbox* checkbox = self->checkbox;

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
    text = [[NSMutableAttributedString alloc] initWithAttributedString:[checkbox attributedTitle]];
    range = NSMakeRange(0, [text length]);
    [text addAttribute: NSForegroundColorAttributeName
                  value: color
                  range: range];
    [checkbox setAttributedTitle:text];
    checkbox.needsDisplay = YES;
    return 0;
}

static char Checkbox_foreground__doc__[] = "foreground color.";

static PyGetSetDef Checkbox_getseters[] = {
    {"minimum_size", (getter)Checkbox_get_minimum_size, (setter)NULL, Checkbox_minimum_size__doc__, NULL},
    {"state", (getter)Checkbox_get_state, (setter)Checkbox_set_state, Checkbox_state__doc__, NULL},
    {"text", (getter)Checkbox_get_text, (setter)Checkbox_set_text, Checkbox_text__doc__, NULL},
    {"command", (getter)Checkbox_get_command, (setter)Checkbox_set_command, Checkbox_command__doc__, NULL},
    {"background", (getter)Checkbox_get_background, (setter)Checkbox_set_background, Checkbox_background__doc__, NULL},
    {"foreground", (getter)Checkbox_get_foreground, (setter)Checkbox_set_foreground, Checkbox_foreground__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Checkbox_doc[] =
"A Checkbox object wraps a Cocoa NSButton object of type NSButtonTypeSwitch.";

Py_LOCAL_SYMBOL PyTypeObject CheckboxType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Checkbox",            /* tp_name */
    sizeof(CheckboxObject),       /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Checkbox_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Checkbox_repr,      /* tp_repr */
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
    Checkbox_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Checkbox_methods,             /* tp_methods */
    0,                          /* tp_members */
    Checkbox_getseters,           /* tp_getset */
    &WidgetType,                /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Checkbox_init,      /* tp_init */
    0,                          /* tp_alloc */
    Checkbox_new,                 /* tp_new */
};
