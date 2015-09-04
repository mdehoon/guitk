#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <Python.h>
#include <Cocoa/Cocoa.h>
#define EVENTS_MODULE
#include "events.h"
#include "window.h"
#include "label.h"
#include "../Generic/packed.h"

#define PYOSINPUTHOOK_REPETITIVE 1 /* Remove this once Python is fixed */

#if PY_MAJOR_VERSION >= 3
#define PY3K 1
#else
#if PY_MINOR_VERSION < 7
#error Python version should be 2.7 or newer
#else
#define PY3K 0
#endif
#endif

@interface WindowServerConnectionManager : NSObject
{
}
+ (WindowServerConnectionManager*)sharedManager;
- (void)launch:(NSNotification*)notification;
@end

typedef struct {
    PyObject_HEAD
    CFRunLoopTimerRef timer;
    PyObject* callback;
} TimerObject;

static PyTypeObject TimerType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "events.Timer",            /*tp_name*/
    sizeof(TimerObject),       /*tp_basicsize*/
    0,                         /*tp_itemsize*/
    0,                         /*tp_dealloc*/
    0,                         /*tp_print*/
    0,                         /*tp_getattr*/
    0,                         /*tp_setattr*/
    0,                         /*tp_compare*/
    0,                         /*tp_repr*/
    0,                         /*tp_as_number*/
    0,                         /*tp_as_sequence*/
    0,                         /*tp_as_mapping*/
    0,                         /*tp_hash */
    0,                         /*tp_call*/
    0,                         /*tp_str*/
    0,                         /*tp_getattro*/
    0,                         /*tp_setattro*/
    0,                         /*tp_as_buffer*/
    Py_TPFLAGS_DEFAULT,        /*tp_flags*/
    "Timer object",            /*tp_doc */
};

static void timer_callback(CFRunLoopTimerRef timer, void* info)
{
    PyGILState_STATE gstate;
    PyObject* exception_type;
    PyObject* exception_value;
    PyObject* exception_traceback;
    PyObject* callback;
    PyObject* arguments;
    PyObject* result = NULL;
    TimerObject* object = (TimerObject*)info;
    if (object->timer != timer) {
        /* this is not supposed to happen */
        return;
    }
    object->timer = NULL;
    callback = object->callback;
    gstate = PyGILState_Ensure();
    PyErr_Fetch(&exception_type, &exception_value, &exception_traceback);
    arguments = Py_BuildValue("(O)", object);
    if (arguments) {
        result = PyEval_CallObject(callback, arguments);
        Py_DECREF(arguments);
    }
    if (result) Py_DECREF(result);
    else PyErr_Print();
    PyErr_Restore(exception_type, exception_value, exception_traceback);
    PyGILState_Release(gstate);
    Py_DECREF(callback);
    Py_DECREF((PyObject*)object);
}

static PyObject*
PyEvents_AddTimer(PyObject* unused, PyObject* args)
{
    TimerObject* object;
    CFRunLoopTimerRef timer;
    CFTimeInterval interval;
    CFAbsoluteTime fireDate;
    CFRunLoopTimerContext context;
    CFRunLoopRef runloop;
    unsigned long timeout;
    PyObject* callback;
    if (!PyArg_ParseTuple(args, "kO", &timeout, &callback)) return NULL;
    if (!PyCallable_Check(callback)) {
        PyErr_SetString(PyExc_TypeError, "Callback should be callable");
        return NULL;
    }
    runloop = CFRunLoopGetCurrent();
    if (!runloop) {
        PyErr_SetString(PyExc_RuntimeError, "Failed to obtain run loop");
        return NULL;
    }
    object = (TimerObject*)PyType_GenericNew(&TimerType, NULL, NULL);
    Py_INCREF((PyObject*)object);
    Py_INCREF(callback);
    interval = timeout / 1000.0;
    fireDate = CFAbsoluteTimeGetCurrent() + interval;
    context.version = 0;
    context.retain = 0;
    context.release = 0;
    context.copyDescription = 0;
    context.info = object;
    timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
                                 fireDate,
                                 0,
                                 0,
                                 0,
                                 timer_callback,
                                 &context);
    CFRunLoopAddTimer(runloop, timer, kCFRunLoopDefaultMode);
    object->timer = timer;
    object->callback = callback;
    return (PyObject*)object;
}

