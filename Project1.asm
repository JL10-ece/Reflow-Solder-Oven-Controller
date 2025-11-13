; 76E003 ADC test program: Reads channel 7 on P1.1, pin 14
; This version uses the LM4040 voltage reference connected to pin 6 (P1.7/AIN0)

$NOLIST
$MODN76E003
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

CLK               EQU 16600000 ; Microcontroller system frequency in Hz
BAUD              EQU 115200 ; Baud rate of UART in bps
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RATE       EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD     EQU ((65536-(CLK/TIMER0_RATE)))
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))
TIMER2_RATE       EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD     EQU ((65536-(CLK/TIMER2_RATE)))


ORG 0x0000
ljmp main

; External interrupt 0 vector (not used in this code)
ORG 0x0003
reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023
reti

;------------------------------------
; Timer/Counter 2 overflow interrupt vector
org 0x002B
ljmp Timer2_ISR

;------------------------------

;                    1234567890123456    <- This helps determine the location of the counter
upper_message:   db 'S       Tk=XX.XX', 0
lower_message:   db '        Tj=XX.X ', 0
blank:           db '                ', 0
blank1:          db ' ', 0
celsius:         db 'C', 0
sec_display:     db 's', 0

STATE1:          db 'Soak Temperature', 0
STATE2:          db 'Soak Time       ', 0
STATE3:          db 'Reflow Temp     ', 0
STATE4:          db 'Reflow Time     ', 0
STATE5:          db 'Cooling Temp    ', 0
title:           db 'Main            ', 0


cseg
; These 'equ' must match the hardware wiring
LCD_RS    equ    P1.3
LCD_E     equ    P1.4
LCD_D4    equ    P0.0
LCD_D5    equ    P0.1
LCD_D6    equ    P0.2
LCD_D7    equ    P0.3
TOGGLE    equ    P1.5
;STATEPIN  equ    P1.6
SOUND_OUT equ    P1.6
PWM_OUT   equ    P1.2
LED_1     equ    p0.4
LED_0 	  equ    p1.0

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;///////////////////////////////////////////////////
; These register definitions needed by 'math32.inc';
;Basically where all the variables are defined     ;
;///////////////////////////////////////////////////

DSEG at 30H
v0:     ds 2 ;variable1
x:            ds 4
y:            ds 4
bcd:          ds 5
VAL_LM4040:   ds 2
FSM1_state:   ds 3    ; State variables are added here
sec:          ds 1
temp:         ds 8
; Temperature register values for comparison (determining if the temperature goes to next state)
compTemp1:    ds 4                ;;;;;;;;;;;;;;;;;;;;;
compTemp2:    ds 4                ;;;;;;;;;;;;;;;;;;;;;
x1:           ds 11
temp_counter: ds 12
pwm_counter:  ds 1
pwm:          ds 1
seconds:      ds 1
;;--- ;FSM counter variables: (implement with code later)
sec2:         ds 1
temp_soak:    ds 2        
time_soak:    ds 2          ;;;;;;;;;
temp_refl:    ds 2         ;;;;;;;;;;;;;;
time_refl:    ds 2       ;;;;;;;;;;;;;;
temp_cooling: ds 2
time_abort:   ds 2
cmp:          ds 2                   ;;;;;;;;;

;----------------------------------------------------
Count1ms:     ds 9 ; Used to determine when half second has passed
;----------------------------------------------------
;///////////////////////////////////////////;
;One bit variables                          ;
;///////////////////////////////////////////;
BSEG
mf:                dbit 1
half_seconds_flag: dbit 2   ; Set to one in the ISR every time 500 ms had passed
unit_flag:         dbit 3   ; 1 = Fahrenheit, 0 = Celsius
s_flag:            dbit 1   ; set to 1 every time a second has passed
flag:              dbit 1

PB0: dbit 1
PB1: dbit 1
PB2: dbit 1
PB3: dbit 1
PB4: dbit 1

v4:  dbit 1

$NOLIST
$include(math32.inc)
$LIST

;Intialization of timers of

Init_All:
; Configure all the pins for biderectional I/O
;//////////////////;
;TIMER1_INIT:      ; For UART (serial port)
;//////////////////;
orl  CKCON, #0x10 ; CLK is the input for timer 1
orl  PCON, #0x80 ; Bit SMOD=1, double baud rate
mov  SCON, #0x52
anl  T3CON, #0b11011111
anl  TMOD, #0x0F ; Clear the configuration bits for timer 1
orl  TMOD, #0x20 ; Timer 1 Mode 2
mov  TH1, #TIMER1_RELOAD ; TH1=TIMER1_RELOAD;
setb  TR1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Initializes PWM for P0.5 using PWM2;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PWM_Init:

    ANL P0M1, #0xDF
    ORL P0M2, #0x20
    
    ;PWM2_P05_OUTPUT_ENABLE	;BIT_TMP=EA;EA=0;TA=0xAA;TA=0x55;SFRS|=0x01;PIOCON1|=0x04;TA=0xAA;TA=0x55;SFRS&=0xFE;EA=BIT_TMP	
    MOV A, EA
    CLR EA
    MOV TA, #0xAA
    MOV TA, #0x55
    ORL SFRS, #0x01
    ORL PIOCON1, #0x04
    MOV TA, #0xAA
    MOV TA, #0x55
    ANL SFRS, #0xFE
    MOV EA , A
    
    ;PWM_IMDEPENDENT_MODE		PWMCON1&=0x3F
    ANL PWMCON1,#0x3F
    
    ;PWM_EDGE_TYPE			    PWMCON1&=~SET_BIT4
    ANL PWMCON1, #0xEF 
    
    ;set_CLRPWM 
    SETB CLRPWM
    
    ;select CLOCK_FSYS for PWM				
     ANL CKCON, #0xBF
     
    ;select CLOCK_DIV_64 for PWM				
    ORL PWMCON1, #0x06
    ANL PWMCON1, #0xFE
    
    MOV PNP, #0x00 ;PWM_OUTPUT_ALL_NORMAL		
    
    ;PERIOD
    MOV PWMPH, #high(5188)
	MOV PWMPL, #low(5188)
	;DUTY_CYCLE	
	MOV PWM2L, #low(519)  
	MOV PWM2H, #high(519)
		

;/////////////

