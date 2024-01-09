#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "window.h"
#include "colors.h"
#include "text.h"
#include "font.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10100
#define COMPILING_FOR_10_10
#endif

typedef enum {N, NE, E, SE, S, SW, W, NW, C} Anchor;

typedef enum {LEFT, CENTER, RIGHT} Alignment;

typedef enum {RAISED, SUNKEN, FLAT, RIDGE, SOLID, GROOVE} Relief;

typedef enum {NORMAL, ACTIVE, DISABLED} State;

@interface LabelView : NSView
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (LabelView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object;
- (BOOL)isFlipped;
- (void)drawRect:(NSRect)rect;
@end

typedef struct {
    WidgetObject widget;
    ColorObject* foreground;
    ColorObject* background;
    ColorObject* active_background;
    ColorObject* active_foreground;
    ColorObject* disabled_foreground;
    ColorObject* highlight_background;
    ColorObject* highlight_color;
    double border_width;
    double height;
    double width;
    double highlight_thickness;
    Alignment alignment;
    Relief relief;
    double padx;
    double pady;
    Anchor anchor;
    State state;
    CFStringRef text;
    FontObject* font;
    Py_ssize_t underline;
    long wrap_length;
    bool take_focus;
    PyObject* minimum_size;
} LabelObject;


static void
_compute_anchor(Anchor anchor,
                int padx, int pady,
                int innerWidth, int innerHeight, CGFloat* x, CGFloat* y)
{
    switch (anchor) {
    case NW:
    case W:
    case SW:
        // *xPtr = Tk_InternalBorderLeft(tkwin) + padx;
        break;

    case N:
    case C:
    case S:
        // *xPtr = (Tk_Width(tkwin) - innerWidth - Tk_InternalBorderLeft(tkwin) -
          //       Tk_InternalBorderRight(tkwin)) / 2 +
            //     Tk_InternalBorderLeft(tkwin);
        break;

    default:
        // *xPtr = Tk_Width(tkwin) - Tk_InternalBorderRight(tkwin) - padx
          //       - innerWidth;
        break;
    }
    switch (anchor) {
    case NW:
    case N:
    case NE:
        // *yPtr = Tk_InternalBorderTop(tkwin) + padY;
        break;

    case W:
    case C:
    case E:
        // *yPtr = (Tk_Height(tkwin) - innerHeight- Tk_InternalBorderTop(tkwin) -
          //       Tk_InternalBorderBottom(tkwin)) / 2 +
            //     Tk_InternalBorderTop(tkwin);
        break;

    default:
        // *yPtr = Tk_Height(tkwin) - Tk_InternalBorderBottom(tkwin) - padY
          //       - innerHeight;
        break;
    }
}

static void
_draw_3d_vertical_bevel(CGContextRef cr,
                        ColorObject* color,
                        CGFloat x, CGFloat y,
                        CGFloat width, CGFloat height,
                        bool left_bevel, Relief relief)
{
    short red = color->rgba[0];
    short green = color->rgba[1];
    short blue = color->rgba[2];
    short alpha = color->rgba[3];
/*
    if (relief != FLAT) {
        TkpGetShadows(borderPtr, tkwin);
    }
*/

/*
    if (relief == TK_RELIEF_RAISED) {
        XFillRectangle(display, drawable,
                (leftBevel) ? borderPtr->lightGC : borderPtr->darkGC,
                x, y, (unsigned) width, (unsigned) height);
    } else if (relief == TK_RELIEF_SUNKEN) {
        XFillRectangle(display, drawable,
                (leftBevel) ? borderPtr->darkGC : borderPtr->lightGC,
                x, y, (unsigned) width, (unsigned) height);
    } else if (relief == TK_RELIEF_RIDGE) {
        int half;

        left = borderPtr->lightGC;
        right = borderPtr->darkGC;
    ridgeGroove:
        half = width/2;
        if (!leftBevel && (width & 1)) {
            half++;
        }
        XFillRectangle(display, drawable, left, x, y, (unsigned) half,
                (unsigned) height);
        XFillRectangle(display, drawable, right, x+half, y,
                (unsigned) (width-half), (unsigned) height);
    } else if (relief == TK_RELIEF_GROOVE) {
        left = borderPtr->darkGC;
        right = borderPtr->lightGC;
        goto ridgeGroove;
    } else */ if (relief == FLAT) {
        CGRect rect = CGRectMake(x, y, width, height);
        CGContextSetRGBFillColor(cr, red/255., green/255., blue/255., alpha/255.);
        CGContextFillRect(cr, rect);
    } /* else if (relief == TK_RELIEF_SOLID) {
        UnixBorder *unixBorderPtr = (UnixBorder *) borderPtr;
        if (unixBorderPtr->solidGC == NULL) {
            XGCValues gcValues;

            gcValues.foreground = BlackPixelOfScreen(borderPtr->screen);
            unixBorderPtr->solidGC = Tk_GetGC(tkwin, GCForeground, &gcValues);
        }
        XFillRectangle(display, drawable, unixBorderPtr->solidGC, x, y,
                (unsigned) width, (unsigned) height);
    }
*/
}

@implementation LabelView
- (PyObject*)object
{
    return (PyObject*)_object;
}

- (LabelView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object
{
    self = [super initWithFrame: rect];
    _object = object;
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    CTLineRef line;
    CFAttributedStringRef string = NULL;
    CFDictionaryRef attributes = NULL;
    CGContextRef cr;
    NSGraphicsContext* gc;
    CGFloat x;
    CGFloat y;
    CGSize size;
    CGRect rect;
    CGFloat ascent;
    CGFloat descent;
    double width;
    CGFloat height;
    short red, green, blue, alpha;

    LabelObject* object = (LabelObject*)_object;
    CFStringRef keys[] = { kCTFontAttributeName,
                           kCTForegroundColorFromContextAttributeName };
    CFTypeRef values[] = { object->font->font,
                           kCFBooleanTrue };
    const Relief relief = object->relief;
    gc = [NSGraphicsContext currentContext];
#ifdef COMPILING_FOR_10_10
    cr = [gc CGContext];
#else
    cr = (CGContextRef) [gc graphicsPort];
#endif
    switch (object->state) {
        case ACTIVE:
            red = object->active_background->rgba[0];
            green = object->active_background->rgba[1];
            blue = object->active_background->rgba[2];
            alpha = object->active_background->rgba[3];
            break;
        case NORMAL:
        case DISABLED:
            red = object->background->rgba[0];
            green = object->background->rgba[1];
            blue = object->background->rgba[2];
            alpha = object->background->rgba[3];
            break;
    }

    CGContextSetRGBFillColor(cr, red/255., green/255., blue/255., alpha/255.);
    rect = NSRectToCGRect(dirtyRect);
    CGContextFillRect(cr, rect);
    attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                    (const void**)&keys,
                                    (const void**)&values,
                                    2,
                                    &kCFTypeDictionaryKeyCallBacks,
                                    &kCFTypeDictionaryValueCallBacks);
    if (!attributes) return;
    string = CFAttributedStringCreate(kCFAllocatorDefault,
                                      object->text,
                                      attributes);
    CFRelease(attributes);
    if (!string) return;
    line = CTLineCreateWithAttributedString(string);
    CFRelease(string);
    rect = NSRectToCGRect(self.frame);
    size = rect.size;
    y = 0.5 * size.height;
    x = 0.5 * size.width;
    width = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
    height = ascent + descent;
    x -= 0.5 * width;
    y += 0.5 * height;
    y -= descent;
    _compute_anchor(object->anchor, object->padx, object->pady,
                    width, height, &x, &y);
    CGAffineTransform transform = CGAffineTransformMakeScale(1.0, -1.0);
    CGContextSetTextMatrix(cr, transform);
    CGContextSetTextPosition(cr, x, y);
    switch (object->state) {
        case NORMAL:
            red = object->foreground->rgba[0];
            green = object->foreground->rgba[1];
            blue = object->foreground->rgba[2];
            alpha = object->foreground->rgba[3];
            break;
        case ACTIVE:
            red = object->active_foreground->rgba[0];
            green = object->active_foreground->rgba[1];
            blue = object->active_foreground->rgba[2];
            alpha = object->active_foreground->rgba[3];
            break;
        case DISABLED:
            red = object->disabled_foreground->rgba[0];
            green = object->disabled_foreground->rgba[1];
            blue = object->disabled_foreground->rgba[2];
            alpha = object->disabled_foreground->rgba[3];
            break;
    }
    CGContextSetRGBFillColor(cr, red/255., green/255., blue/255., alpha/255.);
    CTLineDraw(line, cr);
    CFRelease(line);
    if (relief != FLAT) {
        ColorObject* color;
        CGFloat inset = object->highlight_thickness;
        CGFloat border_width = object->border_width;
        width = size.width;
        height = size.height;
        x = inset;
        y = inset;
        if (width < 2 * border_width) border_width = width / 2.0;
        if (height < 2 * border_width) border_width = height / 2.0;
        switch (object->state) {
            case ACTIVE:
                color = object->active_background;
                break;
            case NORMAL:
            case DISABLED:
                color = object->background;
                break;
        }
        _draw_3d_vertical_bevel(cr, color, x, y, border_width, height, true, relief);

/*
    Tk_3DVerticalBevel(tkwin, drawable, border, x, y, borderWidth, height,
            1, relief);
    Tk_3DVerticalBevel(tkwin, drawable, border, x+width-borderWidth, y,
            borderWidth, height, 0, relief);
    Tk_3DHorizontalBevel(tkwin, drawable, border, x, y, width, borderWidth,
            1, 1, 1, relief);
    Tk_3DHorizontalBevel(tkwin, drawable, border, x, y+height-borderWidth,
            width, borderWidth, 0, 0, 0, relief);
*/
    }
}

- (BOOL)isFlipped
{
    return YES;
}
@end

static PyObject*
Label_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    WidgetObject* widget;
    LabelObject *self = (LabelObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    widget = (WidgetObject*)self;
    widget->view = nil;
    self->foreground = NULL;
    self->background = NULL;
    self->active_foreground = NULL;
    self->active_background = NULL;
    self->disabled_foreground = NULL;
    self->highlight_background = NULL;
    self->highlight_color = NULL;
    self->border_width = 1.0;
    self->highlight_thickness = 0.0;
    self->alignment = CENTER;
    self->padx = 1.0;
    self->pady = 1.0;
    self->relief = FLAT;
    self->state = NORMAL;
    self->take_focus = false;
    self->underline = -1;
    self->width = 0.0;
    self->height = 0.0;
    self->text = NULL;
    self->font = NULL;
    self->anchor = C;
    self->wrap_length = 0;
    self->minimum_size = NULL;
    return (PyObject*)self;
}

static int
Label_init(LabelObject *self, PyObject *args, PyObject *keywords)
{
    WidgetObject* widget;
    LabelView *label;
    CFStringRef text = CFSTR("");
    NSRect rect;
    FontObject* font = default_font_object;

    static char* kwlist[] = {"text", "font", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|O&O!", kwlist, string_converter, &text, &FontType, &font))
        return -1;

/*
    TkWindow* parentPtr;
    TkDisplay *dispPtr = parentPtr->dispPtr;
    int screenNum = parentPtr->screenNum;

    if ((parentPtr != NULL) && (parentPtr->display == winPtr->display)
            && (parentPtr->screenNum == winPtr->screenNum)) {
        winPtr->visual = parentPtr->visual;
        winPtr->depth = parentPtr->depth;
    } else {
        winPtr->visual = DefaultVisual(dispPtr->display, screenNum);
        winPtr->depth = DefaultDepth(dispPtr->display, screenNum);
    }
    winPtr->window = None;
    winPtr->childList = NULL;
    winPtr->lastChildPtr = NULL;
    winPtr->parentPtr = NULL;
    winPtr->nextPtr = NULL;
    winPtr->mainPtr = NULL;
    winPtr->pathName = NULL;
    winPtr->nameUid = NULL;
    winPtr->classUid = NULL;
    winPtr->changes = defChanges;
    winPtr->dirtyChanges = CWX|CWY|CWWidth|CWHeight|CWBorderWidth;
    winPtr->atts = defAtts;
    if ((parentPtr != NULL) && (parentPtr->display == winPtr->display)
            && (parentPtr->screenNum == winPtr->screenNum)) {
        winPtr->atts.colormap = parentPtr->atts.colormap;
    } else {
        winPtr->atts.colormap = DefaultColormap(dispPtr->display, screenNum);
    }
    winPtr->dirtyAtts = CWEventMask|CWColormap|CWBitGravity;
    winPtr->flags = 0;
    winPtr->handlerList = NULL;
#ifdef TK_USE_INPUT_METHODS
    winPtr->ximGeneration = 0;
    winPtr->inputContext = NULL;
#endif
    winPtr->tagPtr = NULL;
    winPtr->numTags = 0;
    winPtr->optionLevel = -1;
    winPtr->selHandlerList = NULL;
    winPtr->geomMgrPtr = NULL;
    winPtr->geomData = NULL;
    winPtr->geomMgrName = NULL;
    winPtr->maintainerPtr = NULL;
    winPtr->reqWidth = winPtr->reqHeight = 1;
    winPtr->internalBorderLeft = 0;
    winPtr->wmInfoPtr = NULL;
    winPtr->classProcsPtr = NULL;
    winPtr->instanceData = NULL;
    winPtr->privatePtr = NULL;
    winPtr->internalBorderRight = 0;
    winPtr->internalBorderTop = 0;
    winPtr->internalBorderBottom = 0;
    winPtr->minReqWidth = 0;
    winPtr->minReqHeight = 0;

    optionTable = Tk_CreateOptionTable(interp, optionSpecs[type]);

    Tk_SetClass(tkwin, classNames[type]);
    butPtr = TkpCreateButton(tkwin);

    Tk_SetClassProcs(tkwin, &tkpButtonProcs, butPtr);
    butPtr->tkwin = tkwin;
    butPtr->display = Tk_Display(tkwin);
    butPtr->interp = interp;
    butPtr->widgetCmd = Tcl_CreateObjCommand(interp, Tk_PathName(tkwin),
            ButtonWidgetObjCmd, butPtr, ButtonCmdDeletedProc);
    butPtr->type = type;
    butPtr->optionTable = optionTable;
    butPtr->textPtr = NULL;
    butPtr->underline = -1;
    butPtr->textVarNamePtr = NULL;
    butPtr->bitmap = None;
    butPtr->imagePtr = NULL;
    butPtr->image = NULL;
    butPtr->selectImagePtr = NULL;
    butPtr->selectImage = NULL;
    butPtr->tristateImagePtr = NULL;
    butPtr->tristateImage = NULL;
    butPtr->state = STATE_NORMAL;
    butPtr->normalBorder = NULL;
    butPtr->activeBorder = NULL;
    butPtr->borderWidthPtr = NULL;
    butPtr->borderWidth = 0;
    butPtr->relief = TK_RELIEF_FLAT;
    butPtr->highlightWidthPtr = NULL;
    butPtr->highlightWidth = 0;
    butPtr->highlightBorder = NULL;
    butPtr->highlightColorPtr = NULL;
    butPtr->inset = 0;
    butPtr->tkfont = NULL;
    butPtr->normalFg = NULL;
    butPtr->activeFg = NULL;
    butPtr->disabledFg = NULL;
    butPtr->normalTextGC = NULL;
    butPtr->activeTextGC = NULL;
    butPtr->disabledGC = NULL;
    butPtr->stippleGC = NULL;
    butPtr->gray = None;
    butPtr->copyGC = NULL;
    butPtr->widthPtr = NULL;
    butPtr->width = 0;
    butPtr->heightPtr = NULL;
    butPtr->height = 0;
    butPtr->wrapLengthPtr = NULL;
    butPtr->wrapLength = 0;
    butPtr->padXPtr = NULL;
    butPtr->padX = 0;
    butPtr->padYPtr = NULL;
    butPtr->padY = 0;
    butPtr->anchor = TK_ANCHOR_CENTER;
    butPtr->justify = TK_JUSTIFY_CENTER;
    butPtr->indicatorOn = 0;
    butPtr->selectBorder = NULL;
    butPtr->textWidth = 0;
    butPtr->textHeight = 0;
    butPtr->textLayout = NULL;
    butPtr->indicatorSpace = 0;
    butPtr->indicatorDiameter = 0;
    butPtr->defaultState = DEFAULT_DISABLED;
    butPtr->selVarNamePtr = NULL;
    butPtr->onValuePtr = NULL;
    butPtr->offValuePtr = NULL;
    butPtr->tristateValuePtr = NULL;
    butPtr->cursor = NULL;
    butPtr->takeFocusPtr = NULL;
    butPtr->commandPtr = NULL;
    butPtr->flags = 0;

    Tk_CreateEventHandler(butPtr->tkwin,
            ExposureMask|StructureNotifyMask|FocusChangeMask,
            ButtonEventProc, butPtr);

    if (Tk_InitOptions(interp, (char *) butPtr, optionTable, tkwin)
            != TCL_OK) {
        Tk_DestroyWindow(butPtr->tkwin);
        return TCL_ERROR;
    }
    if (ConfigureButton(interp, butPtr, objc - 2, objv + 2) != TCL_OK) {
        Tk_DestroyWindow(butPtr->tkwin);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, TkNewWindowObj(butPtr->tkwin));
    return TCL_OK;
*/

    widget = (WidgetObject*)self;
    rect.origin.x = 0;
    rect.origin.y = 0;
    rect.size.width = 100;
    rect.size.height = 100;
    label = [[LabelView alloc] initWithFrame: rect withObject: (PyObject*)self];

    Py_INCREF(font);
    widget->view = label;
    self->text = text;
    self->font = font;

    Py_INCREF(systemWindowBackgroundColor);
    Py_INCREF(systemTextColor);
    Py_INCREF(systemWindowBackgroundColor);
    Py_XDECREF(self->foreground);
    Py_XDECREF(self->background);
    Py_XDECREF(self->active_foreground);
    Py_XDECREF(self->active_background);
    Py_XDECREF(self->disabled_foreground);
    Py_XDECREF(self->highlight_background);
    Py_XDECREF(self->highlight_color);
    self->foreground = systemTextColor;
    self->background = systemWindowBackgroundColor;
    self->active_foreground = systemTextColor;
    self->active_background = systemWindowBackgroundColor;
    self->disabled_foreground = systemTextColor;
    self->highlight_background = systemWindowBackgroundColor;
    self->highlight_color = systemWindowBackgroundColor;

    self->anchor = C;

    return 0;
}

static PyObject*
Label_repr(LabelObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    return PyUnicode_FromFormat("Label object %p wrapping NSView %p",
                               self, widget->view);
}

static void
Label_dealloc(LabelObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    LabelView* label = (LabelView*) (widget->view);
    CFStringRef text = self->text;
    FontObject* font = self->font;
    if (label) [label release];
    if (font) Py_DECREF(font);
    if (text) CFRelease(text);
    Py_XDECREF(self->foreground);
    Py_XDECREF(self->background);
    Py_XDECREF(self->active_foreground);
    Py_XDECREF(self->active_background);
    Py_XDECREF(self->disabled_foreground);
    Py_XDECREF(self->highlight_background);
    Py_XDECREF(self->highlight_color);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Label_set_position(LabelObject* self, PyObject *args)
{
    float x;
    float y;
    NSPoint position;
    WidgetObject* widget = (WidgetObject*)self;
    LabelView* label = (LabelView*) (widget->view);
    if (!label) {
        PyErr_SetString(PyExc_RuntimeError, "label has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ff", &x, &y))
        return NULL;

    position.x = x;
    position.y = y;
    [label setFrameOrigin: position];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Label_methods[] = {
    {"set_position",
     (PyCFunction)Label_set_position,
     METH_VARARGS,
     "Moves the label to the new position."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Label_get_text(LabelObject* self, void* closure)
{
    return PyString_FromCFString(self->text);
}

static int
Label_set_text(LabelObject* self, PyObject* value, void* closure)
{
    CFStringRef text;
    Window* window;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    text = PyString_AsCFString(value);
    if (!text) return -1;
    if (self->text) CFRelease(self->text);
    self->text = text;
    if (self->minimum_size) {
        Py_DECREF(self->minimum_size);
        self->minimum_size = NULL;
    }
    label.needsDisplay = YES;
    window = (Window*) [label window];
    [window requestLayout];
    return 0;
}

static char Label_text__doc__[] = "label text.";

static PyObject* Label_get_font(LabelObject* self, void* closure)
{
    PyObject* font = (PyObject*) self->font;
    Py_INCREF(font);
    return font;
}

static int
Label_set_font(LabelObject* self, PyObject* value, void* closure)
{
    Window* window;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyObject_IsInstance(value, (PyObject *)&FontType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Font object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->font);
    self->font = (FontObject*) value;
    if (self->minimum_size) {
        Py_DECREF(self->minimum_size);
        self->minimum_size = NULL;
    }
    label.needsDisplay = YES;
    window = (Window*) [label window];
    [window requestLayout];
    return 0;
}

static char Label_font__doc__[] = "font for label";

static PyObject* Label_get_active_foreground(LabelObject* self, void* closure)
{
    Py_INCREF(self->active_foreground);
    return (PyObject*) self->active_foreground;
}

static int
Label_set_active_foreground(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->active_foreground);
    self->active_foreground = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_active_foreground__doc__[] = "active foreground color.";

static PyObject* Label_get_active_background(LabelObject* self, void* closure)
{
    Py_INCREF(self->active_background);
    return (PyObject*) self->active_background;
}

static int
Label_set_active_background(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->active_background);
    self->active_background = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_active_background__doc__[] = "background color if active.";

static PyObject* Label_get_highlight_background(LabelObject* self, void* closure)
{
    Py_INCREF(self->highlight_background);
    return (PyObject*) self->highlight_background;
}

static int
Label_set_highlight_background(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->highlight_background);
    self->highlight_background = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_highlight_background__doc__[] = "background color when the label does not have focus.";

static PyObject* Label_get_highlight_color(LabelObject* self, void* closure)
{
    Py_INCREF(self->highlight_color);
    return (PyObject*) self->highlight_color;
}

static int
Label_set_highlight_color(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->highlight_color);
    self->highlight_color = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_highlight_color__doc__[] = "background color when the label has focus.";

static PyObject* Label_get_foreground(LabelObject* self, void* closure)
{
    Py_INCREF(self->foreground);
    return (PyObject*) self->foreground;
}

static int
Label_set_foreground(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->foreground);
    self->foreground = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_foreground__doc__[] = "foreground color.";

static PyObject* Label_get_background(LabelObject* self, void* closure)
{
    Py_INCREF(self->background);
    return (PyObject*) self->background;
}

static int
Label_set_background(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->background);
    self->background = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_background__doc__[] = "background color.";

static PyObject* Label_get_disabled_foreground(LabelObject* self, void* closure)
{
    Py_INCREF(self->disabled_foreground);
    return (PyObject*) self->disabled_foreground;
}

static int
Label_set_disabled_foreground(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->disabled_foreground);
    self->disabled_foreground = (ColorObject*) value;
    label.needsDisplay = YES;
    return 0;
}

static char Label_disabled_foreground__doc__[] = "foreground color when disabled.";

static PyObject* Label_get_state(LabelObject* self, void* closure)
{
    switch (self->state) {
        case NORMAL: return PyUnicode_FromString("NORMAL");
        case ACTIVE: return PyUnicode_FromString("ACTIVE");
        case DISABLED: return PyUnicode_FromString("DISABLED");
        default:
            PyErr_Format(PyExc_RuntimeError,
                "expected NORMAL (%d), ACTIVE (%d), or DISABLED (%d), got %d",
                NORMAL, ACTIVE, DISABLED, self->state);
            return NULL;
    }
}

static int
Label_set_state(LabelObject* self, PyObject* value, void* closure)
{
    const char* state;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyUnicode_Check(value)) {
        PyErr_SetString(PyExc_ValueError, "expected a string");
        return -1;
    }
    state = PyUnicode_AsUTF8(value);
    if (!state) return -1;
    if (PyOS_stricmp(state, "NORMAL")==0) self->state = NORMAL;
    else if (PyOS_stricmp(state, "ACTIVE")==0) self->state = ACTIVE;
    else if (PyOS_stricmp(state, "DISABLED")==0) self->state = DISABLED;
    else {
        PyErr_Format(PyExc_ValueError,
            "expected 'NORMAL', 'ACTIVE', 'DISABLED (case-insensitive)' "
            "got %s", state);
        return -1;
    }
    label.needsDisplay = YES;
    return 0;
}

static char Label_state__doc__[] = "state of the label ('NORMAL', 'ACTIVE', or 'DISABLED').";

static PyObject* Label_get_take_focus(LabelObject* self, void* closure)
{
    if (self->take_focus) Py_RETURN_TRUE;
    else Py_RETURN_FALSE;
}

static int
Label_set_take_focus(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (value == Py_True) self->take_focus = true;
    else if (value == Py_False) self->take_focus = false;
    else {
        PyErr_SetString(PyExc_ValueError, "expected either True or False");
        return -1;
    }
    label.needsDisplay = YES;
    return 0;
}

static char Label_take_focus__doc__[] = "True if the label accepts the focus during keyboard traversal, False otherwise.";

static PyObject* Label_get_relief(LabelObject* self, void* closure)
{
    switch (self->relief) {
        case RAISED: return PyUnicode_FromString("RAISED");
        case SUNKEN: return PyUnicode_FromString("SUNKEN");
        case FLAT: return PyUnicode_FromString("FLAT");
        case RIDGE: return PyUnicode_FromString("RIDGE");
        case SOLID: return PyUnicode_FromString("SOLID");
        case GROOVE: return PyUnicode_FromString("GROOVE");
        default:
            PyErr_Format(PyExc_RuntimeError,
                "expected RAISED (%d), SUNKEN (%d), FLAT (%d), RIDGE (%d) "
                "SOLID (%d), or GROOVE (%d), got %d",
                RAISED, SUNKEN, FLAT, RIDGE, SOLID, GROOVE, self->relief);
            return NULL;
    }
}

static int
Label_set_relief(LabelObject* self, PyObject* value, void* closure)
{
    const char* relief;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyUnicode_Check(value)) {
        PyErr_SetString(PyExc_ValueError, "expected a string");
        return -1;
    }
    relief = PyUnicode_AsUTF8(value);
    if (!relief) return -1;
    if (PyOS_stricmp(relief, "RAISED")==0) self->relief = RAISED;
    else if (PyOS_stricmp(relief, "SUNKEN")==0) self->relief = SUNKEN;
    else if (PyOS_stricmp(relief, "FLAT")==0) self->relief = FLAT;
    else if (PyOS_stricmp(relief, "RIDGE")==0) self->relief = RIDGE;
    else if (PyOS_stricmp(relief, "SOLID")==0) self->relief = SOLID;
    else if (PyOS_stricmp(relief, "GROOVE")==0) self->relief = GROOVE;
    else {
        PyErr_Format(PyExc_ValueError,
            "expected 'RAISED', 'SUNKEN', 'FLAT', 'RIDGE', 'SOLID', 'GROOVE' "
            "(case-insensitive), got %s.", relief);
        return -1;
    }
    label.needsDisplay = YES;
    return 0;
}

static char Label_relief__doc__[] = "desired 3D effect of the label ('NORMAL', 'ACTIVE', or 'DISABLED').";

static PyObject* Label_get_border_width(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->border_width);
}

static int
Label_set_border_width(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat border_width = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->border_width = border_width;
    label.needsDisplay = YES;
    return 0;
}

static char Label_border_width__doc__[] = "width of the 3-D border to draw around the outside of the label.";

static PyObject* Label_get_padx(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->padx);
}

static int
Label_set_padx(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat padx = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->padx = padx;
    label.needsDisplay = YES;
    return 0;
}

static char Label_padx__doc__[] = "extra space to request for the label in the X-direction.";

static PyObject* Label_get_pady(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->pady);
}

