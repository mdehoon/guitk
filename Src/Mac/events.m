#include <Python.h>
#include <Cocoa/Cocoa.h>

#define PYOSINPUTHOOK_REPETITIVE 1 /* Remove this once Python is fixed */

#define READABLE 1
#define WRITABLE 2


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10120
#define COMPILING_FOR_10_12
#endif

@interface ApplicationDelegate: NSObject <NSApplicationDelegate>
{
}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app;
@end

@implementation ApplicationDelegate
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return true;
}
@end


static CFMachPortRef receivePort = NULL;
static mach_port_t rawReceivePort = 0;

static void application_connect(void) {
    NSEvent *event;
    [NSApplication sharedApplication];

    ApplicationDelegate* delegate = [[ApplicationDelegate alloc] init];
    NSApp.delegate = delegate;
    [delegate release];

    while (true) {
#ifdef COMPILING_FOR_10_12
        event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                   untilDate:[NSDate distantPast]
                                      inMode:NSDefaultRunLoopMode
                                     dequeue:YES];
#else
        event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                   untilDate:[NSDate distantPast]
                                      inMode:NSDefaultRunLoopMode
                                     dequeue:YES];
#endif
        if (!event) break;
        [NSApp sendEvent:event];
    }
}

typedef struct {
    PyObject_HEAD
    CFRunLoopTimerRef timer;
    PyObject* callback;
} TimerObject;

static const void* timer_retain(const void *info)
{
    const PyObject* object = info;
    TimerObject* self = (TimerObject*)object;
    PyObject* callback = self->callback;
    Py_INCREF(callback);
    Py_INCREF(object);
    return info;
}

static void timer_release(const void *info)
{
    const PyObject* object = info;
    TimerObject* self = (TimerObject*)object;
    PyObject* callback = self->callback;
    Py_DECREF(callback);
    Py_DECREF(object);
}

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
    callback = object->callback;
    gstate = PyGILState_Ensure();
    PyErr_Fetch(&exception_type, &exception_value, &exception_traceback);
    arguments = Py_BuildValue("(O)", object);
    if (arguments) {
        result = PyObject_CallObject(callback, arguments);
        Py_DECREF(arguments);
    }
    if (result) Py_DECREF(result);
    else PyErr_Print();
    PyErr_Restore(exception_type, exception_value, exception_traceback);
    PyGILState_Release(gstate);
}

static int
Timer_init(TimerObject *self, PyObject *args, PyObject *kwds)
{
    CFRunLoopTimerRef timer;
    CFAbsoluteTime fireDate;
    CFTimeInterval interval;
    CFRunLoopTimerContext context;
    int repeat = 0;
    double timeout;
    PyObject* callback;
    static char* kwlist[] = {"callback", "timeout", "repeat", NULL};
    if(!PyArg_ParseTupleAndKeywords(args, kwds, "Od|i", kwlist,
                                    &callback, &timeout, &repeat))
        return -1;
    if (!PyCallable_Check(callback)) {
        PyErr_SetString(PyExc_TypeError, "callback should be callable");
        return -1;
    }
    if (timeout <= 0)
    {
        PyErr_SetString(PyExc_TypeError, "timeout should be positive");
        return -1;
    }
    self->callback = callback;
    interval = timeout;
    fireDate = CFAbsoluteTimeGetCurrent() + interval;
    if (!repeat) interval = 0.0;
    context.version = 0;
    context.info = self;
    context.retain = timer_retain;
    context.release = timer_release;
    context.copyDescription = NULL;
    timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
                                 fireDate,
                                 interval,
                                 0,
                                 0,
                                 timer_callout,
                                 &context);
    self->timer = timer;
    return 0;
}

