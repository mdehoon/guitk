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

static CFMachPortRef receivePort = NULL;
static mach_port_t rawReceivePort = 0;

typedef struct {
    PyObject_HEAD
    CFRunLoopTimerRef timer;
    PyObject* callback;
} TimerObject;

static void timer_callout(CFRunLoopTimerRef timer, void* info)
{
    TimerObject* object = info;
    PyGILState_STATE gstate;
    PyObject* exception_type;
    PyObject* exception_value;
    PyObject* exception_traceback;
    PyObject* callback;
    PyObject* arguments;
    PyObject* result = NULL;
    if (object->timer != timer) {
        NSLog(@"Found unexpected timer in callback");
        return;
    }
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
}

static PyObject*
Timer_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    TimerObject *self = (TimerObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->timer = NULL;
    self->callback = NULL;
    return (PyObject*)self;
}

static int
Timer_init(TimerObject *self, PyObject *args, PyObject *kwds)
{
    CFRunLoopTimerRef timer;
    CFAbsoluteTime fireDate;
    CFTimeInterval interval;
    CFRunLoopTimerContext context;
    int repeat = 0;
    unsigned long timeout;
    PyObject* callback;
    if (!PyArg_ParseTuple(args, "kOi", &timeout, &callback, &repeat))
        return -1;
    if (!PyCallable_Check(callback)) {
        PyErr_SetString(PyExc_TypeError, "Callback should be callable");
        return -1;
    }
    interval = timeout / 1000.0;
    fireDate = CFAbsoluteTimeGetCurrent() + interval;
    if (!repeat) interval = 0.0;
    Py_INCREF(callback);
    context.version = 0;
    context.info = self;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
                                 fireDate,
                                 interval,
                                 0,
                                 0,
                                 timer_callout,
                                 &context);
    self->timer = timer;
    self->callback = callback;
    return 0;
}