static int
Label_set_pady(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat pady = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->pady = pady;
    label.needsDisplay = YES;
    return 0;
}

static char Label_pady__doc__[] = "extra space to request for the label in the Y-direction.";

static PyObject* Label_get_highlight_thickness(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->highlight_thickness);
}

static int
Label_set_highlight_thickness(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat highlight_thickness = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->highlight_thickness = highlight_thickness;
    label.needsDisplay = YES;
    return 0;
}

static char Label_highlight_thickness__doc__[] = "width of the highlight rectangle to draw around the outside of the label when it has the input focus.";

static PyObject* Label_get_anchor(LabelObject* self, void* closure)
{
    switch (self->anchor) {
        case N: return PyUnicode_FromString("N");
        case NE: return PyUnicode_FromString("NE");
        case E: return PyUnicode_FromString("E");
        case SE: return PyUnicode_FromString("SE");
        case S: return PyUnicode_FromString("S");
        case SW: return PyUnicode_FromString("SW");
        case W: return PyUnicode_FromString("W");
        case NW: return PyUnicode_FromString("NW");
        case C: return PyUnicode_FromString("CENTER");
        default:
            PyErr_Format(PyExc_RuntimeError,
                "expected N (%d), NE (%d), E (%d), SE (%d), S (%d), SW (%d), "
                "W (%d), NW (%d), or C (%d), got %d",
                N, NE, E, SE, S, SW, W, NW, C, self->anchor);
            return NULL;
    }
}

