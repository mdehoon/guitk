#include <Cocoa/Cocoa.h>
#include "window.h"
#include "widgets.h"
#include "label.h"
#include "button.h"

#if PY_MAJOR_VERSION >= 3
#define PY3K 1
#else
#if PY_MINOR_VERSION < 7
#error Python version should be 2.7 or newer
#else
#define PY3K 0
#endif
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
#define COMPILING_FOR_10_7
#endif


@interface View : NSView <NSWindowDelegate>
{
}
- (BOOL)isFlipped;
- (BOOL)autoresizesSubviews;
@end

@implementation View
- (BOOL)isFlipped
{
    return YES;
}

- (BOOL)autoresizesSubviews
{
    return NO;
}
@end

typedef struct {
    PyObject_HEAD
    NSWindow* window;
} Window;

static PyObject*
Window_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    Window *self = (Window*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->window = NULL;
    return (PyObject*)self;
}

static int
Window_init(Window *self, PyObject *args, PyObject *kwds)
{
    NSRect rect;
    NSWindow* window;
    View* view;
    const char* title = "";
    int width = 100;
    int height = 100;

    if (!PyArg_ParseTuple(args, "|iis", &width, &height, &title)) return -1;

    rect.origin.x = 100;
    rect.origin.y = 350;
    rect.size.height = height;
    rect.size.width = width;

    NSApp = [NSApplication sharedApplication];
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    window = [NSWindow alloc];
    if (!window) return -1;
    [window initWithContentRect: rect
                      styleMask: NSTitledWindowMask
                               | NSClosableWindowMask
                               | NSResizableWindowMask
                               | NSMiniaturizableWindowMask
                        backing: NSBackingStoreBuffered
                          defer: YES];
    [window setTitle: [NSString stringWithCString: title
                                         encoding: NSASCIIStringEncoding]];

    [window setAcceptsMouseMovedEvents: YES];
    view = [[View alloc] initWithFrame: rect];
    [window setContentView: view];
    [window setDelegate: view];

    self->window = window;

    [pool release];
    return 0;
}

static PyObject*
Window_repr(Window* self)
{
#if PY3K
    return PyUnicode_FromFormat("Window object %p wrapping NSWindow %p",
                               (void*) self, (void*)(self->window));
#else
    return PyString_FromFormat("Window object %p wrapping NSWindow %p",
                               (void*) self, (void*)(self->window));
#endif
}

