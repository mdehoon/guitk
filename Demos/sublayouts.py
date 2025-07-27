from guitk.gui import *
from guitk.layout import Grid


root = Window()
root.size = (700, 500)

label1 = Label(text="One")
label1.background=Color('red')
label1.font = Font("Helvetica", 64)
label1.hexpand = True
label1.halign = "FILL"
label1.underline = 0

label2 = Label(text="Two")
label2.background=Color('pink')
label2.font = Font("Helvetica", 64)
label2.underline = 0

label3 = Label(text="Three")
label3.background=Color('Orange')
label3.font = Font("Helvetica", 64)
label3.underline = 2

label4 = Label(text="Four")
label4.background=Color('green')
label4.font = Font("Helvetica", 64)
label4.underline = 0

label5 = Label(text="Five")
label5.background=Color('blue')
label5.font = Font("Helvetica", 64)
label5.underline = 1

label6 = Label(text="Six")
label6.background=Color('lightblue')
label6.font = Font("Helvetica", 64)
label6.hexpand = True
label6.vexpand = True
label6.halign = "FILL"
label6.valign = "FILL"
label6.underline = 0


# label1.focus_set()

grid = Grid(1,3)
grid[0,0] = Grid(2,1)
grid[0,1] = Grid(2,1)
grid[0,2] = Grid(2,1)
grid[0,0][0,0] = label1
grid[0,0][1,0] = label2
grid[0,1][0,0] = label3
grid[0,1][1,0] = label4
grid[0,2][0,0] = label5
grid[0,2][1,0] = label6

grid[0,0].hexpand = True
grid[0,2].hexpand = True
grid[0,2].vexpand = True

root.content = grid
root.show()
