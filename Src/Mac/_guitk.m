#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <pthread.h>
#include <Python.h>
#include <Cocoa/Cocoa.h>
#define EVENTS_MODULE
#include "events.h"
#include "window.h"
#include "label.h"
#include "button.h"
#include "widgets.h"
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

static pthread_once_t key_once = PTHREAD_ONCE_INIT;
static pthread_key_t notifier_key;

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

static NSMachPort *receivePort = nil;
static mach_port_t rawReceivePort = 0;

static void _sigint_handler(int sig)
{
    mach_msg_return_t retCode = 0;
    mach_msg_empty_send_t msg = {{0}};
    msg.header.msgh_id = sig;
    msg.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSGH_BITS_ZERO);
    msg.header.msgh_size = sizeof(mach_msg_empty_send_t);
    msg.header.msgh_remote_port = rawReceivePort;
    msg.header.msgh_local_port = MACH_PORT_NULL;
    retCode = mach_msg_send(&msg.header);
    if (retCode != 0)
    {
        NSLog(@"mach_msg_send failed in sigint handler");
    }
}

@interface Notifier : NSObject <NSMachPortDelegate>

{
    PyOS_sighandler_t py_sigint_handler;
    BOOL _interrupted;
}
+ (Notifier*)getThreadSpecificNotifier;
- (void)setSigintHandler:(PyOS_sighandler_t)handler;
- (BOOL)resetSigintHandler;
- (void)handleMachMessage:(void *)machMessage;
- (void)dataAvailable:(NSNotification*)notification;
@end

@implementation Notifier
+ (Notifier*)getThreadSpecificNotifier
{
    Notifier* notifier = pthread_getspecific(notifier_key);
    if (!notifier)
    {
        int error;
        notifier = [[Notifier alloc] init];
        error = pthread_setspecific(notifier_key, notifier);
        if (error) {
            errno = error;
            return nil;
        }
    }
    return notifier;
}

- (void)setSigintHandler:(PyOS_sighandler_t)handler {
    NSRunLoop* runloop = [NSRunLoop currentRunLoop];
    [receivePort setDelegate: self];
    [receivePort scheduleInRunLoop: runloop forMode: NSDefaultRunLoopMode];
    py_sigint_handler = PyOS_setsig(SIGINT, handler);
    _interrupted = NO;
}

- (BOOL)resetSigintHandler {
    PyOS_setsig(SIGINT, py_sigint_handler);
    NSRunLoop* runloop = [NSRunLoop currentRunLoop];
    [receivePort removeFromRunLoop: runloop forMode: NSDefaultRunLoopMode];
    return _interrupted;
}

- (void)handleMachMessage:(void *)machMessage
{
    static NSEvent* event = nil;
    mach_msg_header_t* header = machMessage;
    if (header->msgh_id != SIGINT) {
        NSLog(@"Mach message ID is %d (expected SIGINT)", header->msgh_id);
    }
    if (!event) {
        event = [NSEvent otherEventWithType: NSApplicationDefined
                                   location: NSZeroPoint
                              modifierFlags: 0
                                  timestamp: 0
                               windowNumber: 0
                                    context: nil
                                    subtype: 0
                                      data1: 0
                                      data2: 0
                ];
        [event retain];
    }
    [NSApp stop:self];
    [NSApp postEvent: event atStart: NO];
    _interrupted = YES;
}

- (void) dataAvailable: (NSNotification*)notification
{
    static NSEvent* event = nil;
    if (!event) {
        event = [NSEvent otherEventWithType: NSApplicationDefined
                                   location: NSZeroPoint
                              modifierFlags: 0
                                  timestamp: 0
                               windowNumber: 0
                                    context: nil
                                    subtype: 0
                                      data1: 0
                                      data2: 0
                ];
        [event retain];
    }
    [NSApp stop:self];
    [NSApp postEvent: event atStart: NO];
}
@end

static int wait_for_stdin(void)
{
    BOOL interrupted;
    NSNotificationCenter* notificationCenter;
    Notifier* notifier;
    NSFileHandle* stdin_handle;
    notificationCenter = [NSNotificationCenter defaultCenter];
    notifier = [Notifier getThreadSpecificNotifier];
    if (!notifier) return -1;
    stdin_handle = [NSFileHandle fileHandleWithStandardInput];
    [notificationCenter addObserver: notifier
                           selector: @selector(dataAvailable:)
                               name: NSFileHandleDataAvailableNotification
                             object: stdin_handle];
    [stdin_handle waitForDataInBackgroundAndNotify];
    [notifier setSigintHandler:_sigint_handler];
    [NSApp run];
    interrupted = [notifier resetSigintHandler];
    [notificationCenter removeObserver: notifier];
    [stdin_handle release];
    if (interrupted) {
        errno = EINTR;
        raise(SIGINT);
        return -1;
    }
    return +1;
}

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

void delete_notifier(void* value)
{
    Notifier* notifier = value;
    [notifier release];
}

static void create_notifier_key(void)
{
   pthread_key_create(&notifier_key, delete_notifier);
}

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
    if (PyType_Ready(&GridType) < 0)
        goto error;
    if (PyType_Ready(&GridItemType) < 0)
        goto error;
    if (PyType_Ready(&LabelType) < 0)
        goto error;
    if (PyType_Ready(&ButtonType) < 0)
        goto error;
    Py_INCREF(&GridType);
    Py_INCREF(&GridItemType);
    Py_INCREF(&LabelType);
    Py_INCREF(&ButtonType);
    if (PyModule_AddObject(module, "Grid", (PyObject*) &GridType) < -1)
        goto error;
    if (PyModule_AddObject(module, "GridItem", (PyObject*) &GridItemType) < -1)
        goto error;
    if (PyModule_AddObject(module, "Label", (PyObject*) &LabelType) < -1)
        goto error;
    if (PyModule_AddObject(module, "Button", (PyObject*) &ButtonType) < -1)
        goto error;
    if (PyType_Ready(&PackedType) < 0)
        goto error;
    Py_INCREF(&PackedType);
    if (PyModule_AddObject(module, "Packed", (PyObject*) &PackedType) < -1)
        goto error;

    initialize_widgets();

    receivePort = [[NSMachPort alloc] init];
    rawReceivePort = [receivePort machPort];

    PyOS_InputHook = wait_for_stdin;

    pthread_once(&key_once, create_notifier_key);
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
