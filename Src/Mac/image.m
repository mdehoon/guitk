#include "image.h"


static PyObject*
Image_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    ImageObject *self = (ImageObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->image = NULL;
    return (PyObject*)self;
}

static int
Image_init(ImageObject *self, PyObject *args, PyObject *kwds)
{
    NSImage* image;
    NSString* string;
    const char* path;

    if (!PyArg_ParseTuple(args, "s", &path)) return -1;

    string = [NSString stringWithCString: path encoding: NSUTF8StringEncoding];
    image = [NSImage alloc];
    if (!image) {
        PyErr_SetString(PyExc_MemoryError, "insufficient memory");
        return -1;
    }
    image = [image initWithContentsOfFile: string];
    if (!image) {
        PyErr_SetString(PyExc_ValueError, "failed to create the image");
        return -1;
    }
    self->image = image;

    return 0;
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

PyTypeObject ImageType = {
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
    (initproc)Image_init,       /* tp_init */
    0,                          /* tp_alloc */
    Image_new,                  /* tp_new */
};
