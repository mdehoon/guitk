#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "colors.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10100
#define COMPILING_FOR_10_10
#endif


@interface Button : NSControl
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (Button*)initWithObject:(PyObject*)obj;
- (void)command:(id)sender;
- (void)drawRect:(NSRect)rect;
@end

typedef struct {
    PyObject_HEAD
    Button* button;
    NSString* text;
    NSFont* font;
    ColorObject* background;
    PyObject* minimum_size;
    PyObject* command;
} ButtonObject;

@implementation Button

- (PyObject*)object
{
    return (PyObject*)_object;
}

- (Button*)initWithObject:(PyObject*)object
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
    ButtonObject* object = (ButtonObject*)_object;
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

- (void)drawRect:(NSRect)dirtyRect
{
    CGContextRef cr;
    NSGraphicsContext* gc;
    short red, green, blue, alpha;
    CGRect rect;
    ButtonObject* object = (ButtonObject*)_object;
    gc = [NSGraphicsContext currentContext];
#ifdef COMPILING_FOR_10_10
    cr = gc.CGContext;
#else
    cr = (CGContextRef) [gc graphicsPort];
#endif
    rect = NSRectToCGRect(dirtyRect);
    red = object->background->rgba[0];
    green = object->background->rgba[1];
    blue = object->background->rgba[2];
    alpha = object->background->rgba[3];
    CGContextSetRGBFillColor(cr, red/255., green/255., blue/255., alpha/255.);
    rect = NSRectToCGRect(dirtyRect);
    CGContextFillRect(cr, rect);
    fprintf(stderr, "In drawRect, filling with %d,%d,%d,%d\n", red, green, blue, alpha); fflush(stderr);

/*

    if (Tk_Width(tkwin) > 0 && (Tk_Height(tkwin) > 0)) {
        Pixmap pixmap = (Pixmap) Tk_WindowId(tkwin);
        MacButton *macButtonPtr = (MacButton *)clientData;
        Tk_Window tkwin = butPtr->tkwin;
        DrawParams* dpPtr = &macButtonPtr->drawParams;
        butPtr->flags &= ~REDRAW_PENDING;
        if ((butPtr->tkwin == NULL) || !Tk_IsMapped(tkwin)) {
            return;
        }


        XRectangle rectangle;
        rectangle.x = 0;
        rectangle.y = 0;
        rectangle.width = Tk_Width(tkwin);
        rectangle.height = Tk_Height(tkwin);
        MacDrawable *macWin = (MacDrawable *)pixmap;
        TkMacOSXDrawingContext dc;
        XRectangle * rectPtr;
        display->request++;
        if (!TkMacOSXSetupDrawingContext(pixmap, butPtr->highlightBorder, &dc)) {
            return;
        }
        if (dc.context) {
            CGRect rect = GRectMake(macWin->xOff + rectPtr->x,
                                    macWin->yOff + rectPtr->y,
                                    rectangle.width, rectangle.height);
            CGContextFillRect(dc.context, rect);
        }
        TkMacOSXRestoreDrawingContext(&dc);
    }
        DrawButtonImageAndText(butPtr);
        GC gc = NULL;
        if ((butPtr->flags & GOT_FOCUS) && butPtr->highlightColorPtr) {
            gc = Tk_GCForColor(butPtr->highlightColorPtr, pixmap);
        } else if (butPtr->type == TYPE_LABEL) {
            gc = Tk_GCForColor(Tk_3DBorderColor(butPtr->highlightBorder), pixmap);
        }
        if (gc) {
            TkMacOSXDrawSolidBorder(tkwin, gc, 0, butPtr->highlightWidth);
        }
*/
}
@end

static PyObject*
Button_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    ButtonObject *self = (ButtonObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    Py_INCREF(Py_None);
    self->command = Py_None;;
    self->minimum_size = NULL;
    return (PyObject*)self;
}

