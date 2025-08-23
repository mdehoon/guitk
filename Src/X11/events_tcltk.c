#include <Python.h>
#include <stdbool.h>
#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>
#include <X11/Shell.h>
#include <X11/Xatom.h>
#include <X11/IntrinsicP.h>
#include <X11/ConvertI.h>
#include <X11/IntrinsicI.h>
#include <X11/InitialI.h>


#include <unistd.h>  // for pipe()


#define TCL_THREADS

#include "tcl.h"
#include "tk.h"

static TimerEventRec *freeTimerRecs;
static WorkProcRec *freeWorkRecs;


#define IeCallProc(ptr) \
    (*ptr->ie_proc) (ptr->ie_closure, &ptr->ie_source, (XtInputId*)&ptr);

#define SeCallProc(ptr) \
    (*ptr->se_proc) (ptr->se_closure, (XtSignalId*)&ptr);

#define TeCallProc(ptr) \
    (*ptr->te_proc) (ptr->te_closure, (XtIntervalId*)&ptr);


/* Some systems running NTP daemons are known to return strange usec
 * values from gettimeofday.
 */

#ifndef NEEDS_NTPD_FIXUP
#if defined(sun) || defined(MOTOROLA) || (defined(__osf__) && defined(__alpha))
#define NEEDS_NTPD_FIXUP 1
#else
#define NEEDS_NTPD_FIXUP 0
#endif
#endif

#if NEEDS_NTPD_FIXUP
#define FIXUP_TIMEVAL(t) { \
        while ((t).tv_usec >= 1000000) { \
            (t).tv_usec -= 1000000; \
            (t).tv_sec++; \
        } \
        while ((t).tv_usec < 0) { \
            if ((t).tv_sec > 0) { \
                (t).tv_usec += 1000000; \
                (t).tv_sec--; \
            } else { \
                (t).tv_usec = 0; \
                break; \
            } \
        }}
#else
#define FIXUP_TIMEVAL(t)
#endif                          /*NEEDS_NTPD_FIXUP */


#define TIMEDELTA(dest, src1, src2) { \
        if(((dest).tv_usec = (src1).tv_usec - (src2).tv_usec) < 0) {\
              (dest).tv_usec += 1000000;\
              (dest).tv_sec = (src1).tv_sec - (src2).tv_sec - 1;\
        } else  (dest).tv_sec = (src1).tv_sec - (src2).tv_sec;  }

#define IS_AFTER(t1, t2) (((t2).tv_sec > (t1).tv_sec) \
        || (((t2).tv_sec == (t1).tv_sec)&& ((t2).tv_usec > (t1).tv_usec)))

#define IS_AT_OR_AFTER(t1, t2) (((t2).tv_sec > (t1).tv_sec) \
        || (((t2).tv_sec == (t1).tv_sec)&& ((t2).tv_usec >= (t1).tv_usec)))


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

typedef struct {
    struct timeval cur_time;
    struct timeval start_time;
    struct timeval wait_time;
    struct timeval new_time;
    struct timeval time_spent;
    struct timeval max_wait_time;
#ifdef USE_POLL
    int poll_wait;
#else
    struct timeval *wait_time_ptr;
#endif
} wait_times_t, *wait_times_ptr_t;

typedef struct {
#ifdef USE_POLL
    struct pollfd *fdlist;
    struct pollfd *stack;
    int fdlistlen, num_dpys;
#else
    fd_set rmask, wmask, emask;
    int nfds;
#endif
} wait_fds_t, *wait_fds_ptr_t;


void MyInitFds1(XtAppContext app, wait_fds_ptr_t wf);
void MyInitFds2(XtAppContext app, wait_fds_ptr_t wf);
void MyFindInputs1(XtAppContext app, wait_fds_ptr_t wf, int nfds _X_UNUSED, int *dpy_no, int *found_input);
void MyFindInputs2(XtAppContext app, wait_fds_ptr_t wf, int nfds _X_UNUSED, int *dpy_no, int *found_input);



static struct timeval zero_time = { 0, 0 };

