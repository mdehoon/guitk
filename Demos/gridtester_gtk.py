import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk

from guitk.gui import *

from numpy.random import random, randint

fontname = "Helvetiva"


class MyWindow(Gtk.ApplicationWindow):

    def __init__(self, **kargs):
        super().__init__(**kargs, title='GTK')

        self.grid = Gtk.Grid()
        self.add(self.grid)

        self.grid1 = Gtk.Grid()
        self.grid2 = Gtk.Grid()
        self.grid.attach(self.grid1, 0, 0, 1, 1)
        self.grid.attach(self.grid2, 1, 0, 1, 1)

        self.label1 = self.create_label(1, text="One", color="red")
        self.grid1.attach(self.label1, 0, 0, 1, 1)

        self.label2 = self.create_label(2, text="Two", color='pink')
        self.grid1.attach(self.label2, 0, 1, 1, 1)

        self.label3 = self.create_label(3, text="Three", color='Orange')
        self.grid1.attach(self.label3, 0, 2, 1, 1)

        self.label4 = self.create_label(4, text="Four", color='green')
        self.grid2.attach(self.label4, 1, 0, 1, 1)

        self.label5 = self.create_label(5, text="Five", color='blue')
        self.grid2.attach(self.label5, 1, 1, 1, 1)

        self.label6 = self.create_label(6, text="Six", color='lightblue')
        self.grid2.attach(self.label6, 1, 2, 1, 1)

    def create_label(self, number, text, color):
        label = Gtk.Label(label=text)
        key = "cutom-label%d" % number
        label.get_style_context().add_class(key)
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(b"""
            .%s {
                font-family: %s;
                font-size: 64pt;
                background-color: %s;
                color: black;
            }
        """ % (key.encode(), fontname.encode(), color.encode()))
        # Apply the CSS to the display
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        )
        return label


window = MyWindow()
label1 = window.label1
label2 = window.label2
label3 = window.label3
label4 = window.label4
label5 = window.label5
label6 = window.label6
labels = (label1, label2, label3, label4, label5, label6)
grid = window.grid
grid1 = window.grid1
grid2 = window.grid2
window.connect("destroy", Gtk.main_quit)
window.show_all()

def randomize():
    attributes = ("xalign", "yalign", "halign", "valign", "hexpand", "vexpand")
    for i, label in enumerate(labels):
        number = i + 1
        words = []
        # halign
        index = randint(4)
        values = (Gtk.Align.FILL, Gtk.Align.START, Gtk.Align.END, Gtk.Align.CENTER)
        value = values[index]
        label.set_halign(value)
        words.append(f"halign={value}")
        # valign
        index = randint(4)
        values = (Gtk.Align.FILL, Gtk.Align.START, Gtk.Align.END, Gtk.Align.CENTER)
        value = values[index]
        label.set_valign(value)
        words.append(f"valign={value}")
        # hexpand
        flag = (randint(2) == 0)
        label.set_hexpand(flag)
        words.append(f"hexpand={flag}")
        # vexpand
        flag = (randint(2) == 0)
        label.set_vexpand(flag)
        words.append(f"vexpand={flag}")
        # xalign
        value = random()
        label.set_xalign(value)
        words.append(f"xalign={value:.3f}")
        # yalign
        value = random()
        label.set_yalign(value)
        words.append(f"yalign={value:.3f}")
        # margin_start
        value = randint(20) * randint(2)
        label.set_margin_start(value)
        words.append(f"margin_left={value}")
        # margin_end
        value = randint(20) * randint(2)
        label.set_margin_end(value)
        words.append(f"margin_right={value}")
        # margin_top
        value = randint(20) * randint(2)
        label.set_margin_top(value)
        words.append(f"margin_top={value}")
        # margin_bottom
        value = randint(20) * randint(2)
        label.set_margin_bottom(value)
        words.append(f"margin_bottom={value}")
        line = f"label{number}: " + ", ".join(words)
        # padding
        padding_x = randint(20) * randint(2)
        padding_y = randint(20) * randint(2)
        label.set_padding(padding_x, padding_y)
        words.append(f"padding={padding_x, padding_y}")
        line = f"label{number}: " + ", ".join(words)
        print(line)
