#include "window.h"
#include "graphics.h"
// #include "widgets.h"
#include "events.h"
#include "float.h"
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <X11/Xmd.h>
#include <sys/types.h>
#include <sys/socket.h>



#define _NET_WM_STATE_REMOVE        0L   /* remove/unset property */
#define _NET_WM_STATE_ADD           1L   /* add/set property */
#define _NET_WM_STATE_TOGGLE        2L   /* toggle property  */



#ifdef FINISHED
@implementation Window
- (void)windowWillClose:(NSNotification *)notification
{
    Py_DECREF(_object);
}

- (void)windowDidResize:(NSNotification *)notification
{
    [self requestLayout];
}

- (void)requestLayout
{
    _object->layout_requested = true;
}
@end
#endif

static PyObject*
Window_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    WindowObject *self = (WindowObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->content = NULL;
    self->layout_requested = False;
    return (PyObject*)self;
}

static unsigned int nwindows = 0;
Display* display = NULL;
static Atom object_atom = None;
static Atom pointer_atom = None;
static Atom wm_delete_atom = None;

static void Window_store_object(Window window, WindowObject* object) {
    int n;
    if (object_atom==None)
        object_atom = XInternAtom(display, "object", False);
    if (pointer_atom==None)
        pointer_atom = XInternAtom(display, "POINTER", False);
    n = sizeof(WindowObject*);
    XChangeProperty(display,
                    window,
                    object_atom,
                    pointer_atom,
                    8,
                    PropModeReplace,
                    (unsigned char*)(&object),
                    n);
}

static WindowObject* Window_retrieve_object(Window window) {
    Atom type;
    int format;
    unsigned long nitems;
    unsigned long bytes;
    unsigned char* data;
    WindowObject* object;
    const unsigned long n = sizeof(WindowObject*);
    XGetWindowProperty(display,
                       window,
                       object_atom,
                       0,
                       n,
                       False,
                       pointer_atom,
                       &type,
                       &format,
                       &nitems,
                       &bytes,
                       &data);
    if (nitems != n) {
        PyErr_SetString(PyExc_RuntimeError,
                        "XGetWindowProperty failed to find window object");
        return NULL;
    }
    if (type != pointer_atom) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned incorrect type for window object");
        return NULL;
    }
    if (format != 8) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned incorrect format for window object");
        return NULL;
    }
    if (bytes != 0) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned additional bytes for window object");
        return NULL;
    }
    object = *((WindowObject**)data);
    XFree(data);
    return object;
}

static void event_callback(IdleObject* idle)
{
    XEvent event;
    Window window;
    WindowObject* object;
    while (XPending(display)) {
        XNextEvent(display, &event);
        switch (event.type) {
            case Expose: {
                PyObject* content;
                GraphicsContext* gc;
                int screen = DefaultScreen(display);
                PyGILState_STATE gstate;
                PyObject* exception_type;
                PyObject* exception_value;
                PyObject* exception_traceback;
                PyObject* result = NULL;
                window = event.xany.window;
                object = Window_retrieve_object(window);
                if (!object) continue;
                content = object->content;
                if (content == Py_None) continue;
                gstate = PyGILState_Ensure();
                PyErr_Fetch(&exception_type, &exception_value, &exception_traceback);
                gc = (GraphicsContext*) PyType_GenericAlloc(&GraphicsContextType, 0);
                if (gc) {
                    gc->display = display;
                    gc->window = window;
                    gc->gc = DefaultGC(display, screen);
                    result = PyObject_CallMethod(content, "draw", "O", gc);
                    Py_DECREF((PyObject*)gc);
                }
                if (result) Py_DECREF(result);
                else PyErr_Print();
                PyErr_Restore(exception_type, exception_value, exception_traceback);
                PyGILState_Release(gstate);
                break;
            }
            case ClientMessage:
            {
                int screen = DefaultScreen(display);
                window = event.xclient.window;
                object = Window_retrieve_object(window);
                if (!object) continue;
                if (event.xclient.data.l[0] == wm_delete_atom) {
                    XWithdrawWindow(display, window, screen);
                }
                else printf("Unknown client message\n");
                break;
            }
            case DestroyNotify:
            {
                break;
            }
            case ConfigureNotify:
            {
                break;
            }
            case PropertyNotify:
            {
                break;
            }
            default:
            {
                break;
            }
        }
    }
}

static void event_socket_callback(SocketObject* socket, int mask)
{
    event_callback(NULL);
}

int set_window_title(Window window, PyObject* title)
{
    Atom property;
    Atom encoding = XInternAtom(display, "UTF8_STRING", False);
    unsigned char *data;
    int nelements;
    const char* string;
    if (title == NULL) string = "";
    else if (PyUnicode_Check(title)) {
        string = PyUnicode_AsUTF8(title);
    }
    else {
        PyErr_SetString(PyExc_TypeError,
		        "title should be a string or None");
        return -1;
    }
    XStoreName(display, window, string);
    nelements = strlen(string);
    data = (unsigned char*)string;
    property = XInternAtom(display, "_WM_NAME", False);
    if (property != None)
        XChangeProperty(display, window, property, encoding , 8, PropModeReplace, data, nelements);
        property = XInternAtom(display, "_NET_WM_NAME", False);
    if (property != None)
        XChangeProperty(display, window, property, encoding , 8, PropModeReplace, data, nelements);
    return 0;
}