static PyObject*
PyEvents_RemoveTimer(PyObject* unused, PyObject* argument)
{
    TimerObject* object;
    PyObject* callback;
    CFRunLoopRef runloop;
    CFRunLoopTimerRef timer;
    if (!PyObject_TypeCheck(argument, &TimerType)) {
        PyErr_SetString(PyExc_TypeError, "argument is not a timer");
        return NULL;
    }
    object = (TimerObject*)argument;
    timer = object->timer;
    callback = object->callback;
    runloop = CFRunLoopGetCurrent();
    if (timer) {
        CFRunLoopRemoveTimer(runloop, timer, kCFRunLoopDefaultMode);
        object->timer = NULL;
    }
    Py_DECREF(callback);
    Py_DECREF(argument);
    Py_INCREF(Py_None);
    return Py_None;
}

typedef struct {
    PyObject_HEAD
    CFRunLoopSourceRef source;
    int mask;
    PyObject* callback;
} SocketObject;

static void
socket_callback(CFSocketRef socket,
                CFSocketCallBackType callbackType,
                CFDataRef address,
                const void* data,
                void* info)
{
    PyGILState_STATE gstate;
    PyObject* exception_type;
    PyObject* exception_value;
    PyObject* exception_traceback;
    PyObject* arguments;
    PyObject* result = NULL;
    SocketObject* object = info;
    int fd = CFSocketGetNative(socket);
    int mask = object->mask;
    gstate = PyGILState_Ensure();
    PyErr_Fetch(&exception_type, &exception_value, &exception_traceback);
    arguments = Py_BuildValue("(ii)", fd, mask);
    if (arguments) {
        PyObject* callback = object->callback;
        result = PyEval_CallObject(callback, arguments);
        Py_DECREF(arguments);
    }
    if (result) Py_DECREF(result);
    else PyErr_Print();
    PyErr_Restore(exception_type, exception_value, exception_traceback);
    PyGILState_Release(gstate);
}

static PyTypeObject SocketType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "events.Socket",           /*tp_name*/
    sizeof(SocketObject),      /*tp_basicsize*/
    0,                         /*tp_itemsize*/
    0,                         /*tp_dealloc*/
    0,                         /*tp_print*/
    0,                         /*tp_getattr*/
    0,                         /*tp_setattr*/
    0,                         /*tp_compare*/
    0,                         /*tp_repr*/
    0,                         /*tp_as_number*/
    0,                         /*tp_as_sequence*/
    0,                         /*tp_as_mapping*/
    0,                         /*tp_hash */
    0,                         /*tp_call*/
    0,                         /*tp_str*/
    0,                         /*tp_getattro*/
    0,                         /*tp_setattro*/
    0,                         /*tp_as_buffer*/
    Py_TPFLAGS_DEFAULT,        /*tp_flags*/
    "Socket object",           /*tp_doc */
};