static PyObject*
Timer_start(TimerObject* self, PyObject *args)
{
    CFRunLoopRef runloop;
    CFRunLoopTimerRef timer = self->timer;
    if (!timer) {
        PyErr_SetString(PyExc_RuntimeError, "timer has not been initialized.");
        return NULL;
    }
    runloop = CFRunLoopGetMain();
    if (!CFRunLoopTimerIsValid(timer)) {
        /* The timer has been invalidated. Create a new one. */
        CFRunLoopTimerContext context;
        Boolean repeat = CFRunLoopTimerDoesRepeat(timer);
        CFTimeInterval interval = CFRunLoopTimerGetInterval(timer);
        CFAbsoluteTime fireDate = CFAbsoluteTimeGetCurrent() + interval;
        if (!repeat) interval = 0.0;
        CFRunLoopTimerGetContext(timer, &context);
        /* context.info may be NULL if the timer is not running. */
        context.info = self;
        timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
                                     fireDate,
                                     interval,
                                     0,
                                     0,
                                     timer_callout,
                                     &context);
        CFRelease(self->timer);
        self->timer = timer;
    }
    CFRunLoopAddTimer(runloop, timer, kCFRunLoopDefaultMode);
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Timer_stop(TimerObject* self, PyObject *args)
{
    CFRunLoopTimerRef timer = self->timer;
    if (!timer) {
        PyErr_SetString(PyExc_RuntimeError, "timer has not been initialized.");
        return NULL;
    }
    /* Invalidate, rather than just removing the timer, to make sure that
     * the timer can be deallocated. */
    CFRunLoopTimerInvalidate(timer);
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

static PyObject* Timer_get_timeout(TimerObject* self, void* closure)
{
    CFTimeInterval interval;
    CFRunLoopTimerRef timer = self->timer;
    if (!timer) {
        PyErr_SetString(PyExc_RuntimeError, "timer has not been initialized.");
        return NULL;
    }
    interval = CFRunLoopTimerGetInterval(timer);
    return PyFloat_FromDouble(interval);
}

static int
Timer_set_timeout(TimerObject* self, PyObject* value, void* closure)
{
    CFAbsoluteTime fireDate;
    CFAbsoluteTime now;
    CFTimeInterval interval;
    Boolean repeat;
    Boolean running;
    CFRunLoopRef runloop;
    CFRunLoopTimerContext context;
    CFRunLoopTimerRef timer = self->timer;
    if (!timer) {
        PyErr_SetString(PyExc_RuntimeError, "timer has not been initialized.");
        return -1;
    }
    now = CFAbsoluteTimeGetCurrent();
    repeat = CFRunLoopTimerDoesRepeat(timer);
    interval = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    if (interval <= 0)
    {
        PyErr_SetString(PyExc_TypeError, "timeout should be positive");
        return -1;
    }
    fireDate = now + interval;
    if (!repeat) interval = 0.0;
    runloop = CFRunLoopGetMain();
    running = CFRunLoopContainsTimer(runloop, timer, kCFRunLoopDefaultMode);
    CFRunLoopTimerGetContext(timer, &context);
    /* context.info may be NULL if the timer is not running. */
    context.info = self;
    timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
                                 fireDate,
                                 interval,
                                 0,
                                 0,
                                 timer_callout,
                                 &context);
    CFRunLoopTimerInvalidate(self->timer);
    CFRelease(self->timer);
    self->timer = timer;
    if (running) CFRunLoopAddTimer(runloop, timer, kCFRunLoopDefaultMode);
    return 0;
}

static char Timer_timeout__doc__[] = "timeout in seconds";

static PyObject* Timer_get_repeating(TimerObject* self, void* closure)
{
    CFRunLoopTimerRef timer = self->timer;
    if (!timer) {
        PyErr_SetString(PyExc_RuntimeError, "timer has not been initialized.");
        return NULL;
    }
    if (CFRunLoopTimerDoesRepeat(timer)) Py_RETURN_TRUE;
    Py_RETURN_FALSE;
}

static char Timer_repeating__doc__[] = "True if the timer is repeating; False if the timer is one-shot";

static PyGetSetDef Timer_getset[] = {
    {"timeout", (getter)Timer_get_timeout, (setter)Timer_set_timeout, Timer_timeout__doc__, NULL},
    {"repeating", (getter)Timer_get_repeating, (setter)NULL, Timer_repeating__doc__, NULL},
    {NULL}  /* Sentinel */
};

