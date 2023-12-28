#include <Cocoa/Cocoa.h>
#include <Python.h>

typedef struct {
    PyObject_HEAD
    CTFontRef font;
} FontObject;

typedef struct {
    FontObject super;
    CTFontUIFontType uiType;
    Boolean default_size;
} SystemFontObject;

extern PyTypeObject FontType;
extern PyTypeObject SystemFontType;

extern FontObject* default_font_object;

Boolean _init_system_fonts(void);