static int
Button_init(ButtonObject *self, PyObject *args, PyObject *keywords)
{
    Button *button;
    const char* text = "";
    NSString* s;
    NSColor* color;

    static char* kwlist[] = {"text", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|s", kwlist, &text))
        return -1;

    button = [[Button alloc] initWithObject: (PyObject*)self];
    color = [NSColor lightGrayColor];
    [[button cell] setBackgroundColor: color];

    Py_INCREF(systemWindowBackgroundColor);
    self->background = systemWindowBackgroundColor;

    s = [[NSString alloc] initWithCString: text encoding: NSUTF8StringEncoding];
    fprintf(stderr, "Should call [button setTitle: s]\n"); fflush(stderr);
/*
    [button setTitle: s];
*/
    [s release];
    self->button = button;

    return 0;
}

static PyObject*
Button_repr(ButtonObject* self)
{
    return PyUnicode_FromFormat("Button object %p wrapping NSButton %p",
                               (void*) self, (void*)(self->button));
}

static void
Button_dealloc(ButtonObject* self)
{
    Button* button = self->button;
    if (button)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [button release];
        [pool release];
    }
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Button_set_frame(ButtonObject* self, PyObject *args)
{
    float x0;
    float y0;
    float x1;
    float y1;
    NSPoint position;
    NSSize size;
    Button* button = self->button;
    if (!button) {
        PyErr_SetString(PyExc_RuntimeError, "button has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ffff", &x0, &y0, &x1, &y1))
        return NULL;
    printf("Setting frame to %f, %f, %f, %f\n", x0, y0, x1, y1);

    position.x = x0;
    position.y = y0;
    [button setFrameOrigin: position];
    size.width = x1 - x0;
    size.height = y1 - y0;
    [button setFrameSize: size];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Button_get_size(ButtonObject* self, PyObject *args)
{
    float width;
    float height;
    NSRect frame;
    Button* button = self->button;
    if (!button) {
        PyErr_SetString(PyExc_RuntimeError, "button has not been initialized");
        return NULL;
    }
    frame = [button frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("ff", width, height);
}

static PyObject*
Button_set_size(ButtonObject* self, PyObject *args)
{
    float width;
    float height;
    NSSize size;
    Button* button = self->button;
    if (!button) {
        PyErr_SetString(PyExc_RuntimeError, "button has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ff", &width, &height)) return NULL;
    if (width < 0 || height < 0) {
        PyErr_SetString(PyExc_RuntimeError, "width and height should be non-negative");
        return NULL;
    }
    size.width = width;
    size.height = height;
    [button setFrameSize: size];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Button_methods[] = {
    {"set_frame",
     (PyCFunction)Button_set_frame,
     METH_VARARGS,
     "Sets the size and position of the button."
    },
    {"get_size",
     (PyCFunction)Button_get_size,
     METH_NOARGS,
     "Returns the size of the button."
    },
    {"set_size",
     (PyCFunction)Button_set_size,
     METH_VARARGS,
     "Sets the size of the button."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Button_get_minimum_size(ButtonObject* self, void* closure)
{
    PyObject* minimum_size = self->minimum_size;
    if (minimum_size==NULL) {
        Button* button = self->button;
        NSSize size = [[button cell] cellSize];
        size.width = 100;
        size.height = 100;
        minimum_size = Py_BuildValue("ff", size.width, size.height);
        self->minimum_size = minimum_size;
    }
    Py_INCREF(minimum_size);
    return minimum_size;
}

static char Button_minimum_size__doc__[] = "minimum size needed to show the button.";

static PyObject* Button_get_command(ButtonObject* self, void* closure)
{
    PyObject* command = self->command;
    Py_INCREF(command);
    return command;
}

static int
Button_set_command(ButtonObject* self, PyObject* value, void* closure)
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

static char Button_command__doc__[] = "Python command to be executed when the button is pressed.";

static PyObject* Button_get_background(ButtonObject* self, void* closure)
{
    short rgba[4];
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    Button* button = self->button;
    NSColor* color = [[button cell] backgroundColor];
    color = [color colorUsingColorSpace: [NSColorSpace genericRGBColorSpace]];
    [color getRed: &red green: &green blue: &blue alpha: &alpha];
    rgba[0] = (short)round(red*255);
    rgba[1] = (short)round(green*255);
    rgba[2] = (short)round(blue*255);
    rgba[3] = (short)round(alpha*255);
    return Color_create(rgba);
}

static int
Button_set_background(ButtonObject* self, PyObject* value, void* closure)
{
    short rgba[4];
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    NSColor* color;
    Button* button = self->button;
    if (!Color_converter(value, rgba)) return -1;
    red = rgba[0] / 255.;
    green = rgba[1] / 255.;
    blue = rgba[2] / 255.;
    alpha = rgba[3] / 255.;
    color = [NSColor colorWithCalibratedRed: red
                                      green: green
                                       blue: blue
                                      alpha: alpha];
    [[button cell] setBackgroundColor: color];
    button.needsDisplay = YES;
    return 0;
}

static char Button_background__doc__[] = "background color.";

static PyObject* Button_get_foreground(ButtonObject* self, void* closure)
{
    short rgba[4];
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    fprintf(stderr, "Should call [button attributedTitle]\n"); fflush(stderr);
    red = 0.0;
    green = 0.0;
    blue = 0.0;
    alpha = 0.0;
/*
    Button* button = self->button;
    NSAttributedString* text = [button attributedTitle];
    NSColor* color = [text attribute: NSForegroundColorAttributeName
                             atIndex: 0
                      effectiveRange: NULL];
    color = [color colorUsingColorSpace: [NSColorSpace genericRGBColorSpace]];
    [color getRed: &red green: &green blue: &blue alpha: &alpha];
*/
    rgba[0] = (short)round(red*255);
    rgba[1] = (short)round(green*255);
    rgba[2] = (short)round(blue*255);
    rgba[3] = (short)round(alpha*255);
    return Color_create(rgba);
}

static int
Button_set_foreground(ButtonObject* self, PyObject* value, void* closure)
{
    short rgba[4];
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
/*
    NSColor* color;
    NSRange range;
*/
    Button* button = self->button;
/*
    NSMutableAttributedString *text;
*/
    if (!Color_converter(value, rgba)) return -1;
    red = rgba[0] / 255.;
    green = rgba[1] / 255.;
    blue = rgba[2] / 255.;
    alpha = rgba[3] / 255.;
    fprintf(stderr, "Should call [button attributedTitle]\n"); fflush(stderr);
/*
    color = [NSColor colorWithCalibratedRed: red
                                      green: green
                                       blue: blue
                                      alpha: alpha];
    text = [[NSMutableAttributedString alloc] initWithAttributedString:[button attributedTitle]];
    range = NSMakeRange(0, [text length]);
    [text addAttribute: NSForegroundColorAttributeName
                  value: color
                  range: range];
    [button setAttributedTitle:text];
*/
    button.needsDisplay = YES;
    return 0;
}

static char Button_foreground__doc__[] = "foreground color.";

static PyGetSetDef Button_getseters[] = {
    {"minimum_size", (getter)Button_get_minimum_size, (setter)NULL, Button_minimum_size__doc__, NULL},
    {"command", (getter)Button_get_command, (setter)Button_set_command, Button_command__doc__, NULL},
    {"background", (getter)Button_get_background, (setter)Button_set_background, Button_background__doc__, NULL},
    {"foreground", (getter)Button_get_foreground, (setter)Button_set_foreground, Button_foreground__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Button_doc[] =
"A Button object wraps a Cocoa NSButton object.\n";

PyTypeObject ButtonType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Button",            /* tp_name */
    sizeof(ButtonObject),       /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Button_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Button_repr,      /* tp_repr */
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
    Button_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Button_methods,             /* tp_methods */
    0,                          /* tp_members */
    Button_getseters,           /* tp_getset */
    &WidgetType,                /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Button_init,      /* tp_init */
    0,                          /* tp_alloc */
    Button_new,                 /* tp_new */
};
