#!/usr/bin/python
import sys
if sys.version_info[0] < 3:
    import Tkinter
    from tkinter import *
    import tkMessageBox
else:
    import tkinter as Tkinter
    from tkinter import *
    from tkinter import messagebox as tkMessageBox
import time
import serial
import serial.tools.list_ports
import kconvert
from matplotlib.figure import Figure
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import pandas as pd
from openpyxl import Workbook
from openpyxl.drawing.image import Image as ExcelImage
import matplotlib.pyplot as plt

top = Tk()
top.resizable(0, 0)
top.title("Fluke_45/Tek_DMM40xx K-type Thermocouple")

# ATTENTION: Make sure the multimeter is configured at 9600 baud, 8-bits, parity none, 1 stop bit, echo Off

CJTemp = StringVar()
Temp = StringVar()
DMMout = StringVar()
portstatus = StringVar()
DMM_Name = StringVar()
connected = 0
val2 = 0
global ser

# Initialize data storage for plotting and Excel
time_data = []
temp_data = []  # For ktemp (thermocouple temperature)
val2_data = []  # For val2 (microcontroller reading)
diff_data = []  # For absolute difference between ktemp and val2

# Create a matplotlib figure and axis
fig = Figure(figsize=(6, 4), dpi=100)
ax = fig.add_subplot(111)
ax.set_xlabel('Time (s)')
ax.set_ylabel('Temperature (C) / Value')
ax.grid(True)

# Embed the plot in the Tkinter window
canvas = FigureCanvasTkAgg(fig, master=top)
canvas.get_tk_widget().grid(row=0, column=1, rowspan=10)

def save_to_excel():
    # Create a DataFrame
    df = pd.DataFrame({
        'Time (s)': time_data,
        'Thermocouple Temp (C)': temp_data,
        'Microcontroller Value': val2_data,
        'Absolute Difference': diff_data
    })

    # Save the DataFrame to an Excel file
    excel_file = 'data_output.xlsx'
    df.to_excel(excel_file, index=False)
    
    # Create a plot and save it as an image
    plt.figure(figsize=(10, 6))
    plt.plot(time_data, temp_data, 'b-', label='Thermocouple Temp (C)')
    plt.plot(time_data, val2_data, 'r-', label='Microcontroller Temp (C)')
    plt.xlabel('Time (s)')
    plt.ylabel('Temperature (C)')
    plt.title('Multimeter and Microcontroller Temperature Readings over Time')
    plt.grid(True)
    plt.legend()
    plot_file = 'plot.png'
    plt.savefig(plot_file)
    plt.close()

    # Embed the plot image in the Excel file
    wb = Workbook()
    ws = wb.active
    ws.title = "Data"
    img = ExcelImage(plot_file)
    headers = ["Time (s)", "Thermocouple Temp (C)", "Microcontroller Temp (C)", "Difference"]
    ws.append(headers)

    # Write data to respective columns
    for i in range(len(time_data)):
        ws.append([time_data[i], temp_data[i], val2_data[i], diff_data[i]])
    ws.add_image(img, 'F2')  # Adjust the cell position as needed
    wb.save(excel_file)

    print(f"Data and plot saved to {excel_file}")

def Just_Exit():
    save_to_excel()  # Save data to Excel before exiting
    top.destroy()
    try:
        ser.close()
    except:
        dummy = 0

