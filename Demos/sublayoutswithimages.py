from guitk.gui import *
from guitk.layout import Grid

from array import array


root = Window()
root.size = (700, 500)

buffer1 = array('B', [255,0,0, 128] * 1024)
data1 = memoryview(buffer1).cast('B', shape=(32, 32, 4))
image1 = Image(data1)

buffer2 = array('B', [255, 192, 203, 128] * 1024)
data2 = memoryview(buffer2).cast('B', shape=(32, 32, 4))
image2 = Image(data2)

buffer3 = array('B', [255, 165, 0, 128] * 1024)
data3 = memoryview(buffer3).cast('B', shape=(32, 32, 4))
image3 = Image(data3)

buffer4 = array('B', [0,128,0, 128] * 1024)
data4 = memoryview(buffer4).cast('B', shape=(32, 32, 4))
image4 = Image(data4)

buffer5 = array('B', [0,0,255, 128] * 1024)
data5 = memoryview(buffer5).cast('B', shape=(32, 32, 4))
image5 = Image(data5)

buffer6 = array('B', [173,216,230, 128] * 1024)
data6 = memoryview(buffer6).cast('B', shape=(32, 32, 4))
image6 = Image(data6)

label1 = Label(text="One", image=image1, compound='CENTER')
label1.background=Color('red')
label1.font = Font("Helvetica", 64)
label1.hexpand = True
label1.sticky = 'WE'

label2 = Label(text="Two", image=image2)
label2.background=Color('pink')
label2.font = Font("Helvetica", 64)
label2.compound = 'TOP'

label3 = Label(text="Three", image=image3, compound='BOTTOM')
label3.background=Color('Orange')
label3.font = Font("Helvetica", 64)

label4 = Label(text="Four", image=image4, compound='TOP')
label4.background=Color('green')
label4.font = Font("Helvetica", 64)

label5 = Label(text="Five", image=image5)
label5.background=Color('blue')
label5.font = Font("Helvetica", 64)
label5.compound = 'RIGHT'

label6 = Label(text="Six", image=image6)
label6.background=Color('lightblue')
label6.font = Font("Helvetica", 64)
label6.sticky = 'NSWE'
label6.hexpand = True
label6.vexpand = True
label6.compound = 'LEFT'


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
