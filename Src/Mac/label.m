#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "window.h"
#include "colors.h"
#include "image.h"
#include "text.h"
#include "font.h"


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 10100
#define COMPILING_FOR_10_10
#endif

typedef enum {LEFT, CENTER, RIGHT} Alignment;

typedef enum {PY_COMPOUND_NONE,
              PY_COMPOUND_BOTTOM,
              PY_COMPOUND_TOP,
              PY_COMPOUND_LEFT,
              PY_COMPOUND_RIGHT,
              PY_COMPOUND_CENTER} Compound;

typedef enum {PY_RELIEF_RAISED,
              PY_RELIEF_SUNKEN,
              PY_RELIEF_FLAT,
              PY_RELIEF_RIDGE,
              PY_RELIEF_SOLID,
              PY_RELIEF_GROOVE} Relief;

typedef enum {NORMAL, ACTIVE, DISABLED} State;


@interface LabelView : WidgetView
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
    double xalign;
    double yalign;
    double padx;
    double pady;
    Compound compound;
    ImageObject* image;
    State state;
    CFStringRef text;
    FontObject* font;
    CTLineRef line;
    CTFrameRef frame;
    Py_ssize_t underline;
    size_t wraplength;
    bool take_focus;
    bool is_first_responder;
} LabelObject;


static void _get_dark_shadow(unsigned short* red, unsigned short* green, unsigned short *blue)
/* TkpGetShadows */
{
    const unsigned short r = *red;
    const unsigned short g = *green;
    const unsigned short b = *blue;
    if (r*0.5*r + g*1.0*g + b*0.28*b < USHRT_MAX*0.05*USHRT_MAX) {
        *red = (USHRT_MAX + 3*r)/4;
        *green = (USHRT_MAX + 3*g)/4;
        *blue = (USHRT_MAX + 3*b)/4;
    } else {
        *red = (60 * r)/100;
        *green = (60 * g)/100;
        *blue = (60 * b)/100;
    }
}

static void _get_light_shadow(unsigned short* red, unsigned short* green, unsigned short *blue)
/* TkpGetShadows */
{
    const unsigned short r = *red;
    const unsigned short g = *green;
    const unsigned short b = *blue;
    if (g > USHRT_MAX * 0.95) {
        *red = (90 * r)/100;
        *green = (90 * g)/100;
        *blue = (90 * b)/100;
    } else {
        int tmp1, tmp2;
        tmp1 = (14 * r)/10;
        if (tmp1 > USHRT_MAX) {
            tmp1 = USHRT_MAX;
        }
        tmp2 = (USHRT_MAX + r)/2;
        *red = (tmp1 > tmp2) ? tmp1 : tmp2;
        tmp1 = (14 * g)/10;
        if (tmp1 > USHRT_MAX) {
            tmp1 = USHRT_MAX;
        }
        tmp2 = (USHRT_MAX + g)/2;
        *green = (tmp1 > tmp2) ? tmp1 : tmp2;
        tmp1 = (14 * b)/10;
        if (tmp1 > USHRT_MAX) {
            tmp1 = USHRT_MAX;
        }
        tmp2 = (USHRT_MAX + b)/2;
        *blue = (tmp1 > tmp2) ? tmp1 : tmp2;
    }
}

