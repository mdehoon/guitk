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

NSString* PyString_AsNSString(PyObject* object)
{
    if (object==NULL) {
        return [NSString string];
    }
    if (PyUnicode_Check(object)) {
        object = PyUnicode_AsUTF8String(object); 
        if (!object) return NULL;
        const char* text = PyBytes_AS_STRING(object);
        NSString* s = [NSString stringWithCString: text encoding: NSUTF8StringEncoding];
        Py_DECREF(object);
        return s;
    }
    return NULL;
}

PyObject* PyString_FromNSString(const NSString* text)
{
    PyObject* object;
    const char* s;
    NSUInteger n = [text lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
    s = [text cStringUsingEncoding: NSUTF8StringEncoding];
    object = PyUnicode_FromStringAndSize(s, n);
    return object;
}
