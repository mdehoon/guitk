#include "font.h"
#include <CoreFoundation/CFBase.h>
#include <stdbool.h>


struct SystemFontMapEntry {
    const char* name;
    CTFontUIFontType uiType;
};

static struct SystemFontMapEntry system_font_map[] = {
    {".kCTFontUIFontAlertHeader", kCTFontUIFontAlertHeader},
    {".kCTFontUIFontApplication", kCTFontUIFontApplication},
    {".kCTFontUIFontControlContent", kCTFontUIFontControlContent},
    {".kCTFontUIFontEmphasizedSystem", kCTFontUIFontEmphasizedSystem},
    {".kCTFontUIFontEmphasizedSystemDetail", kCTFontUIFontEmphasizedSystemDetail},
    {".kCTFontUIFontLabel", kCTFontUIFontLabel},
    {".kCTFontUIFontMenuItem", kCTFontUIFontMenuItem},
    {".kCTFontUIFontMenuItemCmdKey", kCTFontUIFontMenuItemCmdKey},
    {".kCTFontUIFontMenuItemMark", kCTFontUIFontMenuItemMark},
    {".kCTFontUIFontMenuTitle", kCTFontUIFontMenuTitle},
    {".kCTFontUIFontMessage", kCTFontUIFontMessage},
    {".kCTFontUIFontMiniEmphasizedSystem", kCTFontUIFontMiniEmphasizedSystem},
    {".kCTFontUIFontMiniSystem", kCTFontUIFontMiniSystem},
    {".kCTFontUIFontPalette", kCTFontUIFontPalette},
    {".kCTFontUIFontPushButton", kCTFontUIFontPushButton},
    {".kCTFontUIFontSmallEmphasizedSystem", kCTFontUIFontSmallEmphasizedSystem},
    {".kCTFontUIFontSmallSystem", kCTFontUIFontSmallSystem},
    {".kCTFontUIFontSmallToolbar", kCTFontUIFontSmallToolbar},
    {".kCTFontUIFontSystem", kCTFontUIFontSystem},
    {".kCTFontUIFontSystemDetail", kCTFontUIFontSystemDetail},
    {".kCTFontUIFontToolTip", kCTFontUIFontToolTip},
    {".kCTFontUIFontToolbar", kCTFontUIFontToolbar},
    {".kCTFontUIFontUser", kCTFontUIFontUser},
    {".kCTFontUIFontUserFixedPitch", kCTFontUIFontUserFixedPitch},
    {".kCTFontUIFontUtilityWindowTitle", kCTFontUIFontUtilityWindowTitle},
    {".kCTFontUIFontViews", kCTFontUIFontViews},
    {".kCTFontUIFontWindowTitle", kCTFontUIFontWindowTitle},
    {NULL, -1},
};

static const char* _get_system_font_name(CTFontUIFontType uiType)
{
    struct SystemFontMapEntry* font;
    for (font = system_font_map; font->name; font++) {
        if (font->uiType == uiType) return font->name;
    }
    PyErr_SetString(PyExc_RuntimeError, "failed to find system font");
    return NULL;
}

static char* _get_font_size_string(CTFontRef font) {
    const CGFloat size = CTFontGetSize(font);
    char* s = PyOS_double_to_string(size, 'r', 0, Py_DTSF_ADD_DOT_0, NULL);
    if (!s)
        PyErr_SetString(PyExc_MemoryError, "failed to format font size");
    return s;
}

static char* _get_postscript_name(CTFontRef font, CFStringRef* namePtr) {
    char* buffer;
    CFIndex length;
    CFStringRef name = CTFontCopyPostScriptName(font);
    buffer = (char*) CFStringGetCStringPtr(name, kCFStringEncodingUTF8);
    if (buffer) {
        *namePtr = name;
        return buffer;
    }
    *namePtr = NULL;
    length = CFStringGetLength(name) + 1;
    buffer = PyMem_Malloc(length);
    if (buffer) {
        if (!CFStringGetCString(name, buffer, length, kCFStringEncodingUTF8)) {
            PyMem_Free(buffer);
            buffer = NULL;
        }
    }
    CFRelease(name);
    if (!buffer)
        PyErr_SetString(PyExc_MemoryError, "failed to copy PostScript name");
    return buffer;
}

