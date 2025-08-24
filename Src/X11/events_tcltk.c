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

#define ADD_TIME(dest, src1, src2) { \
        if(((dest).tv_usec = (src1).tv_usec + (src2).tv_usec) >= 1000000) {\
              (dest).tv_usec -= 1000000;\
              (dest).tv_sec = (src1).tv_sec + (src2).tv_sec + 1 ; \
        } else { (dest).tv_sec = (src1).tv_sec + (src2).tv_sec ; \
           if(((dest).tv_sec >= 1) && (((dest).tv_usec <0))) { \
            (dest).tv_sec --;(dest).tv_usec += 1000000; } } }


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


static struct timeval zero_time = { 0, 0 };

static XtInputId
MyXtAppAddInput(XtAppContext app,
              int source,
              XtPointer Condition,
              XtInputCallbackProc proc,
              XtPointer closure)
{
    InputEvent *sptr;
    XtInputMask condition = (XtInputMask) Condition;

    LOCK_APP(app);
    if (!condition ||
        condition & (unsigned
                     long) (~(XtInputReadMask | XtInputWriteMask |
                              XtInputExceptMask)))
        XtAppErrorMsg(app, "invalidParameter", "xtAddInput", XtCXtToolkitError,
                      "invalid condition passed to XtAppAddInput", NULL, NULL);

    if (app->input_max <= source) {
        Cardinal n = (Cardinal) (source + 1);
        int ii;

        app->input_list = (InputEvent **) XtRealloc((char *) app->input_list,
                                                    (Cardinal) ((size_t) n *
                                                                sizeof
                                                                (InputEvent
                                                                 *)));
        for (ii = app->input_max; ii < (int) n; ii++)
            app->input_list[ii] = (InputEvent *) NULL;
        app->input_max = (short) n;
    }
    sptr = XtNew(InputEvent);

    sptr->ie_proc = proc;
    sptr->ie_closure = closure;
    sptr->app = app;
    sptr->ie_oq = NULL;
    sptr->ie_source = source;
    sptr->ie_condition = condition;
    sptr->ie_next = app->input_list[source];
    app->input_list[source] = sptr;

#ifdef USE_POLL
    if (sptr->ie_next == NULL)
        app->fds.nfds++;
#else
    if (condition & XtInputReadMask)
        FD_SET(source, &app->fds.rmask);
    if (condition & XtInputWriteMask)
        FD_SET(source, &app->fds.wmask);
    if (condition & XtInputExceptMask)
        FD_SET(source, &app->fds.emask);

    if (app->fds.nfds < (source + 1))
        app->fds.nfds = source + 1;
#endif
    app->input_count++;
    app->rebuild_fdlist = TRUE;
    UNLOCK_APP(app);
    return ((XtInputId) sptr);
}

static void
MyQueueTimerEvent(XtAppContext app, TimerEventRec *ptr)
{
    TimerEventRec *t, **tt;

    tt = &app->timerQueue;
    t = *tt;
    while (t != NULL && IS_AFTER(t->te_timer_value, ptr->te_timer_value)) {
        tt = &t->te_next;
        t = *tt;
    }
    ptr->te_next = t;
    *tt = ptr;
}

static XtIntervalId MyXtAppAddTimeOut(XtAppContext app, unsigned long interval, XtTimerCallbackProc proc, XtPointer closure)
{
    TimerEventRec *tptr;
    struct timeval current_time;

    LOCK_APP(app);
    LOCK_PROCESS;
    if (freeTimerRecs) {
        tptr = freeTimerRecs;
        freeTimerRecs = tptr->te_next;
    }
    else
        tptr = XtNew(TimerEventRec);

    UNLOCK_PROCESS;
    tptr->te_next = NULL;
    tptr->te_closure = closure;
    tptr->te_proc = proc;
    tptr->app = app;
    tptr->te_timer_value.tv_sec = (time_t) (interval / 1000);
    tptr->te_timer_value.tv_usec = (suseconds_t) ((interval % 1000) * 1000);
    X_GETTIMEOFDAY(&current_time);
    FIXUP_TIMEVAL(current_time);
    ADD_TIME(tptr->te_timer_value, tptr->te_timer_value, current_time);
    MyQueueTimerEvent(app, tptr);
    UNLOCK_APP(app);

    return ((XtIntervalId) tptr);
}

static void MyXtRemoveTimeOut(XtIntervalId id)
{
    TimerEventRec *t, *last, *tid = (TimerEventRec *) id;
    XtAppContext app = tid->app;

    /* find it */
    LOCK_APP(app);
    for (t = app->timerQueue, last = NULL;
         t != NULL && t != tid; t = t->te_next)
        last = t;

    if (t == NULL) {
        UNLOCK_APP(app);
        return;                 /* couldn't find it */
    }
    if (last == NULL) {         /* first one on the list */
        app->timerQueue = t->te_next;
    }
    else
        last->te_next = t->te_next;

    LOCK_PROCESS;
    t->te_next = freeTimerRecs;
    freeTimerRecs = t;
    UNLOCK_PROCESS;
    UNLOCK_APP(app);
}


