#include "text.h"

CFStringRef PyString_AsCFString(const PyObject* object)
{
    if (object==NULL) {
        return CFSTR("");
    }
    if (PyString_Check(object)) {
        const char* text = PyString_AS_STRING(object); 
        return CFStringCreateWithCString(kCFAllocatorDefault, text, kCFStringEncodingUTF8);
    }
    if (PyUnicode_Check(object)) {
        const UniChar* text = (const UniChar*)PyUnicode_AS_DATA(object); 
        const Py_ssize_t size = PyUnicode_GET_SIZE(object);
        return CFStringCreateWithCharacters(kCFAllocatorDefault, text, size);
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
    object = PyString_FromStringAndSize((const char*)buffer, usedBufLen);
    free(buffer);
    return object;
}

NSString* PyString_AsNSString(const PyObject* object)
{
    if (object==NULL) {
        return [NSString string];
    }
    if (PyString_Check(object)) {
        const char* text = PyString_AS_STRING(object); 
        return [NSString stringWithCString: text encoding: NSUTF8StringEncoding];
    }
    if (PyUnicode_Check(object)) {
        const UniChar* text = (const UniChar*)PyUnicode_AS_DATA(object); 
        const Py_ssize_t size = PyUnicode_GET_SIZE(object);
        return [NSString stringWithCharacters: text length: size];
    }
    return NULL;
}

PyObject* PyString_FromNSString(const NSString* text)
{
    PyObject* object;
    const char* s;
    NSUInteger n = [text lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
    s = [text cStringUsingEncoding: NSUTF8StringEncoding];
    object = PyString_FromStringAndSize(s, n);
    return object;
}