static int
Label_set_anchor(LabelObject* self, PyObject* value, void* closure)
{
    const char* anchor;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyUnicode_Check(value)) {
        PyErr_SetString(PyExc_ValueError, "expected a string");
        return -1;
    }
    anchor = PyUnicode_AsUTF8(value);
    if (!anchor) return -1;
    if (PyOS_stricmp(anchor, "N")==0) self->anchor = N;
    else if (PyOS_stricmp(anchor, "NE")==0) self->anchor = NE;
    else if (PyOS_stricmp(anchor, "E")==0) self->anchor = E;
    else if (PyOS_stricmp(anchor, "SE")==0) self->anchor = SE;
    else if (PyOS_stricmp(anchor, "S")==0) self->anchor = S;
    else if (PyOS_stricmp(anchor, "SW")==0) self->anchor = SW;
    else if (PyOS_stricmp(anchor, "W")==0) self->anchor = W;
    else if (PyOS_stricmp(anchor, "NW")==0) self->anchor = NW;
    else if (PyOS_stricmp(anchor, "CENTER")==0) self->anchor = C;
    else {
        PyErr_Format(PyExc_ValueError,
            "expected 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', "
            "or 'CENTER' (case-insensitive), got %s", anchor);
        return -1;
    }
    label.needsDisplay = YES;
    return 0;
}