static void MyFindInputs1(XtAppContext app, wait_fds_ptr_t wf, int nfds _X_UNUSED, int *dpy_no, int *found_input)
{
    InputEvent *ep;
    int ii;

#ifdef USE_POLL                 /* { check ready file descriptors block */
    struct pollfd *fdlp;

    *dpy_no = -1;
    *found_input = False;

    fdlp = &wf->fdlist[wf->num_dpys];
    for (ii = wf->num_dpys; ii < wf->fdlistlen; ii++, fdlp++) {
        XtInputMask condition = 0;

        if (fdlp->revents) {
            if (fdlp->revents & (XPOLL_READ | POLLHUP | POLLERR)
#ifdef XTHREADS
                && !(fdlp->revents & POLLNVAL)
#endif
                )
                condition = XtInputReadMask;
            if (fdlp->revents & XPOLL_WRITE)
                condition |= XtInputWriteMask;
            if (fdlp->revents & XPOLL_EXCEPT)
                condition |= XtInputExceptMask;
        }
        if (condition) {
            *found_input = True;
            for (ep = app->input_list[fdlp->fd]; ep; ep = ep->ie_next)
                if (condition & ep->ie_condition) {
                    InputEvent *oq;

                    /* make sure this input isn't already marked outstanding */
                    for (oq = app->outstandingQueue; oq; oq = oq->ie_oq)
                        if (oq == ep)
                            break;
                    if (!oq) {
                        ep->ie_oq = app->outstandingQueue;
                        app->outstandingQueue = ep;
                    }
                }
            }
        }
#else                           /* }{ */
#ifdef XTHREADS
    fd_set rmask;
#endif
    int dd;

    *dpy_no = -1;
    *found_input = False;

#ifdef XTHREADS
    rmask = app->fds.rmask;
    for (dd = app->count; dd-- > 0;)
        FD_SET(ConnectionNumber(app->list[dd]), &rmask);
#endif

    for (ii = 0; ii < wf->nfds && nfds > 0; ii++) {
        XtInputMask condition = 0;

        if (FD_ISSET(ii, &wf->rmask)
#ifdef XTHREADS
            && FD_ISSET(ii, &rmask)
#endif
            ) {
            nfds--;
            condition = XtInputReadMask;
        }
        if (FD_ISSET(ii, &wf->wmask)
#ifdef XTHREADS
            && FD_ISSET(ii, &app->fds.wmask)
#endif
            ) {
            condition |= XtInputWriteMask;
            nfds--;
        }
        if (FD_ISSET(ii, &wf->emask)
#ifdef XTHREADS
            && FD_ISSET(ii, &app->fds.emask)
#endif
            ) {
            condition |= XtInputExceptMask;
            nfds--;
        }
        if (condition) {
            for (ep = app->input_list[ii]; ep; ep = ep->ie_next)
                if (condition & ep->ie_condition) {
                    /* make sure this input isn't already marked outstanding */
                    InputEvent *oq;

                    for (oq = app->outstandingQueue; oq; oq = oq->ie_oq)
                        if (oq == ep)
                            break;
                    if (!oq) {
                        ep->ie_oq = app->outstandingQueue;
                        app->outstandingQueue = ep;
                    }
                }
            *found_input = True;
        }
    }                           /* endfor */
#endif                          /* } */
}

static void MyFindInputs2(XtAppContext app, wait_fds_ptr_t wf, int nfds _X_UNUSED, int *dpy_no, int *found_input)
{
    InputEvent *ep;
    int ii;

#ifdef USE_POLL                 /* { check ready file descriptors block */
    struct pollfd *fdlp;

    *dpy_no = -1;
    *found_input = False;

    fdlp = wf->fdlist;
    for (ii = 0; ii < wf->num_dpys; ii++, fdlp++) {
        if (*dpy_no == -1 && fdlp->revents & (POLLIN | POLLHUP | POLLERR) &&
#ifdef XTHREADS
            !(fdlp->revents & POLLNVAL) &&
#endif
            XEventsQueued(app->list[ii], QueuedAfterReading)) {
            *dpy_no = ii;
            break;
        }
    }

    fdlp = &wf->fdlist[wf->num_dpys];
    for (ii = wf->num_dpys; ii < wf->fdlistlen; ii++, fdlp++) {
        XtInputMask condition = 0;

        if (fdlp->revents) {
            if (fdlp->revents & (XPOLL_READ | POLLHUP | POLLERR)
#ifdef XTHREADS
                && !(fdlp->revents & POLLNVAL)
#endif
                )
                condition = XtInputReadMask;
            if (fdlp->revents & XPOLL_WRITE)
                condition |= XtInputWriteMask;
            if (fdlp->revents & XPOLL_EXCEPT)
                condition |= XtInputExceptMask;
        }
        if (condition) {
            *found_input = True;
            for (ep = app->input_list[fdlp->fd]; ep; ep = ep->ie_next)
                if (condition & ep->ie_condition) {
                    InputEvent *oq;

                    /* make sure this input isn't already marked outstanding */
                    for (oq = app->outstandingQueue; oq; oq = oq->ie_oq)
                        if (oq == ep)
                            break;
                    if (!oq) {
                        ep->ie_oq = app->outstandingQueue;
                        app->outstandingQueue = ep;
                    }
                }
            }
    }
#else                           /* }{ */
#ifdef XTHREADS
    fd_set rmask;
#endif
    int dd;

    *dpy_no = -1;
    *found_input = False;

#ifdef XTHREADS
    rmask = app->fds.rmask;
    for (dd = app->count; dd-- > 0;)
        FD_SET(ConnectionNumber(app->list[dd]), &rmask);
#endif

    for (ii = 0; ii < wf->nfds && nfds > 0; ii++) {
        XtInputMask condition = 0;

        if (FD_ISSET(ii, &wf->rmask)
#ifdef XTHREADS
            && FD_ISSET(ii, &rmask)
#endif
            ) {
            nfds--;
            for (dd = 0; dd < app->count; dd++) {
                if (ii == ConnectionNumber(app->list[dd])) {
                    if (*dpy_no == -1) {
                        if (XEventsQueued
                            (app->list[dd], QueuedAfterReading))
                            *dpy_no = dd;
                        /*
                         * An error event could have arrived
                         * without any real events, or events
                         * could have been swallowed by Xlib,
                         * or the connection may be broken.
                         * We can't tell the difference, so
                         * assume Xlib will eventually discover
                         * a broken connection.
                         */
                    }
                    goto ENDILOOP;
                }
            }
            condition = XtInputReadMask;
        }
        if (FD_ISSET(ii, &wf->wmask)
#ifdef XTHREADS
            && FD_ISSET(ii, &app->fds.wmask)
#endif
            ) {
            condition |= XtInputWriteMask;
            nfds--;
        }
        if (FD_ISSET(ii, &wf->emask)
#ifdef XTHREADS
            && FD_ISSET(ii, &app->fds.emask)
#endif
            ) {
            condition |= XtInputExceptMask;
            nfds--;
        }
        if (condition) {
            for (ep = app->input_list[ii]; ep; ep = ep->ie_next)
                if (condition & ep->ie_condition) {
                    /* make sure this input isn't already marked outstanding */
                    InputEvent *oq;

                    for (oq = app->outstandingQueue; oq; oq = oq->ie_oq)
                        if (oq == ep)
                            break;
                    if (!oq) {
                        ep->ie_oq = app->outstandingQueue;
                        app->outstandingQueue = ep;
                    }
                }
            *found_input = True;
        }
 ENDILOOP:;
    }                           /* endfor */
#endif                          /* } */
}

