#include <Python.h>
#include <stdbool.h>
#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>
#include <X11/Shell.h>
#include <X11/Xatom.h>


#define TCL_THREADS

#include "tcl.h"
#include "tk.h"


static PyThread_type_lock tcl_lock = 0;

extern Tcl_ThreadDataKey state_key;
typedef PyThreadState *ThreadSpecificData;

#define ENTER_TCL \
    { PyThreadState *tstate = PyThreadState_Get(); \
      Py_BEGIN_ALLOW_THREADS \
      if(tcl_lock)PyThread_acquire_lock(tcl_lock, 1); \
      (*(PyThreadState**)Tcl_GetThreadData(&state_key, sizeof(PyThreadState*))) = tstate;

#define LEAVE_TCL \
    (*(PyThreadState**)Tcl_GetThreadData(&state_key, sizeof(PyThreadState*))) = NULL; \
    if(tcl_lock)PyThread_release_lock(tcl_lock); \
    Py_END_ALLOW_THREADS}


static bool threaded = 0;
static Tcl_ThreadId thread_id = NULL;

static int* framePtr = NULL;

typedef struct FileHandler {
    int fd;
    int mask;			/* Mask of desired events: TCL_READABLE,
				 * etc. */
    int readyMask;		/* Events that have been seen since the last
				 * time FileHandlerEventProc was called for
				 * this file. */
    XtInputId read;		/* Xt read callback handle. */
    XtInputId write;		/* Xt write callback handle. */
    XtInputId except;		/* Xt exception callback handle. */
    Tcl_FileProc *proc;		/* Procedure to call, in the style of
				 * Tcl_CreateFileHandler. */
    void *clientData;		/* Argument to pass to proc. */
    struct FileHandler *nextPtr;/* Next in list of all files we care about. */
} FileHandler;


typedef struct {
    Tcl_Event header;		/* Information that is standard for all
				 * events. */
    int fd;			/* File descriptor that is ready. Used to find
				 * the FileHandler structure for the file
				 * (can't point directly to the FileHandler
				 * structure because it could go away while
				 * the event is queued). */
} FileHandlerEvent;

static struct NotifierState {
    XtAppContext appContext;	/* The context used by the Xt notifier. */
    XtIntervalId currentTimeout;/* Handle of current timer. */
    FileHandler *firstFileHandlerPtr;
				/* Pointer to head of file handler list. */
} notifier = {NULL, 0, NULL};

/*
 *----------------------------------------------------------------------
 *
 * TimerProc --
 *
 *	This procedure is the XtTimerCallbackProc used to handle timeouts.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Processes all queued events.
 *
 *----------------------------------------------------------------------
 */

static void
TimerProc(XtPointer unused, XtIntervalId *id)
{
fprintf(stderr, "In TimerProc\n"); fflush(stderr);
    if (*id != notifier.currentTimeout) {
	return;
    }
    notifier.currentTimeout = 0;

    Tcl_ServiceAll();
}

