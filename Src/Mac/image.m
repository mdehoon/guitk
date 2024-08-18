#include "image.h"
#include "colors.h"


static PyObject*
_photo_new(PyTypeObject *type, PyObject *args, PyObject *keywords)
{
    /* ImgPhotoCreate in tkImgPhoto.c */
    fprintf(stderr, "fmt = photo\n");
    ImageObject *obj = (ImageObject*)type->tp_alloc(type, 0);
    if (!obj) return NULL;
    obj->image = NULL;
    return (PyObject*)obj;
}

static PyObject*
Image_new(PyTypeObject *type, PyObject *args, PyObject *keywords)
{
    PyObject* fmt = NULL;

    if (keywords != NULL) {
        if (!PyDict_Check(keywords)) {
            PyErr_BadInternalCall();
            return NULL;
        }
        fmt = PyDict_GetItemString(keywords, "fmt");
    }
    if (fmt == NULL) {
        if (!PyTuple_Check(args)) {
            PyErr_BadInternalCall();
            return NULL;
        }
        if (PyTuple_GET_SIZE(args) > 0) {
            fmt = PyTuple_GET_ITEM(args, 0);
        }
        if (fmt == NULL) {
            PyErr_SetString(PyExc_TypeError,
                            "required argument 'fmt' is missing");
            return NULL;
        }
    }
    if (!PyUnicode_Check(fmt)) {
        PyErr_SetString(PyExc_TypeError, "argument 'fmt' must be a string");
        return NULL;
    }
    if (PyUnicode_CompareWithASCIIString(fmt, "pbm") == 0) {
        return _pbm_new(type, args, keywords);
    }
    if (PyUnicode_CompareWithASCIIString(fmt, "photo") == 0) {
        return _photo_new(type, args, keywords);
    }
    PyErr_SetString(PyExc_ValueError,
                    "argument 'fmt' must be 'pbm' or 'photo'");
    return NULL;
}

static PyObject*
Image_repr(ImageObject* self)
{
    return PyUnicode_FromFormat("Image object %p wrapping NSImage %p",
                               (void*) self, (void*)(self->image));
}

static void
Image_dealloc(ImageObject* self)
{
    NSImage* image = self->image;
    if (image) [image release];
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
