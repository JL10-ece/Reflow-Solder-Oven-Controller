#!/usr/bin/python
from tkinter import *
import time
import serial
import serial.tools.list_ports
import sys
import kconvert
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import xlsxwriter
from playsound import playsound
import threading

times = []
ktemps = []
states = []
start_time = time.time()
startSoak = 0
soakTime = 0
startReflow = 0
reflowTime = 0

top = Tk()
top.resizable(0,0)
top.title("Fluke_45/Tek_DMM4020 K-type Thermocouple")
#ATTENTION: Make sure the multimeter is configured at 9600 baud, 8-bits, parity none, 1 stop bit, echo Off

CJTemp = StringVar()
Temp = StringVar()
DMMout = StringVar()
portstatus = StringVar()
DMM_Name = StringVar()
connected=0
currState = StringVar()
currState.set("Pre-Heating")
global ser

fig, ax = plt.subplots()
line, = ax.plot([],[], 'r-')
ax.set_xlabel('Time (s)')
ax.set_ylabel('Temperature (°C)')
ax.set_title('Graph of Temperature over Time')

canvas = FigureCanvasTkAgg(fig, master=top)
canvas.get_tk_widget().grid(row=0, column=1, rowspan=11)

state_colors = {
    "Pre-Heating": "yellow",
    "Soaking": "orange",
    "Peak Ramp": "red",
    "Reflow": "brown",
    "Cooling": "blue"
}
#play sound in a separate thread so it doesn't interrupt data logging
def play_sound_async(soundfile):
    threading.Thread(target=playsound, args=(soundfile,), daemon=True).start()
play_sound_async('preheat.wav')
def Just_Exit():
    top.destroy()
    try:
        ser.close()
    except:
        dummy=0

#updates the plot on tkinter window        
def update_plot():
    line.set_data(times, ktemps)
    line.set_color(state_colors[currState.get()])
    ax.relim()
    ax.autoscale_view()
    canvas.draw()

def save_to_excel():
    #Create dataframe from times and ktemps arrays
    df = pd.DataFrame({
        'Time (s)': times,
        'Temperature (°C)': ktemps,
        'State': states
    })
    
    # Add columns for each state
    df['Pre-Heating'] = df.apply(lambda row: row['Temperature (°C)'] if row['State'] == "Pre-Heating" else None, axis=1)
    df['Soaking'] = df.apply(lambda row: row['Temperature (°C)'] if row['State'] == "Soaking" else None, axis=1)
    df['Peak Ramp'] = df.apply(lambda row: row['Temperature (°C)'] if row['State'] == "Peak Ramp" else None, axis=1)
    df['Reflow'] = df.apply(lambda row: row['Temperature (°C)'] if row['State'] == "Reflow" else None, axis=1)
    df['Cooling'] = df.apply(lambda row: row['Temperature (°C)'] if row['State'] == "Cooling" else None, axis=1)
    # Send dataframe to excel file
    with pd.ExcelWriter('temperature_data.xlsx', engine='xlsxwriter') as writer:
        df.to_excel(writer, sheet_name='Data', index=False)

        # Access the workbook and worksheet objects
        workbook = writer.book
        worksheet = writer.sheets['Data']

        # Create a chart object
        chart = workbook.add_chart({'type': 'line'})

        # Configure the chart
        chart.set_title({'name': 'Temperature vs Time'})
        chart.set_x_axis({'name': 'Time (s)', 'major_gridlines': {'visible': False}})
        chart.set_y_axis({'name': 'Temperature (°C)', 'major_gridlines': {'visible': False}})
        worksheet.set_column('B:B', 20)
        # Define the data range for the chart
        # x-axis (categories): Time (s) column (column A, starting from row 2)
        # y-axis (data): Temperature (°C) column (column B, starting from row 2)
        max_row = len(df) + 1  # +1 to account for the header row
        chart.add_series({
            'categories': ['Data', 1, 0, max_row, 0],  # Time (s) column (A2:A<max_row>)
            'values': ['Data', 1, 1, max_row, 1],      # Temperature (°C) column (B2:B<max_row>)
            'name': 'Temperature',
            'line': {'color': 'black'}, 
        })
        chart.add_series({
            'name': 'Pre-Heating',
            'categories': ['Data', 1, 0, max_row, 0],  # Time (s) column (A2:A<max_row>)
            'values': ['Data', 1, 3, max_row, 3],      # Pre-Heating column (D2:D<max_row>)
            'line': {'color': 'yellow'}, 
        })
        chart.add_series({
            'name': 'Soaking',
            'categories': ['Data', 1, 0, max_row, 0],  # Time (s) column (A2:A<max_row>)
            'values': ['Data', 1, 4, max_row, 4],      # Soaking column (E2:E<max_row>)
            'line': {'color': 'orange'},
        })
        chart.add_series({
            'name': 'Peak Ramp',
            'categories': ['Data', 1, 0, max_row, 0],  # Time (s) column (A2:A<max_row>)
            'values': ['Data', 1, 5, max_row, 5],      # Peak Ramp column (F2:F<max_row>)
            'line': {'color': 'red'}, 
        })
        chart.add_series({
            'name': 'Reflow',
            'categories': ['Data', 1, 0, max_row, 0],  # Time (s) column (A2:A<max_row>)
            'values': ['Data', 1, 6, max_row, 6],      # Reflow column (G2:G<max_row>)
            'line': {'color': 'brown'},
        })
        chart.add_series({
            'name': 'Cooling',
            'categories': ['Data', 1, 0, max_row, 0],  # Time (s) column (A2:A<max_row>)
            'values': ['Data', 1, 7, max_row, 7],      # Cooling column (H2:H<max_row>)
            'line': {'color': 'blue'}, 
        })
        
        # Insert the chart into the worksheet
        worksheet.insert_chart('I2', chart)