static char Label_anchor__doc__[] = "anchor specifying location of the label.";

static PyObject* Label_calculate_minimum_size(LabelObject* self)
{
    CGFloat ascent;
    CGFloat descent;
    CGFloat width;
    CGFloat height;
    CTLineRef line;
    CFAttributedStringRef string;
    CFDictionaryRef attributes;
    CFStringRef keys[1];
    CFTypeRef values[1];
    keys[0] = kCTFontAttributeName;
    values[0] = self->font->font;
    attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                    (const void**)&keys,
                                    (const void**)&values,
                                    1,
                                    &kCFTypeDictionaryKeyCallBacks,
                                    &kCFTypeDictionaryValueCallBacks);
    if (!attributes) return PyErr_NoMemory();
    string = CFAttributedStringCreate(kCFAllocatorDefault,
                                      self->text,
                                      attributes);
    CFRelease(attributes);
    if (!string) return PyErr_NoMemory();
    line = CTLineCreateWithAttributedString(string);
    CFRelease(string);
    if (!line) return PyErr_NoMemory();
    width = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
    height = ascent + descent;
    width += 2 * (self->padx + self->highlight_thickness + self->border_width);
    height += 2 * (self->pady + self->highlight_thickness + self->border_width);
    return Py_BuildValue("ff", width, height);
}