static int MyInitFds1(XtAppContext app, wait_fds_ptr_t wf)
{
#ifdef USE_POLL
    size_t n;
    PyGILState_STATE gstate;
#endif
    app->rebuild_fdlist = FALSE;
#ifdef USE_POLL
#ifndef POLLRDNORM
#define POLLRDNORM 0
#endif

#ifndef POLLRDBAND
#define POLLRDBAND 0
#endif

#ifndef POLLWRNORM
#define POLLWRNORM 0
#endif

#ifndef POLLWRBAND
#define POLLWRBAND 0
#endif

#define XPOLL_READ (POLLIN|POLLRDNORM|POLLPRI|POLLRDBAND)
#define XPOLL_WRITE (POLLOUT|POLLWRNORM|POLLWRBAND)
#define XPOLL_EXCEPT 0

    wf->fdlistlen = wf->num_dpys = 0;

    if (app->input_list != NULL) {
        for (ii = 0; ii < (int) app->input_max; ii++)
            if (app->input_list[ii] != NULL)
                wf->fdlistlen++;
    }

    n = sizeof(struct pollfd) * (size_t) wf->fdlistlen;
    gstate = PyGILState_Ensure();
    if (!wf->fdlist || wf->fdlist == wf->stack) {
        if (n <= sizeof(wf->stack))
            wf->fdlist = wf->stack;
        else {
            wf->fdlist = PyMem_Malloc(n);
        }
    }
    else {
       if (wf->fdlist == NULL) {
           wf->fdlist = PyMem_Malloc(n);
       } else {
           wf->fdlist = PyMem_Realloc(n);
       }
    }
    if (wf->fdlist == NULL) {
        PyErr_Print();
        PyGILState_Release(gstate);
        return -1;
    }
    PyGILState_Release(gstate);

    if (wf->fdlistlen) {
        struct pollfd *fdlp = wf->fdlist;
        InputEvent *iep;

        if (app->input_list != NULL)
            for (ii = 0; ii < app->input_max; ii++)
                if (app->input_list[ii] != NULL) {
                    iep = app->input_list[ii];
                    fdlp->fd = ii;
                    fdlp->events = 0;
                    for (; iep; iep = iep->ie_next) {
                        if (iep->ie_condition & XtInputReadMask)
                            fdlp->events |= XPOLL_READ;
                        if (iep->ie_condition & XtInputWriteMask)
                            fdlp->events |= XPOLL_WRITE;
                        if (iep->ie_condition & XtInputExceptMask)
                            fdlp->events |= XPOLL_EXCEPT;
                    }
                    fdlp++;
                }
    }
#else
    wf->nfds = app->fds.nfds;
    wf->rmask = app->fds.rmask;
    wf->wmask = app->fds.wmask;
    wf->emask = app->fds.emask;
#endif
    return 0;
}