static void
Window_dealloc(Window* self)
{
    NSWindow* window = self->window;
    if (window)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [window close];
        [pool release];
    }
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Window_show(Window* self)
{
    NSWindow* window = self->window;
    if (window)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [window makeKeyAndOrderFront: nil];
        [window orderFrontRegardless];
        [pool release];
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_close(Window* self)
{
    NSWindow* window = self->window;
    if (window)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [window close];
        [pool release];
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_iconify(Window* self)
{
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    [window miniaturize: NSApp];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_deiconify(Window* self)
{
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    [window deminiaturize: NSApp];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_put(Window* self, PyObject *args, PyObject *kwds)
{
    PyObject* object;
    PyObject* item;
    PyObject* items;
    Py_ssize_t i;
    Py_ssize_t n;
    View* view;

    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }

    view = [window contentView];
    if (!PyArg_ParseTuple(args, "O", &object))
        return NULL;
    if (!PyMapping_Check(object)) {
        PyErr_SetString(PyExc_RuntimeError, "argument is not a layout manager");
        return NULL;
    }
    items = PyMapping_Values(object);
    n = PyMapping_Length(object);
    for (i = 0; i < n; i++) {
        item = PyList_GET_ITEM(items, i);
        if (!PyObject_IsInstance(item, widgets)) break;
        printf("Item %ld OK\n", i);
    }

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_add(Window* self, PyObject *args, PyObject *kwds)
{
    PyObject* object;
    View* view;

    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }

    view = [window contentView];
    if (!PyArg_ParseTuple(args, "O", &object))
        return NULL;

    if (PyObject_IsInstance(object, (PyObject*) &LabelType)) {
        PyLabel* label = (PyLabel*)object;
        Py_INCREF(label);
        [view addSubview: label->label];
    } else
    if (PyObject_IsInstance(object, (PyObject*) &ButtonType)) {
        PyButton* button = (PyButton*)object;
        Py_INCREF(button);
        [view addSubview: button->button];
    } else {
        PyErr_SetString(PyExc_TypeError, "windows can only add labels or buttons");
        return NULL;
    }

    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Window_methods[] = {
    {"show",
     (PyCFunction)Window_show,
     METH_NOARGS,
     "Shows the window."
    },
    {"close",
     (PyCFunction)Window_close,
     METH_NOARGS,
     "Closes the window."
    },
    {"iconify",
     (PyCFunction)Window_iconify,
     METH_NOARGS,
     "Attempts to iconify the window."
    },
    {"deiconify",
     (PyCFunction)Window_deiconify,
     METH_NOARGS,
     "Attempts to deiconify the window."
    },
    {"put",
     (PyCFunction)Window_put,
     METH_VARARGS,
     "Sets the layout manager."
    },
    {"add",
     (PyCFunction)Window_add,
     METH_VARARGS,
     "Adds a control to the window."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Window_get_title(Window* self, void* closure)
{
    NSWindow* window = self->window;
    PyObject* result = NULL;
    if (window)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        NSString* title = [window title];
        if (title) {
            const char* cTitle = [title UTF8String];
#if PY3K || (PY_MAJOR_VERSION == 2 && PY_MINOR_VERSION >= 6)
            result = PyUnicode_FromString(cTitle);
#else
            result = PyString_FromString(cTitle);
#endif
        }
        [pool release];
    }
    if (result) {
        return result;
    } else {
        Py_INCREF(Py_None);
        return Py_None;
    }
}

static int
Window_set_title(Window* self, PyObject* value, void* closure)
{
    char* title;
    title = PyString_AsString(value);
    if (!title) return -1;

    NSWindow* window = self->window;
    if (window)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        NSString* s = [[NSString alloc] initWithCString: title
                                               encoding: NSUTF8StringEncoding];
        [window setTitle: s];
        [s release];
        [pool release];
    }
    return 0;
}

static char Window_title__doc__[] = "window title";

static PyObject* Window_get_origin(Window* self, void* closure)
{
    CGFloat x;
    CGFloat y;
    CGFloat height;
    NSRect frame;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    frame = [[window screen] visibleFrame];
    height = NSMaxY(frame);
    frame = [window frame];
    x = NSMinX(frame);
    y = height - NSMaxY(frame);
    return Py_BuildValue("ii", (int) round(x), (int) round(y));
}

static int Window_set_origin(Window* self, PyObject* value, void* closure)
{
    int x;
    int y;
    CGFloat height;
    NSPoint point;
    NSRect frame;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    if (!PyArg_ParseTuple(value, "ii", &x, &y)) return -1;
    frame = [[window screen] visibleFrame];
    height = NSMaxY(frame);
    point.x = x;
    point.y = height - y;
    [window setFrameTopLeftPoint: point];
    return 0;
}

static char Window_origin__doc__[] = "position of the top-left corner of the window";

static PyObject* Window_get_width(Window* self, void* closure)
{
    long width;
    NSWindow* window = self->window;
    NSRect frame;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    frame = [[window contentView] frame];
    width = round(frame.size.width);
    return PyInt_FromLong(width);
}

static int Window_set_width(Window* self, PyObject* value, void* closure)
{
    double width;
    NSRect frame;
    NSSize size;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    width = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    frame = [[window contentView] frame];
    size = frame.size;
    size.width = width;
    [window setContentSize: size];
    return 0;
}

static char Window_width__doc__[] = "width of window content";

static PyObject* Window_get_height(Window* self, void* closure)
{
    long height;
    NSRect frame;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    frame = [[window contentView] frame];
    height = round(frame.size.height);
    return PyInt_FromLong(height);
}

static int Window_set_height(Window* self, PyObject* value, void* closure)
{
    int height;
    NSRect frame;
    NSSize size;
    NSPoint point;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    frame = [window frame];
    size = frame.size;
    point = frame.origin;
    point.y += size.height;
    height = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    size.height = height;
    [window setContentSize: size];
    [window setFrameTopLeftPoint: point];
    return 0;
}

static char Window_height__doc__[] = "height of window content";

static PyObject* Window_get_size(Window* self, void* closure)
{
    int width;
    int height;
    NSRect frame;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    frame = [[window contentView] frame];
    width = round(frame.size.width);
    height = round(frame.size.height);
    return Py_BuildValue("ii", width, height);
}

static int Window_set_size(Window* self, PyObject* value, void* closure)
{
    int width;
    int height;
    NSRect frame;
    NSSize size;
    NSPoint point;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    frame = [window frame];
    size = frame.size;
    point = frame.origin;
    point.y += size.height;
    if (!PyArg_ParseTuple(value, "ii", &width, &height)) return -1;
    size.width = width;
    size.height = height;
    [window setContentSize: size];
    [window setFrameTopLeftPoint: point];
    return 0;
}

static char Window_size__doc__[] = "window content size";

static PyObject* Window_get_frame(Window* self, void* closure)
{
    CGFloat x;
    CGFloat y;
    CGFloat width;
    CGFloat height;
    NSRect frame;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    frame = [[window screen] visibleFrame];
    height = NSMaxY(frame);
    frame = [window frame];
    x = NSMinX(frame);
    y = height - NSMaxY(frame);
    width = NSWidth(frame);
    height = NSHeight(frame);
    return Py_BuildValue("iiii", (int) round(x), (int) round(y),
                                 (int) round(width), (int) round(height));
}

static int Window_set_frame(Window* self, PyObject* value, void* closure)
{
    int x;
    int y;
    int width;
    int height;
    NSRect rect;
    NSRect frame;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    if (!PyArg_ParseTuple(value, "iiii", &x, &y, &width, &height)) return -1;
    frame = [[window screen] visibleFrame];
    rect.origin.x = x;
    rect.origin.y = NSMaxY(frame) - y - height;
    rect.size.width = width;
    rect.size.height = height;
    [window setFrame: rect display: NO];
    return 0;
}

static char Window_frame__doc__[] = "position and size of the window; position is the position of the top-left corner of the window; the size is the window size, which may be larger than the content size";

static PyObject* Window_get_resizable(Window* self, void* closure)
{
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if (window.styleMask & NSResizableWindowMask) Py_RETURN_TRUE;
    Py_RETURN_FALSE;
}

static int
Window_set_resizable(Window* self, PyObject* value, void* closure)
{
    int flag;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    flag = PyObject_IsTrue(value);
    switch (flag) {
        case 1: window.styleMask |= NSResizableWindowMask; break;
        case 0: window.styleMask &= ~NSResizableWindowMask; break;
        case -1: return -1;
    }
    return 0;
}

static char Window_resizable__doc__[] = "specifies whether the window can be resized by the user";

static PyObject* Window_get_min_width(Window* self, void* closure)
{
    long width;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    width = (int) window.minSize.width;
    return PyInt_FromLong(width);
}

static int
Window_set_min_width(Window* self, PyObject* value, void* closure)
{
    long width;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    width = PyInt_AsLong(value);
    if (PyErr_Occurred()) return -1;
    size = window.minSize;
    size.width = width;
    window.minSize = size;
    return 0;
}

static char Window_min_width__doc__[] = "the minimum width to which the window can be resized by the user";

static PyObject* Window_get_max_width(Window* self, void* closure)
{
    long width;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    width = (int) window.maxSize.width;
    return PyInt_FromLong(width);
}

static int
Window_set_max_width(Window* self, PyObject* value, void* closure)
{
    long width;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    width = PyInt_AsLong(value);
    if (PyErr_Occurred()) return -1;
    size = window.maxSize;
    size.width = width;
    window.maxSize = size;
    return 0;
}

static char Window_max_width__doc__[] = "the maximum width to which the window can be resized by the user";

static PyObject* Window_get_min_height(Window* self, void* closure)
{
    long height;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    height = (int) window.minSize.height;
    return PyInt_FromLong(height);
}

static int
Window_set_min_height(Window* self, PyObject* value, void* closure)
{
    long height;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    height = PyInt_AsLong(value);
    if (PyErr_Occurred()) return -1;
    size = window.minSize;
    size.height = height;
    window.minSize = size;
    return 0;
}

static char Window_min_height__doc__[] = "the minimum height to which the window can be resized by the user";

static PyObject* Window_get_max_height(Window* self, void* closure)
{
    long height;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    height = (int) window.maxSize.height;
    return PyInt_FromLong(height);
}

static int
Window_set_max_height(Window* self, PyObject* value, void* closure)
{
    long height;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    height = PyInt_AsLong(value);
    if (PyErr_Occurred()) return -1;
    size = window.maxSize;
    size.height = height;
    window.maxSize = size;
    return 0;
}

static char Window_max_height__doc__[] = "the maximum height to which the window can be resized by the user";

static PyObject* Window_get_fullscreen(Window* self, void* closure)
{
#ifdef COMPILING_FOR_10_7
    NSUInteger styleMask;
#endif
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
#ifdef COMPILING_FOR_10_7
    styleMask = [window styleMask];
    if (styleMask & NSFullScreenWindowMask) Py_RETURN_TRUE;
#endif
    Py_RETURN_FALSE;
}

static int
Window_set_fullscreen(Window* self, PyObject* value, void* closure)
{
#ifdef COMPILING_FOR_10_7
    BOOL fullscreen;
    NSUInteger styleMask;
#endif
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
#ifdef COMPILING_FOR_10_7
    styleMask = [window styleMask];
    fullscreen = (styleMask & NSFullScreenWindowMask) ? true : false;
    if (value==Py_False) {
        if (!fullscreen) return 0;
    }
    else if (value==Py_True) {
        if (fullscreen) return 0;
    }
    else {
        PyErr_SetString(PyExc_RuntimeError, "fullscreen should be True or False");
        return -1;
    }
    [window toggleFullScreen: NSApp];
    return 0;
#else
    if (value==Py_False) return 0;
    PyErr_SetString(PyExc_RuntimeError, "fullscreen mode is not available if compiled for Mac OS X versions older than 10.7.");
    return -1;
#endif
}

static char Window_fullscreen__doc__[] = "specify if the window is in full-screen mode";

static PyObject* Window_get_zoomed(Window* self, void* closure)
{
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if (window.zoomed) Py_RETURN_TRUE;
    Py_RETURN_FALSE;
}

static int
Window_set_zoomed(Window* self, PyObject* value, void* closure)
{
    BOOL zoomed;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    zoomed = window.zoomed;
    if (value==Py_False) {
        if (!zoomed) return 0;
    }
    else if (value==Py_True) {
        if (zoomed) return 0;
    }
    else {
        PyErr_SetString(PyExc_RuntimeError, "zoomed should be True or False");
        return -1;
    }
    [window zoom: NSApp];
    return 0;
}

static char Window_zoomed__doc__[] = "specify if the window is in full-screen mode";

static PyObject* Window_get_topmost(Window* self, void* closure)
{
    const char* s = "(unknown)";
    NSInteger level;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    level = [window level];
    if (level==NSNormalWindowLevel) Py_RETURN_FALSE;
    else if (level==NSStatusWindowLevel) Py_RETURN_TRUE;
    if (level== NSFloatingWindowLevel) s = "NSFloatingWindowLevel";
    else if (level== NSSubmenuWindowLevel) s = "NSSubmenuWindowLevel";
    else if (level== NSTornOffMenuWindowLevel) s = "NSTornOffMenuWindowLevel";
    else if (level== NSMainMenuWindowLevel) s = "NSMainMenuWindowLevel";
    else if (level== NSModalPanelWindowLevel) s = "NSModalPanelWindowLevel";
    else if (level== NSPopUpMenuWindowLevel) s = "NSPopUpMenuWindowLevel";
    else if (level== NSScreenSaverWindowLevel) s = "NSScreenSaverWindowLevel";
    else if (level== NSDockWindowLevel) s = "NSDockWindowLevel";
    PyErr_Format(PyExc_RuntimeError, "unexpected window level %s", s);
    return NULL;
}

static int
Window_set_topmost(Window* self, PyObject* value, void* closure)
{
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    if (value==Py_False) [window setLevel: NSNormalWindowLevel];
    else if (value==Py_True) [window setLevel: NSStatusWindowLevel];
    else {
        PyErr_SetString(PyExc_RuntimeError, "topmost should be True or False");
        return -1;
    }
    return 0;
}

static char Window_topmost__doc__[] = "True if the window is topmost; False otherwise";

static PyObject* Window_get_iconified(Window* self, void* closure)
{
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if ([window isMiniaturized]) Py_RETURN_TRUE;
    Py_RETURN_FALSE;
}

static char Window_iconified__doc__[] = "True if the window is iconified; False otherwise";

static PyObject* Window_get_alpha(Window* self, void* closure)
{
    double alpha;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    alpha = [window alphaValue];
    return PyFloat_FromDouble(alpha);
}

static int
Window_set_alpha(Window* self, PyObject* value, void* closure)
{
    double alpha;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    alpha = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    if (alpha < 0.0) alpha = 0.0;
    else if (alpha > 1.0) alpha = 1.0;
    [window setAlphaValue: alpha];
    return 0;
}

static char Window_alpha__doc__[] = "alpha transparency level of the window, ranging from 0.0 (fully transparent) to 1.0 (opaque); values outside this range will be clipped. If not supported, the alpha value remains at 1.0.";

static PyGetSetDef Window_getset[] = {
    {"title", (getter)Window_get_title, (setter)Window_set_title, Window_title__doc__, NULL},
    {"origin", (getter)Window_get_origin, (setter)Window_set_origin, Window_origin__doc__, NULL},
    {"width", (getter)Window_get_width, (setter)Window_set_width, Window_width__doc__, NULL},
    {"height", (getter)Window_get_height, (setter)Window_set_height, Window_height__doc__, NULL},
    {"size", (getter)Window_get_size, (setter)Window_set_size, Window_size__doc__, NULL},
    {"frame", (getter)Window_get_frame, (setter)Window_set_frame, Window_frame__doc__, NULL},
    {"resizable", (getter)Window_get_resizable, (setter)Window_set_resizable, Window_resizable__doc__, NULL},
    {"min_width", (getter)Window_get_min_width, (setter)Window_set_min_width, Window_min_width__doc__, NULL},
    {"max_width", (getter)Window_get_max_width, (setter)Window_set_max_width, Window_max_width__doc__, NULL},
    {"min_height", (getter)Window_get_min_height, (setter)Window_set_min_height, Window_min_height__doc__, NULL},
    {"max_height", (getter)Window_get_max_height, (setter)Window_set_max_height, Window_max_height__doc__, NULL},
    {"fullscreen", (getter)Window_get_fullscreen, (setter)Window_set_fullscreen, Window_fullscreen__doc__, NULL},
    {"zoomed", (getter)Window_get_zoomed, (setter)Window_set_zoomed, Window_zoomed__doc__, NULL},
    {"iconified", (getter)Window_get_iconified, (setter)NULL, Window_iconified__doc__, NULL},
    {"topmost", (getter)Window_get_topmost, (setter)Window_set_topmost, Window_topmost__doc__, NULL},
    {"alpha", (getter)Window_get_alpha, (setter)Window_set_alpha, Window_alpha__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Window_doc[] =
"A Window object wraps a Cocoa NSWindow object.\n";

static PyTypeObject WindowType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Window",            /* tp_name */
    sizeof(Window),             /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Window_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Window_repr,      /* tp_repr */
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
    Window_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Window_methods,             /* tp_methods */
    0,                          /* tp_members */
    Window_getset,              /* tp_getset */
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Window_init,      /* tp_init */
    0,                          /* tp_alloc */
    Window_new,                 /* tp_new */
};

int initialize_window(PyObject* module) {
    if (PyType_Ready(&WindowType) < 0) return -1;
    Py_INCREF(&WindowType);
    return PyModule_AddObject(module, "Window", (PyObject*) &WindowType);
}

/*
Remaining:
    wm group window ?pathName? 
    wm iconbitmap window ?bitmap? 
    wm iconify window 
    wm iconmask window ?bitmap? 
    wm iconname window ?newName? 
    wm iconposition window ?x y? 
    wm iconwindow window ?pathName? 
    wm maxsize window ?width height? 
    wm minsize window ?width height? 
    wm overrideredirect window ?boolean? 
    wm positionfrom window ?who? 
    wm protocol window ?name? ?command? 
    wm resizable window ?width height? 
    wm sizefrom window ?who? 
    wm stackorder window ?isabove|isbelow window? 
    wm state window ?newstate? 
    wm title window ?string? 
    wm transient window ?master? 
    wm withdraw window 
*/
