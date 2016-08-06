#include <Cocoa/Cocoa.h>
#include <Python.h>
#include "window.h"
#include "widgets.h"
#include "image.h"


#if PY_MAJOR_VERSION >= 3
#define PY3K 1
#else
#if PY_MINOR_VERSION < 7
#error Python version should be 2.7 or newer
#else
#define PY3K 0
#endif
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
#define COMPILING_FOR_10_6
#endif

static PyObject*
Application_set_icon(PyObject* unused, PyObject* args, PyObject* keywords)
{
    PyObject* argument;
    static char* kwlist[] = {"icon", NULL};
    if (PyTuple_Check(args) && PyTuple_GET_SIZE(args)==0)
        [NSApp setApplicationIconImage:nil];
    else if (PyArg_ParseTupleAndKeywords(args, keywords, "O!", kwlist,
                                         &ImageType, &argument)) {
        ImageObject* object = (ImageObject*)argument;
        [NSApp setApplicationIconImage: object->image];
    } else {
        return NULL;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Application_get_windows(PyObject* unused, PyObject* args)
{
#ifdef COMPILING_FOR_10_6
    Py_ssize_t i;
    Py_ssize_t len;
    PyObject* list;
    id item;
    NSInteger number;
    NSWindow* window;
    NSArray* windows;
    NSEnumerator* enumerator;
    NSWindowNumberListOptions options = 0;
    PyObject* object;
    /* visible windows on the active space belonging to the calling application.
     */
    windows = [NSWindow windowNumbersWithOptions: options];
    enumerator = [windows objectEnumerator];
    len = 0;
    while (item = [enumerator nextObject]) {
        number = [item integerValue];
        window = [NSApp windowWithWindowNumber: number];
        if ([window isKindOfClass: [Window class]]) {
            len++;
        }
    }
    list = PyList_New(len);
    if (!list) return NULL;
    enumerator = [windows objectEnumerator];
    i = 0;
    while (item = [enumerator nextObject]) {
        number = [item integerValue];
        window = [NSApp windowWithWindowNumber: number];
        if ([window isKindOfClass: [Window class]]) {
            Window* w = (Window*) window;
            object = [w object];
            Py_INCREF(object);
            PyList_SET_ITEM(list, i, object);
            i++;
        }
    }
    return list;
#else
    PyErr_SetString(PyExc_RuntimeError, "this function is not available if compiled for Mac OS X versions older than 10.6.");
    return NULL;
#endif
}

static struct PyMethodDef methods[] = {
    {"set_icon",
     (PyCFunction)Application_set_icon,
     METH_KEYWORDS | METH_VARARGS,
     "Sets the application icon.\n"
    },
    {"get_windows",
     (PyCFunction)Application_get_windows,
     METH_NOARGS,
     "Returns a list of windows ordered front-to-back."
    },
    {NULL,          NULL, 0, NULL} /* sentinel */
};

#if PY3K
static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,      /* m_base */
    "gui",                      /* m_name */
    "gui module for Mac OS X",  /* m_doc */
    -1,                         /* m_size */
    methods,                    /* m_methods */
    NULL,                       /* m_reload */
    NULL,                       /* m_traverse */
    NULL,                       /* m_clear */
    NULL,                       /* m_free */
};

PyObject* PyInit_gui(void)

#else

void initgui(void)
#endif
{
#ifdef WITH_NEXT_FRAMEWORK
    PyObject *module;

#if PY3K
    module = PyModule_Create(&moduledef);
#else
    module = Py_InitModule4("gui",
                            methods,
                            "Mac OS X native GUI",
                            NULL,
                            PYTHON_API_VERSION);
#endif
    if (module==NULL) goto error;

    if (PyType_Ready(&WindowType) < 0)
        goto error;
    if (PyType_Ready(&WidgetType) < 0)
        goto error;
    if (PyType_Ready(&GridType) < 0)
        goto error;
    if (PyType_Ready(&ImageType) < 0)
        goto error;
    if (PyType_Ready(&LabelType) < 0)
        goto error;
    if (PyType_Ready(&ButtonType) < 0)
        goto error;

    Py_INCREF(&WindowType);
    Py_INCREF(&WidgetType);
    Py_INCREF(&GridType);
    Py_INCREF(&ImageType);
    Py_INCREF(&LabelType);
    Py_INCREF(&ButtonType);

    if (PyModule_AddObject(module, "Window", (PyObject*) &WindowType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Widget", (PyObject*) &WidgetType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Grid", (PyObject*) &GridType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Image", (PyObject*) &ImageType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Label", (PyObject*) &LabelType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Button", (PyObject*) &ButtonType) < 0)
        goto error;

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
