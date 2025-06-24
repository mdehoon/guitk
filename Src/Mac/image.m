#include "image.h"
#include "colors.h"


static int
data_converter(PyObject* argument, void* pointer)
{
    Py_buffer* view = pointer;
    if (argument == NULL) {
        PyBuffer_Release(view);
        return 1;
    }
    if (PyObject_GetBuffer(argument, view, PyBUF_FORMAT | PyBUF_ND) != 0)
        return 0;
    if (view->itemsize != 1)
        PyErr_SetString(PyExc_ValueError, "data must consist of single bytes");
    else if (strcmp(view->format, "B") != 0 && strcmp(view->format, "?") != 0)
        PyErr_SetString(PyExc_ValueError, "data format must be 'B' or '?'");
    else if (view->ndim != 2 && view->ndim != 3)
        PyErr_SetString(PyExc_ValueError, "data must have 2 or 3 dimensions");
    else
        return Py_CLEANUP_SUPPORTED;
    PyBuffer_Release(view);
    return 0;
}

static PyObject*
Image_new(PyTypeObject *type, PyObject *args, PyObject *keywords)
{
    static char *kwlist[] = {"data", NULL};

    ImageObject* image = (ImageObject*)PyType_GenericAlloc(&ImageType, 0);

    Py_buffer* data = &image->data;

    if (!PyArg_ParseTupleAndKeywords(args, keywords, "O&", kwlist,
                                     data_converter, data)) {
        Py_DECREF(image);
        return NULL;
    }

    return (PyObject*)image;
}

static PyObject*
Image_repr(ImageObject* self)
{
    return PyUnicode_FromFormat("Image object %p", (void*) self);
}

static void
Image_dealloc(ImageObject* self)
{
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyMethodDef Image_methods[] = {
    {NULL}  /* Sentinel */
};

static PyGetSetDef Image_getset[] = {
    {NULL}  /* Sentinel */
};

static char Image_doc[] =
"A Image object wraps a Cocoa NSImage object.\n";

Py_LOCAL_SYMBOL PyTypeObject ImageType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "graphics.Image",           /* tp_name */
    sizeof(ImageObject),        /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Image_dealloc,  /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Image_repr,       /* tp_repr */
    0,                          /* tp_as_number */
    0,                          /* tp_as_sequence */
    0,                          /* tp_as_mapping */
    0,                          /* tp_hash */
    0,                          /* tp_call */
    0,                          /* tp_str */
    0,                          /* tp_getattro */
    0,                          /* tp_setattro */
    0,                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,        /* tp_flags */
    Image_doc,                  /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Image_methods,              /* tp_methods */
    0,                          /* tp_members */
    Image_getset,               /* tp_getset */
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    0,                          /* tp_init */
    0,                          /* tp_alloc */
    Image_new,                  /* tp_new */
};