static int MyIoWait(wait_times_ptr_t wt, wait_fds_ptr_t wf)
{
#ifdef USE_POLL
    return poll(wf->fdlist, (nfds_t) wf->fdlistlen, wt->poll_wait);
#else
#if !defined(WIN32) || defined(__CYGWIN__)
    return select(wf->nfds, &wf->rmask, &wf->wmask, &wf->emask, wt->wait_time_ptr);
#else
    return select(0, &wf->rmask, &wf->wmask, &wf->emask, wt->wait_time_ptr);
#endif
#endif
}

static void MyAdjustTimes(XtAppContext app, wait_times_ptr_t wt)
{
    if (app->timerQueue != NULL) {
#ifdef USE_POLL
        if (IS_AFTER(wt->cur_time, app->timerQueue->te_timer_value)) {
            TIMEDELTA(wt->wait_time, app->timerQueue->te_timer_value,
                      wt->cur_time);
            wt->poll_wait =
                (int) (wt->wait_time.tv_sec * 1000 +
                       wt->wait_time.tv_usec / 1000);
        }
        else
            wt->poll_wait = X_DONT_BLOCK;
#else
        if (IS_AFTER(wt->cur_time, app->timerQueue->te_timer_value)) {
            TIMEDELTA(wt->wait_time, app->timerQueue->te_timer_value,
                      wt->cur_time);
            wt->wait_time_ptr = &wt->wait_time;
        }
        else
            wt->wait_time_ptr = &zero_time;
#endif
    }
}

static void _MyXtWaitForSomething1(XtAppContext app)
{
    wait_times_t wt;
    wait_fds_t wf;
    int nfds, dpy_no, found_input;
    _XtBoolean drop_lock = TRUE;

#ifdef USE_POLL
    struct pollfd fdlist[XT_DEFAULT_FDLIST_SIZE];
#endif

#ifdef XTHREADS
    Boolean push_thread = TRUE;
    Boolean pushed_thread = FALSE;
    int level = 0;
    /* If not multi-threaded, never drop lock */
    if (app->lock == (ThreadAppProc) NULL)
        drop_lock = FALSE;
#endif

    wt.max_wait_time = zero_time;
#ifdef USE_POLL
    wt.poll_wait = X_DONT_BLOCK;
    wf.fdlist = NULL;
    wf.stack = fdlist;
    wf.fdlistlen = wf.num_dpys = 0;
#else
    wt.wait_time_ptr = &wt.max_wait_time;
#endif

    app->rebuild_fdlist = TRUE;

    while (1) {
        if (app->rebuild_fdlist) MyInitFds1(app, &wf);

#ifdef XTHREADS                 /* { */
        if (drop_lock) {
            YIELD_APP_LOCK(app, &push_thread, &pushed_thread, &level);
            nfds = MyIoWait(&wt, &wf);
            RESTORE_APP_LOCK(app, level, &pushed_thread);
        }
        else
#endif                          /* } */
            nfds = MyIoWait(&wt, &wf);
        if (nfds == -1) {
            /*
             *  interrupt occured recalculate time value and wait again.
             */
            if (errno == EINTR) errno = 0;
            else if (errno == EAGAIN) {
                errno = 0;
                continue;
            }
            else {
                char Errno[12];
                String param = Errno;
                Cardinal param_count = 1;

                sprintf(Errno, "%d", errno);
                XtAppWarningMsg(app, "communicationError", "select",
                                XtCXtToolkitError,
                                "Select failed; error code %s", &param,
                                &param_count);
                continue;
            }
        }                       /* timed out or input available */
        break;
    }

    if (nfds == 0) {
        /* Timed out */
#ifdef USE_POLL
        if (wf.fdlist != fdlist) free(wf.fdlist);
#endif
        return;
    }

    MyFindInputs1(app, &wf, nfds, &dpy_no, &found_input);

    if (dpy_no >= 0 || found_input) {
#ifdef USE_POLL
        if ((wf.fdlist) != fdlist) free(wf.fdlist);
#endif
        return;
    }
#ifdef USE_POLL
    if ((wf.fdlist) != fdlist) free(wf.fdlist);
#endif
    return;
}

