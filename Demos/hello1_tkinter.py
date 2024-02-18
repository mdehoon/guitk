# Original Tkinter version obtained from:
# http://effbot.org/tkinterbook/tkinter-hello-tkinter.htm


from tkinter import *

root = Tk()

w = Label(root, text="Hello, world!", font='Times 40')
w.pack()

root.mainloop()