static char* _get_family_name(CTFontRef font, CFStringRef* namePtr) {
    char* buffer;
    CFIndex length;
    CFStringRef name = CTFontCopyFamilyName(font);
    buffer = (char*) CFStringGetCStringPtr(name, kCFStringEncodingUTF8);
    if (buffer) {
        *namePtr = name;
        return buffer;
    }
    *namePtr = NULL;
    length = CFStringGetLength(name) + 1;
    buffer = PyMem_Malloc(length);
    if (buffer) {
        if (!CFStringGetCString(name, buffer, length, kCFStringEncodingUTF8)) {
            PyMem_Free(buffer);
            buffer = NULL;
        }
    }
    CFRelease(name);
    if (!buffer)
        PyErr_SetString(PyExc_MemoryError, "failed to copy PostScript name");
    return buffer;
}

static char* _get_full_name(CTFontRef font, CFStringRef* namePtr) {
    char* buffer;
    CFIndex length;
    CFStringRef name = CTFontCopyFullName(font);
    buffer = (char*) CFStringGetCStringPtr(name, kCFStringEncodingUTF8);
    if (buffer) {
        *namePtr = name;
        return buffer;
    }
    *namePtr = NULL;
    length = CFStringGetLength(name) + 1;
    buffer = PyMem_Malloc(length);
    if (buffer) {
        if (!CFStringGetCString(name, buffer, length, kCFStringEncodingUTF8)) {
            PyMem_Free(buffer);
            buffer = NULL;
        }
    }
    CFRelease(name);
    if (!buffer)
        PyErr_SetString(PyExc_MemoryError, "failed to copy PostScript name");
    return buffer;
}

static char* _get_display_name(CTFontRef font, CFStringRef* namePtr) {
    char* buffer;
    CFIndex length;
    CFStringRef name = CTFontCopyDisplayName(font);
    buffer = (char*) CFStringGetCStringPtr(name, kCFStringEncodingUTF8);
    if (buffer) {
        *namePtr = name;
        return buffer;
    }
    *namePtr = NULL;
    length = CFStringGetLength(name) + 1;
    buffer = PyMem_Malloc(length);
    if (buffer) {
        if (!CFStringGetCString(name, buffer, length, kCFStringEncodingUTF8)) {
            PyMem_Free(buffer);
            buffer = NULL;
        }
    }
    CFRelease(name);
    if (!buffer)
        PyErr_SetString(PyExc_MemoryError, "failed to copy PostScript name");
    return buffer;
}

static PyObject*
Font_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    CTFontRef font;
    CFStringRef fontName;
    float size = 0.0;
    const char* name;
    FontObject *self;

    if (!PyArg_ParseTuple(args, "s|f", &name, &size)) return NULL;

    if (name[0] == '.') {
        PyErr_SetString(PyExc_ValueError, "cannot create system UI font");
        return NULL;
    }

    fontName = CFStringCreateWithCStringNoCopy(kCFAllocatorDefault,
                                               name,
                                               kCFStringEncodingUTF8,
                                               kCFAllocatorNull);
    if (!fontName) {
        return PyErr_Format(PyExc_RuntimeError,
                            "failed to create CFString for '%s'", name);
    }
    font = CTFontCreateWithName(fontName, size, NULL);
    CFRelease(fontName);
    if (!font) {
        PyErr_SetString(PyExc_ValueError, "failed to initialize font");
        return NULL;
    }

    self = (FontObject*)type->tp_alloc(type, 0);
    if (!self) {
        CFRelease(font);
        return NULL;
    }
    self->font = font;

    return (PyObject*)self;
}

static PyObject*
SystemFont_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    CTFontRef font;
    float size = 0.0;
    const char* name;
    SystemFontObject *self;

    const char* system_font_name;
    struct SystemFontMapEntry* system_font;

    if (!PyArg_ParseTuple(args, "s|f", &name, &size)) return NULL;

    for (system_font = system_font_map; ; system_font++) {
        system_font_name = system_font->name;
        if (!system_font_name) {
            return PyErr_Format(PyExc_ValueError,
                                "failed to find system font '%s'", name);
        }
        if (strcmp(name, system_font_name) == 0) break;
    }
    font = CTFontCreateUIFontForLanguage(system_font->uiType, size, NULL);
    if (!font) {
        PyErr_SetString(PyExc_ValueError, "failed to initialize font");
        return NULL;
    }

    self = (SystemFontObject*)type->tp_alloc(type, 0);
    if (!self) {
        CFRelease(font);
        return NULL;
    }
    ((FontObject*)self)->font = font;
    self->uiType = system_font->uiType;
    self->default_size = (size == 0.0) ? true : false;

    return (PyObject*)self;
}