static int _MyXtWaitForSomething2(XtAppContext app)
{
    wait_times_t wt;
    wait_fds_t wf;
    int nfds, dpy_no, found_input, dd;

#ifdef XTHREADS
    Boolean push_thread = TRUE;
    Boolean pushed_thread = FALSE;
    int level = 0;
#endif
#ifdef USE_POLL
    struct pollfd fdlist[XT_DEFAULT_FDLIST_SIZE];
#endif

    X_GETTIMEOFDAY(&wt.cur_time);
    FIXUP_TIMEVAL(&wt.cur_time);
    wt.start_time = wt.cur_time;
#ifdef USE_POLL
    wt.poll_wait = X_BLOCK;
#else
    wt.wait_time_ptr = NULL;
#endif

#ifdef USE_POLL
    wf.fdlist = NULL;
    wf.stack = fdlist;
    wf.fdlistlen = wf.num_dpys = 0;
#endif

 WaitLoop:
    app->rebuild_fdlist = TRUE;

    while (1) {
        MyAdjustTimes(app, &wt);

        if (app->block_hook_list) {
            BlockHook hook;

            for (hook = app->block_hook_list; hook != NULL; hook = hook->next)
                (*hook->proc) (hook->closure);

            /* see if the hook(s) generated any protocol */
            for (dd = 0; dd < app->count; dd++)
                if (XEventsQueued(app->list[dd], QueuedAlready)) {
#ifdef USE_POLL
                    if ((wf.fdlist) != fdlist) free(wf.fdlist);
#endif
                    return dd;
                }
        }

        if (app->rebuild_fdlist) MyInitFds2(app, &wf);

#ifdef XTHREADS                 /* { */
        YIELD_APP_LOCK(app, &push_thread, &pushed_thread, &level);
        nfds = MyIoWait(&wt, &wf);
        RESTORE_APP_LOCK(app, level, &pushed_thread);
#endif                          /* } */
        if (nfds == -1) {
            /*
             *  interrupt occured recalculate time value and wait again.
             */
            if (errno == EINTR || errno == EAGAIN) {
                if (errno == EAGAIN) {
                    errno = 0;  /* errno is not self reseting */
                    continue;
                }
                errno = 0;      /* errno is not self reseting */

                /* was it interrupted by a signal that we care about? */
                if (app->signalQueue != NULL) {
                    SignalEventRec *se_ptr = app->signalQueue;

                    while (se_ptr != NULL) {
                        if (se_ptr->se_notice) {
#ifdef USE_POLL
                            if ((wf.fdlist) != fdlist) free(wf.fdlist);
#endif
                            return -1;
                        }
                        se_ptr = se_ptr->se_next;
                    }
                }

                /* get Xlib to detect a bad connection */
                for (dd = 0; dd < app->count; dd++)
                    if (XEventsQueued(app->list[dd], QueuedAfterReading)) {
#ifdef USE_POLL
                        if ((wf.fdlist) != fdlist) free(wf.fdlist);
#endif
                        return dd;
                    }

#ifdef USE_POLL
                if (wt.poll_wait == X_BLOCK)
#else
                if (wt.wait_time_ptr == NULL)
#endif
                    continue;
                X_GETTIMEOFDAY(&wt.new_time);
                FIXUP_TIMEVAL(wt.new_time);
                TIMEDELTA(wt.time_spent, wt.new_time, wt.cur_time);
                wt.cur_time = wt.new_time;
#ifdef USE_POLL
                if ((wt.time_spent.tv_sec * 1000 +
                     wt.time_spent.tv_usec / 1000) < wt.poll_wait) {
                    wt.poll_wait -=
                        (int) (wt.time_spent.tv_sec * 1000 +
                               wt.time_spent.tv_usec / 1000);
                    continue;
                }
                else
#else
                if (IS_AFTER(wt.time_spent, *wt.wait_time_ptr)) {
                    TIMEDELTA(wt.wait_time, *wt.wait_time_ptr,
                              wt.time_spent);
                    wt.wait_time_ptr = &wt.wait_time;
                    continue;
                }
                else
#endif
                    nfds = 0;
            }
            else {
                char Errno[12];
                String param = Errno;
                Cardinal param_count = 1;

                sprintf(Errno, "%d", errno);
                XtAppWarningMsg(app, "communicationError", "select",
                                XtCXtToolkitError,
                                "Select failed; error code %s", &param,
                                &param_count);
                continue;
            }
        }                       /* timed out or input available */
        break;
    }

    if (nfds == 0) {
        /* Timed out */
#ifdef USE_POLL
        if ((wf.fdlist) != fdlist) free(wf.fdlist);
#endif
        return -1;
    }

    MyFindInputs2(app, &wf, nfds, &dpy_no, &found_input);

    if (dpy_no >= 0 || found_input) {
#ifdef USE_POLL
        if ((wf.fdlist) != fdlist) free(wf.fdlist);
#endif
        return dpy_no;
    }
    goto WaitLoop;
}



