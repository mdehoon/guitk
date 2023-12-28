#include <Cocoa/Cocoa.h>
#include <Python.h>
#include "window.h"
#include "widgets.h"
#include "image.h"
#include "colors.h"
#include "font.h"


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
            object = (PyObject*) [w object];
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
{
#ifdef WITH_NEXT_FRAMEWORK
    PyObject *module;

    PyObject* system_font_names;

    module = PyModule_Create(&moduledef);
    if (module==NULL) goto error;

    if (PyType_Ready(&WindowType) < 0)
        goto error;
    if (PyType_Ready(&WidgetType) < 0)
        goto error;
    if (PyType_Ready(&LayoutType) < 0)
        goto error;
    if (PyType_Ready(&FontType) < 0)
        goto error;
    if (PyType_Ready(&SystemFontType) < 0)
        goto error;
    if (PyType_Ready(&FrameType) < 0)
        goto error;
    if (PyType_Ready(&SeparatorType) < 0)
        goto error;
    if (PyType_Ready(&ImageType) < 0)
        goto error;
    if (PyType_Ready(&LabelType) < 0)
        goto error;
    if (PyType_Ready(&ButtonType) < 0)
        goto error;
    if (PyType_Ready(&CheckboxType) < 0)
        goto error;
    if (PyType_Ready(&TextboxType) < 0)
        goto error;
    if (PyType_Ready(&ListboxType) < 0)
        goto error;
    if (PyType_Ready(&ColorType) < 0)
        goto error;

    Py_INCREF(&WindowType);
    Py_INCREF(&WidgetType);
    Py_INCREF(&LayoutType);
    Py_INCREF(&FontType);
    Py_INCREF(&SystemFontType);
    Py_INCREF(&FrameType);
    Py_INCREF(&SeparatorType);
    Py_INCREF(&ImageType);
    Py_INCREF(&LabelType);
    Py_INCREF(&ButtonType);
    Py_INCREF(&CheckboxType);
    Py_INCREF(&TextboxType);
    Py_INCREF(&ListboxType);
    Py_INCREF(&ColorType);

    _init_system_fonts();

    if (PyModule_AddObject(module, "Window", (PyObject*) &WindowType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Widget", (PyObject*) &WidgetType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Layout", (PyObject*) &LayoutType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Font", (PyObject*) &FontType) < 0)
        goto error;
    if (PyModule_AddObject(module, "SystemFont", (PyObject*) &SystemFontType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Frame", (PyObject*) &FrameType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Separator", (PyObject*) &SeparatorType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Image", (PyObject*) &ImageType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Label", (PyObject*) &LabelType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Button", (PyObject*) &ButtonType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Checkbox", (PyObject*) &CheckboxType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Textbox", (PyObject*) &TextboxType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Listbox", (PyObject*) &ListboxType) < 0)
        goto error;
    if (PyModule_AddObject(module, "Color", (PyObject*) &ColorType) < 0)
        goto error;

    Py_INCREF(default_font_object);
    if (PyModule_AddObject(module, "default_font", (PyObject*) default_font_object) < 0)
        goto error;

    system_font_names = _create_system_font_name_tuple();
    if (PyModule_AddObject(module, "system_font_names", (PyObject*) system_font_names) < 0)
        goto error;

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
