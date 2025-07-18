import gi
from guitk.gui import *
from guitk.layout import Grid

gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib

from numpy.random import random, randint


class MyWindow(Gtk.ApplicationWindow):

    def __init__(self, **kargs):
        super().__init__(**kargs, title='GTK')

        grid = Gtk.Grid()
        self.set_child(grid)

        self.label1 = self.create_label(1, text="One", color="red")
        grid.attach(self.label1, 0, 0, 1, 1)

        self.label2 = self.create_label(2, text="Two", color='pink')
        grid.attach(self.label2, 0, 1, 1, 1)

        self.label3 = self.create_label(3, text="Three", color='Orange')
        grid.attach(self.label3, 1, 0, 1, 1)

        self.label4 = self.create_label(4, text="Four", color='green')
        grid.attach(self.label4, 1, 1, 1, 1)

        self.label5 = self.create_label(5, text="Five", color='blue')
        grid.attach(self.label5, 2, 0, 1, 1)

        self.label6 = self.create_label(6, text="Six", color='lightblue')
        grid.attach(self.label6, 2, 1, 1, 1)

    def create_label(self, number, text, color):
        label = Gtk.Label(label=text)
        key = "cutom-label%d" % number
        label.set_css_classes([key])
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(b"""
            .%s {
                font-family: "Helvetica";
                font-size: 64pt;
                background-color: %s;
                color: black;
                padding: 10px;
            }
        """ % (key.encode(), color.encode()))
        # Apply the CSS to the display
        Gtk.StyleContext.add_provider_for_display(
            self.get_display(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        return label


def on_activate(app):
    # Create window
    global gtk_win
    print("activating")
    gtk_win = MyWindow(application=app)
    gtk_win.present()

app = Gtk.Application(application_id='com.example.App')
app.connect('activate', on_activate)

app.register(None)
app.activate()

guitk_win = Window()
guitk_win.size = (700, 500)
guitk_win.title = "guitk"

def create_guitk_label(text, color):
    label = Label(text=text)
    label.background=Color(color)
    label.font = Font("Helvetica", 64)
    label.hexpand = False
    label.vexpand = False
    label.halign = "FILL"
    label.valign = "FILL"
    # label.xalign = 0.5
    # label.yalign = 0.5
    # label.margin_left = 0
    # label.margin_right = 0
    # label.margin_top = 0
    # label.margin_bottom = 0
    return label

label1 = create_guitk_label("One", 'red')
label2 = create_guitk_label("Two", 'pink')
label3 = create_guitk_label("Three", 'orange')
label4 = create_guitk_label("Four", 'green')
label5 = create_guitk_label("Five", 'blue')
label6 = create_guitk_label("Six", 'lightblue')

grid = Grid(2,3)
grid[0,0] = label1
grid[1,0] = label2
grid[0,1] = label3
grid[1,1] = label4
grid[0,2] = label5
grid[1,2] = label6

guitk_win.content = grid
guitk_win.show()


def get_labels(number):
    if number == 1:
        guitk_label = label1
    elif number == 2:
        guitk_label = label2
    elif number == 3:
        guitk_label = label3
    elif number == 4:
        guitk_label = label4
    elif number == 5:
        guitk_label = label5
    elif number == 6:
        guitk_label = label6
    if number == 1:
        gtk_label = gtk_win.label1
    elif number == 2:
        gtk_label = gtk_win.label2
    elif number == 3:
        gtk_label = gtk_win.label3
    elif number == 4:
        gtk_label = gtk_win.label4
    elif number == 5:
        gtk_label = gtk_win.label5
    elif number == 6:
        gtk_label = gtk_win.label6
    return guitk_label, gtk_label

def randomize():
    attributes = ("xalign", "yalign", "halign", "valign", "hexpand", "vexpand")
    for number in range(1, 7):
        guitk_label, gtk_label = get_labels(number)
        # halign
        index = randint(4)
        gtk_values = (Gtk.Align.FILL, Gtk.Align.START, Gtk.Align.END, Gtk.Align.CENTER)
        guitk_values = ("FILL", "LEFT", "RIGHT", "CENTER")
        gtk_label.set_halign(gtk_values[index])
        # guitk_label.halign = guitk_values[index]
        # valign
        index = randint(4)
        gtk_values = (Gtk.Align.FILL, Gtk.Align.START, Gtk.Align.END, Gtk.Align.CENTER)
        guitk_values = ("FILL", "TOP", "BOTTOM", "CENTER")
        gtk_label.set_valign(gtk_values[index])
        # guitk_label.valign = guitk_values[index]
        # hexpand
        flag = (randint(2) == 0)
        gtk_label.set_hexpand(flag)
        guitk_label.hexpand = flag
        # vexpand
        flag = (randint(2) == 0)
        gtk_label.set_vexpand(flag)
        guitk_label.vexpand = flag
        # xalign
        value = random()
        gtk_label.set_xalign(value)
        # guitk_label.xalign = value
        # yalign
        value = random()
        gtk_label.set_yalign(value)
        # guitk_label.yalign = value
        # margin_start
        value = randint(20)
        gtk_label.set_margin_start(value)
        # guitk_label.margin_left = value
        # margin_end
        value = randint(20)
        gtk_label.set_margin_end(value)
        # guitk_label.margin_right = value
        # margin_top
        value = randint(20)
        gtk_label.set_margin_top(value)
        # guitk_label.margin_top = value
        # margin_bottom
        value = randint(20)
        gtk_label.set_margin_bottom(value)
        # guitk_label.margin_bottom = value