static void
_MyXtRefreshMapping(XEvent *event)
{
    XtPerDisplay pd;

    if(_XtProcessLock)(*_XtProcessLock)();
    pd = _XtGetPerDisplay(event->xmapping.display);

    if (event->xmapping.request != MappingPointer &&
        pd && pd->keysyms && (event->xmapping.serial >= pd->keysyms_serial))
        _XtBuildKeysymTables(event->xmapping.display, pd);

    XRefreshKeyboardMapping(&event->xmapping);
    if(_XtProcessUnlock)(*_XtProcessUnlock)();
}


static Widget
MyLookupSpringLoaded(XtGrabList grabList)
{
    XtGrabList gl;

    for (gl = grabList; gl != NULL; gl = gl->next) {
        if (gl->spring_loaded) {
            if (XtIsSensitive(gl->widget))
                return gl->widget;
            else
                return NULL;
        }
        if (gl->exclusive)
            break;
    }
    return NULL;
}


static Boolean
MyDispatchEvent(XEvent *event, Widget widget)
{
    if (event->type == EnterNotify &&
        event->xcrossing.mode == NotifyNormal &&
        widget->core.widget_class->core_class.compress_enterleave) {
        if (XPending(event->xcrossing.display)) {
            XEvent nextEvent;
            XPeekEvent(event->xcrossing.display, &nextEvent);

            if (nextEvent.type == LeaveNotify &&
                event->xcrossing.window == nextEvent.xcrossing.window &&
                nextEvent.xcrossing.mode == NotifyNormal &&
                ((event->xcrossing.detail != NotifyInferior &&
                  nextEvent.xcrossing.detail != NotifyInferior) ||
                 (event->xcrossing.detail == NotifyInferior &&
                  nextEvent.xcrossing.detail == NotifyInferior))) {
                /* skip the enter/leave pair */
                XNextEvent(event->xcrossing.display, &nextEvent);

                return False;
            }
        }
    }

    if (event->type == MotionNotify &&
        widget->core.widget_class->core_class.compress_motion) {
        while (XPending(event->xmotion.display)) {
            XEvent nextEvent;
            XPeekEvent(event->xmotion.display, &nextEvent);

            if (nextEvent.type == MotionNotify &&
                event->xmotion.window == nextEvent.xmotion.window &&
                event->xmotion.subwindow == nextEvent.xmotion.subwindow) {
                /* replace the current event with the next one */
                XNextEvent(event->xmotion.display, event);
            }
            else
                break;
        }
    }

    return XtDispatchEventToWidget(widget, event);
}


typedef enum _GrabType { pass, ignore, remap } GrabType;

