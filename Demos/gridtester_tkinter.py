import tkinter as tk

root = tk.Tk()
root.title("Grid in a Grid Example")

# Create a Frame to hold the inner grid
left_frame = tk.Frame(root, bd=2, relief="solid")
left_frame.grid(row=0, column=0, padx=5, pady=5)
right_frame = tk.Frame(root, bd=2, relief="solid")
right_frame.grid(row=0, column=1, padx=5, pady=5)

# Inner grid inside the frame
label1 = tk.Label(left_frame, text="One", bg="red", font="Helvetica 64")
label2 = tk.Label(left_frame, text="Two", bg="pink", font="Helvetica 64")
label3 = tk.Label(left_frame, text="Three", bg="orange", font="Helvetica 64")
label4 = tk.Label(right_frame, text="Four", bg="green", font="Helvetica 64")
label5 = tk.Label(right_frame, text="Five", bg="blue", font="Helvetica 64")
label6 = tk.Label(right_frame, text="Six", bg="lightblue", font="Helvetica 64")

label1.grid(row=0, column=0, padx=3, pady=3)
label2.grid(row=1, column=0, padx=3, pady=3)
label3.grid(row=2, column=0, padx=3, pady=3)
label4.grid(row=0, column=0, padx=3, pady=3)
label5.grid(row=1, column=0, padx=3, pady=3)
label6.grid(row=2, column=0, padx=3, pady=3)
