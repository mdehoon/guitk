#include <Cocoa/Cocoa.h>
#include "window.h"
#include "widgets.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
#define COMPILING_FOR_10_6
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
#define COMPILING_FOR_10_7
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10120
#define COMPILING_FOR_10_12
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10130
#define COMPILING_FOR_10_13
#endif

#ifndef CGFloat
#define CGFloat float
#endif


@implementation Window
- (void) displayIfNeeded
{
    NSView *view = [self contentView];
    if ([view isKindOfClass: [WidgetView class]]) {
        PyObject* result;
        PyGILState_STATE gstate;
        NSRect frame;
        WidgetObject* object = (WidgetObject*) ((WidgetView*)view)->object;
        CGSize minimum_size = object->minimum_size;
        double x, y, width, height;
        NSRect rect = view.frame;
        if (minimum_size.width == 0 || minimum_size.height == 0) {
            gstate = PyGILState_Ensure();
            result = Widget_get_minimum_size(object, NULL);
            if (result) Py_DECREF(result);
            else PyErr_Print();
            PyGILState_Release(gstate);
            if (!result) return;
            minimum_size = object->minimum_size;
        }
        if (rect.size.width < minimum_size.width) rect.size.width = minimum_size.width;
        if (rect.size.height < minimum_size.height) rect.size.height = minimum_size.height;
        frame = [self frameRectForContentRect:rect];
        frame.origin = self.frame.origin;
        frame.origin.y -= frame.size.height - self.frame.size.height;
        [self setFrame: frame display: NO];
        x = rect.origin.x;
        y = rect.origin.y;
        width = rect.size.width;
        height = rect.size.height;
        gstate = PyGILState_Ensure();
        result = PyObject_CallMethod((PyObject *)object, "place", "dddd", x, y, width, height, NULL);
        if (result) Py_DECREF(result);
        else PyErr_Print();
        PyGILState_Release(gstate);
    }
    // otherwise, the contentView of this window was not yet loaded with a widget.
    [super displayIfNeeded];
}
@synthesize object = _object;

- (Window*)initWithContentRect: (NSRect)rect
                     styleMask: (NSUInteger)windowStyle
                        object: (WindowObject*)object
{
    self = [self initWithContentRect: rect
                           styleMask: windowStyle
                             backing: NSBackingStoreBuffered
                               defer: YES];
    _object = object;
    self.releasedWhenClosed = NO;
    self.acceptsMouseMovedEvents = YES;
    self.delegate = self;
    return self;
}

- (void)windowWillClose:(NSNotification *)notification
{
    Py_DECREF(_object);
}

- (void)windowDidBecomeKey:(NSNotification *)notification;
{
    _object->is_key = true;
    self.contentView.needsDisplay = YES;
}

- (void)windowDidResignKey:(NSNotification *)notification;
{
    _object->is_key = false;
    self.contentView.needsDisplay = YES;
}
@end

static int converter(PyObject* object, void* address)
{
    NSWindow** p;
    if (!PyObject_IsInstance(object, (PyObject*) &WindowType)) {
        PyErr_SetString(PyExc_RuntimeError, "expected a window");
        return 0;
    }
    WindowObject* window = (WindowObject*)object;
    p = address;
    *p = window->window;
    return 1;
}

static PyObject*
Window_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    WindowObject *self = (WindowObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->window = NULL;
    return (PyObject*)self;
}