static PyObject*
PyEvents_CreateSocket(PyObject* unused, PyObject* args)
{
    SocketObject* object;
    int fd;			/* Handle of stream to watch. */
    int mask;			/* OR'ed combination of PyEvents_READABLE,
				 * PyEvents_WRITABLE, and PyEvents_EXCEPTION:
                                 * indicates conditions under which proc
                                 * should be called. */
    PyObject* callback;         /* Callback function */
    CFRunLoopRef runloop;
    CFRunLoopSourceRef source;
    CFSocketRef socket;
    CFSocketCallBackType condition;
    CFSocketContext context;
    if (!PyArg_ParseTuple(args, "iiO", &fd, &mask, &callback)) return NULL;
    if (!PyCallable_Check(callback)) {
        PyErr_SetString(PyExc_TypeError, "Callback should be callable");
        return NULL;
    }
    switch (mask) {
        case PyEvents_READABLE:
            condition = kCFSocketReadCallBack; break;
        case PyEvents_WRITABLE:
            condition = kCFSocketWriteCallBack; break;
        case PyEvents_EXCEPTION:
            condition = kCFSocketNoCallBack; break;
        default:
            return PyErr_Format(PyExc_TypeError, "Unexpected mask %d", mask);
    }
    object = (SocketObject*)PyType_GenericNew(&SocketType, NULL, NULL);
    Py_INCREF(object);
    Py_INCREF(callback);
    context.version = 0;
    context.info = object;
    context.retain = 0;
    context.release = 0;
    context.copyDescription = 0;
    socket = CFSocketCreateWithNative(kCFAllocatorDefault,
                                      fd,
                                      condition,
                                      socket_callback,
                                      &context);
    source = CFSocketCreateRunLoopSource(kCFAllocatorDefault,
                                         socket,
                                         0);
    CFRelease(socket);
    runloop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(runloop, source, kCFRunLoopDefaultMode);
    CFRelease(source);
    object->callback = callback;
    object->mask = mask;
    object->source = source;
    return (PyObject*)object;
}

static PyObject*
PyEvents_DeleteSocket(PyObject* argument)
{
    if (!PyObject_TypeCheck(argument, &SocketType)) {
        PyErr_SetString(PyExc_TypeError, "argument is not a socket");
        return NULL;
    }
    SocketObject* object = (SocketObject*)argument;
    CFRunLoopSourceRef source = object->source;
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    if (source) {
        CFRunLoopRemoveSource(runloop, source, kCFRunLoopDefaultMode);
        object->source = NULL;
    }
    Py_DECREF(object->callback);
    Py_DECREF(object);
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
PyEvents_WaitForEvent(PyObject* unused, PyObject* args)
{
    int milliseconds;
    CFTimeInterval seconds;
    SInt32 status;
    long result = 0;
    if (!PyArg_ParseTuple(args, "k", &milliseconds)) return NULL;
    seconds = milliseconds / 1000.0;
    status = CFRunLoopRunInMode(kCFRunLoopDefaultMode, seconds, true);
    switch (status) { 
        case kCFRunLoopRunFinished: result = -1; break;
        case kCFRunLoopRunStopped: result = -1; break;
        case kCFRunLoopRunTimedOut: result = 0; break;
        case kCFRunLoopRunHandledSource: result = 1; break;
    }
    return PyInt_FromLong(result);
}

static void
_stdin_callback(CFReadStreamRef stream, CFStreamEventType eventType, void* info)
{
    CFRunLoopRef runloop = info;
    CFRunLoopStop(runloop);
}

static int sigint_fd = -1;

static void _sigint_handler(int sig)
{
    const char c = 'i';
    write(sigint_fd, &c, 1);
}

static void _sigint_callback(CFSocketRef s,
                             CFSocketCallBackType type,
                             CFDataRef address,
                             const void * data,
                             void *info)
{
    char c;
    int* interrupted = info;
    CFSocketNativeHandle handle = CFSocketGetNative(s);
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    read(handle, &c, 1);
    *interrupted = 1;
    CFRunLoopStop(runloop);
}

static CGEventRef _eventtap_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
    CFRunLoopRef runloop = refcon;
    CFRunLoopStop(runloop);
    return event;
}

static int wait_for_stdin(void)
{
    int interrupted = 0;
    const UInt8 buffer[] = "/dev/fd/0";
    const CFIndex n = (CFIndex)strlen((char*)buffer);
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault,
                                                           buffer,
                                                           n,
                                                           false);
    CFReadStreamRef stream = CFReadStreamCreateWithFile(kCFAllocatorDefault,
                                                        url);
    CFRelease(url);

    CFReadStreamOpen(stream);