#if !defined(AIXV3) || !defined(AIXSHLIB)
static                          /* AIX shared libraries are broken */
#endif
Boolean
_MyXtDefaultDispatcher(XEvent *event)
{
    register Widget widget;
    GrabType grabType;
    XtPerDisplayInput pdi;
    XtGrabList grabList;
    Boolean was_dispatched = False;
    DPY_TO_APPCON(event->xany.display);

    /* the default dispatcher discards all extension events */
    if (event->type >= LASTEvent)
        return False;

    LOCK_APP(app);

    switch (event->type) {
    case KeyPress:
    case KeyRelease:
    case ButtonPress:
    case ButtonRelease:
        grabType = remap;
        break;
    case MotionNotify:
    case EnterNotify:
        grabType = ignore;
        break;
    default:
        grabType = pass;
        break;
    }

    widget = XtWindowToWidget(event->xany.display, event->xany.window);
    pdi = _XtGetPerDisplayInput(event->xany.display);

    grabList = *_XtGetGrabList(pdi);

    if (widget == NULL) {
        if (grabType == remap
            && (widget = MyLookupSpringLoaded(grabList)) != NULL) {
            /* event occurred in a non-widget window, but we've promised also
               to dispatch it to the nearest accessible spring_loaded widget */
            was_dispatched = (XFilterEvent(event, XtWindow(widget))
                              || XtDispatchEventToWidget(widget, event));
        }
        else
            was_dispatched = (Boolean) XFilterEvent(event, None);
    }
    else if (grabType == pass) {
        if (event->type == LeaveNotify ||
            event->type == FocusIn || event->type == FocusOut) {
            if (XtIsSensitive(widget))
                was_dispatched = (XFilterEvent(event, XtWindow(widget)) ||
                                  XtDispatchEventToWidget(widget, event));
        }
        else
            was_dispatched = (XFilterEvent(event, XtWindow(widget)) ||
                              XtDispatchEventToWidget(widget, event));
    }
    else if (grabType == ignore) {
        if ((grabList == NULL || _XtOnGrabList(widget, grabList))
            && XtIsSensitive(widget)) {
            was_dispatched = (XFilterEvent(event, XtWindow(widget))
                              || MyDispatchEvent(event, widget));
        }
    }
    else if (grabType == remap) {
        EventMask mask = _XtConvertTypeToMask(event->type);
        Widget dspWidget;
        Boolean was_filtered = False;

        dspWidget = _XtFindRemapWidget(event, widget, mask, pdi);

        if ((grabList == NULL || _XtOnGrabList(dspWidget, grabList))
            && XtIsSensitive(dspWidget)) {
            if ((was_filtered =
                 (Boolean) XFilterEvent(event, XtWindow(dspWidget)))) {
                /* If this event activated a device grab, release it. */
                _XtUngrabBadGrabs(event, widget, mask, pdi);
                was_dispatched = True;
            }
            else
                was_dispatched = XtDispatchEventToWidget(dspWidget, event);
        }
        else
            _XtUngrabBadGrabs(event, widget, mask, pdi);

        if (!was_filtered) {
            /* Also dispatch to nearest accessible spring_loaded. */
            /* Fetch this afterward to reflect modal list changes */
            grabList = *_XtGetGrabList(pdi);
            widget = MyLookupSpringLoaded(grabList);
            if (widget != NULL && widget != dspWidget) {
                was_dispatched = (XFilterEvent(event, XtWindow(widget))
                                  || XtDispatchEventToWidget(widget, event)
                                  || was_dispatched);
            }
        }
    }
    UNLOCK_APP(app);
    return was_dispatched;
}

static Boolean
MyXtDispatchEvent(XEvent *event)
{
    Boolean was_dispatched, safe;
    int dispatch_level;
    int starting_count;
    XtPerDisplay pd;
    Time time = 0;
    XtEventDispatchProc dispatch = _MyXtDefaultDispatcher;
    XtAppContext app = XtDisplayToApplicationContext(event->xany.display);

    LOCK_APP(app);
    dispatch_level = ++app->dispatch_level;
    starting_count = app->destroy_count;

    switch (event->type) {
    case KeyPress:
    case KeyRelease:
        time = event->xkey.time;
        break;
    case ButtonPress:
    case ButtonRelease:
        time = event->xbutton.time;
        break;
    case MotionNotify:
        time = event->xmotion.time;
        break;
    case EnterNotify:
    case LeaveNotify:
        time = event->xcrossing.time;
        break;
    case PropertyNotify:
        time = event->xproperty.time;
        break;
    case SelectionClear:
        time = event->xselectionclear.time;
        break;

    case MappingNotify:
        _XtRefreshMapping(event, True);
        break;
    }
    pd = _XtGetPerDisplay(event->xany.display);

    if (time)
        pd->last_timestamp = time;
    pd->last_event = *event;

    if (pd->dispatcher_list) {
        dispatch = pd->dispatcher_list[event->type];
        if (dispatch == NULL)
            dispatch = _MyXtDefaultDispatcher;
    }
    was_dispatched = (*dispatch) (event);

    /*
     * To make recursive XtDispatchEvent work, we need to do phase 2 destroys
     * only on those widgets destroyed by this particular dispatch.
     *
     */

    if (app->destroy_count > starting_count)
        _XtDoPhase2Destroy(app, dispatch_level);

    app->dispatch_level = dispatch_level - 1;

    if ((safe = _XtSafeToDestroy(app))) {
        if (app->dpy_destroy_count != 0)
            _XtCloseDisplays(app);
        if (app->free_bindings)
            _XtDoFreeBindings(app);
    }
    UNLOCK_APP(app);
    LOCK_PROCESS;
    if (_XtAppDestroyCount != 0 && safe)
        _XtDestroyAppContexts();
    UNLOCK_PROCESS;
    return was_dispatched;
}