static void
Timer_dealloc(TimerObject *self)
{
    CFRunLoopTimerRef timer = self->timer;
    if (timer) {
        CFRunLoopTimerInvalidate(timer);
        CFRelease(timer);
    }
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*               
Timer_repr(TimerObject* self)
{
    void* p = self;
    return PyUnicode_FromFormat("Timer object %p", p);
}

static PyTypeObject TimerType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "events.Timer",            /*tp_name*/
    sizeof(TimerObject),       /*tp_basicsize*/
    0,                         /*tp_itemsize*/
    (destructor)Timer_dealloc, /*tp_dealloc*/
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
    Timer_getset,              /* tp_getset */
    0,                         /* tp_base */
    0,                         /* tp_dict */
    0,                         /* tp_descr_get */
    0,                         /* tp_descr_set */
    0,                         /* tp_dictoffset */
    (initproc)Timer_init,      /* tp_init */
};

static PyObject*
PyEvents_CreateTimer(PyObject* unused, PyObject* args, PyObject* keywords)
{
    PyObject* object;
    CFRunLoopRef runloop;
    CFRunLoopTimerRef timer;
    CFAbsoluteTime fireDate;
    CFTimeInterval interval;
    CFRunLoopTimerContext context;
    int repeat = 0;
    double timeout;
    PyObject* callback;
    PyTypeObject* type = &TimerType;
    static char* kwlist[] = {"callback", "timeout", "repeat", NULL};
    if(!PyArg_ParseTupleAndKeywords(args, keywords, "Od|i", kwlist,
                                    &callback, &timeout, &repeat))
        return NULL;
    if (!PyCallable_Check(callback)) {
        PyErr_SetString(PyExc_TypeError, "callback should be callable");
        return NULL;
    }
    if (timeout <= 0)
    {
        PyErr_SetString(PyExc_TypeError, "timeout should be positive");
        return NULL;
    }
    TimerObject *self = (TimerObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->callback = callback;
    interval = timeout;
    fireDate = CFAbsoluteTimeGetCurrent() + interval;
    if (!repeat) interval = 0.0;
    context.version = 0;
    context.info = self;
    context.retain = timer_retain;
    context.release = timer_release;
    context.copyDescription = NULL;
    timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
                                 fireDate,
                                 interval,
                                 0,
                                 0,
                                 timer_callout,
                                 &context);
    self->timer = timer;
    runloop = CFRunLoopGetMain();
    CFRunLoopAddTimer(runloop, timer, kCFRunLoopDefaultMode);
    object = (PyObject*)self;
    return object;
}

typedef struct {
    PyObject_HEAD
    CFFileDescriptorRef fdref;
    PyObject* callback;
} NotifierObject;

static void* notifier_retain(void *info)
{
    const PyObject* object = info;
    NotifierObject* self = (NotifierObject*)object;
    PyObject* callback = self->callback;
    Py_INCREF(callback);
    Py_INCREF(object);
    return info;
}

static void notifier_release(void *info)
{
    const PyObject* object = info;
    NotifierObject* self = (NotifierObject*)object;
    PyObject* callback = self->callback;
    Py_DECREF(callback);
    Py_DECREF(object);
}

static void
notifier_callout(CFFileDescriptorRef fdref,
                 CFOptionFlags callBackTypes,
                 void *info)
{
    PyGILState_STATE gstate;
    PyObject* exception_type;
    PyObject* exception_value;
    PyObject* exception_traceback;
    PyObject* callback;
    PyObject* arguments;
    PyObject* result = NULL;
    NotifierObject* object = info;
    callback = object->callback;
    gstate = PyGILState_Ensure();
    PyErr_Fetch(&exception_type, &exception_value, &exception_traceback);
    arguments = Py_BuildValue("(O)", object);
    if (arguments) {
        result = PyObject_CallObject(callback, arguments);
        Py_DECREF(arguments);
    }
    if (result) Py_DECREF(result);
    else PyErr_Print();
    CFFileDescriptorInvalidate(fdref);
    PyErr_Restore(exception_type, exception_value, exception_traceback);
    PyGILState_Release(gstate);
}

static int
Notifier_init(NotifierObject *self, PyObject *args, PyObject *kwds)
{
    int fd;               /* Handle of stream to watch. */
    PyObject* callback;
    CFFileDescriptorRef fdref;
    CFFileDescriptorContext context;
    static char* kwlist[] = {"callback", "fd", NULL};
    if(!PyArg_ParseTupleAndKeywords(args, kwds, "Oi", kwlist, &callback, &fd))
        return -1;
    if (!PyCallable_Check(callback)) {
        PyErr_SetString(PyExc_TypeError, "Callback should be callable");
        return -1;
    }
    self->callback = callback;
    context.version = 0;
    context.info = self;
    context.retain = notifier_retain;
    context.release = notifier_release;
    context.copyDescription = NULL;
    fdref = CFFileDescriptorCreate(kCFAllocatorDefault,
                                   fd,
                                   false,
                                   notifier_callout,
                                   &context);
    self->fdref = fdref;
    return 0;
}