static void MyInitFds2(XtAppContext app, wait_fds_ptr_t wf)
{
    int ii;

    app->rebuild_fdlist = FALSE;
#ifdef USE_POLL
#ifndef POLLRDNORM
#define POLLRDNORM 0
#endif

#ifndef POLLRDBAND
#define POLLRDBAND 0
#endif

#ifndef POLLWRNORM
#define POLLWRNORM 0
#endif

#ifndef POLLWRBAND
#define POLLWRBAND 0
#endif

#define XPOLL_READ (POLLIN|POLLRDNORM|POLLPRI|POLLRDBAND)
#define XPOLL_WRITE (POLLOUT|POLLWRNORM|POLLWRBAND)
#define XPOLL_EXCEPT 0

    wf->fdlistlen = wf->num_dpys = app->count;

    if (app->input_list != NULL) {
        for (ii = 0; ii < (int) app->input_max; ii++)
            if (app->input_list[ii] != NULL)
                wf->fdlistlen++;
    }

    if (!wf->fdlist || wf->fdlist == wf->stack) {
        if ((sizeof(struct pollfd) * (size_t) wf->fdlistlen) <= sizeof(wf->stack))
            wf->fdlist = wf->stack;
        else {
            wf->fdlist = malloc(sizeof(struct pollfd) * (size_t) wf->fdlistlen);
            if (wf->fdlist == NULL) _XtAllocError("malloc");
        }
    }
    else {
       if (wf->fdlist == NULL) {
           wf->fdlist = malloc(sizeof(struct pollfd) *(size_t) wf->fdlistlen);
           if (wf->fdlist == NULL) _XtAllocError("malloc");
       } else {
           wf->fdlist = realloc(wf->fdlist, sizeof(struct pollfd) *(size_t) wf->fdlistlen);
           if (wf->fdlist == NULL) _XtAllocError("realloc");
       }
    }

    if (wf->fdlistlen) {
        struct pollfd *fdlp = wf->fdlist;
        InputEvent *iep;

        for (ii = 0; ii < wf->num_dpys; ii++, fdlp++) {
            fdlp->fd = ConnectionNumber(app->list[ii]);
            fdlp->events = POLLIN;
        }
        if (app->input_list != NULL)
            for (ii = 0; ii < app->input_max; ii++)
                if (app->input_list[ii] != NULL) {
                    iep = app->input_list[ii];
                    fdlp->fd = ii;
                    fdlp->events = 0;
                    for (; iep; iep = iep->ie_next) {
                        if (iep->ie_condition & XtInputReadMask)
                            fdlp->events |= XPOLL_READ;
                        if (iep->ie_condition & XtInputWriteMask)
                            fdlp->events |= XPOLL_WRITE;
                        if (iep->ie_condition & XtInputExceptMask)
                            fdlp->events |= XPOLL_EXCEPT;
                    }
                    fdlp++;
                }
    }
#else
    wf->nfds = app->fds.nfds;
    wf->rmask = app->fds.rmask;
    wf->wmask = app->fds.wmask;
    wf->emask = app->fds.emask;

    for (ii = 0; ii < app->count; ii++) {
        FD_SET(ConnectionNumber(app->list[ii]), &wf->rmask);
    }
#endif
}

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
_MyXtBuildKeysymTables(Display *dpy, register XtPerDisplay pd)
{
    ModToKeysymTable *table;
    int maxCount, i, j, k, tempCount, idx;
    KeySym keysym, tempKeysym;
    XModifierKeymap *modKeymap;
    KeyCode keycode;

#define KeysymTableSize 16
#define FLUSHKEYCACHE(ctx) \
        memset((void *)&ctx->keycache, 0, sizeof(TMKeyCache))

    FLUSHKEYCACHE(pd->tm_context);

    XFree((char *) pd->keysyms);
    pd->keysyms_serial = NextRequest(dpy);
    pd->keysyms = XGetKeyboardMapping(dpy, (KeyCode) pd->min_keycode,
                                      pd->max_keycode - pd->min_keycode + 1,
                                      &pd->keysyms_per_keycode);
    XtFree((char *) pd->modKeysyms);

    pd->modKeysyms =
        (KeySym *) __XtMalloc((Cardinal) KeysymTableSize * sizeof(KeySym));
    maxCount = KeysymTableSize;
    tempCount = 0;

    XtFree((char *) pd->modsToKeysyms);
    table =
        (ModToKeysymTable *) __XtMalloc((Cardinal) 8 *
                                        sizeof(ModToKeysymTable));
    pd->modsToKeysyms = table;

    table[0].mask = ShiftMask;
    table[1].mask = LockMask;
    table[2].mask = ControlMask;
    table[3].mask = Mod1Mask;
    table[4].mask = Mod2Mask;
    table[5].mask = Mod3Mask;
    table[6].mask = Mod4Mask;
    table[7].mask = Mod5Mask;
    tempKeysym = 0;

    modKeymap = XGetModifierMapping(dpy);
    for (i = 0; i < 32; i++)
        pd->isModifier[i] = 0;
    pd->mode_switch = 0;
    pd->num_lock = 0;
    for (i = 0; i < 8; i++) {
        table[i].idx = tempCount;
        table[i].count = 0;
        for (j = 0; j < modKeymap->max_keypermod; j++) {
            keycode = modKeymap->modifiermap[i * modKeymap->max_keypermod + j];
            if (keycode != 0) {
                pd->isModifier[keycode >> 3] |=
                    (unsigned char) (1 << (keycode & 7));
                for (k = 0; k < pd->keysyms_per_keycode; k++) {
                    idx = ((keycode - pd->min_keycode) *
                           pd->keysyms_per_keycode) + k;
                    keysym = pd->keysyms[idx];
                    if ((keysym == XK_Mode_switch) && (i > 2))
                        pd->mode_switch =
                            (pd->mode_switch | (Modifiers) (1 << i));
                    if ((keysym == XK_Num_Lock) && (i > 2))
                        pd->num_lock = (pd->num_lock | (Modifiers) (1 << i));
                    if (keysym != 0 && keysym != tempKeysym) {
                        if (tempCount == maxCount) {
                            maxCount += KeysymTableSize;
                            pd->modKeysyms = (KeySym *) XtRealloc((char *) pd->
                                                                  modKeysyms,
                                                                  (unsigned) ((size_t) maxCount * sizeof(KeySym)));
                        }
                        pd->modKeysyms[tempCount++] = keysym;
                        table[i].count++;
                        tempKeysym = keysym;
                    }
                }
            }
        }
    }
    pd->lock_meaning = NoSymbol;
    for (i = 0; i < table[1].count; i++) {
        keysym = pd->modKeysyms[table[1].idx + i];
        if (keysym == XK_Caps_Lock) {
            pd->lock_meaning = XK_Caps_Lock;
            break;
        }
        else if (keysym == XK_Shift_Lock) {
            pd->lock_meaning = XK_Shift_Lock;
        }
    }
    XFreeModifiermap(modKeymap);
}