static int
Window_init(WindowObject *self, PyObject *args, PyObject *keywords)
{
    int screen;
    Window root;
    Window window;
    int x, y;
    unsigned int width = 200;
    unsigned int height = 200;;
    unsigned int border_width = 5;
    unsigned long border;
    unsigned long background;
    PyObject* title = NULL;
    static char* kwlist[] = {"width", "height", "title", NULL};

    if (nwindows==0) {
        int fd;
        display = XOpenDisplay(NULL);
        if (display == NULL) {
            PyErr_SetString(PyExc_RuntimeError, "failed to open display");
            return -1;
        }
        if (import_events() < 0) {
            PyErr_SetString(PyExc_RuntimeError, "failed to import events");
            return -1;
        }
        fd = ConnectionNumber(display);
        if (PyEvents_create_socket(event_socket_callback, fd, PyEvents_READABLE, 0) < 0) {
            PyErr_SetString(PyExc_RuntimeError, "failed to create socket");
            return -1;
        }
/*
        if (PyEvents_create_idle(event_callback) < 0) {
            PyErr_SetString(PyExc_RuntimeError, "failed to create idle function");
            return -1;
        }
*/
    }
    nwindows++;
    screen = DefaultScreen(display);
    root = DefaultRootWindow(display);
    border = BlackPixel(display, screen);
    background = WhitePixel(display, screen);
    x = 1; /* The window manager will override these values */
    y = 1; /* The window manager will override these values */
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|iiO", kwlist,
                                     &width, &height, &title))
        return -1;

    if (title == Py_None) border_width = 0;
    window = XCreateSimpleWindow(display, root, x, y, width, height, border_width, border, background);
    if (window == 0) {
        PyErr_SetString(PyExc_RuntimeError, "failed to create window");
        return -1;
    }
    XSelectInput(display, window, ExposureMask | KeyPressMask | KeyReleaseMask | PointerMotionMask | ButtonPressMask | ButtonReleaseMask  | StructureNotifyMask );
    if (title == Py_None) {
        XSetWindowAttributes attributes;
        attributes.override_redirect = True;
        XChangeWindowAttributes(display, window, CWOverrideRedirect, &attributes);
    }
    else  {
        if (set_window_title(window, title) < 0) return -1;
    }

    if (wm_delete_atom == None)
        wm_delete_atom = XInternAtom(display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(display, window, &wm_delete_atom, 1);

    Py_INCREF(Py_None);
    self->content = Py_None;
    self->window = window;
    Window_store_object(window, self);
#ifdef FINISHED
    self->layout_requested = NO;
#endif
    return 0;
}

static PyObject*
Window_repr(WindowObject* self)
{
    return PyUnicode_FromFormat("Window object %p wrapping X11 Window %lu",
                               self, self->window);
}