/* Tk_3DVerticalBevel */
static void
_draw_3d_vertical_bevel(CGContextRef cr,
                        ColorObject* color,
                        CGFloat x, CGFloat y,
                        CGFloat width, CGFloat height,
                        bool left_bevel, Relief relief)
{
    unsigned short red = color->rgba[0];
    unsigned short green = color->rgba[1];
    unsigned short blue = color->rgba[2];
    unsigned short alpha = color->rgba[3];

    if (relief == PY_RELIEF_RAISED) {
        CGRect rect = CGRectMake(x, y, width, height);
        if (left_bevel) {
            _get_light_shadow(&red, &green, &blue);
        } else {
            _get_dark_shadow(&red, &green, &blue);
        }
        CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                     ((CGFloat)green)/USHRT_MAX,
                                     ((CGFloat)blue)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
    } else if (relief == PY_RELIEF_SUNKEN) {
        CGRect rect = CGRectMake(x, y, width, height);
        if (left_bevel) {
            _get_dark_shadow(&red, &green, &blue);
        } else {
            _get_light_shadow(&red, &green, &blue);
        }
        CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                     ((CGFloat)green)/USHRT_MAX,
                                     ((CGFloat)blue)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
    } else if (relief == PY_RELIEF_RIDGE) {
        unsigned short red_shadow;
        unsigned short green_shadow;
        unsigned short blue_shadow;
        CGRect rect;
        CGFloat half = width/2;
        if (!left_bevel && (width > 0.0)) half++;
        red_shadow = red;
        green_shadow = green;
        blue_shadow = blue;
        _get_light_shadow(&red_shadow, &green_shadow, &blue_shadow);
        rect.origin.x = x;
        rect.origin.y = y;
        rect.size.width = half;
        rect.size.height = height;
        CGContextSetRGBFillColor(cr, ((CGFloat)red_shadow)/USHRT_MAX,
                                     ((CGFloat)green_shadow)/USHRT_MAX,
                                     ((CGFloat)blue_shadow)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
        rect.origin.x = x + half;
        rect.size.width = width - half;
        red_shadow = red;
        green_shadow = green;
        blue_shadow = blue;
        _get_dark_shadow(&red_shadow, &green_shadow, &blue_shadow);
        CGContextSetRGBFillColor(cr, ((CGFloat)red_shadow)/USHRT_MAX,
                                     ((CGFloat)green_shadow)/USHRT_MAX,
                                     ((CGFloat)blue_shadow)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
    } else if (relief == PY_RELIEF_GROOVE) {
        unsigned short red_shadow;
        unsigned short green_shadow;
        unsigned short blue_shadow;
        CGRect rect;
        CGFloat half = width/2;
        if (!left_bevel && (width > 0.0)) half++;
        red_shadow = red;
        green_shadow = green;
        blue_shadow = blue;
        _get_dark_shadow(&red_shadow, &green_shadow, &blue_shadow);
        rect.origin.x = x;
        rect.origin.y = y;
        rect.size.width = half;
        rect.size.height = height;
        CGContextSetRGBFillColor(cr, ((CGFloat)red_shadow)/USHRT_MAX,
                                     ((CGFloat)green_shadow)/USHRT_MAX,
                                     ((CGFloat)blue_shadow)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
        rect.origin.x = x + half;
        rect.size.width = width - half;
        red_shadow = red;
        green_shadow = green;
        blue_shadow = blue;
        _get_light_shadow(&red_shadow, &green_shadow, &blue_shadow);
        CGContextSetRGBFillColor(cr, ((CGFloat)red_shadow)/USHRT_MAX,
                                     ((CGFloat)green_shadow)/USHRT_MAX,
                                     ((CGFloat)blue_shadow)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
    } else if (relief == PY_RELIEF_FLAT) {
        CGRect rect = CGRectMake(x, y, width, height);
        CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                     ((CGFloat)green)/USHRT_MAX,
                                     ((CGFloat)blue)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);
        CGContextFillRect(cr, rect);
    } else if (relief == PY_RELIEF_SOLID) {
        CGRect rect = CGRectMake(x, y, width, height);
        CGContextSetRGBFillColor(cr, 0.0, 0.0, 0.0, 1.0);
        CGContextFillRect(cr, rect);
    }
}

/* Tk_3DHorizontalBevel */
static void
_draw_3d_horizontal_bevel(CGContextRef cr,
                          ColorObject* color,
                          CGFloat x, CGFloat y,
                          CGFloat width, CGFloat height,
                          bool left_in, bool right_in, bool top_bevel,
                          Relief relief)
{
    int bottom, halfway, x1, x2, x1Delta, x2Delta;

    unsigned short red = color->rgba[0];
    unsigned short green = color->rgba[1];
    unsigned short blue = color->rgba[2];
    unsigned short alpha = color->rgba[3];

    unsigned short red_top = red;
    unsigned short green_top = green;
    unsigned short blue_top = blue;

    unsigned short red_bottom = red;
    unsigned short green_bottom = green;
    unsigned short blue_bottom = blue;

    switch (relief) {
    case PY_RELIEF_FLAT:
        break;
    case PY_RELIEF_GROOVE:
        _get_dark_shadow(&red_top, &green_top, &blue_top);
        _get_light_shadow(&red_bottom, &green_bottom, &blue_bottom);
        break;
    case PY_RELIEF_RAISED:
        if (top_bevel) {
            _get_light_shadow(&red_top, &green_top, &blue_top);
            _get_light_shadow(&red_bottom, &green_bottom, &blue_bottom);
        } else {
            _get_dark_shadow(&red_top, &green_top, &blue_top);
            _get_dark_shadow(&red_bottom, &green_bottom, &blue_bottom);
        }
        break;
    case PY_RELIEF_RIDGE:
        _get_light_shadow(&red_top, &green_top, &blue_top);
        _get_dark_shadow(&red_bottom, &green_bottom, &blue_bottom);
        break;
    case PY_RELIEF_SOLID: {
        CGRect rect = CGRectMake(x, y, width, height);
        CGContextSetRGBFillColor(cr, 0.0, 0.0, 0.0, 1.0);
        CGContextFillRect(cr, rect);
        return;
    }
    case PY_RELIEF_SUNKEN:
        if (top_bevel) {
            _get_dark_shadow(&red_top, &green_top, &blue_top);
            _get_dark_shadow(&red_bottom, &green_bottom, &blue_bottom);
        } else {
            _get_light_shadow(&red_top, &green_top, &blue_top);
            _get_light_shadow(&red_bottom, &green_bottom, &blue_bottom);
        }
        break;
    }

    x1 = x;
    if (!left_in) {
        x1 += height;
    }
    x2 = x+width;
    if (!right_in) {
        x2 -= height;
    }
    x1Delta = (left_in) ? 1 : -1;
    x2Delta = (right_in) ? -1 : 1;
    halfway = y + height/2;
    if (!top_bevel && (height > 0)) {
        halfway++;
    }
    bottom = y + height;

    /* use CGContextDrawPath */
    for ( ; y < bottom; y++) {
        if (x1 < SHRT_MIN) {
            x1 = SHRT_MIN;
        }
        if (x2 > SHRT_MAX) {
            x2 = SHRT_MAX;
        }
        if (x1 < x2) {
            CGRect rect = CGRectMake(x1, y, x2 - x1, 1);
            if (y < halfway)
                CGContextSetRGBFillColor(cr, ((CGFloat)red_top)/USHRT_MAX,
                                             ((CGFloat)green_top)/USHRT_MAX,
                                             ((CGFloat)blue_top)/USHRT_MAX,
                                             ((CGFloat)alpha)/USHRT_MAX);
            else
                CGContextSetRGBFillColor(cr, ((CGFloat)red_bottom)/USHRT_MAX,
                                             ((CGFloat)green_bottom)/USHRT_MAX,
                                             ((CGFloat)blue_bottom)/USHRT_MAX,
                                             ((CGFloat)alpha)/USHRT_MAX);
            CGContextFillRect(cr, rect);
        }
        x1 += x1Delta;
        x2 += x2Delta;
    }
}

/* Tk_DrawFocusHighlight */
static void
_draw_focus_highlight(CGContextRef cr, ColorObject* color, CGRect rect, CGFloat width)
{
/*
    On X11: TkDrawInsetFocusHighlight(tkwin, gc, width, drawable, 0);
    On Max: TkMacOSXDrawSolidBorder
*/
    unsigned short red, green, blue, alpha;
    red = color->rgba[0];
    green = color->rgba[1];
    blue = color->rgba[2];
    alpha = color->rgba[3];
    CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                 ((CGFloat)green)/USHRT_MAX,
                                 ((CGFloat)blue)/USHRT_MAX,
                                 ((CGFloat)alpha)/USHRT_MAX);
    CGRect inner = CGRectInset(rect, width, width);
    CGContextBeginPath(cr);
    CGContextAddRect(cr, rect);
    CGContextAddRect(cr, inner);
    CGContextEOFillPath(cr);
}

@implementation LabelView
- (BOOL)becomeFirstResponder {
    ((LabelObject*)object)->is_first_responder = true;
    [self setNeedsDisplay:YES];
    return YES;
}

- (BOOL)resignFirstResponder {
    ((LabelObject*)object)->is_first_responder = false;
    [self setNeedsDisplay:YES];
    return YES;
}

- (BOOL)acceptsFirstResponder {
    LabelObject* label = (LabelObject*)object;
    if (label->take_focus) return YES;
    else return NO;
}

/* TkpDisplayButton */
- (void)drawRect:(NSRect)dirtyRect
{
    CGContextRef cr;
    NSGraphicsContext* gc;
    CGFloat x;
    CGFloat y;
    CGSize size;
    CGRect rect;
    CGFloat width = 0;
    CGFloat height = 0;
    CGFloat imageWidth;
    CGFloat imageHeight;
    unsigned short red, green, blue, alpha;
    LabelObject* label = (LabelObject*)object;
    WidgetObject* widget = (WidgetObject*)label;
    const Relief relief = label->relief;
    CGImageRef image = NULL;

    gc = [NSGraphicsContext currentContext];
#ifdef COMPILING_FOR_10_10
    cr = [gc CGContext];
#else
    cr = (CGContextRef) [gc graphicsPort];
#endif
    switch (label->state) {
        case ACTIVE:
            red = label->active_background->rgba[0];
            green = label->active_background->rgba[1];
            blue = label->active_background->rgba[2];
            alpha = label->active_background->rgba[3];
            break;
        case NORMAL:
        case DISABLED:
            red = label->background->rgba[0];
            green = label->background->rgba[1];
            blue = label->background->rgba[2];
            alpha = label->background->rgba[3];
            break;
    }

    CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                 ((CGFloat)green)/USHRT_MAX,
                                 ((CGFloat)blue)/USHRT_MAX,
                                 ((CGFloat)alpha)/USHRT_MAX);

    switch (widget->halign) {
        case 'f':
            rect.size.width = self.frame.size.width - widget->margin_left - widget->margin_right;
            rect.origin.x = widget->margin_left;
            break;
        case 'l':
            rect.size.width = widget->minimum_size.width - widget->margin_left - widget->margin_right;
            rect.origin.x = widget->margin_left;
            break;
        case 'r':
            rect.size.width = widget->minimum_size.width - widget->margin_left - widget->margin_right;
            rect.origin.x = self.frame.size.width - widget->margin_right - rect.size.width;
            break;
        case 'c':
            rect.size.width = widget->minimum_size.width - widget->margin_left - widget->margin_right;
            rect.origin.x = 0.5 * (self.frame.size.width - rect.size.width + widget->margin_left - widget->margin_right);
            break;
    }
    switch (widget->valign) {
        case 'f':
            rect.origin.y = widget->margin_top;
            rect.size.height = self.frame.size.height - widget->margin_top - widget->margin_bottom;
            break;
        case 't':
            rect.size.height = widget->minimum_size.height - widget->margin_top - widget->margin_bottom;
            rect.origin.y = widget->margin_top;
            break;
        case 'b':
            rect.size.height = widget->minimum_size.height - widget->margin_top - widget->margin_bottom;
            rect.origin.y = self.frame.size.height - widget->margin_bottom - rect.size.height;
            break;
        case 'c':
            rect.size.height = widget->minimum_size.height - widget->margin_top - widget->margin_bottom;
            rect.origin.y = 0.5 * (self.frame.size.height - rect.size.height + widget->margin_top - widget->margin_bottom);
            break;
    }

/*
    Tk_Fill3DRectangle(tkwin, pixmap, border, 0, 0, Tk_Width(tkwin),
            Tk_Height(tkwin), 0, TK_RELIEF_FLAT);
*/
    CGContextFillRect(cr, rect);
    /*
     * Display image or bitmap or text for button.
     */
    if (label->image) {
        image = label->image->data;
        width = CGImageGetWidth(image);
        height = CGImageGetHeight(image);
    }
    imageWidth = width;
    imageHeight = height;

    if (label->text) {
        double xalign = label->xalign;
        double yalign = label->yalign;
        switch (label->state) {
            case NORMAL:
                red = label->foreground->rgba[0];
                green = label->foreground->rgba[1];
                blue = label->foreground->rgba[2];
                alpha = label->foreground->rgba[3];
                break;
            case ACTIVE:
                red = label->active_foreground->rgba[0];
                green = label->active_foreground->rgba[1];
                blue = label->active_foreground->rgba[2];
                alpha = label->active_foreground->rgba[3];
                break;
            case DISABLED:
                red = label->disabled_foreground->rgba[0];
                green = label->disabled_foreground->rgba[1];
                blue = label->disabled_foreground->rgba[2];
                alpha = label->disabled_foreground->rgba[3];
                break;
        }
        CGContextSetRGBFillColor(cr, ((CGFloat)red)/USHRT_MAX,
                                     ((CGFloat)green)/USHRT_MAX,
                                     ((CGFloat)blue)/USHRT_MAX,
                                     ((CGFloat)alpha)/USHRT_MAX);

        x = rect.origin.x + label->padx;
        y = self.bounds.size.height - rect.origin.y - label->pady;
        if (label->line) {
            CGFloat ascent;
            CGFloat descent;
            CGFloat leading;
            size.width = CTLineGetTypographicBounds(label->line, &ascent, &descent, &leading);
            size.height = ascent + descent;
            y -= ascent;
        }
        if (label->frame) {
            CGPathRef path = CTFrameGetPath(label->frame);
            CGPathIsRect(path, &rect);
            size = rect.size;
            y -= size.height;
        }
	x += xalign * (rect.size.width - size.width - 2 * label->padx);
        y -= yalign * (rect.size.height - size.height - 2 * label->pady);

        CGContextSaveGState(cr);
        CGContextClipToRect(cr, self.bounds);
        CGContextTranslateCTM(cr, 0, self.bounds.size.height);
        CGContextScaleCTM(cr, 1.0, -1.0);
        CGContextTranslateCTM(cr, x, y);

        if (label->line) CTLineDraw(label->line, cr);
        else if (label->frame) CTFrameDraw(label->frame, cr);

        CGContextRestoreGState(cr);
    }

    if (relief != PY_RELIEF_FLAT) {
        ColorObject* color;
        CGFloat inset = label->highlight_thickness;
        CGFloat border_width = label->border_width;
        x = rect.origin.x + inset;
        y = rect.origin.y + inset;
        width = rect.size.width - 2 * inset;
        height = rect.size.height - 2 * inset;
        switch (label->state) {
            case ACTIVE:
                color = label->active_background;
                break;
            case NORMAL:
            case DISABLED:
                color = label->background;
                break;
        }
/*
        Tk_Draw3DRectangle(tkwin, pixmap, border, inset, inset,
                Tk_Width(tkwin) - 2*inset, Tk_Height(tkwin) - 2*inset,
                butPtr->borderWidth, relief);
*/
        if (width < 2 * border_width) border_width = width / 2.0;
        if (height < 2 * border_width) border_width = height / 2.0;
        _draw_3d_vertical_bevel(cr, color, x, y, border_width, height, true, relief);
        _draw_3d_vertical_bevel(cr, color, x+width-border_width, y, border_width, height, false, relief);
        _draw_3d_horizontal_bevel(cr, color, x, y, width, border_width, true, true, true, relief);
        _draw_3d_horizontal_bevel(cr, color, x, y+height-border_width, width, border_width, false, false, false, relief);
    }
    if (label->highlight_thickness > 0) {
        Window* window = (Window*) [self window];
        ColorObject* color;
        if (window.object->is_key && label->is_first_responder) {
            color = label->highlight_color;
        }
        else {
            color = label->highlight_background;
        }
/*
            Tk_DrawFocusHighlight(tkwin, gc, butPtr->highlightWidth, pixmap);
*/
        _draw_focus_highlight(cr, color, rect, label->highlight_thickness);
    }
    if (image) {
        CGRect rect;
        rect.origin.x = 0;
        rect.origin.y = 0;
        rect.size.width = imageWidth;
        rect.size.height = imageHeight;
        CGContextDrawImage(cr, rect, image);
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
    widget->minimum_size = CGSizeZero;
    self->foreground = NULL;
    self->background = NULL;
    self->active_foreground = NULL;
    self->active_background = NULL;
    self->disabled_foreground = NULL;
    self->highlight_background = NULL;
    self->highlight_color = NULL;
    self->border_width = 0.0;
    self->highlight_thickness = 0.0;
    self->alignment = CENTER;
    self->padx = 0.0;
    self->pady = 0.0;
    self->xalign = 0.5;
    self->yalign = 0.5;
    self->relief = PY_RELIEF_FLAT;
    self->state = NORMAL;
    self->take_focus = false;
    self->is_first_responder = false;
    self->underline = -1;
    self->width = 0.0;
    self->height = 0.0;
    self->text = NULL;
    self->font = NULL;
    self->line = NULL;
    self->image = NULL;
    self->compound = PY_COMPOUND_NONE;
    self->wraplength = 0;
    return (PyObject*)self;
}

static int
compound_converter(PyObject* argument, void* pointer)
{
    const char* value;
    Compound* compound = pointer;
    if (argument == NULL) return 1;
    if (!PyUnicode_Check(argument)) {
        PyErr_SetString(PyExc_ValueError, "expected a string");
        return 0;
    }
    value = PyUnicode_AsUTF8(argument);
    if (!value) return 0;
    if (PyOS_stricmp(value, "N")==0
     || PyOS_stricmp(value, "NONE")==0) *compound = PY_COMPOUND_NONE;
    else if (PyOS_stricmp(value, "B")==0
          || PyOS_stricmp(value, "BOTTOM")==0) *compound = PY_COMPOUND_BOTTOM;
    else if (PyOS_stricmp(value, "T")==0
          || PyOS_stricmp(value, "TOP")==0) *compound = PY_COMPOUND_TOP;
    else if (PyOS_stricmp(value, "B")==0
          || PyOS_stricmp(value, "BOTTOM")==0) *compound = PY_COMPOUND_BOTTOM;
    else if (PyOS_stricmp(value, "L")==0
          || PyOS_stricmp(value, "LEFT")==0) *compound = PY_COMPOUND_LEFT;
    else if (PyOS_stricmp(value, "R")==0
          || PyOS_stricmp(value, "RIGHT")==0) *compound = PY_COMPOUND_RIGHT;
    else if (PyOS_stricmp(value, "C")==0
          || PyOS_stricmp(value, "CENTER")==0) *compound = PY_COMPOUND_CENTER;
    else {
        PyErr_Format(PyExc_ValueError,
            "expected 'NONE', 'N', 'BOTTOM', 'B', 'TOP', 'T', "
            "'LEFT', 'L', 'RIGHT', 'R', 'CENTER', or 'C' "
            "(case-insensitive), got '%s'", value);
        return 0;
    }
    return Py_CLEANUP_SUPPORTED;
}


static int
Label_init(LabelObject *self, PyObject *args, PyObject *keywords)
{
    WidgetObject* widget;
    LabelView *label;
    CFStringRef text = NULL;
    NSRect rect;
    FontObject* font = default_font_object;
    ImageObject* image = NULL;
    Compound compound = PY_COMPOUND_NONE;

    static char* kwlist[] = {"text", "font", "image", "compound", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|O&O!O!O&", kwlist,
                                     string_converter, &text,
                                     &FontType, &font,
                                     &ImageType, &image,
                                     compound_converter, &compound))
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
    Py_INCREF(font);
    if (self->text) CFRelease(self->text);
    if (text) CFRetain(text);
    self->text = text;
    self->font = font;

    Py_XDECREF(self->image);
    if (image) Py_INCREF(image);
    self->image = image;
    self->compound = compound;

    rect.origin.x = 0;
    rect.origin.y = 0;
    rect.size = widget->minimum_size;

    label = [[LabelView alloc] initWithFrame: rect];
    widget->view = label;
    label->object = widget;

    Py_INCREF(systemTextColor);
    Py_INCREF(systemTextColor);
    Py_INCREF(systemTextColor);
    Py_INCREF(systemWindowBackgroundColor);
    Py_INCREF(systemWindowBackgroundColor);
    Py_INCREF(systemWindowBackgroundColor);
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
    CTLineRef line = self->line;
    CTFrameRef frame = self->frame;
    if (label) [label release];
    if (text) CFRelease(text);
    if (line) CFRelease(line);
    if (frame) CFRelease(frame);
    Py_XDECREF(self->font);
    Py_XDECREF(self->foreground);
    Py_XDECREF(self->background);
    Py_XDECREF(self->active_foreground);
    Py_XDECREF(self->active_background);
    Py_XDECREF(self->disabled_foreground);
    Py_XDECREF(self->highlight_background);
    Py_XDECREF(self->highlight_color);
    Py_XDECREF(self->image);
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

static PyObject* Label_calculate_minimum_size(LabelObject* self, void* closure)
{
    /* follows the logic in TkpComputeButtonGeometry */
    WidgetObject* widget = (WidgetObject*) self;
    CGFloat width = widget->minimum_size.width;
    CGFloat height = widget->minimum_size.height;
    CFStringRef text = self->text;

    if (width > 0 && height > 0) {
        return Py_BuildValue("ff", width, height);
    }

    if (self->line) {
        CFRelease(self->line);
        self->line = NULL;
    }

    if (text) {
        CFMutableAttributedStringRef string;
        CFDictionaryRef attributes;
        CFRange range = CFRangeMake(0, CFStringGetLength(self->text));
        CFStringRef keys[] = { kCTFontAttributeName };
        CFTypeRef values[] = { self->font->font } ;
        Py_ssize_t underline = self->underline;
        attributes = CFDictionaryCreate(kCFAllocatorDefault,
                                        (const void**)&keys,
                                        (const void**)&values,
                                        1,
                                        &kCFTypeDictionaryKeyCallBacks,
                                        &kCFTypeDictionaryValueCallBacks);
        if (!attributes) {
            PyErr_SetString(PyExc_MemoryError,
                            "failed to create attributes dictionary");
            return NULL;
        }
        string = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
        if (!string) {
            PyErr_SetString(PyExc_MemoryError,
                            "failed to create attributed string");
            return NULL;
        }
        CFAttributedStringReplaceString(string, CFRangeMake(0, 0), self->text);
        CFAttributedStringSetAttributes(string, range, attributes, false);
        CFRelease(attributes);
        if (underline >= 0) {
            CTUnderlineStyle value = kCTUnderlineStyleSingle;
            CFNumberRef number = CFNumberCreate(kCFAllocatorDefault,
                                                kCFNumberNSIntegerType,
                                                &value);
            if (number) {
                CFAttributedStringSetAttribute(string,
                                               CFRangeMake(underline, 1),
                                               kCTUnderlineStyleAttributeName,
                                               number);
                CFRelease(number);
            }
            else {
                CFRelease(string);
                PyErr_SetString(PyExc_MemoryError,
                                "failed to create number with the index "
                                "for the character to underline");
                return NULL;
            }
        }
        if (self->wraplength
         || CFStringFind(text, CFSTR("\n"), 0).location != kCFNotFound) {
            // multiple lines
            CGSize size;
            CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(string);
            CGSize constraints = CGSizeMake(self->wraplength, CGFLOAT_MAX);
            CFRange fitRange;
            CFRange range = CFRangeMake(0, 0);
            CGPathRef path;
            CTFrameRef frame;
            CFRelease(string);
            if (!framesetter) {
                PyErr_SetString(PyExc_MemoryError, "failed to create framesetter");
                return NULL;
            }
            size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter,
                                                                range,
                                                                NULL,
                                                                constraints,
                                                                &fitRange);
            width = size.width;
            height = size.height;
            path = CGPathCreateWithRect(CGRectMake(0, 0, width, height), NULL);
            if (path) {
                frame = CTFramesetterCreateFrame(framesetter, range, path, NULL);
                CFRelease(path);
            }
            else frame = NULL;
            CFRelease(framesetter);
            if (!frame) {
                PyErr_SetString(PyExc_MemoryError, "failed to create framer");
                return NULL;
            }
            self->frame = frame;
        }
        else {
            // single line
            CGFloat ascent;
            CGFloat descent;
            CGFloat leading;
            self->line = CTLineCreateWithAttributedString(string);
            if (!self->line) {
                PyErr_SetString(PyExc_MemoryError, "failed to create framesetter");
                return NULL;
            }
            CFRelease(string);
            width = CTLineGetTypographicBounds(self->line, &ascent, &descent, &leading);
            height = ascent + descent;
        }
    }

    if (self->image) {
        CGImageRef image = self->image->data;
        size_t image_width = CGImageGetWidth(image);
        size_t image_height = CGImageGetHeight(image);

        switch (self->compound) {
            case PY_COMPOUND_TOP:
            case PY_COMPOUND_BOTTOM:
                height += self->pady + image_height;
                width = (width > image_width ? width : image_width);
                break;
            case PY_COMPOUND_LEFT:
            case PY_COMPOUND_RIGHT:
                height = (height > image_height ? height : image_height);
                width += self->padx + image_width;
                break;
            case PY_COMPOUND_CENTER:
                height = (height > image_height ? height : image_height);
                width = (width > image_width ? width : image_width);
                break;
            default:
                break;
        }
    }

    if (width > 0 && height > 0) {
        width += 2 * (self->padx + self->highlight_thickness + self->border_width);
        width += widget->margin_left + widget->margin_right;
        height += 2 * (self->pady + self->highlight_thickness + self->border_width);
        height += widget->margin_top + widget->margin_bottom;
    }

    widget->minimum_size.width = width;
    widget->minimum_size.height = height;

    return Py_BuildValue("ff", width, height);
}

static char
Label_calculate_minimum_size__doc__[] = "minimum size requested by label.";

static PyMethodDef Label_methods[] = {
    {"set_position",
     (PyCFunction)Label_set_position,
     METH_VARARGS,
     "Moves the label to the new position."
    },
    {"calculate_minimum_size",
     (PyCFunction)Label_calculate_minimum_size,
     METH_VARARGS,
     Label_calculate_minimum_size__doc__
    },
    {NULL}  /* Sentinel */
};

static PyObject* Label_get_text(LabelObject* self, void* closure)
{
    if (self->text) return PyString_FromCFString(self->text);

    Py_INCREF(Py_None);
    return Py_None;
}

static int
Label_set_text(LabelObject* self, PyObject* value, void* closure)
{
    CFStringRef text;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (Py_IsNone(value)) self->text = NULL;
    else {
        text = PyString_AsCFString(value);
        if (!text) return -1;
        if (self->text) CFRelease(self->text);
        self->text = text;
    }
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
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
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (!PyObject_IsInstance(value, (PyObject *)&FontType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Font object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->font);
    self->font = (FontObject*) value;
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_font__doc__[] = "font for label";

static PyObject* Label_get_underline(LabelObject* self, void* closure)
{
    Py_ssize_t underline = self->underline;
    if (underline == -1) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyLong_FromSsize_t(underline);
}

static int
Label_set_underline(LabelObject* self, PyObject* value, void* closure)
{
    Py_ssize_t underline;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (value == Py_None) underline = -1;
    else {
        if (!PyLong_Check(value)) {
            PyErr_SetString(PyExc_ValueError, "expected an integer.");
            return -1;
        }
        underline = PyLong_AsSsize_t(value);
        if (underline == -1 && PyErr_Occurred()) return -1;
        if (underline < 0) {
            PyErr_SetString(PyExc_ValueError, "expected a positive integer.");
            return -1;
        }
    }
    self->underline = underline;
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_underline__doc__[] = "specifies the index of the character to underline.";

static PyObject* Label_get_wraplength(LabelObject* self, void* closure)
{
    const size_t wraplength = self->wraplength;
    if (wraplength == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyLong_FromSize_t(wraplength);
}

static int
Label_set_wraplength(LabelObject* self, PyObject* value, void* closure)
{
    size_t wraplength;
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (value == Py_None) wraplength = 0;
    else {
        wraplength = PyLong_AsSize_t(value);
        if (wraplength == (size_t)-1 && PyErr_Occurred()) return -1;
    }
    self->wraplength = wraplength;
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_wraplength__doc__[] = "maximum line length (in pixels); longer lines will be wrapped.";

static PyObject* Label_get_image(LabelObject* self, void* closure)
{
    PyObject* image = (PyObject*) self->image;
    if (!image) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    Py_INCREF(image);
    return image;
}

static int
Label_set_image(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    if (Py_IsNone(value)) {
        Py_XDECREF(self->image);
        self->image = NULL;
    }
    else if (PyObject_IsInstance(value, (PyObject *)&ImageType)) {
        Py_INCREF(value);
        Py_XDECREF(self->image);
        self->image = (ImageObject*) value;
    }
    else {
        PyErr_SetString(PyExc_ValueError, "expected an Image object");
        return -1;
    }
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_image__doc__[] = "the image associated with the label, if any";

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
        case PY_RELIEF_RAISED: return PyUnicode_FromString("RAISED");
        case PY_RELIEF_SUNKEN: return PyUnicode_FromString("SUNKEN");
        case PY_RELIEF_FLAT: return PyUnicode_FromString("FLAT");
        case PY_RELIEF_RIDGE: return PyUnicode_FromString("RIDGE");
        case PY_RELIEF_SOLID: return PyUnicode_FromString("SOLID");
        case PY_RELIEF_GROOVE: return PyUnicode_FromString("GROOVE");
        default:
            PyErr_Format(PyExc_RuntimeError,
                "expected RAISED (%d), SUNKEN (%d), FLAT (%d), "
                "RIDGE (%d), SOLID (%d), or GROOVE (%d), got %d",
                PY_RELIEF_RAISED, PY_RELIEF_SUNKEN, PY_RELIEF_FLAT,
                PY_RELIEF_RIDGE, PY_RELIEF_SOLID, PY_RELIEF_GROOVE,
                self->relief);
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
    if (PyOS_stricmp(relief, "RAISED")==0) self->relief = PY_RELIEF_RAISED;
    else if (PyOS_stricmp(relief, "SUNKEN")==0) self->relief = PY_RELIEF_SUNKEN;
    else if (PyOS_stricmp(relief, "FLAT")==0) self->relief = PY_RELIEF_FLAT;
    else if (PyOS_stricmp(relief, "RIDGE")==0) self->relief = PY_RELIEF_RIDGE;
    else if (PyOS_stricmp(relief, "SOLID")==0) self->relief = PY_RELIEF_SOLID;
    else if (PyOS_stricmp(relief, "GROOVE")==0) self->relief = PY_RELIEF_GROOVE;
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

static PyObject* Label_get_xalign(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->xalign);
}

static int
Label_set_xalign(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat xalign = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    if (xalign < 0 || xalign > 1) {
        PyErr_SetString(PyExc_ValueError,
                        "xalign must be between 0 and 1");
        return -1;
    }
    self->xalign = xalign;
    label.needsDisplay = YES;
    return 0;
}

static char Label_xalign__doc__[] = "horizontal alignment of the text with respect to the label.";

static PyObject* Label_get_yalign(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->yalign);
}

static int
Label_set_yalign(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat yalign = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    if (yalign < 0 || yalign > 1) {
        PyErr_SetString(PyExc_ValueError,
                        "yalign must be between 0 and 1");
        return -1;
    }
    self->yalign = yalign;
    label.needsDisplay = YES;
    return 0;
}

static char Label_yalign__doc__[] = "vertical alignment of the text with respect to the label.";

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
    Widget_unset_minimum_size(widget);
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
    Widget_unset_minimum_size(widget);
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

static PyObject* Label_get_width(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->width);
}

static int
Label_set_width(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat width = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->width = width;
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_width__doc__[] = "preferred label width in characters (in case of text only) or pixels (if the label includes an image).";

static PyObject* Label_get_height(LabelObject* self, void* closure)
{
    return PyFloat_FromDouble(self->height);
}

static int
Label_set_height(LabelObject* self, PyObject* value, void* closure)
{
    WidgetObject* widget = (WidgetObject*) self;
    LabelView* label = (LabelView*) (widget->view);
    const CGFloat height = PyFloat_AsDouble(value);
    if (PyErr_Occurred()) return -1;
    self->height = height;
    Widget_unset_minimum_size(widget);
    label.needsDisplay = YES;
    return 0;
}

static char Label_height__doc__[] = "preferred label height as the number of text lines (in case of text only) or pixels (if the label includes an image).";

static PyObject* Label_get_compound(LabelObject* self, void* closure)
{
    switch (self->compound) {
        case PY_COMPOUND_NONE: return PyUnicode_FromString("NONE");
        case PY_COMPOUND_BOTTOM: return PyUnicode_FromString("BOTTOM");
        case PY_COMPOUND_TOP: return PyUnicode_FromString("TOP");
        case PY_COMPOUND_LEFT: return PyUnicode_FromString("LEFT");
        case PY_COMPOUND_RIGHT: return PyUnicode_FromString("RIGHT");
        case PY_COMPOUND_CENTER: return PyUnicode_FromString("CENTER");
        default:
            PyErr_Format(PyExc_RuntimeError,
                "expected NONE (%d), BOTTOM (%d), TOP (%d), "
                "LEFT (%d), RIGHT (%d), or CENTER (%d)",
                PY_COMPOUND_NONE, PY_COMPOUND_BOTTOM, PY_COMPOUND_TOP,
                PY_COMPOUND_LEFT, PY_COMPOUND_RIGHT, PY_COMPOUND_CENTER,
                self->compound);
            return NULL;
    }
}

static int
Label_set_compound(LabelObject* self, PyObject* value, void* closure)
{
    if (compound_converter(value, &self->compound)) {
        WidgetObject* widget = (WidgetObject*) self;
        LabelView* label = (LabelView*) (widget->view);
        label.needsDisplay = YES;
        return 0;
    }
    return -1;
}

static char Label_compound__doc__[] = "for compound labels, the location of the image relative to the text.";


static PyGetSetDef Label_getseters[] = {
    {"text", (getter)Label_get_text, (setter)Label_set_text, Label_text__doc__, NULL},
    {"font", (getter)Label_get_font, (setter)Label_set_font, Label_font__doc__, NULL},
    {"image", (getter)Label_get_image, (setter)Label_set_image, Label_image__doc__, NULL},
    {"underline", (getter)Label_get_underline, (setter)Label_set_underline, Label_underline__doc__, NULL},
    {"wraplength", (getter)Label_get_wraplength, (setter)Label_set_wraplength, Label_wraplength__doc__, NULL},
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
    {"compound", (getter)Label_get_compound, (setter)Label_set_compound, Label_compound__doc__, NULL},
    {"border_width", (getter)Label_get_border_width, (setter)Label_set_border_width, Label_border_width__doc__, NULL},
    {"padx", (getter)Label_get_padx, (setter)Label_set_padx, Label_padx__doc__, NULL},
    {"pady", (getter)Label_get_pady, (setter)Label_set_pady, Label_pady__doc__, NULL},
    {"xalign", (getter)Label_get_xalign, (setter)Label_set_xalign, Label_xalign__doc__, NULL},
    {"yalign", (getter)Label_get_yalign, (setter)Label_set_yalign, Label_yalign__doc__, NULL},
    {"highlight_thickness", (getter)Label_get_highlight_thickness, (setter)Label_set_highlight_thickness, Label_highlight_thickness__doc__, NULL},
    {"width", (getter)Label_get_width, (setter)Label_set_width, Label_width__doc__, NULL},
    {"height", (getter)Label_get_height, (setter)Label_set_height, Label_height__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Label_doc[] =
"A Label object wraps a Cocoa NSTextField object.\n";

Py_LOCAL_SYMBOL PyTypeObject LabelType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "_guitk.Label",
    .tp_basicsize = sizeof(LabelObject),
    .tp_dealloc = (destructor)Label_dealloc,
    .tp_repr = (reprfunc)Label_repr,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_doc = Label_doc,
    .tp_methods = Label_methods,
    .tp_getset = Label_getseters,
    .tp_base = &WidgetType,
    .tp_init = (initproc)Label_init,
    .tp_new = Label_new,
};
