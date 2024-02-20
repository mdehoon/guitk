from guitk.gui import *
from guitk.layout import Grid


root = Window()
root.size = (700, 500)

label1 = Label(text="Relief = raised,\nstate = disabled")
label1.active_background=Color('red')
label1.border_width=20
# label1.padx=20
# label1.pady=90
# label1.anchor='se'
label1.size = (10, 2)
label1.background=Color('pink')
label1.highlight_background=Color('green')
label1.highlight_color=Color('yellow')
label1.highlight_thickness=25
label1.relief='raised'
label1.take_focus=True
label1.active_foreground=Color('purple')
# label1.cursor='hand2'
label1.disabled_foreground=Color('cyan')
# label1.foreground=Color('blue')
# label1.state='disabled'
label1.font = Font("Helvetica 9")

label2 = Label(text="Relief = sunken,\nstate = normal")
label2.active_background=Color('red')
label2.border_width=20
# label2.padx=20
# label2.pady=90
# label2.anchor='se'
label2.size = (10, 2)
label2.background=Color('pink')
label2.highlight_background=Color('green')
label2.highlight_color=Color('yellow')
label2.highlight_thickness=25
label2.relief='sunken'
label2.take_focus=True
label2.active_foreground=Color('purple')
# label2.cursor='hand2'
label2.disabled_foreground=Color('cyan')
# label2.foreground=Color('blue')
# label2.state='disabled'
label2.font = Font("Helvetica 9")

label3 = Label(text="Relief = solid,\nstate = disabled")
label3.active_background=Color('red')
label3.border_width=20
# label3.padx=20
# label3.pady=90
label3.anchor='se'
label3.size = (10, 2)
label3.background=Color('pink')
label3.highlight_background=Color('green')
label3.highlight_color=Color('yellow')
label3.highlight_thickness=25
label3.relief='solid'
label3.take_focus=True
label3.active_foreground=Color('purple')
# label3.cursor='hand2'
label3.disabled_foreground=Color('cyan')
# label3.foreground=Color('blue')
label3.state='disabled'
label3.font = Font("Helvetica 9")

label4 = Label(text="Relief = flat,\nstate = disabled")
label4.active_background=Color('red')
label4.border_width=20
# label4.padx=20
# label4.pady=90
label4.anchor='se'
label4.size = (10, 2)
label4.background=Color('pink')
label4.highlight_background=Color('green')
label4.highlight_color=Color('yellow')
label4.highlight_thickness=25
label4.relief='flat'
label4.take_focus=True
label4.active_foreground=Color('purple')
# label4.cursor='hand2'
label4.disabled_foreground=Color('cyan')
# label4.foreground=Color('blue')
label4.state='disabled'
label4.font = Font("Helvetica 9")

label5 = Label(text="Relief = ridge,\nstate = disabled")
label5.active_background=Color('red')
label5.border_width=20
# label5.padx=20
# label5.pady=90
label5.anchor='se'
label5.size = (10, 2)
label5.background=Color('pink')
label5.highlight_background=Color('green')
label5.highlight_color=Color('yellow')
label5.highlight_thickness=25
label5.relief='ridge'
label5.take_focus=True
label5.active_foreground=Color('purple')
# label5.cursor='hand2'
label5.disabled_foreground=Color('cyan')
# label5.foreground=Color('blue')
label5.state='disabled'
label5.font = Font("Helvetica 9")

label6 = Label(text="Relief = groove, state = disabled")
label6.active_background=Color('red')
label6.border_width=20
# label6.padx=20
# label6.pady=90
label6.anchor='se'
label6.size = (10, 2)
label6.background=Color('pink')
label6.highlight_background=Color('green')
label6.highlight_color=Color('yellow')
label6.highlight_thickness=25
label6.relief='groove'
label6.take_focus=True
label6.active_foreground=Color('purple')
# label6.cursor='hand2'
label6.disabled_foreground=Color('cyan')
# label6.foreground=Color('blue')
label6.state='disabled'
label6.font = Font("Helvetica 9")





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

root.content = grid
# print("Setting root.content.size")
# root.content.size = root.size
# print("After setting root.content.size")
root.show()
