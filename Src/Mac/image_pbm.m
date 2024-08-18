#include "image.h"
#include "colors.h"


static int _pbm_converter(PyObject* argument, ImageObject *image)
{
    char* s;
    Py_ssize_t i, n;
    Py_ssize_t width = 0;
    Py_ssize_t height = 0;
    if (!PyBytes_Check(argument)) {
        PyErr_SetString(PyExc_TypeError, "'data' must be a bytes object");
        return 0;
    }
    s = PyBytes_AS_STRING(argument);
    n = PyBytes_GET_SIZE(argument);
    if (n < 2 || s[0] != 'P' || s[1] != '4') {
        PyErr_SetString(PyExc_ValueError, "'data' is not in PBM format");
        return 0;
    }
    for (i = 2; i < n; i++) {
        switch (s[i]) {
            case ' ':
            case '\t':
            case '\r':
            case '\n': continue;
            default: break;
        }
    }
    for ( ; i < n; i++) {
        switch (s[i]) {
            case ' ':
            case '\t':
            case '\r':
            case '\n': break;
            case '0': width *= 10; continue;
            case '1': width *= 10; width += 1; continue;
            case '2': width *= 10; width += 2; continue;
            case '3': width *= 10; width += 3; continue;
            case '4': width *= 10; width += 4; continue;
            case '5': width *= 10; width += 5; continue;
            case '6': width *= 10; width += 6; continue;
            case '7': width *= 10; width += 7; continue;
            case '8': width *= 10; width += 8; continue;
            case '9': width *= 10; width += 9; continue;
            default:
                PyErr_SetString(PyExc_ValueError, "PBM data corrupted");
                return 0;
        }
    }
    for (i++; i < n; i++) {
        switch (s[i]) {
            case ' ':
            case '\t':
            case '\r':
            case '\n': continue;
            default: break;
        }
    }
    for ( ; i < n; i++) {
        switch (s[i]) {
            case ' ':
            case '\t':
            case '\r':
            case '\n': break;
            case '#':
                for (i++ ; i < n; i++) {
                    switch (s[i]) {
                        case '\r':
                        case '\n': break;
                    }
                }
                break;
            case '0': height *= 10; continue;
            case '1': height *= 10; height += 1; continue;
            case '2': height *= 10; height += 2; continue;
            case '3': height *= 10; height += 3; continue;
            case '4': height *= 10; height += 4; continue;
            case '5': height *= 10; height += 5; continue;
            case '6': height *= 10; height += 6; continue;
            case '7': height *= 10; height += 7; continue;
            case '8': height *= 10; height += 8; continue;
            case '9': height *= 10; height += 9; continue;
            default:
                PyErr_SetString(PyExc_ValueError, "PBM data corrupted");
                return 0;
        }
        break;
    }
    i++;
    image->width = width;
    image->height = height;
    return 1;
}

Py_LOCAL_SYMBOL PyObject*
_pbm_new(PyTypeObject *type, PyObject *args, PyObject *keywords)
{
    /* ImgBmapCreate in tkImgBmap.c */
    PyObject* fmt;
    ColorObject* foreground = NULL;
    ColorObject* background = NULL;
    fprintf(stderr, "fmt = pbm\n");
    static char* kwlist[] = {"fmt", "data", "foreground", "background", NULL};

    ImageObject *obj = (ImageObject*)type->tp_alloc(type, 0);
    if (!obj) return NULL;
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "OO&|O!O!", kwlist,
                                     &fmt,
                                     _pbm_converter, obj,
                                     &ColorType, &foreground,
                                     &ColorType, &background)) goto error;
    obj->image = NULL;
    return (PyObject*)obj;
error:
    Py_XDECREF((PyObject*)obj);
    return NULL;
}