static PyObject*
Notifier_start(NotifierObject *self, PyObject *args, PyObject *kwds)
{
    CFRunLoopRef runloop;
    CFRunLoopSourceRef source;
    int event = READABLE; /* events we are interested in; READABLE or WRITABLE */
    CFOptionFlags flags;
    static char* kwlist[] = {"event", NULL};
    CFFileDescriptorRef fdref = self->fdref;
    if (!fdref) {
        PyErr_SetString(PyExc_RuntimeError, "notifier has not been initialized.");
        return NULL;
    }
    if(!PyArg_ParseTupleAndKeywords(args, kwds, "i", kwlist, &event))
        return NULL;
    switch (event) {
        case READABLE: flags = kCFFileDescriptorReadCallBack; break;
        case WRITABLE: flags = kCFFileDescriptorWriteCallBack; break;
        default:
            PyErr_SetString(PyExc_TypeError, "event should be events.readable or events.writable");
            return NULL;
    }
    runloop = CFRunLoopGetMain();
    if (!CFFileDescriptorIsValid(fdref)) {
        /* The file descriptor has been invalidated. Create a new one. */
        int fd = CFFileDescriptorGetNativeDescriptor(fdref);
        CFFileDescriptorContext context;
        context.version = 0;
        context.info = self;
        context.retain = notifier_retain;
        context.release = notifier_release;
        context.copyDescription = NULL;
        fdref = CFFileDescriptorCreate(kCFAllocatorDefault,
                                       fd,
                                       false,
                                       notifier_callout,
                                       &context);
        CFRelease(self->fdref);
        self->fdref = fdref;
    }
    if (fdref == 0) {fprintf(stderr, "fdref = 0\n"); fflush(stderr); }
    CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
    source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdref, 0);
    CFRunLoopAddSource(runloop, source, kCFRunLoopDefaultMode);
    CFRelease(source);
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Notifier_stop(NotifierObject* self, PyObject *args)
{
    CFFileDescriptorRef fdref = self->fdref;
    if (!fdref) {
        PyErr_SetString(PyExc_RuntimeError, "notifier has not been initialized.");
        return NULL;
    }
    CFFileDescriptorInvalidate(fdref);
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Notifier_methods[] = {
    {"start",
     (PyCFunction)Notifier_start,
     METH_KEYWORDS | METH_VARARGS,
     "Starts the notifier."
    },
    {"stop",
     (PyCFunction)Notifier_stop,
     METH_NOARGS,
     "Stops the notifier."
    },
    {NULL}  /* Sentinel */
};

static char Notifier_fd__doc__[] = "native file descriptor";

static PyObject* Notifier_get_fd(NotifierObject* self, void* closure)
{
    int fd;
    CFFileDescriptorRef fdref = self->fdref;
    if (!fdref) {
        PyErr_SetString(PyExc_RuntimeError, "notifier has not been initialized.");
        return NULL;
    }
    fd = CFFileDescriptorGetNativeDescriptor(fdref);
    return PyLong_FromLong(fd);
}

static PyGetSetDef Notifier_getset[] = {
    {"fd", (getter)Notifier_get_fd, (setter)NULL, Notifier_fd__doc__, NULL},
    {NULL}  /* Sentinel */
};

static void
Notifier_dealloc(NotifierObject *self)
{
    CFFileDescriptorRef fdref = self->fdref;
    if (fdref) {
        CFFileDescriptorInvalidate(fdref);
        CFRelease(fdref);
    }
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*               
Notifier_repr(NotifierObject* self)
{
    int fd;
    void* p = self;
    CFFileDescriptorRef fdref = self->fdref;
    if (!fdref)
        return PyUnicode_FromFormat("Notifier object %p (not initialized)", p);
    fd = CFFileDescriptorGetNativeDescriptor(fdref);
    return PyUnicode_FromFormat("Notifier object %p for file descriptor %d", p, fd);
}

static PyTypeObject NotifierType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "events.Notifier",         /*tp_name*/
    sizeof(NotifierObject),    /*tp_basicsize*/
    0,                         /*tp_itemsize*/
    (destructor)Notifier_dealloc, /*tp_dealloc*/
    0,                         /*tp_print*/
    0,                         /*tp_getattr*/
    0,                         /*tp_setattr*/
    0,                         /*tp_compare*/
    (reprfunc)Notifier_repr,   /*tp_repr*/ 
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
    "Notifier object",         /*tp_doc */
    0,                         /* tp_traverse */
    0,                         /* tp_clear */
    0,                         /* tp_richcompare */
    0,                         /* tp_weaklistoffset */
    0,                         /* tp_iter */
    0,                         /* tp_iternext */
    Notifier_methods,          /* tp_methods */
    0,                         /* tp_members */
    Notifier_getset,           /* tp_getset */
    0,                         /* tp_base */
    0,                         /* tp_dict */
    0,                         /* tp_descr_get */
    0,                         /* tp_descr_set */
    0,                         /* tp_dictoffset */
    (initproc)Notifier_init,   /* tp_init */
};

static PyObject*
PyEvents_CreateNotifier(PyObject* unused, PyObject* args, PyObject* kwds)
{
    int fd;               /* Handle of stream to watch. */
    int event = READABLE; /* events we are interested in; READABLE or WRITABLE */
    PyObject* callback;
    CFOptionFlags flags;
    CFFileDescriptorRef fdref;
    CFFileDescriptorContext context;
    CFRunLoopRef runloop;
    CFRunLoopSourceRef source;
    PyObject* object;
    PyTypeObject* type = &NotifierType;
    static char* kwlist[] = {"callback", "fd", "event", NULL};
    if(!PyArg_ParseTupleAndKeywords(args, kwds, "Oi|i", kwlist, &callback, &fd, &event))
        return NULL;
    if (!PyCallable_Check(callback)) {
        PyErr_SetString(PyExc_TypeError, "Callback should be callable");
        return NULL;
    }
    switch (event) {
        case READABLE: flags = kCFFileDescriptorReadCallBack; break;
        case WRITABLE: flags = kCFFileDescriptorWriteCallBack; break;
        default:
            PyErr_SetString(PyExc_TypeError, "event should be events.readable or events.writable");
            return NULL;
    }
    NotifierObject *self = (NotifierObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->callback = callback;
    context.version = 0;
    context.info = self;
    context.retain = notifier_retain;
    context.release = notifier_release;
    context.copyDescription = NULL;
    fdref = CFFileDescriptorCreate(kCFAllocatorDefault,
                                   fd,
                                   false,
                                   notifier_callout,
                                   &context);
    self->fdref = fdref;
    CFFileDescriptorEnableCallBacks(fdref, flags);
    source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdref, 0);
    runloop = CFRunLoopGetMain();
    CFRunLoopAddSource(runloop, source, kCFRunLoopDefaultMode);
    CFRelease(source);
    object = (PyObject*)self;
    return object;
}

static void _stop(void)
{
    if ([NSApp isRunning]) {
        NSEvent* event;
#ifdef COMPILING_FOR_10_12
        event = [NSEvent otherEventWithType: NSEventTypeApplicationDefined
                                   location: NSZeroPoint
                              modifierFlags: 0
                                  timestamp: 0
                               windowNumber: 0
                                    context: nil
                                    subtype: 0
                                      data1: 0
                                      data2: 0
                 ];
#else
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
#endif
        [NSApp stop:nil];
        [NSApp postEvent: event atStart: NO];
    }
    else {
        CFRunLoopRef runloop = CFRunLoopGetCurrent();
        CFRunLoopStop(runloop);
    }
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
    _stop();
}

static void
stdin_callout(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info)
{
    _stop();
}

static Boolean _run(CFRunLoopRef runloop)
{
    NSArray* windows;
    NSUInteger count;
    Boolean interrupted = false;
    CFMachPortContext machport_context;
    CFRunLoopSourceRef source;
    PyOS_sighandler_t py_sigint_handler;
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
    source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, receivePort, 0);
    CFRunLoopAddSource(runloop, source, kCFRunLoopDefaultMode);
    CFRelease(source);
    py_sigint_handler = PyOS_setsig(SIGINT, _sigint_handler);
    windows = [NSApp windows];
    count = [windows count];
    [windows release];
    if (count > 0)
        [NSApp run];
    else
        CFRunLoopRun(); 
    PyOS_setsig(SIGINT, py_sigint_handler);
    CFRunLoopRemoveSource(runloop, source, kCFRunLoopDefaultMode);
    return interrupted;
}