static PyObject*
Font_str(FontObject* self)
{
    CTFontRef font = self->font;

    char* size_string;

    CFStringRef postscript_name = NULL;
    char* postscript_name_string = NULL;

    CFStringRef family_name = NULL;
    char* family_name_string = NULL;

    CFStringRef full_name = NULL;
    char* full_name_string = NULL;

    CFStringRef display_name = NULL;
    char* display_name_string = NULL;

    PyObject* text = NULL;

    size_string = _get_font_size_string(font);
    if (!size_string) goto exit;

    postscript_name_string = _get_postscript_name(font, &postscript_name);
    if (!postscript_name_string) goto exit;

    family_name_string = _get_family_name(font, &family_name);
    if (!family_name_string) goto exit;

    full_name_string = _get_full_name(font, &full_name);
    if (!full_name_string) goto exit;

    display_name_string = _get_display_name(font, &display_name);
    if (!display_name_string) goto exit;

    text = PyUnicode_FromFormat("Font object %p wrapping CTFontRef %p\n"
                                " PostScript name : %s\n"
                                " family name     : %s\n"
                                " full name       : %s\n"
                                " display name    : %s\n"
                                " size            : %s\n",
                                (void*) self, (void*) font,
                                postscript_name_string,
                                family_name_string,
                                full_name_string,
                                display_name_string,
                                size_string);

exit:
    if (size_string) PyMem_Free(size_string);
    if (postscript_name) CFRelease(postscript_name);
    else if (postscript_name_string) PyMem_Free(postscript_name_string);
    if (family_name) CFRelease(family_name);
    else if (family_name_string) PyMem_Free(family_name_string);
    if (full_name) CFRelease(full_name);
    else if (full_name_string) PyMem_Free(full_name_string);
    if (display_name) CFRelease(display_name);
    else if (display_name_string) PyMem_Free(display_name_string);
    return text;
}

static PyObject*
SystemFont_str(SystemFontObject* self)
{
    CTFontRef font = ((FontObject*)self)->font;

    char* size_string = NULL;

    CFStringRef postscript_name = NULL;
    char* postscript_name_string = NULL;

    CFStringRef family_name = NULL;
    char* family_name_string = NULL;

    CFStringRef full_name = NULL;
    char* full_name_string = NULL;

    CFStringRef display_name = NULL;
    char* display_name_string = NULL;

    PyObject* text = NULL;

    const CTFontUIFontType uiType = self->uiType;
    const char* default_size = self->default_size ?  " (default)" : "";
    const char* name = _get_system_font_name(uiType);
    if (!name) goto exit;

    size_string = _get_font_size_string(font);
    if (!size_string) goto exit;

    postscript_name_string = _get_postscript_name(font, &postscript_name);
    if (!postscript_name_string) goto exit;

    family_name_string = _get_family_name(font, &family_name);
    if (!family_name_string) goto exit;

    full_name_string = _get_full_name(font, &full_name);
    if (!full_name_string) goto exit;

    display_name_string = _get_display_name(font, &display_name);
    if (!display_name_string) goto exit;

    text = PyUnicode_FromFormat("SystemFont object %p wrapping CTFontRef %p\n"
                                " user-interface font %s = %d\n"
                                " PostScript name : %s\n"
                                " family name     : %s\n"
                                " full name       : %s\n"
                                " display name    : %s\n"
                                " size            : %s%s\n",
                                (void*) self, (void*) font,
                                name, uiType,
                                postscript_name_string,
                                family_name_string,
                                full_name_string,
                                display_name_string,
                                size_string, default_size);
exit:
    if (size_string) PyMem_Free(size_string);
    if (postscript_name) CFRelease(postscript_name);
    else if (postscript_name_string) PyMem_Free(postscript_name_string);
    if (family_name) CFRelease(family_name);
    else if (family_name_string) PyMem_Free(family_name_string);
    if (full_name) CFRelease(full_name);
    else if (full_name_string) PyMem_Free(full_name_string);
    if (display_name) CFRelease(display_name);
    else if (display_name_string) PyMem_Free(display_name_string);
    return text;
}

