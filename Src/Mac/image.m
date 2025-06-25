#include "image.h"
#include "colors.h"


static void release(void* info, const void* data, unsigned long size) {
    Py_buffer* buffer = info;
    PyBuffer_Release(buffer);
}

static PyObject*
Image_new(PyTypeObject *type, PyObject *args, PyObject *keywords)
{
    static char *kwlist[] = {"data", NULL};

    ImageObject* object;
    Py_buffer buffer;

    CGBitmapInfo bitmapInfo = 0;
    size_t height;
    size_t width;
    size_t bitsPerComponent;
    size_t bitsPerPixel;
    size_t bytesPerRow;
    CGColorSpaceRef space;
    CGDataProviderRef provider;
    CGImageRef image;

    if (!PyArg_ParseTupleAndKeywords(args, keywords, "y*", kwlist, &buffer))
        return NULL;

    if (buffer.itemsize != 1) {
        PyErr_SetString(PyExc_ValueError, "data must consist of single bytes");
        PyBuffer_Release(&buffer);
        return NULL;
    }
    if (buffer.format == NULL || strcmp(buffer.format, "B") == 0) {  // bytes
        bitsPerComponent = 8;  // grayscale or rgb or rgba
    }
    else if (strcmp(buffer.format, "?") == 0) {  // bool
        bitsPerComponent = 1;  // black and white
    }
    else {
        PyErr_SetString(PyExc_ValueError, "data format must be 'B' or '?'");
        PyBuffer_Release(&buffer);
        return NULL;
    }
fprintf(stderr, "bitsPerComponent = %d\n", bitsPerComponent); fflush(stderr);
    switch (buffer.ndim) {
        case 2:  // grayscale or black and white
            height = buffer.shape[0];
            width = buffer.shape[1];
            bitsPerPixel = bitsPerComponent;
            bytesPerRow = width;
            space = CGColorSpaceCreateWithName(kCGColorSpaceExtendedGray);
            break;
        case 3:  // rgb or rgba
            height = buffer.shape[0];
            width = buffer.shape[1];
            switch (buffer.shape[2]) {
                case 4:
                    bitmapInfo |= kCGBitmapAlphaInfoMask;
                case 3:
                    break;
                default:
                    PyErr_SetString(PyExc_ValueError,
                                    "the third dimension of data must have "
                                    "3 (for RGB) or 4 (for RGBA) elements");
                    PyBuffer_Release(&buffer);
                    return NULL;
            }
            if (bitsPerComponent != 8) {
                PyErr_Format(PyExc_ValueError,
                             "expected 8 bits per component for RGB data"
                             "(found %zd bits per component)",
                             bitsPerComponent);
                PyBuffer_Release(&buffer);
                return NULL;
            }
            bytesPerRow = 3 * width;
            bitsPerPixel = 3 * bitsPerComponent;
            space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            break;
        default:
            PyErr_Format(PyExc_ValueError, "data must have 2 or 3 dimensions "
                                           "(found %d dimensions)", buffer.ndim);
            PyBuffer_Release(&buffer);
            return NULL;
    }

fprintf(stderr, "height = %zd width = %zd bitsPerPixel = %zd bytesPerRow = %zd space = %p\n", height, width, bitsPerPixel, bytesPerRow, space); fflush(stderr);
    provider = CGDataProviderCreateWithData(&buffer,
                                            buffer.buf,
                                            bytesPerRow * height,
                                            release);

fprintf(stderr, "provider = %p\n", provider); fflush(stderr);
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
        PyBuffer_Release(&buffer);
        return NULL;
    }

    object = (ImageObject*)PyType_GenericAlloc(&ImageType, 0);
    if (object) object->data = image;

    return (PyObject*)object;
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