static int
Window_init(WindowObject *self, PyObject *args, PyObject *keywords)
{
    NSRect rect;
    NSUInteger windowStyle;
    Window* window;
    PyObject* argument = NULL;
    const char* title = NULL;
    int width = 100;
    int height = 100;
    static char* kwlist[] = {"width", "height", "title", NULL};

    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|iiO", kwlist,
                                     &width, &height, &argument))
        return -1;

    if (argument == Py_None) {
#ifdef COMPILING_FOR_10_12
        windowStyle = NSWindowStyleMaskBorderless;
#else
        windowStyle = NSBorderlessWindowMask;
#endif
    }
    else  {
#ifdef COMPILING_FOR_10_12
        windowStyle = NSWindowStyleMaskTitled
                    | NSWindowStyleMaskClosable
                    | NSWindowStyleMaskResizable
                    | NSWindowStyleMaskMiniaturizable;
#else
        windowStyle = NSTitledWindowMask
                    | NSClosableWindowMask
                    | NSResizableWindowMask
                    | NSMiniaturizableWindowMask;
#endif
        if (argument == NULL) title = "";
        else if (PyUnicode_Check(argument)) {
            argument = PyUnicode_AsUTF8String(argument);
            if (!argument) return -1;
            title = PyBytes_AS_STRING(argument);
        }
        else {
            PyErr_SetString(PyExc_TypeError,
                            "title should be a string or None");
        }
    }

    rect.origin.x = 100;
    rect.origin.y = 350;
    rect.size.height = height;
    rect.size.width = width;

    NSApp = [NSApplication sharedApplication];
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    window = [Window alloc];
    if (!window) return -1;
    window = [window initWithContentRect: rect
                               styleMask: windowStyle
                                  object: self];
    if (title) {
        [window setTitle: [NSString stringWithCString: title
                                             encoding: NSUTF8StringEncoding]];
        if (argument) Py_DECREF(argument);
    }
    self->window = window;

    [pool release];

    return 0;
}

static PyObject*
Window_repr(WindowObject* self)
{
    Window* window = self->window;
    return PyUnicode_FromFormat("Window object %p wrapping NSWindow %p",
                                self, window);
}

