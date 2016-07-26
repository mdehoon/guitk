#include <Python.h>
#include "window.h"
#include "image.h"
#include "widgets.h"
#include "label.h"
#include "button.h"


#if PY_MAJOR_VERSION >= 3
#define PY3K 1
#else
#if PY_MINOR_VERSION < 7
#error Python version should be 2.7 or newer
#else
#define PY3K 0
#endif
#endif

static PyObject*
Application_set_icon(PyObject* unused, PyObject* args, PyObject* keywords)
{
    PyObject* argument;
    static char* kwlist[] = {"icon", NULL};
    if (PyTuple_Check(args) && PyTuple_GET_SIZE(args)==0)
        NSApp.applicationIconImage = nil;
    else if (PyArg_ParseTupleAndKeywords(args, keywords, "O!", kwlist,
                                         &ImageType, &argument)) {
        ImageObject* object = (ImageObject*)argument;
        NSApp.applicationIconImage = object->image;
    } else {
        return NULL;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static struct PyMethodDef methods[] = {
    {"set_icon",
     (PyCFunction)Application_set_icon,
     METH_KEYWORDS | METH_VARARGS,
     "Sets the application icon.\n"
    },
   {NULL,          NULL, 0, NULL} /* sentinel */
};

#if PY3K
static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,         /* m_base */
    "_guitk",                      /* m_name */
    "_guitk module for Mac OS X",  /* m_doc */
    -1,                            /* m_size */
    methods,                       /* m_methods */
    NULL,                          /* m_reload */
    NULL,                          /* m_traverse */
    NULL,                          /* m_clear */
    NULL,                          /* m_free */
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

    if (PyType_Ready(&WindowType) < 0)
        goto error;
    if (PyType_Ready(&ImageType) < 0)
        goto error;
    if (PyType_Ready(&GridType) < 0)
        goto error;
    if (PyType_Ready(&GridItemType) < 0)
        goto error;
    if (PyType_Ready(&LabelType) < 0)
        goto error;
    if (PyType_Ready(&ButtonType) < 0)
        goto error;

    Py_INCREF(&WindowType);
    Py_INCREF(&ImageType);
    Py_INCREF(&GridType);
    Py_INCREF(&GridItemType);
    Py_INCREF(&LabelType);
    Py_INCREF(&ButtonType);

    if (PyModule_AddObject(module, "Window", (PyObject*) &WindowType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Image", (PyObject*) &ImageType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Grid", (PyObject*) &GridType) < 0)
        goto error;
    if (PyModule_AddObject(module, "GridItem", (PyObject*) &GridItemType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Label", (PyObject*) &LabelType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Button", (PyObject*) &ButtonType) < 0)
        goto error;

    initialize_widgets();

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
