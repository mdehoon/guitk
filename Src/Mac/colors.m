#include <Cocoa/Cocoa.h>
#include <Python.h>
#include <stdbool.h>
#include "colors.h"


static char* colors[][2] = {
    {"AliceBlue", "#F0F8FF"},
    {"AntiqueWhite", "#FAEBD7"},
    {"Aqua", "#00FFFF"},
    {"Aquamarine", "#7FFFD4"},
    {"Azure", "#F0FFFF"},
    {"Beige", "#F5F5DC"},
    {"Bisque", "#FFE4C4"},
    {"Black", "#000000"},
    {"BlanchedAlmond", "#FFEBCD"},
    {"Blue", "#0000FF"},
    {"BlueViolet", "#8A2BE2"},
    {"Brown", "#A52A2A"},
    {"BurlyWood", "#DEB887"},
    {"CadetBlue", "#5F9EA0"},
    {"Chartreuse", "#7FFF00"},
    {"Chocolate", "#D2691E"},
    {"Coral", "#FF7F50"},
    {"CornflowerBlue", "#6495ED"},
    {"Cornsilk", "#FFF8DC"},
    {"Crimson", "#DC143C"},
    {"Cyan", "#00FFFF"},
    {"DarkBlue", "#00008B"},
    {"DarkCyan", "#008B8B"},
    {"DarkGoldenRod", "#B8860B"},
    {"DarkGray", "#A9A9A9"},
    {"DarkGrey", "#A9A9A9"},
    {"DarkGreen", "#006400"},
    {"DarkKhaki", "#BDB76B"},
    {"DarkMagenta", "#8B008B"},
    {"DarkOliveGreen", "#556B2F"},
    {"DarkOrange", "#FF8C00"},
    {"DarkOrchid", "#9932CC"},
    {"DarkRed", "#8B0000"},
    {"DarkSalmon", "#E9967A"},
    {"DarkSeaGreen", "#8FBC8F"},
    {"DarkSlateBlue", "#483D8B"},
    {"DarkSlateGray", "#2F4F4F"},
    {"DarkSlateGrey", "#2F4F4F"},
    {"DarkTurquoise", "#00CED1"},
    {"DarkViolet", "#9400D3"},
    {"DeepPink", "#FF1493"},
    {"DeepSkyBlue", "#00BFFF"},
    {"DimGray", "#696969"},
    {"DimGrey", "#696969"},
    {"DodgerBlue", "#1E90FF"},
    {"FireBrick", "#B22222"},
    {"FloralWhite", "#FFFAF0"},
    {"ForestGreen", "#228B22"},
    {"Fuchsia", "#FF00FF"},
    {"Gainsboro", "#DCDCDC"},
    {"GhostWhite", "#F8F8FF"},
    {"Gold", "#FFD700"},
    {"GoldenRod", "#DAA520"},
    {"Gray", "#808080"},
    {"Grey", "#808080"},
    {"Green", "#008000"},
    {"GreenYellow", "#ADFF2F"},
    {"HoneyDew", "#F0FFF0"},
    {"HotPink", "#FF69B4"},
    {"IndianRed ", "#CD5C5C"},
    {"Indigo ", "#4B0082"},
    {"Ivory", "#FFFFF0"},
    {"Khaki", "#F0E68C"},
    {"Lavender", "#E6E6FA"},
    {"LavenderBlush", "#FFF0F5"},
    {"LawnGreen", "#7CFC00"},
    {"LemonChiffon", "#FFFACD"},
    {"LightBlue", "#ADD8E6"},
    {"LightCoral", "#F08080"},
    {"LightCyan", "#E0FFFF"},
    {"LightGoldenRodYellow", "#FAFAD2"},
    {"LightGray", "#D3D3D3"},
    {"LightGrey", "#D3D3D3"},
    {"LightGreen", "#90EE90"},
    {"LightPink", "#FFB6C1"},
    {"LightSalmon", "#FFA07A"},
    {"LightSeaGreen", "#20B2AA"},
    {"LightSkyBlue", "#87CEFA"},
    {"LightSlateGray", "#778899"},
    {"LightSlateGrey", "#778899"},
    {"LightSteelBlue", "#B0C4DE"},
    {"LightYellow", "#FFFFE0"},
    {"Lime", "#00FF00"},
    {"LimeGreen", "#32CD32"},
    {"Linen", "#FAF0E6"},
    {"Magenta", "#FF00FF"},
    {"Maroon", "#800000"},
    {"MediumAquaMarine", "#66CDAA"},
    {"MediumBlue", "#0000CD"},
    {"MediumOrchid", "#BA55D3"},
    {"MediumPurple", "#9370DB"},
    {"MediumSeaGreen", "#3CB371"},
    {"MediumSlateBlue", "#7B68EE"},
    {"MediumSpringGreen", "#00FA9A"},
    {"MediumTurquoise", "#48D1CC"},
    {"MediumVioletRed", "#C71585"},
    {"MidnightBlue", "#191970"},
    {"MintCream", "#F5FFFA"},
    {"MistyRose", "#FFE4E1"},
    {"Moccasin", "#FFE4B5"},
    {"NavajoWhite", "#FFDEAD"},
    {"Navy", "#000080"},
    {"OldLace", "#FDF5E6"},
    {"Olive", "#808000"},
    {"OliveDrab", "#6B8E23"},
    {"Orange", "#FFA500"},
    {"OrangeRed", "#FF4500"},
    {"Orchid", "#DA70D6"},
    {"PaleGoldenRod", "#EEE8AA"},
    {"PaleGreen", "#98FB98"},
    {"PaleTurquoise", "#AFEEEE"},
    {"PaleVioletRed", "#DB7093"},
    {"PapayaWhip", "#FFEFD5"},
    {"PeachPuff", "#FFDAB9"},
    {"Peru", "#CD853F"},
    {"Pink", "#FFC0CB"},
    {"Plum", "#DDA0DD"},
    {"PowderBlue", "#B0E0E6"},
    {"Purple", "#800080"},
    {"RebeccaPurple", "#663399"},
    {"Red", "#FF0000"},
    {"RosyBrown", "#BC8F8F"},
    {"RoyalBlue", "#4169E1"},
    {"SaddleBrown", "#8B4513"},
    {"Salmon", "#FA8072"},
    {"SandyBrown", "#F4A460"},
    {"SeaGreen", "#2E8B57"},
    {"SeaShell", "#FFF5EE"},
    {"Sienna", "#A0522D"},
    {"Silver", "#C0C0C0"},
    {"SkyBlue", "#87CEEB"},
    {"SlateBlue", "#6A5ACD"},
    {"SlateGray", "#708090"},
    {"SlateGrey", "#708090"},
    {"Snow", "#FFFAFA"},
    {"SpringGreen", "#00FF7F"},
    {"SteelBlue", "#4682B4"},
    {"Tan", "#D2B48C"},
    {"Teal", "#008080"},
    {"Thistle", "#D8BFD8"},
    {"Tomato", "#FF6347"},
    {"Turquoise", "#40E0D0"},
    {"Violet", "#EE82EE"},
    {"Wheat", "#F5DEB3"},
    {"White", "#FFFFFF"},
    {"WhiteSmoke", "#F5F5F5"},
    {"Yellow", "#FFFF00"},
    {"YellowGreen", "#9ACD32"},
    {NULL, NULL},
};