static PyObject* Label_get_minimum_size(LabelObject* self, void* closure)
{
    PyObject* minimum_size = self->minimum_size;
    if (minimum_size==NULL) {
        minimum_size = Label_calculate_minimum_size(self);
        self->minimum_size = minimum_size;
    }
    Py_INCREF(minimum_size);
    return minimum_size;
}

static char Label_minimum_size__doc__[] = "minimum size needed to show the label.";

static PyGetSetDef Label_getseters[] = {
    {"text", (getter)Label_get_text, (setter)Label_set_text, Label_text__doc__, NULL},
    {"font", (getter)Label_get_font, (setter)Label_set_font, Label_font__doc__, NULL},
    {"foreground", (getter)Label_get_foreground, (setter)Label_set_foreground, Label_foreground__doc__, NULL},
    {"background", (getter)Label_get_background, (setter)Label_set_background, Label_background__doc__, NULL},
    {"active_foreground", (getter)Label_get_active_foreground, (setter)Label_set_active_foreground, Label_active_foreground__doc__, NULL},
    {"active_background", (getter)Label_get_active_background, (setter)Label_set_active_background, Label_active_background__doc__, NULL},
    {"disabled_foreground", (getter)Label_get_disabled_foreground, (setter)Label_set_disabled_foreground, Label_disabled_foreground__doc__, NULL},
    {"highlight_background", (getter)Label_get_highlight_background, (setter)Label_set_highlight_background, Label_highlight_background__doc__, NULL},
    {"highlight_color", (getter)Label_get_highlight_color, (setter)Label_set_highlight_color, Label_highlight_color__doc__, NULL},
    {"relief", (getter)Label_get_relief, (setter)Label_set_relief, Label_relief__doc__, NULL},
    {"state", (getter)Label_get_state, (setter)Label_set_state, Label_state__doc__, NULL},
    {"take_focus", (getter)Label_get_take_focus, (setter)Label_set_take_focus, Label_take_focus__doc__, NULL},
    {"anchor", (getter)Label_get_anchor, (setter)Label_set_anchor, Label_anchor__doc__, NULL},
    {"border_width", (getter)Label_get_border_width, (setter)Label_set_border_width, Label_border_width__doc__, NULL},
    {"padx", (getter)Label_get_padx, (setter)Label_set_padx, Label_padx__doc__, NULL},
    {"pady", (getter)Label_get_pady, (setter)Label_set_pady, Label_pady__doc__, NULL},
    {"highlight_thickness", (getter)Label_get_highlight_thickness, (setter)Label_set_highlight_thickness, Label_highlight_thickness__doc__, NULL},
    {"minimum_size", (getter)Label_get_minimum_size, (setter)NULL, Label_minimum_size__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Label_doc[] =
"A Label object wraps a Cocoa NSTextField object.\n";

PyTypeObject LabelType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Label",             /* tp_name */
    sizeof(LabelObject),        /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Label_dealloc,  /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Label_repr,       /* tp_repr */
    0,                          /* tp_as_number */
    0,                          /* tp_as_sequence */
    0,                          /* tp_as_mapping */
    0,                          /* tp_hash */
    0,                          /* tp_call */
    0,                          /* tp_str */
    0,                          /* tp_getattro */
    0,                          /* tp_setattro */
    0,                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,        /* tp_flags */
    Label_doc,                  /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Label_methods,              /* tp_methods */
    0,                          /* tp_members */
    Label_getseters,            /* tp_getset */
    &WidgetType,                /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Label_init,       /* tp_init */
    0,                          /* tp_alloc */
    Label_new,                  /* tp_new */
};
