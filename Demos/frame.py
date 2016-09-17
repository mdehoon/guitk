# Original Tkinter version is available here:
# http://effbot.org/tkinterbook/frame.htm

from guitk import gui, layout

window = gui.Window()
frame = gui.Frame()
frame.title = "Numbers"
window.content = frame
grid = layout.Grid(2,1)
frame.content = grid
grid[0,0] = gui.Label('One')
grid[1,0] = gui.Label('Two')
grid[0,0].hexpand = True
grid[0,0].vexpand = True
grid[1,0].hexpand = True
grid[1,0].vexpand = True
window.show()