static int Color_converter(PyObject* argument, void* address)
{
    PyTypeObject* type;
    unsigned short* rgba = address;
    if (argument==NULL) {
        rgba[0] = 0;
        rgba[1] = 0;
        rgba[2] = 0;
        rgba[3] = 0;
        return 1;
    }
    type = Py_TYPE(argument);
    if (PyType_IsSubtype(type, &ColorType)) {
        ColorObject* color = (ColorObject*)argument;
        rgba[0] = color->rgba[0];
        rgba[1] = color->rgba[1];
        rgba[2] = color->rgba[2];
        rgba[3] = color->rgba[3];
        return 1;
    }
    if (PyTuple_Check(argument)) {
        int i;
        unsigned short values[4];
        if (PyTuple_GET_SIZE(argument) != 4) {
            PyErr_SetString(PyExc_ValueError,
                            "expected a tuple with 4 components");
            return 0;
        }
        for (i = 0; i < 4; i++) {
            long value;
            PyObject* item;
            item = PyTuple_GET_ITEM(argument, i);
            value = PyLong_AsLong(item);
            if (value==-1 && PyErr_Occurred()) {
                PyErr_SetString(PyExc_ValueError,
                                "expected a tuple with 4 values");
                return 0;
            }
            if (value < 0 || value >= 256) {
                PyErr_Format(PyExc_ValueError, "value %d is out of bounds", value);
                return 0;
            }
            values[i] = (unsigned short)value;
        }
        memcpy(rgba, values, 4 * sizeof(unsigned short));
        return 1;
    }
    if (PyUnicode_Check(argument)) {
        char* s;
        char *(*p)[2];
        const char* name;
        long hex;
        const char* hexcode = NULL;
        argument = PyUnicode_AsASCIIString(argument);
        if (!argument) {
            PyErr_Clear();
            PyErr_SetString(PyExc_ValueError, "expected an ASCII string");
            return 0;
        }
        s = PyBytes_AS_STRING(argument);
        rgba[0] = 0;
        rgba[1] = 0;
        rgba[2] = 0;
        rgba[3] = 0;
        if (s[0] == '#') {
            if (strlen(s) == 7) {
                hexcode = s + 1;
                rgba[3] = 255;
                hex = strtol(hexcode, NULL, 16);
            }
            else if (strlen(s) == 9) {
                hexcode = s + 1;
                hex = strtol(hexcode, NULL, 16);
                rgba[3] = hex & 0xff;
                hex >>= 8;
            }
        }
        else {
            for (p = colors; p[0]; p++) {
                name = (*p)[0];
                if (!name) break;
                if (PyOS_stricmp(name, s)==0) {
                    hexcode = (*p)[1] + 1;
                    hex = strtol(hexcode, NULL, 16);
                    rgba[3] = 255;
                    break;
                }
            }
        }
        if (!hexcode) {
            Py_DECREF(argument);
            PyErr_SetString(PyExc_ValueError, "failed to find color name");
            return 0;
        }
        rgba[2] = hex & 0xff;
        hex >>= 8;
        rgba[1] = hex & 0xff;
        hex >>= 8;
        rgba[0] = hex & 0xff;
        Py_DECREF(argument);
        return 1;
    }
    PyErr_SetString(PyExc_ValueError,
                    "expected a tuple, string, or color object");
    return 0;
}