#ifdef PYOSINPUTHOOK_REPETITIVE
    if (!CFReadStreamHasBytesAvailable(stream))
    /* This is possible because of how PyOS_InputHook is called from Python */
    {
#endif
        int error;
        int channel[2];
        CFSocketRef sigint_socket = NULL;
        PyOS_sighandler_t py_sigint_handler = NULL;
        CFStreamClientContext clientContext = {0, NULL, NULL, NULL, NULL};
        clientContext.info = runloop;
        CFReadStreamSetClient(stream,
                              kCFStreamEventHasBytesAvailable,
                              _stdin_callback,
                              &clientContext);
        CFReadStreamScheduleWithRunLoop(stream, runloop, kCFRunLoopDefaultMode);
        error = socketpair(AF_UNIX, SOCK_STREAM, 0, channel);
        if (error==0)
        {
            CFSocketContext context;
            context.version = 0;
            context.info = &interrupted;
            context.retain = NULL;
            context.release = NULL;
            context.copyDescription = NULL;
            fcntl(channel[0], F_SETFL, O_WRONLY | O_NONBLOCK);
            sigint_socket = CFSocketCreateWithNative(
                kCFAllocatorDefault,
                channel[1],
                kCFSocketReadCallBack,
                _sigint_callback,
                &context);
            if (sigint_socket)
            {
                CFRunLoopSourceRef source;
                source = CFSocketCreateRunLoopSource(kCFAllocatorDefault,
                                                     sigint_socket,
                                                     0);
                CFRelease(sigint_socket);
                if (source)
                {
                    CFRunLoopAddSource(runloop, source, kCFRunLoopDefaultMode);
                    CFRelease(source);
                    sigint_fd = channel[0];
                    py_sigint_handler = PyOS_setsig(SIGINT, _sigint_handler);
                }
            }
        }

        NSEvent* event;
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        while (true) {
            while (true) {
                event = [NSApp nextEventMatchingMask: NSAnyEventMask
                                           untilDate: [NSDate distantPast]
                                              inMode: NSDefaultRunLoopMode
                                             dequeue: YES];
                if (!event) break;
                [NSApp sendEvent: event];
            }
            CFRunLoopRun();
            if (interrupted || CFReadStreamHasBytesAvailable(stream)) break;
        }
        [pool release];
        if (py_sigint_handler) PyOS_setsig(SIGINT, py_sigint_handler);
        CFReadStreamUnscheduleFromRunLoop(stream,
                                          runloop,
                                          kCFRunLoopCommonModes);
        if (sigint_socket) CFSocketInvalidate(sigint_socket);
        if (error==0) {
            close(channel[0]);
            close(channel[1]);
        }
#ifdef PYOSINPUTHOOK_REPETITIVE
    }
#endif
    CFReadStreamClose(stream);
    CFRelease(stream);
    if (interrupted) {
        errno = EINTR;
        raise(SIGINT);
        return -1;
    }
    return 1;
}

@implementation WindowServerConnectionManager
static WindowServerConnectionManager *sharedWindowServerConnectionManager = nil;

+ (WindowServerConnectionManager *)sharedManager
{
    if (sharedWindowServerConnectionManager == nil)
    {
        sharedWindowServerConnectionManager = [[super allocWithZone:NULL] init];
    }
    return sharedWindowServerConnectionManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [[self sharedManager] retain];
}

+ (id)copyWithZone:(NSZone *)zone
{
    return self;
}

+ (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (oneway void)release
{
    // Don't release a singleton object
}

- (id)autorelease
{
    return self;
}

- (void)launch:(NSNotification*)notification
{
    CFRunLoopRef runloop;
    CFMachPortRef port;
    CFRunLoopSourceRef source;
    NSDictionary* dictionary = [notification userInfo];
    NSNumber* psnLow = [dictionary valueForKey: @"NSApplicationProcessSerialNumberLow"];
    NSNumber* psnHigh = [dictionary valueForKey: @"NSApplicationProcessSerialNumberHigh"];
    ProcessSerialNumber psn;
    psn.highLongOfPSN = [psnHigh intValue];
    psn.lowLongOfPSN = [psnLow intValue];
    runloop = CFRunLoopGetCurrent();
    port = CGEventTapCreateForPSN(&psn,
                                  kCGHeadInsertEventTap,
                                  kCGEventTapOptionListenOnly,
                                  kCGEventMaskForAllEvents,
                                  &_eventtap_callback,
                                  runloop);
    source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault,
                                           port,
                                           0);
    CFRunLoopAddSource(runloop, source, kCFRunLoopDefaultMode);
    CFRelease(port);
}
@end

