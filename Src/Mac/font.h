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

extern FontObject* fixed_font_object;
extern FontObject* default_font_object;
extern FontObject* icon_font_object;
extern FontObject* caption_font_object;
extern FontObject* heading_font_object;
extern FontObject* tooltip_font_object;
extern FontObject* text_font_object;
extern FontObject* small_caption_font_object;
extern FontObject* menu_font_object;

Boolean _init_default_fonts(void);
PyObject* _create_system_font_name_tuple(void);
