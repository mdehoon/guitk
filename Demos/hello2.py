# Original Tkinter version is available here:
# http://effbot.org/tkinterbook/tkinter-hello-again.htm

from guitk import gui, layout
from guitk.gui import Color

class App(gui.Window):
    def __init__(self):
        gui.Window.__init__(self)
        button1 = gui.Button("QUIT")
        button2 = gui.Button("Hello")
        button1.hexpand = True
        button2.hexpand = True
        button1.vexpand = True
        button2.vexpand = True
        button1.halign = 'RIGHT'
        button2.halign = 'LEFT'
        button1.foreground = Color('Red')
        grid = layout.Grid(1,2)
        grid[0,0] = button1
        grid[0,1] = button2
        grid.size = grid.minimum_size
        self.content = grid
        button1.command = self.close
        button2.command = self.say_hi

    def say_hi(self):
        print("hi there, everyone")

window = App()
window.show()