static void
Window_dealloc(WindowObject* self)
{
    /* If Window.__init__ fails, then Window_dealloc is called before
     * all member objects have been initialized. Some members may therefore
     * still be NULL.
     */
    NSWindow* window = self->window;
    if (window) [window release];
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Window_show(WindowObject* self)
{
    Window* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if (!window.visible)
    {
        if (!window.miniaturized) {
            PyObject* object = (PyObject*)window.object;
            Py_INCREF(object);
        }
        [window makeKeyAndOrderFront: nil];
        [window orderFrontRegardless];
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_close(WindowObject* self)
{
    Window* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if (window.visible || window.miniaturized) [window close];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_iconify(WindowObject* self)
{
    Window* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if (window.visible && !window.miniaturized) [window miniaturize: NSApp];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_deiconify(WindowObject* self)
{
    Window* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if (!window.visible)
    {
        if (!window.miniaturized) {
            PyObject* object = (PyObject*) window.object;
            Py_INCREF(object);
        }
        [window deminiaturize: NSApp];
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_add_child(WindowObject* self, PyObject *args, PyObject *keywords)

{
    static char* kwlist[] = {"child", "above", NULL};
    PyObject* above;
    NSWindowOrderingMode ordered;
    NSWindow* child;
    NSWindow* parent;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }

    if (!PyArg_ParseTupleAndKeywords(args, keywords, "O&|O", kwlist,
                                     converter, &child, &above))
        return NULL;

    parent = window;
    while (parent) {
        if (parent==child) {
            PyErr_SetString(PyExc_ValueError,
                            "cyclical parent-child relations are not allowed");
            return NULL;
        }
        parent = [parent parentWindow];
    }

    if (above==Py_True) ordered = NSWindowAbove;
    else if (above==Py_False) ordered = NSWindowBelow;
    else {
        PyErr_SetString(PyExc_ValueError, "above should be True or False");
        return NULL;
    }
    [window addChildWindow: child ordered: ordered];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_remove_child(WindowObject* self, PyObject *args, PyObject *keywords)

{
    static char* kwlist[] = {"child", NULL};
    NSWindow* child;
    NSArray* children;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }

    if (!PyArg_ParseTupleAndKeywords(args, keywords, "O&", kwlist,
                                     converter, &child))
        return NULL;

    children = [window childWindows];
    if (![children containsObject: child]) {
        PyErr_SetString(PyExc_ValueError, "child window not found");
        return NULL;
    }
    [window removeChildWindow: child];

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
    {"add_child",
     (PyCFunction)Window_add_child,
     METH_KEYWORDS | METH_VARARGS,
     "Adds a child window."
    },
    {"remove_child",
     (PyCFunction)Window_remove_child,
     METH_KEYWORDS | METH_VARARGS,
     "Removes a child window."
    },
    {NULL, NULL, 0, NULL}  /* Sentinel */
};

static PyObject* Window_get_content(WindowObject* self, void* closure)
{
    PyObject* object;
    WidgetView* view;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    view = (WidgetView*) window.contentView;
    if (view) {
        object = (PyObject*) (view->object);
    }
    else {
        object = Py_None;
    }
    Py_INCREF(object);
    return object;
}

static int
Window_set_content(WindowObject* self, PyObject* value, void* closure)
{
    PyObject* size;
    PyGILState_STATE gstate;
    PyTypeObject* type;
    WidgetObject* widget;
    NSView* view;
    Window* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    type = Py_TYPE(value);
    if (!PyType_IsSubtype(type, &WidgetType)) {
        PyErr_SetString(PyExc_ValueError, "expected a widget or None");
        return -1;
    }
    widget = (WidgetObject*)value;
    view = widget->view;
    gstate = PyGILState_Ensure();
    size = PyObject_GetAttrString(value, "minimum_size");
    if (size) {
        Py_DECREF(size);
        PyGILState_Release(gstate);
    }
    else {
        PyErr_Print();
        PyGILState_Release(gstate);
        return -1;
    }
    window.contentSize = widget->minimum_size;
    [view setFrameSize: widget->minimum_size];
    if (window.contentView) {
        [window.contentView removeFromSuperview];
    }
    Py_INCREF(value);
    window.contentView = view;
    return 0;
}

static char Window_content__doc__[] = "window content";

static PyObject* Window_get_title(WindowObject* self, void* closure)
{
    PyObject* result = NULL;
    NSAutoreleasePool* pool;
    NSString* title;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
#ifdef COMPILING_FOR_10_12
    if (! (window.styleMask & NSWindowStyleMaskTitled)) {
#else
    if (! (window.styleMask & NSTitledWindowMask)) {
#endif
        Py_INCREF(Py_None);
        return Py_None;
    }
    pool = [[NSAutoreleasePool alloc] init];
    title = [window title];
    if (title) {
        const char* cTitle = [title UTF8String];
        result = PyUnicode_FromString(cTitle);
    }
    [pool release];
    return result;
}

static int
Window_set_title(WindowObject* self, PyObject* value, void* closure)
{
    NSWindow* window;
    NSAutoreleasePool* pool;
    NSString* s;

#ifdef COMPILING_FOR_10_12
    const NSUInteger mask = NSWindowStyleMaskTitled
                          | NSWindowStyleMaskClosable
                          | NSWindowStyleMaskResizable
                          | NSWindowStyleMaskMiniaturizable;
#else
    const NSUInteger mask = NSTitledWindowMask
                          | NSClosableWindowMask
                          | NSResizableWindowMask
                          | NSMiniaturizableWindowMask;
#endif
    window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }

    if (value == Py_None) {
        if (! (window.styleMask & mask)) return 0;
#ifdef COMPILING_FOR_10_6
        window.styleMask &= ~mask;
        return 0;
#else
        PyErr_SetString(PyExc_RuntimeError, "if compiled for Mac OS X versions older than 10.6, the window style cannot be changed after the window is created.");
        return -1;
#endif
    }

    value = PyUnicode_AsUTF8String(value);
    if (!value) return -1;

    if (! (window.styleMask & mask)) {
#ifdef COMPILING_FOR_10_6
        window.styleMask |= mask;
#else
        PyErr_SetString(PyExc_RuntimeError, "if compiled for Mac OS X versions older than 10.6, the window style cannot be changed after the window is created.");
        return -1;
#endif
    }
    pool = [[NSAutoreleasePool alloc] init];
    s = [[NSString alloc] initWithCString: PyBytes_AS_STRING(value)
                                 encoding: NSUTF8StringEncoding];
    [window setTitle: s];
    [s release];
    [pool release];
    Py_DECREF(value);
    return 0;
}

static char Window_title__doc__[] = "window title";

static PyObject* Window_get_origin(WindowObject* self, void* closure)
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

static int Window_set_origin(WindowObject* self, PyObject* value, void* closure)
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

static PyObject* Window_get_width(WindowObject* self, void* closure)
{
    long width;
    NSWindow* window = self->window;
    NSRect frame;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    frame = window.contentView.frame;
    width = round(frame.size.width);
    return PyLong_FromLong(width);
}

static int Window_set_width(WindowObject* self, PyObject* value, void* closure)
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
    frame = window.contentView.frame;
    size = frame.size;
    size.width = width;
    window.contentSize = size;
    return 0;
}

static char Window_width__doc__[] = "width of window content";

static PyObject* Window_get_height(WindowObject* self, void* closure)
{
    long height;
    NSRect frame;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    frame = window.contentView.frame;
    height = round(frame.size.height);
    return PyLong_FromLong(height);
}

static int Window_set_height(WindowObject* self, PyObject* value, void* closure)
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
    window.contentSize = size;
    [window setFrameTopLeftPoint: point];
    return 0;
}

static char Window_height__doc__[] = "height of window content";

static PyObject* Window_get_size(WindowObject* self, void* closure)
{
    CGFloat width;
    CGFloat height;
    NSRect frame;
    NSWindow* window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    frame = window.contentView.frame;
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("dd", width, height);
}

static int Window_set_size(WindowObject* self, PyObject* value, void* closure)
{
    double width;
    double height;
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
    if (!PyArg_ParseTuple(value, "dd", &width, &height)) return -1;
    size.width = width;
    size.height = height;
    window.contentSize = size;
    [window setFrameTopLeftPoint: point];
    return 0;
}

static char Window_size__doc__[] = "window content size";

static PyObject* Window_get_frame(WindowObject* self, void* closure)
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

static int Window_set_frame(WindowObject* self, PyObject* value, void* closure)
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

static PyObject* Window_get_resizable(WindowObject* self, void* closure)
{
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
#ifdef COMPILING_FOR_10_12
    if (window.styleMask & NSWindowStyleMaskResizable) Py_RETURN_TRUE;
#else
    if (window.styleMask & NSResizableWindowMask) Py_RETURN_TRUE;
#endif
    Py_RETURN_FALSE;
}

static int
Window_set_resizable(WindowObject* self, PyObject* value, void* closure)
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
#ifdef COMPILING_FOR_10_12
        case 1: window.styleMask |= NSWindowStyleMaskResizable; break;
        case 0: window.styleMask &= ~NSWindowStyleMaskResizable; break;
#else
        case 1: window.styleMask |= NSResizableWindowMask; break;
        case 0: window.styleMask &= ~NSResizableWindowMask; break;
#endif
        case -1: return -1;
    }
    return 0;
}

static char Window_resizable__doc__[] = "specifies whether the window can be resized by the user";

static PyObject* Window_get_min_width(WindowObject* self, void* closure)
{
    long width;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    width = (int) window.minSize.width;
    return PyLong_FromLong(width);
}

static int
Window_set_min_width(WindowObject* self, PyObject* value, void* closure)
{
    long width;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    if (value == Py_None) {
        width = 0;
    } else {
        width = PyLong_AsLong(value);
        if (PyErr_Occurred()) return -1;
    }
    size = window.minSize;
    size.width = width;
    window.minSize = size;
    return 0;
}

static char Window_min_width__doc__[] = "the minimum width to which the window can be resized by the user";

static PyObject* Window_get_max_width(WindowObject* self, void* closure)
{
    CGFloat width;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    width = window.maxSize.width;
    if (width > LONG_MAX) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyLong_FromLong((long)width);
}

static int
Window_set_max_width(WindowObject* self, PyObject* value, void* closure)
{
    long width;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    size = window.maxSize;
    if (value == Py_None) {
        size.width = FLT_MAX;
    } else {
        width = PyLong_AsLong(value);
        if (PyErr_Occurred()) return -1;
        size.width = width;
    }
    window.maxSize = size;
    return 0;
}

static char Window_max_width__doc__[] = "the maximum width to which the window can be resized by the user";

static PyObject* Window_get_min_height(WindowObject* self, void* closure)
{
    long height;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    height = (int) window.minSize.height;
    return PyLong_FromLong(height);
}

static int
Window_set_min_height(WindowObject* self, PyObject* value, void* closure)
{
    long height;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    if (value == Py_None) {
        height = 0;
    } else {
        height = PyLong_AsLong(value);
        if (PyErr_Occurred()) return -1;
    }
    size = window.minSize;
    size.height = height;
    window.minSize = size;
    return 0;
}

static char Window_min_height__doc__[] = "the minimum height to which the window can be resized by the user";

static PyObject* Window_get_max_height(WindowObject* self, void* closure)
{
    CGFloat height;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    height = window.maxSize.height;
    if (height > LONG_MAX) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyLong_FromLong((long)height);
}

static int
Window_set_max_height(WindowObject* self, PyObject* value, void* closure)
{
    long height;
    NSSize size;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    size = window.maxSize;
    if (value == Py_None) {
        size.height = FLT_MAX;
    } else {
        height = PyLong_AsLong(value);
        if (PyErr_Occurred()) return -1;
        size.height = height;
    }
    window.maxSize = size;
    return 0;
}

static char Window_max_height__doc__[] = "the maximum height to which the window can be resized by the user";

static PyObject* Window_get_fullscreen(WindowObject* self, void* closure)
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
#ifdef COMPILING_FOR_10_12
    if (styleMask & NSWindowStyleMaskFullScreen) Py_RETURN_TRUE;
#else
    if (styleMask & NSFullScreenWindowMask) Py_RETURN_TRUE;
#endif
#endif
    Py_RETURN_FALSE;
}

static int
Window_set_fullscreen(WindowObject* self, PyObject* value, void* closure)
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
#ifdef COMPILING_FOR_10_12
    fullscreen = (styleMask & NSWindowStyleMaskFullScreen) ? true : false;
#else
    fullscreen = (styleMask & NSFullScreenWindowMask) ? true : false;
#endif
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

static PyObject* Window_get_zoomed(WindowObject* self, void* closure)
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
Window_set_zoomed(WindowObject* self, PyObject* value, void* closure)
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

static PyObject* Window_get_visible(WindowObject* self, void* closure)
{
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if (window.visible) Py_RETURN_TRUE;
    Py_RETURN_FALSE;
}

static char Window_visible__doc__[] = "True if the window is being shown onscreen";

static PyObject* Window_get_topmost(WindowObject* self, void* closure)
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
#ifndef COMPILING_FOR_10_13
    else if (level== NSDockWindowLevel) s = "NSDockWindowLevel";
#endif
    PyErr_Format(PyExc_RuntimeError, "unexpected window level %s", s);
    return NULL;
}

