#include "image.h"
#include "colors.h"


static void release(void* info, const void* data, unsigned long size) {
    Py_buffer* buffer = info;
    PyBuffer_Release(buffer);
    PyMem_Free(buffer);
}

static PyObject*
Image_new(PyTypeObject *type, PyObject *args, PyObject *keywords)
{
    static char *kwlist[] = {"data", NULL};

    ImageObject* object;

    PyObject* argument;
    Py_buffer* buffer;

    CGBitmapInfo bitmapInfo = 0;
    size_t height;
    size_t width;
    size_t bitsPerComponent;
    size_t bitsPerPixel;
    size_t bytesPerRow;
    CGColorSpaceRef space = NULL;
    CGDataProviderRef provider;
    CGImageRef image;

    if (!PyArg_ParseTupleAndKeywords(args, keywords, "O", kwlist, &argument))
        return NULL;

    buffer = PyMem_Malloc(sizeof(Py_buffer));
    if (!buffer) return PyErr_NoMemory();

    if (PyObject_GetBuffer(argument, buffer, PyBUF_ND | PyBUF_FORMAT) != 0) {
        PyErr_SetString(PyExc_ValueError,
            "data must support the buffer protocol");
        PyMem_Free(buffer);
        return NULL;
    }

    if (buffer->itemsize != 1) {
        PyErr_SetString(PyExc_ValueError, "data must consist of single bytes");
        goto error;
    }
    if (strcmp(buffer->format, "B") == 0) {  // bytes
        bitsPerComponent = 8;  // grayscale or rgb or rgba
    }
    else if (strcmp(buffer->format, "?") == 0) {  // bool
        bitsPerComponent = 1;  // black and white
    }
    else {
        PyErr_SetString(PyExc_ValueError, "data format must be 'B' or '?'");
        goto error;
    }
    switch (buffer->ndim) {
        case 2:  // grayscale or black and white
            height = buffer->shape[0];
            width = buffer->shape[1];
            bitsPerPixel = bitsPerComponent;
            bytesPerRow = width;
            space = CGColorSpaceCreateWithName(kCGColorSpaceExtendedGray);
            break;
        case 3:  // rgb or rgba
            height = buffer->shape[0];
            width = buffer->shape[1];
            if (bitsPerComponent != 8) {
                PyErr_Format(PyExc_ValueError,
                             "expected 8 bits per component for RGB(A) data"
                             "(found %zd bits per component)",
                             bitsPerComponent);
                goto error;
            }
            switch (buffer->shape[2]) {
                case 4:
                    bitmapInfo |= kCGImageAlphaPremultipliedLast;
                    bytesPerRow = 4 * width;
                    bitsPerPixel = 4 * bitsPerComponent;
                    break;
                case 3:
                    bitmapInfo |= kCGImageAlphaNone;
                    bytesPerRow = 3 * width;
                    bitsPerPixel = 3 * bitsPerComponent;
                    break;
                default:
                    PyErr_SetString(PyExc_ValueError,
                                    "the third dimension of data must have "
                                    "3 (for RGB) or 4 (for RGBA) elements");
                    goto error;
            }
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101100
            space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            if (!space)  // fallback
#endif
                space = CGColorSpaceCreateDeviceRGB();
            break;
        default:
            PyErr_Format(PyExc_ValueError, "data must have 2 or 3 dimensions "
                                           "(found %d dimensions)", buffer->ndim);
            goto error;
    }

    provider = CGDataProviderCreateWithData(buffer,
                                            buffer->buf,
                                            bytesPerRow * height,
                                            release);

    image = CGImageCreate(width,
                          height,
                          bitsPerComponent,
                          bitsPerPixel,
                          bytesPerRow,
                          space,
                          bitmapInfo,
                          provider,
                          NULL,
                          true,
                          kCGRenderingIntentDefault);

    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);

    if (!image) {
        PyErr_SetString(PyExc_MemoryError, "failed to create CGImage");
        goto error;
    }

    object = (ImageObject*)PyType_GenericAlloc(&ImageType, 0);
    if (object) object->data = image;

    return (PyObject*)object;

error:
    PyBuffer_Release(buffer);
    PyMem_Free(buffer);
    return NULL;
}

static PyObject*
Image_repr(ImageObject* self)
{
    return PyUnicode_FromFormat("Image object %p wrapping CGImage %p",
                                (void*) self, (void*) self->data);
}

static void
Image_dealloc(ImageObject* self)
{
    CGImageRelease(self->data);  // no need to check for NULL
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
    .tp_name = "graphics.Image",
    .tp_basicsize = sizeof(ImageObject),
    .tp_dealloc = (destructor)Image_dealloc,
    .tp_repr = (reprfunc)Image_repr,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_doc = Image_doc,
    .tp_methods = Image_methods,
    .tp_getset = Image_getset,
    .tp_new = Image_new,
};