static Boolean
MyCallWorkProc(XtAppContext app)
{
    register WorkProcRec *w = app->workQueue;
    Boolean delete;

    if (w == NULL)
        return FALSE;

    app->workQueue = w->next;

    delete = (*(w->proc)) (w->closure);

    if (delete) {
#ifdef XTHREADS
        if(_XtProcessLock)(*_XtProcessLock)();
#endif
        w->next = freeWorkRecs;
        freeWorkRecs = w;
#ifdef XTHREADS
        if(_XtProcessUnlock)(*_XtProcessUnlock)();
#endif
    }
    else {
        w->next = app->workQueue;
        app->workQueue = w;
    }
    return TRUE;
}


static void
MyXtAppProcessEvent(XtAppContext app)
{
    int i, d;
    XEvent event;
    struct timeval cur_time;

#ifdef XTHREADS
    if(app && app->lock)(*app->lock)(app);
#endif

    for (;;) {

        if (app->signalQueue != NULL) {
            SignalEventRec *se_ptr = app->signalQueue;

            while (se_ptr != NULL) {
                if (se_ptr->se_notice) {
                    se_ptr->se_notice = FALSE;
                    SeCallProc(se_ptr);
#ifdef XTHREADS
                    if(app && app->unlock)(*app->unlock)(app);
#endif
                    return;
                }
                se_ptr = se_ptr->se_next;
            }
        }

        if (app->timerQueue != NULL) {
            X_GETTIMEOFDAY(&cur_time);
            FIXUP_TIMEVAL(cur_time);
            if (IS_AT_OR_AFTER(app->timerQueue->te_timer_value, cur_time)) {
                TimerEventRec *te_ptr = app->timerQueue;

                app->timerQueue = app->timerQueue->te_next;
                te_ptr->te_next = NULL;
                if (te_ptr->te_proc != NULL)
                    TeCallProc(te_ptr);
#ifdef XTHREADS
                if(_XtProcessLock)(*_XtProcessLock)();
#endif
                te_ptr->te_next = freeTimerRecs;
                freeTimerRecs = te_ptr;
#ifdef XTHREADS
                if(_XtProcessUnlock)(*_XtProcessUnlock)();
                if(app && app->unlock)(*app->unlock)(app);
#endif
                return;
            }
        }

        if (app->input_count > 0 && app->outstandingQueue == NULL) {
            /* Call _XtWaitForSomething to get input queued up */
            _MyXtWaitForSomething1(app);
        }
        if (app->outstandingQueue != NULL) {
            InputEvent *ie_ptr = app->outstandingQueue;

            app->outstandingQueue = ie_ptr->ie_oq;
            ie_ptr->ie_oq = NULL;
            IeCallProc(ie_ptr);
#ifdef XTHREADS
            if(app && app->unlock)(*app->unlock)(app);
#endif
            return;
        }

        for (i = 1; i <= app->count; i++) {
            d = (i + app->last) % app->count;
            if (XEventsQueued(app->list[d], QueuedAfterReading))
                goto GotEvent;
        }
        for (i = 1; i <= app->count; i++) {
            d = (i + app->last) % app->count;
            if (XEventsQueued(app->list[d], QueuedAfterFlush))
                goto GotEvent;
        }

        /* Nothing to do...wait for something */

        if (MyCallWorkProc(app))
            continue;

        d = _MyXtWaitForSomething2(app);
        if (d != -1) {
 GotEvent:
            XNextEvent(app->list[d], &event);
            app->last = (short) d;
            if (event.xany.type == MappingNotify) {
                _MyXtRefreshMapping(&event);
            }
            MyXtDispatchEvent(&event);
#ifdef XTHREADS
            if(app && app->unlock)(*app->unlock)(app);
#endif
            return;
        }

    }
}

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
    if (timePtr) {
	timeout = timePtr->sec * 1000 + timePtr->usec / 1000;
	if (timeout == 0) {
	    if (XtAppPending(notifier.appContext)) {
		goto process;
	    } else {
		return 0;
	    }
	} else {
	    Tcl_SetTimer(timePtr);
	}
    }

  process:
    MyXtAppProcessEvent(notifier.appContext);
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

    if (!(flags & TCL_FILE_EVENTS)) {
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
	    filePtr->proc(filePtr->clientData, mask);
	}
	break;
    }
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
            MyXtAppProcessEvent(notifier.appContext);
        }
        LEAVE_TCL
    }
    (void) Tcl_SetServiceMode(oldMode);
    framePtr = oldFramePtr;
    Py_INCREF(Py_None);
    return Py_None;
}

