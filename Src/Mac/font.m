#include "font.h"


struct SystemFontMapEntry {
    const char* name;
    CTFontUIFontType uiType;
    CFStringRef postscript_name;
    CGFloat size;
};

static struct SystemFontMapEntry system_font_map[] = {
    {"kCTFontUIFontAlertHeader", kCTFontUIFontAlertHeader, NULL, -1},
    {"kCTFontUIFontApplication", kCTFontUIFontApplication, NULL, -1},
    {"kCTFontUIFontControlContent", kCTFontUIFontControlContent, NULL, -1},
    {"kCTFontUIFontEmphasizedSystem", kCTFontUIFontEmphasizedSystem, NULL, -1},
    {"kCTFontUIFontEmphasizedSystemDetail", kCTFontUIFontEmphasizedSystemDetail, NULL, -1},
    {"kCTFontUIFontLabel", kCTFontUIFontLabel, NULL, -1},
    {"kCTFontUIFontMenuItem", kCTFontUIFontMenuItem, NULL, -1},
    {"kCTFontUIFontMenuItemCmdKey", kCTFontUIFontMenuItemCmdKey, NULL, -1},
    {"kCTFontUIFontMenuItemMark", kCTFontUIFontMenuItemMark, NULL, -1},
    {"kCTFontUIFontMenuTitle", kCTFontUIFontMenuTitle, NULL, -1},
    {"kCTFontUIFontMessage", kCTFontUIFontMessage, NULL, -1},
    {"kCTFontUIFontMiniEmphasizedSystem", kCTFontUIFontMiniEmphasizedSystem, NULL, -1},
    {"kCTFontUIFontMiniSystem", kCTFontUIFontMiniSystem, NULL, -1},
    {"kCTFontUIFontPalette", kCTFontUIFontPalette, NULL, -1},
    {"kCTFontUIFontPushButton", kCTFontUIFontPushButton, NULL, -1},
    {"kCTFontUIFontSmallEmphasizedSystem", kCTFontUIFontSmallEmphasizedSystem, NULL, -1},
    {"kCTFontUIFontSmallSystem", kCTFontUIFontSmallSystem, NULL, -1},
    {"kCTFontUIFontSmallToolbar", kCTFontUIFontSmallToolbar, NULL, -1},
    {"kCTFontUIFontSystem", kCTFontUIFontSystem, NULL, -1},
    {"kCTFontUIFontSystemDetail", kCTFontUIFontSystemDetail, NULL, -1},
    {"kCTFontUIFontToolTip", kCTFontUIFontToolTip, NULL, -1},
    {"kCTFontUIFontToolbar", kCTFontUIFontToolbar, NULL, -1},
    {"kCTFontUIFontUser", kCTFontUIFontUser, NULL, -1},
    {"kCTFontUIFontUserFixedPitch", kCTFontUIFontUserFixedPitch, NULL, -1},
    {"kCTFontUIFontUtilityWindowTitle", kCTFontUIFontUtilityWindowTitle, NULL, -1},
    {"kCTFontUIFontViews", kCTFontUIFontViews, NULL, -1},
    {"kCTFontUIFontWindowTitle", kCTFontUIFontWindowTitle, NULL, -1},
    {NULL, -1, NULL, -1},
};

static PyObject*
Font_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    FontObject *self = (FontObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    self->font = NULL;
    return (PyObject*)self;
}

static int
Font_init(FontObject *self, PyObject *args, PyObject *kwds)
{
    CTFontRef font;
    CGFloat fontSize;
    CFStringRef fontName;
    float size = 0.0;
    const char* name;

    if (!PyArg_ParseTuple(args, "s|f", &name, &size)) return -1;

    if (name[0] == '.') {
        PyErr_SetString(PyExc_ValueError, "cannot create system UI font");
        return -1;
    }
    if (strncmp(name, "kCTFontUIFont", strlen("kCTFontUIFont")) == 0) {
        const char* system_font_name;
        struct SystemFontMapEntry* system_font;
        for (system_font = system_font_map; ; system_font++) {
            system_font_name = system_font->name;
            if (strcmp(name, system_font_name) == 0) break;
        }
        if (!system_font_name) {
            PyErr_Format(PyExc_ValueError, "failed to find system font %s", name);
            return -1;
        }
        font = CTFontCreateUIFontForLanguage(system_font->uiType, size, NULL);
        if (font) {
            if (!system_font->postscript_name) {
                CFStringRef postscript_name = CTFontCopyPostScriptName(font);
                CFRetain(postscript_name);
                system_font->postscript_name = postscript_name;
            }
            if (system_font->size < 0 && size == 0.0)
                system_font->size = CTFontGetSize(font);
        }
    }
    else {
        fontName = CFStringCreateWithCStringNoCopy(kCFAllocatorDefault,
                                                   name,
                                                   kCFStringEncodingUTF8,
                                                   kCFAllocatorNull);
        if (!fontName) {
            PyErr_Format(PyExc_RuntimeError, "failed to create CFString for '%s'", name);
            return -1;
        }
        fontSize = size;

        font = CTFontCreateWithName(fontName, fontSize, NULL);
        CFRelease(fontName);
    }
    if (!font) {
        PyErr_SetString(PyExc_ValueError, "failed to initialize font");
        return -1;
    }
    self->font = font;

    return 0;
}