static void
_MyXtRefreshMapping(XEvent *event)
{
    XtPerDisplay pd;

    if(_XtProcessLock)(*_XtProcessLock)();
    pd = _XtGetPerDisplay(event->xmapping.display);

    if (event->xmapping.request != MappingPointer &&
        pd && pd->keysyms && (event->xmapping.serial >= pd->keysyms_serial))
        _MyXtBuildKeysymTables(event->xmapping.display, pd);

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

/* keep this SMALL to avoid blowing stack cache! */
/* because some compilers allocate all local locals on procedure entry */
#define EHSIZE 4

#define KnownButtons (Button1MotionMask|Button2MotionMask|Button3MotionMask|\
                      Button4MotionMask|Button5MotionMask)

#define COMP_EXPOSE   (widget->core.widget_class->core_class.compress_exposure)
#define COMP_EXPOSE_TYPE (COMP_EXPOSE & 0x0f)
#define GRAPHICS_EXPOSE  ((XtExposeGraphicsExpose & COMP_EXPOSE) || \
                          (XtExposeGraphicsExposeMerged & COMP_EXPOSE))
#define NO_EXPOSE        (XtExposeNoExpose & COMP_EXPOSE)

#define GetCount(ev) (((XExposeEvent *)(ev))->count)


#ifndef MAX
#define MAX(a,b) (((a) > (b)) ? (a) : (b))
#endif

#ifndef MIN
#define MIN(a,b) (((a) < (b)) ? (a) : (b))
#endif



typedef struct _CheckExposeInfo {
    int type1, type2;           /* Types of events to check for. */
    Boolean maximal;            /* Ignore non-exposure events? */
    Boolean non_matching;       /* Was there an event that did not
                                   match either type? */
    Window window;              /* Window to match. */
} CheckExposeInfo;

static void
MyAddExposureToRectangularRegion(XEvent *event,   /* when called internally, type is always appropriate */
                               Region region)
{
    XRectangle rect;
    XExposeEvent *ev = (XExposeEvent *) event;

    /* These Expose and GraphicsExpose fields are at identical offsets */

    rect.x = (Position) ev->x;
    rect.y = (Position) ev->y;
    rect.width = (Dimension) ev->width;
    rect.height = (Dimension) ev->height;

    if (XEmptyRegion(region)) {
        XUnionRectWithRegion(&rect, region, region);
    }
    else {
        XRectangle merged, bbox;

        XClipBox(region, &bbox);
        merged.x = MIN(rect.x, bbox.x);
        merged.y = MIN(rect.y, bbox.y);
        merged.width = (unsigned short) (MAX(rect.x + rect.width,
                                             bbox.x + bbox.width) - merged.x);
        merged.height = (unsigned short) (MAX(rect.y + rect.height,
                                              bbox.y + bbox.height) - merged.y);
        XUnionRectWithRegion(&merged, region, region);
    }
}

static Region nullRegion;

static void
MySendExposureEvent(XEvent *event, Widget widget, XtPerDisplay pd)
{   
    XtExposeProc expose;
    XRectangle rect;
    XtEnum comp_expose;
    XExposeEvent *ev = (XExposeEvent *) event;
        
    XClipBox(pd->region, &rect);
    ev->x = rect.x;
    ev->y = rect.y;
    ev->width = rect.width;
    ev->height = rect.height;

    LOCK_PROCESS;
    comp_expose = COMP_EXPOSE;
    expose = widget->core.widget_class->core_class.expose;
    UNLOCK_PROCESS;
    if (comp_expose & XtExposeNoRegion)
        (*expose) (widget, event, NULL);
    else
        (*expose) (widget, event, pd->region);
    (void) XIntersectRegion(nullRegion, pd->region, pd->region);
}