static void
SetTimer(const Tcl_Time *timePtr)
{
    unsigned long timeout;
fprintf(stderr, "In SetTimer\n"); fflush(stderr);
    if (notifier.currentTimeout != 0) {
	XtRemoveTimeOut(notifier.currentTimeout);
    }
    if (timePtr) {
	timeout = timePtr->sec * 1000 + timePtr->usec / 1000;
	notifier.currentTimeout = XtAppAddTimeOut(notifier.appContext,
		timeout, TimerProc, NULL);
    } else {
	notifier.currentTimeout = 0;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * WaitForEvent --
 *
 *	This function is called by Tcl_DoOneEvent to wait for new events on
 *	the message queue. If the block time is 0, then Tcl_WaitForEvent just
 *	polls without blocking.
 *
 * Results:
 *	Returns 1 if an event was found, else 0. This ensures that
 *	Tcl_DoOneEvent will return 1, even if the event is handled by non-Tcl
 *	code.
 *
 * Side effects:
 *	Queues file events that are detected by the select.
 *
 *----------------------------------------------------------------------
 */

static int
WaitForEvent(
    const Tcl_Time *timePtr)	/* Maximum block time, or NULL. */
{
    int timeout;
fprintf(stderr, "Starting WaitForEvent\n"); fflush(stderr);
    if (timePtr) {
	timeout = timePtr->sec * 1000 + timePtr->usec / 1000;
	if (timeout == 0) {
	    if (XtAppPending(notifier.appContext)) {
		goto process;
	    } else {
fprintf(stderr, "Leaving WaitForEvent 0\n"); fflush(stderr);
		return 0;
	    }
	} else {
	    Tcl_SetTimer(timePtr);
	}
    }

  process:
    XtAppProcessEvent(notifier.appContext, XtIMAll);
fprintf(stderr, "Leaving WaitForEvent\n"); fflush(stderr);
    return 1;
}

/*
 *----------------------------------------------------------------------
 *
 * FileHandlerEventProc --
 *
 *	This procedure is called by Tcl_ServiceEvent when a file event reaches
 *	the front of the event queue. This procedure is responsible for
 *	actually handling the event by invoking the callback for the file
 *	handler.
 *
 * Results:
 *	Returns 1 if the event was handled, meaning it should be removed from
 *	the queue. Returns 0 if the event was not handled, meaning it should
 *	stay on the queue. The only time the event isn't handled is if the
 *	TCL_FILE_EVENTS flag bit isn't set.
 *
 * Side effects:
 *	Whatever the file handler's callback procedure does.
 *
 *----------------------------------------------------------------------
 */

static int
FileHandlerEventProc(
    Tcl_Event *evPtr,		/* Event to service. */
    int flags)			/* Flags that indicate what events to handle,
				 * such as TCL_FILE_EVENTS. */
{
    FileHandler *filePtr;
    FileHandlerEvent *fileEvPtr = (FileHandlerEvent *) evPtr;
    int mask;
fprintf(stderr, "Starting FileHandlerEventProc\n"); fflush(stderr);

    if (!(flags & TCL_FILE_EVENTS)) {
fprintf(stderr, "Leaving FileHandlerEventProc 0\n"); fflush(stderr);
	return 0;
    }

    /*
     * Search through the file handlers to find the one whose handle matches
     * the event. We do this rather than keeping a pointer to the file handler
     * directly in the event, so that the handler can be deleted while the
     * event is queued without leaving a dangling pointer.
     */

    for (filePtr = notifier.firstFileHandlerPtr; filePtr != NULL;
	    filePtr = filePtr->nextPtr) {
	if (filePtr->fd != fileEvPtr->fd) {
	    continue;
	}

	/*
	 * The code is tricky for two reasons:
	 * 1. The file handler's desired events could have changed since the
	 *    time when the event was queued, so AND the ready mask with the
	 *    desired mask.
	 * 2. The file could have been closed and re-opened since the time
	 *    when the event was queued. This is why the ready mask is stored
	 *    in the file handler rather than the queued event: it will be
	 *    zeroed when a new file handler is created for the newly opened
	 *    file.
	 */

	mask = filePtr->readyMask & filePtr->mask;
	filePtr->readyMask = 0;
	if (mask != 0) {
fprintf(stderr, "In FileHandlerEventProc, calling filePtr->proc\n"); fflush(stderr);
	    filePtr->proc(filePtr->clientData, mask);
fprintf(stderr, "In FileHandlerEventProc, after calling filePtr->proc\n"); fflush(stderr);
	}
	break;
    }
fprintf(stderr, "Leaving FileHandlerEventProc\n"); fflush(stderr);
    return 1;
}

/*
 *----------------------------------------------------------------------
 *
 * DeleteFileHandler --
 *
 *	Cancel a previously-arranged callback arrangement for a file.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	If a callback was previously registered on file, remove it.
 *
 *----------------------------------------------------------------------
 */

static void
DeleteFileHandler(
    int fd)			/* Stream id for which to remove callback
				 * procedure. */
{
    FileHandler *filePtr, *prevPtr;
fprintf(stderr, "In DeleteFileHandler\n"); fflush(stderr);
    /*
     * Find the entry for the given file (and return if there isn't one).
     */

    for (prevPtr = NULL, filePtr = notifier.firstFileHandlerPtr; ;
	    prevPtr = filePtr, filePtr = filePtr->nextPtr) {
	if (filePtr == NULL) {
	    return;
	}
	if (filePtr->fd == fd) {
	    break;
	}
    }

    /*
     * Clean up information in the callback record.
     */

    if (prevPtr == NULL) {
	notifier.firstFileHandlerPtr = filePtr->nextPtr;
    } else {
	prevPtr->nextPtr = filePtr->nextPtr;
    }
    if (filePtr->mask & TCL_READABLE) {
	XtRemoveInput(filePtr->read);
    }
    if (filePtr->mask & TCL_WRITABLE) {
	XtRemoveInput(filePtr->write);
    }
    if (filePtr->mask & TCL_EXCEPTION) {
	XtRemoveInput(filePtr->except);
    }
    Tcl_Free((char*) filePtr);
}

static void
NotifierExitHandler(void *unused)
{
fprintf(stderr, "in NotifierExitHandler\n"); fflush(stderr);
    if (notifier.currentTimeout != 0) {
	XtRemoveTimeOut(notifier.currentTimeout);
    }
    for (; notifier.firstFileHandlerPtr != NULL; ) {
	Tcl_DeleteFileHandler(notifier.firstFileHandlerPtr->fd);
    }
    if (notifier.appContext) {
	XtDestroyApplicationContext(notifier.appContext);
	notifier.appContext = NULL;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * FileProc --
 *
 *	These procedures are called by Xt when a file becomes readable,
 *	writable, or has an exception.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Makes an entry on the Tcl event queue if the event is interesting.
 *
 *----------------------------------------------------------------------
 */

static void
FileProc(
    XtPointer clientData,
    int *fd,
    XtInputId *id)
{
    FileHandler *filePtr = (FileHandler *) clientData;
    FileHandlerEvent *fileEvPtr;
    int mask = 0;
fprintf(stderr, "Starting FileProc\n"); fflush(stderr);

    /*
     * Determine which event happened.
     */

    if (*id == filePtr->read) {
	mask = TCL_READABLE;
    } else if (*id == filePtr->write) {
	mask = TCL_WRITABLE;
    } else if (*id == filePtr->except) {
	mask = TCL_EXCEPTION;
    }

    /*
     * Ignore unwanted or duplicate events.
     */

    if (!(filePtr->mask & mask) || (filePtr->readyMask & mask)) {
	return;
    }

    /*
     * This is an interesting event, so put it onto the event queue.
     */

    filePtr->readyMask |= mask;
    fileEvPtr = (FileHandlerEvent *) Tcl_Alloc(sizeof(FileHandlerEvent));
    fileEvPtr->header.proc = FileHandlerEventProc;
    fileEvPtr->fd = filePtr->fd;
    Tcl_QueueEvent((Tcl_Event *) fileEvPtr, TCL_QUEUE_TAIL);

    /*
     * Process events on the Tcl event queue before returning to Xt.
     */

    Tcl_ServiceAll();
}

/*
 *----------------------------------------------------------------------
 *
 * CreateFileHandler --
 *
 *	This procedure registers a file handler with the Xt notifier.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Creates a new file handler structure and registers one or more input
 *	procedures with Xt.
 *
 *----------------------------------------------------------------------
 */

static void
CreateFileHandler(
    int fd,			/* Handle of stream to watch. */
    int mask,			/* OR'ed combination of TCL_READABLE,
				 * TCL_WRITABLE, and TCL_EXCEPTION: indicates
				 * conditions under which proc should be
				 * called. */
    Tcl_FileProc *proc,		/* Procedure to call for each selected
				 * event. */
    void *clientData)		/* Arbitrary data to pass to proc. */
{
    FileHandler *filePtr;
fprintf(stderr, "In CreateFileHandler\n"); fflush(stderr);
    for (filePtr = notifier.firstFileHandlerPtr; filePtr != NULL;
	    filePtr = filePtr->nextPtr) {
	if (filePtr->fd == fd) {
	    break;
	}
    }
    if (filePtr == NULL) {
	filePtr = (FileHandler *) Tcl_Alloc(sizeof(FileHandler));
	filePtr->fd = fd;
	filePtr->read = 0;
	filePtr->write = 0;
	filePtr->except = 0;
	filePtr->readyMask = 0;
	filePtr->mask = 0;
	filePtr->nextPtr = notifier.firstFileHandlerPtr;
	notifier.firstFileHandlerPtr = filePtr;
    }
    filePtr->proc = proc;
    filePtr->clientData = clientData;

    /*
     * Register the file with the Xt notifier, if it hasn't been done yet.
     */

    if (mask & TCL_READABLE) {
	if (!(filePtr->mask & TCL_READABLE)) {
	    filePtr->read = XtAppAddInput(notifier.appContext, fd,
		    (void *)(intptr_t)XtInputReadMask, FileProc, filePtr);
	}
    } else {
	if (filePtr->mask & TCL_READABLE) {
	    XtRemoveInput(filePtr->read);
	}
    }
    if (mask & TCL_WRITABLE) {
	if (!(filePtr->mask & TCL_WRITABLE)) {
	    filePtr->write = XtAppAddInput(notifier.appContext, fd,
		    (void *)(intptr_t)XtInputWriteMask, FileProc, filePtr);
	}
    } else {
	if (filePtr->mask & TCL_WRITABLE) {
	    XtRemoveInput(filePtr->write);
	}
    }
    if (mask & TCL_EXCEPTION) {
	if (!(filePtr->mask & TCL_EXCEPTION)) {
	    filePtr->except = XtAppAddInput(notifier.appContext, fd,
		    (void *)(intptr_t)XtInputExceptMask, FileProc, filePtr);
	}
    } else {
	if (filePtr->mask & TCL_EXCEPTION) {
	    XtRemoveInput(filePtr->except);
	}
    }
    filePtr->mask = mask;
}

static void InitNotifier(void)
{
    static Tcl_NotifierProcs np = {
        SetTimer,
	WaitForEvent,
	CreateFileHandler,
	DeleteFileHandler,
	NULL, NULL, NULL, NULL
    };
    Tcl_SetNotifier(&np);
    Tcl_CreateExitHandler(NotifierExitHandler, NULL);
}

static PyObject*
start(PyObject* unused, PyObject* args)
{
static int counter = 0;
    int *oldFramePtr;
    int done;
    int oldMode = Tcl_SetServiceMode(TCL_SERVICE_ALL);

    if (threaded && thread_id != Tcl_GetCurrentThread()) {
        PyErr_SetString(PyExc_RuntimeError,
                        "Calling Tcl from different apartment");
        return NULL;
    }

    oldFramePtr = framePtr;
    framePtr = &done;
    done = 0;

    if (threaded) {
        ENTER_TCL
        while (!done) {
fprintf(stderr, "Calling XtAppProcessEvent %d\n", counter); fflush(stderr);
            XtAppProcessEvent(notifier.appContext, XtIMAll);
fprintf(stderr, "After calling XtAppProcessEvent %d\n", counter++); fflush(stderr);
        }
        LEAVE_TCL
    }
    (void) Tcl_SetServiceMode(oldMode);
    framePtr = oldFramePtr;
    Py_INCREF(Py_None);
    return Py_None;
}

/* Callback to handle mouse clicks */
static void button_callback(Widget w, XtPointer client_data, XEvent *event, Boolean *cont) {
    if (event->type == ButtonPress) {
        printf(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Xt Button clicked!\n");
    }
}

/* Expose handler to draw the button rectangle + label */
static void expose_callback(Widget w, XtPointer client_data, XEvent *event, Boolean *cont) {
    if (event->type == Expose) {
        Display *dpy = XtDisplay(w);
        Window win = XtWindow(w);
        GC gc = XCreateGC(dpy, win, 0, NULL);

        XFontStruct *font = XLoadQueryFont(dpy, "-*-helvetica-bold-r-*-*-72-*-*-*-*-*-*-*");
        if (font) {
            XSetFont(dpy, gc, font->fid);
        }


        /* Draw rectangle */
        XDrawRectangle(dpy, win, gc, 10, 10, 380, 80);

        /* Draw centered text */
        const char *msg = "Xt window";
        int len = strlen(msg);
        int dir, asc, desc;
        XCharStruct overall;
        XTextExtents(font, msg, len, &dir, &asc, &desc, &overall);

        int x = (400 - overall.width) / 2;
	int y = (100 + asc - desc) / 2;

        XDrawString(dpy, win, gc, x, y, msg, len);

        XFreeGC(dpy, gc);
        if (font) XFreeFont(dpy, font);
    }
}

static Atom wm_delete;

static void wm_protocol_handler(Widget w, XtPointer client_data, XEvent *event, Boolean *cont) {
    if (event->type == ClientMessage) {
        if ((Atom) event->xclient.data.l[0] == wm_delete) {
            printf("WM_DELETE_WINDOW received, destroying widget...\n");
            XtDestroyWidget(w);
        }
    }
}

static void
delete_window_handler(Widget w, XtPointer client_data, XtPointer call_data)
{
    /* Perform cleanup here */
fprintf(stderr, "in delete_window_handler\n"); fflush(stderr);
    XtDestroyApplicationContext(XtWidgetToApplicationContext(w));
fprintf(stderr, "leaving delete_window_handler\n"); fflush(stderr);
    exit(0);
}

static PyObject* simple(PyObject* unused, PyObject* args) {
    Widget top, button;
    int argc = 0;
    Display *dpy = NULL;

    dpy = XOpenDisplay(NULL);
    XtDisplayInitialize(notifier.appContext, dpy, "hello", "Hello", NULL, 0, &argc, NULL);
    top = XtAppCreateShell("hello", "Hello", applicationShellWidgetClass, dpy, NULL, 0);

    /* Create a simple widget (core) to act as our button */
    button = XtVaCreateManagedWidget("button",
                                     widgetClass, top,
                                     XtNwidth, 400,
                                     XtNheight, 100,
                                     NULL);

    /* Add event handlers for drawing and clicking */
    XtAddEventHandler(button, ExposureMask, False, expose_callback, NULL);
    XtAddEventHandler(button, ButtonPressMask, False, button_callback, NULL);

    XtRealizeWidget(top);

    /* Ask window manager to send WM_DELETE_WINDOW instead of killing us */
    wm_delete = XInternAtom(XtDisplay(top), "WM_DELETE_WINDOW", False);
    XSetWMProtocols(XtDisplay(top), XtWindow(top), &wm_delete, 1);

    XtAddEventHandler(top, NoEventMask, True, wm_protocol_handler, NULL);
    XtAddCallback(top, XtNdestroyCallback, delete_window_handler, NULL);

    Py_INCREF(Py_None);
    return Py_None;
}

static struct PyMethodDef methods[] = {
    {"start",
     (PyCFunction)start,
     METH_NOARGS,
     "Starts the Tcl/Tk event loop."
    }, 
    {"simple",
     (PyCFunction)simple,
     METH_NOARGS,
     "Creates a simple X11 window using X/Xt only."
    },
    {NULL, NULL, 0, NULL} /* sentinel */
};

static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,  
    .m_name = "events_tcltk",               
    .m_doc = "events_tcltk module",        
    .m_size = -1,                     
    .m_methods = methods,
};

PyObject* PyInit_events_tcltk(void)
{
    Tcl_Interp* interpreter = Tcl_CreateInterp();
    if (interpreter == NULL) {
        PyErr_Format(PyExc_RuntimeError, "failed to create Tcl interpreter");   
        return NULL;
    }
    threaded = Tcl_GetVar2Ex(interpreter,
                             "tcl_platform",
                             "threaded",
                             TCL_GLOBAL_ONLY) != NULL;
    Tcl_DeleteInterp(interpreter);
    if (threaded) thread_id = Tcl_GetCurrentThread();
    XtToolkitInitialize();
    InitNotifier();
    notifier.appContext = XtCreateApplicationContext();
    return PyModule_Create(&moduledef);
}   