;TIMER0_INIT
; Using timer 0 for delay functions.  Initialize here:
;clr TR0 ; Stop timer 0
;orl CKCON,#0x08 ; CLK is the input for timer 0
;anl TMOD,#0xF0 ; Clear the configuration bits for timer 0
;orl TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer
   ;///////////////
   
;//////////////////////////////////////////;
;ADC config for channel 1 and 7 (AIN0,AIN7);
;//////////////////////////////////////////;

; Configure P1.5 as input (Button)
anl P1M1, #0b11011111  ; Set P1.5 as input mode
orl P1M2, #0b00100000  ; Enable pull-up resistor
 
;Initialize and start the ADC:
anl ADCCON0, #0xF0
orl ADCCON0, #0x07 ; Select channel 7
; AINDIDS select if some pins are analog inputs or digital I/O:
mov AINDIDS, #0x00 ; Disable all analog inputs
orl AINDIDS, #0b10000011 ; Activate AIN0, AIN1 and AIN7 analog inputs
orl ADCCON1, #0x01 ; Enable ADC

ret
;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
orl CKCON, #0b00001000 ; Input for timer 0 is sysclk/1
mov a, TMOD
anl a, #0xf0 ; 11110000 Clear the bits for timer 0
orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
mov TMOD, a
mov TH0, #high(TIMER0_RELOAD)
mov TL0, #low(TIMER0_RELOAD)
; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz wave at pin SOUND_OUT   ;
;---------------------------------;
Timer0_ISR:
;clr TF0  ; According to the data sheet this is done for us already.
; Timer 0 doesn't have 16-bit auto-reload, so
clr TR0
mov TH0, #high(TIMER0_RELOAD)
mov TL0, #low(TIMER0_RELOAD)
setb TR0
cpl SOUND_OUT ; Connect speaker the pin assigned to 'SOUND_OUT'!
reti


;wait_1ms:
; clr TR0 ; Stop timer 0
; clr TF0 ; Clear overflow flag
; mov TH0, #high(TIMER0_RELOAD_1MS)
; mov TL0,#low(TIMER0_RELOAD_1MS)
; setb TR0
; jnb TF0, $ ; Wait for overflow
; ret

; Wait the number of miliseconds in R2
;waitms:
; lcall wait_1ms
; djnz R2, waitms
; ret


LCD_PB:
; Set variables to 1: 'no push button pressed'
setb PB0
setb PB1
setb PB2
setb PB3
setb PB4
; The input pin used to check set to '1'
setb P1.5

; Check if any push button is pressed
clr P0.0
clr P0.1
clr P0.2
clr P0.3
clr P1.3
jb P1.5, LCD_PB_Done

