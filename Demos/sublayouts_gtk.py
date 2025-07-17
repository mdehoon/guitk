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
        grid.set_vexpand(True)
        grid.set_valign(Gtk.Align.FILL)

        grid1 = Gtk.Grid()
        grid2 = Gtk.Grid()
        grid3 = Gtk.Grid()
        grid1.set_valign(Gtk.Align.FILL)
        grid2.set_valign(Gtk.Align.FILL)
        grid3.set_valign(Gtk.Align.FILL)
        grid1.set_vexpand(True)
        grid2.set_vexpand(True)
        grid3.set_vexpand(True)
        grid.attach(grid1, 0, 0, 1, 1)
        grid.attach(grid2, 1, 0, 1, 1)
        grid.attach(grid3, 2, 0, 1, 1)
        self.set_child(grid)

        self.label1 = self.create_label(1, text="One", color="red")
        self.label1.set_hexpand(True)
        self.label1.set_vexpand(True)
        self.label1.sticky = 'WE'
        self.label1.set_valign(Gtk.Align.FILL)
        grid1.attach(self.label1, 0, 0, 1, 1)

        self.label2 = self.create_label(2, text="Two", color='pink')
        self.label2.set_hexpand(True)
        self.label2.set_vexpand(True)
        grid1.attach(self.label2, 0, 1, 1, 1)

        self.label3 = self.create_label(3, text="Three", color='Orange')
        grid2.attach(self.label3, 0, 0, 1, 1)

        self.label4 = self.create_label(4, text="Four", color='green')
        grid2.attach(self.label4, 0, 1, 1, 1)

        self.label5 = self.create_label(5, text="Five", color='blue')
        grid3.attach(self.label5, 0, 0, 1, 1)

        self.label6 = self.create_label(6, text="Six", color='lightblue')
        self.label6.sticky = 'NSWE'
        self.label6.hexpand = True
        self.label6.vexpand = True
        grid3.attach(self.label6, 0, 1, 1, 1)

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

label1 = Label(text="One")
label1.background=Color('red')
label1.font = Font("Helvetica", 64)
label1.hexpand = True
label1.sticky = 'WE'

label2 = Label(text="Two")
label2.background=Color('pink')
label2.font = Font("Helvetica", 64)

label3 = Label(text="Three")
label3.background=Color('Orange')
label3.font = Font("Helvetica", 64)

label4 = Label(text="Four")
label4.background=Color('green')
label4.font = Font("Helvetica", 64)

label5 = Label(text="Five")
label5.background=Color('blue')
label5.font = Font("Helvetica", 64)

label6 = Label(text="Six")
label6.background=Color('lightblue')
label6.font = Font("Helvetica", 64)
label6.sticky = 'NSWE'
label6.hexpand = True
label6.vexpand = True


grid = Grid(2,3)
grid[0,0] = label1
grid[1,0] = label2
grid[0,1] = label3
grid[1,1] = label4
grid[0,2] = label5
grid[1,2] = label6

grid[0,0].hexpand = True
grid[0,2].hexpand = True
grid[0,2].vexpand = True

guitk_win.content = grid
guitk_win.show()


def config(number, attribute, value):
    if number == 1:
        label = label1
    elif number == 2:
        label = label2
    elif number == 3:
        label = label3
    elif number == 4:
        label = label4
    elif number == 5:
        label = label5
    elif number == 6:
        label = label6
    setattr(label, attribute, value)
    if number == 1:
        label = gtk_win.label1
    elif number == 2:
        label = gtk_win.label2
    elif number == 3:
        label = gtk_win.label3
    elif number == 4:
        label = gtk_win.label4
    elif number == 5:
        label = gtk_win.label5
    elif number == 6:
        label = gtk_win.label6
    attribute = "set_" + attribute
    method = getattr(label, attribute)
    method(value)

def randomize():
    attributes = ("xalign", "yalign", "halign", "valign", "hexpand", "vexpand")
    for number in range(1, 7):
        flag = 0  # randint(2)
        if flag:
            value = random()
            config(number, "xalign", value)
            print("label%d xalign = %f" % (number, value))
        flag = 0  # randint(2)
        if flag:
            value = random()
            config(number, "yalign", value)
            print("label%d xalign = %f" % (number, value))
        flag = randint(2)
        if flag:
            config(number, "hexpand", True)
            print("label%d hexpand = True" % number)
        else:
            config(number, "hexpand", False)
            print("label%d hexpand = False" % number)
        flag = randint(2)
        if flag:
            config(number, "vexpand", True)
            print("label%d vexpand = True" % number)
        else:
            config(number, "vexpand", False)
            print("label%d vexpand = False" % number)