/* Callback to handle mouse clicks */
static void button_callback1(Widget w, XtPointer client_data, XEvent *event, Boolean *cont) {
    if (event->type == ButtonPress) {
        printf("Xt button clicked\n");
    }
}

static void timer_proc (XtPointer client_data, XtIntervalId *timer)
{
    static int counter = 0;
    printf("Xt timer update %d\n", counter++);
    XtAppAddTimeOut(notifier.appContext, 1500, timer_proc, NULL);
}

static int pipefds[2];

static void pipe_proc (XtPointer client_data, int *source, XtInputId *id)
{
    char c;
    int n;
    printf("Xt file descriptor triggered\n");
    n = read(pipefds[0], &c, 1);
    if (n != 1) {
        fprintf(stderr, "**** FAILED TO READ DATA\n");
        fflush(stderr);
    }
}

static void button_callback2(Widget w, XtPointer client_data, XEvent *event, Boolean *cont) {
    if (event->type == ButtonPress) {
        char c = '\n';
        int n = write(pipefds[1], &c, 1);
        if (n != 1) {
            fprintf(stderr, "**** FAILED TO READ DATA\n");
            fflush(stderr);
        }
    }
}

static void button_callback3(Widget w, XtPointer client_data, XEvent *event, Boolean *cont) {
    if (event->type == ButtonPress) {
        XtAppAddTimeOut(notifier.appContext, 1500, timer_proc, NULL);
    }
}