static PyObject*
Color_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    ColorObject *self = (ColorObject*)type->tp_alloc(type, 0);
    if (!self) return NULL;
    if (!PyArg_ParseTuple(args, "|O&", Color_converter, self->rgba)) {
        Py_DECREF(self);
        return NULL;
    }
    return (PyObject*)self;
}

static PyObject*
Color_repr(ColorObject* self)
{
    const unsigned short* rgba = self->rgba;
    return PyUnicode_FromFormat("Color((%d, %d, %d, %d))",
                                rgba[0], rgba[1], rgba[2], rgba[3]);
}

static PyObject*
Color_str(ColorObject* self)
{
    unsigned int i;
    const unsigned short *rgba = self->rgba;
    char *(*p)[2];
    char buffer[8];
    const char* name;
    const char* hex;
    i = (rgba[0] << 16) + (rgba[1] << 8) + rgba[2];
    sprintf(buffer, "#%06X", i);
    for (p = colors; p[0]; p++) {
        name = (*p)[0];
        if (!name) break;
        hex = (*p)[1];
        if (strcmp(hex, buffer)==0) break;
    }
    i = (rgba[0] << 24) + (rgba[1] << 16) + (rgba[2] << 8) + rgba[3];
    if (name)
        return PyUnicode_FromFormat("Color object %p with color #%08X ('%s')",
                                    (void*) self, i, name);
    else
        return PyUnicode_FromFormat("Color object %p with color #%08X",
                                    (void*) self, i);
}