static void
Timer_dealloc(TimerObject* self)
{
    PyObject* callback;
    CFRunLoopTimerRef timer = self->timer;
    if (timer)
    {
        callback = self->callback;
        Py_DECREF(callback);
        CFRunLoopTimerInvalidate(timer);
        CFRelease(timer);
    }
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Timer_start(TimerObject* self, PyObject *args)
{
    CFRunLoopRef runloop = CFRunLoopGetMain();
    CFRunLoopTimerRef timer = self->timer;
    if (!CFRunLoopContainsTimer(runloop, timer, kCFRunLoopDefaultMode))
    {
        CFRunLoopAddTimer(runloop, timer, kCFRunLoopDefaultMode);
        Py_INCREF((PyObject*)self);
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Timer_stop(TimerObject* self, PyObject *args)
{
    CFRunLoopRef runloop = CFRunLoopGetMain();
    CFRunLoopTimerRef timer = self->timer;
    if (CFRunLoopContainsTimer(runloop, timer, kCFRunLoopDefaultMode))
    {
        CFRunLoopRemoveTimer(runloop, timer, kCFRunLoopDefaultMode);
        Py_DECREF((PyObject*)self);
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Timer_methods[] = {
    {"start",
     (PyCFunction)Timer_start,
     METH_NOARGS,
     "Starts the timer."
    },
    {"stop",
     (PyCFunction)Timer_stop,
     METH_NOARGS,
     "Stops the timer."
    },
    {NULL}  /* Sentinel */
};

static PyObject*               
Timer_repr(TimerObject* self)
{   
    return PyString_FromFormat("Timer object %p", (void*) self);
}

static PyTypeObject TimerType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "events.Timer",            /*tp_name*/
    sizeof(TimerObject),       /*tp_basicsize*/
    0,                         /*tp_itemsize*/
    (destructor)Timer_dealloc, /*tp_dealloc */
    0,                         /*tp_print*/
    0,                         /*tp_getattr*/
    0,                         /*tp_setattr*/
    0,                         /*tp_compare*/
    (reprfunc)Timer_repr,      /*tp_repr*/ 
    0,                         /*tp_as_number*/
    0,                         /*tp_as_sequence*/
    0,                         /*tp_as_mapping*/
    0,                         /*tp_hash */
    0,                         /*tp_call*/
    0,                         /*tp_str*/
    0,                         /*tp_getattro*/
    0,                         /*tp_setattro*/
    0,                         /*tp_as_buffer*/
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,        /* tp_flags */
    "Timer object",            /*tp_doc */
    0,                         /* tp_traverse */
    0,                         /* tp_clear */
    0,                         /* tp_richcompare */
    0,                         /* tp_weaklistoffset */
    0,                         /* tp_iter */
    0,                         /* tp_iternext */
    Timer_methods,             /* tp_methods */
    0,                         /* tp_members */
    0,                         /* tp_getset */
    0,                         /* tp_base */
    0,                         /* tp_dict */
    0,                         /* tp_descr_get */
    0,                         /* tp_descr_set */
    0,                         /* tp_dictoffset */
    (initproc)Timer_init,      /* tp_init */
    0,                         /* tp_alloc */
    Timer_new,                 /* tp_new */
};

static void
callout(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info)
{
    int fd;
    PyGILState_STATE gstate;
    PyObject* exception_type;
    PyObject* exception_value;
    PyObject* exception_traceback;
    PyObject* arguments;
    PyObject* result = NULL;
    fd = CFFileDescriptorGetNativeDescriptor(fdref);
    PyObject* callback = info;
    gstate = PyGILState_Ensure();
    PyErr_Fetch(&exception_type, &exception_value, &exception_traceback);
    arguments = Py_BuildValue("(i)", fd);
    if (arguments) {
        result = PyEval_CallObject(callback, arguments);
        Py_DECREF(arguments);
    }
    if (result) Py_DECREF(result);
    else PyErr_Print();
    PyErr_Restore(exception_type, exception_value, exception_traceback);
    PyGILState_Release(gstate);
    Py_DECREF(callback);
    CFRelease(fdref);
}

static PyObject*
PyEvents_CreateSocket(PyObject* unused, PyObject* args)
{
    int fd;			/* Handle of stream to watch. */
    PyObject* callback;         /* Callback function */
    CFRunLoopRef runloop;
    CFRunLoopSourceRef source;
    CFFileDescriptorRef fdref;
    CFFileDescriptorContext context;
    if (!PyArg_ParseTuple(args, "iO", &fd, &callback)) return NULL;
    if (!PyCallable_Check(callback)) {
        PyErr_SetString(PyExc_TypeError, "Callback should be callable");
        return NULL;
    }
    Py_INCREF(callback);
    context.version = 0;
    context.info = callback;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    fdref = CFFileDescriptorCreate(kCFAllocatorDefault,
                                   fd,
                                   false,
                                   callout,
                                   &context);
    CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
    source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdref, 0);
    runloop = CFRunLoopGetMain();
    CFRunLoopAddSource(runloop, source, kCFRunLoopDefaultMode);
    CFRelease(source);
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

static void
sigint_callout(CFMachPortRef port, void *msg, CFIndex size, void *info)
{
    NSEvent* event;
    Boolean* interrupted = info;
    mach_msg_header_t* header = msg;
    unsigned int expected_size = sizeof(mach_msg_empty_send_t);
    if (header->msgh_id != SIGINT) {
        NSLog(@"Mach message ID is %d (expected SIGINT)", header->msgh_id);
    }
    if (size != expected_size) {
        NSLog(@"Mach message ID is %ld (expected %d)", size, expected_size);
    }
    *interrupted = true;
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
    [NSApp stop:nil];
    [NSApp postEvent: event atStart: NO];
}

static void
stdin_callout(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info)
{
    NSEvent* event;
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
    [NSApp stop:nil];
    [NSApp postEvent: event atStart: NO];
}

static int wait_for_stdin(void)
{
    CFRunLoopRef runloop = CFRunLoopGetMain();
    int fd = fileno(stdin);
    Boolean interrupted = false;
    PyOS_sighandler_t py_sigint_handler;
    CFRunLoopSourceRef stdin_source;
    CFRunLoopSourceRef sigint_source;
    CFFileDescriptorRef fdref;
    CFMachPortContext machport_context;
    runloop = CFRunLoopGetMain();
    fdref = CFFileDescriptorCreate(kCFAllocatorDefault,
                                   fd,
                                   false,
                                   stdin_callout,
                                   NULL);
    CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
    stdin_source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdref, 0);
    CFRelease(fdref);
    CFRunLoopAddSource(runloop, stdin_source, kCFRunLoopDefaultMode);
    CFRelease(stdin_source);
    machport_context.version = 0;
    machport_context.info = &interrupted;
    machport_context.retain = NULL;
    machport_context.release = NULL;
    machport_context.copyDescription = NULL;
    receivePort = CFMachPortCreate(kCFAllocatorDefault,
                                   sigint_callout,
                                   &machport_context,
                                   NULL);
    rawReceivePort = CFMachPortGetPort(receivePort);
    sigint_source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, receivePort, 0);
    CFRunLoopAddSource(runloop, sigint_source, kCFRunLoopDefaultMode);
    CFRelease(sigint_source);
    py_sigint_handler = PyOS_setsig(SIGINT, _sigint_handler);
    [NSApp run];
    PyOS_setsig(SIGINT, py_sigint_handler);
    CFRunLoopRemoveSource(runloop, sigint_source, kCFRunLoopDefaultMode);
    CFRunLoopRemoveSource(runloop, stdin_source, kCFRunLoopDefaultMode);
    if (interrupted) {
        errno = EINTR;
        raise(SIGINT);
        return -1;
    }
    return +1;
}

static struct PyMethodDef methods[] = {
    {"create_socket",
     (PyCFunction)PyEvents_CreateSocket,
     METH_VARARGS,
     "create a socket."
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
    // [receivePort release];
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
    if (PyType_Ready(&TimerType) < 0)
        goto error;
    if (PyType_Ready(&GridType) < 0)
        goto error;
    if (PyType_Ready(&GridItemType) < 0)
        goto error;
    if (PyType_Ready(&LabelType) < 0)
        goto error;
    if (PyType_Ready(&ButtonType) < 0)
        goto error;
    Py_INCREF(&TimerType);
    Py_INCREF(&GridType);
    Py_INCREF(&GridItemType);
    Py_INCREF(&LabelType);
    Py_INCREF(&ButtonType);
    if (PyModule_AddObject(module, "Timer", (PyObject*) &TimerType) < -1)
        goto error;
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

    [NSApplication sharedApplication];

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