def update_temp():
    global ser, connected, startSoak, soakTime, startReflow, reflowTime
    if connected==0:
        top.after(5000, FindPort) # Not connected, try to reconnect again in 5 seconds
        return
    try:
        strin = ser.readline() # Read the requested value, for example "+0.234E-3 VDC"
        strin = strin.rstrip()
        strin = strin.decode()
        print(strin)
        ser.readline() # Read and discard the prompt "=>"
        if len(strin)>1:
            if strin[1]=='>': # Out of sync?
                strin = ser.readline() # Read the value again
        ser.write(b"MEAS1?\r\n") # Request next value from multimeter
    except:
        connected=0
        DMMout.set("----")
        Temp.set("----");
        portstatus.set("Communication Lost")
        DMM_Name.set ("--------")
        top.after(5000, FindPort) # Try to reconnect again in 5 seconds
        return
    strin_clean = strin.replace("VDC","") # get rid of the units as the 'float()' function doesn't like it
    if len(strin_clean) > 0:      
       DMMout.set(strin.replace("\r", "").replace("\n", "")) # display the information received from the multimeter

       try:
           val=float(strin_clean)*1000.0 # Convert from volts to millivolts
           valid_val=1;
       except:
           valid_val=0

       try:
          cj=float(CJTemp.get()) # Read the cold junction temperature in degrees centigrade
       except:
          cj=0.0 # If the input is blank, assume cold junction temperature is zero degrees centigrade

       if valid_val == 1 :
           ktemp=round(kconvert.mV_to_C(val, cj),1)
           if ktemp < -200:  
               Temp.set("UNDER")
           elif ktemp > 1372:
               Temp.set("OVER")
           else:
               #update temp on tkinter window
               Temp.set(ktemp)
               #append time of temp recording to times
               tempDiff = time.time() - start_time
               times.append(round(tempDiff, 2))
               #append value of ktemp to ktemps
               ktemps.append(ktemp)
               #append state to states
               states.append(currState.get())
               #update the tkinter plot
               update_plot()
               # Change text color depending on currState
               if currState.get() == "Pre-Heating":
                   tempLabel.config(fg="yellow")
                   if ktemp > 150:
                       currState.set("Soaking")
                       startSoak = time.time()
                       play_sound_async('soak.wav')
               elif currState.get() == "Soaking":
                   tempLabel.config(fg="orange")
                   soakTime = time.time() - startSoak
                   if soakTime > 60:
                       currState.set("Peak Ramp")
                       play_sound_async('peakramp.wav')
               elif currState.get() == "Peak Ramp":
                    tempLabel.config(fg="red")
                    if ktemp > 220:
                        currState.set("Reflow")
                        startReflow = time.time()
                        play_sound_async('reflow.wav')
               elif currState.get() == "Reflow":
                    tempLabel.config(fg="brown")
                    reflowTime = time.time() - startReflow
                    if reflowTime > 45:
                        currState.set("Cooling")
                        play_sound_async('cooling.wav')
               elif currState.get() == "Cooling":
                   tempLabel.config(fg="blue")
       else:
           Temp.set("----");
    else:
       Temp.set("----");
       connected=0;
    top.after(500, update_temp) # The multimeter is slow and the baud rate is slow: two measurement per second tops!