static int
Window_set_topmost(WindowObject* self, PyObject* value, void* closure)
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

static PyObject* Window_get_iconified(WindowObject* self, void* closure)
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

static PyObject* Window_get_alpha(WindowObject* self, void* closure)
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
Window_set_alpha(WindowObject* self, PyObject* value, void* closure)
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

static PyObject* Window_get_parent(WindowObject* self, void* closure)
{
    Window* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    Window* parent = (Window*) [window parentWindow];
    if (parent) {
        PyObject* object = (PyObject*) parent.object;
        Py_INCREF(object);
        return object;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static char Window_parent__doc__[] = "parent window (as set by add_children).";

static PyObject* Window_get_children(WindowObject* self, void* closure)
{
    PyObject* tuple;
    PyObject* object;
    Window* child;
    NSArray* children;
    NSUInteger i;
    NSUInteger len;
    NSWindow* window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    children = [window childWindows];
    len = [children count];
    tuple = PyTuple_New(len);
    for (i = 0; i < len; i++) {
        child = [children objectAtIndex: i];
        object = (PyObject*) child.object;
        Py_INCREF(object);
        PyTuple_SET_ITEM(tuple, i, object);
    }
    return tuple;
}

static char Window_children__doc__[] = "child windows (as set by add_children).";

static PyGetSetDef Window_getset[] = {
    {"content", (getter)Window_get_content, (setter)Window_set_content, Window_content__doc__, NULL},
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
    {"visible", (getter)Window_get_visible, (setter)NULL, Window_visible__doc__, NULL},
    {"iconified", (getter)Window_get_iconified, (setter)NULL, Window_iconified__doc__, NULL},
    {"topmost", (getter)Window_get_topmost, (setter)Window_set_topmost, Window_topmost__doc__, NULL},
    {"alpha", (getter)Window_get_alpha, (setter)Window_set_alpha, Window_alpha__doc__, NULL},
    {"parent", (getter)Window_get_parent, (setter)NULL, Window_parent__doc__, NULL},
    {"children", (getter)Window_get_children, (setter)NULL, Window_children__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Window_doc[] =
"A Window object wraps a Cocoa NSWindow object.\n";

Py_LOCAL_SYMBOL PyTypeObject WindowType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "gui.Window",
    .tp_basicsize = sizeof(WindowObject),
    .tp_dealloc = (destructor)Window_dealloc,
    .tp_repr = (reprfunc)Window_repr,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_doc = Window_doc,
    .tp_methods = Window_methods,
    .tp_getset = Window_getset,
    .tp_init = (initproc)Window_init,
    .tp_new = Window_new,
};