def update_temp():
    global ser, connected, time_data, temp_data, val2_data, diff_data, val2
    if connected == 0:
        top.after(5000, FindPort)  # Not connected, try to reconnect again in 5 seconds
        return
    try:
        strin_bytes = ser.readline()  # Read the requested value, for example "+0.234E-3 VDC"
        strin = strin_bytes.decode()
        ser.readline()  # Read and discard the prompt "=>"
        if len(strin) > 1:
            if strin[1] == '>':  # Out of sync?
                strin_bytes = ser.readline()  # Read the value again
                strin = strin_bytes.decode()
        ser.write(b"MEAS1?\r\n")  # Request next value from multimeter
    except:
        connected = 0
        DMMout.set("----")
        Temp.set("----")
        portstatus.set("Communication Lost")
        DMM_Name.set("--------")
        top.after(5000, FindPort)  # Try to reconnect again in 5 seconds
        return
    strin_clean = strin.replace("VDC", "")  # get rid of the units as the 'float()' function doesn't like it
    if len(strin_clean) > 0:
        DMMout.set(strin.replace("\r", "").replace("\n", ""))  # display the information received from the multimeter

        try:
            val = float(strin_clean) * 1000.0  # Convert from volts to millivolts
            valid_val = 1
        except:
            valid_val = 0

        try:
            cj = float(CJTemp.get())  # Read the cold junction temperature in degrees centigrade
        except:
            cj = 0.0  # If the input is blank, assume cold junction temperature is zero degrees centigrade

        strin2 = ser2.readline()
        strin2 = strin2.rstrip()
        strin2 = strin2.decode()
        
        if len(strin2) > 0:
            try:
                val2 = float(strin2)
            except:
                val2 = 0

        if valid_val == 1:
            ktemp = round(kconvert.mV_to_C(val, cj), 1)
            if ktemp < -200:
                Temp.set("UNDER")
            elif ktemp > 1372:
                Temp.set("OVER")
            else:
                Temp.set(ktemp)
                try:
                    print(ktemp, val2, round(abs(ktemp - val2), 2))
                except:
                    dummy = 1
                # Update the plot data
                current_time = len(time_data) * 0.5  # Assuming 0.5 seconds per update
                time_data.append(current_time)
                temp_data.append(ktemp)
                val2_data.append(val2)
                diff_data.append(abs(ktemp - val2))  # Store absolute difference
                ax.clear()
                ax.plot(time_data, temp_data, 'b-', label='Thermocouple Temp (C)')
                ax.plot(time_data, val2_data, 'r-', label='Microcontroller Value')
                ax.set_xlabel('Time (s)')
                ax.set_ylabel('Temperature (C) / Value')
                ax.grid(True)
                ax.legend()  # Add a legend to distinguish the lines
                canvas.draw()
        else:
            Temp.set("----")
    else:
        Temp.set("----")
        connected = 0
    top.after(500, update_temp)  # The multimeter is slow and the baud rate is slow: two measurement per second tops!

def FindPort():
    global ser, connected
    try:
        ser.close()
    except:
        dummy = 0

    connected = 0
    DMM_Name.set("--------")
    portlist = list(serial.tools.list_ports.comports())
    for item in reversed(portlist):
        portstatus.set("Trying port " + item[0])
        top.update()
        try:
            ser = serial.Serial(item[0], 9600, timeout=0.5)
            time.sleep(0.2)  # for the simulator
            ser.write(b'\x03')  # Request prompt from possible multimeter
            instr = ser.readline()  # Read the prompt "=>"
            pstring = instr.decode()
            if len(pstring) > 1:
                if pstring[1] == '>':
                    ser.timeout = 3  # Three seconds timeout to receive data should be enough
                    portstatus.set("Connected to " + item[0])
                    ser.write(b"VDC; RATE S; *IDN?\r\n")  # Measure DC voltage, set scan rate to 'Slow' for max resolution, get multimeter ID
                    instr = ser.readline()
                    devicename = instr.decode()
                    DMM_Name.set(devicename.replace("\r", "").replace("\n", ""))
                    ser.readline()  # Read and discard the prompt "=>"
                    ser.write(b"MEAS1?\r\n")  # Request first value from multimeter
                    connected = 1
                    top.after(1000, update_temp)
                    break
                else:
                    ser.close()
            else:
                ser.close()
        except:
            connected = 0
    if connected == 0:
        portstatus.set("Multimeter not found")
        top.after(5000, FindPort)  # Try again in 5 seconds

Label(top, text="Cold Junction Temperature:").grid(row=1, column=0)
Entry(top, bd=1, width=7, textvariable=CJTemp).grid(row=2, column=0)
Label(top, text="Multimeter reading:").grid(row=3, column=0)
Label(top, text="xxxx", textvariable=DMMout, width=20, font=("Helvetica", 20), fg="red").grid(row=4, column=0)
Label(top, text="Thermocouple Temperature (C)").grid(row=5, column=0)
Label(top, textvariable=Temp, width=5, font=("Helvetica", 100), fg="blue").grid(row=6, column=0)
Label(top, text="xxxx", textvariable=portstatus, width=40, font=("Helvetica", 12)).grid(row=7, column=0)
Label(top, text="xxxx", textvariable=DMM_Name, width=40, font=("Helvetica", 12)).grid(row=8, column=0)
Button(top, width=11, text="Exit", command=Just_Exit).grid(row=9, column=0)

CJTemp.set("23")
DMMout.set("NO DATA")
DMM_Name.set("--------")

port = 'COM5'  # Change to the serial port assigned to your board

try:
    ser2 = serial.Serial(port, 115200, timeout=0)
except:
    print('Serial port %s is not available' % (port))
    portlist = list(serial.tools.list_ports.comports())
    print('Available serial ports:')
    for item in portlist:
        print(item[0])

top.after(500, FindPort)
top.mainloop()
