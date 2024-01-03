#include <Python.h>

#define PyEvents_READABLE 2
#define PyEvents_WRITABLE 4
#define PyEvents_EXCEPTION 8

typedef struct SocketObject SocketObject;

struct SocketObject {
    PyObject_HEAD
    int fd;
    int mask;
    PyObject* callback;
    SocketObject* next;
};