static Bool     
MyCheckExposureEvent(Display *disp _X_UNUSED, XEvent *event, char *arg)
{
    CheckExposeInfo *info = ((CheckExposeInfo *) arg);

    if ((info->type1 == event->type) || (info->type2 == event->type)) {
        if (!info->maximal && info->non_matching)
            return FALSE;
        if (event->type == GraphicsExpose)
            return (event->xgraphicsexpose.drawable == info->window);
        return (event->xexpose.window == info->window);
    }
    info->non_matching = TRUE;
    return (FALSE);
}

static void
MyCompressExposures(XEvent *event, Widget widget)
{
    CheckExposeInfo info;
    int count;
    Display *dpy = XtDisplay(widget);
    XtPerDisplay pd = _XtGetPerDisplay(dpy);
    XtEnum comp_expose;
    XtEnum comp_expose_type;
    Boolean no_region;

    LOCK_PROCESS;
    comp_expose = COMP_EXPOSE;
    UNLOCK_PROCESS;
    comp_expose_type = comp_expose & 0x0f;
    no_region = ((comp_expose & XtExposeNoRegion) ? True : False);

    if (no_region)
        MyAddExposureToRectangularRegion(event, pd->region);
    else
        XtAddExposureToRegion(event, pd->region);

    if (GetCount(event) != 0)
        return;

    if ((comp_expose_type == XtExposeCompressSeries) ||
        (XEventsQueued(dpy, QueuedAfterReading) == 0)) {
        MySendExposureEvent(event, widget, pd);
        return;
    }

    if (comp_expose & XtExposeGraphicsExposeMerged) {
        info.type1 = Expose;
        info.type2 = GraphicsExpose;
    }
    else {
        info.type1 = event->type;
        info.type2 = 0;
    }
    info.maximal = (comp_expose_type == XtExposeCompressMaximal);
    info.non_matching = FALSE;
    info.window = XtWindow(widget);

    /*
     * We have to be very careful here not to hose down the processor
     * when blocking until count gets to zero.
     *
     * First, check to see if there are any events in the queue for this
     * widget, and of the correct type.
     *
     * Once we cannot find any more events, check to see that count is zero.
     * If it is not then block until we get another exposure event.
     *
     * If we find no more events, and count on the last one we saw was zero we
     * we can be sure that all events have been processed.
     *
     * Unfortunately, we wind up having to look at the entire queue
     * event if we're not doing Maximal compression, due to the
     * semantics of XCheckIfEvent (we can't abort without re-ordering
     * the event queue as a side-effect).
     */

    count = 0;
    while (TRUE) {
        XEvent event_return;

        if (XCheckIfEvent(dpy, &event_return,
                          MyCheckExposureEvent, (char *) &info)) {

            count = GetCount(&event_return);
            if (no_region)
                MyAddExposureToRectangularRegion(&event_return, pd->region);
            else
                XtAddExposureToRegion(&event_return, pd->region);
        }
        else if (count != 0) {
            XIfEvent(dpy, &event_return, MyCheckExposureEvent, (char *) &info);
            count = GetCount(&event_return);
            if (no_region)
                MyAddExposureToRectangularRegion(&event_return, pd->region);
            else
                XtAddExposureToRegion(&event_return, pd->region);
        }
        else                    /* count == 0 && XCheckIfEvent Failed. */
            break;
    }

    MySendExposureEvent(event, widget, pd);
}

#define EXT_TYPE(p) (((XtEventRecExt*) ((p)+1))->type)

typedef struct _XtEventRecExt {
    int type;
    XtPointer select_data[1];   /* actual dimension is [mask] */
} XtEventRecExt;

static Boolean
MyCallEventHandlers(Widget widget, XEvent *event, EventMask mask)
{
    register XtEventRec *p;
    XtEventHandler *proc;
    XtPointer *closure;
    Boolean cont_to_disp = True;
    int i, numprocs;

    /* Have to copy the procs into an array, because one of them might
     * call XtRemoveEventHandler, which would break our linked list. */

    numprocs = 0;
    for (p = widget->core.event_table; p; p = p->next) {
        if ((!p->has_type_specifier && (mask & p->mask)) ||
            (p->has_type_specifier && event->type == EXT_TYPE(p)))
            numprocs++;
    }
    proc = (XtEventHandler *)
        __XtMalloc((Cardinal)
                   ((size_t) numprocs *
                    (sizeof(XtEventHandler) + sizeof(XtPointer))));
    closure = (XtPointer *) (proc + numprocs);

    numprocs = 0;
    for (p = widget->core.event_table; p; p = p->next) {
        if ((!p->has_type_specifier && (mask & p->mask)) ||
            (p->has_type_specifier && event->type == EXT_TYPE(p))) {
            proc[numprocs] = p->proc;
            closure[numprocs] = p->closure;
            numprocs++;
        }
    }
    for (i = 0; i < numprocs && cont_to_disp; i++)
        (*(proc[i])) (widget, closure[i], event, &cont_to_disp);
    XtFree((char *) proc);
    return cont_to_disp;
}


