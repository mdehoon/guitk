from guitk import gui, layout

window = gui.Window(400,400)

grid = layout.Grid(1,3)
listbox = gui.Listbox(multiple=True)
subgrid = layout.Grid(3,1)
grid[0,0] = listbox
grid[0,1] = gui.Separator()
grid[0,2] = subgrid
button_delete = gui.Button('Delete')
textbox = gui.Textbox()
button_append = gui.Button('Append')
subgrid[0,0] = button_delete
subgrid[1,0] = textbox
subgrid[2,0] = button_append
window.content = grid

listbox.hexpand = True
listbox.vexpand = True
subgrid[0,0].vexpand = True
subgrid[0,0].valign = 'TOP'
subgrid[1,0].vexpand = True
subgrid[1,0].valign = 'BOTTOM'
subgrid[2,0].valign = 'BOTTOM'

listbox.append("Apples")
listbox.append("Bananas")
listbox.append("Oranges")
listbox.append("Strawberries")

def command_append():
    text = textbox.text
    listbox.append(text)

def command_delete():
    indices = listbox.selected
    for index in indices[::-1]:
        listbox.delete(index)

button_append.command = command_append
button_delete.command = command_delete

window.show()