static PyObject*
Font_str(FontObject* self)
{
    CTFontRef font = self->font;

    const CGFloat size = CTFontGetSize(font);
    char* size_buffer;

    CFStringRef postscript_name = NULL;
    const char* postscript_name_cstr;
    char* postscript_name_buffer = NULL;

    CFStringRef family_name = NULL;
    const char* family_name_cstr;
    char* family_name_buffer = NULL;

    CFStringRef full_name = NULL;
    const char* full_name_cstr;
    char* full_name_buffer = NULL;

    CFStringRef display_name = NULL;
    const char* display_name_cstr;
    char* display_name_buffer = NULL;

    PyObject* text = NULL;

    size_buffer = PyOS_double_to_string(size, 'r', 0, Py_DTSF_ADD_DOT_0, NULL);
    if (!size_buffer) {
        PyErr_SetString(PyExc_MemoryError, "failed to format font size");
        goto exit;
    }

    postscript_name = CTFontCopyPostScriptName(font);
    postscript_name_cstr = CFStringGetCStringPtr(postscript_name, kCFStringEncodingUTF8);
    if (!postscript_name_cstr) {
        CFIndex length = CFStringGetLength(postscript_name) + 1;
        postscript_name_buffer = PyMem_Malloc(length);
        if (!postscript_name_buffer) {
            PyErr_SetString(PyExc_MemoryError, "failed to copy PostScript name");
            goto exit;
        }
        if (CFStringGetCString(postscript_name, postscript_name_buffer, length, kCFStringEncodingUTF8) == true)
            postscript_name_cstr = postscript_name_buffer;
        else
            postscript_name_cstr = "";
    }

    family_name = CTFontCopyFamilyName(font);
    family_name_cstr = CFStringGetCStringPtr(family_name, kCFStringEncodingUTF8);
    if (!family_name_cstr) {
        CFIndex length = CFStringGetLength(family_name) + 1;
        family_name_buffer = PyMem_Malloc(length);
        if (!family_name_buffer) {
            PyErr_SetString(PyExc_MemoryError, "failed to copy family name");
            goto exit;
        }
        if (CFStringGetCString(family_name, family_name_buffer, length, kCFStringEncodingUTF8) == true)
            family_name_cstr = family_name_buffer;
        else
            family_name_cstr = "";
    }

    full_name = CTFontCopyFullName(font);
    full_name_cstr = CFStringGetCStringPtr(full_name, kCFStringEncodingUTF8);
    if (!full_name_cstr) {
        CFIndex length = CFStringGetLength(full_name) + 1;
        full_name_buffer = PyMem_Malloc(length);
        if (!full_name_buffer) {
            PyErr_SetString(PyExc_MemoryError, "failed to copy full name");
            goto exit;
        }
        if (CFStringGetCString(full_name, full_name_buffer, length, kCFStringEncodingUTF8) == true)
            full_name_cstr = full_name_buffer;
        else
            full_name_cstr = "";
    }

    display_name = CTFontCopyDisplayName(font);
    display_name_cstr = CFStringGetCStringPtr(display_name, kCFStringEncodingUTF8);
    if (!display_name_cstr) {
        CFIndex length = CFStringGetLength(display_name) + 1;
        display_name_buffer = PyMem_Malloc(length);
        if (!display_name_buffer) {
            PyErr_SetString(PyExc_MemoryError, "failed to copy display name");
            goto exit;
        }
        if (CFStringGetCString(display_name, display_name_buffer, length, kCFStringEncodingUTF8) == true)
            display_name_cstr = display_name_buffer;
        else
            display_name_cstr = "";
    }

    text = PyUnicode_FromFormat("Font object %p wrapping CTFontRef %p\n"
                                " PostScript name : %s\n"
                                " family name     : %s\n"
                                " full name       : %s\n"
                                " display name    : %s\n"
                                " size            : %s\n",
                                (void*) self, (void*) font,
                                postscript_name_cstr,
                                family_name_cstr,
                                full_name_cstr,
                                display_name_cstr,
                                size_buffer);
exit:
    if (postscript_name) CFRelease(postscript_name);
    if (family_name) CFRelease(family_name);
    if (full_name) CFRelease(full_name);
    if (display_name) CFRelease(display_name);
    if (postscript_name_buffer) PyMem_Free(postscript_name_buffer);
    if (family_name_buffer) PyMem_Free(family_name_buffer);
    if (full_name_buffer) PyMem_Free(full_name_buffer);
    if (display_name_buffer) PyMem_Free(display_name_buffer);
    if (size_buffer) PyMem_Free(size_buffer);
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
    if (CFStringHasPrefix(name, CFSTR("."))) {
        struct SystemFontMapEntry* system_font;
        CFStringRef ps_name = NULL;
        for (system_font = system_font_map; system_font->name; system_font++) {
            ps_name = system_font->postscript_name;
            if (ps_name &&
                CFStringCompare(name, ps_name, 0) == kCFCompareEqualTo) {
                if (system_font->size == size) {
                    text = PyUnicode_FromFormat("Font('%s')",
                                                system_font->name);
                    goto exit;
                }
                if (!name_cstr) name_cstr = system_font->name;
            }
        }
        if (!name_cstr) {
            PyErr_SetString(PyExc_RuntimeError,
                            "failed to find font name in system fonts");
            return NULL;
        }
    }
    else {
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
    (initproc)Font_init,        /* tp_init */
    0,                          /* tp_alloc */
    Font_new,                   /* tp_new */
};
