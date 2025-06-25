from guitk import gui
import array

font = gui.Font("Helvetica", 40)

window = gui.Window()
label = gui.Label("Check out the icon", font)
window.content = label

height = 100
width = 100
components = 4

buffer = array.array('B', [0] * (height * width * components))
data = memoryview(buffer).cast('B', shape=(height, width, components))

halfheight = height // 2
halfwidth = width // 2
for i in range(halfheight):
    for j in range(halfwidth):
        data[i, j, 0] = 0
        data[i, j, 1] = (j * 5) % 255
        data[i, j, 2] = 0
        data[i, j, 3] = 255
for i in range(halfheight):
    for j in range(halfwidth, width):
        data[i, j, 0] = (i * 5) % 255
        data[i, j, 1] = 0
        data[i, j, 2] = 0
        data[i, j, 3] = 255
for i in range(halfheight, height):
    for j in range(halfwidth):
        data[i, j, 0] = 0
        data[i, j, 1] = 0
        data[i, j, 2] = 255
        data[i, j, 3] = 0
for i in range(halfheight, height):
    for j in range(halfwidth, width):
        data[i, j, 0] = 128
        data[i, j, 1] = 128
        data[i, j, 2] = 0
        data[i, j, 3] = 128

image = gui.Image(data)

gui.set_icon(image)

window.show()
