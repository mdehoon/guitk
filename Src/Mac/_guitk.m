#include <Python.h>
#include "window.h"
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

static struct PyMethodDef methods[] = {
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