static PyObject*
Font_repr(FontObject* self)
{
    CTFontRef font = self->font;

    const CGFloat size = CTFontGetSize(font);
    char* size_buffer = NULL;

    CFStringRef name = NULL;
    const char* name_cstr = NULL;
    char* name_buffer = NULL;

    PyObject* text = NULL;

    name = CTFontCopyPostScriptName(font);
    name_cstr = CFStringGetCStringPtr(name, kCFStringEncodingUTF8);
    if (!name_cstr) {
        CFIndex length = CFStringGetLength(name) + 1;
        name_buffer = PyMem_Malloc(length);
        if (!name_buffer) {
            PyErr_SetString(PyExc_MemoryError,
                            "failed to copy PostScript name");
            goto exit;
        }
        if (CFStringGetCString(name,
                               name_buffer,
                               length,
                               kCFStringEncodingUTF8) == true)
            name_cstr = name_buffer;
        else
            name_cstr = "";
    }

    size_buffer = PyOS_double_to_string(size, 'r', 0, Py_DTSF_ADD_DOT_0, NULL);
    if (!size_buffer) {
        PyErr_SetString(PyExc_MemoryError, "failed to format font size");
        goto exit;
    }
    text = PyUnicode_FromFormat("Font('%s', %s)", name_cstr, size_buffer);

exit:
    if (name) CFRelease(name);
    if (name_buffer) PyMem_Free(name_buffer);
    if (size_buffer) PyMem_Free(size_buffer);
    return text;
}

static PyObject*
SystemFont_repr(SystemFontObject* self)
{
    CTFontRef font = ((FontObject*)self)->font;
    CTFontUIFontType uiType = self->uiType;

    const char* name = NULL;
    const CGFloat size = CTFontGetSize(font);
    char* buffer = NULL;

    PyObject* text = NULL;

    struct SystemFontMapEntry* system_font;
    for (system_font = system_font_map; ; system_font++) {
        name = system_font->name;
        if (!name) break;
        if (system_font->uiType == uiType) {
            if (self->default_size == true) {
                return PyUnicode_FromFormat("SystemFont('%s')", name);
            }
            break;
        }
    }
    if (!name) {
        PyErr_SetString(PyExc_RuntimeError, "failed to find system font");
        return NULL;
    }

    buffer = PyOS_double_to_string(size, 'r', 0, Py_DTSF_ADD_DOT_0, NULL);
    if (!buffer) {
        PyErr_SetString(PyExc_MemoryError, "failed to format font size");
        return NULL;
    }
    text = PyUnicode_FromFormat("SystemFont('%s', %s)", name, buffer);

    PyMem_Free(buffer);
    return text;
}

static void
Font_dealloc(FontObject* self)
{
    CTFontRef font = self->font;
    if (font) CFRelease(font);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyMethodDef Font_methods[] = {
    {NULL}  /* Sentinel */
};

static PyGetSetDef Font_getset[] = {
    {NULL}  /* Sentinel */
};

static char Font_doc[] =
"A Font object wraps a CTFontRef object.\n";

PyTypeObject FontType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "Font",                     /* tp_name */
    sizeof(FontObject),         /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Font_dealloc,   /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Font_repr,        /* tp_repr */
    0,                          /* tp_as_number */
    0,                          /* tp_as_sequence */
    0,                          /* tp_as_mapping */
    0,                          /* tp_hash */
    0,                          /* tp_call */
    (reprfunc)Font_str,         /* tp_str */
    0,                          /* tp_getattro */
    0,                          /* tp_setattro */
    0,                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,        /* tp_flags */
    Font_doc,                   /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Font_methods,               /* tp_methods */
    0,                          /* tp_members */
    Font_getset,                /* tp_getset */
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    0,                          /* tp_init */
    0,                          /* tp_alloc */
    Font_new,                   /* tp_new */
};

PyTypeObject SystemFontType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "SystemFont",               /* tp_name */
    sizeof(SystemFontObject),   /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Font_dealloc,   /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)SystemFont_repr,  /* tp_repr */
    0,                          /* tp_as_number */
    0,                          /* tp_as_sequence */
    0,                          /* tp_as_mapping */
    0,                          /* tp_hash */
    0,                          /* tp_call */
    (reprfunc)SystemFont_str,   /* tp_str */
    0,                          /* tp_getattro */
    0,                          /* tp_setattro */
    0,                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,        /* tp_flags */
    Font_doc,                   /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Font_methods,               /* tp_methods */
    0,                          /* tp_members */
    Font_getset,                /* tp_getset */
    &FontType,                  /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    0,                          /* tp_init */
    0,                          /* tp_alloc */
    SystemFont_new,             /* tp_new */
};

FontObject* default_font_object = NULL;

Boolean _init_system_fonts(void)
{
    CTFontRef font;

    font = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 0.0, NULL);
    if (!font) {
        PyErr_SetString(PyExc_RuntimeError, "failed to initialize font");
        return false;
    }

    default_font_object = (FontObject*) SystemFontType.tp_alloc(&SystemFontType, 0);
    if (!default_font_object) {
        CFRelease(font);
        return false;
    }
    default_font_object->font = font;
    ((SystemFontObject*)default_font_object)->uiType = kCTFontUIFontSystem;
    ((SystemFontObject*)default_font_object)->default_size = true;

    return true;
}
