from guitk.gui import *
from guitk.layout import Grid

from numpy.random import random, randint

fontname = "Helvetiva"


guitk_win = Window()
guitk_win.size = (700, 500)
guitk_win.title = "guitk"

def create_guitk_label(text, color):
    label = Label(text=text)
    label.background=Color(color)
    label.font = Font(fontname, 48)
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
label2 = create_guitk_label("Two two", 'pink')
label3 = create_guitk_label("Three three three", 'orange')
label4 = create_guitk_label("Four four four four", 'green')
label5 = create_guitk_label("Five five five five five", 'blue')
label6 = create_guitk_label("Six six six six six six", 'lightblue')

label1.wraplength = 200
label2.wraplength = 200
label3.wraplength = 200
label4.wraplength = 200
label5.wraplength = 200
label6.wraplength = 200

grid = Grid(2,3)
grid[0,0] = label1
grid[1,0] = label2
grid[0,1] = label3
grid[1,1] = label4
grid[0,2] = label5
grid[1,2] = label6

guitk_win.content = grid
guitk_win.show()

def randomize():
    attributes = ("xalign", "yalign", "halign", "valign", "hexpand", "vexpand")
    for number in range(1, 7):
        words = []
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
        # halign
        index = randint(4)
        values = ("FILL", "LEFT", "RIGHT", "CENTER")
        label.halign = values[index]
        words.append(f"halign='{label.halign}'")
        # valign
        index = randint(4)
        values = ("FILL", "TOP", "BOTTOM", "CENTER")
        label.valign = values[index]
        words.append(f"valign='{label.valign}'")
        # hexpand
        flag = (randint(2) == 0)
        label.hexpand = flag
        words.append(f"hexpand={label.hexpand}")
        # vexpand
        flag = (randint(2) == 0)
        label.vexpand = flag
        words.append(f"vexpand={label.vexpand}")
        # xalign
        value = random()
        label.xalign = value
        words.append(f"xalign={label.xalign:.3f}")
        # yalign
        value = random()
        label.yalign = value
        words.append(f"yalign={label.yalign:.3f}")
        # margin_start
        value = randint(20) * randint(2)
        label.margin_left = value
        words.append(f"margin_left={label.margin_left:.1f}")
        # margin_end
        value = randint(20) * randint(2)
        label.margin_right = value
        words.append(f"margin_right={label.margin_right:.1f}")
        # margin_top
        value = randint(20) * randint(2)
        label.margin_top = value
        words.append(f"margin_top={label.margin_top:.1f}")
        # margin_bottom
        value = randint(20) * randint(2)
        label.margin_bottom = value
        words.append(f"margin_bottom={label.margin_bottom:.1f}")
        line = f"label{number}: " + ", ".join(words)
        # padding
        padding_x = randint(20) * randint(2)
        padding_y = randint(20) * randint(2)
        label.padx = padding_x
        label.pady = padding_y
        words.append(f"padding={padding_x, padding_y}")
        # wrapping
        wraplength = 10 * randint(50)
        if wraplength < 100:
            label.wraplength = None
        else:
            label.wraplength = wraplength
        words.append(f"wraplength={wraplength}")
        line = f"label{number}: " + ", ".join(words)
        print(line)