static int wait_for_stdin(void)
{
    CFRunLoopRef runloop = CFRunLoopGetMain();
    int fd = fileno(stdin);
    Boolean interrupted;
    CFRunLoopSourceRef source;
    CFFileDescriptorRef fdref;
    runloop = CFRunLoopGetMain();
    fdref = CFFileDescriptorCreate(kCFAllocatorDefault,
                                   fd,
                                   false,
                                   stdin_callout,
                                   NULL);
    CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
    source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdref, 0);
    CFRelease(fdref);
    CFRunLoopAddSource(runloop, source, kCFRunLoopDefaultMode);
    CFRelease(source);
    interrupted = _run(runloop);
    CFRunLoopRemoveSource(runloop, source, kCFRunLoopDefaultMode);
    if (interrupted) {
        errno = EINTR;
        raise(SIGINT);
        return -1;
    }
    return +1;
}

static PyObject*
PyEvents_Run(PyObject* unused, PyObject* args)
{
    CFRunLoopRef runloop;
    Boolean interrupted;
    runloop = CFRunLoopGetMain();
    interrupted = _run(runloop);
    if (interrupted) {
        PyErr_SetNone(PyExc_KeyboardInterrupt);
        return NULL;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
PyEvents_Stop(PyObject* unused, PyObject* args)
{
    _stop();
    Py_INCREF(Py_None);
    return Py_None;
}

static struct PyMethodDef methods[] = {
    {"create_timer",
     (PyCFunction)PyEvents_CreateTimer,
     METH_KEYWORDS | METH_VARARGS,
     "Creates and starts a timer.\n",
    },
    {"create_notifier",
     (PyCFunction)PyEvents_CreateNotifier,
     METH_KEYWORDS | METH_VARARGS,
     "Creates and starts a file descriptor notifier.\n",
    },
    {"run",
     (PyCFunction)PyEvents_Run,
     METH_NOARGS,
     "Run the event loop."
    },
    {"stop",
     (PyCFunction)PyEvents_Stop,
     METH_NOARGS,
     "Stops the event loop."
    },
   {NULL,          NULL, 0, NULL} /* sentinel */
};

static void freeevents(void* module)
{
    PyOS_InputHook = NULL;
    // [receivePort release];
}

static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,         /* m_base */
    "events",                      /* m_name */
    "events module for Mac OS X",  /* m_doc */
    -1,                            /* m_size */
    methods,                       /* m_methods */
    NULL,                          /* m_reload */
    NULL,                          /* m_traverse */
    NULL,                          /* m_clear */
    freeevents                     /* m_free */
};

PyObject* PyInit_events(void)
{
#ifdef WITH_NEXT_FRAMEWORK
    PyObject *module;

    module = PyModule_Create(&moduledef);
    if (module==NULL) goto error;

    TimerType.tp_new = PyType_GenericNew;
    if (PyType_Ready(&TimerType) < 0)
        goto error;
    NotifierType.tp_new = PyType_GenericNew;
    if (PyType_Ready(&NotifierType) < 0)
        goto error;
    Py_INCREF(&TimerType);
    Py_INCREF(&NotifierType);
    if (PyModule_AddObject(module, "Timer", (PyObject*) &TimerType) < -1)
        goto error;
    if (PyModule_AddObject(module, "Notifier", (PyObject*) &NotifierType) < -1)
        goto error;

    if (PyModule_AddIntConstant(module, "READABLE", READABLE) < -1)
        goto error;
    if (PyModule_AddIntConstant(module, "WRITABLE", WRITABLE) < -1)
        goto error;

    application_connect();

    PyOS_InputHook = wait_for_stdin;

    return module;
error:
    return NULL;
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
    return NULL;
#endif
}