def FindPort():
   global ser, connected
   try:
       ser.close()
   except:
       dummy=0
       
   connected=0
   DMM_Name.set ("--------")
   portlist=list(serial.tools.list_ports.comports())
   for item in reversed(portlist):
      portstatus.set("Trying port " + item[0])
      top.update()
      try:
         ser = serial.Serial(item[0], 9600, timeout=0.5)
         ser.write(b"\x03") # Request prompt from possible multimeter
         pstring = ser.readline() # Read the prompt "=>"
         pstring=pstring.rstrip()
         pstring=pstring.decode()
         # print(pstring)
         if len(pstring) > 1:
            if pstring[1]=='>':
               ser.timeout=3  # Three seconds timeout to receive data should be enough
               portstatus.set("Connected to " + item[0])
               ser.write(b"VDC; RATE S; *IDN?\r\n") # Measure DC voltage, set scan rate to 'Slow' for max resolution, get multimeter ID
               devicename=ser.readline()
               devicename=devicename.rstrip()
               devicename=devicename.decode()
               DMM_Name.set(devicename.replace("\r", "").replace("\n", ""))
               ser.readline() # Read and discard the prompt "=>"
               ser.write(b"MEAS1?\r\n") # Request first value from multimeter
               connected=1
               top.after(1000, update_temp)
               break
            else:
               ser.close()
         else:
            ser.close()
      except:
         connected=0
   if connected==0:
      portstatus.set("Multimeter not found")
      top.after(5000, FindPort) # Try again in 5 seconds

Label(top, text="Cold Junction Temperature:").grid(row=1, column=0)
Entry(top, bd =1, width=7, textvariable=CJTemp).grid(row=2, column=0)
Label(top, text="Multimeter reading:").grid(row=3, column=0)
Label(top, text="xxxx", textvariable=DMMout, width=20, font=("Helvetica", 20), fg="red").grid(row=4, column=0)
Label(top, text="Thermocouple Temperature (C)").grid(row=5, column=0)

tempLabel = Label(top, textvariable=Temp, width=5, font=("Helvetica", 100), fg="blue")
tempLabel.grid(row=6, column=0)

Label(top, text="xxxx", textvariable=portstatus, width=40, font=("Helvetica", 12)).grid(row=7, column=0)
Label(top, text="xxxx", textvariable=DMM_Name, width=40, font=("Helvetica", 12)).grid(row=8, column=0)

stateLabel = Label(top, textvariable=currState, width=40, font=("Helvetica", 12))
stateLabel.grid(row=9, column=0)

Button(top, width=11, text = "Exit", command = Just_Exit).grid(row=10, column=0)
Button(top, width=11, text="Save to Excel", command=save_to_excel).grid(row=11, column=0)

CJTemp.set ("22")
DMMout.set ("NO DATA")
DMM_Name.set ("--------")

top.after(500, FindPort)
top.mainloop()