static struct PyMethodDef methods[] = {
    {"add_timer",
     (PyCFunction)PyEvents_AddTimer,
     METH_VARARGS,
     "add a timer."
    },
    {"remove_timer",
     (PyCFunction)PyEvents_RemoveTimer,
     METH_O,
     "remove the timer."
    },
    {"create_socket",
     (PyCFunction)PyEvents_CreateSocket,
     METH_VARARGS,
     "create a socket."
    },
    {"delete_socket",
     (PyCFunction)PyEvents_DeleteSocket,
     METH_O,
     "delete a socket."
    },
    {"wait_for_event",
     (PyCFunction)PyEvents_WaitForEvent,
     METH_VARARGS,
     "wait for an event."
    },
   {NULL,          NULL, 0, NULL} /* sentinel */
};

#if PY3K
static void freeevents(void* module)
{
    PyOS_InputHook = NULL;
}

static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,  /* m_base */
    "_guitk",               /* m_name */
    "Mac OS X native GUI",  /* m_doc */
    -1,                     /* m_size */
    methods,                /* m_methods */
    NULL,                   /* m_reload */
    NULL,                   /* m_traverse */
    NULL,                   /* m_clear */
    freeevents              /* m_free */
};

PyObject* PyInit__guitk(void)

#else

void init_guitk(void)
#endif
{
#ifdef WITH_NEXT_FRAMEWORK
    PyObject *module;

    if (PyType_Ready(&TimerType) < 0)
        goto error;
    if (PyType_Ready(&SocketType) < 0)
        goto error;

#if PY3K
    module = PyModule_Create(&moduledef);
#else
    module = Py_InitModule4("_guitk",
                            methods,
                            "Mac OS X native GUI",
                            NULL,
                            PYTHON_API_VERSION);
#endif
    if (module==NULL) goto error;

    if (initialize_window(module) < 0)
        goto error;
    if (PyType_Ready(&LabelType) < 0)
        goto error;
    Py_INCREF(&LabelType);
    if (PyModule_AddObject(module, "Label", (PyObject*) &LabelType) < -1)
        goto error;
    if (PyType_Ready(&PackedType) < 0)
        goto error;
    Py_INCREF(&PackedType);
    if (PyModule_AddObject(module, "Packed", (PyObject*) &PackedType) < -1)
        goto error;


    WindowServerConnectionManager* connectionManager = [WindowServerConnectionManager sharedManager];
    NSWorkspace* workspace = [NSWorkspace sharedWorkspace];
    NSNotificationCenter* notificationCenter = [workspace notificationCenter];
    [notificationCenter addObserver: connectionManager
                           selector: @selector(launch:)
                               name: NSWorkspaceDidLaunchApplicationNotification
                             object: nil];

    PyOS_InputHook = wait_for_stdin;
#if PY3K
    return module;
#endif
error:
#if PY3K
    return NULL;
#else
    return;
#endif
#else
    /* WITH_NEXT_FRAMEWORK is not defined. This means that Python is not
     * installed as a framework, and therefore the Mac OS X GUI will
     * not interact properly with the window manager.
     */
    PyErr_SetString(PyExc_RuntimeError,
        "Python is not installed as a framework. The Mac OS X GUI will "
        "not be able to function correctly if Python is not installed as a "
        "framework. See the Python documentation for more information on "
        "installing Python as a framework on Mac OS X.");
#if PY3K
    return NULL;
#else
    return;
#endif
#endif
}
