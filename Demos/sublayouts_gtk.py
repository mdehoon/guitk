import gi
import sys

gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib


class MyWindow(Gtk.ApplicationWindow):

    def __init__(self, **kargs):
        super().__init__(**kargs, title='Hello World')

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
    win = MyWindow(application=app)
    def on_close(window):
        loop.quit()
        return False
    win.connect('close-request', on_close)
    win.present()

app = Gtk.Application(application_id='com.example.App')
app.connect('activate', on_activate)

app.register(None)
app.activate()

# app.run(None)

loop = GLib.MainLoop()
loop.run()
