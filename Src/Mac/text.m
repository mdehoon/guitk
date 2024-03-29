#include "text.h"

CFStringRef PyString_AsCFString(const PyObject* object)
{
    if (object==NULL) {
        return CFSTR("");
    }
    if (PyUnicode_Check(object)) {
        CFStringEncoding encoding;
        const Py_ssize_t length = PyUnicode_GET_LENGTH(object);
        const int kind = PyUnicode_KIND(object);
        switch (kind) {
            case PyUnicode_1BYTE_KIND: encoding = kCFStringEncodingISOLatin1; break;
            case PyUnicode_2BYTE_KIND: encoding = kCFStringEncodingUTF16LE; break;
            case PyUnicode_4BYTE_KIND: encoding = kCFStringEncodingUTF32LE; break;
        }
        return CFStringCreateWithBytes(kCFAllocatorDefault,
                                       PyUnicode_DATA(object),
                                       length * kind,
                                       encoding,
                                       false);
    }
    PyErr_Format(PyExc_ValueError, "must be str, not %s", Py_TYPE(object)->tp_name);
    return NULL;
}

PyObject* PyString_FromCFString(const CFStringRef text)
{
    PyObject* object;
    CFIndex usedBufLen;
    UInt8* buffer;
    size_t size;
    CFRange range;
    range.location = 0;
    range.length = CFStringGetLength(text);
    CFStringGetBytes(text, range, kCFStringEncodingUTF8, 0, false, NULL, 0, &usedBufLen);
    size = usedBufLen*sizeof(UInt8);
    buffer = malloc(size);
    if (!buffer) return PyErr_NoMemory();
    CFStringGetBytes(text, range, kCFStringEncodingUTF8, 0, false, buffer, size, &usedBufLen);
    object = PyUnicode_FromStringAndSize((const char*)buffer, usedBufLen);
    free(buffer);
    return object;
}

int string_converter(PyObject* argument, CFStringRef* pointer)
{
    CFStringRef s;
    if (argument == NULL) {
        CFRelease(*pointer);
        return 1;
    }
    s = PyString_AsCFString(argument);
    if (s == NULL) return 0;
    *pointer = s;
    return Py_CLEANUP_SUPPORTED;
}