static Boolean
MyXtDispatchEventToWidget(Widget widget, XEvent *event)
{
    register XtEventRec *p;
    Boolean was_dispatched = False;
    Boolean call_tm = False;
    Boolean cont_to_disp;
    EventMask mask;

    WIDGET_TO_APPCON(widget);

    LOCK_APP(app);

    mask = _XtConvertTypeToMask(event->type);
    if (event->type == MotionNotify)
        mask |= (event->xmotion.state & KnownButtons);

    LOCK_PROCESS;
    if ((mask == ExposureMask) ||
        ((event->type == NoExpose) && NO_EXPOSE) ||
        ((event->type == GraphicsExpose) && GRAPHICS_EXPOSE)) {

        if (widget->core.widget_class->core_class.expose != NULL) {

            /* We need to mask off the bits that could contain the information
             * about whether or not we desire Graphics and NoExpose events.  */

            if ((COMP_EXPOSE_TYPE == XtExposeNoCompress) ||
                (event->type == NoExpose))

                (*widget->core.widget_class->core_class.expose)
                    (widget, event, (Region) NULL);
            else {
                MyCompressExposures(event, widget);
            }
            was_dispatched = True;
        }
    }

    if ((mask == VisibilityChangeMask) &&
        XtClass(widget)->core_class.visible_interest) {
        was_dispatched = True;
        /* our visibility just changed... */
        switch (((XVisibilityEvent *) event)->state) {
        case VisibilityUnobscured:
            widget->core.visible = TRUE;
            break;

        case VisibilityPartiallyObscured:
            /* what do we want to say here? */
            /* well... some of us is visible */
            widget->core.visible = TRUE;
            break;

        case VisibilityFullyObscured:
            widget->core.visible = FALSE;
            /* do we want to mark our children obscured? */
            break;
        }
    }
    UNLOCK_PROCESS;

    /* to maintain "copy" semantics we check TM now but call later */
    if (widget->core.tm.translations &&
        (mask & widget->core.tm.translations->eventMask))
        call_tm = True;

    cont_to_disp = True;
    p = widget->core.event_table;
    if (p) {
        if (p->next) {
            XtEventHandler proc[EHSIZE];
            XtPointer closure[EHSIZE];
            int numprocs = 0;

            /* Have to copy the procs into an array, because one of them might
             * call XtRemoveEventHandler, which would break our linked list. */

            for (; p; p = p->next) {
                if ((!p->has_type_specifier && (mask & p->mask)) ||
                    (p->has_type_specifier && event->type == EXT_TYPE(p))) {
                    if (numprocs >= EHSIZE)
                        break;
                    proc[numprocs] = p->proc;
                    closure[numprocs] = p->closure;
                    numprocs++;
                }
            }
            if (numprocs) {
                if (p) {
                    cont_to_disp = MyCallEventHandlers(widget, event, mask);
                }
                else {
                    int i;

                    for (i = 0; i < numprocs && cont_to_disp; i++)
                        (*(proc[i])) (widget, closure[i], event, &cont_to_disp);
                }
                was_dispatched = True;
            }
        }
        else if ((!p->has_type_specifier && (mask & p->mask)) ||
                 (p->has_type_specifier && event->type == EXT_TYPE(p))) {
            (*p->proc) (widget, p->closure, event, &cont_to_disp);
            was_dispatched = True;
        }
    }
    if (call_tm && cont_to_disp)
        _XtTranslateEvent(widget, event);
    UNLOCK_APP(app);
    return (was_dispatched | call_tm);
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

    return MyXtDispatchEventToWidget(widget, event);
}

#define NonMaskableMask ((EventMask)0x80000000L)

static EventMask const masks[] = {
    0,                          /* Error, should never see  */
    0,                          /* Reply, should never see  */
    KeyPressMask,               /* KeyPress                 */
    KeyReleaseMask,             /* KeyRelease               */
    ButtonPressMask,            /* ButtonPress              */
    ButtonReleaseMask,          /* ButtonRelease            */
    PointerMotionMask           /* MotionNotify             */
        | ButtonMotionMask,
    EnterWindowMask,            /* EnterNotify              */
    LeaveWindowMask,            /* LeaveNotify              */
    FocusChangeMask,            /* FocusIn                  */
    FocusChangeMask,            /* FocusOut                 */
    KeymapStateMask,            /* KeymapNotify             */
    ExposureMask,               /* Expose                   */
    NonMaskableMask,            /* GraphicsExpose, in GC    */
    NonMaskableMask,            /* NoExpose, in GC          */
    VisibilityChangeMask,       /* VisibilityNotify         */
    SubstructureNotifyMask,     /* CreateNotify             */
    StructureNotifyMask         /* DestroyNotify            */
        | SubstructureNotifyMask,
    StructureNotifyMask         /* UnmapNotify              */
        | SubstructureNotifyMask,
    StructureNotifyMask         /* MapNotify                */
        | SubstructureNotifyMask,
    SubstructureRedirectMask,   /* MapRequest               */
    StructureNotifyMask         /* ReparentNotify           */
        | SubstructureNotifyMask,
    StructureNotifyMask         /* ConfigureNotify          */
        | SubstructureNotifyMask,
    SubstructureRedirectMask,   /* ConfigureRequest         */
    StructureNotifyMask         /* GravityNotify            */
        | SubstructureNotifyMask,
    ResizeRedirectMask,         /* ResizeRequest            */
    StructureNotifyMask         /* CirculateNotify          */
        | SubstructureNotifyMask,
    SubstructureRedirectMask,   /* CirculateRequest         */
    PropertyChangeMask,         /* PropertyNotify           */
    NonMaskableMask,            /* SelectionClear           */
    NonMaskableMask,            /* SelectionRequest         */
    NonMaskableMask,            /* SelectionNotify          */
    ColormapChangeMask,         /* ColormapNotify           */
    NonMaskableMask,            /* ClientMessage            */
    NonMaskableMask             /* MappingNotify            */
};