/* Expose handler to draw the button rectangle + label */
static void expose_callback(Widget w, XtPointer client_data, XEvent *event, Boolean *cont) {
    if (event->type == Expose) {
        Display *dpy = XtDisplay(w);
        Window win = XtWindow(w);
        GC gc = XCreateGC(dpy, win, 0, NULL);

        XFontStruct *font = XLoadQueryFont(dpy, "-*-helvetica-bold-r-*-*-48-*-*-*-*-*-*-*");
        if (font) XSetFont(dpy, gc, font->fid);
        const char *msg = "Xt";
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

/* Expose handler to draw the button rectangle + label */
static void expose_callback1(Widget w, XtPointer client_data, XEvent *event, Boolean *cont) {
    if (event->type == Expose) {
        Display *dpy = XtDisplay(w);
        Window win = XtWindow(w);
        GC gc = XCreateGC(dpy, win, 0, NULL);

        XFontStruct *font = XLoadQueryFont(dpy, "-*-helvetica-bold-r-*-*-32-*-*-*-*-*-*-*");
        if (font) XSetFont(dpy, gc, font->fid);
        XDrawRectangle(dpy, win, gc, 10, 10, 380, 80);
        const char *msg = "Click me";
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

static void expose_callback2(Widget w, XtPointer client_data, XEvent *event, Boolean *cont) {
    if (event->type == Expose) {
        Display *dpy = XtDisplay(w);
        Window win = XtWindow(w);
        GC gc = XCreateGC(dpy, win, 0, NULL);

        XFontStruct *font = XLoadQueryFont(dpy, "-*-helvetica-bold-r-*-*-32-*-*-*-*-*-*-*");
        if (font) XSetFont(dpy, gc, font->fid);
        XDrawRectangle(dpy, win, gc, 10, 10, 380, 80);
        const char *msg = "Trigger file descriptor";
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

static void expose_callback3(Widget w, XtPointer client_data, XEvent *event, Boolean *cont) {
    if (event->type == Expose) {
        Display *dpy = XtDisplay(w);
        Window win = XtWindow(w);
        GC gc = XCreateGC(dpy, win, 0, NULL);

        XFontStruct *font = XLoadQueryFont(dpy, "-*-helvetica-bold-r-*-*-32-*-*-*-*-*-*-*");
        if (font) XSetFont(dpy, gc, font->fid);
        XDrawRectangle(dpy, win, gc, 10, 10, 380, 80);
        const char *msg = "Start timer";
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
    XtDestroyApplicationContext(XtWidgetToApplicationContext(w));
    exit(0);
}

static PyObject* simple(PyObject* unused, PyObject* args) {
    Widget top, container, label, button1, button2, button3;
    int argc = 0;
    Display *dpy = NULL;

    int result = pipe(pipefds);
    if (result == -1) {
        PyErr_Format(PyExc_RuntimeError,
                     "failed to create pipe (errno %d)", errno);
        return NULL;
    }

    dpy = XOpenDisplay(NULL);
    XtDisplayInitialize(notifier.appContext, dpy, "hello", "Hello", NULL, 0, &argc, NULL);
    top = XtAppCreateShell("hello", "Hello", applicationShellWidgetClass, dpy, NULL, 0);

    container = XtVaCreateManagedWidget("container",
                                        compositeWidgetClass,
                                        top,
                                        XtNwidth, 400,
                                        XtNheight, 400,
                                        NULL);

    /* Create a simple widget (core) to act as our button */
    label = XtVaCreateManagedWidget("label",
                                    widgetClass, container,
                                    XtNwidth, 400,
                                    XtNheight, 100,
                                    XtNx, 0,
                                    XtNy, 0,
                                    NULL);

    XtAddEventHandler(label, ExposureMask, False, expose_callback, NULL);

    /* Create a simple widget (core) to act as our button */
    button1 = XtVaCreateManagedWidget("button",
                                      widgetClass, container,
                                      XtNwidth, 400,
                                      XtNheight, 100,
                                      XtNx, 0,
                                      XtNy, 100,
                                      NULL);

    /* Add event handlers for drawing and clicking */
    XtAddEventHandler(button1, ExposureMask, False, expose_callback1, NULL);
    XtAddEventHandler(button1, ButtonPressMask, False, button_callback1, NULL);

    /* Create a simple widget (core) to act as our button */
    button2 = XtVaCreateManagedWidget("button",
                                     widgetClass, container,
                                     XtNwidth, 400,
                                     XtNheight, 100,
                                     XtNx, 0,
                                     XtNy, 200,
                                     NULL);

    /* Add event handlers for drawing and clicking */
    XtAddEventHandler(button2, ExposureMask, False, expose_callback2, NULL);
    XtAddEventHandler(button2, ButtonPressMask, False, button_callback2, NULL);
    XtAppAddInput(notifier.appContext, pipefds[0], (XtPointer)XtInputReadMask, pipe_proc, NULL);

    /* Create a simple widget (core) to act as our button */
    button3 = XtVaCreateManagedWidget("button",
                                     widgetClass, container,
                                     XtNwidth, 400,
                                     XtNheight, 100,
                                     XtNx, 0,
                                     XtNy, 300,
                                     NULL);

    /* Add event handlers for drawing and clicking */
    XtAddEventHandler(button3, ExposureMask, False, expose_callback3, NULL);
    XtAddEventHandler(button3, ButtonPressMask, False, button_callback3, NULL);

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
