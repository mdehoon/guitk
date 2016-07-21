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

static struct PyMethodDef methods[] = {
   {NULL,          NULL, 0, NULL} /* sentinel */
};

#if PY3K
static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,         /* m_base */
    "graphics",                      /* m_name */
    "graphics module for Mac OS X",  /* m_doc */
    -1,                            /* m_size */
    methods,                       /* m_methods */
    NULL,                          /* m_reload */
    NULL,                          /* m_traverse */
    NULL,                          /* m_clear */
    NULL,                          /* m_free */
};

PyObject* PyInit_graphics(void)

#else

void initgraphics(void)
#endif
{
    PyObject *module;

#if PY3K
    module = PyModule_Create(&moduledef);
#else
    module = Py_InitModule4("graphics",
                            methods,
                            "graphics module for Mac OS X",
                            NULL,
                            PYTHON_API_VERSION);
#endif
    if (module==NULL) goto error;

    if (initialize_image(module)==-1) goto error;

#if PY3K
    return module;
#endif
error:
#if PY3K
    return NULL;
#else
    return;
#endif
}