static EventMask
_MyXtConvertTypeToMask(int eventType)
{
    if ((Cardinal) eventType < XtNumber(masks))
        return masks[eventType];
    else
        return NoEventMask;
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
                              || MyXtDispatchEventToWidget(widget, event));
        }
        else
            was_dispatched = (Boolean) XFilterEvent(event, None);
    }
    else if (grabType == pass) {
        if (event->type == LeaveNotify ||
            event->type == FocusIn || event->type == FocusOut) {
            if (XtIsSensitive(widget))
                was_dispatched = (XFilterEvent(event, XtWindow(widget)) ||
                                  MyXtDispatchEventToWidget(widget, event));
        }
        else
            was_dispatched = (XFilterEvent(event, XtWindow(widget)) ||
                              MyXtDispatchEventToWidget(widget, event));
    }
    else if (grabType == ignore) {
        if ((grabList == NULL || _XtOnGrabList(widget, grabList))
            && XtIsSensitive(widget)) {
            was_dispatched = (XFilterEvent(event, XtWindow(widget))
                              || MyDispatchEvent(event, widget));
        }
    }
    else if (grabType == remap) {
        EventMask mask = _MyXtConvertTypeToMask(event->type);
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
                was_dispatched = MyXtDispatchEventToWidget(dspWidget, event);
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
                                  || MyXtDispatchEventToWidget(widget, event)
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
	MyXtRemoveTimeOut(notifier.currentTimeout);
    }
    if (timePtr) {
	timeout = timePtr->sec * 1000 + timePtr->usec / 1000;
	notifier.currentTimeout = MyXtAppAddTimeOut(notifier.appContext,
		timeout, TimerProc, NULL);
    } else {
	notifier.currentTimeout = 0;
    }
}

static XtInputMask MyXtAppPending(XtAppContext app)
{
    struct timeval cur_time;
    int d;
    XtInputMask ret = 0;

/*
 * Check for pending X events
 */
    LOCK_APP(app);
    for (d = 0; d < app->count; d++) {
        if (XEventsQueued(app->list[d], QueuedAfterReading)) {
            ret = XtIMXEvent;
            break;
        }
    }
    if (ret == 0) {
        for (d = 0; d < app->count; d++) {
            if (XEventsQueued(app->list[d], QueuedAfterFlush)) {
                ret = XtIMXEvent;
                break;
            }
        }
    }

    if (app->signalQueue != NULL) {
        SignalEventRec *se_ptr = app->signalQueue;

        while (se_ptr != NULL) {
            if (se_ptr->se_notice) {
                ret |= XtIMSignal;
                break;
            }
            se_ptr = se_ptr->se_next;
        }
    }

/*
 * Check for pending alternate input
 */
    if (app->timerQueue != NULL) {      /* check timeout queue */
        X_GETTIMEOFDAY(&cur_time);
        FIXUP_TIMEVAL(cur_time);
        if ((IS_AT_OR_AFTER(app->timerQueue->te_timer_value, cur_time)) &&
            (app->timerQueue->te_proc != NULL)) {
            ret |= XtIMTimer;
        }
    }

    if (app->outstandingQueue != NULL)
        ret |= XtIMAlternateInput;
    else {
        /* This won't cause a wait, but will enqueue any input */

        if (_XtWaitForSomething(app,
                                FALSE, TRUE, FALSE, TRUE,
                                FALSE, TRUE, (unsigned long *) NULL) != -1)
            ret |= XtIMXEvent;
        if (app->outstandingQueue != NULL)
            ret |= XtIMAlternateInput;
    }
    UNLOCK_APP(app);
    return ret;
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
	    if (MyXtAppPending(notifier.appContext)) {
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
	MyXtRemoveTimeOut(notifier.currentTimeout);
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
	    filePtr->read = MyXtAppAddInput(notifier.appContext, fd,
		    (void *)(intptr_t)XtInputReadMask, FileProc, filePtr);
	}
    } else {
	if (filePtr->mask & TCL_READABLE) {
	    XtRemoveInput(filePtr->read);
	}
    }
    if (mask & TCL_WRITABLE) {
	if (!(filePtr->mask & TCL_WRITABLE)) {
	    filePtr->write = MyXtAppAddInput(notifier.appContext, fd,
		    (void *)(intptr_t)XtInputWriteMask, FileProc, filePtr);
	}
    } else {
	if (filePtr->mask & TCL_WRITABLE) {
	    XtRemoveInput(filePtr->write);
	}
    }
    if (mask & TCL_EXCEPTION) {
	if (!(filePtr->mask & TCL_EXCEPTION)) {
	    filePtr->except = MyXtAppAddInput(notifier.appContext, fd,
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
    MyXtAppAddTimeOut(notifier.appContext, 1500, timer_proc, NULL);
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
        MyXtAppAddTimeOut(notifier.appContext, 1500, timer_proc, NULL);
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
    MyXtAppAddInput(notifier.appContext, pipefds[0], (XtPointer)XtInputReadMask, pipe_proc, NULL);

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
#ifndef __lock_lint
    nullRegion = XCreateRegion();
#endif
    return PyModule_Create(&moduledef);
}
