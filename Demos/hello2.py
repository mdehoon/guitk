from guitk import gui, layout

def say_hi():
    print "hi there, everyone"

window = gui.Window(300,50, 'Hello')
grid = layout.Grid(1,2)
button1 = gui.Button("QUIT")
button2 = gui.Button("Hello")
button1.hexpand = True
button2.hexpand = True
button1.vexpand = True
button2.vexpand = True
button1.halign = 'RIGHT'
button2.halign = 'LEFT'
button1.foreground = 'Red'
grid[0,0] = button1
grid[0,1] = button2
window.content = grid
window.show()
