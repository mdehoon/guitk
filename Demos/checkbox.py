# Original Tkinter version is available here:
# http://effbot.org/tkinterbook/checkbutton.htm

from guitk import gui, layout

class App(gui.Window):
    def __init__(self):
        gui.Window.__init__(self)
        checkbox1 = gui.Checkbox(text="Apples")
        checkbox2 = gui.Checkbox(text="Oranges")
        checkbox1.command = self.checkbox_command
        checkbox2.command = self.checkbox_command
        checkbox1.hexpand = True
        checkbox1.vexpand = True
        checkbox2.hexpand = True
        checkbox2.vexpand = True
        grid = layout.Grid(2,1)
        grid[0,0] = checkbox1
        grid[1,0] = checkbox2
        self.content = grid
    def checkbox_command(self, checkbox):
        text = checkbox.text
        print(text, "became", checkbox.state)

window = App()
window.show()