static void
Window_dealloc(WindowObject* self)
{
    /* If Window.__init__ fails, then Window_dealloc is called before
     * all member objects have been initialized. Some members may therefore
     * still be NULL.
     */
    XDestroyWindow(display, self->window);
    nwindows--;
    if (nwindows == 0) {
        XCloseDisplay(display); /* needs error checking */
        display = NULL;
    }
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static int _Window_get_state(Window window)
{
    Atom atom;
    Atom type;
    int format;
    unsigned long nitems, bytes;
    CARD32 state;
    struct {
        CARD32 state;
        Window icon;
    } *wm_state;
    atom = XInternAtom(display, "WM_STATE", True);
    XGetWindowProperty(display, window, atom, 0, LONG_MAX, False, atom, &type,
                       &format, &nitems, &bytes, (unsigned char**)&wm_state);
    if (type==None) {
        if (format != 0) {
            PyErr_SetString(PyExc_RuntimeError,
                "XGetWindowProperty returned type None but non-zero format");
            return -1;
        }
        if (bytes != 0) {
            PyErr_SetString(PyExc_RuntimeError,
                "XGetWindowProperty returned type None but non-zero bytes");
            return -1;
        }
        return WithdrawnState;
    }
    state = wm_state->state;
    XFree(wm_state);
    switch (state) {
        case NormalState:
        case IconicState:
        case WithdrawnState:
            break;
        default:
            PyErr_SetString(PyExc_RuntimeError,
                            "Received unexpected value for WM_STATE");
            state = -1;
            break;
    }
    return state;
}

static PyObject*
Window_show(WindowObject* self)
{
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    printf("Calling XMapWindow\n");
    XMapWindow(display, window);
    /* If we use an idle function, then XPending will be called, which flushes
     * the output buffer (i.e. transmits all requests to the X server. If
     * instead we wait for the file descriptor, then we need to call XFlush
     * here to make sure that all requests are transmitted. */
    XFlush(display);
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_close(WindowObject* self)
{
    int screen;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    screen = DefaultScreen(display);
    XWithdrawWindow(display, window, screen);
    XFlush(display);
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_get_state(WindowObject* self)
{
    int state;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    state = _Window_get_state(window);
    switch (state) {
        case NormalState: {
printf("NormalState\n");
            break;
        }
        case IconicState:
printf("IconicState\n");
            break;
        case WithdrawnState: {
printf("WithdrawnState\n");
            break;
        }
        case -1:
        default: /* fall through */
            return NULL;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_iconify(WindowObject* self)
{
    Status status;
    int state;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    state = _Window_get_state(window);
    switch (state) {
        case NormalState: {
printf("NormalState; calling XIconifyWindow\n");
            int screen = DefaultScreen(display);
            status = XIconifyWindow(display, window, screen);
            if (status == 0) {
                PyErr_SetString(PyExc_RuntimeError,
                                "failed to send iconification message");
                return NULL;
            }
            XFlush(display);
            break;
        }
        case IconicState:
printf("IconicState\n");
            break;
        case WithdrawnState: {
printf("WithdrawnState; calling XSetWMHints\n");
            XWMHints* hints = XAllocWMHints();
            hints->flags = StateHint;
            hints->initial_state = IconicState;
            XSetWMHints(display, window, hints);
            XFree(hints);
            break;
        }
        case -1:
        default: /* fall through */
            return NULL;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_deiconify(WindowObject* self)
{
    int state;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    state = IconicState; // _Window_get_state(window);
    switch (state) {
        case IconicState:
            printf("Current state = IconicState\n");
            XWMHints* hints = XGetWMHints(display, window);
            if (!hints) hints = XAllocWMHints();
            hints->flags |= StateHint;
            hints->initial_state = NormalState;
            XSetWMHints(display, window, hints);
            XFree(hints);
            // XFlush(display);
            /* fall through */
            break;
        case NormalState:
            printf("Current state = NormalState\n");
            /* fall through */
        case WithdrawnState: {
            printf("Current state = WithdrawnState\n");
            XWMHints* hints = XAllocWMHints();
            hints->flags = StateHint;
            hints->initial_state = NormalState;
            XSetWMHints(display, window, hints);
            XFree(hints);
            break;
        }
        default:
        case -1:
            return NULL;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_request_layout(WindowObject* self)
{
#ifdef FINISHED
    self->layout_requested = YES;
#endif
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Window_invalidate(WindowObject* self, PyObject *args, PyObject *keywords)
{
    XEvent event;
    PyObject* region = NULL;
    static char* kwlist[] = {"region", NULL};
    Window window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|O", kwlist, &region))
        return NULL;
    memset(&event, 0, sizeof(event));
    event.xexpose.type = Expose;
    event.xexpose.window = window;
    XSendEvent(display, window, False, ExposureMask, &event);
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
    {"state",
     (PyCFunction)Window_get_state,
     METH_NOARGS,
     "doit."
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
    {"request_layout",
     (PyCFunction)Window_request_layout,
     METH_NOARGS,
     "Requests that the layout managers recalculates its layout."
    },
    {"invalidate",
     (PyCFunction)Window_invalidate,
     METH_KEYWORDS | METH_VARARGS,
     "Marks a region for redraw."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Window_get_content(WindowObject* self, void* closure)
{
    PyObject* object = self->content;
    Py_INCREF(object);
    return object;
}

static int
Window_set_content(WindowObject* self, PyObject* value, void* closure)
{
#ifdef FINISHED
    PyTypeObject* type;
    WidgetObject* widget;
#endif
    Window window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
#ifdef FINISHED
    type = Py_TYPE(value);
    if (!PyType_IsSubtype(type, &WidgetType)) {
        PyErr_SetString(PyExc_ValueError, "expected a widget or None");
        return -1;
    }
    [window requestLayout];
#endif
    Py_DECREF(self->content);
    Py_INCREF(value);
    self->content = value;
    return 0;
}

static char Window_content__doc__[] = "window content";

static PyObject* Window_get_title(WindowObject* self, void* closure)
{
    char* title;
    PyObject* result = NULL;
    Window window = self->window;
    XWindowAttributes xwa;
    XGetWindowAttributes(display, window, &xwa);
    if (xwa.override_redirect == True) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    XFetchName(display, window, &title);
    if (title) {
        result = PyUnicode_FromString(title);
        XFree(title);
    }
    return result;
}

static int
Window_set_title(WindowObject* self, PyObject* value, void* closure)
{
    Window window = self->window;
    XWindowAttributes xwa;
    XSetWindowAttributes attributes;
    XGetWindowAttributes(display, window, &xwa);
    if (value == Py_None && xwa.override_redirect == True)
        return 0;
    else if (value != Py_None && xwa.override_redirect == False) {
        if (set_window_title(window, value) < 0) return -1;
    }
    else {
        int x, y;
        unsigned int width, height;
        Window root;
        unsigned int border_width, depth;
        int screen = DefaultScreen(display);
        unsigned long border = BlackPixel(display, screen);
        unsigned long background = WhitePixel(display, screen);
        XGetGeometry(display, window, &root, &x, &y, &width, &height, &border_width, &depth);
        XUnmapWindow(display, window);
        XDestroyWindow(display, window);
        if (value == Py_None) {
            border_width = 0;
            attributes.override_redirect = True;
        }
        else {
            border_width = 5;
            attributes.override_redirect = False;
        }
        window = XCreateSimpleWindow(display, root, x, y, width, height, border_width, border, background);
        self->window = window;
        Window_store_object(window, self);
        XChangeWindowAttributes(display, window, CWOverrideRedirect, &attributes);
        if (value != Py_None) {
            if (set_window_title(window, value) < 0) return -1;
        }
        if (xwa.map_state != IsUnmapped) XMapWindow(display, window);
    }
    /* If we use an idle function, then XPending will be called, which flushes
     * the output buffer (i.e. transmits all requests to the X server. If
     * instead we wait for the file descriptor, then we need to call XFlush
     * here to make sure that all requests are transmitted. */
    XFlush(display);
    return 0;
}

static char Window_title__doc__[] = "window title";

static PyObject* Window_get_origin(WindowObject* self, void* closure)
{
    int x;
    int y;
    Window window = self->window;
    Window parent;
    Window root;
    Window* children;
    unsigned int nchildren;
    XQueryTree(display, window, &root, &parent, &children, &nchildren);
    if (children) XFree(children);
    if (root == parent) {
        XWindowAttributes xwa;
        XGetWindowAttributes(display, window, &xwa);
        x = xwa.x;
        y = xwa.y;
    }
    else
        XTranslateCoordinates(display, parent, root, 0, 0, &x, &y, &window);
    return Py_BuildValue("ii", x, y);
}

static int Window_set_origin(WindowObject* self, PyObject* value, void* closure)
{
    int x;
    int y;
    Window window = self->window;
    if (!PyArg_ParseTuple(value, "ii", &x, &y)) return -1;
    XMoveWindow(display, window, x, y);
    return 0;
}

static char Window_origin__doc__[] = "position of the top-left corner of the window";

static PyObject* Window_get_width(WindowObject* self, void* closure)
{
    Window root;
    int x, y;
    unsigned int width, height;
    unsigned int border_width;
    unsigned int depth;
    Window window = self->window;
    XGetGeometry(display, window,
                 &root, &x, &y, &width, &height, &border_width, &depth);
    return PyLong_FromLong((long)width);
}

static int
Window_set_width(WindowObject* self, PyObject* argument, void* closure)
{
    Window root;
    int x, y;
    unsigned int width, height;
    unsigned int border_width;
    unsigned int depth;
    long value;
    Window window = self->window;
    XGetGeometry(display, window,
                 &root, &x, &y, &width, &height, &border_width, &depth);
    value = PyLong_AsLong(argument);
    if (value==-1 && PyErr_Occurred()) return -1;
    if (value < 0) {
        PyErr_SetString(PyExc_RuntimeError, "height should be non-negative");
        return -1;
    }
    width = value;
    XResizeWindow(display, window, width, height);
    XFlush(display);
    return 0;
}

static char Window_width__doc__[] = "width of window content";

static PyObject* Window_get_height(WindowObject* self, void* closure)
{
    Window root;
    int x, y;
    unsigned int width, height;
    unsigned int border_width;
    unsigned int depth;
    Window window = self->window;
    XGetGeometry(display, window,
                 &root, &x, &y, &width, &height, &border_width, &depth);
    return PyLong_FromLong((long)height);
}

static int
Window_set_height(WindowObject* self, PyObject* argument, void* closure)
{
    Window root;
    int x, y;
    unsigned int width, height;
    unsigned int border_width;
    unsigned int depth;
    long value;
    Window window = self->window;
    XGetGeometry(display, window,
                 &root, &x, &y, &width, &height, &border_width, &depth);
    value = PyLong_AsLong(argument);
    if (value==-1 && PyErr_Occurred()) return -1;
    if (value < 0) {
        PyErr_SetString(PyExc_RuntimeError, "height should be non-negative");
        return -1;
    }
    height = value;
    XResizeWindow(display, window, width, height);
    XFlush(display);
    return 0;
}

static char Window_height__doc__[] = "height of window content";

static PyObject* Window_get_size(WindowObject* self, void* closure)
{
    Window root;
    int x, y;
    unsigned int width, height;
    unsigned int border_width;
    unsigned int depth;
    Window window = self->window;
    XGetGeometry(display, window,
                 &root, &x, &y, &width, &height, &border_width, &depth);
    return Py_BuildValue("II", width, height);
}

static int Window_set_size(WindowObject* self, PyObject* value, void* closure)
{
    unsigned int width;
    unsigned int height;
    Window window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    if (!PyArg_ParseTuple(value, "II", &width, &height)) return -1;
    XResizeWindow(display, window, width, height);
    XFlush(display);
    return 0;
}

static char Window_size__doc__[] = "window content size";

static PyObject* Window_get_frame(WindowObject* self, void* closure)
{
    Window root;
    int x, y;
    unsigned int width, height;
    unsigned int border_width;
    unsigned int depth;
    Window window = self->window;
    Window parent;
    Window* children;
    unsigned int nchildren;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    XQueryTree(display, window, &root, &parent, &children, &nchildren);
    if (children) XFree(children);
    if (parent != root) window = parent;
    XGetGeometry(display, window,
                 &root, &x, &y, &width, &height, &border_width, &depth);
    return Py_BuildValue("iiII", x, y, width, height);
}

static int Window_set_frame(WindowObject* self, PyObject* value, void* closure)
{
    int x;
    int y;
    unsigned int width, height;
    Window root;
    Window parent;
    Window* children;
    unsigned int nchildren;
    Window window = self->window;
    if (!window) {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    XQueryTree(display, window, &root, &parent, &children, &nchildren);
    if (children) XFree(children);
    if (parent != root) window = parent;
    if (!PyArg_ParseTuple(value, "iiII", &x, &y, &width, &height)) return -1;
    XMoveWindow(display, window, x, y);
    XResizeWindow(display, window, width, height);
    XFlush(display);
    return 0;
}

static char Window_frame__doc__[] = "position and size of the window; position is the position of the top-left corner of the window; the size is the window size, which may be larger than the content size";

static PyObject* Window_get_resizable(WindowObject* self, void* closure)
{
    Window window = self->window;
    long length = 1024;
    int format;
    unsigned long i;
    unsigned long nitems;
    unsigned long bytes;
    Atom* atoms;
    Atom type;
    Atom resizable;
    Atom allowed;
    PyObject* result = Py_False;
    resizable = XInternAtom(display, "_NET_WM_ACTION_RESIZE", True);
    if (resizable == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_ACTION_RESIZE");
        return NULL;
    }
    allowed = XInternAtom(display, "_NET_WM_ALLOWED_ACTIONS", True);
    if (allowed == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_ALLOWED_ACTIONS");
        return NULL;
    }
    if (XGetWindowProperty(display, window, allowed, 0, length, False, XA_ATOM,
                           &type, &format, &nitems, &bytes,
                           (unsigned char **)(&atoms)) != Success) {
        PyErr_SetString(PyExc_RuntimeError, "XGetWindowProperty failed");
        return NULL;
    }
    if (type == None) /* window is unmapped */ Py_RETURN_FALSE;
    if (type != XA_ATOM) {
        PyErr_SetString(PyExc_RuntimeError,
                        "XGetWindowProperty returned incorrect type"
                        " for _NET_WM_ALLOWED_ACTIONS");
        return NULL;
    }
    if (format != 32) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned incorrect format"
            " for _NET_WM_ALLOWED_ACTIONS");
        return NULL;
    }
    if (bytes != 0) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned additional bytes"
            " for _NET_WM_ALLOWED_ACTIONS");
        return NULL;
    }
    for (i = 0; i < nitems; i++) {
        if (atoms[i]==resizable) {
            result = Py_True;
            break;
        }
    }
    XFree((unsigned char*)atoms);
    Py_INCREF(result);
    return result;
}

static int
Window_set_resizable(WindowObject* self, PyObject* value, void* closure)
{
    Status status;
    XSizeHints* hints;
    long supplied;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    hints = XAllocSizeHints();
    status = XGetWMNormalHints(display, window, hints, &supplied);
    if (status) {
        hints->flags = supplied;
    } else {
        hints->flags = PMinSize | PMaxSize;
    }
    if (PyObject_IsTrue(value)) {
        hints->min_width = 0;
        hints->max_width = INT_MAX;
        hints->min_height = 0;
        hints->max_height = INT_MAX;
    } else {
        Window root;
        int x, y;
        unsigned int width, height;
        unsigned int border_width;
        unsigned int depth;
        Window window = self->window;
        XGetGeometry(display, window,
                     &root, &x, &y, &width, &height, &border_width, &depth);
        hints->min_width = width;
        hints->max_width = width;
        hints->min_height = height;
        hints->max_height = height;
    }
    XSetWMNormalHints(display, window, hints);
    XFree(hints);
    XFlush(display);
    return 0;
}

static char Window_resizable__doc__[] = "specifies whether the window can be resized by the user";

static PyObject* Window_get_min_width(WindowObject* self, void* closure)
{
    Status status;
    int width = 0;
    XSizeHints* hints;
    long supplied;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    hints = XAllocSizeHints();
    status = XGetWMNormalHints(display, window, hints, &supplied);
    if (status && (supplied & PMinSize)) width = hints->min_width;
    XFree(hints);
    if (width == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyLong_FromLong((long)width);
}

static int
Window_set_min_width(WindowObject* self, PyObject* value, void* closure)
{
    Status status;
    long width;
    XSizeHints* hints;
    long supplied;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    hints = XAllocSizeHints();
    if (value == Py_None) {
        width = 0;
    } else {
        width = PyLong_AsLong(value);
        if (width==-1 && PyErr_Occurred()) return -1;
        if (width <= 0) {
            PyErr_SetString(PyExc_RuntimeError, "width should be positive");
            return -1;
        }
    }
    status = XGetWMNormalHints(display, window, hints, &supplied);
    if (status) hints->flags = supplied;
    else {
        hints->flags = PMinSize;
        hints->min_height = 0;
    }
    hints->min_width = width;
    XSetWMNormalHints(display, window, hints);
    XFree(hints);
    return 0;
}

static char Window_min_width__doc__[] = "the minimum width to which the window can be resized by the user";

static PyObject* Window_get_max_width(WindowObject* self, void* closure)
{
    Status status;
    int width = INT_MAX;
    XSizeHints* hints;
    long supplied;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    hints = XAllocSizeHints();
    status = XGetWMNormalHints(display, window, hints, &supplied);
    if (status && (supplied & PMaxSize)) width = hints->max_width;
    XFree(hints);
    if (width == 0 || width == INT_MAX) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyLong_FromLong((long)width);
}

static int
Window_set_max_width(WindowObject* self, PyObject* value, void* closure)
{
    Status status;
    int width;
    XSizeHints* hints;
    long supplied;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    hints = XAllocSizeHints();
    if (value == Py_None) {
        width = INT_MAX;
    } else {
        long l;
        l = PyLong_AsLong(value);
        if (l==-1 && PyErr_Occurred()) return -1;
        if (l <= 0) {
            PyErr_SetString(PyExc_RuntimeError, "width should be positive");
            return -1;
        }
        width = (int)l;
        if (width != l) {
            PyErr_SetString(PyExc_RuntimeError, "value out of bounds");
            return -1;
        }
    }
    status = XGetWMNormalHints(display, window, hints, &supplied);
    if (status) {
        hints->flags = supplied;
    }
    else {
        hints->flags = PMaxSize;
        hints->max_height = INT_MAX;
    }
    hints->max_width = width;
    XSetWMNormalHints(display, window, hints);
    XFree(hints);
    return 0;
}

static char Window_max_width__doc__[] = "the maximum width to which the window can be resized by the user";

static PyObject* Window_get_min_height(WindowObject* self, void* closure)
{
    Status status;
    int height = 0;
    XSizeHints* hints;
    long supplied;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    hints = XAllocSizeHints();
    status = XGetWMNormalHints(display, window, hints, &supplied);
    if (status && (supplied & PMinSize)) height = hints->min_height;
    XFree(hints);
    if (height == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyLong_FromLong((long)height);
}

static int
Window_set_min_height(WindowObject* self, PyObject* value, void* closure)
{
    Status status;
    long height;
    XSizeHints* hints;
    long supplied;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    hints = XAllocSizeHints();
    if (value == Py_None) {
        height = 0;
    } else {
        height = PyLong_AsLong(value);
        if (height==-1 && PyErr_Occurred()) return -1;
        if (height <= 0) {
            PyErr_SetString(PyExc_RuntimeError, "height should be positive");
            return -1;
        }
    }
    status = XGetWMNormalHints(display, window, hints, &supplied);
    if (status) hints->flags = supplied;
    else {
        hints->flags = PMinSize;
        hints->min_width = 0;
    }
    hints->min_height = height;
    XSetWMNormalHints(display, window, hints);
    XFree(hints);
    return 0;
}

static char Window_min_height__doc__[] = "the minimum height to which the window can be resized by the user";

static PyObject* Window_get_max_height(WindowObject* self, void* closure)
{
    Status status;
    int height = INT_MAX;
    XSizeHints* hints;
    long supplied;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    hints = XAllocSizeHints();
    status = XGetWMNormalHints(display, window, hints, &supplied);
    if (status && (supplied * PMaxSize)) height = hints->max_height;
    XFree(hints);
    if (height == 0 || height == INT_MAX) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyLong_FromLong((long)height);
}

static int
Window_set_max_height(WindowObject* self, PyObject* value, void* closure)
{
    Status status;
    long height;
    XSizeHints* hints;
    long supplied;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    hints = XAllocSizeHints();
    if (value == Py_None) {
        height = INT_MAX;
    } else {
        height = PyLong_AsLong(value);
        if (height==-1 && PyErr_Occurred()) return -1;
        if (height <= 0) {
            PyErr_SetString(PyExc_RuntimeError, "height should be positive");
            return -1;
        }
    }
    status = XGetWMNormalHints(display, window, hints, &supplied);
    if (status) {
        hints->flags = supplied;
    }
    else {
        hints->flags = PMaxSize;
        hints->max_width = INT_MAX;
    }
    hints->max_height = height;
    XSetWMNormalHints(display, window, hints);
    XFree(hints);
    return 0;
}

static char Window_max_height__doc__[] = "the maximum height to which the window can be resized by the user";

static PyObject* Window_get_fullscreen(WindowObject* self, void* closure)
{
    Window window = self->window;
    long length = 1024;
    int format;
    unsigned long i;
    unsigned long nitems;
    unsigned long bytes;
    Atom* atoms;
    Atom type;
    Atom fullscreen;
    Atom state;
    PyObject* result = Py_False;
    fullscreen = XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", True);
    if (fullscreen == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_STATE_FULLSCREEN");
        return NULL;
    }
    state = XInternAtom(display, "_NET_WM_STATE", True);
    if (state == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_STATE");
        return NULL;
    }
    if (XGetWindowProperty(display, window, state, 0, length, False, XA_ATOM,
                           &type, &format, &nitems, &bytes,
                           (unsigned char **)(&atoms)) != Success) {
        PyErr_SetString(PyExc_RuntimeError, "XGetWindowProperty failed");
        return NULL;
    }
    if (type == None) /* window is unmapped */ Py_RETURN_FALSE;
    if (type != XA_ATOM) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned incorrect type for _NET_WM_STATE");
        return NULL;
    }
    if (format != 32) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned incorrect format for _NET_WM_STATE");
        return NULL;
    }
    if (bytes != 0) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned additional bytes for _NET_WM_STATE");
        return NULL;
    }
    for (i = 0; i < nitems; i++) {
        if (atoms[i]==fullscreen) {
            result = Py_True;
            break;
        }
    }
    XFree((unsigned char*)atoms);
    Py_INCREF(result);
    return result;
}

static int
Window_set_fullscreen(WindowObject* self, PyObject* value, void* closure)
{
    long action;
    Atom fullscreen;
    Atom state;
    XClientMessageEvent event;
    Window root = DefaultRootWindow(display);
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    fullscreen = XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", True);
    if (fullscreen == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_STATE_FULLSCREEN");
        return -1;
    }
    state = XInternAtom(display, "_NET_WM_STATE", True);
    if (state == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_STATE");
        return -1;
    }
    if (PyObject_IsTrue(value)) action = _NET_WM_STATE_ADD;
    else action = _NET_WM_STATE_REMOVE;
    memset(&event, 0, sizeof(event));
    event.type = ClientMessage;
    event.window = window;
    event.message_type = state;
    event.format = 32;
    event.data.l[0] = action;
    event.data.l[1] = fullscreen;
    event.data.l[2] = 0;
    event.data.l[3] = 0;
    event.data.l[4] = 0;
    XSendEvent(display, root, False,
               SubstructureRedirectMask | SubstructureNotifyMask,
               (XEvent *)&event);
    XFlush(display);
    return 0;
}

static char Window_fullscreen__doc__[] = "specify if the window is in full-screen mode";

static PyObject* Window_get_zoomed(WindowObject* self, void* closure)
{
    Window window = self->window;
    long length = 1024;
    int format;
    unsigned long i;
    unsigned long nitems;
    unsigned long bytes;
    Atom* atoms;
    Atom type;
    Atom maximized_horz;
    Atom maximized_vert;
    Atom state;
    Atom atom;
    Bool maximized_horz_found = False;
    Bool maximized_vert_found = False;
    maximized_horz = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_HORZ", True);
    if (maximized_horz == None) {
        PyErr_SetString(PyExc_RuntimeError,
            "Failed to obtain atom for _NET_WM_STATE_MAXIMIZED_HORZ");
        return NULL;
    }
    maximized_vert = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_VERT", True);
    if (maximized_vert == None) {
        PyErr_SetString(PyExc_RuntimeError,
            "Failed to obtain atom for _NET_WM_STATE_MAXIMIZED_VERT");
        return NULL;
    }
    state = XInternAtom(display, "_NET_WM_STATE", True);
    if (state == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_STATE");
        return NULL;
    }
    if (XGetWindowProperty(display, window, state, 0, length, False, XA_ATOM,
                           &type, &format, &nitems, &bytes,
                           (unsigned char **)(&atoms)) != Success) {
        PyErr_SetString(PyExc_RuntimeError, "XGetWindowProperty failed");
        return NULL;
    }
    if (type == None) /* window is unmapped */ Py_RETURN_FALSE;
    if (type != XA_ATOM) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned incorrect type for _NET_WM_STATE");
        return NULL;
    }
    if (format != 32) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned incorrect format for _NET_WM_STATE");
        return NULL;
    }
    if (bytes != 0) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned additional bytes for _NET_WM_STATE");
        return NULL;
    }
    for (i = 0; i < nitems; i++) {
        atom = atoms[i];
        if (atom==maximized_horz) maximized_horz_found = True;
        if (atom==maximized_vert) maximized_vert_found = True;
    }
    XFree((unsigned char*)atoms);
    if (maximized_horz_found && maximized_vert_found) Py_RETURN_TRUE;
    Py_RETURN_FALSE;
}

static int
Window_set_zoomed(WindowObject* self, PyObject* value, void* closure)
{
    long action;
    Atom maximized_horz;
    Atom maximized_vert;
    Atom state;
    XClientMessageEvent event;
    Window root = DefaultRootWindow(display);
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    maximized_horz = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_HORZ", True);
    if (maximized_horz == None) {
        PyErr_SetString(PyExc_RuntimeError,
            "Failed to obtain atom for _NET_WM_STATE_MAXIMZED_HORZ");
        return -1;
    }
    maximized_vert = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_VERT", True);
    if (maximized_vert == None) {
        PyErr_SetString(PyExc_RuntimeError,
            "Failed to obtain atom for _NET_WM_STATE_MAXIMZED_VERT");
        return -1;
    }
    state = XInternAtom(display, "_NET_WM_STATE", True);
    if (state == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_STATE");
        return -1;
    }
    if (PyObject_IsTrue(value)) action = _NET_WM_STATE_ADD;
    else action = _NET_WM_STATE_REMOVE;
    memset(&event, 0, sizeof(event));
    event.type = ClientMessage;
    event.window = window;
    event.message_type = state;
    event.format = 32;
    event.data.l[0] = action;
    event.data.l[1] = maximized_horz;
    event.data.l[2] = maximized_vert;
    event.data.l[3] = 0;
    event.data.l[4] = 0;
    XSendEvent(display, root, False,
               SubstructureRedirectMask | SubstructureNotifyMask,
               (XEvent *)&event);
    XFlush(display);
    return 0;
}

static char Window_zoomed__doc__[] = "specify if the window is in full-screen mode";

static PyObject* Window_get_visible(WindowObject* self, void* closure)
{
    int state;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    state = _Window_get_state(window);
    switch (state) {
        case NormalState:
        case IconicState:
            Py_RETURN_TRUE;
        case WithdrawnState:
            Py_RETURN_FALSE;
        case -1:
        default:
            return NULL;
    }
}

static char Window_visible__doc__[] = "True if the window is being shown onscreen";

static PyObject* Window_get_topmost(WindowObject* self, void* closure)
{
    Window window = self->window;
    long length = 1024;
    int format;
    unsigned long i;
    unsigned long nitems;
    unsigned long bytes;
    Atom* atoms;
    Atom type;
    Atom above;
    Atom state;
    PyObject* result = Py_False;
    above = XInternAtom(display, "_NET_WM_STATE_ABOVE", True);
    if (above == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_STATE_ABOVE");
        return NULL;
    }
    state = XInternAtom(display, "_NET_WM_STATE", True);
    if (state == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_STATE");
        return NULL;
    }
    if (XGetWindowProperty(display, window, state, 0, length, False, XA_ATOM,
                           &type, &format, &nitems, &bytes,
                           (unsigned char **)(&atoms)) != Success) {
        PyErr_SetString(PyExc_RuntimeError, "XGetWindowProperty failed");
        return NULL;
    }
    if (type == None) /* window is unmapped */ Py_RETURN_FALSE;
    if (type != XA_ATOM) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned incorrect type for _NET_WM_STATE");
        return NULL;
    }
    if (format != 32) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned incorrect format for _NET_WM_STATE");
        return NULL;
    }
    if (bytes != 0) {
        PyErr_SetString(PyExc_RuntimeError,
            "XGetWindowProperty returned additional bytes for _NET_WM_STATE");
        return NULL;
    }
    for (i = 0; i < nitems; i++) {
        if (atoms[i]==above) {
            result = Py_True;
            break;
        }
    }
    XFree((unsigned char*)atoms);
    Py_INCREF(result);
    return result;
}

static int
Window_set_topmost(WindowObject* self, PyObject* value, void* closure)
{
    long action;
    Atom above;
    Atom state;
    XClientMessageEvent event;
    Window root = DefaultRootWindow(display);
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    above = XInternAtom(display, "_NET_WM_STATE_ABOVE", True);
    if (above == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_STATE_ABOVE");
        return -1;
    }
    state = XInternAtom(display, "_NET_WM_STATE", True);
    if (state == None) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Failed to obtain atom for _NET_WM_STATE");
        return -1;
    }
    if (PyObject_IsTrue(value)) action = _NET_WM_STATE_ADD;
    else action = _NET_WM_STATE_REMOVE;
    memset(&event, 0, sizeof(event));
    event.type = ClientMessage;
    event.window = window;
    event.message_type = state;
    event.format = 32;
    event.data.l[0] = action;
    event.data.l[1] = above;
    event.data.l[2] = 0;
    event.data.l[3] = 0;
    event.data.l[4] = 0;
    XSendEvent(display, root, False,
               SubstructureRedirectMask | SubstructureNotifyMask,
               (XEvent *)&event);
    XFlush(display);
    return 0;
}

static char Window_topmost__doc__[] = "True if the window is topmost; False otherwise";

static PyObject* Window_get_iconified(WindowObject* self, void* closure)
{
    int state;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    state = _Window_get_state(window);
    switch (state) {
        case IconicState:
            Py_RETURN_TRUE;
        case NormalState:
            Py_RETURN_FALSE;
        case WithdrawnState: {
            XWMHints* hints = XGetWMHints(display, window);
            if (hints) {
                int initial_state = hints->initial_state;
                XFree(hints);
                if (initial_state == IconicState) Py_RETURN_TRUE;
            }
            Py_RETURN_FALSE;
        }
        case -1:
        default:
            return NULL;
    }
}

static char Window_iconified__doc__[] = "True if the window is iconified; False otherwise";

static PyObject* Window_get_alpha(WindowObject* self, void* closure)
{
    double alpha;
    Atom atom;
    Atom type;
    int format;
    unsigned long nitems;
    unsigned long bytes;
    uint32_t opacity;
    unsigned char* data;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return NULL;
    }
    atom = XInternAtom(display, "_NET_WM_WINDOW_OPACITY", False);
    XGetWindowProperty(display, window, atom, 0, 1, False, XA_CARDINAL,
                       &type, &format, &nitems, &bytes, &data);
    if (nitems==0) alpha = 1.0;
    else {
        opacity = *((uint32_t*)data);
        XFree(data);
        if (type != XA_CARDINAL) {
            PyErr_SetString(PyExc_RuntimeError,
                            "XGetWindowProperty returned incorrect type");
            return NULL;
        }
        if (format != 32) {
            PyErr_SetString(PyExc_RuntimeError,
                            "XGetWindowProperty returned incorrect format");
            return NULL;
        }
        if (bytes != 0) {
            PyErr_SetString(PyExc_RuntimeError,
                            "XGetWindowProperty returned additional bytes");
            return NULL;
        }
        alpha = ((double)opacity)/UINT32_MAX;
    }
    return PyFloat_FromDouble(alpha);
}

static int
Window_set_alpha(WindowObject* self, PyObject* value, void* closure)
{
    double alpha;
    Atom atom;
    uint32_t opacity;
    Window window = self->window;
    if (!window)
    {
        PyErr_SetString(PyExc_RuntimeError, "window has not been initialized");
        return -1;
    }
    atom = XInternAtom(display, "_NET_WM_WINDOW_OPACITY", False);
    alpha = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    if (alpha < 0.0) alpha = 0.0;
    else if (alpha > 1.0) alpha = 1.0;
    opacity = (uint32_t) (alpha * UINT32_MAX);
    if (opacity == UINT32_MAX) {
        XDeleteProperty(display, window, atom);
    } else {
        XChangeProperty(display, window, atom, XA_CARDINAL, 32, PropModeReplace,
                      (unsigned char*) &opacity, 1) ;
    }
    XFlush(display);
    return 0;
}

static char Window_alpha__doc__[] = "alpha transparency level of the window, ranging from 0.0 (fully transparent) to 1.0 (opaque); values outside this range will be clipped. If not supported, the alpha value remains at 1.0.";

static PyObject* Window_get_layout_requested(WindowObject* self, void* closure)
{
#ifdef FINISHED
    if (self->layout_requested) Py_RETURN_TRUE;
#endif
    Py_RETURN_FALSE;
}

static char Window_layout_requested__doc__[] = "True if a recalculation of the layout has been requested";

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
    {"layout_requested", (getter)Window_get_layout_requested, (setter)NULL, Window_layout_requested__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Window_doc[] =
"A Window object wraps a Cocoa NSWindow object.\n";

PyTypeObject WindowType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "gui.Window",               /* tp_name */
    sizeof(WindowObject),       /* tp_basicsize */
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