; Debounce
Wait_Milli_Seconds(#50)
Wait_Milli_Seconds(#50)
jb P1.5, LCD_PB_Done

; Set the LCD data pins to logic 1
setb P0.0
setb P0.1
setb P0.2
setb P0.3
setb P1.3

; Check the push buttons one by one
;///////////////////////////////////////////////

clr P1.3
mov c, P1.5
mov PB4, c

;;;;;;;;;;

;;;;;;;;;;;



jnc small_start

sjmp after_start


small_start:
ljmp start

after_start:
setb P1.3

;///////////////////////////////////////////////

clr P0.0
mov c, P1.5
mov PB3, c

jnc BUTTON_4_small

sjmp BUTTON_4_after
BUTTON_4_small:
ljmp BUTTON_4
BUTTON_4_after:
setb P0.0

;///////////////////////////////////////////////

clr P0.1
mov c, P1.5
mov PB2, c

jnc BUTTON_3_small

sjmp BUTTON_3_after
BUTTON_3_small:
ljmp BUTTON_3
BUTTON_3_after:
setb P0.1

;///////////////////////////////////////////////

clr P0.2
mov c, P1.5
mov PB1, c

jnc BUTTON_2

setb P0.2

;/////////////MODE BUTTON//////////////////////////////////

clr P0.3
mov c, P1.5
mov PB0, c

WAIT_FOR_RELEASE:
jb P1.5, BUTTON_RELEASED     ; Wait until button released
   
sjmp WAIT_FOR_RELEASE


BUTTON_RELEASED:

jnc set_value

setb P0.3

LCD_PB_Done:
ret


; ? Routines to update each variable separately
set_value:

mov a, FSM1_state
  cjne a, #0, spoon_end

    mov a, v0
    cjne a, #0x05, next_one  
    mov a, #0x00
Set_Cursor(1, 1)
    Send_Constant_String(#upper_message)
Set_Cursor(2, 1)
    Send_Constant_String(#lower_message)
    sjmp spoon        
   
     
next_one:                      
    add a, #0x01  
spoon:                  
    da a                  
    mov v0, a  
   
spoon_end:              
    ret


;-------------------------------------------------------------;

BUTTON_2:

mov a, FSM1_state
  cjne a, #0, END_BUTTON2

mov a, v0

cjne a, #0x00, BUTTON2_TS
ljmp END_BUTTON2

BUTTON2_TS:

cjne a, #0x01, BUTTON2_TS2

;-ADD-1-to-temp_soak
    mov a, temp_soak
    inc a
    mov temp_soak, a
   


BUTTON2_TS_done:
 
    ljmp END_BUTTON2
 
BUTTON2_TS2:


cjne a, #0x02, BUTTON2_TR


;-ADD-1-to-time_soak
    mov a, time_soak
    add a, #1
    mov time_soak, a
   

BUTTON2_TS2_done:
   
ljmp END_BUTTON2


BUTTON2_TR:

cjne a, #0x03, BUTTON2_TR2



;-ADD-1-to-temp_refl
    mov a, temp_refl
    add a, #1
    mov temp_refl, a
   
   


BUTTON2_TR_done:
   
   
ljmp END_BUTTON2


BUTTON2_TR2:

cjne a, #0x04, BUTTON2_COOL


;-ADD-1-to-time_refl
    mov a, time_refl
    add a, #1
    mov time_refl, a
   

BUTTON2_COOL:    

cjne a, #0x05, END_BUTTON2

   
mov a, temp_cooling
    add a, #1
    mov temp_cooling, a

   
   
   
ljmp END_BUTTON2


   

BUTTON2_TR2_done:  
   
ljmp END_BUTTON2




END_BUTTON2:

    ret


;--------------------------------------------------------;

BUTTON_3:

mov a, FSM1_state
  cjne a, #0, END_BUTTON3

mov a, v0

cjne a, #0x00, BUTTON3_TS
ljmp END_BUTTON3

BUTTON3_TS:

cjne a, #0x01, BUTTON3_TS2

    mov a, temp_soak
    dec a
    mov temp_soak, a
   
    ljmp END_BUTTON3
 
BUTTON3_TS2:

cjne a, #0x02, BUTTON3_TR

mov a, time_soak
    dec a
    mov time_soak, a
   
ljmp END_BUTTON3


BUTTON3_TR:

cjne a, #0x03, BUTTON3_TR2


;-ADD-1-to-temp_refl
    mov a, temp_refl
    dec a
    mov temp_refl, a
   
   
ljmp END_BUTTON3


BUTTON3_TR2:

cjne a, #0x04, BUTTON3_COOL

;-ADD-1-to-temp_refl
    mov a, time_refl
    dec a
    mov time_refl, a
   
   
ljmp END_BUTTON3


BUTTON3_COOL:    

cjne a, #0x05, END_BUTTON3

   
mov a, temp_cooling
    dec a
    mov temp_cooling, a

   
   
ljmp END_BUTTON3



END_BUTTON3:

    ret


BUTTON_4:

mov a, FSM1_state
  cjne a, #0, END_BUTTON4

mov a, v0

cjne a, #0x00, BUTTON4_TS
ljmp END_BUTTON4

BUTTON4_TS:

cjne a, #0x01, BUTTON4_TS2

    mov a, temp_soak
    add a, #10
    mov temp_soak, a
   
    ljmp END_BUTTON4
 
BUTTON4_TS2:

cjne a, #0x02, BUTTON4_TR

mov a, time_soak
    add a, #10
    mov time_soak, a
   
ljmp END_BUTTON4


BUTTON4_TR:

cjne a, #0x03, BUTTON4_TR2

mov a, temp_refl
    add a, #10
    mov temp_refl, a

   
ljmp END_BUTTON4


BUTTON4_TR2:

cjne a, #0x04, BUTTON4_COOL

mov a, time_refl
    add a, #10
    mov time_refl, a

   
ljmp END_BUTTON4
   
BUTTON4_COOL:    

cjne a, #0x05, END_BUTTON4

   
mov a, temp_cooling
    add a, #10
    mov temp_cooling, a

ljmp END_BUTTON4


END_BUTTON4:

    ret

;-------------------------------------------------------------;





;-------------------------------------------------------------------; Start Button

start:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;clr TR2
;mov pwm, #0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


mov a, FSM1_state
cjne a, #0, oven_off


    cpl LED_0
    mov FSM1_state, #1
    mov sec,   #00
    mov sec+1, #00


sjmp v4_end



oven_off:
;;;;;;;;;;;;;;;;;;;;;;
    ;clr P1.3
    ;mov c, P1.3
   ; mov PB4, c  
   
    ;jc wait_for_release2

	;sjmp oven_off
    
;;;;;;;;;;;
    mov a, #0x00
    ;da a                          ;;;;SOURCE OF BUG
    mov FSM1_state, a
    
    clr LED_1
    clr LED_0
Set_Cursor(1, 1)
    Send_Constant_String(#upper_message)
Set_Cursor(2, 1)
    Send_Constant_String(#lower_message)

;wait_for_release2:
 ;   clr P1.3          
;	mov c, P1.5
;	mov PB4, c
	
;	jnc v4_end
	
;	sjmp wait_for_release2
	
v4_end:
;;;;;
;setb TR2
;;;;;  
    ret

;-----------------------------------------------------------------------------------------------------CHECK HERE



;; -------------------------------- CHAR CODE -----------
; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret
   
;; --------------------------------------------------------------420349394023-492-034923-04923-04923-04230-42394

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
mov TH2,   #high(TIMER2_RELOAD)
mov TL2,   #low(TIMER2_RELOAD)
; Set the reload value
orl T2MOD, #0x80 ; Enable timer 2 autoreload
mov RCMP2H, #high(TIMER2_RELOAD)
mov RCMP2L, #low(TIMER2_RELOAD)

; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
clr a
mov Count1ms+0, a
mov Count1ms+1, a
mov pwm_counter, #0
; Enable the timer and interrupts
orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2  ; Enable timer 2
   
    ;setb EA
ret


;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
;cpl P0.4 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.

; The two registers used in the ISR must be saved in the stack
push acc
push psw

;////////////////
;Increment the 16-bit one mili second counter
inc Count1ms+0    ; Increment the low 8-bits first
mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
jnz Inc_Done
inc Count1ms+1
;//////////////////

; inc pwm_counter
; clr c
; mov a, pwm
; subb a, pwm_counter ; If pwm_counter <= pwm then c=1
; cpl c
 ;   mov PWM_OUT, c
;    mov a, pwm_counter
;    cjne a, #100, Timer2_ISR_done
;    mov pwm_counter, #0
;    inc seconds ; It is super easy to keep a seconds count here
    ; moving seconds to accumulator
   
;    setb s_flag
   
Inc_Done:
; Check if a second has passed
mov  a,  Count1ms+0
cjne a, #low(1000), Check_PWM ; Warning: this instruction changes the carry flag!
mov  a,  Count1ms+1
cjne a, #high(1000), Check_PWM

; 1000 milliseconds have passed.  Set a flag so the main program knows
setb half_seconds_flag ; Let the main program know half second had passed;-------------------------------------------------
; Reset to zero the milli-seconds counter, it is a 16-bit variable
clr a
clr TR0
mov Count1ms+0, a
mov Count1ms+1, a
; Increment the BCD counter
;----------------------------------------------------

;------------------------------------------------
    mov a, sec
    add a, #01   ; Increment sec
    sjmp Timer2_ISR_da

Timer2_ISR_decrement:
    add a, #99   ; Adding the 10-complement of -1 is like subtracting 1.

Timer2_ISR_da:
    da a           ; Decimal adjust instruction for BCD
    mov sec, a     ; Store updated sec value
    cjne a, #0x00, Timer2_ISR_done
    mov a, sec+1
    add a, #0x01
    da a
    mov sec+1, a

;--------------------------------------
;POWER CONTROL
;--------------------------------------

Check_PWM: ;handles PWM
;//////////////////
inc pwm_counter
clr c
mov a, pwm
subb a, pwm_counter ; If pwm_counter <= pwm then c=1
cpl c  
    mov PWM_OUT, c
   
    mov a, pwm_counter
    cjne a, #100, Timer2_ISR_done
    mov pwm_counter, #0
    inc seconds ; It is super easy to keep a seconds count here
    setb s_flag


Timer2_ISR_done:
pop psw
pop acc
reti

;--------------------------------------

;--------------------------------------
;Automatic cycle termination on error
;--------------------------------------
mov a, FSM1_state
cjne a, #1, Timer2_ISR_done
mov a, sec
cjne a, #60, Timer2_ISR_done ; if FSM1 is in state1(ramp to soak) and oven does not reach
mov a, temp                  ; 50 degrees in a minute, FSM1 goes to state0(idle)
cjne a, #50, Timer2_ISR_done
mov FSM1_state, #0
;--------------------------------------

;--------------------------------------------------------------------------1239012930123912-039-0123-012-0


;---------------------------------;
; Send a BCD number to PuTTY ;
;---------------------------------;
Send_BCD mac
push ar0
mov r0, %0
lcall ?Send_BCD
pop ar0
endmac
?Send_BCD:
push acc
; Write most significant digit
mov a, r0
swap a
anl a, #0fh
orl a, #30h
lcall putchar
; write least significant digit
mov a, r0
anl a, #0fh
orl a, #30h
lcall putchar
pop acc
ret

;---------------------------
; Display FSM values       ;
;---------------------------

Display_temp_soak:

Set_Cursor(2,1)
send_constant_string(#blank)

Set_Cursor(2,5)
mov x+0, temp_soak+0    ; Load first value into A
mov x+1, #0
mov x+2, #0
mov x+3, #0

Load_y(10)   ; Load the multiplier (10)
lcall mul32  ; Perform x = x * y
lcall hex2bcd
display_BCD(bcd+1)
display_BCD(bcd+0)

Set_Cursor(2,8)
send_constant_string(#celsius)
;send_constant_string(#blank1)
;send_constant_string(#blank1)
;send_constant_string(#blank1)
;send_constant_string(#blank1)
;send_constant_string(#blank1)
;send_constant_string(#blank1)
;send_constant_string(#blank1)
ret

Display_time_soak:

Set_Cursor(2,1)
send_constant_string(#blank)

Set_Cursor(2,4)
mov x+0, time_soak+0       ; Load first value into A
mov x+1, #0
mov x+2, #0
mov x+3, #0
lcall hex2bcd
display_BCD(bcd+1)
display_BCD(bcd+0)

Set_Cursor(2,4)
send_constant_string(#blank1)
Set_Cursor(2,8)
send_constant_string(#sec_display)

send_constant_string(#blank1)
send_constant_string(#blank1)
send_constant_string(#blank1)
send_constant_string(#blank1)
send_constant_string(#blank1)
send_constant_string(#blank1)

ret

Display_temp_refl:

Set_Cursor(2,1)
send_constant_string(#blank)

Set_Cursor(2,5)
mov x+0, temp_refl+0       ; Load first value into A
mov x+1, #0
mov x+2, #0
mov x+3, #0
Load_y(10)   ; Load the multiplier (10)
lcall mul32  ; Perform x = x * y
lcall hex2bcd
display_BCD(bcd+1)
display_BCD(bcd+0)

Set_Cursor(2,8)
send_constant_string(#celsius)
send_constant_string(#blank1)
send_constant_string(#blank1)
send_constant_string(#blank1)
send_constant_string(#blank1)
send_constant_string(#blank1)
send_constant_string(#blank1)
send_constant_string(#blank1)
ret

Display_time_refl:

Set_Cursor(2,1)
send_constant_string(#blank)

Set_Cursor(2,4)
mov x+0, time_refl+0       ; Load first value into A
mov x+1, #0
mov x+2, #0
mov x+3, #0
lcall hex2bcd
display_BCD(bcd+1)
display_BCD(bcd+0)
Set_Cursor(2,8)
send_constant_string(#sec_display)

ret

Display_temp_cooling:

Set_Cursor(2,1)
send_constant_string(#blank)

Set_Cursor(2,5)
mov x+0, temp_cooling+0       ; Load first value into A
mov x+1, #0
mov x+2, #0
mov x+3, #0
Load_y(10)   ; Load the multiplier (10)
lcall mul32  ; Perform x = x * y
lcall hex2bcd
display_BCD(bcd+1)
display_BCD(bcd+0)
Set_Cursor(2,8)
send_constant_string(#celsius)

ret

Display_time_abort:
Set_Cursor(2,4)
mov x+0, time_abort+0       ; Load first value into A
mov x+1, #0
mov x+2, #0
mov x+3, #0
lcall hex2bcd
display_BCD(bcd+1)
display_BCD(bcd+0)
ret

store_values:
mov cmp+1,bcd+1
mov cmp, bcd+0
ret

store_temps:
mov cmp+1,bcd+1
mov cmp, bcd+0

ret

;---------------------------------;
; Temperature
;---------------------------------;

temp_c:
clr ADCF
setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
   
    ; Read the ADC result and store in [R1, R0]
    mov a, ADCRH  
    swap a
    push acc
    anl a, #0x0f
    mov R1, a
    pop acc
    anl a, #0xf0
    orl a, ADCRL
    mov R0, A
    ret

average14:
mov x+0, R0
mov x+1, R1
mov x+2, #0
mov x+3, #0

Load_y(50300) ; VCC voltage measured
lcall mul32
Load_y(4095) ; 2^12-1
lcall div32
Load_y(27300)
lcall sub32
Load_y(100)
lcall mul32

mov y+0, x1+0
mov y+1, x1+1
mov y+2, x1+2
mov y+3, x1+3

lcall add32

mov x1+0, x+0
mov x1+1, x+1
mov x1+2, x+2
mov x1+3, x+3


mov R2, #100  ; amount of time to wait 100ms = 0.1s
Wait_Milli_Seconds(#100)
ret

average5:
    mov x+0, R3
mov x+1, R4
mov x+2, #0
mov x+3, #0

Load_y(50300) ; VCC voltage measured
lcall mul32
Load_y(4095) ; 2^12-1
lcall div32


    Load_y(41095)
lcall mul32 ;410.9520322
Load_y(4096)
lcall div32;4096
Load_y(22000)
lcall add32

mov y+0, x1+0
mov y+1, x1+1
mov y+2, x1+2
mov y+3, x1+3

lcall add32

mov x1+0, x+0
mov x1+1, x+1
mov x1+2, x+2
mov x1+3, x+3


mov R2, #100  ; amount of time to wait 100ms = 0.1s
Wait_Milli_Seconds(#100)
ret

temp_average:
mov temp_counter, #0
avav:
lcall temp_c
    lcall average14
   
    mov a, temp_counter
    add a, #1
    mov temp_counter, a
;----------------------------------------
cjne a, pwm, active
;deactivate oven

dfdf:
mov a, temp_counter
cjne a, #10, avav
ret

active:
;activate oven
sjmp dfdf



;---------------------------------------------------------------------


; We can display a number any way we want.
Display_formated_BCD_temp14:
    Set_Cursor(2, 11)
Display_BCD(bcd+2)
Display_BCD(bcd+1)
Set_Cursor(2,14)
Display_BCD(bcd+1)
Set_Cursor(2,14)
Display_char(#'.')
Set_Cursor(2, 11)
Display_char(#'=')
ret

Display_formated_BCD_temp5:

Set_Cursor(1, 12)
Display_BCD(bcd+2)
Display_BCD(bcd+1)
Set_Cursor(1,15)
Display_BCD(bcd+1)
Set_Cursor(1,15)
Display_char(#'.')




; Store the value of bcd+2 into compTemp1
mov A, bcd+2
mov compTemp1, A
; Store the value of bcd+1 into var2
mov A, bcd+1
mov compTemp2, A
ret

Display_formated_BCD:
Set_Cursor(2, 10)
Display_BCD(bcd+2)
Display_char(#'.')
Display_BCD(bcd+1)
Display_BCD(bcd+0)
Set_Cursor(2, 10)
Display_char(#'=')
ret

Read_ADC:
  clr ADCF
  setb ADCS ; ADC start trigger signal
  jnb ADCF, $ ; Wait for conversion complete
; Read the ADC result and store in [R1, R0]
  mov a, ADCRL
  anl a, #0x0f
  mov R0, a
  mov a, ADCRH
  swap a
  push acc
  anl a, #0x0f
  mov R1, a
  pop acc
  anl a, #0xf0
  orl a, R0
  mov R0, A
  
  ret


Display_variables:

mov a, v0

cjne a, #0x00, CHECK_DISPLAY1

   
   ljmp DISPLAY_END


CHECK_DISPLAY1:

cjne a, #0x01, CHECK_DISPLAY2

   Set_Cursor(1,1)
   Send_Constant_String(#STATE1)
   
   Set_Cursor(2,14)
   Display_BCD(v0)
   
   lcall Display_temp_soak
   
   ljmp DISPLAY_END
   

CHECK_DISPLAY2:

cjne a, #0x02, CHECK_DISPLAY3

   Set_Cursor(1,1)
   Send_Constant_String(#STATE2)
   
   
   Set_Cursor(2,14)
   Display_BCD(v0)
   
  lcall Display_time_soak
   
   ljmp DISPLAY_END

CHECK_DISPLAY3:

cjne a, #0x03, CHECK_DISPLAY4

   Set_Cursor(1,1)
   Send_Constant_String(#STATE3)
   
   Set_Cursor(2,14)
   Display_BCD(v0)
   
   lcall Display_temp_refl
   
   ljmp DISPLAY_END
   
CHECK_DISPLAY4:

cjne a, #0x04, CHECK_DISPLAY5

   Set_Cursor(1,1)
   Send_Constant_String(#STATE4)
   
   Set_Cursor(2,14)
   Display_BCD(v0)

   lcall Display_time_refl
   
   ljmp DISPLAY_END
   
CHECK_DISPLAY5:

   cjne a, #0x05, CHECK_DISPLAY6

   Set_Cursor(2,14)
   Display_BCD(v0)

   Set_Cursor(1,1)
   Send_Constant_String(#STATE5)
   
   lcall Display_temp_cooling
   
   
   
   ljmp DISPLAY_END
   
 
CHECK_DISPLAY6:



DISPLAY_END:
  

   ret
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;MAIN                      ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

main:
mov sp, #0x7f
lcall Init_All

;/////////////


;/////////

mov P0M1, #0x00
    mov P0M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P3M1, #0x00
    mov P3M2, #0x00
    mov v0, #0
    mov temp_soak,    #150
    mov time_refl,    #45
    mov time_soak,    #60
    mov time_abort,   #59
  mov temp_refl,    #217
  mov temp_cooling, #60
  mov flag,         #1
    lcall Display_time_refl
    lcall LCD_4BIT
    lcall Timer2_Init  ;timer 2 initialization
    lcall Timer0_Init
    mov pwm, #50
    mov sec2, #0x00
    
    clr LED_0
    clr LED_1

;---------    
    setb EA   ; Enable Global interrupts
    ;setb half_seconds_flag
    ;clr TR0 ;-------------
    Wait_Milli_Seconds(#250)
    clr TR0
;---------
    mov FSM1_state, #0
    mov pwm_counter, #0
    mov temp_counter, #0
    mov sec, #0x95
    mov sec+1, #0x00
    mov pwm, #50
   
    ; initial messages in LCD
Set_Cursor(1, 1)
    Send_Constant_String(#upper_message)
Set_Cursor(2, 1)
    Send_Constant_String(#lower_message)


Forever:
;; -----------------------------------
;mov x1+0, #0
;mov x1+1, #0
;mov x1+2, #0
;mov x1+3, #0

;lcall temp_average

;Load_y(10)   ; 10 measurements so division by 10
  ; to change # of measurements, have to change amount of time to wait in 'average' subroutine
;lcall div32    ; take average
;----------------------------
; Convert to BCD and display
;lcall hex2bcd
;lcall Display_formated_BCD_temp14

;lcall Display_formated_BCD_temp5
;//////////////////////////////////////////


;//////////////////////////////////////////////////////;
;Store ADC values in R0,R1 and R3,R4 (R2 is for delays);
;//////////////////////////////////////////////////////;

mov a, v0

cjne a, #0x00, FSM2_little

sjmp FSM_after
FSM2_little:
ljmp FSM2

FSM_after:

    ;anl ADCCON0, #0xF0
    ;orl ADCCON0, #0x07
    ;clr ADCF
    ;setb ADCS ;  ADC start trigger signal
    ;jnb ADCF, $ ; Wait for conversion complete
   
    ; Read the ADC result and store in [R1, R0]
    ;mov a, ADCRH  
    ;swap a
    ;push acc
    ;anl a, #0x0F
    ;mov R1, a
    ;mov VAL_LM4040+1,a
    ;pop acc
    ;anl a, #0xf0
    ;orl a, ADCRL
    ;mov R0, A
    ;mov VAL_LM4040+0,a
    
    ;
    ;
    ;
    
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x00
    
    lcall Read_ADC
    
    mov VAL_LM4040+0, R0
    mov VAL_LM4040+1, R1
    ;clr ADCF
    ;setb ADCS
    ;jnb ADCF,$
    
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x07
    lcall Read_ADC
    
    ;mov a, ADCRH
    ;swap a
    ;push acc
    ;anl a, #0xF0
    ;orl a, ADCRL
    ;mov R0,a

    ; Convert to voltage
  mov x+0, R0
  mov x+1, R1
  mov x+2, #0
  mov x+3, #0
  ;Load_y(50300) ; VCC voltage measured
  ;lcall mul32
  ;Load_y(4095) ; 2^12-1
  ;lcall div32
  Load_y(40959)
  lcall mul32

; Convert to BCD and display
;lcall hex2bcd
;lcall Display_formated_BCD_pin14

   ;Load_y(10)
   ;lcall mul32
   ;Load_y(273000)
   ;lcall sub32
   
   mov y+0, VAL_LM4040+0
   mov y+1, VAL_LM4040+1
   mov y+2, #0
   mov y+3, #0
   lcall div32
   
   
   Load_y(10)
   lcall mul32
   Load_y(273000)
   lcall sub32
   
   lcall hex2bcd
   lcall Display_formated_BCD_temp14
   
   ;;;
   
   ;;;;;
   
   ;;;
   
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x00
    
    lcall Read_ADC
    
    mov VAL_LM4040+0, R0
    mov VAL_LM4040+1, R1
    
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x01
    lcall Read_ADC
    
    mov x+0, R0
    
    mov x+1, R1
    
    mov x+2, #0
    
    mov x+3, #0
    
    Load_y(40959)
    lcall mul32
    
    mov y+0, VAL_LM4040+0
    
    mov y+1, VAL_LM4040+1
    
    mov y+2, #0
   
    mov y+3, #0
  
    lcall div32
   
   Load_y(41095)
   lcall mul32 ;410.9520322
   Load_y(4096)
   lcall div32;4096
   Load_y(20000)
   lcall add32
   
   lcall hex2bcd
    
   lcall Display_formated_BCD_temp5
   
    mov R2, #250
    Wait_Milli_Seconds(#250)
    mov R2, #250
    Wait_Milli_Seconds(#250)

    ;lcall hex2bcd
    ;lcall Display_formated_BCD_temp14

;///////////////////////////////////////////////;
;To send to a serial port using UART and python ;
;///////////////////////////////////////////////;

; Send_BCD(bcd+3)
; Send_BCD(bcd+2)
;
; mov a, #'.'
 ;   lcall putchar
;
; Send_BCD(bcd+1)
; Send_BCD(bcd+0)
;
; mov a, #'\r'
; lcall putchar
;
; mov a, #'\n'
; lcall putchar

;--------------------
;Set_Cursor(1, 4)
;Display_BCD(sec+1)
;Display_BCD(sec)
;Set_Cursor(1, 8)
;Display_BCD(compTemp1)
;Set_Cursor(1,10)
;Display_BCD(compTemp2)

    ;anl ADCCON0, #0xF0  ; Clear previous channel selection
    ;orl ADCCON0, #0x01  ; Select channel 1
    ;clr ADCF
    ;setb ADCS           ; Start ADC conversion
    ;jnb ADCF, $         ; Wait for conversion complete

    ;mov a, ADCRH
    ;swap a
    ;push acc
    ;anl a, #0x0f
    ;mov R4, a
    ;pop acc
    ;anl a, #0xf0
    ;orl a, ADCRL
    ;mov R3, A

    ; Convert to voltage and display
    ;mov x+0, R3
    ;mov x+1, R4
    ;mov x+2, #0
    ;mov x+3, #0
    ;Load_y(50300)  ; VCC voltage measured
    ;lcall mul32
  ;  Load_y(4095)   ; 2^12 - 1
   ; lcall div32
   
    ;lcall hex2bcd
    ;lcall Display_formated_BCD_pin5
    
    
    ;anl ADCCON0, #0xF0
    ;orl ADCCON0,  #0x00
    
    ;lcall Read_ADC
    ;mov VAL_LM4040+0,R3
    ;mov VAL_LM4040+1,R4
    
    
    
 ;   Load_y(41095)
;lcall mul32 ;410.9520322
;Load_y(4096)
;lcall div32;4096
;Load_y(22000)
;lcall add32

;mov R2, #250
;Wait_Milli_Seconds(#250)
;mov R2, #250
;Wait_Milli_Seconds(#250)

;lcall hex2bcd
;lcall Display_formated_BCD_temp5


;;;;;;;;;;;;;;;;;;;
;SEND TO TERMINAL ;
;;;;;;;;;;;;;;;;;;;

    
    mov a, bcd+2
    swap a
    anl a, #0x0F
    add a, #0x30
    lcall putchar
   
    mov  a, bcd+2     ; Get Tens digit (BCD format)
    anl  a, #0x0F
    add  a, #0x30     ; Convert to ASCII
    lcall putchar      ; Print tens   
    
    mov  a, bcd+1     ; Get Ones digit
    swap a            ; Swap to lower nibble
    anl a,#0x0F
    add a, #0x30
    lcall putchar      ; Print ones

    mov  a, #'.'      ; Print decimal point
    lcall putchar

    mov  a, bcd+1     ; Get fraction part (BCD format)
    anl  a, #0x0F     ; Mask lower nibble
    add  a, #0x30     ; Convert to ASCII
    lcall putchar

    mov  a, #'\r'     ; Print carriage return
    lcall putchar

    mov  a, #'\n'     ; Print newline
    lcall putchar


;;;;;;;;

;-------------------------------;
;Finite State Machine subroutine;
;-------------------------------;

FSM1:
    mov a, FSM1_state
   
;--------------------------------------------------------------------------------IDLE STATE
FSM1_state0:                        
    cjne a, #0, FSM1_state1
    Set_Cursor(1,1)
    Display_Char(#'0')
    mov pwm, #0                                          ;No power
    ; State 0 to State 1 condition
   
    ;jb STATEPIN, FSM1_state0_done                       ;REMOVED RECENTLY MIGHT MESS THINGS UP :O
    ;Wait_Milli_Seconds(#100)
    ;jb STATEPIN, FSM1_state0_done
    ;jnb STATEPIN, $    ; Wait for key release
    
    ;mov FSM1_state, #1
    ;mov sec,   #00
    ;mov sec+1, #00
   
FSM1_state0_done:
    ljmp FSM2
; ----------------------------------------------------------------------------- TEMPERATURE SOAK: RAMP TO SOAK
FSM1_state1:
    
                               
    cjne a, #1, FSM1_state2_extended2
    Set_Cursor(1,1)
    Display_Char(#'1')
    ;Set_Cursor(1,8)
    ;Display_BCD(compTemp1)
    ;Set_Cursor(1,10)
    ;Display_BCD(compTemp2) 
    ;;;;;;;;;;;;
   Set_Cursor(1, 4)
   Display_BCD(sec+1)
   Display_BCD(sec)
   ;;;;;;;
    mov a, flag
    cjne a,#1, no_beeping
    setb TR0
    Wait_Milli_Seconds(#250)
    clr TR0
    mov flag, #0
   
 no_beeping:
    mov pwm, #100                                        ;power = 100%
;    mov sec, #00
;    mov sec+1, #00

; ----------------- added code ---------------
    da a
    ;mov a, time_soak       ; can adjust with variables (the number time has to reach)
    lcall display_time_abort
    lcall store_values
    ; ------------------
    mov a, cmp+1
    clr c
; compares first if they are equal, else skip cmp+0 = sec+1
    cjne a, sec+1, first_not_equal
sjmp check_second_timeabort
first_not_equal:
    subb a, sec+1                ; Check if cmp+0 > sec
    jnc FSM1_abort_no         ; If first condition is met, check second one
check_second_timeabort:           ; Second comparison (cmp+0 - compTemp2)
    mov a, cmp+0
    clr c

; compares second if they are equal, else skip
    cjne a, sec+1, second_not_equal
sjmp completed_state
second_not_equal:
    subb a, sec  ; Check if cmp+1 >= compTemp1
    jnc FSM1_abort_no  ; If both conditions are met, go to next state
sjmp completed_state

FSM1_state2_extended2:
sjmp FSM1_state2_extended


completed_state:

abort_check:
    lcall display_temp_cooling
    lcall store_values
    ;------------
    mov a, cmp+1
    clr c
    subb a, compTemp1            ; Check if cmp+0 > compTemp1
    jnc completed_state6         ; cmp +1 < compTemp1
jz equal6
sjmp no_error
equal6:
    mov a, cmp+0
    clr c
    subb a, compTemp2
    jnc completed_state6
    sjmp no_error

; compares second if they are equal, else skip
completed_state6:
    mov FSM1_state, #0
    
    cpl LED_0

FSM1_abort_no:
no_error:
    ;mov seconds,#0x00
    ;mov a, temp_soak         ; can adjust with variables (the number temperature has to reach)
    lcall display_temp_soak
    lcall store_values
    ; ------------------
    mov a, cmp+1
    clr c
    subb a, compTemp1            ; Check if cmp+0 > compTemp1
    jc completed_state1          ; cmp +1 < compTemp1
jz equal1
sjmp FSM1_state1_done
equal1:
    mov a, cmp+0
    clr c
    subb a, compTemp2
    jc completed_state1
    sjmp FSM1_state1_done

; compares second if they are equal, else skip

; compares second if they are equal, else skip
FSM1_state2_extended:
sjmp FSM1_state2

completed_state1:
    mov FSM1_state, #2
    mov sec,   #00
    mov sec+1, #00

FSM1_state1_done:
    ljmp FSM2
; ------------------------------------------------------------------------------ TIME SOAK: TIME IN SOAK
FSM1_state2:
                
    cjne a, #2, FSM1_state3
    Set_Cursor(1,1)
    Display_Char(#'2')
    
   Set_Cursor(1, 4)
   Display_BCD(sec+1)
   Display_BCD(sec)
    
    mov pwm, #20       ; power = 20%
    da a
    ;mov a, time_soak       ; can adjust with variables (the number time has to reach)
   
    mov a, flag
   
    cjne a,#0, no_beeping2
    setb TR0
    Wait_Milli_Seconds(#250)
    clr TR0
    mov flag, #1
   
 no_beeping2:

    lcall display_time_soak
    lcall store_values
    ; ------------------
    mov a, cmp+1
    clr c
; compares first if they are equal, else skip cmp+0 = sec+1
    cjne a, sec+1, first_not_equal2
sjmp check_second_timesoak
first_not_equal2:
    subb a, sec+1                ; Check if cmp+0 > sec
    jnc FSM1_state2_done         ; If first condition is met, check second one
check_second_timesoak:           ; Second comparison (cmp+0 - compTemp2)
    mov a, cmp+0
    clr c

; compares second if they are equal, else skip
    cjne a, sec+1, second_not_equal2
sjmp completed_state2
second_not_equal2:
    subb a, sec  ; Check if cmp+1 >= compTemp1
    jnc FSM1_state2_done  ; If both conditions are met, go to next state

completed_state2:

	clr LED_0
	clr LED_1
	cpl LED_1
    mov FSM1_state, #3
    sjmp FSM1_state3

FSM1_state2_done:
    ljmp FSM2
   
FSM3:
ljmp FSM1
   
; ---------------------------------------------------------------------------- TEMPERATURE REFLOW:      RAMP TO REFLOW

; Directory for those reading this code:
;
; Summary of current FSM state:
; - splits a stored decimal value into 2 bcd registers -> converts from hex to bcd
; - stores those bcd values currently displaying (or not displaying, you can
;            just remove the display code) into cmp ( a comparison register)
; - runs through comparisons using cjne and bne to see if it goes to next state
; - loops and repeats
;
; -- FUNCTIONS --
; display_temp_refl: function that puts temp_refl into bcd values (hex2bcd)
; store values: function that stores the current bcd values into cmp, a variable.
;               Used after display_temp_refl (inteded purpose) to store that but if other bcd values
;               were stored before this, it will store those into cmp (meaning: not intended purpose but will work)
; -- BRANCHES  --
; first_not_equal: Goes to this branch if the branch is not equal
;                 -> if equal, it will pass through and go to next comparison (cmp+0) which are the 3rd and 4th digits
;
; FSM1_stateX_done: leads to FSM 2, which exits the FSM code
;
;
; FSM 3: just an extension of FSM1, since some branches can't reach in one go


FSM1_state3:                  
cjne a, #3, FSM1_state4
Set_Cursor(1,1)
Display_Char(#'3')
 ;   Set_Cursor(2,1)
;Display_BCD(cmp+1)
;Set_Cursor(2,3)
;Display_BCD(cmp+0)
   
mov pwm, #100       ; power = 100%
mov sec, #00
    mov sec+1, #00
   
    mov a, flag
   
    cjne a,#1, no_beeping3
    setb TR0
    Wait_Milli_Seconds(#250)
    clr TR0
    mov flag, #0
   
 no_beeping3:
   
    clr c
    lcall display_temp_refl
    lcall store_values
    ;------------
    mov a, cmp+1
    clr c
    subb a, compTemp1            ; Check if cmp+0 > compTemp1
    jc completed_state3          ; cmp +1 < compTemp1
jz equal3
sjmp FSM1_state3_done
equal3:
    mov a, cmp+0
    clr c
    subb a, compTemp2
    jc completed_state3
    sjmp FSM1_state3_done

; compares second if they are equal, else skip
completed_state3:
    mov FSM1_state, #4
;sjmp FSM1_state4         ; <-- add back if you don't want a delay between switching states
FSM1_state3_done:
    ljmp FSM2

FSM4:
ljmp FSM3

; --------------------------------------------------------------------------------- TIME REFLOW: TIME IN REFLOW
FSM1_state4:               ;REFLOW


cjne a, #4, FSM_5_BIG

sjmp FSM_5_SMALL

FSM_5_BIG:
ljmp FSM1_state5

FSM_5_SMALL:


Set_Cursor(1,1)
    Display_Char(#'4')
    
    Set_Cursor(1, 4)
   Display_BCD(sec+1)
   Display_BCD(sec)
    
    
    mov pwm, #20       ; power = 20%
    mov a, time_refl        ; can adjust with variables (the number time has to reach)
    lcall display_time_refl
    lcall store_values
    ; ------------------
   
    mov a, flag
    cjne a,#0, no_beeping4
    setb TR0
    Wait_Milli_Seconds(#250)
    clr TR0
    mov flag, #1
   
 no_beeping4:
    mov a, cmp+1
    clr c
; compares first if they are equal, else skip cmp+0 = sec+1
    cjne a, sec+1, first_not_equal4
sjmp check_second_timerefl
first_not_equal4:
    subb a, sec+1                ; Check if cmp+0 > sec
    jnc FSM1_state4_done         ; If first condition is met, check second one
check_second_timerefl:           ; Second comparison (cmp+0 - compTemp2)
    mov a, cmp+0
    clr c

; compares second if they are equal, else skip
    cjne a, sec+1, second_not_equal4
sjmp completed_state4
second_not_equal4:
    subb a, sec  ; Check if cmp+1 >= compTemp1
    jnc FSM1_state4_done  ; If both conditions are met, go to next state

completed_state4:

	clr LED_0
	clr LED_1
	cpl LED_0
	cpl LED_1
    mov FSM1_state, #5
    
    setb PWMRUN           ; activate servo motor
    Wait_Milli_Seconds(#250)
    Wait_Milli_Seconds(#250)
    Wait_Milli_Seconds(#250)
    Wait_Milli_Seconds(#250)
    Wait_Milli_Seconds(#250)
    Wait_Milli_Seconds(#250)
    clr PWMRUN
    
    
    sjmp FSM1_state5

FSM1_state4_done:
    ljmp FSM2
; ----------------------------------------------- COOLING STATE
FSM1_state5:
 
    cjne a, #5, FSM_4_SMALL
    
sjmp FSM_4_BIG
    
FSM_4_SMALL:

ljmp FSM4
    
FSM_4_BIG:
    
    
    Set_Cursor(1,1)
    Display_Char(#'5')
    mov pwm, #0       ; power = 0%
    ;mov a, #60         ; temperature at which cooling ends
    mov sec, #00
    mov sec+1,#00
    clr c
   
    Set_Cursor(1, 4)
   Display_BCD(sec+1)
   Display_BCD(sec)
   
    mov a, flag
    cjne a,#1, no_beeping5
    setb TR0
    Wait_Milli_Seconds(#250)
    clr TR0
    mov flag, #0
 
 no_beeping5:
   
    ;subb a, temp
    lcall display_temp_cooling
    lcall store_values
   
    mov a, cmp+1
    clr c
    subb a, compTemp1            ; Check if cmp+0 > compTemp1
    jnc completed_state5          ; cmp +1 < compTemp1
jz equal5
sjmp FSM1_state5_done

equal5:
    mov a, cmp+0
    clr c
    subb a, compTemp2
    jnc completed_state5
    sjmp FSM1_state5_done

; compares second if they are equal, else skip
completed_state5:
    mov FSM1_state, #0
    clr LED_1
    clr LED_0                   

;sjmp FSM1_state4         ; <-- add back if you don't want a delay between switching states
FSM1_state5_done:
    ljmp FSM2

FSM2:
;; -------- MODIFIED CODE ----------------

 
  lcall LCD_PB
  mov a, FSM1_state
  cjne a, #0, very_end
 

    mov pwm, #0                                          ;No power
    ; State 0 to State 1 condition

lcall Display_variables


;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;

; Wait 50 ms between readings
Wait_Milli_Seconds(#50)
Wait_Milli_Seconds(#50)

very_end:

ljmp Forever

END


  