static PyObject* Color_get_rgba(ColorObject* self, void* closure)
{
    return Py_BuildValue("iiii", self->rgba[0], self->rgba[1], self->rgba[2], self->rgba[3]);
}

static char Color_rgba__doc__[] = "rgba.";

static PyGetSetDef Color_getseters[] = {
    {"rgba", (getter)Color_get_rgba, (setter)NULL, Color_rgba__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Color_doc[] =
"Color object.\n";

PyTypeObject ColorType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Color",             /* tp_name */
    sizeof(ColorObject),        /* tp_basicsize */
    0,                          /* tp_itemsize */
    0,                          /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Color_repr,       /* tp_repr */
    0,                          /* tp_as_number */
    0,                          /* tp_as_sequence */
    0,                          /* tp_as_mapping */
    0,                          /* tp_hash */
    0,                          /* tp_call */
    (reprfunc)Color_str,        /* tp_str */
    0,                          /* tp_getattro */
    0,                          /* tp_setattro */
    0,                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,        /* tp_flags */
    Color_doc,                  /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    0,                          /* tp_methods */
    0,                          /* tp_members */
    Color_getseters,            /* tp_getset */
    0,                          /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    0,                          /* tp_init */
    0,                          /* tp_alloc */
    Color_new,                  /* tp_new */
};


ColorObject* transparent = NULL;
ColorObject* black = NULL;
ColorObject* systemTextColor = NULL;
ColorObject* systemWindowBackgroundColor = NULL;


@interface AppearanceObserver : NSObject
{
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context;
@end

static void _set_system_color(ColorObject* object, NSColor* color)
{
    color = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    object->rgba[0] = (short) round(255.0 * color.redComponent);
    object->rgba[1] = (short) round(255.0 * color.greenComponent);
    object->rgba[2] = (short) round(255.0 * color.blueComponent);
    object->rgba[3] = (short) round(255.0 * color.alphaComponent);
}

static void _set_system_colors(void) {
    _set_system_color(systemTextColor,
                      [NSColor textColor]);
    _set_system_color(systemWindowBackgroundColor,
                      [NSColor windowBackgroundColor]);
}

@implementation AppearanceObserver
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"effectiveAppearance"]) {
        NSAppearance *savedAppearance = [NSAppearance currentAppearance];
        NSAppearance.currentAppearance = [NSApp effectiveAppearance];
        _set_system_colors();
        [NSAppearance setCurrentAppearance:savedAppearance];
    }
}
@end

bool _init_default_colors(void)
{
    AppearanceObserver* observer = [[AppearanceObserver alloc] init];
    [NSApp addObserver:observer
            forKeyPath:@"effectiveAppearance"
               options:NSKeyValueObservingOptionNew
               context:NULL];

    transparent = (ColorObject*)ColorType.tp_alloc(&ColorType, 0);
    if (!transparent) goto error;
    transparent->rgba[0] = 0;
    transparent->rgba[1] = 0;
    transparent->rgba[2] = 0;
    transparent->rgba[3] = 0;

    black = (ColorObject*)ColorType.tp_alloc(&ColorType, 0);
    if (!black) goto error;
    black->rgba[0] = 0;
    black->rgba[1] = 0;
    black->rgba[2] = 0;
    black->rgba[3] = 255;

    systemTextColor = (ColorObject*)ColorType.tp_alloc(&ColorType, 0);
    if (!systemTextColor) goto error;

    systemWindowBackgroundColor = (ColorObject*)ColorType.tp_alloc(&ColorType, 0);
    if (!systemWindowBackgroundColor) goto error;

    _set_system_colors();

    return true;

error:
    Py_XDECREF(transparent);
    Py_XDECREF(black);
    Py_XDECREF(systemWindowBackgroundColor);
    return false;
}
