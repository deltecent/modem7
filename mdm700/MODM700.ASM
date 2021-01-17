VERSION	EQU	700	;MODM700 as of 11/04/84 -- CP/M MODEM PROGRAM
;
; This modem program uses the Christensen protocol.  It has both 'CRC'
; and CHECKSUM capability for error detection.  It supports dialing
; and auto-redialing for the Anchor Automation Signalman Mark XII,
; US Robotics modems, the Hayes Smartmodem 300 and 1200 and PMMI
; S-100 modems.  It supports up to two alternate dialing systems
; such as 'MCI', 'SPRINT', etc.
;
; Other external modems may be used, although manual dialing may be
; necessary.  Many overlays are available to allow easy configuration
; on various computers using I/O devices including the 2661, 8250, 8251,
; Z80-SIO, and many others.
;
; NOTE:  Current version is 73 sectors long. Use this figure when using
;	 DDT, etc. to merge the appropriate overlay, regardless of what
;	 the overlay may call for (such as 66 sectors for overlays made
;	 when the program was not as lengthy.)
;
;***********************************************************************
;
;	   THIS PROGRAM IS IN THE PUBLIC DOMAIN.
;
;***********************************************************************
;
; When transferring files modem-to-modem, the batch mode is extremely
; useful.  It allows automatic transmission of multiple files.  It can
; be used for single files or with wildcards.  With normal single program
; transfer, the receiving end switches from CRC to checksum in one minute
; and times out completely in 120 seconds.  (In batch mode it times out
; in 3 minutes for receive.)  This allows ample opportunity to transfer
; programs between individuals.
;
;	M7NM-6.ASM can be used to change the telephone overlay numbers
;	   and/or set the alternate dialing system code (also used to
;	   change HEXSHO and SAVSIZ, mentioned below.)
;
;	M7LIB.COM can be used to easily change any of the telephone
;	   overlay numbers.
;
;	M7FNK.COM can be used to easily change any of the 10 function
;	   key assignments (or the function key intercept character
;	   itself, which is currently the '^' character.
;
; Significant address changes now used:
;
;	0DFEH  -  HEXSHO  00 = do not show hex record count
;			  FF = show both hex and decimal count
;	0DFFH  -  SAVSIZ  20 = 4k file transfer buffer size
;			  40 = 8k file transfer buffer size
;			  80 = 16k file transfer buffer size
;	0E00H  -  NUMLIB  (start of telephone number library)
;
;***********************************************************************
;
; Many people have contributed ideas for this modem program:
;
;	Ward Christensen, Jim Mills, Mark Zeigler, Keith Petersen,
;	Paul Kelly, Bruce Ratoff, John Mahr, Rich Berg, Bob Clyne,
;	Bill Earnest, Paul Hansknecht, Ron Fowler, Fred Viles, Bob
;	Plouffe, Ben Bronson, Sigi Kluger, Irv Hoff, Frank Gaude'
;	and others.
;
;***********************************************************************
;
PORT	EQU	0C0H	;your base port (data or status)
;
MDCTL1	EQU	PORT	;modem control port
MDDATP	EQU	PORT+1	;modem data port
MDRCVB	EQU	02H	;modem receive bit (DAV)
MDRCVR	EQU	02H	;modem receive ready
MDSNDB	EQU	01H	;modem send bit
MDSNDR	EQU	01H	;modem send ready bit
;
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;		     special equates for PMMI
;
MDCTL2	EQU	PORT+3	;modem status port
;
BAUDRP	EQU	PORT+2	;modem baud rate port
BRKMASK	EQU	0FBH	;mask to set break
EVPAMSK	EQU	20H	;mask to set even parity
NOPAMSK	EQU	10H	;mask to reset to no parity
ODPAMSK	EQU	0CFH	;mask to set odd parity
;
ANSWMOD	EQU	1EH	;answer mode
ORIGMOD	EQU	1DH	;originate mode
WAITCTS	EQU	150	;number of seconds (x5) to wait for the
			;computer to answer after PMMI auto-dial
			;100=20 sec, 150=30 sec, 255=51 seconds
			;any number 0-255 acceptable
;
;		  (end of special PMMI equates)
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
YES	EQU	0FFH
NO	EQU	0
;
BUFSIZ	EQU	16	;buffer size in Kbytes for ASCII capture to disk
			;(16k is one file extent)
XFRSIZ	EQU	4	;file transfer buffer in Kbytes.  Do not make
			;any larger than BUFSIZ.  16k works fine on all
			;but very slowest systems
;
BDNMCH	EQU	75H	;bad name match
ERRLIM	EQU	10	;maximum allowable consecutive errors
ERRCRC	EQU	6	;CRC tries, then switches to CHECKSUM
LIBLEN	EQU	34	;length of each phone library entry
SHOWHEX	EQU	YES	;yes, show both decimal and hex record counts
			;no, show just decimal record count
RUB	EQU	7FH	;rub
CRC	EQU	'C'	;requests 'CRC' instead of 'CKSUM'
ESC	EQU	'['-40H	;^[ = escape
SOH	EQU	'A'-40H	;^A = start of header
EOT	EQU	'D'-40H	;^D = end of text
EXITCHR	EQU	'E'-40H	;^E = exit character
ACK	EQU	'F'-40H	;^F = acknowledge
OKNMCH	EQU	'F'-40H	;^F = ok name match
BELL	EQU	'G'-40H	;^G = bell character
BKSP	EQU	'H'-40H	;^H = backspace
LF	EQU	'J'-40H	;^J = linefeed
CR	EQU	'M'-40H	;^M = carriage return
XON	EQU	'Q'-40H	;^Q = XON character
XOFF	EQU	'S'-40H	;^S = XOFF character
NAK	EQU	'U'-40H	;^U = not acknowledge
CANCEL	EQU	'X'-40H	;^X = cancel send or receive
EOFCHAR	EQU	'Z'-40H	;^Z = end of file
;
	ORG	0100H
;
	JMP	START	;skip the data area below
;
; These routines and equates are at the beginning of the program so
; they can be patched by a monitor or overlay file without re-assembling
; the program.
;
PMMIMD	DB	YES	;yes=PMMI modem
AUTDIAL	DB	NO	;yes=Hayes-type autodial modem
TCHPUL	DB	'T'	;T=touch, P=pulse (autodial-only)
CLOCK	DB	40	;clock speed in MHz x 10, 25.5 MHz max.
			;2 MHz=20, 3.68 MH=37, 4 MHz=40, etc.
MSPEED	DB	1	;sets display time for sending a file
			;0=110	1=300  2=450  3=600  4=710
			;5=1200 6=2400 7=4800 8=9600 9=19200
BYTDLY	DB	5	;0=0 delay  1=10 ms  5=50 ms - 9=90 ms
			;defaut time to send character in ter-
			;minal mode file transfer for slow BBS
CRDLY	DB	5	;0=0 delay 1=100 ms 5=500 ms - 9=900 ms
			;default time for extra wait after CRLF
			;in terminal mode file transfer
NOFCOL	DB	5	;number of directory columns
STUPTST	DB	NO	;yes=non-PMMI setup routine
SCRNTST	DB	NO	;yes=if home cursor and clear screen
			;routine at CLRSCR
RETRY	DB	YES	;yes=reset the error limit to try again
			;no=abort after 10 consecutive errors
BACKUP	DB	NO	;yes=make .BAK file
CRCDFLT	DB	YES	;yes=default to CRC checking
			;no=default to Checksum checking
TGLECRC	DB	YES	;yes=allow toggling of Checksum to CRC
CONVRUB	DB	NO	;yes=convert rub to backspace
TGLERUB	DB	YES	;yes=allow toggling of rub to backspace
ADDLFD	DB	NO	;no=no LF after CR to send file in
			;terminal mode (added by remote echo)
TGLELF	DB	YES	;yes=allow toggling of LF after CR
TRANLOG	DB	NO	;yes=allow transmission of logon
			;write logon sequence at location LOGON
SAVCCP	DB	YES	;yes=do not overwrite CCP
LOCNXT	DB	NO	;yes=local cmd if EXTCHR precedes
			;no=not local cmd if EXTCHR precedes
TGLELOC	DB	YES	;yes=allow toggling of LOCNXT
LSTTST	DB	YES	;yes=allow toggling of printer on/off
			;in terminal mode. Set to no if using
			;the printer port for the modem
XOFFTST	DB	NO	;yes=allow testing of XOFF from remote
			;while sending a file in terminal mode
XONWAIT	DB	NO	;yes=wait for XON after sending CR while
			;transmitting a file in terminal mode
TGXOFF	DB	YES	;yes=allow toggling of XOFF testing
IGNRCTL	DB	NO	;yes=do not send control characters
			;above CTL-M to CRT in terminal mode
			;no=send any incoming CTL-char to CRT
EXTRA1	DB	0	;for future expansion
EXTRA2	DB	0	;for future expansion
BRKCHR	DB	'@'-40H	;^@ = Send a 300 ms. break tone
NOCONCT	DB	'N'-40H	;^N = Disconnect from phone line
LOGCHR	DB	'L'-40H	;^L = Send logon
LSTCHR	DB	'P'-40H	;^P = Toggle printer
UNSAVCH	DB	'R'-40H	;^R = Close input text buffer
TRANCHR	DB	'T'-40H	;^T = Transmit file to remote
SAVECHR	DB	'Y'-40H	;^Y = Open input text buffer
EXTCHR	DB	'^'-40H	;^^ = Send next character
;
; Equates used only by PMMI routines grouped together here
;
PULRATE	DB	250	;125=20pps dialing, 250=10pps
CHGBAUD	DB	'B'-40H	;^B = Used with PMMIMD in terminal
			;mode to change baud rate on fly
;
; Handles in/out ports for data and status
;
I$MDCTL1 IN	MDCTL1	! RET		;in modem control port
	 DB	0,0,0,0,0,0,0		;spares if needed for non-PMMI
;
O$MDDATP OUT	MDDATP	! RET		;out modem data port
	 DB	0,0,0,0,0,0,0		;spares if needed for non=PMMI
;
I$MDDATP IN	MDDATP	! RET		;in modem data port
	 DB	0,0,0,0,0,0,0		;spares if needed for non-PMMI
;
A$MDRCVB ANI	MDRCVB	! RET		;bit to test for receive ready
C$MDRCVR CPI	MDRCVR	! RET		;value of receive bit when ready
A$MDSNDB ANI	MDSNDB	! RET		;bit to test for send ready
C$MDSNDR CPI	MDSNDR	! RET		;value of send bit when ready
;
;====================== SPECIAL PMMI PORTS =============================
;
I$BAUDRP IN	BAUDRP	! RET		;in baudrate port
O$BAUDRP OUT	BAUDRP	! RET		;out baudrate port
O$MDCTL1 OUT	MDCTL1	! RET		;out modem control port #1
O$MDCTL2 OUT	MDCTL2	! RET		;out modem control port #2
;
LOGONPTR DW	LOGON
J$DIAL	 JMP	DIAL
J$DSCONT JMP	DSCONT
J$GOODBY JMP	GOODBY
J$INITMD JMP	INITMD
J$NWBAU	 JMP	NWBAU
J$NPARIT JMP	NPARIT
J$PRITY	 JMP	PRITY
J$STUPR	 JMP	STUPR
J$SPMEN	 JMP	SPMEN
J$SYSVR	 JMP	SYSVR
J$BREAK	 JMP	SNDBRK
;
; Next six lines should not be changed by user overlay as these go to
; specific locations in the main program, not in the overlay.
;
J$ILPRT	 JMP	ILPRT
J$INBUF	 JMP	INBUF
J$INLNCP JMP	INLNCP
J$INMDM	 JMP	INMDM
J$NXTSCR JMP	NXTSCR
J$TIMER	 JMP	TIMER
;
; Clear sequences are for Televideo, Lear Siegler, etc.  Change to match
; your terminal.  (Heath uses ESC 4AH for clear to end of screen, ESC 45H
; to clear screen.  Lear Siegler and others use ESC 79H for clear to end
; of screen and ESC 3AH to clear screen.)  Room allowed for four bytes.
; (Last zero needed for stopping the string display.  Any extra 0's just
; act as NOP's.)
;
CLREOS	CALL	J$ILPRT
	DB	ESC,79H,0,0,0
	RET
;
CLRSCR	CALL	J$ILPRT
	DB	ESC,3AH,0,0,0
	RET
;
;======================= SIGN-ON MESSAGE ==============================
;
; Send version number and date
;
SYSVR	LDA	PMMIMD		;using the PMMI S-100 modem?
	ORA	A
	JZ	SYSVR1		;go if not
	CALL	J$ILPRT
	DB	'Version for PMMI S-100 modem starting at port: ',0
	LDA	I$MDCTL1+1
	CALL	HEXO		;put in PMMI control port number
	CALL	J$ILPRT
	DB	'H',CR,LF,0
	RET
;
SYSVR1	CALL	J$ILPRT		;if not using the PMMI S-100 board
	DB	'Version for Non-PMMI modem',CR,LF,0
	RET
;
;==================== LOGON MESSAGE (IF ANY) ===========================
;
; Insert your logon message here.  End with a 0 (for"CALL ILPRT").
; PMMIusers have 59 bytes available, non-PMMI users have approximately
; 2K bytes available as they can overwrite all the following PMMI rou-
; tines if they wish.  This method allows the external overlays to have
; plenty of room.  It keeps the phone number library at a fixed location.
;
LOGON	DS	59	;up to 59 characters allowed
	DB	0	;to terminate the logon message
;
;=============== NON-PMMI INITIALIZATION (IF ANY) ======================
;
; Insert your initialization routine here if needed.  Can replace the
; following special PMMI area to set speed and auto-dial.  Over 950
; bytes are available for this purpose.  (End your routine with a RET.)
;
INITMD	RET
;
;========== NON-PMMI SETUP (SPEED CHANGE, ETC.) IF ANY ==============
;
; Insert your speed change and/or auto-dialing routines here.  Over 950
; bytes are available (INCLUDING INITMD, above).  End your routine with
; a RET.
;
STUPR	RET
;
; Not needed if using the PMMI board, as it has its own break routine
;
SNDBRK	RET
;
;**************** START OF SPECIAL PMMI ROUTINES **********************
;
;=======================================================================
;			SETS THE BAUD RATE
;=======================================================================
;
STBAUD	LDA	ANSWFLG		;if 'O' or 'A' not requested and
	ORA	A		;   baudrate not specified, returns
	JZ	FXBAUD		;   with current mode and rate
	LDA	ORIGFLG		;if option requested, a blank returns
	ORA	A		;   with current mode and rate
	RNZ			;no change if neither 'O' or 'A' shown
;
FXBAUD	CALL	GTBAUD		;calculate PMMI baud rate divisor
	CALL	STMSPD		;set the file time transfer value
	CALL	O$BAUDRP	;set the PMMI board to that baudrate
	CPI	52
	MVI	A,5FH		;DTR (filter for over 300 baud)
	JC	GT300		;yes, greater than
	MVI	A,7FH		;DTR (filter for 300 and less baud)
;
GT300	CALL	O$MDCTL2
	STA	MDCTLB		;save modem control byte
;
OFHOOK	LXI	H,7500		;throw in some delay
;
OFFDLY	DCR	L
	JNZ	OFFDLY
	DCR	H
	JNZ	OFFDLY
	LDA	UARTCT		;UART control byte for 'A' or 'O'
	CALL	O$MDCTL1	;now set to answer or originate
	MOV	A,C
	STA	MSPEED		;set the file transfer time value
	XRA	A		;clear the flags
	RET
;
;=======================================================================
;		 CALCULATES THE BAUD RATE DIVISOR
;
; Returns with current baud rate intact if a blank or null in the speed
; field (extent area).
;
GTBAUD	LDA	FCB+9		;get 1st digit of requested baudrate
	CPI	' '		;if a space, return with current speed
	LDA	CURRENT
	RZ
	LDA	FCB+9
	ORA	A		;if a null, return with current speed
	LDA	CURRENT
	RZ
;
	LXI	D,FCB+9		;get the requested speed
	LXI	H,0
;
DECLP	LDAX	D		;get the ASCII digit
	INX	D
	CPI	' '
	JZ	DECLP
	CPI	'0'		;numerals are 0-9
	JC	BADRTE
	CPI	'9'+1
	JNC	BADRTE
	SUI	'0'
	MOV	B,H
	MOV	C,L
	DAD	H
	DAD	H
	DAD	B
	DAD	H
	ADD	L
	MOV	L,A
	JNZ	DIGNC
	INR	H
;
DIGNC	MOV	A,E
	CPI	FCB+12
	JNZ	DECLP
	MOV	A,H
	CMA
	MOV	D,A
	MOV	A,L
	CMA
	MOV	E,A
	INX	D
	LXI	H,15625		;250000/16
	LXI	B,-1
;
DIVLP	INX	B
	DAD	D
	JC	DIVLP
	MOV	A,B
	ORA	A
	MOV	A,C
	STA	CURRENT		;can use this the next time by default
	RZ
;
BADRTE	CALL	ERXIT
	DB	'++ INVALID BAUDRATE ++$'
;
;=======================================================================
;		    SETS 'MSPEED' TO BAUD RATE
;
STMSPD	MVI	C,0		;changes PMMI mspeed for 110-710 bps
	CPI	100		;<300 bps
	RNC
	INR	C		;C=1 for 300 bps
	CPI	40		;<450 bps
	RNC
	INR	C		;C=2 for 450 bps
	CPI	30		;<600 bps
	RNC
	INR	C		;C=3 for 600 bps
	CPI	24		;<710 bps
	RNC
	INR	C		;C=4 for 710 bps
	RET
;
; Change baudrate on-the-fly with CTL-B (while in terminal mode)
;
NWBAU	LDA	PMMIMD
	ORA	A
	RZ
	CALL	J$ILPRT
	DB	CR,LF,'Enter new Baudrate: ',0
	LXI	H,FCB+9
	MVI	M,' '		;keep current baud if none included
;
NWBAU1	CALL	KEYIN		;get the baud rate
	CPI	CR		;carriage ret finishes baud rate entry
	CZ	CRLF		;if a 'CR', baud rate has been entered
	JZ	FXBAUD		;go change the baud rate
;
NWBAU2	CPI	'0'		;numerals are 0-9
	JC	NWBAU1
	CPI	'9'+1
	JNC	NWBAU1		;if not a numeral, ignore, ask again
	MOV	M,A		;store answer starting at FCB+9
	CALL	TYPE		;show the numeral on the CRT
	INX	H		;next storage location in FCB
	JMP	NWBAU1		;get the next numeral
;
;======================= PARITY ROUTINES ===============================
;
;--->PRITY: Routine to setup PMMI for odd/even parity.
;
PRITY	LDA	PMMIMD		;is modem a PMMI?
	ORA	A		;set flags
	RZ			;no, return
	LDA	OPRITY		;get odd parity request byte
	ORA	A		;set flags
	JNZ	EVNPAR		;if not odd see if it is even
	LDA	UARTCT		;get uart/modem control byte
	ANI	ODPAMSK
	JMP	PRITY1
;
EVNPAR	LDA	EPRITY		;get even parity request byte
	ORA	A		;set flags
	RNZ			;if even parity not specified return
	LDA	UARTCT		;get uart/modem control byte
	ANI	ODPAMSK		;set for parity
	ORI	EVPAMSK		;now set for even parity
;
PRITY1	STA	UARTCT
	JMP	O$MDCTL1	;send to PMMI
;
NPARIT	LDA	PMMIMD
	ORA	A
	RZ
	LDA	UARTCT
	ORI	NOPAMSK		;reset parity bit on PMMI
	JMP	O$MDCTL1
;
;=======================================================================
;		   HAYES/PMMI DIALING ROUTINES
;=======================================================================
;
	DS	128	;for expansion
;
; Modem control command words
;
BRKMSK	EQU	0	;tele line on hook (break while dialing)
CLEAR	EQU	3FH	;idle mode
DTMSK	EQU	1	;dial tone mask
MAKEM	EQU	1	;tele line make (off hook)
RBLMT	EQU	35	;7 seconds to wait til no-ring-heard msg
RBWAIT	EQU	50	;5 second delay before redialing PMMI
SMWAIT	EQU	15	;1.5 sec delay before redialing HAYES
TMPUL	EQU	80H	;timer pulses mask bit
TRATE	EQU	250	;value for 0.1 second
;
; Dialing routine
;
DIAL	LDA	PMMIMD	;using a PMMI modem?
	ORA	A
	JNZ	DIAL1
	LDA	AUTDIAL
	ORA	A
	RZ			;return if neither modem
	CALL	SMNSY		;make sure autodial modem speaker is on
;
DIAL1	XRA	A
	STA	AUTDIR		;zero the direct to terminal mode flag
	STA	AUTOFL		;zero the auto-linking flag
	STA	CRFLAG		;zero the continuous dial flag
	LXI	H,0
	SHLD	DIALCT		;zero the dial count
	LXI	H,CMDBUF+1	;point to the number of characters in
	MOV	A,M		;  the buffer, then get the number
	CPI	3+1		;anything typed after 'CAL'?
	JC	DIAL2		;if not, go through library routine
;
; If there were only 3 characters, then "CAL<RET>" was typed -- the user
; obviously expecting to get a phone number (or letter) from the library
; file.  If 4 or more, a number (or letter) was typed in from the menu
; command line, so move the characters down 4 to compensate.  Needed for
; auto-redialing of menu command line entries.
;
	MOV	C,A		;put into the 'C' reg.
	MVI	B,0		;will move original number down 4
	SUI	4		;eliminate the 'CAL' portion
	MOV	M,A		;store new count at cmdbuf+1
	INX	H		;CMDBUF+2 (first character of string)
	XCHG			;'DE' now has CMDBUF+2
	LXI	H,CMDBUF+6	;point to number (or letter) to dial
	CALL	MOVER		;move the group down 4 places
	JMP	DIAL4		;check if library number, then dial
;
; Comes here if no phone number was manually entered after 'CAL' and if
; no phone library code was entered.  Displays the phone number library
; then asks for an entry.
;
DIAL2	MVI	C,18		;number of lines to move
	LXI	H,NUMLIB	;start of phone number library
	LXI	D,BUFFER	;buffer add. to store them temporarily
	CALL	NEWLINE		;start with CR/LF
	STAX	D		;+LF
	INX	D		;and bump it
;
DIAL3	MVI	B,LIBLEN	;number of bytes to move
	CALL	MOVE		;move to buffer
	CALL	SPACES		;2 entries + 3 spaces = 71 characters
	PUSH	H		;save source address
	PUSH	D		;save destination address
	LXI	D,(17*LIBLEN)	;get offset of 17 times entry length
	DAD	D		;add it to source address
	POP	D		;restore destination address
	MVI	B,LIBLEN	;get length of library entry
	CALL	MOVE		;move another entry
	POP	H		;restore source address
	CALL	NEWLINE
	DCR	C		;one less line to print
	JNZ	DIAL3		;if not zero, print another
	MVI	A,'$'		;BDOS print routine terminate character
	STAX	D		;store in buffer
	CALL	CLRTST
	MVI	C,PRINT
	LXI	D,BUFFER	;print the library on the CRT
	CALL	BDOS
	CALL	J$ILPRT		;ask which one is wanted
	DB	CR,LF,'Enter library code or phone number,',CR,LF
	DB	'Hit RET to abort this function now or',CR,LF
	DB	'CTL-X quits while dialing or ringing: ',0
	LXI	D,CMDBUF
	CALL	INBUF		;get the answer from the keyboard
;
; You now have either a library code or a manually entered phone num-
; ber.	These either came from the menu command line or from the library
; command line.  Next we see if a code, if so, get the corresponding
; line with phone number from the library.  If a number greater than
; one digit, we ignore the library look-up.  (Ringback numbers must end
; with letter 'R'.)
;
DIAL4	LXI	H,CMDBUF+1	;number of characters in buffer
	MOV	A,M
	ORA	A		;null means CR was typed
	JZ	DLXIT2		;abort dialing, return to menu
	STA	NUMBER
	LDA	CMDBUF+3	;see if at least two characters entered
	CPI	'/'		;slash for linking, direct to terminal
	CZ	AUTO		;  mode on answer
	CPI	','		;comma used for linking
	CZ	AUTO1		;if yes, set it up for auto-linking
;
; Check to see how many characters were typed.	If more than one, then
; it was a hand-entered phone number, so exit.
;
DIAL5	CALL	DIALBG		;disconnect, reconnect
	LDA	AUTOFL		;auto-link flag set?
	ORA	A
	JNZ	AUTO2		;if yes exit
	LDA	NUMBER		;number of characters in buffer
	STA	CMDBUF+1	;reset the character count, if needed
	CPI	1+1		;more than one character?
	JNC	DIAL14		;if more than one, hand-entered number
	LXI	H,CMDBUF+2	;first character in phone number line
;
; If just one character entered, see if a (A-Z) letter
;
DIAL6	MOV	A,M
	MVI	B,'A'		;first letter of alphabet
	MVI	E,0		;counts number of letters to match
	MVI	C,26		;number of letters in alphabet
;
DIAL7	CMP	B		;letter from table?
	JZ	DIAL9		;if yes, get phone number, else
	INR	B		;make next letter (A-Z)
	INR	E		;count up
	DCR	C		;count down
	JNZ	DIAL7		;try next one in (A-Z) table
;
; If not (A-Z) then should be (0-9)
;
	MVI	B,'0'		;first digit to check
	MVI	E,26		;point past alpha codes
	MVI	C,10		;number of digits in table
;
DIAL8	CMP	B		;number from table?
	JZ	DIAL9		;if yes, go dial, else
	INR	B		;make next digit to compare
	INR	E		;make next table line number
	DCR	C		;count down - loop counter
	JNZ	DIAL8		;loop
	JMP	DIALBD		;error if not a number or a letter
;
; Now have a match between the requested code and one in the library.
; E-reg. holds the library line number (1-36) that matches the requested
; code (A-Z or 0-9).
;
DIAL9	LXI	H,NUMLIB	;phone number library
	LXI	B,LIBLEN	;length of library entry
	MOV	A,E		;number of times to library length to HL
	ORA	A		;set flags
	JZ	DIAL11
;
DIAL10	MOV	A,M		;get first char of selected lib entry
	ORA	A		;set flags
	JZ	DIALBD		;send bad library msg and abort
	DAD	B		;increment 'HL' by library length
	DCR	E		;countdown
	JNZ	DIAL10		;not there yet, loop
;
; Now have the line in the phone number library matching the requested
; letter so store that line starting at 'CMDBUF+1'
;
DIAL11	MVI	B,LIBLEN	;number of characters to get from table
	LXI	D,CMDBUF+1	;point to buffer
	XCHG			;'HL' points to CMDBUF+1
	MOV	M,B		;length of each table entry
	XCHG			;restore the registers
	INX	D		;point to first char position in buffer
	CALL	MOVE		;move the table entry to the buffer
;
; Now have the full line including phone number in 'CMDBUF' area.  Scan
; past the descriptive portion of library entry - terminate scan at the
; first '.'  This allows commas and numbers to be part of the text, such
; as:
;	     'A=DataTech, Node 7..1-408-238-9621'
;
DIAL12	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	CNZ	SMINIT		;if yes, initialize
	LXI	H,CMDBUF+1
	MOV	E,M		;number of chars in buffer
	INX	H		;point to 1st character in buffer
;
DIAL13	MOV	A,M		;get next character
	CALL	TYPE		;show it
	INX	H		;bump pointer
	DCR	E		;decrement count
	JZ	DLXIT		;exit if no '.' (bad library entry)
	CPI	'.'		;dot?
	JZ	DIAL15		;yes, go dial the phone
	JMP	DIAL13		;no, loop for next character
;
; There is a user entered phone number in 'CMDBUF' area
;
DIAL14	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	CNZ	SMINIT		;if yes, initialize
	LXI	H,CMDBUF+1	;get the number of characters in buffer
	MOV	A,M
	MOV	E,M
	INX	H		;point to 1st character to dial
;
; Loop to dial the phone number pointed to by 'HL', character count in
; the 'E' register.
;
DIAL15	MOV	A,M		;get first number from the buffer
	ORA	A		;set flags
	JZ	DIALBD		;bad number if a null
;
; Dial a digit, check keyboard for abort
;
	CALL	DL		;dial a digit, show on CRT
	CALL	STAT		;keypress?
	JZ	DIAL17		;if not, exit
	CALL	KEYIN		;yes, go get it
	CPI	CANCEL		;CTL-X?
	JNZ	DIAL17		;if not, exit
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JZ	DLXIT		;if not, exit now, otherise clear line
;
; If using an autodial modem, backspace 30 tims to make sure the entire
; number plus 'DT' part of 'ATDT' is erased.
;
	MVI	C,30
;
DIAL16	MVI	B,BKSP
	CALL	SNDCHR		;send to the modem to cancel call
	DCR	C
	JNZ	DIAL16		;if not zero, do another
	MVI	B,CR
	CALL	SNDCHR
	MVI	A,' '
	CALL	TYPE		;show on CRT
	JMP	DLXIT		;now go abort
;
DIAL17	INX	H		;bump pointer
	DCR	E		;one less character to go
	JNZ	DIAL15		;if not done, send the next digit
;
; Show the number of dial attempts
;
	CALL	J$ILPRT
	DB	' - try #',0
	LHLD	DIALCT		;increment the dial count
	INX	H
	SHLD	DIALCT
	CALL	DECOUT		;show number of attempts so far
	MVI	A,' '		;extra space to position cursor
	CALL	TYPE
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JZ	DIAL19		;if not, exit
	MVI	B,CR		;tells the modem the number is done
	CALL	SNDCHR		;just have one character to send
;
DIAL18	CALL	J$INMDM		;catch any output from the modem
	JNC	DIAL18
	JMP	SMRSLT		;number sent to modem, now get results
;
; Dialing is all done, this section is PMMI-only
;
DIAL19	MVI	A,07FH		;turn on PMMI 'DTR'
	CALL	O$MDCTL2	;timer rate?
	MVI	B,1		;0.1 second per interval
	CALL	J$TIMER
	MVI	A,5DH		;2 stop bits, nor parity, 8 data bits
	CALL	O$MDCTL1
	MVI	D,4		;clear to send mask
	MVI	C,WAITCTS	;wait time for CTS
	CALL	WAIT		;(30 seconds, can set 'WAITCTS' for
				;up to 51 seconds for European use)
;
; If PMMI connection made, go get options for starting communications
;
	JNC	CONMD		;connection made
;
; Connection not made, see if a redial is desired
;
;	CALL	DSCONT		;hang-up so we can redial
;
DLGN	LXI	SP,STACK	;reset the stack to normal, just in case
	LDA	CRFLAG		;continuous redial flag
	ORA	A
	JNZ	DLGN2		;if already set, go dial again
	CALL	J$ILPRT		;see if we should keep trying
	DB	CR,LF,CR,LF,'     Redial? (C/Y/N/Q): ',BELL,0
	CALL	KBDCHR
	CALL	CRLF		;turn up a line
	CPI	'Y'		;redial?
	JZ	DLGN2		;yes, redial
	CPI	'C'		;continuous redial?
	JZ	DLGN1		;if yes, set continuous redial flag
	CPI	'Q'
	JNZ	DLXIT1		;none of these, quit
	CALL	SMQT		;turn off the loud speaker for 'Quiet'
;
DLGN1	MVI	A,1
	STA	CRFLAG		;continuous redial flag
;
DLGN2	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JNZ	DLGN3		;if yes, exit
	MVI	B,RBWAIT	;wait for PMMI reset (or busy)
	CALL	J$TIMER		;or busy tone may be sensed as dialtone
	JMP	DLGN4
;
DLGN3	MVI	B,SMWAIT
	CALL	J$TIMER
;
DLGN4	CALL	CRLF		;start a new line
	JMP	DIAL5		;redial entry point
;
; Connection has been made
;
CONMD	LDA	PMMIMD
	ORA	A
	JZ	CONMD1
	LDA	CURRENT		;get curret baud rate
	CALL	O$BAUDRP	;set baudrate
;
CONMD1	MVI	B,2
	CALL	J$TIMER
	CALL	J$ILPRT
	DB	BELL,CR,LF,CR,LF,'     CONNECTED',0
	LDA	AUTDIR		;going direct to terminal mode?
	ORA	A
	JNZ	RETRN
	LDA	CRFLAG		;in continuous redial or first time try?
	ORA	A
	JZ	RETRN		;go to terminal mode if first time
	CALL	J$ILPRT
	DB	' - any key for terminal mode ',0
;
CONMD2	MVI	E,10
;
CONMD3	CALL	STAT		;keypress?
	JZ	CONMD4		;exit if no keys pressed
	CALL	KEYIN
	XRA	A
	JMP	RETRN		;key pressed, go to terminal mode
;
CONMD4	MVI	B,1		;wait 0.1 second
	CALL	J$TIMER
	DCR	E		;one less loop to make
	JNZ	CONMD3		;see if a keyboard character yet
	MVI	A,BELL		;sound a bell
	CALL	TYPE
	JMP	CONMD2		;reset the counter
;
; Automatic dialing routine, prints the number being dialed.  If we find
; 'R', it either has to be the final character for ringback or toss it.
;
DL	CALL	TYPE		;print whatever character, dashes, etc.
	CPI	'R'		;could it be a ringback character?
	JNZ	DL1		;if not, probably a number so exit
	MOV	A,E		;get the character count.  Is this "R"
	CPI	1		;  the last character in the string?
	JZ	RNGBK		;if yes, set up ringback
	RET			;if not, ignore the 'R'
;
DL1	MOV	B,A		;store the character for now
	CALL	DLD		;check for alternate dialing like 'MCI'
	MOV	A,B		;get the original character back
;
DL2	CPI	'*'		;* is a valid dial digit
	JZ	DL3
	CPI	'#'		;# is a valid dial digit
	JZ	DL3
	CPI	','		;comma indicates a short delay-time
	JZ	DL3
	CPI	'0'		;digits are (0-9)
	RC			;exit less than ASCII '0'
	CPI	'9'+1
	RNC			;exit if more than ASCII '9'
	SUI	'0'		;strip ASCII - could also do 'ANI 0FH'
	JNZ	DL3
	MVI	A,10		;convert zero to 10 pulses
;
; Sends the digit to the modem.  Waits 100 ms. after each digit to in-
; sure it gets to the modem ok.
;
DL3	MOV	C,A
	LDA	PMMIMD		;using a PMMI?
	ORA	A
	JNZ	DL4		;if yes, exit
	CALL	SNDCHR		;character is already in the 'B' reg.
	MVI	B,1		;slight delay to let modem settle down
	JMP	J$TIMER
;
DL4	LDA	PULRATE
	CALL	O$BAUDRP
;
DL5	CALL	I$BAUDRP
	ANI	TMPUL
	JNZ	DL5
;
DL6	CALL	I$BAUDRP
	ANI	TMPUL
	JZ	DL6
;
DL7	MVI	A,MAKEM
	CALL	O$MDCTL1
;
DL8	CALL	I$BAUDRP
	ANI	TMPUL
	JNZ	DL8
	MVI	A,BRKMSK
	CALL	O$MDCTL1
;
DL9	CALL	I$BAUDRP
	ANI	TMPUL
	JZ	DL9
	DCR	C
	JNZ	DL7
	MVI	A,MAKEM
	CALL	O$MDCTL1
	MVI	B,2
	JMP	J$TIMER
;
; Print bad library number message and abort if a null is encountered.
;
DIALBD	CALL	J$ILPRT
	DB	CR,LF,CR,LF,'++ Bad library number called ++',CR,LF,0
;
DLXIT	CALL	CRLF		;turn up a new line
;
DLXIT1	LXI	SP,STACK	;make sure the stack is normal again
;;;	CALL	J$GOODBY	;user routine to disable DTR, if any
	DB	0,0,0		;(PREVENT DOUBLE TIME FOR DISCONNECT)
	CALL	J$DSCONT	;hang up the phone and reset the modem
;
DLXIT2	XRA	A
	STA	CRFLAG		;reset the continuous redial flag
	JMP	MENU
;
; Disconnect from the line, reconnect and wait for the dialtone.
;
DIALBG	LDA	AUTDIAL		;Hayes-type autodial modem?
	ORA	A
	RNZ			;if yes, finished
	MVI	A,MAKEM		;go off-hook
	CALL	O$MDCTL1
	MVI	D,DTMSK		;dial tone mask
	MVI	C,50		;waits up to 10 seconds for dial tone
	CALL	WAIT		;wait for dial tone
;
; Wait subroutine will return with carry set if unable to get dialtone.
; If carry is not set, the dialtone was received.
;
	RNC			;if dial tone within 10 seconds
	CALL	J$ILPRT		;otherwise print error message
	DB	CR,LF,CR,LF,'++ NO DIAL TONE ++ ',BELL,0
	POP	H		;restore the stack to normal
	JMP	DLXIT		;forget it.
;
; Do any alternate dialing such as 'MCI' or 'SPRINT'
;
DLD	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	RZ			;if not, exit
	LDA	TCHPUL		;using touch tone dialing?
	CPI	'T'
	RNZ			;if not, ignore
	MOV	A,B		;get the character back
	CPI	'<'		;alternate dialing system #1 (MCI?)
	JNZ	DLD1		;if not, exit
	PUSH	H		;save the current values
	LXI	H,ALTDL1	;alternate dialing area
	JMP	DLD2
;
DLD1	CPI	'>'		;alternate dialing system #2 (Sprint?)
	RNZ			;if neither, exit
	PUSH	H		;save the current values
	LXI	H,ALTDL2
;
DLD2	MOV	A,M
	CPI	'$'		;ready to terminate?
	JZ	DLD3		;if yes, exit
;
; Move the semicolons up one line if you do not want to see the Sprint
; number dialed.
;
	CALL	TYPE		;display the character
;;;	DB	0,0,0		;(keeps the total bytes similar)
	MOV	B,A		;need the char. in 'B' to send to modem
	CALL	DL2		;send proper characters to the modem
	INX	H		;next location
	CALL	STAT		;keypress?
	JZ	DLD2		;if not, do the next character
	CALL	KEYIN		;yes, go get it
	CPI	CANCEL		;CTL-X?
	JNZ	DLD2		;if not, handle the next character
	POP	H		;if yes, reset the stack
	JMP	DLXIT		;if yes, exit
;
DLD3	MVI	A,' '
	MOV	B,A		;clears 'B' from last digit sent
	CALL	TYPE
	POP	H		;restore the stack
	RET
;
; Disconnect the autodial modem from the phone line.  Sends 'I, CR' to
; the Racal-Vadic to return to IDLE mode
;
GOODBY
DSCONT	LDA	AUTDIAL		;using a Hayes-type autodial modem?
	ORA	A
	JNZ	DSCON1		;if yes, skip PMMI section
	XRA	A
	CALL	O$MDCTL1	;hang up
	CALL	O$MDCTL2	;clear DAV, ESD, etc.
	PUSH	B
	MVI	B,10		;1 second for PMMI to disconnect
	CALL	J$TIMER
	POP	B
	RET
;
; Disconnect the autodial modem from the phone line
;
DSCON1	MVI	B,12		;1.2 seconds pause
	CALL	J$TIMER
	LXI	H,SM$DISC	;get into command mode
	CALL	SNDOUT
	MVI	B,12		;another 1.2 seconds pause
	CALL	J$TIMER
	MVI	A,' '		;space character
;
; If printing +++ and ATH, ATD, etc. move the three semicolons up one
; line to include a space on the CRT to look better.
;
	DB	0,0,0
;;;	CALL	TYPE		;show on local CRT only
	LXI	H,SM$DISC1	;now disconnect the modem
	CALL	SNDOUT
;
DSCON2	CALL	J$INMDM		;wait 0.1 seconds after last character
	JNC	DSCON2
	RET
;
;-----------------------------------------------------------------------
;			   Hayes Stuff
;
SMQT	LDA	SPKRFLG		;speaker flag set to quiet?
	ORA	A
	RNZ			;if yes, forget it
	MVI	A,YES
	STA	SPKRFLG		;flip the flag to quiet, now
	LXI	H,SM$SOFF
	CALL	SNDOUT
	MVI	B,6
	JMP	J$TIMER		;time for an 'OK' from modem and return
;
SMNSY	LDA	SPKRFLG		;speaker already turned on?
	ORA	A
	RZ			;if yes, forget it
	MVI	A,NO		;set for noisey, now
	STA	SPKRFLG
	LXI	H,SM$SON
	CALL	SNDOUT
	MVI	B,6
	JMP	J$TIMER
;
; Hayes-like autodial modem control codes
;
SM$DIAL	 DB	'ATDT $'	;set for touch (or pulse) dialing
SM$DISC	 DB	'+++$'		;puts the modem in local command mode
SM$DISC1 DB	'ATH',CR,'$'	;disconnects the modem
SM$SOFF	 DB	'ATM0',CR,'$'	;turns the speaker off
SM$SON	 DB	'ATM1',CR,'$'	;turns the speaker on
SPKRFLG	 DB	0		;0 = speaker has not been silenced
;
; Set the autodial modem for pulse dialing
;
SMINIT	LDA	TCHPUL		;touch or pulse dialing for autodial?
	STA	SM$DIAL+3	;store
	LXI	H,SM$DIAL
	CALL	SNDOUT
;
SMINT1	CALL	J$INMDM		;wait for modem to finish, if needed
	JNC	SMINT1
	RET
;
; Send the string pointed to by 'HL' to both the CRT and the modem
;
SNDOUT	CALL	SNDNOW		;wait until modem is ready
	MOV	A,M		;get the character
	CPI	'$'
	RZ			;if yes, finished
	MOV	A,M
	CALL	O$MDDATP	;send to modem
;
; If you want to print the +++ ATD, etc. from Hayes-type units, move the
; three semi-colons down one line.
;
;;;	CALL	TYPE		;show on CRT
	DB	0,0,0		;(PREVENT SHOWING THE +++ ATD)
	INX	H
	JMP	SNDOUT
;
; Checks for answer from Hayes-type autodial modem
;
SMRSLT	CALL	RCVRDY		;see if any incoming character yet
	JZ	SMRSL1		;if yes, exit and look at it
	CALL	STAT		;else see if want to abort ringing
	JZ	SMRSLT		;if neither, wait for one of them
	CALL	KEYIN		;get character from keyboard
	CPI	CANCEL		;CTL-X to terminate dialing?
	JNZ	SMRSLT		;if not, keep going
	MVI	B,CR
	CALL	SNDCHR		;tells the modem to hang up right away
	JMP	DLXIT		;abort dialing routine
;
SMRSL1	CALL	I$MDDATP	;get the character, then
	ANI	7FH		;remove any parity
	MOV	B,A		;store for 'GIVLF' area if needed
	CPI	'B'		;'BUSY' (for Anchor modems, etc.)
	JZ	BUSY		;if busy, flush string and retry
	CPI	'0'		;'OK' single digit result code
	JZ	SMRSL1		;ok, loop for next response
	CPI	'O'		;'OK' verbose digit result coe
	JZ	SMRSL1		;ok, loop for next response
	CPI	'1'		;'CONNECT', single digit result code
	JZ	ON$LIN		;connected, reset redial flags
	CPI	'C'		;'CONNECT', verbose result code
	JZ	ON$LIN		;connected, reset redial flags
	CPI	'3'		;'NO CARRIER', single digit result code
	JZ	NO$CAR		;no carrier, flush string and retry
	CPI	'N'		;'NO CARRIER', verbose result code
	JZ	NO$CAR		;no carrier, flush string and retry
	CPI	'4'		;'ERROR', single digit result code
	JZ	FAILED		;error, go display
	CPI	'E'		;'ERROR', verbose result code
	JZ	FAILED		;error, go display
	CPI	'5'		;'CONNECT 1200' single digit result code
	JZ	ON$120		;connected, reset redial flags
;
SMDM1	CPI	LF		;<LF> is end-of-line for verbose mode
	JZ	SMRSLT		;yes, go get the next response
	CPI	CR		;<CR> may precede digit in digit mode
	JZ	SMRSLT		;yes, go get the next response
;
	CALL	STAT		;else, see if want to abort ringing
	JZ	SMDM1A		;if not, get next character
	CALL	KEYIN		;else, get character from keyboard
	CPI	CANCEL		;CTL-X to terminate dialing?
	JNZ	SMDM1A		;if not, keep going
	MVI	B,CR
	CALL	SNDCHR		;tells the modem to hang up right away
	JMP	DLXIT		;abort dialing routine
;
SMDM1A	CALL	J$INMDM		;get next character
	JMP	SMDM1		;loop until end of response encountered
;
; The Anchor modem gives a busy result code, although still waits the
; normal time-out period to do it.
;
BUSY	CALL	J$ILPRT
	DB	'busy! ',0
	JMP	DLGN
;
; Failed call is usually caused by continuous ringing with no answer.
; The modem times out (can be set to either 30 seconds or 60 seconds.)
;
FAILED	CALL	J$ILPRT
	DB	'abort ',0
	JMP	DLGN
;
NO$CAR	CALL	J$ILPRT
	DB	'no carrier ',0
	JMP	DLGN
;
ON$LIN	CALL	J$ILPRT
	DB	'on line',0
	JMP	CONMD
;
ON$120	CALL	J$ILPRT
	DB	'on at 1200',0
	JMP	CONMD
;
;		end of special Hayes-like handling
;-----------------------------------------------------------------------
;
; Handles the special ringback numbers.  Dials, lets it ring only once,
; hangs up and then redials.
;
RNGBK	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JNZ	RNGBK2		;if yes, ringback not possible
	LDA	CMDBUF+1	;get the number of chars. in the buffer
	DCR	A		;subtract 1 to avoid the ringback char
	STA	CMDBUF+1	;store the new value
	MVI	D,DTMSK		;load tone detect mask
	MVI	C,RBLMT		;waits up to 7 seconds for a ring
	CALL	WAIT
	JNC	RNGBK0		;if no ring detected, pretend we got one
	JMP	RNGBK1		;hangup, redial, & listen for carrier
;
RNGBK0	MVI	B,25		;got a ring, wait 2.5 seconds
	CALL	TIMER
	CALL	I$BAUDRP	;is tone still present?
	ANA	D
	JZ	DLGN		;yes, must be busy, do a normal redial
;
; Hang up, redial and listen for dial tone
;
RNGBK1	CALL	HANGUP		;hang up the phone
	CALL	J$ILPRT
	DB	'ringback set, first ring ',0
	MVI	B,RBWAIT	;wait 5 seconds before redialing
	CALL	J$TIMER		;  for line to clear, etc.
	CALL	DIALBG		;disconnect, reconnect, wait for tone
	JC	DLXIT
	LDA	NUMBER		;number of characters in buffer
	CPI	1+1		;more than one character?
	JNC	DIAL14		;if more than one, hand-entered number
	JMP	DIAL12		;go redial for the table ringback number
;
RNGBK2	CALL	J$ILPRT
	DB	CR,LF,'++ No ringback for autodial modem ++',0
	POP	H		;reset the stack
	JMP	DLXIT
;
HANGUP	MVI	A,CLEAR
	CALL	O$MDCTL2
	XRA	A
	JMP	O$MDCTL1	;turn off DTR, originate/answer tones
;
; This is the auto-linking area.  Up to 32 numbers may be linked, each
; should have a comma for a separator, such as:
;
;	B>>COMMAND: CAL A,F,3,A,G,A,H
;
AUTO	STA	AUTDIR		;direct to terminal mode on answer
;
AUTO1	MVI	A,0FFH		;set the flags to -1
	STA	AUTOFL		;set the auto-linking flag
	STA	CRFLAG		;set the continuous redial flag
	MVI	B,64		;maximum number of characters to move
	LXI	H,CMDBUF+1	;start with number in the string
	LXI	D,CMDBUF+65	;move to aft part of buffer
	JMP	MOVE		;when finished return to caller
;
; Linking routine
;
AUTO2	LDA	AUTOFL		;increment the flag for each new try
	INR	A
	INR	A
	STA	AUTOFL
	MOV	C,A		;hold momentarily
	MVI	B,0
	LDA	CMDBUF+65	;see how many characters typed
	CMP	C
	JNC	AUTO3
	MVI	A,1		;reset the flag to start over
	MOV	C,A
	STA	AUTOFL
;
AUTO3	LXI	H,CMDBUF+65
	DAD	B
	JMP	DIAL6		;go to work
;
AUTDIR	DB	0		;direct to terminal mode on answer
AUTOFL	DB	0		;auto-linking flag
NUMBER	DB	0		;number of characters in CMDBUF
;
; Time-out routine.  Must be called with mask in 'D' reg. for input at
; relative port 2 and number of seconds (times 10) in 'C' reg.
;
WAIT	MVI	B,2
	CALL	TIMER		;wait for timer to go high then low
	CALL	I$BAUDRP	;PMMIADDR+2 (modem status port)
	ANA	D		;(CTS or dialtone mask)
	RZ			;active low, so return on 0
	PUSH	B		;save the registers
	PUSH	D
	CALL	STAT		;keypress?
	JZ	WAIT1		;if not, exit
	CALL	KEYIN		;yes, get char
	CPI	CANCEL		;CTL-X to intentionally abort?
	JZ	WAIT2		;yes, disconnect, jmp to menu
;
WAIT1	POP	D		;restore the registers
	POP	B
	DCR	C		;count-down
	JNZ	WAIT
	STC			;set carry to indicate mask not set
	RET
;
WAIT2	POP	D		;restore the registers
	POP	B
	JMP	DONETD		;disconnect
;
;=======================================================================
;			SPECIAL PMMI MENU
;
SPMEN	LDA	PMMIMD
	ORA	A
	RZ
	CALL	J$NXTSCR
	CALL	J$ILPRT
	DB	'        Additional Subcommands for PMMI Modems'
	DB	CR,LF,LF
	DB	'  Modem control:',CR,LF
	DB	'    A - Answer tone for send or receive',CR,LF
	DB	'    O - Originate tone for send or receive',CR,LF,LF
	DB	'  Parity option:',CR,LF
	DB	'    1 - Set and check for odd parity',CR,LF
	DB	'    0 - Set and check for even parity',CR,LF
	DB	'           Both ends must be capable of these options'
	DB	CR,LF
	DB	'           which are available only in R and S modes.'
	DB	CR,LF
	DB	'           The parity checking will be part of the'
	DB	CR,LF
	DB	'           file transfer protocol.',CR,LF,LF
	DB	'  Speed Options:',CR,LF
	DB	'        After entering your primary and secondary '
	DB	'options,',CR,LF
	DB	'        you can set the modem speed by placing a '
	DB	' "." after',CR,LF
	DB	'        the options followed by the speed e.g., '
	DB	'300, 600.',CR,LF,LF
	DB	'        EXAMPLE:  SBO.600 will set the modem for '
	DB	'600 baud',CR,LF,0
	RET			;all done
;
;=======================================================================
;
; Timer routine.  Waits 0.1 seconds for each unit in 'B' reg.
;
TIMER	PUSH	H
;
TIMER1	PUSH	B
;
TIMER2	CALL	J$INMDM		;100 ms. delay per loop
	JNC	TIMER2
	POP	B
	DCR	B
	JNZ	TIMER1
	POP	H
	RET
;
; CALCULATES DISK SPACE REMAINING IF CP/M+
;
CKCPM3	CALL	CRLF
	MVI	C,CPMVER	;check version #
	CALL	BDOS
	MOV	A,L
	CPI	30H		;version 3.0?
	RC			;use normal method if not CP/M 3.0
	POP	H		;remove 'CALL CKCPM3' from stack
	MVI	C,CURDSK
	CALL	BDOS
	MOV	E,A
	MVI	C,46		;CP/M 3.0 compute free space call
	CALL	BDOS
	MVI	C,3		;answer is 3 bytes long (24 bits)
;
FREE30	LXI	H,TBUF+2	;answer is located here
	MVI	B,3		;convert to 'K' length
	ORA	A
;
FREE31	MOV	A,M
	RAR
	MOV	M,A
	DCX	H
	DCR	B
	JNZ	FREE31		;loop for 3 bytes
	DCR	C
	JNZ	FREE30		;shift 3 times
	LHLD	TBUF		;get result in 'K'
	JMP	PRTFREE		;display result
;
;=======================================================================
;
	ORG	(($+255+50)/256*256)-50	;so 'NUMLIB' starts on even page
;
;-----------------------------------------------------------------------
;
; Long distance alternate dialing such as MCI, SPRINT, etc.  Must end
; with a '$', use as many commas (2 seconds delay, each) as needed to
; let the alternate dialing code return with a new dial tone.  Fill in
; any character (periods are fine) after the $ to keep number of columns
; to 24, i.e.,	'1234567,,,,12345,,$.....'   --   the first group is the
; MCI or SPRINT access number, the second group is the user number.  A
; small delay is usually required after the billing number also.
;
ALTDL1	DB	'xxxxxxx,,,,,,xxxxxxxx,,$'	;accessed by a < character
;
ALTDL2	DB	'xxxxxxx,,,,,,xxxxxxxx,,$'	;accessed by a > character
;
;=======================================================================
;
HEXSHO	DB	SHOWHEX		;can easily change SHOWHEX via DDT
;
SAVSIZ	DB	XFRSIZ*8	;can easily change buffer size for file
				;transfers with DDT for "NUMLIB-1" ad-
				;dress.  Normally 4k (32 records or 4k).
;
;=======================================================================
;
; Phone number library table for auto-dialing.	Each number must be as
; long as"LIBLEN" (EQU at start of program).  Some areas require extra
; characters such as:	1-313-846-7127.  Room is left for those.  Use
; a (<) for alternate dialing system #1, and a (>) for alternate dialing
; System #2.  Either would preceed the actual number, for example:
;
;	DB    'A=Alan Alda..........<123-456-7890'    ;'A'
;
; -	-     -     -	  -	-     -     -	  -	-     -     -
;
; NOTE: At least one dot (.) MUST precede the actual phone number
;
;		'----5---10---15---20---25---30--34'
NUMLIB	DB	'A=Bob Robesky.......1-209-227-2083'	;'A'
	DB	'B=Byron McKay.......1-415-965-4097'	;'B'
	DB	'C=Chuck Metz........1-408-354-5934'	;'C'
	DB	'D=Bruce Jorgens.....1-509-255-6324'	;'D'
	DB	'E=Bill Earnest......1-215-398-3937'	;'E'
	DB	'F=Chuck Forsberg....1-503-621-3193'	;'F'
	DB	'G=Ron Fowler........1-414-563-9932'	;'G'
	DB	'H=Kirk De Haan......1-408-296-5078'	;'H'
	DB	'I=Jack Kinn.........1-817-547-8890'	;'I'
	DB	'J=Walt Jung.........1-301-661-2175'	;'J'
	DB	'K=Keith Petersen....1-313-759-6569'	;'K'
	DB	'L=Larry Snyder......1-305-671-2330'	;'L'
	DB	'M=Wayne Masters.....1-408-378-7474'	;'M'
	DB	'N=Dick Mead.........1-213-799-1632'	;'N'
	DB	'O=Al Mehr...........1-408-238-9621'	;'O'
	DB	'P=Pasadena RBBS.....1-213-577-9947'	;'P'
	DB	'Q=Mark Pulver.......1-312-789-0499'	;'Q'
	DB	'R=Bruce Ratoff......1-201-272-1874'	;'R'
	DB	'S=Ken Stritzel......1-201-584-9227'	;'S'
	DB	'T=TCBBS, Dearborn...1-313-846-6127'	;'T'
	DB	'U=AnaHUG RCPM.......1-714-774-7860'	;'U'
	DB	'V=Dave Austin.......1-707-257-6502'	;'V'
	DB	'W=Bill Wood.........1-619-256-3914'	;'W'
	DB	'X=Charlie Hoffman...1-813-831-7276'	;'X'
	DB	'Y=Byron Kantor......1-619-273-4354'	;'Y'
	DB	'Z=Spare.............1-xxx-xxx-xxxx'	;'Z'
	DB	'0=Paul Bagdonovich..1-201-747-7301'	;'0'
	DB	'1=Bill Parrott......1-913-682-3328'	;'1'
	DB	'2=Alex Soya.........1-305-676-3573'	;'2'
	DB	'3=Tony Stanley......1-912-929-8728'	;'3'
	DB	'4=Tampa Bay Bandit..1-813-937-3608'	;'4'
	DB	'5=Thousand Oaks.....1-805-492-5472'	;'5'
	DB	'6=Spare.............1-xxx-xxx-xxxx'	;'6'
	DB	'7=Spare.............1-xxx-xxx-xxxx'	;'7'
	DB	'8=Spare.............1-xxx-xxx-xxxx'	;'8'
	DB	'9=Spare.............1-xxx-xxx-xxxx'	;'9'
	DB	0	;end
;		'----5---10---15---20---25---30--34'
;
;-----------------------------------------------------------------------
;
; This is the storage area for the ten function keys.  The M7FNK.COM
; program dynamically allocates the storage for the keys.  Thus, no
; function key is limited to so-and-so many characters.  Rather, the
; total number of bytes in the function key library (including flags)
; is 256.
;
INTCPT	DB	'^'		;intercept character (prefix)
;
FNCTBL	DB	0,'DIR ',CR,0
	DB	1,'DIR *.* $U0AD ',CR,0
	DB	2,'XMODEM S ',0
	DB	3,'XMODEM R ',0
	DB	4,'BYE ',CR,0
	DB	5,'RBBS ',CR,0
	DB	6,'(vacant)',0
	DB	7,'(vacant)',0
	DB	8,'(vacant)',0
	DB	9,'Nice chatting, see you again soon... ',CR,0
	DS	256-($-FNCTBL)
;
;
;********************************************************************
;	PROGRAM STARTS HERE
;********************************************************************
;
START	LXI	H,0
	DAD	SP		;add the current stack pointer to 'HL'
	SHLD	STACK
	LXI	SP,STACK	;start local stack
;
; The 'FIXCNT' calculations are done here and the values stored so the
; overhead of doing the calculation is not incurred in the RECV routine
; where it is desired to pick up a character from the modem data port as
; quickly as possible.
;
	LXI	H,624		;adjust to get 1 second time intervals
	CALL	FIXCNT
	SHLD	TIMVAL
	LXI	H,39		;should be 1/16 of above value
	CALL	FIXCNT
	SHLD	QUIKTIM
;
; Now display the program name and version number and we are under way
;
	CALL	ILPRT
	DB	CR,LF,'MODM',VERSION/100+'0',VERSION MOD 100/10+'0'
	DB	VERSION MOD 10+'0','  (type M for Menu)',CR,LF,0
	CALL	J$SYSVR		;give configuration message
	CALL	CRCGN		;generate tables for fast 'CRC' check
	CALL	INITAD		;initialize addresses
	CALL	INTRCPT		;establish the function key intercept
	CALL	PROCOPT		;process any options
	LDA	OPTION		;any options on the command line?
	CPI	' '+1
	JC	MENU		;if not, show the menu
;
; Comes here from menu once the options have been set
;
RSTRT	LXI	SP,STACK	;make sure we have a clean stack
	CALL	CKCHAR		;catch any garbage characters left over
	LDA	PMMIMD
	ORA	A
	JNZ	RSTRT1		;if yes, accept 'C' or 'D'
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JZ	RSTRT2		;exit if neither modem-type
;
RSTRT1	LDA	OPTION		;get the option
	CPI	'C'		;call (dial) function?
	JZ	J$DIAL		;yes, go to it
	LDA	PMMIMD
	ORA	A
	CNZ	STBAUD		;just the PMMI has to check each time
;
RSTRT2	CALL	MOVEFCB
	LDA	OPTION		;get main option
	CPI	'D'		;disconnect?
	JZ	DONETD		;yes, disconnect then back to the menu
	CPI	'M'		;menu asked for?
	JZ	MENU2		;go display the menu
	CPI	'R'		;want to receive a file?
	JZ	RCVFL		;exit if yes
	CPI	'S'		;want to send a file?
	JZ	SNDFL		;exit if yes
	CPI	'T'		;want terminal mode?
	JNZ	RSTRT3		;if not, exit
	XRA	A
	STA	ECHOFLG		;reset echo flag
	STA	LOCFLG		;reset local flag
	JMP	DSKSV		;exit if yes
;
RSTRT3	CPI	'E'		;want echo mode?
	JNZ	NOECHO		;if not, exit
	STA	ECHOFLG		;set the echo flag
	XRA	A
	STA	LOCFLG		;reset local flag
	JMP	DSKSV
;
NOECHO	CPI	'L'		;want local echo mode?
	JNZ	NOLOCL		;if not, exit
	STA	LOCFLG		;set the local flag
	XRA	A
	STA	ECHOFLG		;reset echo flag
	JMP	DSKSV
;
NOLOCL	CALL	NVLDMS		;say not a valid option
	JMP	MENU		;then go back to the command mode
;
INITAD	LHLD	0000H+1		;BIOS warm reboot jump vector
	LXI	D,3
	DAD	D
	SHLD	VSTAT+1		;BIOS console status jump vector
	DAD	D
	SHLD	VKEYIN+1	;BIOS console keyboard jump vector
	DAD	D
	SHLD	VTYPE+1		;BIOS console CRT jump vector
	LXI	D,33
	DAD	D
	SHLD	GOLIST+1	;BIOS list device status jump vector
	CALL	GETUSER		;get current user number
	STA	OLDUSER		;save to restore upon exit
	CALL	GTMAX		;find maximum ram for printer use
	JMP	J$INITMD	;initialize non-PMMI systems if needed
;
; Get the function key intercept character and put in appropriate places
;
INTRCPT	LDA	INTCPT		;get the function key intercept char.
	ANI	07FH		;strip off any parity
	STA	GTCMD1+1	;store in the menu area
	CPI	' '		;printing character?
	JNC	INTER2		;if yes, exit
	ADI	40H		;change to printing character
	JMP	FIXFNK		;fix-patch area of extra bytes
;
INTER1	MVI	A,'^'
	STA	MENU3		;store the "control-" character
	RET
;
INTER2	STA	MENU3+1
	RET
;
; Process any options - put 0 in appropriate place in option table if
; option is selected
;
PROCOPT	LXI	D,FCB+1
	LDAX	D
	STA	OPTION
	CPI	' '		;exit if no options
	RZ
;
OPTLP	INX	D
	LDAX	D
	CPI	' '
	JZ	ENDOPT
	LXI	H,OPTBL
	MVI	B,OPTBE-OPTBL
;
OPTCK	CMP	M
	JNZ	OPTNO
	CPI	'O'		;want originate tones?
	MOV	B,A		;store momentarily
	MVI	A,ORIGMOD
	JZ	OPTCK1
	MOV	A,B		;get the option back
	CPI	'A'		;want answer tones?
	JNZ	OPTCK2		;if not, exit
	MVI	A,ANSWMOD
;
OPTCK1	STA	UARTCT
;
OPTCK2	MVI	M,0
	JMP	OPTLP
;
OPTNO	INX	H
	DCR	B
	JNZ	OPTCK
	CALL	NVLDMS
	POP	H		;preserve stack
	JMP	MENU
;
ENDOPT	LDA	VSEEFLG
	ORA	A
	JNZ	CKOPT
	STA	QFLG		;quiet mode for watching data items
;
CKOPT	LDA	OPTION		;check on the primary option
	CPI	'D'		;going to disconnect?
	RZ
	CPI	'E'		;return if echo option
	RZ
	CPI	'M'		;return if help option
	RZ
	CPI	'L'		;return if local echo option
	RZ
	CPI	'T'		;return if terminal mode
	RZ
	MOV	B,A		;save the primary option for a moment
	LDA	PMMIMD		;PMMI modem?
	ORA	A
	JNZ	CKOPT0		;if yes, accept 'C'
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JZ	CKOPT1		;exit if neither
;
CKOPT0	MOV	A,B		;get the character back
	CPI	'C'		;going to call a number now?
	RZ
;
CKOPT1	LDA	NFILFLG		;saving memory for disk file?
	ORA	A
	JZ	CKOPT2		;if not, continue
	POP	H		;reset the stack from 'CALL PROCOPT'
	JMP	MENU0		;go show the 'FILE OPEN' message
;
CKOPT2	MOV	A,B		;get the option back
	CPI	'S'
	JZ	CKFILE
	CPI	'R'
	JNZ	BDOPT		;none of these, bad option
	LDA	BCHFLG		;see if the batch mode flag is set
	ORA	A
	RZ			;if yes, exit
;
CKFILE	LDA	FCB+17		;'S' and 'R' need a file name
	CPI	' '
	RNZ			;exit if a file name is present
;
REENT	CALL	ILPRT
	DB	'++ Enter primary option plus file name ++'
	DB	CR,LF,BELL,0
	POP	H		;reset stack from 'CALL STFCB
	JMP	MENU		;abort to command line
;
BDOPT	CALL	ILPRT
	DB	CR,LF,'++ Bad option ++',CR,LF,LF,0
;
; Check for any garbage characters on line - catch and ignore
;
CKCHAR	CALL	RCVRDY		;any characters ready to receive?
	RNZ			;if not, return
	CALL	I$MDDATP	;otherwise get the character and ignore
	JMP	CKCHAR		;check for any additional characters
;
; Revised terminal routine allowing memory save.  First checks for bad
; options, to prevent wiping out the disk with accidental memory save.
;
DSKSV	LDA	BCHFLG		;batch flag set?
	ORA	A
	JNZ	DSKSV1		;if not set, everything is normal
	MVI	A,'B'		;if set, shouldn't be, so reset it
	STA	BCHFLG
	JMP	NOTVLD		;if set, error for 'E', 'L' or 'T'
;
DSKSV1	STA	XFLG		;will use the ASCII capture buffer size
	LDA	NFILFLG		;already saving for a file?
	ORA	A
	JZ	DSKSV2		;exit if not, and open a file
	CALL	BUFMS		;tell if buffer if on or off
	JMP	TERM
;
DSKSV2	LDA	FCB+1		;first character of filename (if any)
	CPI	' '		;file specified?
	JNZ	GOODNM		;yes, good name
	XRA	A
	STA	NFILFLG		;show no file being saved
	STA	SAVEFLG		;reset the flag to zero
	JMP	TERM
;
GOODNM	CALL	ERASF
	LXI	H,FCB3
	CALL	INITFCB
	LXI	H,FCB		;move the disk name into FCB3 area
	LXI	D,FCB3
	MVI	B,12
	CALL	MOVE
	LXI	D,FCB3		;now make a file from that name
	MVI	C,MAKE
	CALL	BDOS
	LXI	D,FCB3		;now open the file from FCB3
	MVI	C,OPEN
	CALL	BDOS
	LXI	H,BUFFER	;reset pointers to start of buffer
	SHLD	HLSAV
	MVI	A,1
	STA	NFILFLG		;show now saving to memory for disk file
	CALL	BUFMS2		;show buffer is available
;
TERM	LDA	LSTTST		;allowing the printer to be used?
	ORA	A
	CNZ	GOLIST		;if yes, see if anything to print
	CALL	STAT		;keyboard have a character?
	JZ	TERML		;if not, see if any incoming
	CALL	KEYIN		;get character from keyboard
	MOV	B,A		;save for now to protect 'A' reg.
	CPI	RUB		;test for rub
	JNZ	NOTRUB		;exit if not
	LDA	CONVRUB		;convert rub to backspace?
	ORA	A
	JZ	NOTRUB		;exit if no conversion
	MVI	B,BKSP		;call it a backspace
	JMP	NTOG		;go send a backspace
;
NOTRUB	LDA	FNKFLG		;get function key active flag
	ORA	A
	JZ	NOF		;if not set yet, exit
	MOV	A,B		;get character
	CPI	'0'
	JC	NOFNK1		;ignore invalid key codes
	CPI	'9'+1
	JNC	NOFNK1
	ANI	0FH		;make 0..9
	JMP	SNDFK
;
NOF	LDA	INTCPT		;check intercept character
	CMP	B
	JNZ	NOFNK1		;skip if no function key
	STA	FNKFLG		;set the function flag
	JMP	TERML		;do not send the intercept character
;
NOFNK1	XRA	A		;reset the flag
	STA	FNKFLG
	LDA	EXACFLG
	ORA	A		;exact?
	MVI	A,0		;(cannot use 'XRA A' here)
	STA	EXACFLG		;clear for next time
	JZ	NTEXAF		;go if EXACFLG not set 'YES'
	LDA	LOCNXT
	ORA	A		;should we send on exacflg?
	JZ	NTOG		;jump if LOCONEXTCHR 'NO'
	LDA	EXTCHR		;we want to send EXTCHR in any case
	CMP	B
	JZ	NTOG		;send if EXTCHR
	JMP	LOCCHK		;otherwise do local stuff
;
NTEXAF	LDA	EXTCHR		;treat next character in special way?
	CMP	B		;check against this control character
	JNZ	NTEXA1		;yes, set exacflg for next character
	MVI	A,1
	STA	EXACFLG		;set the flag
	JMP	TERM		;do not send, get next character
;
NTEXA1	LDA	LOCNXT
	ORA	A		;should we send if not EXACFLG?
	JNZ	NTOG		;jump if loconextchr 'YES'
;
LOCCHK	CALL	XITST1		;want to exit to menu?
	LDA	NOCONCT		;want to disconnect from line?
	CMP	B
	JZ	DONETD		;if yes go disconnect
	LDA	TRANCHR		;output text file to remote?
	CMP	B
	JZ	TRNSFR
	LDA	TRANLOG
	ORA	A
	JZ	SKPLOG
	LDA	LOGCHR		;send logon?
	CMP	B
	JZ	SNDLOG
;
SKPLOG	LDA	LSTTST		;going to use the external printer?
	ORA	A
	JZ	NOLST		;if not, skip this area
	LDA	LSTCHR		;get the printer control-character
	CMP	B		;did we just ask for printer control?
	JNZ	NOLST		;if not, exit
	LDA	LISTFLG		;otherwise reset the printer toggle
	CMA
	STA	LISTFLG		;and store
	CALL	CRLF
	CALL	CRLF
	CALL	LSTMS		;tell if printer is on or off now
	CALL	CRLF
	JMP	TERML		;back to the terminal mode again
;
NOLST	LDA	BRKCHR		;PMMI break?
	CMP	B
	JZ	BREAK
	LDA	PMMIMD		;using a PMMI board?
	ORA	A
	JZ	NOLST1		;if not, skip the next few lines
	LDA	CHGBAUD		;PMMI change baud?
	CMP	B
	PUSH	PSW
	PUSH	H
	CZ	J$NWBAU
	POP	H
	POP	PSW
	JZ	TERML
;
NOLST1	LDA	UNSAVCH		;close input buffer?
	CMP	B
	JZ	NOLST2		;if yes, disable copy
	LDA	SAVECHR		;open input buffer?
	CMP	B
	JNZ	NTOG
	LDA	NFILFLG		;do not allow save if flag is set
	ORA	A
	JZ	TERML
	JMP	NOLST3
;
NOLST2	XRA	A		;stop copy into file
;
NOLST3	STA	SAVEFLG
	CALL	BUFMS
	JMP	TERM		;get next character
;
;***********************************************************************
;			 SEND A CP/M FILE
;***********************************************************************
;
SNDFL	XRA	A		;set to checksum initially on send
	STA	CRCFLAG		;  initially on send
	CALL	CKCHAR		;catch any garbage characters
;
SNDFL1	LDA	BCHFLG		;check if multiple file
	ORA	A		;  mode is set.
	JNZ	SNDC1
	CALL	ILPRT
	DB	'Ready to send in batch mode',CR,LF,0
;
SNDFL2	CALL	J$PRITY
	MVI	A,YES		;indicate send for batch mode
	STA	SNDFLG
	LDA	FSTFLG		;if first time through
	ORA	A		;  scan the command line
	CZ	TNMBUF		;  for multiple names
	CALL	SNDFN		;sends file name to receive
	PUSH	PSW
	CALL	CRLF
	CALL	SHOFIL
	MVI	A,' '
	CALL	TYPE
	POP	PSW
	JNC	SNDC2		;carry set means no more files
	MVI	A,'B'		;stop batch
	STA	BCHFLG		;mode option
	MVI	A,EOT		;final transfer end
	CALL	SND
	JMP	DONE
;
SNDC1	LDA	FCB+1
	CPI	' '
	JZ	BLKFILE
;
SNDC2	CALL	CNREC		;get number of records
	CALL	OPENFIL
	MVI	E,120		;wait 2 minutes maximum
	CALL	WAITNAK
;
SNDLP	CALL	CKABORT		;want to terminate while sending file?
	CALL	RDRECD
	JC	SNDEOF
	CALL	INCRRNO
	MVI	A,1
	STA	ERRCT
;
SNDRPT	CALL	CKABORT		;want to terminate while sending file?
	CALL	SNDHDR
	CALL	SNDREC
	LDA	CRCFLAG
	ORA	A
	CZ	SNDCKS
	CNZ	SNDCRC
	CALL	GTACK
	JC	SNDRPT
	JMP	SNDLP
;
SNDEOF	MVI	A,EOT
	CALL	SND
	CALL	GTACK
	JC	SNDEOF
	JMP	DONE
;
;***********************************************************************
;		       RECEIVE A CP/M FILE
;***********************************************************************
;
RCVFL	LDA	CRCDFLT		;get mode requested by operator
	STA	CRCFLAG		;store it
;
RCVFL1	CALL	J$PRITY
	LDA	BCHFLG		;check if multiple file mode
	ORA	A
	JNZ	RCVC1		;if not, exit
	MVI	A,NO		;flag where to return
	STA	SNDFLG		;  for next file transfer
	CALL	GETFN		;get the file name
	JNC	RCVC2		;carry set means no more files
	MVI	A,'B'		;stop batch
	STA	BCHFLG		;mode option
	JMP	DONE
;
RCVC1	LDA	FCB+1		;make sure file is named
	CPI	' '
	JZ	BLKFILE
	JMP	RCVC3
;
RCVC2	CALL	SHOFIL		;show the file name
	MVI	A,' '
	CALL	TYPE
	CALL	SNDPRG		;get progress and wait for quiet line
	CALL	CKCPM2
	CALL	CRLF
	CALL	CKBAKUP
;
RCVC3	CALL	ERASF
	CALL	MAKEFIL
	CALL	WAITQ1
	LDA	BCHFLG		;do not print message if in batch mode
	ORA	A
	JZ	RCVFST
	CALL	ILPRTQ
	DB	'File open, ready to receive',CR,LF,0
;
RCVFST	LDA	CRCFLAG
	ORA	A
	JZ	RCVNKM		;if in 'CRC' mode
	CALL	ILPRTQ		;then say so
	DB	'CRC in effect',CR,LF,0
	MVI	A,CRC
	JMP	RCVLP0
;
RCVNKM	CALL	ILPRTQ		;else say 'CHECKSUM' mode
	DB	'Checksum in effect',CR,LF,0
	MVI	A,NAK
;
RCVLP0	PUSH	PSW
	CALL	ILPRT
	DB	'Waiting.....',0
;
NOPRG	POP	PSW
	CALL	SND
;
RCVLP	CALL	RCVRECD
	JC	RCVEOT
	CALL	REPORT		;show record received if not in quiet
	CALL	WRRECD
	CALL	INCRRNO
	CALL	SNDACK
	JMP	RCVLP
;
RCVEOT	CALL	WRBLOCK
	CALL	SNDACK
	CALL	CLOSFIL
	JMP	DONE
;
SNDACK	MVI	A,ACK
	CALL	SND
	RET
;
;=================== FILE TRANSFER IN T-MODE ===========================
;
; File transfer routine - called with CTL-T from terminal mode.  Trans-
; fer may be cancelled while sending, by using CTL-X.
;
TRNSFR	LXI	H,FCB4
	CALL	INITFCB		;initializes FCBs pointed
	LXI	H,FCB+16	;  to by 'HL' register
	CALL	INITFCB
;
; Get name of file to send in "T" (terminal) mode
;
GET	CALL	ILPRT
	DB	CR,LF,'File name to send? (CR to abort): ',0
	LXI	D,CMDBUF
	CALL	INBUF
	LDA	CMDBUF+2	;was file entered?
	CPI	' '
	JZ	RETRN		;if not probably wanted to quit
	LXI	D,CMDBUF
	LXI	H,FCB4
	CALL	CMDLINE
	LXI	D,FCB4
	MVI	C,OPEN
	CALL	BDOS
	CPI	0FFH		;return with 0FFH means 'NO SUCH FILE'
	JZ	TRANSL
	LDA	XONWAIT		;waiting for X-on to send next line?
	ORA	A
	JNZ	DLYSAV		;if yes, skip additional delays
;
; Choice of normal speed or delays between characters / lines
;
	CALL	ILPRT
	DB	'Want to include time delays? (Y/N): ',0
	CALL	KBDCHR
	CPI	'N'		;if 'N' send normal speed
	JZ	DLYSAV
	XRA	A		;otherwise use character/line delays
;
DLYSAV	STA	DLYFLG		;store the decision
	CALL	CRLF
	LXI	D,CMDBUF+2	;make sure cmdbuf has been selected
	MVI	C,STDMA
	CALL	BDOS
;
; Get 128-byte record
;
READM	LXI	D,FCB4
	MVI	C,READ
	CALL	BDOS
	ORA	A		;check for a good read
	JZ	READM1
	DCR	A		;check for end of file to send
	JZ	RETRNS
	CALL	ERXIT		;neither of those, was a read error
	DB	'++ DISK READ ERROR ++','$'
;
; Successful read, so send the record
;
READM1	CALL	SND80C		;send one 128-char record
	CPI	EOFCHAR		;end of file - omit if object
	JZ	RETRNS		;  code is to be sent.
	CPI	CANCEL		;cancellation?
	JNZ	READM
;
RETRN	CALL	ILPRT
	DB	CR,LF,LF,'(in Terminal-mode now)',CR,LF,LF,0
	CALL	SNDNOW		;insures last character is finished
	CALL	CKCHAR		;catch any echo character on line
	JMP	TERM		;finished, back to t-mode
;
RETRNS	CALL	ILPRT
	DB	CR,LF,'[Transfer completed]',0
	JMP	RETRN
;
TRANSL	CALL	ILPRT
	DB	CR,LF,BELL,'++ FILE NAME ERROR ++ ',CR,LF,0
	JMP	GET
;
; Send one 128-byes record
;
SND80C	MVI	B,128		;will send a maximum of 128 character
	LXI	H,CMDBUF+2	;they are in the cmdbuf area
;
SNDCH1	PUSH	D
	CALL	SPEED		;0-90 ms. delay between characters
	POP	D
	MOV	A,M
	CPI	EOFCHAR
	RZ
	CALL	MDOUT		;send the character to modem
	CALL	STAT		;test to see if
	ORA	A		;cancellation requested
	JZ	SKIP1
	CALL	KEYIN
	CPI	CANCEL
	RZ
;
SKIP1	INX	H
	DCR	B
	JNZ	SNDCH1
	RET
;
; Send the character to the output
;
MDOUT	PUSH	PSW		;save the character so can use 'A' reg.
	CPI	LF
	JNZ	MDOUTL
	LDA	ADDLFD		;going to send the line feed to modem?
	ORA	A
	JNZ	MDOUTL		;if yes, exit
	POP	PSW		;get the char. back (a line feed)
	CALL	TYPE		;show on CRT, do not send to modem
	RET
;
MDOUTL	LDA	XOFFTST		;waiting for X-off, X-on ?
	ORA	A
	CNZ	TXOFF		;if yes, go check
	CALL	SNDRDY		;wait until modem is ready to send
	JNZ	MDOUTL
	POP	PSW		;get the character back
	CALL	TYPE		;send character to CRT
	CALL	O$MDDATP	;send character to modem
	CPI	CR		;was it an end of line?
	RNZ			;if yes, see if any delay is needed
;
; Delay to allow slow BBS systems (most use BASIC) to enter the line.
; Choice of 0-9 for about 100 ms. each, maximum of 900 ms.
;
MDOUTN	LDA	XONWAIT		;wait for X-on after CR?
	ORA	A
	JNZ	WATXON		;if yes, handle separately
	MVI	D,10
;
MDOUTT	PUSH	D
	CALL	SPEED1		;10 ms delay
	POP	D
	DCR	D
	JNZ	MDOUTT		;10 loops for 100 ms.
	RET
;
; Add from 0 to 90 ms. delay between characters for slow (most use
; BASIC) bulletin board systems.  Also used to add 0-900 ms. delay
; between lines.
;
SPEED	LDA	BYTDLY		;get delay between characters (0-9)
	JMP	SPEED1+3	;1=10 ms, 5=50 ms, 9=90 ms, etc.
;
SPEED1	LDA	CRDLY		;get delay after crlf (0-9)
	ORA	A		;100 ms, 5=500 ms, 9=900 ms, etc.
	RZ			;if no delay needed, return
	MOV	C,A		;store number requested in c-reg.
	LDA	DLYFLG		;want any delays this file?
	ORA	A
	RNZ			;if not, skip this section
;
SPEED2	CALL	SPEED3		;outer loop
	DCR	C
	JNZ	SPEED2
	RET			;done whenever the c-reg. is zero
;
SPEED3	PUSH	H		;save current 'HL' value
	LXI	H,20
	LDA	XOFFTST
	ORA	A
	JZ	SPEED4
	LXI	H,20		;adjust for 'X-OFF' testing
	LDA	ECHOFLG
	ORA	A
	JZ	SPEED4
	LDA	LOCFLG
	ORA	A
	JZ	SPEED4
	LXI	H,25		;adjust for remote echo
;
SPEED4	CALL	FIXCNT		;multiply delay by clock speed
	XCHG			;transfer delay to 'DE'
	POP	H		;restore current 'HL' from"speed3"
;
SPEED5	DCX	D		;inner loop
	LDA	XOFFTST
	ORA	A
	CNZ	TXOFF
	MOV	A,E
	ORA	D
	JNZ	SPEED5
	RET
;
TXOFF	CALL	RCVRDY
	RNZ
	CALL	I$MDDATP
	ANI	7FH
	CPI	XOFF
	CZ	WATXON
	RET
;
WATXON	CALL	RCVRDY		;have a character? (like x-on)
	JNZ	WATXN1		;if no character see if want to abort
	CALL	I$MDDATP
	ANI	7FH		;strip off any parity
	CPI	XON		;see if character was X-on
	RZ			;if yes, keep going
;
WATXN1	CALL	STAT		;test to see if requesting cancellation
	JZ	WATXON
	CALL	KEYIN		;can abort if the x-on never comes
	CPI	CANCEL		;CTL-X to abort?
	JNZ	WATXON		;if not, keep going
	RZ
;
;***********************************************************************
;			   SUBROUTINES
;***********************************************************************
;
; Returns with the zero flag set if retry requested.  If using multi-
; file (batch) mode, then no questions asked, just quit.
;
CKQIT	LDA	BCHFLG		;using batch mode now?
	ORA	A
	JZ	ABORT		;quit if using batch mode
;
CKQIT1	MVI	A,1
	STA	ERRCT
	CALL	ILPRT
	DB	CR,LF,'Multiple errors encountered.',CR,LF
	DB	'Type Q to quit, R to retry:  ',BELL,0
	CALL	KEYIN
	PUSH	PSW
	CALL	CRLF
	POP	PSW
	CALL	UCASE		;instead of 'ANI 5FH'
	CPI	'R'
	JZ	RCVRECD		;if 'R' keep trying
	CPI	'Q'
	JNZ	CKQIT1
	JMP	ABORT
;
; Show the file name as stored in the FCB but in CP/M format
;
SHOFIL	LDA	QFLG		;can type it if no 'QFLG'
	ORA	A
	RZ
	LXI	H,FCB+1
;
SHONM	XRA	A
	STA	FTYCNT
	MVI	C,11
;
PRNAM	CALL	FTYTST
	INX	H
	DCR	C
	JNZ	PRNAM
	RET
;
; Give report of received records as they occur
;
REPORT	LDA	QFLG
	ORA	A
	RZ
	LHLD	RECNO		;get record number
	INX	H
	CALL	ILPRT
	DB	CR,'Received # ',0
	CALL	DECOUT		;print record number in decimal
	CALL	ILPRT
	DB	' ',0
;
	LDA	HEXSHO
	ORA	A
	RZ
	CALL	ILPRT
	DB	'(', 0
	CALL	DHXOUT		;16 bit hex conversion and output
	CALL	ILPRT
	DB	'H) ',0
	RET
;
FTYTST	LDA	FTYCNT
	INR	A
	STA	FTYCNT
	CPI	9		;are we at the file type?
	JZ	SPCTST		;go if so
;
ENDSPT	MOV	A,M
	CPI	' '		;test for space
	CNZ	TYPE		;type if not
	RET
;
SPCTST	MOV	A,M
	CPI	' '		;test for space in 1st file type byte
	RZ			;do not output period if space
	MVI	A,'.'
	CALL	TYPE
	JMP	ENDSPT		;output 1st file type byte
;
; Get sender's progress report if it is present and wait for line to get
; quiet
;
SNDPRG	MVI	B,5		;wait up to 5 seconds
	CALL	RECV
	CALL	TYPE		;show the progress report from sender
	JNC	SNDPRG
	RET
;
SNDFN	CALL	ILPRTQ
	DB	'Awaiting name NAK  ',CR,LF,0
	CALL	GTACK
	CC	SNDACK
	LXI	H,FILECT
	DCR	M
	JM	NOMRN
	LHLD	NBSAVE		;get file name in FCB
	LXI	D,FCB
	MVI	B,12
	CALL	MOVE
	SHLD	NBSAVE
	CALL	SNDNM		;send it
	ORA	A		;clear carry
	RET
;
NOMRN	MVI	A,EOT
	CALL	SND
	STC
	RET
;
; Wait for line to get quiet and gobble characters
;
WAITQ1	MVI	B,1
	CALL	RECV
	JNC	WAITQ1
	RET
;
SNDNM	PUSH	H
;
SNDNM1	MVI	D,11		;count characters in name
	MVI	C,0		;initialize checksum
	LXI	H,FCB+1		;address name
;
NAMLPS	MOV	A,M		;send name
	ANI	7FH		;strip high order bit so CP/M 2.x
	CALL	SND		;  will not send R/O file designation
;
ACKLP	PUSH	B		;save checksum
	MVI	B,5		;wait for receiver to acknowledge
	CALL	RECV		;  getting the letter
	POP	B
	JC	SCKSER
	CPI	ACK
	JNZ	ACKLP
	INX	H		;next character
	DCR	D
	JNZ	NAMLPS
	MVI	A,EOFCHAR	;tell receiver the end of name
	CALL	SND
	MOV	D,C		;save checksum
;
CKSMLP	MVI	B,5		;wait up to 5 seconds
	CALL	RECV		;get checksum
	CMP	D
	JNZ	SCKSER		;exit if bad name
	MVI	A,OKNMCH	;good name-tell receiver
	CALL	SND
	POP	H
	RET
;
SCKSER	MVI	A,BDNMCH	;bad name-tell receiver
	CALL	SND
	CALL	ILPRT
	DB	CR,LF,'++ ERROR sending name  ++',CR,LF,0
	MVI	E,120		;do handshaking over (2 minutes maximum)
	CALL	WAITNLP		;don't print "WAITING READY SIGNAL" msg.
	CALL	SNDACK
	JMP	SNDNM1
;
; This patch fixes a problem with the display of the function key
; group on the menu.  It uses some of the extra bytes available in
; this area from the CKSMLP fix.
;
FIXFNK	STA	MENU3+1		;store the character in the menu display
	CPI	'['		;'ESC' character, printed
	JNC	INTER2		;if 'ESC' or more, exit
	JMP	INTER1		;otherwise include a '^'
;
; Patch to close FCB3 instead of FCB when in disk-capture mode.
;
WRERRSP	CALL	WRFIL2		;close FCB3 file
	JMP	WRERR1		;go write 'DISK FULL' message and quit
;
EXTRA	DB	'123456789 '	;10 extras from CKSMLP (there were 27)
;
GETFN	LXI	H,FCB
	CALL	INITFCB+2	;does not initialize drive
	CALL	ILPRTQ
	DB	'Awaiting file name',CR,LF,0
	CALL	HSNAK
	CALL	GETNM		;get the name
	CPI	EOT		;if EOT, then no more files
	JZ	NOMRNG
	ORA	A		;clear carry
	RET
;
NOMRNG	STC
	RET
;
GETNM	PUSH	H
;
GETNM1	MVI	A,0FFH
	STA	FLTRFLG
	MVI	C,0		;initialize checksum
	LXI	H,FCB+1
;
NAMELPG	MVI	B,5
	CALL	RECV		;get the character
	PUSH	B
	PUSH	PSW
	MVI	A,0FFH
	STA	TIMFLG
	MVI	B,1
	CALL	RECV
	XRA	A
	STA	TIMFLG
	POP	PSW
	POP	B
	JNC	GETNM3
	CALL	ILPRTQ
	DB	'Time out receiving filename',CR,LF,0
	JMP	GCKSER
;
GETNM3	CPI	EOT		;if EOT, then no more files
	JZ	GNRET
	CPI	EOFCHAR		;got end of name
	JZ	ENDNAM
	PUSH	PSW
	PUSH	B
	CALL	SNDACK
	POP	B
	POP	PSW
	MOV	M,A		;put name in FCB
	INX	H		;get next character
	MOV	A,L		;do not let noise cause overflow
	CPI	7FH		;  into the program area
	JZ	GCKSER
	JMP	NAMELPG
;
ENDNAM	XRA	A
	STA	FLTRFLG
	MOV	A,C		;send checksum
	MOV	D,C
	CALL	SND
;
NMLP1	MVI	B,5		;wait up to 5 seconds to see if
	CALL	RECV		;  the checksum is good
	CPI	OKNMCH		;yes if 'OKNMCH' sent
	JZ	GNRET
	CMP	D
	JZ	NMLP1		;in case it is echo of send
	CPI	CR
	JZ	NMLP1
	CPI	LF
	JZ	NMLP1
;
GCKSER	LXI	H,FCB		;clear FCB (except drive) since it
	CALL	INITFCB+2	;  might be damaged
	CALL	ILPRTQ
	DB	CR,LF,'**  Checksum error  **',CR,LF,0
	XRA	A
	STA	FLTRFLG
	CALL	HSNAK		;do handshaking over
	JMP	GETNM1
;
GNRET	PUSH	PSW
	XRA	A
	STA	FLTRFLG
	POP	PSW
	POP	H
	RET
;
HSNAK	MVI	E,180		;3 minute wait for file name
	XRA	A
	STA	FLTRFLG
;
HSNAK1	CALL	CKABORT		;want to abort?
	MVI	A,NAK		;send 'NAK' until receiving 'ACK'
	CALL	SND
	MVI	B,1		;wait up to 1 second for a character
	CALL	RECV
	CPI	ACK		;'ACK' is what we were waiting for
	RZ
	DCR	E
	JNZ	HSNAK1
	JMP	ABORT		;back to command line
;
TNMBUF	MVI	A,1		;call from 'SNDFL' only once
	STA	FSTFLG
	XRA	A
	STA	FILECT
	CALL	SCAN
	LXI	H,NAMEBUF
	SHLD	NBSAVE		;save address of 1st name
;
TNLP1	CALL	TRTOBUF
	LXI	H,FCB
	LXI	D,FCBBUF
	CALL	CMDLINE		;parse name to CP/M format
;
TNLP2	CALL	MFNAM		;search for names (wildcard format)
	JC	NEXTNM
	LDA	FCB+10		;if CP/M 2.x SYS file
	ANI	80H		;  do not send
	JNZ	TNLP2
	LHLD	NBSAVE		;get name
	LXI	D,FCB		;move it to FCB
	XCHG
	MVI	B,12
	CALL	MOVE
	XCHG
	SHLD	NBSAVE		;address of next name
	LXI	H,FILECT	;count files found
	INR	M
	JMP	TNLP2
;
NEXTNM	LXI	H,NAMECT	;count names found
	DCR	M
	JNZ	TNLP1
	LXI	H,NAMEBUF	;save start of buffer
	SHLD	NBSAVE
	LDA	FILECT
	CPI	64+1		;no more than 64 transfers
	RC
	MVI	A,64		;only transfer first 64
	STA	FILECT
	RET
;
; Tells when buffer is opened/closed for memory save to write on disk
;
BUFMS	CALL	ILPRT
	DB	CR,LF,'** Memory buffer ',0
	LDA	SAVEFLG
	ORA	A
	JZ	BUFMS1
	CALL	ILPRT
	DB	'open **',CR,LF,LF,';',0
	RET
;
BUFMS1	CALL	ILPRT
	DB	'closed **',CR,LF,LF,0
	RET
;
BUFMS2	CALL	ILPRT
	DB	CR,LF,'** Memory buffer available **',CR,LF,0
	RET
;
; Clear the screen and return to the menu command
;
XITMNU	CALL	CRLF
	CALL	CLREOS		;clear line to clean up any mess
	JMP	MENU0
;
; Checks to see if the modem has a character ready
;
RCVRDY	CALL	I$MDCTL1
	CALL	A$MDRCVB
	JMP	C$MDRCVR
;
; Checks to see if the modem is ready to receive a character
;
SNDRDY	CALL	I$MDCTL1
	CALL	A$MDSNDB
	JMP	C$MDSNDR
;
SNDNOW	CALL	XITST		;see if want to quit now
	CALL	SNDRDY		;ready to send a character?
	JNZ	SNDNOW		;if not ready wait some more
	RET			;exit if ready
;
; Send the log-on message when requested
;
SNDLOG	LHLD	LOGONPTR	;'HL' points to start of logon message
	CALL	LOGLP
	JMP	TERML
;
LOGLP	CALL	SNDNOW		;wait until modem is ready
	MOV	A,M		;get logon byte
	ORA	A		;last character in string is '0'
	RZ			;return if finished
	CALL	O$MDDATP	;otherwise send the character
	CALL	LOGLP1		;check for echo character and display it
	INX	H		;next location in message
	JMP	LOGLP		;get next character
;
LOGLP1	CALL	J$INMDM		;get the echo character
	CC	J$INMDM		;if none, try once more
	RC			;if no character do not try to print
	ANI	7FH		;strip off any parity
	JMP	TYPE		;display the character, then return
;
; Check for exit character
;
XITST	CALL	STAT		;anything on keyboard?
	RZ
	CALL	KEYIN		;get it, then
	MOV	B,A		;save to protect the 'A' register
;
XITST1	MVI	A,EXITCHR	;exit character
	CMP	B		;asking to exit to menu?
	RNZ			;if not, back to work
	POP	H		;clear the stack from 'CALL'
	JMP	XITMNU		;exit to the menu
;
LSTMS	CALL	ILPRT
	DB	'Printer buffer is ',0
	LDA	LISTFLG		;see if printer should be on or off
	ORA	A
	JZ	LSTMS1
	CALL	ILPRT
	DB	'ON',CR,LF,0
	RET
;
LSTMS1	CALL	ILPRT
	DB	'OFF',CR,LF,0
	RET
;
; Special function key handler.  This routine is entered with the
; function key number (0..9) in A.  The corresponding function key is
; then transmitted.
;
SNDFK	PUSH	H		;save register
	LXI	H,FNCTBL	;point to function key codes
;
SFK1	CMP	M		;this the one?
	INX	H		;point to next byte
	JNZ	SFK1		;loop until found
	CALL	LOGLP		;send the char
	POP	H
	XRA	A		;reset the function flag
	STA	FNKFLG
	JMP	TERML
;
; Send keyboard character to modem, also to console if "E" or "L".  If
; "E" include a LF after a CR, if either, include a LF if toggle is set.
;
NTOG	CALL	SNDCHR		;send char. in 'B' to modem
	LDA	LOCFLG		;using the local mode?
	ORA	A
	JNZ	LTYPE		;if yes, show the character
	LDA	ECHOFLG		;in echo mode?
	ORA	A
	JZ	TERML		;if not, see if it was a 'CR'
;
LTYPE	MOV	A,B		;get the character back
	CALL	TYPE		;show on the local CRT
	CALL	CKSAV		;to store local if buffer open
	CALL	CHKPRNT		;put on printer if running
;
CHKCR	MVI	A,CR
	CMP	B
	JNZ	TERML		;if not CR, all done
	LDA	ECHOFLG		;in echo mode now?
	ORA	A
	JNZ	CHKLF		;if yes add a line feed
	LDA	ADDLFD		;going to add a line feed in 'L' mode?
	ORA	A
	JZ	TERM		;if not, exit
;
CHKLF	MVI	B,LF
	JMP	NTOG		;send locally and to remote
;
TERML	CALL	RCVRDY		;character on the receive-ready line?
	JNZ	TERM		;if not, exit
	CALL	I$MDDATP	;get the character
	ANI	7FH		;strip parity
	JZ	TERM		;do not bother with nulls
	CPI	RUB
	JZ	TERM		;do not bother with rubouts for fill
	MOV	B,A		;store temporarily
	LDA	IGNRCTL		;ignoring all but necessary CTL-chars?
	ORA	A
	JZ	GIVLF		;if zero, display them all
	MOV	A,B
	CPI	' '
	JNC	GIVLF		;display all printing characters
	CPI	'G'-40H		;^G for bell
	JC	TERM		;ignore CTL-characters less than ^G
	CPI	CR+1
	JNC	TERM		;ignore CTL-characters more than ^M
;
GIVLF	MOV	A,B		;get the character back
	CALL	TYPE		;show it on the CRT
	CALL	CKSAV		;saving for disk file?
	CALL	CHKPRNT		;printer running?
	LDA	ECHOFLG		;going to echo the character?
	ORA	A
	JZ	NOECH		;if not, do not resend
;
GIVLF1	CALL	SNDCHR		;send character in 'B' to modem
;
NOECH	MVI	A,CR
	CMP	B		;was it a 'CR' just now?
	JNZ	TERM		;if not, all done so exit
	LDA	ECHOFLG		;in the echo mode?
	ORA	A
	JZ	TERM
	CALL	SNDNOW		;modem ready for a character?
	MVI	B,LF
	JMP	GIVLF		;send LF
;
; See if putting character into memory for a disk file
;
CKSAV	LDA	SAVEFLG		;saving to disk?
	ORA	A
	RZ			;if not, exit
	LHLD	HLSAV		;get last address
	MOV	M,B		;store this character
	INX	H		;increment for next character
	SHLD	HLSAV		;remember that location
	MVI	A,LF
	CMP	B		;this character a line feed?
	JNZ	CKSAV1		;  type ";" after each line feed
	MVI	A,CR		;insure at left column with a LF
	CALL	TYPE
	CALL	TYPSEM		;show a ';' on CRT
;
CKSAV1	MOV	A,H
	LXI	H,BUFTOP	;get the address at top of buffer
	CMP	H
	CZ	DCTLS		;if different, buffer is not full
	RET
;
; Memory buffer is full, send a X-OFF (CTL-S, DC3), save any extra in-
; coming characters, then dump to disk, reset buffer to include those
; characters.
;
DCTLS	CALL	SNDNOW		;modem ready for a character?
	MVI	A,XOFF		;send a CTL-S to stop remote computer
	CALL	O$MDDATP
	CALL	CHKPRNT		;insure character gets to the printer
	LXI	H,BUFFDSK	;address of auxiliary buffer
	CALL	GTDSK		;put any extra chars. into aux. buffer
	PUSH	D		;save the number of aux. chars.
	MVI	A,1		;show we put something in the buffer
	STA	WRFLG		;  to protect erasing an empty file
	LHLD	HLSAV		;find current end of buffer
	CALL	WRDSK1		;write the records
	POP	D		;get auxiliary character count back
	LXI	H,BUFFER	;start again at bottom of buffer
	XRA	A		;set 'A' to zero
	CMP	D		;see if any count in 'D'
	JZ	DCTLQ		;if nothing, exit and continue
	LXI	B,BUFFDSK	;address of auxiliary buffer
;
; Move the characters from the auxiliary buffer to the main buffer and
; display
;
DCTLS1	LDAX	B		;get the character there
	MOV	M,A		;store in main buffer
	CALL	TYPE		;show on CRT
	PUSH	H
	PUSH	D
	PUSH	B
	PUSH	PSW
	MOV	B,A
	CALL	CHKPRNT
	POP	PSW		;get the character again
	POP	B
	POP	D
	POP	H
	CPI	LF
	CZ	TYPSEM
	INX	H		;next buffer position
	INX	B		;next auxiliary buffer position
	DCR	D		;one less to go
	JNZ	DCTLS1		;if not zero, keep going
	MVI	B,0		;falls through to 'CHKPRNT' next
;
DCTLQ	SHLD	HLSAV		;next position to store in buffer
	CALL	SNDNOW
	MVI	A,XON		;allow remote input to continue
	JMP	O$MDDATP
;
; Gets any incoming characters after sending an XOFF and stores at HL.
; Returns with number of characters stored in D-reg.
;
GTDSK	MVI	D,0		;character count in buffer
	MVI	E,128		;maximum for buffer length
;
GTDSK1	CALL	J$INMDM		;get any character
	RC			;if none, finished
	CPI	' '
	JNC	GTDSK2		;if greater, handle normally
	CPI	CR+1		;ignore CTL-characters > CR
	JNC	GTDSK1
;
GTDSK2	MOV	M,A		;store
	INX	H		;next buffer location to use
	INR	D		;increment character count
	DCR	E		;room for one less
	JNZ	GTDSK1		;if room in buffer, keep going
	RET			;if buffer is filled, exit
;
; See if printing the character, if yes, put into buffer
;
CHKPRNT	LDA	LISTFLG		;printer in use?
	ORA	A
	RZ			;return if not
	LHLD	HLSAV1		;get input address
	MOV	M,B		;save this character there
	INX	H		;increment the buffer location
	SHLD	HLSAV1		;store for next character
	LDA	MAXRAM		;see if at top of buffer yet
	CMP	H
	CZ	PCTLS		;if different, buffer is not full
	RET
;
; Memory buffer is full, send a X-OFF (CTL-S, DC3), save any extra in-
; coming characters, then dump to disk, reset buffer to include those
; characters.
;
PCTLS	CALL	SNDNOW		;wait until modem is ready
	MVI	A,XOFF		;send a CTL-S to stop remote computer
	CALL	O$MDDATP
	LXI	H,BUFFPNT	;address of auxiliary buffer
	CALL	GTDSK		;put any extra chars. into aux. buffer
	MOV	A,D		;get the aux. buffer character count
	STA	DSTORE		;save for later
	RET
;
; Output has now caught up to the input and both are at top of buffer
;
PCTLS1	LDA	DSTORE		;get the aux. buffer character count
	MOV	D,A		;put into 'D' register
	XRA	A		;set 'A' to zero
	CMP	D		;see if any count in 'D'
	LXI	H,PBUFF		;address at start of printer buffer
	JZ	PCTLQ		;if nothing, exit and continue
	LXI	B,BUFFPNT	;address of auxiliary buffer
;
; Move the characters from the aux. buffer to the main buffer and display
;
PCTLS2	LDAX	B		;get the character there
	MOV	M,A		;store in main buffer
	CALL	TYPE		;show on CRT
	PUSH	H
	PUSH	D
	PUSH	B
	PUSH	PSW
	MOV	B,A
	CALL	CKSAV
	POP	PSW
	POP	B
	POP	D
	POP	H
	CPI	LF
	CZ	TYPSEM
	INX	H		;next buffer position
	INX	B		;next auxiliary buffer position
	DCR	D		;one less to go
	JNZ	PCTLS2		;if not zero, keep going
;
PCTLQ	SHLD	HLSAV1		;next position to store in buffer
	LXI	H,PBUFF		;start of buffer location
	SHLD	HLSAV2		;output to start of buffer
	CALL	SNDNOW		;wait until modem is ready
	MVI	A,XON		;send start character
	JMP	O$MDDATP	;  to remote computer, back to work
;
; List the character on the printer if it is ready, then see if at the
; top of the buffer.
;
GOLIST	CALL	$-$		;get the printer status - filled in
	ORA	A		;by 'INITAD' routine
	RZ			;return if printer not ready
;
; Compare input and output pointers.  If at same address, nothing to
; print.
;
	CALL	CMP$I$O		;if the same, nothing to print
	RZ
;
; If not the same, print the character
;
GOLIST1	PUSH	H		;save current buffer address
	MOV	E,M		;get the character to display
	MVI	C,LIST		;list routine
	CALL	BDOS
	POP	H		;restore current buffer address
	INX	H		;increment pointer for next position
	SHLD	HLSAV2		;store for next time through here
;
; See if the output is at the end of the buffer now.  If yes, go put
; the auxiliary characters into the start of the buffer.
;
	LDA	MAXRAM		;check for end of buffer area
	CMP	H
	JZ	PCTLS1		;if at end, restore auxiliary buffer
;
; See if the output has caught up with the input - if so, reset the
; pointers to the start of the buffer
;
	CALL	CMP$I$O
	RNZ			;if not, back to work
	LXI	H,PBUFF		;if output caught input, reset both
	SHLD	HLSAV1		;  to bottom of buffer to start over
	SHLD	HLSAV2
	RET
;
; Compare the input and output pointers to see if the same address
;
CMP$I$O	LHLD	HLSAV1		;get input pointer address
	XCHG			;put in 'DE'
	LHLD	HLSAV2		;get output pointer address
	MOV	A,H
	CMP	D
	RNZ			;return if different
	MOV	A,L
	CMP	E
	RET
;
GTMAX	LDA	SAVCCP		;going to save 'CCP'?
	ORA	A
	LDA	BDOS+2		;'MSP' of 'BDOS' address
	JZ	GTMAX1
	SBI	8		;'CCP' is 2k or 8 pages
;
GTMAX1	STA	MAXRAM		;save
	RET
;
; This subroutine will loop until the modem receives a character or 100
; milliseconds.  It returns with a character in 'A' reg. but if no char-
; acter was recieved it returns after a timeout with carry set.
;
INMDM	PUSH	H
	LXI	H,63		;about 100 milliseconds
	CALL	FIXCNT
	MOV	B,H		;delay is in 'HL'
	MOV	C,L		;transfer to 'BC'
	POP	H		;get original value of 'HL' back
;
INMDM1	CALL	RCVRDY		;see if there is a character ready
	JNZ	INMDM2		;if no character, exit
	CALL	I$MDDATP	;get the character
	ANI	7FH		;strip off any parity
	RET			;return with character in 'A' reg.
;
INMDM2	DCX	B		;otherwise keep timing
	MOV	A,B
	ORA	C
	JNZ	INMDM1		;loop until timeout if needed
	STC			;shows a timeout occured
	RET
;
; Send a space tone to the phone line for a short time.
;
BREAK	LDA	PMMIMD		;using the PMMI modem?
	ORA	A
	JZ	BREAK1		;if not, exit
	LDA	MDCTLB		;get the last modem control byte
	ANI	BRKMASK		;set the transmit break bit low
	CALL	O$MDCTL2	;send it to the modem
	MVI	B,2
	CALL	TIMER		;send a space tone for 200 ms.
	LDA	MDCTLB		;get the last modem control byte
	CALL	O$MDCTL2	;restore to normal
	JMP	TERM		;back to work
;
BREAK1	CALL	J$BREAK		;get the user's break routine
	JMP	TERM		;back to work
;
;=======================================================================
;		     WRITE BUFFER TO DISK
;
; Make sure this record is included in the count.
;
WRDSK	LHLD	HLSAV
	MVI	M,EOFCHAR	;ASCII file, store end-of-file char.
	LXI	D,127
	DAD	D
;
WRDSK1	LXI	D,-(BUFFER)	;subtract the start of the buffer
	DAD	D		;by adding a minus number to buffer end
	MOV	A,L		;divide hl by 128
	ORA	A
	RAL			;  to get the
	MOV	L,H		;  number of records
	MVI	H,0
	PUSH	PSW
	DAD	H
	POP	PSW
	MVI	A,0
	ADC	L
	MOV	L,A		;number of records in 'HL'
;
; See if buffer is empty.  If yes, see if we need to erase an empty
; file or have already written something.
;
	LXI	D,BUFFER
	LDAX	D
	CPI	EOFCHAR		;'EOF' in first address means
	JNZ	WRDSK2		;  nothing in buffer to write
	LDA	WRFLG		;first time by this way?
	ORA	A
	JZ	NOWRITE		;if yes, show erasing file
	RET			;otherwise go close file
;
; Write to disk.  Start from BUFFER (in 'DE').	Number of records to
; write in 'HL'.
;
WRDSK2	MVI	C,STDMA
	CALL	BDOSRT
	PUSH	D
	MVI	C,WRITE
	LXI	D,FCB3		;location of filename to write to
	CALL	BDOSRT
	POP	D
	ORA	A
	JNZ	WRERRSP		;error if disk is full ** special patch
	XCHG			;put the current address in 'HL'
	PUSH	D		;  and number of records left in
	LXI	D,128		;  for now
	DAD	D		;add for next record write, now in 'HL'
	POP	D		;restore number of records left
	XCHG			;records to 'HL' again, address to 'DE'
	DCX	H		;one less record left
	MOV	A,H
	ORA	L		;done writing when 'H' and 'H' both zero
	JNZ	WRDSK2		;otherwise do another disk write
	RET
;
; Error while writing a record, show why it is aborting
;
WRERR	MVI	C,CANCEL	;send cancel char. to sending station
	CALL	SND
	CALL	CLOSFIL		;close the current file
;
WRERR1	CALL	ERXIT		;also will reset stack
	DB	'++ DISK FULL, SAVING PARTIAL FILE ++','$'
;
; If no data to store on the disk, close the empty file and erase it
;
NOWRITE	CALL	WRFIL2		;close the empty file
	CALL	NOASK		;erase the empty file
	CALL	ILPRT
	DB	'++ Nothing to save, erasing file ++'
	DB	CR,LF,BELL,0
	JMP	DONETA		;reset any flags, return to menu
;
; Show you are in memory-save for disk write
;
TYPSEM	MVI	A,';'
	JMP	TYPE		;show on CRT, return
;
; Save the registers, call BDOS then restore the registers
;
BDOSRT	PUSH	B
	PUSH	D
	PUSH	H
	CALL	BDOS
	POP	H
	POP	D
	POP	B
	RET
;
INITFCB	MVI	M,0		;entry at +2 will leave drive # intact
	INX	H		;will initialize an FCB
	MVI	B,11		;pointed to by HL-reg. fills 1st pos.
;
LOOP11	MVI	M,' '		;  with 0, next 11 with
	INX	H		;  with blanks, and last
	DCR	B		;  21 with nulls
	JNZ	LOOP11
	MVI	B,21
;
LOOP21	MVI	M,0
	INX	H
	DCR	B
	JNZ	LOOP21
	RET
;
; Scans CMDBUF counting names and putting delimiter (space) after last
; name.
;
SCAN	PUSH	H
	LXI	H,NAMECT
	MVI	M,0
	LXI	H,CMDBUF+1	;find end of command line, add space
	MOV	C,M
	MVI	B,0
	LXI	H,CMDBUF+2
	DAD	B
	MVI	M,' '
	LXI	H,CMDBUF+1
	MOV	B,M
	INR	B
	INR	B
;
SCANL1	INX	H
	DCR	B
	JZ	DNSCAN
	MOV	A,M
	CPI	' '
	JNZ	SCANL1
;
SCANL2	INX	H		;eat extra spaces
	DCR	B
	JZ	DNSCAN
	MOV	A,M
	CPI	' '
	JZ	SCANL2
	SHLD	BGNMS		;save start of names in CMDBUF
	INR	B
	DCX	H
;
SCANL3	INX	H
	DCR	B
	JZ	DNSCAN
	MOV	A,M
	CPI	' '
	JNZ	SCANL3
	LDA	NAMECT		;counts names
	INR	A
	STA	NAMECT
;
SCANL4	INX	H		;eat spaces
	DCR	B
	JZ	DNSCAN
	MOV	A,M
	CPI	' '
	JZ	SCANL4
	JMP	SCANL3
;
DNSCAN	MVI	M,' '		;space after last character
	POP	H
	RET
;
; Places next name in buffer so 'CMDLINE' may parse it
;
TRTOBUF	LHLD	BGNMS
	MVI	B,0
	LXI	D,FCBBUF+2
;
TBLP	MOV	A,M
	CPI	' '
	JZ	TRBFEND
	STAX	D
	INX	H
	INX	D
	INR	B		;count characterss in name
	JMP	TBLP
;
TRBFEND	INX	H
	MOV	A,M		;eat extra spaces
	CPI	' '
	JZ	TRBFEND
	SHLD	BGNMS
	LXI	H,FCBBUF+1	;put # chars before name
	MOV	M,B
	RET
;
CKCPM2	MVI	C,CPMVER	;BDOS 12 -- version number -- cp/m 2.x?
	CALL	BDOS
	ORA	A
	RZ
	MVI	C,STDMA
	LXI	D,TBUF
	CALL	BDOS
	MVI	C,SRCHF
	LXI	D,FCB
	CALL	BDOS
	CPI	0FFH
	RZ
;
	CALL	GETADD
	LXI	D,9
	DAD	D		;point to R/O attribute byte
	MOV	A,M
	ANI	80H		;test most significant byte
	JNZ	MKCHG		;if set, make change
	INX	H		;check system attribute byte
	MOV	A,M
	ANI	80H
	RZ			;not SYS or R/O attribute
	DCX	H
;
MKCHG	LXI	D,-8
	DAD	D		;point HL to filename + 1
	LXI	D,FCB+1		;move directory name to FCB
	MVI	B,11		;  without changing drive
	CALL	MOVE
	LXI	H,FCB+9		;R/O attribute
	MOV	A,M
	ANI	7FH		;strip R/O attribute
	MOV	M,A
	INX	H		;system attribute
	MOV	A,M
	ANI	7FH
	MOV	M,A
	LXI	D,FCB
	MVI	C,30		;set new attributes in directory
	CALL	BDOS
;
; Called by 'CKBAKUP' below, return done here through 'BDOS' jump
;
PLANCHG	LXI	H,FCB		;change name to type "BAK"
	LXI	D,FCB2
	MVI	B,9		;move drive and name (not type)
	CALL	MOVE
	LXI	H,75H		;start of type in FCB2
	MVI	M,'B'
	INX	H
	MVI	M,'A'
	INX	H
	MVI	M,'K'
	LXI	D,FCB2
	MVI	C,ERASE		;erase any previous backups
	CALL	BDOS
	LXI	H,FCB2		;FCB2 drive field should have
	MVI	M,0
	LXI	D,FCB
	MVI	C,23		;rename
	JMP	BDOS
;
CKBAKUP	LDA	BACKUP
	ORA	A
	RZ
	MVI	C,SRCHF
	LXI	D,FCB
	CALL	BDOS
	INR	A
	RZ			;file not found
	JMP	PLANCHG		;in 'CKCPM2' - return done there
;
;***********************************************************************
;	    RECEIVE A RECORD FROM SENDING STATION
;***********************************************************************
;
; If CRC is in effect, there is a 10-second timeout to the first SOH.
; It then tries six more times to let the sender know the system is
; capable of receiving a 'CRC' check.  At the end of that time a NAK is
; sent which tells the sender to use CHECKSUM checking instead of CRC.
; This allows automatic compatability with systems implementing CRC -
; (Cyclic Redundancy Checking).  The search for SOH will cycle through
; one record interval and ignore noise or characters sent by the remote
; for any purpose (such as progress reporting).  So extraneous characters
; that are sometimes sent by remote-end protocol will be gobbled up until
; the first SOH.  EOT is tested only as the first returned character af-
; ter each sector.
;
SRCHSOH	EQU	160		;number of times to loop search for SOH
;
RCVRECD	MVI	A,1
	STA	ERRCT		;initialize the error count
;
RCVSQ	MVI	B,10		;10 seconds allowed to receive 1st char.
	LXI	D,SRCHSOH	;initialize loop for up to 160 seconds
	CALL	RECV		;get the 1st character
	JC	RCVSTOT		;timeout error if not rcvd in 10 seconds
	MOV	C,A		;save the character for now
	CPI	EOT		;see if end of transmission
	STC			;set carry
	RZ			;return with carry set
;
SOHLUP	MVI	A,0FFH
	STA	CHRFLG
	STA	TIMFLG
	MOV	A,E		;get search count-down value
	CPI	SRCHSOH		;see if it is the 1st returned character
	MOV	A,C		;get the first character now
	JZ	NORECV		;skip RECV routine if 1st character
	MVI	B,1
	CALL	RECV
	MOV	B,A
	JNC	TSTSOH
;
NORECV	MOV	B,A
	XRA	A		;else set the value that forces timeout
	STA	CHRFLG
;
TSTSOH	MOV	A,B		;get the character
	CPI	SOH		;see if it is SOH
	PUSH	PSW
	XRA	A
	STA	TIMFLG		;restore this flag
	POP	PSW
	JZ	RCVSOH		;got SOH, get rcd # and its complement
	MOV	A,D
	ORA	E		;see if counted-down to zero
	DCX	D
	JNZ	SOHLUP		;go around again if not
	LDA	CHRFLG		;see if timeout needs to be forced
	ORA	A
	JZ	RCVSTOT		;go do timeout and count them
	LDA	QFLG
	ORA	A
	JZ	RCVSRR
;
RCVSH	CALL	CRLF
	MOV	A,B
	CALL	HEXO
	CALL	ILPRT
	DB	'H received not SOH - ',0
;
RCVPRN	CALL	SHOERR		;display error count
;
RCVSRR	CALL	WAITQ1		;wait for 1 second with no characters
	CALL	CKABORT		;want to stop receiving now?
	LDA	CRCFLAG		;get 'CRC' flag
	ORA	A		;'CRC' in effect?
	MVI	A,NAK		;put 'NAK' in 'A' register
	JZ	RCVSR1		;no, send the 'NAK'
	LDA	FIRSTME		;get first time switch
	ORA	A		;has first 'SOH' been received?
	MVI	A,NAK		;put 'NAK' in 'A' register
	JNZ	RCVSR1		;yes, then send 'NAK'
	MVI	A,CRC		;tell sender 'CRC' is in effect
;
RCVSR1	CALL	SND		;  the 'NAK' or 'CRC' request
	LDA	ERRCT		;abort if we have reached error limit
	INR	A
	STA	ERRCT		;store for next time
	CPI	ERRLIM		;see if at limit yet
	JC	RCVSQ		;if not, keep going
	LDA	RETRY		;see if retry after 10 errors is set
	ORA	A
	JZ	ABORT		;if 'YES', abort
	JMP	CKQIT		;if 'NO' check for continued use
;
RCVSABT	LXI	SP,STACK	;reset the stack just in case
	CALL	CLOSFIL		;close the partial file
	CALL	NOASK		;delete partial file
	CALL	ILPRT
	DB	CR,LF,LF
	DB	'++ RECEIVED FILE CANCELLED ++',CR,LF,BELL
	DB	'++ UNFINISHED FILE DELETED ++',CR,LF,0
	JMP	DONETA
;
RCVSTOT	LDA	QFLG
	ORA	A
	JZ	RCVSCC
;
RCVSPT	CALL	ILPRT
	DB	CR,LF,'++ Timeout ',0
	CALL	SHOERR
;
RCVSCC	CALL	RCVSCC2
	JMP	RCVSRR
;
; Routine will switch from 'CRC' to Checksum if 'ERCNT' reaches 'ERRCRC'
; and 'FIRSTIME' is false.
;
RCVSCC2	LDA	ERRCT
	CPI	ERRCRC
	RNZ
	LDA	FIRSTME
	ORA	A
	RNZ
	LDA	CRCFLAG
	ORA	A
	RZ
	CMA
	STA	CRCFLAG
	STA	CRCDFLT
	CALL	ILPRTQ
	DB	'** Switching to Checksum mode **',CR,BELL,LF,0
	RET
;
; Got SOH - get block #, block # complemented
;
RCVSOH	MVI	A,0FFH
	STA	FIRSTME		;indicate 1st soh was received
	MVI	B,5		;timeout = 5 seconds
	CALL	RECV		;get record
	JC	RCVSTOT		;got timeout
	MOV	D,A
	MVI	B,5		;timeout = 5 seconds
	CALL	RECV
	JC	RCVSTOT
	CMA
	CMP	D
	JZ	RCVDATA
	LDA	QFLG
	ORA	A
	JZ	RCVSRR
;
RCVBSE	CALL	ILPRT
	DB	CR,LF,'++ Bad record # in header ',0
	JMP	RCVPRN
;
RCVDATA	MOV	A,D
	STA	RCVRNO
	MVI	A,1
	STA	DATAFLG
	MVI	C,0
	LXI	H,0
	SHLD	CRCVAL
	LXI	H,80H
;
RCVCHR	MVI	B,5		;wait up to 5 seconds for a character
	CALL	RECV
	JC	RCVSTOT
	MOV	M,A
	INR	L
	JNZ	RCVCHR
	XRA	A
	STA	DATAFLG
	LDA	CRCFLAG
	ORA	A
	JNZ	RCVCR
	MOV	D,C
	MVI	B,5		;wait up to 5 seconds for an answer
	CALL	RECV
	JC	RCVSTOT
	CMP	D
	JNZ	RCVCERR
;
CHKSNUM	LDA	RCVRNO
	MOV	B,A
	LDA	RECNO
	CMP	B
	JZ	RCVACK
	INR	A
	CMP	B
	JNZ	ABORT
	RET
;
RCVCR	MVI	E,2		;number of 'CRC' bytes
;
RCVCR2	MVI	B,5		;wait up to 5 seconds for a character
	CALL	RECV
	JC	RCVSTOT
	DCR	E
	JNZ	RCVCR2
	CALL	CRCCHK
	ORA	A
	JZ	CHKSNUM
	LDA	QFLG
	ORA	A
	JZ	RCVSRR
;
RCVCRER	CALL	ILPRT
	DB	'++ CRC error ',0
	JMP	RCVPRN
;
RCVCERR	LDA	QFLG
	ORA	A
	JZ	RCVSRR
;
RCVCPR	CALL	ILPRT
	DB	'++ CHECKSUM error ',0
	JMP	RCVPRN
;
RCVACK	CALL	SNDACK
	JMP	RCVRECD
;
; Get the error count and display on CRT
;
SHOERR	PUSH	H
	LHLD	ERRCT
	MVI	H,0
	CALL	DECOUT
	POP	H
	CALL	ILPRT
	DB	' ++',CR,LF,0
	LDA	ERRCT
	CPI	ERRLIM
	JNC	ABORT
	RET
;
SNDHDR	LDA	QFLG
	ORA	A
	JZ	SNDHNM
	CALL	ILPRT
	DB	CR,'Sending # ',0
	PUSH	H		;store current address
	LHLD	RECNO		;get record number
	CALL	DECOUT		;print it in decimal
	CALL	ILPRT
	DB	' ',0
;
	LDA	HEXSHO
	ORA	A
	JZ	SNDHNM-1
	CALL	ILPRT
	DB	'(',0
	CALL	DHXOUT		;16 bit hex conversion & output
	CALL	ILPRT
	DB	'H) ',0
;
	POP	H		;restore current address
;
SNDHNM	MVI	A,SOH		;send 'SOH' character to the output
	CALL	SND
	LDA	RECNO		;send record number to the output
	CALL	SND
	LDA	RECNO
	CMA			;complement the record number
	JMP	SND		;send this value to the output
;
SNDREC	MVI	A,1
	STA	DATAFLG
	MVI	C,0
	LXI	H,0		;new record, clear 'CHECKSUM' value
	SHLD	CRCVAL		;new record, clear 'CRC' value
	LXI	H,TBUF		;store at 0080H
;
SNDC	MOV	A,M
	CALL	SND
	INR	L
	JNZ	SNDC
	XRA	A
	STA	DATAFLG
	RET
;
SNDCKS	MOV	A,C
	JMP	SND
;
SNDCRC	PUSH	H
	LHLD	CRCVAL
	MOV	A,H
	CALL	SND
	MOV	A,L
	CALL	SND
	POP	H
	XRA	A		;reset the carry bit
	RET
;
; After a record is sent, a character is returned telling if it was re-
; ceived properly or not.  An ACK allows the next record to be sent.  A
; NAK causes the current record to be resent.  If no character (or any
; character other than ACK or NAK) is received after a short wait (10
; to 12 seconds), a timeout error message is shown and the record will
; be resent.  The GTACK routine can gobble up a string of up to 191
; characters while searching for an 'ACK' or a 'NAK'.
;
GTACK	MVI	E,192		;number of characters to gobble
;
ACKLUP	MVI	A,0FFH
	STA	CHRFLG		;set the character flag
	STA	TIMFLG		;set the time flag
	MVI	B,1
	CALL	RECV
	MOV	B,A		;save the character
	JNC	ACKTST
	XRA	A
	STA	CHRFLG		;reset the character flag, was none
;
ACKTST	XRA	A
	STA	TIMFLG
	MOV	A,B		;get the character back
	CPI	ACK
	RZ
	CPI	NAK
	JZ	GTACK1
;
NOAKNK	DCR	E		;one less to go
	JNZ	ACKLUP		;loop around again if not zero
	LDA	CHRFLG
	ORA	A
	JZ	GETATOT
;
GTACK1	LDA	BENHERE
	XRA	B
	JZ	ACKER0		;do not say 'ACK error' if 1st 'NAK'
	LDA	QFLG
	ORA	A
	JZ	ACKER
	CALL	ILPRT
	DB	'++ ',0
	MOV	A,B
	CPI	NAK
	JZ	GTACK3
	CALL	HEXO
	CALL	ILPRT
	DB	'H',0
	JMP	GTACK4
;
GTACK3	CALL	ILPRT
	DB	'NAK',0
;
GTACK4	CALL	ILPRT
	DB	' received not ACK - ',0
	CALL	SHOERR
;
ACKER0	XRA	A
	STA	BENHERE
;
ACKER	LDA	ERRCT
	INR	A
	STA	ERRCT
	CPI	ERRLIM+1	;at error limit yet?
	RC			;if not, return
;
ACKER1	CALL	ERXIT
	DB	CR,LF,'++ SEND-FILE CANCELLED ++','$'
;
; Reached error limit
;
GETATOT	CALL	ILPRT
	DB	CR,'++ TIMEOUT - no ACK - ',0
	CALL	SHOERR		;display error count
	JMP	ACKER
;
CKABORT	LDA	QFLG
	ORA	A
	RZ
	CALL	STAT
	RZ
	CALL	KEYIN
	CPI	CANCEL
	RNZ
;
; Aborts send or receive routines and returns to command line
;
ABORT	LXI	SP,STACK
;
ABORTL	MVI	B,1		;1-second delay to clear input
	CALL	RECV
	JNC	ABORTL
	MVI	A,CANCEL	;show you are cancelling
	CALL	SND
;
ABORTW	MVI	B,1		;1-second delay to clear input
	CALL	RECV
	JNC	ABORTW
	MVI	A,' '
	CALL	SND
	MVI	A,'B'		;turn multi-file mode
	STA	BCHFLG		;  off so routine ends
	STA	ABTFLG		;shows an abort was made
	XRA	A
	STA	NFILFLG		;stop copy into memory for disk file
	LDA	OPTION		;receiving a file now?
	CPI	'R'
	JZ	RCVSABT		;if yes, cancel the unfinished file
	CALL	ILPRT
	DB	CR,LF,LF,'++ FILE CANCELLED ++',CR,LF,BELL,0
	JMP	DONETA
;
; Increment the record count
;
INCRRNO	PUSH	H
	LHLD	RECNO		;get record number
	INX	H		;bump it
	SHLD	RECNO		;store it
	MOV	A,L
	POP	H
	RET
;
; First check for any wild cards and disallow, just to be safe.  Do not
; want a group of files being accidently erased.
;
ERASF	LXI	H,FCB		;file name is stored here
	MVI	B,11		;maximum of 11 chars for filename.ext
;
ERASF1	INX	H		;next location in file name
	MOV	A,M		;get the char.
	CPI	'?'		;check for any wild card characters
	JZ	ERRORW		;error if one is found
	DCR	B		;number of tries left
	JNZ	ERASF1		;if not zero, keep checking
	LDA	BCHFLG		;do not ask for erase
	ORA	A		;  in multi-file mode,
	JZ	NOASK		;  just do it
	LXI	D,FCB
	MVI	C,SRCHF
	CALL	BDOS
	INR	A
	RZ			;file erased ok, return
	CALL	ILPRT		;otherwise make sure it is ok
	DB	'File exists - erase?  (Y/N): ',BELL,0
	CALL	KBDCHR
	CPI	'Y'
	JNZ	MENU		;if not a 'Y' do not erase
	CALL	CRLF		;otherwise erase the file
;
NOASK	LXI	D,FCB
	MVI	C,ERASE
	JMP	BDOS
;
ERRORW	POP	H		;restore stack from "call ERASF"
	CALL	ILPRT
	DB	'++ NO WILDCARDS ALLOWED FOR TEXT FILES ++'
	DB	CR,LF,BELL,0
	JMP	MENU
;
BLKFILE	CALL	ILPRT		;no file named for send or receive
	DB	'++ NO FILE SPECIFIED ++',CR,LF,BELL,0
	JMP	MENU
;
MAKEFIL	LXI	D,FCB
	MVI	C,MAKE
	CALL	BDOS
	INR	A
	RNZ
	CALL	ERXIT
	DB	'++ ERROR -- Can''t open file ++',CR,LF
	DB	'++ Directory is perhaps full ++','$'
;
CNREC	MVI	C,FILSIZ	;compute file size function in CP/M 2.x
	LXI	D,FCB		;point to file control block
	CALL	BDOS
	LHLD	FCB+33		;get record count
	SHLD	RCNT		;store it
	LXI	H,0		;zero 'HL'
	SHLD	FCB+33		;reset random record in FCB
	RET
;
OPENFIL	XRA	A
	STA	FCBEXT
	LXI	D,FCB
	MVI	C,OPEN
	CALL	BDOS
	INR	A
	JNZ	SNDTM		;send transfer time, # of records, etc.
	CALL	ERXIT		;file did not open
	DB	'++ FILE NOT FOUND ++','$'
;
CLOSFIL	LXI	D,FCB		;get the file name
	MVI	C,CLOSE
	CALL	BDOS		;close the file
	INR	A
	RNZ
	JMP	ERXIT1		;no file to close, exit
;
; Update record read
;
RDRECD	LDA	RECINBF		;decrement 'RECORDS IN BUFFER' count
	DCR	A
	STA	RECINBF
	JM	RDBLOCK
	LHLD	RECPTR		;find where last move stopped
	LXI	D,128
	CALL	MOVE128		;move 128 characters
	SHLD	RECPTR		;store new address for next move
	RET
;
; Buffer empty so read in another block from the disk
;
RDBLOCK	LDA	EOFLG
	CPI	1
	STC
	RZ
	MVI	C,0
	LXI	D,BUFFER
;
RDRECLP	PUSH	B
	PUSH	D
	MVI	C,STDMA
	CALL	BDOS
	LXI	D,FCB
	MVI	C,READ
	CALL	BDOS
	POP	D
	POP	B
	ORA	A
	JZ	RDRECOK
	DCR	A
	JZ	REOF
	CALL	ERXIT
	DB	'++ FILE READ ERROR ++','$'
;
RDRECOK	LXI	H,128
	DAD	D
	XCHG
	INR	C
	CALL	DSKSIZ		;establish buffer size
	JZ	RDBFULL
	JMP	RDRECLP
;
REOF	MVI	A,1
	STA	EOFLG
	MOV	A,C
;
; Buffer full or received "End Of File (EOF)"
;
RDBFULL	STA	RECINBF
	LXI	H,BUFFER
	SHLD	RECPTR
	MVI	C,STDMA
	LXI	D,TBUF
	CALL	BDOS
	JMP	RDRECD
;
; Write a record
;
WRRECD	LHLD	RECPTR
	XCHG
	LXI	H,128
	CALL	MOVE128
	XCHG
	SHLD	RECPTR		;new record pointer
	LDA	RECINBF		;increment 'RECORDS IN BUFFER' count
	INR	A
	STA	RECINBF
	MOV	C,A		;store the record count for now
	CALL	DSKSIZ		;establish buffer size
	RNZ			;buffer not full, return
;
; Write a block to disk
;
WRBLOCK	LDA	RECINBF		;get the number of records in the buffer
	ORA	A
	RZ			;if zero, don't try to move to disk
	MOV	C,A		;otherwise store in 'C' register
	LXI	D,BUFFER	;start of buffer to move to disk
;
DSKWRT	PUSH	B
	PUSH	D
	PUSH	H
	MVI	C,STDMA
	CALL	BDOS
	MVI	C,WRITE
	LXI	D,FCB
	CALL	BDOS
	POP	H
	POP	D
	POP	B
	ORA	A
	JNZ	WRERR		;error if disk is full
	LXI	H,128		;add in another page
	DAD	D
	XCHG
	DCR	C		;one less record left to move to disk
	JNZ	DSKWRT
	XRA	A
	STA	RECINBF		;zero the 'RECORDS IN BUFFER' count
	LXI	H,BUFFER	;reset location to next buffer start
	SHLD	RECPTR
	RET
;
; Determine if the buffer size is for file transfer or for ASCII capture
; to disk then compare with current record length
;
DSKSIZ	LDA	XFLG		;see if transferring files now
	ORA	A
	MOV	A,C		;get the current record count
	JZ	DSKSIZ1		;if yes, exit
	MOV	A,C
	CPI	BUFSIZ*8	;buffer size for ASCII capture to disk
	RET			;return with flag set for the compare
;
DSKSIZ1	LDA	SAVSIZ		;get the file transfer buffer size..
	CMP	C		;..from special storage area and compare
	RET			;return with flag set for the compare
;
; Timeout time is in B, in seconds.  Entry via 'RECVDG' deletes garbage
; characters on the line.  For example, having just sent a record, cal-
; ling RECVDG will delete any line noise induced characters LONG before
; the ACK/NAK would be received.
;
RECVDG	CALL	CKCHAR		;catch any garbage characters
;
RECV	PUSH	D
;
; Get back quickly to gobble 2nd character if TIMFLG is set by the GETNM
; routine - or just step through quickly after the first wait for 'SOH'
; in the 'SOHLUP' routine.
;
MSEC	PUSH	H
	LXI	H,TIMFLG
	MOV	E,M
	INR	E
	LHLD	QUIKTIM
	JZ	DOQUIK
	LHLD	TIMVAL
;
DOQUIK	XCHG
	POP	H
;
MWTI	CALL	RCVRDY
	JZ	MCHAR
	MOV	A,D
	ORA	E
	DCX	D
	JNZ	MWTI
	DCR	B
	JNZ	MSEC
	POP	D
	CALL	CKABORT
	STC
	RET
;
; Get the character from the modem, but filter out 'ACK' and '.' chars.
; if receiving a file name.  ('FILTRFLG' is set by the 'GETNM' routine.)
;
MCHAR	CALL	I$MDDATP	;get the character that is waiting
	POP	D
	PUSH	PSW		;save the character for later use also
	CPI	ACK		;see if it is 'ACK'
	JZ	ISACK
	CPI	'.'		;see if it is a period
	JNZ	DOUPD		;neither, so update 'CRC'
;
ISACK	PUSH	H
	PUSH	D
	LXI	H,FLTRFLG	;see if need to each 'ACK' or period
	MOV	E,M
	INR	E
	POP	D
	POP	H
	JZ	MWTI		;yes, so do it
;
DOUPD	CALL	CRCUPD		;calculate 'CRC'
	ADD	C
	MOV	C,A
	LDA	RSEEFLG
	ORA	A
	JZ	MONIN
	LDA	VSEEFLG
	ORA	A
	JNZ	NOMONIN
	LDA	DATAFLG
	ORA	A
	JZ	NOMONIN
;
MONIN	POP	PSW		;get the character again
	PUSH	PSW		;resave it for later use also
	CALL	SHOW		;show the character on the CRT
;
NOMONIN	CALL	CKABORT
	POP	PSW		;get the character back once more
	ORA	A		;reset the carry flag
	RET			;return with the character and flag set
;
; Send a character to the modem
;
SND	PUSH	PSW
	LDA	SSEEFLG
	ORA	A
	JZ	MONOUT
	LDA	VSEEFLG
	ORA	A
	JNZ	NOMONOT
	LDA	DATAFLG
	ORA	A
	JZ	NOMONOT
;
MONOUT	POP	PSW
	PUSH	PSW
	CALL	SHOW
;
NOMONOT	POP	PSW
	PUSH	PSW
	CALL	CRCUPD		;update the 'CRC' calcuation
	ADD	C
	MOV	C,A
;
SNDW	CALL	SNDRDY
	JNZ	SNDW
	POP	PSW
	JMP	O$MDDATP	;send character to modem, done
;
; Waits for the first character received while waiting to send a file.
; If a character is not received in one second, it loops again until a
; char. is received or it times out.  The count is set for two minutes
; before timeout.  This gives the receiving station ample time to name
; a file, etc.
;
WAITNAK	CALL	ILPRT
	DB	'Waiting ready signal',CR,LF,0
	CALL	CRLF
;
WAITNLP	CALL	CKABORT
	MVI	B,1		;wait up to 1 second for a character
	CALL	RECV
	CPI	CANCEL		;want to quit?
	JZ	ABORT
	CPI	CRC		;'CRC' request?
	JZ	WAITCRC		;yes, go set 'CRC' flag
	CPI	NAK
	JZ	WAICK
	DCR	E
	JNZ	WAITNLP
	JMP	ABORT
;
WAITCRC	CALL	ILPRTQ
	DB	'CRC request received',CR,LF,0
	MVI	A,1
	STA	CRCFLAG		;make sure in 'CRC' mode then
	RET
;
WAICK	LDA	BCHFLG		;in batch mode?
	ORA	A
	RZ
	CALL	ILPRTQ
	DB	'Got checksum request',CR,LF,0
	RET
;
WAICK1	CALL	ILPRTQ
	DB	'Name NAK received',CR,LF,0
	RET
;
; Finished with the file transfer
;
DONE	LDA	BCHFLG		;in batch mode?
	ORA	A
	JNZ	DONET		;exit if not
	LDA	QFLG
	ORA	A
	JZ	NMSTRNS
	MVI	B,12		;zero out FTRNM
	LXI	H,FTRNM
	MVI	A,0
;
ZEROLP	MOV	M,A
	INX	H
	DCR	B
	JNZ	ZEROLP
	MVI	B,12		;put file name in FTRNM
	LXI	H,FCB+1
	LXI	D,FTRNM
;
LOADMSG	MVI	A,4		;start of file type?
	CMP	B
	JZ	PERIOD		;put in period if so
	MOV	A,M
	CPI	' '
	JZ	SKPSP
	STAX	D		;store in FTRNM
	INX	D
;
SKPSP	INX	H
	DCR	B
	MOV	A,B
	ORA	A		;end of file name?
	JZ	FTRNM0		;display file name
	JMP	LOADMSG		;loop for another character
;
PERIOD	MOV	A,M
	CPI	' '		;is file type empty?
	JZ	FTRNM0		;go if so
	MVI	A,'.'		;else put period in message
	STAX	D
	INX	D
	DCR	B
	JMP	LOADMSG
;
FTRNM0	CALL	ILPRT
	DB	CR,LF
;
FTRNM	DS	12
	DB	0
	CALL	ILPRT
	DB	' Transferred',CR,LF,LF,BELL,0
;
NMSTRNS	LDA	FCB		;save drive number
	STA	DISKNO
	LXI	H,FCB		;blank out file control blocks
	CALL	INITFCB
	LDA	DISKNO		;put drive number back
	STA	FCB
	LXI	H,RESTSN	;restore record numbers
	LXI	D,RECNOB	;  for new file transfer
	MVI	B,RECNOE-RECNOB	;routine also done in menu
	CALL	MOVE
	CALL	SNDNOW		;insures last character is finished
	CALL	CKCHAR		;catch any echo characters on line
	LDA	SNDFLG		;goes to either send or
	ORA	A		;  receive file, depending
	JNZ	SNDFL2		;  upon which routine set
	JMP	RCVFL1		;  the flag in multi-file mode
;
DONET	CALL	CKABORT		;slight delay for next message
	CALL	ILPRT
	DB	CR,LF,'[Transfer completed]',CR,LF,BELL,0
;
DONETA	LDA	XITFLG		;special 'X' flag set?
	ORA	A
	JZ	BYEBYE		;if yes, disconnect and reboot
	LDA	DISCFLG		;normal 'D' flag set?
	ORA	A
	JZ	DONETD		;if yes, disconnect, get next command
;
DONETB	CALL	J$NPARIT	;reset to no parity
	XRA	A
	STA	CRCFLAG		;reset back to checksum
	STA	FIRSTME		;reset first-time 'SOH' flag
	STA	FSTFLG		;reset multi-file trans
	STA	NFILFLG		;turn off the memory save for disk file
	STA	SAVEFLG		;stop memory save in term routine.
	LDA	VSEEFLG		;view flag set?
	ORA	A
	JNZ	DONETC		;if not, exit
	CMA
	STA	QFLG		;VSEEFLG also sets the QFLG
	STA	VSEEFLG		;reset the flag
;
DONETC	LXI	H,QFLG		;in quiet mode?
	MOV	A,M
	ORA	A
	MVI	M,'Q'		;reset the flag to normal
	JZ	MENU		;if yes, go back to command line
	LDA	ABTFLG		;come here from a timeout?
	ORA	A
	JNZ	MENU		;if yes, go to command mode
	LDA	JMPCMD		;requesting return to command mode?
	ORA	A
	JZ	MENU		;if yes go to command mode
	CALL	CRLF		;turn up a new line
	JMP	TERM		;otherwise return to terminal mode
;
DONETD	CALL	ILPRT
	DB	CR,LF,'<< DISCONNECTED >>',BELL,CR,LF,0
	CALL	J$GOODBY	;set 'DTR' low for 300 ms.
	LDA	PMMIMD
	ORA	A
;;;	CNZ	J$GOODBY
	DB	0,0,0		;(PREVENT DOUBLE DISCONNECT)
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
;;;	CNZ	J$GOODBY	;if yes, disconnect
	DB	0,0,0		;(PREVENT DOUBLE DISCONNECT)
	JMP	MENU0		;back to command line
;
MOVEFCB	LXI	H,FCB+16
	LXI	D,FCB
	MVI	B,16
	CALL	MOVE
	XRA	A
	STA	FCBSNO
	STA	FCBEXT
	RET
;
SHOW	CPI	LF
	JZ	CTYPE
	CPI	CR
	JZ	CTYPE
	CPI	9
	JZ	CTYPE
	CPI	' '
	JC	SEEHEX
	CPI	7FH
	JC	CTYPE
;
SEEHEX	PUSH	PSW
	MVI	A,'('
	CALL	CTYPE
	POP	PSW
	CALL	HEXO
	MVI	A,')'
	JMP	CTYPE
;
CTYPE	PUSH	B
	PUSH	D
	PUSH	H
	MOV	E,A
	MVI	C,WRCON
	CALL	BDOS
	POP	H
	POP	D
	POP	B
	RET
;
CRLF	PUSH	PSW
	MVI	A,CR
	CALL	TYPE
	MVI	A,LF
	CALL	TYPE
	POP	PSW
	RET
;
STAT	PUSH	B
	PUSH	D
	PUSH	H
;
VSTAT	CALL	$-$		;BIOS constat address, filled in
	POP	H		;  by 'INITAD' routine
	POP	D
	POP	B
	ORA	A
	RET
;
KEYIN	PUSH	B
	PUSH	D
	PUSH	H
;
VKEYIN	CALL	$-$		;BIOS 'CONIN' address, filled in
	POP	H		;  by 'INITAD' routine
	POP	D
	POP	B
	RET
;
TYPE	PUSH	PSW
	PUSH	B
	PUSH	D
	PUSH	H
	MOV	C,A
;
VTYPE	CALL	$-$		;BIOS 'CONOUT' address, filled in
	POP	H		;  by 'INITAD' routine
	POP	D
	POP	B
	POP	PSW
	RET
;
; Get a character from the keyboard, convert to upper-case if needed,
; and show on CRT
;
KBDCHR	CALL	KEYIN		;get a keyboard character
	CALL	UCASE		;convert to upper case if needed
	CALL	TYPE		;show on CRT
	RET
;
UCASE	CPI	61H		;changes lower case character
	RC			;  in 'A'reg. to upper case
	CPI	7AH+1		;see if more than small 'Z'
	RNC
	ANI	5FH
	RET
;
DECOUT	PUSH	PSW
	PUSH	B
	PUSH	D
	PUSH	H
	LXI	B,-10
	LXI	D,-1
;
DECOU1	DAD	B
	INX	D
	JC	DECOU1
	LXI	B,10
	DAD	B
	XCHG
	MOV	A,H
	ORA	L
	CNZ	DECOUT
	MOV	A,E
	ADI	'0'
	CALL	CTYPE
	POP	H
	POP	D
	POP	B
	POP	PSW
	RET
;
;---->	DHXOUT: - double precision hex output routine
;
DHXOUT	PUSH	H
	PUSH	PSW
	MOV	A,H		;get MS byte
	CALL	HEXO		;output high order byte
	MOV	A,L		;get LS byte
	CALL	HEXO		;output low order byte
	POP	PSW
	POP	H
	RET
;
; Prints a hex value in 'A' on the CRT
;
HEXO	PUSH	PSW
	RAR
	RAR
	RAR
	RAR
	CALL	NIBBL
	POP	PSW
;
NIBBL	ANI	0FH
	CPI	10
	JC	ISNUM
	ADI	7
;
ISNUM	ADI	'0'		;add in ASCII bias
	JMP	CTYPE
;
; Displays the control-characters shown in the menu
;
SHFTYPE	PUSH	PSW
	CALL	ILPRT
	DB	'CTL-',0
	POP	PSW
	ADI	40H		;convert binary to ASCII chars.
	CALL	TYPE		;show on the CRT
	JMP	ILPRT
;
; Write a string of characters to the CRT
;
ILPRT	XTHL
;
ILPRT1	MOV	A,M		;get the character
	ORA	A		;see if a "0" for end of string
	JZ	ILPRT2		;if yes, all done
	CALL	CTYPE		;show on CRT
	INX	H		;get the next location in the string
	JMP	ILPRT1
;
ILPRT2	XTHL			;restore the address
	RET
;
; Write a string of characters unless in the Quiet mode
;
ILPRTQ	XTHL
;
ILPRTQ1	MOV	A,M		;get the character
	ORA	A		;see if a "0" for end of string
	JZ	ILPRTQ2		;if yes, all done
	LDA	QFLG
	ORA	A
	MOV	A,M
	CNZ	CTYPE		;show on CRT if not in quiet mode
	INX	H		;get the next location in the string
	JMP	ILPRTQ1
;
ILPRTQ2	XTHL			;restore the address
	RET
;
PRTMSG	MVI	C,PRINT		;print the string
	JMP	BDOS
;
; Displays error statement then resturns to command mode
;
ERXIT	POP	D
	CALL	PRTMSG
	MVI	A,BELL
	CALL	TYPE
	CALL	CRLF
;
ERXIT1	MVI	A,1
	STA	ABTFLG		;shows an unintentional abort
	LDA	BCHFLG		;in batch mode?
	ORA	A
	JNZ	DONETB		;if not, exit
	JMP	ABORT		;abort other computer
;
; Exits directly to CP/M, with no reboot unless you have selected pos-
; sible overwriting of 'CCP'
;
EXIT	LDA	OLDUSER		;get original user number back
	MOV	E,A
	CALL	STUSER
	MVI	C,STDMA
	LXI	D,TBUF		;restore original buffer area
	CALL	BDOS
	LXI	B,1A00H		;a little delay timer
;
EXIT1	DCX	B		;one less loop to make
	MOV	A,B
	ORA	C
	JNZ	EXIT1		;loop again till both are zero
	CALL	CKCON		;catch any extra keyboard characters
	LDA	NFILFLG		;saving for a disk file?
	ORA	A
	CNZ	WRFIL1		;if yes, close the file
	LDA	SAVCCP		;was 'CCP' left intact?
	ORA	A
	JZ	0000H		;if not, warm reboot just in case
;
EXIT2	XRA	A		;clear the 'A' reg. and all flags
	LHLD	STACK		;get the original stack pointer back
	SPHL			;set the stack pointer to that address
	RET
;
; Catch any extra keyboard characters coming through BDOS
;
CKCON	MVI	C,CONST		;see if any characters waiting
	CALL	BDOS
	ORA	A
	RZ			;if not, exit
	MVI	C,RDCON		;otherwise get the character
	CALL	BDOS
	XRA	A		;discard the character
	JMP	CKCON		;see if any others
;
MOVE128	MVI	B,128
;
MOVE	MOV	A,M
	STAX	D
	INX	H
	INX	D
	DCR	B
	JNZ	MOVE
	RET
;
; Sends the character in 'A' to the modem
;
SNDCHR	CALL	SNDNOW		;wait until modem is ready for character
	MOV	A,B		;get the original character back
	JMP	O$MDDATP	;send the character to modem, return
;
; Initializes CP/M file control blocks AT 5CH and 6CH
;
STFCB	LXI	D,CMDBUF
	LXI	H,FCB
	JMP	CMDLINE
;
; Adjusts loop counter for the selected clock speed.  Returns with delay
; in 'HL'.
;
FIXCNT	LDA	CLOCK		;get the user's clock speed
	PUSH	D		;save the current 'DE' value
	PUSH	H
	POP	D		;get same value into 'DE' as in 'HL'
;
CNTMUL	DAD	D		;add 'DE' to 'HL'
	DCR	A		;one less to go
	JNZ	CNTMUL
	POP	D		;restore current 'DE', delay in 'HL'
	RET
;
;=======================================================================
;
; Loads a command line addressed by 'DE' registers (max # characters in
; line in 'DE', number of characters in line in DE+1, line starts in
; DE+2) into FCB addressed by 'HL' registers.  The FCB should be at least
; 33 bytes in length.  The command line buffer must have a maximum length
; at least one more than the greatest number of characters that will be
; needed.
CMDLINE	PUSH	PSW
	PUSH	B
	PUSH	D
	PUSH	H
	CALL	INITIAL		;fills FCBs with blanks and nulls
	XCHG			;get start of command line in HL
	INX	H		;address # bytes in cmd line
	MOV	E,M		;load de pair with # bytes
	MVI	D,0
	INX	H
	DAD	D		;point to byte after last character
	MVI	M,CR		;  in cmd line and store delimiter
	POP	H		;restore HL and DE
	POP	D
	PUSH	D
	PUSH	H
	INX	D		;address start of command
	INX	D
	CALL	DRIVE
;
NAME1	MVI	C,8		;transfer first filename to FCB
	CALL	TRANS
	CPI	CR
	JZ	DONEL
	CPI	' '		;if space, then start of
	JZ	NAME2		;  second filename
	POP	H		;filetype must be after
	PUSH	H		;  eighth byte of name
	LXI	B,9
	DAD	B
	MVI	C,3		;transfer type of first file
	CALL	TRANS
	CPI	CR
	JZ	DONEL
;
NAME2	LDAX	D		;eat multiple spaces
	CPI	' '		;  between names
	JNZ	NAME3
	INX	D
	JMP	NAME2
;
NAME3	POP	H		;second name starts in 16th byte
	PUSH	H		;point HL to this byte
	LXI	B,16
	DAD	B
	CALL	DRIVE
	MVI	C,8
	CALL	TRANS
	CPI	CR
	JZ	DONEL
	POP	H		;second type starts in 25th byte
	PUSH	H
	LXI	B,25
	DAD	B
	MVI	C,3
	CALL	TRANS
;
DONEL	POP	H
	PUSH	H
	INX	H		;point to 1st char of 1st name in FCB
	CALL	SCANL		;check for * (ambiguous names)
	POP	H
	PUSH	H
	LXI	B,17		;  to 1st char of second name in FCB
	DAD	B
	CALL	SCANL
	POP	H
	POP	D
	POP	B
	POP	PSW
	RET
;
; Subroutines for CMDLINE section
;
INITIAL	PUSH	H
	PUSH	B
	MVI	M,0
	INX	H
	MVI	B,11
	MVI	A,' '
	CALL	INITFIL
	MVI	B,5
	XRA	A
	CALL	INITFIL
	MVI	B,11
	MVI	A,' '
	CALL	INITFIL
	MVI	B,4
	XRA	A
	CALL	INITFIL
	POP	B
	POP	H
	RET
;
INITFIL	MOV	M,A
	INX	H
	DCR	B
	JNZ	INITFIL
	RET
;
DRIVE	INX	D		;check 2nd byte of filename - if it
	LDAX	D		;  is a ":", then drive was specified
	DCX	D
	CPI	':'
	JNZ	DEFDR		;else zero for default drive
	LDAX	D		;('INIT' put zero)
	ANI	5FH
	SUI	40H		;calculate drive (A=1, B=2,...)
	MOV	M,A		;place it in FCB.
	INX	D		;address first byte
	INX	D
;
DEFDR	INX	H		;name field in FCB
	RET
;
TRANS	LDAX	D		;transfer from command line to FCB
	INX	D		;up to number of characters specified
	CPI	CR		;in 'C' reg. keep scanning field
	RZ			;  without transfer until a delimiting
	CPI	'.'		;  field char such as '.', blank, or
	RZ			;  CR (for end of commmand line)
	CPI	' '
	RZ
	DCR	C
	JM	TRANS		;once C-reg is less than zero, keep
	MOV	M,A		;  reading command line but do not
	INX	H		;  transfer to FCB
	JMP	TRANS
;
SCANL	MVI	B,8		;scan file name addressed by HL
;
TSTNAM	MOV	A,M
	CPI	'*'		;if '*' found, fill in rest of field
	JZ	FILL1		;  with '?' for ambiguous name
	INX	H
	DCR	B
	JNZ	TSTNAM
	JMP	TSTTYP
;
FILL1	CALL	FILL
;
TSTTYP	MVI	B,3		;scan and fill type field for name
;
TSTTYPL	MOV	A,M		;  specified above
	CPI	'*'
	JZ	FILL2
	INX	H
	DCR	B
	JNZ	TSTTYPL
	RET
;
FILL2	CALL	FILL
	RET
;
FILL	MVI	M,'?'		;routine transfers '?'
	INX	H
	DCR	B
	JNZ	FILL
	RET
;
;=======================================================================
; LISTS DIRECTORY AND GIVES FREE SPACE REMAINING ON THE REQUESTED DRIVE.
;
; Disk system reset - currently bypassed, if you wish this feature, put
;	JMP DRLST2 instead of JMP DRLST3 in the eighth line.  The
;	current disk (plus the A: drive) will then reset each DIR re-
;	quest.	You can also reset the disk with the LOG command when
;	when inserting a different one.  This saves a reset each time
;	DIR might be requested.
;
DRLST	CALL	GETDISK
	ADI	'A'		;change to ASCII
	STA	DRNAME		;show for drive name
	STA	ACTDRV		;show for space remaining on drive
;
DRLST1	JMP	DRLST3
;
DRLST2	MVI	C,RESET		;13 reset disk system (RESETDK)
	CALL	BDOS
;
; Directory list routine
;
DRLST3	LXI	D,CMDBUF	;put command line in FCB
	LXI	H,FCB		;  addressed by HL-reg
	CALL	CMDLINE		;  and then
	LXI	H,FCB4
	CALL	INITFCB
	LDA	FCB2		;get drive number
	STA	FCB4
	LDA	FCB2+1
	CPI	' '		;if a space (blank) get all names
	PUSH	PSW
	CZ	QSTMARK
	POP	PSW
	CNZ	MOVNAME		;else move name into FCB
	CALL	DRIVEL
	MVI	C,STDMA
	LXI	D,TBUF
	CALL	BDOS
	LDA	NOFCOL		;number of columns into 'A' reg.
	STA	NAMECT		;CRLF after 'NOFCOL' number of columns
	LXI	D,FCB4
	MVI	C,SRCHF		;do first search
	CALL	BDOS
	INR	A		;0FFH --> 0 if no file(s) found
	JNZ	DIRLOOP
	CALL	ILPRT
	DB	'++ FILE NOT FOUND ++',0
	JMP	STORAGE		;still show storage on default drive
;
DIRLOOP	CALL	GETADD
	INX	H		;point to first letter of filename
	LXI	D,PRTNAME
	LXI	B,8
	CALL	MOVER
	INX	D
	LXI	B,3
	CALL	MOVER
	CALL	ILPRT
;
PRTNAME	DB	'        ','.','   ',0	; 8 spaces, period, 3 spaces
;
NEXTSR	LXI	D,FCB4
	MVI	C,SRCHN		;do next search
	CALL	BDOS
	INR	A		;if 0FFH --> 0 then
	JZ	STORAGE		;  directory-read finished
	PUSH	PSW
	PUSH	D
	PUSH	H
	LDA	NAMECT
	DCR	A
	STA	NAMECT		;name count updated
	ORA	A
	CZ	CRLF		;terminate line of file names
	JNZ	FENCE
	LDA	NOFCOL		;restart columns-per-line count
	STA	NAMECT
	JMP	NOFENCE		;fence not needed
;
FENCE	CALL	ILPRT
	DB	' : ',0		;fence if not at end of line or
;				;  LAST FILENAME
NOFENCE	POP	H
	POP	D
	POP	PSW
	JMP	DIRLOOP
;
; Determine storage remaining on default drive
;
STORAGE	CALL	CKCPM3
	MVI	C,DSKPAR	;current disk parameter block
	CALL	BDOS
	INX	H
	INX	H
	MOV	A,M		;get block shift factor
	STA	BSHIFTF
	INX	H		;bump to block mask
	MOV	A,M		;get it
	STA	BMASK
	INX	H
	INX	H
	MOV	E,M		;get max block number
	INX	H
	MOV	D,M
	XCHG
	SHLD	BMAX		;put it away
	MVI	C,DSKALL	;address of cp/m allocation vector
	CALL	BDOS
	XCHG			;get its length
	LHLD	BMAX
	INX	H
	LXI	B,0		;initialize block count to zero
;
GSPBYT	PUSH	D		;save allocation address
	LDAX	D
	MVI	E,8		;set to process 8 blocks
;
GSPLUP	RAL			;test bit
	JC	NOTFRE
	INX	B
;
NOTFRE	MOV	D,A		;save bits
	DCX	H
	MOV	A,L
	ORA	H
	JZ	ENDALC		;quit if out of blocks
	MOV	A,D		;restore bits
	DCR	E		;count down 8 bits
	JNZ	GSPLUP		;do another bit
	POP	D		;bump to next count
	INX	D		; of allocation vector
	JMP	GSPBYT		;process it
;
ENDALC	POP	D		;clear alloc vector pointer from stack
	MOV	L,C		;copy block to HL
	MOV	H,B
	LDA	BSHIFTF		;get block shift factor
	SUI	3		;convert from records to thousands (k)
	JZ	PRTFREE		;skip shifts if 1k blocks
;
FREKLP	DAD	H		;multiply blocks by k per block
	DCR	A
	JNZ	FREKLP
;
PRTFREE	CALL	DECOUT		;(# of free k bytes now in 'HL')
	LXI	D,FREEMSG
	JMP	PRTMSG
;
; Subroutines for 'DRLST' section
;
QSTMARK	MVI	A,'?'		;if blank in FCB, put in 11 '?' chars.
	MVI	B,11
	LXI	H,FCB4+1
;
QSTLP	MOV	M,A
	INX	H
	DCR	B
	JNZ	QSTLP
	RET
;
MOVNAME	LXI	H,FCB2+1
	LXI	D,FCB4+1
	LXI	B,11
	CALL	MOVER
	RET
;
GETADD	DCR	A		;un-do the INR above
	ADD	A		;times 32
	ADD	A
	ADD	A
	ADD	A
	ADD	A
	ADI	TBUF		;add buffer offset
	MOV	L,A
	MVI	H,0
	RET
;
DRIVEL	LDA	FCB4		;if no drive, use
	ORA	A		;  default drive in DRNAME
	JZ	PRNTHD
	PUSH	PSW
	DCR	A
	MOV	E,A
	MVI	C,SELDSK
	CALL	BDOS
	POP	PSW
	ADI	40H		;make 1=A, 2=B, etc., and
	STA	DRNAME		; overwrite default stored below
	STA	ACTDRV
;
PRNTHD	CALL	ILPRT
	DB	'Drive '
;
DRNAME	DB	' :',CR,LF,0
	RET
;
; Initialized storage
;
FREEMSG	DB	'k bytes free on drive '
ACTDRV	DB	' :',CR,LF,'$'
;
; Uninitialized storage
;
BMAX	DS	2		;highest block number on drive
BMASK	DS	1		;rec/blk - 1
BSHIFTF	DS	1		;number of shifts to multiply by rec/blk
;
;=======================================================================
;
; Duplicates 'READ BUFFER' routine same as CP/M function 10, but does
; not use CTL-C (reason for the routine).  Does allow controls U, R, E
; and H (BACKSPACE).  Outputs bell if the input is greater than the
; buffer.
;
INBUF	PUSH	PSW
	PUSH	H
	PUSH	B
	PUSH	D		;'DE' registers must be pushed last
;
INBUFA	CALL	CLRBUF		;clear the buffer area
	POP	D		;get address of buffer on retries
	PUSH	D		;restore stack
	XRA	A
	INX	D		;address count field
	STAX	D		;initialize with a zero in count byte
	INX	D
	XCHG			;address first buffer byte with 'HL'
;
INBUFB	CALL	KEYIN		;(waits for char)
	CALL	UCASE		;convert to upper case if needed
	CPI	CR		;is it <return> (enter command)?
	JZ	INBUFR		;if so, then return.
	CPI	08H		;CTL-H backspaces over deleted character
	JZ	DELETE
	CPI	7FH		;is it a delete?
	JZ	DELETE
	CPI	'U'-40H		;is it a CTL-U?
	JZ	INBUFO		;output #, CR, LF, and start over
	CPI	'R'-40H		;CTL-R retypes line
	JZ	RETYPE
;
INBUFC	MOV	B,A		;save inputted character
	XCHG			;save 'HL' in 'DE'
	POP	H		;get address of buffer in 'HL'
	PUSH	H		;restore stack
	INX	H		;address count byte
	INR	M		;increase count byte
	DCX	H		;address maximum
	MOV	A,M		;put maximum in 'A'
	INX	H		;address count
	CMP	M		;compare count to maximum
	JC	ALERTL		;if maximum, ring bell and wait for cr.
	XCHG			;restore buffer pointer to 'HL'
	MOV	M,B		;put inputted character in buffer
	MOV	A,B		;output it
	CPI	EXITCHR		;exit character?
	JZ	INBUFR		;if yes, all done
	CPI	20H		;printing character?
	CNC	TYPE		;if yes, print it
	INX	H		;bump pointer
	JMP	INBUFB		;get next character
;
DELETE	XCHG			;save buffer pointer in 'DE'
	POP	H		;address beginning of buffer
	PUSH	H		;restore stack
	INX	H		;address count field
	MOV	A,M
	SUI	1		;decrease count
	MOV	M,A
	JC	NODEL		;don't delete past beginning of buffer
	XCHG			;restore buffer pointer to 'HL'
	DCX	H		;point to last byte inputted
	MOV	A,M		;get the character being deleted
	MVI	M,' '		;restore blank
	CPI	' '		;see if a non-printing character
	JC	INBUFB		;if yes, skip the CRT backup
	MVI	A,BKSP
	CALL	TYPE		;true erase if 08H
	MVI	A,' '
	CALL	TYPE
	MVI	A,BKSP
	CALL	TYPE
	JMP	INBUFB
;
MORE	DB	'12345'		;5 bytes extra from DELETE routine fix
;
NODEL	INR	M		;do not leave count negative
	XCHG			;restore pointer to 'HL'
	MVI	A,BELL		;says can go no further
	CALL	TYPE
	JMP	INBUFB
;
INBUFO	MVI	A,'#'		;announces the line has been removed
	CALL	TYPE
	CALL	CRLF
	JMP	INBUFA
;
RETYPE	POP	D
	PUSH	D
	INX	D		;point to current number of characters
	LDAX	D
	MOV	B,A
	MVI	A,'#'
	CALL	TYPE
	CALL	CRLF
	MOV	A,B		;test if zero input
	ORA	A
	JZ	INBUFB
;
CTLRLP	INX	D
	LDAX	D
	CALL	TYPE
	DCR	B
	JNZ	CTLRLP
	JMP	INBUFB
;
ALERTL	MVI	A,BELL		;alarm for full buffer
	CALL	TYPE
	DCR	M
	XCHG
	JMP	INBUFB
;
PCRLF	CALL	CRLF
	JMP	INBUFB
;
INBUFR	CALL	CRLF		;1st new line after a command character
	POP	D
	POP	B
	POP	H
	POP	PSW
	RET
;
CLRBUF	POP	D		;accounts for call
	POP	H		;restore the registers
	PUSH	H
	PUSH	D
	MOV	B,M		;save maximum in 'B'
	INX	H		;point to first buffer byte
	INX	H
	MVI	A,' '
;
CLEARL	MOV	M,A
	INX	H
	DCR	B
	JNZ	CLEARL
	RET
;
;=======================================================================
;
; In-line compare.  Compares string addressed by 'DE' to string after
; call (ends with zero).  Return with carry set means strings not the
; same.  All registers except 'A'-reg are unaffected.
;
INLNCP	XTHL			;point 'HL' to 1st character
	PUSH	D
;
ILCOMPL	MOV	A,M		;'HL' points to in-line string
	ORA	A		;end of string if zero
	JZ	SAME
	LDAX	D
	CMP	M
	JNZ	NOTSAME
	INX	H
	INX	D
	JMP	ILCOMPL
;
NOTSAME	XRA	A		;if not same, finish through
;
NSLP	INX	H		;  string so return will
	CMP	M		;  go to instruction after
	JNZ	NSLP		;  string and not remainder of string
	STC
;
SAME	POP	D
	INX	H		;avoids a NOP instruction
	XTHL			;  when returning
	RET
;
;=======================================================================
;		  MULTI-FILE ACCESS ROUTINE
;
; Multi-file access subroutine.  Allows processing of multiple files
; (i.e., *.ASM) from disk.  Builds the correct name in the FCB each time
; it is called.  The command is used in programs to process single or
; multiple files.  The FCB is set up with the next name, ready to do
; normal processing (open, read, etc.) when routine is called.	Carry is
; set if no more names are found.
MFNAM	PUSH	B
	PUSH	D
	PUSH	H
	MVI	C,STDMA
	LXI	D,TBUF
	CALL	BDOS
	POP	H
	POP	D
	POP	B
	XRA	A
	STA	FCBEXT
	LDA	MFFLG1
	ORA	A
	JNZ	MFNAM1
	MVI	A,1
	STA	MFFLG1
	LXI	H,FCB
	LXI	D,MFNAM5
	LXI	B,12
	CALL	MOVER
	LDA	FCB
	STA	MFNAM6		;save disk in current FCB
	LXI	H,MFNAM5
	LXI	D,FCB
	LXI	B,12
	CALL	MOVER
	PUSH	B
	PUSH	D
	PUSH	H
	MVI	C,SRCHF
	LXI	D,FCB
	CALL	BDOS
	POP	H
	POP	D
	POP	B
	JMP	MFNAM2
;
MFNAM1	LXI	H,MFNAM6
	LXI	D,FCB
	LXI	B,12
	CALL	MOVER
	PUSH	B
	PUSH	D
	PUSH	H
	MVI	C,SRCHF
	LXI	D,FCB
	CALL	BDOS
	POP	H
	POP	D
	POP	B
	LXI	H,MFNAM5
	LXI	D,FCB
	LXI	B,12
	CALL	MOVER
	PUSH	B
	PUSH	D
	PUSH	H
	MVI	C,SRCHN
	LXI	D,FCB
	CALL	BDOS
	POP	H
	POP	D
	POP	B
;
MFNAM2	INR	A
	STC
	JNZ	MFNAM3
	STA	MFFLG1
	RET
;
MFNAM3	DCR	A
	ANI	3
	ADD	A
	ADD	A
	ADD	A
	ADD	A
	ADD	A
	ADI	81H
	MOV	L,A
	MVI	H,0
	PUSH	H		;save name pointer
	LXI	D,MFNAM6+1
	LXI	B,11
	CALL	MOVER
	POP	H
	LXI	D,FCB+1
	LXI	B,11
	CALL	MOVER
	XRA	A
	STA	FCBEXT
	STA	FCBRNO
	RET
;
MOVER	MVI	A,2
	INR	A
	JPE	MFNAM4
	DB	0EDH,0B0H	;Z-80 'LDIR' instruction
	RET
;
MFNAM4	MOV	A,M		;used if an 8080 CPU is active
	STAX	D
	INX	H
	INX	D
	DCX	B
	MOV	A,B
	ORA	C
	JNZ	MFNAM4
	RET
;
;=======================================================================
;		 CALCULATE FILE TRANSFER TIME
; Shows the time to transfer a file at various baud rates.  (110-19200)
;
SNDTM	CALL	ILPRT
	DB	'File open: ',0
	LHLD	RCNT		;get record count
	CALL	DECOUT		;print decimal number of records
;
	LDA	HEXSHO
	ORA	A
	JZ	SNDTM1
	CALL	ILPRT
	DB	' (',0
	CALL	DHXOUT		;now print size in hex
	CALL	ILPRT
	DB	'H)',0
;
SNDTM1	CALL	ILPRT
	DB	' records'
	DB	CR,LF,'Send time: ',0
	LDA	MSPEED		;get the speed indicator
	MVI	D,0
	MOV	E,A		;set up for table access
	LXI	H,BTABLE	;point to baud factor table
	DAD	D		;index to proper factor
	DAD	D		;factor in 'DE'
	MOV	E,M
	INX	H
	MOV	D,M
	LHLD	RCNT		;get # of records
	CALL	DVHLDE		;divide HL by value in DE (records/min)
	PUSH	H
	MOV	L,C
	MOV	H,B
	CALL	DECOUT		;print the minutes portion
	CALL	ILPRT
	DB	' mins, ',0
	LXI	H,RECDBL	;point to divisors for seconds
	LXI	D,0		;   calculation
	LDA	MSPEED		;get index for baud rate
	MOV	E,A
	DAD	D		;index into table
	MOV	A,M		;get multiplier
	POP	H		;get remainder
	CALL	MULHLA		;multiply the 'HL' x 'A'
	CALL	SHFTHL
	CALL	SHFTHL
	CALL	SHFTHL
	CALL	SHFTHL
	MVI	H,0
	CALL	DECOUT		;print the seconds portion
	CALL	ILPRT
	DB	' secs at ',0
	CALL	PRTBAUD
	CALL	ILPRTQ
	DB	'To cancel: use CTL-X',CR,LF,0
	RET
;
BTABLE	DW	5,13,20,26,29,48,85,152,280,480,0	;records/min for..
RECDBL	DB	192,74,48,37,33,20,11,6,3,2,0		;110-19200 baud
;
; Shows baud rates set for 'time to send' file transfer
;
PRTBAUD	LXI	H,BAUDSPD
	MVI	D,0
	LDA	MSPEED		;get baud rate code
	MOV	E,A		;x1
	ADD	A		;x2
	ADD	A		;x4
	ADD	E		;x5
	ADD	E
	MOV	E,A
	DAD	D		;point to correct rate
	XCHG
	MVI	C,PRINT
	CALL	BDOS
	CALL	ILPRT
	DB	' bps ',CR,LF,0
	RET
;
BAUDSPD	DB	'110$',0,0,'300$',0,0,'450$',0,0,'600$',0,0,'710$',0,0
	DB	'1200$',0,'2400$',0,'4800$',0,'9600$',0,'19200$'
;
;---->	DVHLDE: Divides 'HL' by value in 'DE',
;	Upon exit: 'BC'=quotient,'L'=remainder
;
DVHLDE	PUSH	D		;save divisor
	MOV	A,E
	CMA			;negate divisor
	MOV	E,A
	MOV	A,D
	CMA
	MOV	D,A
	INX	D		;'DE' is now two's complemented
	LXI	B,0		;init quotient
;
DIVL1	DAD	D		;subtract divisor from dividend
	INX	B		;bump quotient
	JC	DIVL1		;loop till sign changes
	DCX	B		;adjust quotient
	POP	D		;retrieve divisor
	DAD	D		;adjust remainder
	RET
;
;---->	MULHLA:  Multiply the value in 'HL' by the value in 'A'
;		 Return with answer in 'HL'
;
MULHLA	XCHG			;multiplicand to 'DE'
	LXI	H,0		;init product
	INR	A		;adjust multiplier for zero test
;
MULLP	DCR	A
	RZ
	DAD	D
	JMP	MULLP
;
; Shift 'HL' register pair one bit to the right
;
SHFTHL	MOV	A,L
	RAR
	MOV	L,A
	ORA	A		;clear the carry
	MOV	A,H
	RAR
	MOV	H,A
	RNC
	MVI	A,128
	ORA	L
	MOV	L,A
	RET
;
;=======================================================================
;			 CRC SUBROUTINES
;
; Check 'CRC' bytes of record just received
;
CRCCHK	PUSH	H
	LHLD	CRCVAL
	MOV	A,H
	ORA	L
	POP	H
	RZ
	MVI	A,0FFH
	RET
;
; Generate the CRC tables for fast calculations
;
CRCGN	LXI	H,CRCTBL	;address at start of 'CRC' lookup table
	MVI	C,0
;
CRCGN1	XCHG			;store table location into 'DE'
	LXI	H,0		;clear 'HL' pair
	MOV	A,C
	PUSH	B
	MVI	B,8
	XRA	H
	MOV	H,A
;
CRCGN2	DAD	H		;index into the table
	JNC	CRCGN3
	MVI	A,16		;using x^ 16 + x^12 + x^5 + 1 algorithm
	XRA	H		;(called 'SDLC' networking algorithm)
	MOV	H,A
	MVI	A,32+1
	XRA	L
	MOV	L,A
;
CRCGN3	DCR	B
	JNZ	CRCGN2		;make 8 loops, one for each bit
;
; Value now in 'HL', table address still stored in 'DE'.  Exchange, and
; store the 'CRC' value in the two tables after splitting.
;
	POP	B		;finished borrowing the 'B' register
	XCHG			;address back in 'HL', 'CRC' in 'DE'
	MOV	M,D		;store 1st part of 'CRC' value
	INR	H		;move up 256 bytes
	MOV	M,E		;store 2nd part of 'CRC' value
	DCR	H		;move back 256 bytes
	INX	H		;increment to next location
	INR	C		;done when 'C' reg. turns zero again
	JNZ	CRCGN1		;now go do the next location
	RET
;
; Update the CRC value from a character in the 'A' register
;
CRCUPD	PUSH	PSW		;save all registers just in case
	PUSH	B
	PUSH	D
	PUSH	H
	LHLD	CRCVAL		;get current value
	XCHG			;put in 'DE' for now
	MVI	B,0
	XRA	D
	MOV	C,A		;now have the character in 'BC' pair
	LXI	H,CRCTBL	;start of 'CRC' lookup-table
	DAD	B		;index into the 'CRC' table
	MOV	A,M		;get the value from the table
	XRA	E
	MOV	D,A
	INR	H		;move 256 bytes for 2nd table location
	MOV	E,M		;put value there into 'E' register
	XCHG			;put 'DE' into 'HL'
	SHLD	CRCVAL		;updated 'CRC' value with this character
	POP	H		;restore all registers
	POP	D
	POP	B
	POP	PSW
	RET
;
;=========================START OF MENU ================================
;
MENU0	LDA	NFILFLG
	ORA	A
	JZ	MENU		;exit if not saving memory for disk file
	CALL	ILPRT		;else print message
	DB	CR,LF,'** File still open, use DEL, DIR, WRT, E, L '
	DB	'or T ** ',CR,LF,BELL,0
	JMP	MENU1
;
MENU	XRA	A
	STA	ABTFLG		;null the flag
;
MENU1	LXI	H,RESTSN	;restore record numbers for new file
	LXI	D,RECNOB	;  transfer
	MVI	B,RECNOE-RECNOB
	CALL	MOVE
	LXI	H,RSTOPT	;restore option table
	LXI	D,OPTBL
	MVI	B,OPTBE-OPTBL
	CALL	MOVE
	XRA	A
	STA	FSTFLG
	STA	TIMFLG
	STA	FLTRFLG		;reset multi-file trans
	STA	MFFLG1
	JMP	XPRT
;
; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;		       MENU OF COMMANDS
; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;
MENU2	CALL	CLRTST
	CALL	ILPRT
	DB	'                  Single Letter Commands',CR,LF,LF
	DB	' ?  - Display current settings',CR,LF
MENU3	DB	' ^  - Function key intercept character, '
	DB	'then (0-9)',CR,LF
	DB	' M  - Display the menu',CR,LF
	DB	' E  - Terminal mode with echo',CR,LF
	DB	' L  - Terminal mode with local echo',CR,LF
	DB	' T  - Terminal mode',CR,LF
	DB	'         For copying text to disk use T (E or L) '
	DB	'FILENAME.TYP',CR,LF
	DB	'         Start or Stop toggles described on subsequent'
	DB	' screen.',CR,LF
	DB	' R  - Receive CP/M file using Christensen Protocol'
	DB	CR,LF
	DB	' S  - Send CP/M file using Christensen Protocol',CR,LF
	DB	'         COMMAND: R (or S) FILENAME.TYP',CR,LF
	DB	'         R and S can use the following subcommands:'
	DB	CR,LF
	DB	'            B  - Bulk transfer using wildcards '
	DB	'(e.g., *.*)',CR,LF
	DB	'            D  - Disconnect when done'
	DB	CR,LF
	DB	'            Q  - Quiet mode (no messages to console)'
	DB	CR,LF
	DB	'            V  - View <R> or <S> bytes on console'
	DB	CR,LF
	DB	'            X  - When done, disconnect, go to CP/M'
	DB	CR,LF,LF
	DB	'      The single letter commands may also be used on '
	DB	'the',CR,LF
	DB	'      command line when the program is initially '
	DB	'executed.',CR,LF,LF,0
;
THRLTR	CALL	J$NXTSCR
	CALL	ILPRT
	DB	'                Three Letter Commands',CR,LF,LF
	DB	'CPM - Exit from this program to CP/M',CR,LF
	DB	'DIR - List directory and space free (may specify '
	DB	'drive)',CR,LF
	DB	'ERA - Erase file (may specify drive)',CR,LF
	DB	'LOG - Change default drive/user no. (specify '
	DB	'drive/user)',CR,LF
	DB	'      and reset disks.  e.g. LOG A0: or LOG B:  '
	DB	'(user # unchanged)',CR,LF
	DB	'SPD - Set file output speed in terminal mode'
	DB	CR,LF,0
;
	CALL	SORPTST
	JNZ	NOTIME
	CALL	ILPRT
	DB	'TIM - Select Baud rate for "time-to-send" msg.',CR,LF,0
;
NOTIME	LDA	TGLECRC
	ORA	A
	JZ	NOTOCRC
	CALL	ILPRT
	DB	'TCC - Toggle CRC/Checksum mode on receive',CR,LF,0
;
NOTOCRC	LDA	TGLELOC
	ORA	A
	JZ	NTOGOC
	CALL	ILPRT
	DB	'TLC - Toggle local command immediate or after ',0
	LDA	EXTCHR
	CALL	SHFTYPE
	DB	CR,LF,0
;
NTOGOC	LDA	TGLELF
	ORA	A
	JZ	NTOGUB
	CALL	ILPRT
	DB	'TLF - Toggle LF after CR in "L" or "T" mode for '
	DB	'a disk file',CR,LF,0
;
NTOGUB	LDA	TGLERUB
	ORA	A
	JZ	NTOGF
	CALL	ILPRT
	DB	'TRB - Toggle rubout to backspace conversion',CR,LF,0
;
NTOGF	LDA	TGXOFF
	ORA	A
	JZ	NTOGOF
	CALL	ILPRT
	DB	'TXO - Toggle XOFF testing in terminal mode '
	DB	'file output',CR,LF,0
;
NTOGOF	LDA	PMMIMD		;using a PMMI modem?
	ORA	A
	JNZ	NONUM
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JNZ	NTOG2
;
NTOG1	CALL	ILPRT
	DB	'NUM - List remote systems',CR,LF,0
;
NTOG2	LDA	STUPTST
	ORA	A
	JZ	NONUM
	CALL	ILPRT
	DB	'SET - Set modem baud rate',CR,LF,0
;
NONUM	CALL	ILPRT
	DB	'BYE - Disconnect, then return to CP/M'
	DB	CR,LF,0
	LDA	PMMIMD		;using a PMMI modem?
	ORA	A
	JNZ	NONUM0		;if yes, display 'CAL'
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JZ	NOPMMI		;exit if neither
;
NONUM0	CALL	ILPRT
	DB	'CAL - Dial number',CR,LF,0
;
NOPMMI	CALL	ILPRT
	DB	'DSC - Disconnect from the phone line',CR,LF,LF
	DB	'          The following are terminal text '
	DB	'buffer commands:',CR,LF,LF,0
;
SKPLF	CALL	ILPRT
	DB	'DEL - Delete memory buffer and file',CR,LF
	DB	'WRT - Write memory buffer to disk file',CR,LF,LF,0
	CALL	NXTSCR
	CALL	ILPRT
	DB	'        Local Commands while in Terminal Mode'
	DB	CR,LF,LF,0
	LDA	BRKCHR
	CALL	SHFTYPE
	DB	'  - Send a break tone for 300 ms.',CR,LF,0
	LDA	PMMIMD
	ORA	A
	JZ	SKPLF1
	LDA	CHGBAUD
	CALL	SHFTYPE
	DB	'  - Change baud rate',CR,LF,0
;
SKPLF1	MVI	A,EXITCHR
	CALL	SHFTYPE
	DB	'  - Exit to command mode',CR,LF,0
	LDA	TRANLOG
	ORA	A
	JZ	NOTLOG
	LDA	LOGCHR
	CALL	SHFTYPE
	DB	'  - Send log-on message',CR,LF,0
;
NOTLOG	LDA	NOCONCT
	CALL	SHFTYPE
	DB	'  - Disconnect from the phone line',CR,LF,0
	LDA	LSTTST
	ORA	A
	JZ	NOLIS
	LDA	LSTCHR
	CALL	SHFTYPE
	DB	'  - Toggle printer',CR,LF,0
;
NOLIS	MVI	A,LF
	CALL	TYPE
	LDA	SAVECHR
	CALL	SHFTYPE
	DB	'  - Start copy into buffer',CR,LF,0
	LDA	UNSAVCH
	CALL	SHFTYPE
	DB	'  - Stop copy into buffer',CR,LF,LF
	DB	'             Start & Stop may be toggled as often as '
	DB	'desired.',CR,LF
	DB	'             A ";" at start of line indicates buffer '
	DB	'is copying.',CR,LF
	DB	'             XOFF automatically used to stop input '
	DB	'when writing',CR,LF
	DB	'                full buffer to disk, XON sent to '
	DB	'resume.',CR,LF,LF,0
	LDA	TRANCHR
	CALL	SHFTYPE
	DB	'  - Transfer ASCII file to remote',CR,LF,LF,0
	LDA	LOCNXT
	ORA	A
	LDA	EXTCHR
	JNZ	REMDFLT
	CALL	SHFTYPE
	DB	'  - Send local control character to remote'
	DB	CR,LF,LF,0
	JMP	CKSPCL
;
REMDFLT	CALL	SHFTYPE
	DB	'  - Next character will be used for local control'
	DB	CR,LF,0
;
CKSPCL	CALL	J$SPMEN		;may have a special menu in the overlay
;				;FALLS ON THROUGH TO 'XPRT'
;
;=======================================================================
;		    START OF COMMAND LINE HANDLING
;
; Check first to see if a file was opened for copying incoming to disk
;
XPRT	CALL	CRLF		;turn up a blank line to look nice
	LDA	NFILFLG		;have a file open for text mode copy?
	ORA	A
	JZ	XPRT1		;if not, exit
;
	CALL	GETSPC		;otherwise show remaining space
	CALL	ILPRT
	DB	' Bytes of buffer free',CR,LF,LF,0
;
; Show disk drive and user number, then command line
;
XPRT1	MVI	C,CURDSK	;current disk function
	CALL	BDOS
	ADI	'A'		;make ASCII
	CALL	TYPE
	CALL	GETUSER		;get current user number
	ORA	A
	JZ	XPRT2		;skip if user 0
	MVI	H,0
	MOV	L,A
	CALL	DECOUT		;show current user area
;
XPRT2	MVI	A,'>'
	CALL	TYPE
	MVI	A,'>'
	CALL	TYPE
	CALL	ILPRT
	DB	'COMMAND: ',0
	XRA	A
	STA	XFLG		;null the buffer-length flag
;
; Get the command line parameters
;
GTCMD	LXI	D,CMDBUF	;enter command
	CALL	INBUF
	LDA	CMDBUF+2
	CPI	EXITCHR		;exit character
	JZ	XPRT1
;
GTCMD1	CPI	'^'		;function key intercept character
	JZ	FUNCT		;   (supplied from 'INTCPT' table)
	CPI	'?'
	JZ	CURPAR
	CPI	' '
	JZ	XPRT+3		;skip the extra line feed
	LDA	CMDBUF+3
	CPI	':'		;see if request for new drive/user
	JZ	STDRV
	LXI	D,CMDBUF+2	;point to command
	CALL	INLNCP
	DB	'CPM',0
	JNC	EXIT
	CALL	CRLF		;(1st CR/LF at 'INBUFR')
	CALL	INLNCP
	DB	'LOG',0
	JNC	LOGNW
	CALL	INLNCP
	DB	'DIR',0
	JNC	DIR
	CALL	INLNCP
	DB	'ERA',0
	JNC	ERASEF
	CALL	INLNCP
	DB	'SPD',0
	JNC	STSPD
	CALL	INLNCP
	DB	'TIM',0
	JNC	STTIM
	CALL	INLNCP
	DB	'TCC',0
	JNC	TGCRC
	CALL	INLNCP
	DB	'TRB',0
	JNC	TGRUB
	CALL	INLNCP
	DB	'TLC',0
	JNC	TGLOC
	CALL	INLNCP
	DB	'TLF',0
	JNC	TGLF
	CALL	INLNCP
	DB	'TXO',0
	JNC	TGTXOFF
	LDA	PMMIMD		;using a PMMI  modem?
	ORA	A
	JNZ	NONUM1		;if yes, exit
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JNZ	NONUM1		;if yes, exit
	CALL	INLNCP
	DB	'NUM',0
	JNC	NUMPR
;
NONUM1	LDA	STUPTST
	ORA	A
	JZ	NXOPT1
	CALL	INLNCP
	DB	'SET',0
	JNC	STUPENT
;
NXOPT1	CALL	INLNCP
	DB	'WRT',0
	JNC	WRFIL
	CALL	INLNCP
	DB	'DEL',0
	JNC	NEWFILE
	CALL	INLNCP
	DB	'BYE',0
	JNC	BYEBYE
	CALL	INLNCP
	DB	'DSC',0
	JNC	DONETD
	LDA	PMMIMD		;using a PMMI modem?
	ORA	A
	JNZ	NXOPT0		;if yes, exit
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JZ	NXOPT2		;exit if neither modem-type
;
NXOPT0	CALL	INLNCP		;'DE' set from 1st 'INLNCP' call
	DB	'CAL',0
	JC	NXOPT2
	MVI	A,' '		;fool the system
	STA	CMDBUF+3	;  'TBUF' so that it
	JMP	DOOPT		;  looks at option for dial
;
NXOPT2	LDA	CMDBUF+2
	LXI	H,COMLST
	CALL	COMPARE		;compares list pointed to by HL
	JC	NOTVLD		;carry set = no match
;
DOOPT	CALL	STFCB		;loads command buffer into FCB
	CALL	PROCOPT		;check out the options
	JMP	RSTRT		;go to work
;
NOTVLD	CALL	NVLDMS
	JMP	XPRT
;
NVLDMS	CALL	ILPRT
	DB	'++ Invalid command ++',CR,LF,BELL,0
	RET
;
FUNCT	LDA	INTCPT		;get the function key intercept char.
	ANI	07FH		;strip off any parity
	PUSH	PSW		;save the character for now
	CALL	CLRTST
	CALL	ILPRT
	DB	'         SPECIAL FUNCTION KEY TABLE'
	DB	CR,LF,LF,0
	POP	PSW		;get the character back
	CPI	' '		;see if a printing character
	JNC	FUNCT1		;if a printing character, show it
	PUSH	PSW
	CALL	ILPRT
	DB	'CTL-',0
	POP	PSW
	ADI	40H		;convert binary to ASCII character
;
FUNCT1	CALL	TYPE		;show on the CRT
	CALL	ILPRT
	DB	' current function key intercept character',CR,LF,LF,0
;
; Shows the functions of the (0-9) keys
;
	LXI	H,FNCTBL-1	;index into the function key table
	MVI	B,10		;has ten entries
;
FUNCT2	INX	H		;next table location
	MOV	A,M		;get the binary function number
	ADI	'0'		;convert binary to ASCII digits
	CALL	TYPE
	MVI	A,' '
	CALL	TYPE
;
FUNCT3	INX	H		;next table location
	MOV	A,M
	ORA	A		;see if a binary zero
	JZ	FUNCT5
	CPI	CR
	JNZ	FUNCT4
	CALL	ILPRT
	DB	'<CR>',0
	JMP	FUNCT3
;
FUNCT4	CALL	TYPE
	JMP	FUNCT3
;
FUNCT5	CALL	CRLF
	DCR	B
	JNZ	FUNCT2
	CALL	CRLF
	JMP	XPRT
;
BYEBYE	LDA	PMMIMD		;using a PMMI modem?
	ORA	A
;;;	CNZ	J$GOODBY	;if yes, disconnect
	DB	0,0,0		;(PREVENT DOUBLE DISCONNECT)
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	CNZ	SMRST		;if yes, disconnect
	CALL	J$GOODBY	;user's custom-area goodbye routine
	CALL	ILPRT
	DB	CR,LF,'<< Exit to CP/M >>',CR,LF,0
	JMP	EXIT	;return to CP/M
;
SMRST	MVI	B,20
	CALL	TIMER
	LXI	H,SM$DISC
	CALL	SNDOUT
	MVI	B,20
	CALL	TIMER
	MVI	A,' '
;
; If showing the +++ and ATH and ATD, etc. move the three semicolons up
; one line.
;
	DB	0,0,0
;;;	CALL	TYPE
	LXI	H,SM$ATZ
	CALL	SNDOUT
;
SMRST1	MVI	B,2
	CALL	RECV
	JNC	SMRST1
	RET
;
SM$ATZ	DB	'ATZ',CR,'$'
;
DIR	MVI	C,CURDSK
	CALL	BDOS
	STA	DISKSAV
	CALL	DRLST
	LDA	DISKSAV
	MOV	E,A
	MVI	C,SELDSK
	CALL	BDOS
	JMP	XPRT
;
ERASEF	LXI	D,CMDBUF	;put cmd line into FCB at 'HL'
	LXI	H,FCB
	CALL	CMDLINE
	CALL	MOVEFCB		;move FCB+16 to FCB
	LDA	FCB+1
	CPI	' '
	JZ	NOTVLD		;go if no file specified
	LXI	D,FCB
	MVI	C,SRCHF
	CALL	BDOS
	INR	A		;0 if file not found
	JNZ	ERAFILE		;ok, go erase
	CALL	ILPRT
	DB	'++ File not found ++',CR,LF,BELL,0
	JMP	XPRT
;
ERAFILE	LXI	D,FCB
	MVI	C,ERASE
	CALL	BDOS
	CALL	ILPRT
	DB	'File erased',CR,LF,0
	JMP	XPRT
;
LOGNW	LDA	NFILFLG		;file open for memory save to disk?
	ORA	A
	JNZ	NORESET		;if yes, do not reset disk drive now
	LDA	CMDBUF+6	;any disk drive specified?
	CPI	' '
	JNZ	LOGNW1		;if not a blank, exit
	CALL	GETDISK		;if not, use current drive
	ADI	'A'		;to compensate for next line
;
LOGNW1	SUI	'A'
	CPI	15+1		;for drives 0-15
	JNC	NOTVLD		;if more than 15, display error message
	STA	DISKSAV		;store requested drive
	CALL	GETUSER		;pick up current user number
	MOV	B,A		;save it
	LDA	CMDBUF+7	;get new user number
	CALL	CHRCK		;check the character
	CALL	FNDUSR
	LDA	CMDBUF+8	;get 2nd digit
	CALL	CHRCK		;check the character
	CALL	FNDUSR+2
;
LOGNW2	CALL	SVUSER
	MVI	C,RESET
	CALL	BDOS
	LDA	DISKSAV
	MOV	E,A
	MVI	C,SELDSK
	CALL	BDOS
	LDA	SAVUSR
	MOV	E,A
	CALL	STUSER
	JMP	XPRT
;
CHRCK	CPI	' '
	JZ	CHRCK1
	CPI	':'		;in case of A: or A1: or A11:  (etc.)
	RNZ
;
CHRCK1	POP	PSW		;reset the 'CALL' on the stack
	JMP	LOGNW2
;
FNDUSR	MVI	B,0		;zero the 'B' reg. for 1st time through
	CALL	NUMCHK		;if neither, see if a valid number
	MOV	C,A		;save
	MOV	A,B		;get save first digit
	ADD	A		;x2
	ADD	A		;x4
	ADD	A		;x8
	ADD	B		;x9
	ADD	B		;x10
	ADD	C
	MOV	B,A		;save
	RET
;
SVUSER	MOV	A,B
	CPI	15+1		;user numbers are 0-15
	JNC	NOTVLD
	STA	SAVUSR
	RET
;
NUMGET	LXI	D,CMDBUF
	CALL	INBUF
	LDA	CMDBUF+2	;get number
	CPI	' '
	RZ
;
NUMCHK	SUI	'0'		;remove ascii bias
	CPI	9+1
	RC			;ok if 9 or less
	POP	H		;remove 1st call from the stack
	POP	H		;remove 2nd call from the stack
	JMP	NOTVLD
;
GETUSER	MVI	E,0FFH		;get current user
;
STUSER	MVI	C,USER		;set up BDOS call
	JMP	BDOS
;
GETDISK	MVI	C,CURDSK	;get current drive
	JMP	BDOS
;
NORESET	CALL	ILPRT
	DB	'++      Terminal mode file open      ++',CR,LF
	DB	'++ Use WRT or DEL before LOG command ++',CR,LF
	DB	CR,LF,BELL,0
	XRA	A
	JMP	XPRT
;
STSPD	CALL	ILPRT
	DB	'Delay between chars. (0-9): ',0
;
NOKYS	CALL	STAT
	JZ	NOKYS
	CALL	KEYIN
	CALL	TYPE
	CALL	SAVEA
	SUI	'0'
	CPI	10
	JNC	NOTVLD
	STA	BYTDLY
;
	CALL	ILPRT
	DB	'Delay at end of line (0-9): ',0
;
NOKYS1	CALL	STAT
	JZ	NOKYS1
	CALL	KEYIN
	CALL	TYPE
	CALL	SAVEA
	SUI	'0'
	CPI	10
	JNC	NOTVLD
	STA	CRDLY
;
SPDMSG	CALL	ILPRT
	DB	CR,LF,'Char. delay (terminal file mode) is:  ',0
	LDA	BYTDLY
	MOV	B,A
	MOV	A,B
	PUSH	H
	MOV	L,A
	MVI	H,0
	CALL	DECOUT
	POP	H
	CALL	ILPRT
	DB	'0 ms. per character',CR,LF
	DB	'Line  delay (terminal file mode) is: ',0
	LDA	CRDLY
	MOV	B,A
	PUSH	H
	MOV	L,A
	MVI	H,0
	CALL	DECOUT
	POP	H
	CALL	ILPRT
	DB	'00 ms. per character',CR,LF,0
	JMP	XPRT
;
SAVEA	PUSH	PSW
	CALL	ILPRT
	DB	CR,LF,0
	POP	PSW
	RET
;
STDRV	LDA	CMDBUF+2	;get the disk drive
	SUI	'A'		;convert to binary value
	CPI	15+1		;for drives 0-15
	JNC	NOTVLD
	MOV	E,A
	MVI	C,SELDSK	;select requested drive
	CALL	BDOS
	LDA	CMDBUF+5	;get user number, if any
	CPI	' '		;keep current user area?
	JZ	XPRT
	SUI	'0'		;convert to binary value
	CPI	1		;if a '1', could be units or tens
	JNZ	STDRV1		;if not, numbers stop at 15 so exit
	LDA	CMDBUF+6	;check for a 2nd digit
	CPI	'0'
	JC	STDRV2		;if less, not a valid number, ignore
	SUI	'0'-10		;leave the '10' in as two digits used
;
STDRV1	CPI	15+1		;user areas are 0-15
	JNC	NOTVLD
	MOV	E,A
	CALL	STUSER
	JMP	XPRT		;back to work
;
STDRV2	MVI	A,1
	JMP	STDRV1
;
STTIM	CALL	SORPTST
	JNZ	NOTVLD
	CALL	ILPRT
	DB	'Use 0-8 to give baud rate for ''S'' mode '
	DB	'time-to-send message,',CR,LF
	DB	'where 0=110, 1=300, 2=450, 3=600, 4=710, 5=1200, '
	DB	'6=2400, ',CR,LF,'7=4800 8=9600 and 9=19200 Baud.'
	DB	CR,LF,LF,'Enter value: ',0
	CALL	NUMGET
	CPI	9+1		;only looking for 0-9 answers
	JNC	NOTVLD
	STA	MSPEED
	CALL	STTIM1
	JMP	XPRT
;
STTIM1	CALL	SORPTST
	JNZ	STTIM2
	CALL	ILPRT
	DB	'Rate for the S mode time-to-send message is set to ',0
	JMP	STTIM3
;
STTIM2	CALL	ILPRT
	DB	'Modem speed is ',0
;
STTIM3	JMP	PRTBAUD
;
SORPTST	LDA	STUPTST		;if setup is 'YES' or PMMIMD is
	MOV	B,A		;  'YES' or autodial modem is 'YES'
	LDA	PMMIMD		;  return with zero bit not set
	ORA	B
	RNZ
	LDA	AUTDIAL
	ORA	B
	RET
;
TGCRC	LDA	TGLECRC		;allowing CRC/CHECKSUM toggle?
	ORA	A
	JZ	NOTVLD		;if not, exit
	LDA	CRCDFLT		;get present value and switch it
	CMA
	STA	CRCDFLT
	CALL	TGCRC1		;show on CRT it has been changed
	JMP	XPRT
;
TGCRC1	CALL	ILPRT
	DB	'Mode: ',0
	LDA	CRCDFLT		;see if set for 'CRC' or 'CHECKSUM'
	ORA	A
	JZ	CHEKMSG
	CALL	ILPRT
	DB	'CRC',CR,LF,0
	RET
;
CHEKMSG	CALL	ILPRT
	DB	'CHECKSUM',CR,LF,0
	RET
;
TGRUB	LDA	TGLERUB
	ORA	A
	JZ	NOTVLD
	LDA	CONVRUB
	CMA
	STA	CONVRUB
	CALL	TGRUB1
	JMP	XPRT
;
TGRUB1	LDA	CONVRUB
	ORA	A
	JZ	NORUBMS
	CALL	ILPRT
	DB	'Rub is backspace',CR,LF,0
	RET
;
NORUBMS	CALL	ILPRT
	DB	'Rub is rub',CR,LF,0
	RET
;
TGLOC	LDA	TGLELOC
	ORA	A
	JZ	NOTVLD
	LDA	LOCNXT
	CMA
	STA	LOCNXT
	CALL	TGLOC1
	JMP	XPRT
;
TGLOC1	CALL	ILPRT
	DB	'Use ',0
	LDA	LOCNXT
	ORA	A
	LDA	EXTCHR
	JZ	LOCMSG
	CALL	SHFTYPE
	DB	' before local command',CR,LF,0
	RET
;
LOCMSG	CALL	SHFTYPE
	DB	' to send local command to remote',CR,LF,0
	RET
;
TGLF	LDA	TGLELF
	ORA	A
	JZ	NOTVLD
	LDA	ADDLFD
	CMA
	STA	ADDLFD
	CALL	TGLF1
	JMP	XPRT
;
TGLF1	CALL	ILPRT
	DB	'LF ',0
	LDA	ADDLFD		;adding LF after CR?
	ORA	A
	JNZ	LFMSG		;if yes, exit
	CALL	ILPRT
	DB	'NOT ',0
;
LFMSG	CALL	ILPRT
	DB	'sent after CR in "L" or "T" for a disk file',CR,LF,0
	RET
;
TGTXOFF	LDA	TGXOFF
	ORA	A
	JZ	NOTVLD
	CALL	ILPRT
	DB	'Use XOFF testing? (Y/N): ',0
	CALL	GETANS
	JC	NOCHG3
	STA	XOFFTST
;
NOCHG3	CALL	XOFFMSG
	CALL	ILPRT
	DB	CR,LF,'Use XON waiting after <CR> (Y/N): ',0
	CALL	GETANS
	JC	NOCHG4
	STA	XONWAIT
;
NOCHG4	CALL	XONMS
	LDA	XONWAIT
	ORA	A
	JZ	XPRT
	CMA
	STA	XOFFTST		;do not allow both
	CALL	ILPRT
	DB	'Therefore ',0
	CALL	XOFFMSG
	JMP	XPRT
;
GETANS	LXI	D,CMDBUF
	CALL	INBUF
	LDA	CMDBUF+2	;get answer
	CPI	' '
	CMC			;set the carry flag
	RZ
	MOV	B,A
	CPI	'N'
	MVI	A,0
	RZ
	MOV	A,B
	CPI	'Y'
	MVI	A,1
	RZ
	POP	PSW		;preserve stack
	JMP	NOTVLD
;
XOFFMSG	CALL	ILPRT
	DB	'XOFF testing ',0
	LDA	XOFFTST
	ORA	A
	JNZ	XOTSTON
	CALL	ILPRT
	DB	'NOT ',0
;
XOTSTON	CALL	ILPRT
	DB	'used',0
;
XONMS1	CALL	ILPRT
	DB	' in terminal mode file output',CR,LF,0
	RET
;
XONMS	CALL	ILPRT
	DB	'XON ',0
	LDA	XONWAIT
	ORA	A
	JNZ	XONMS2
	CALL	ILPRT
	DB	'NOT ',0
;
XONMS2	CALL	ILPRT
	DB	'automatically tested after CR',0
	JMP	XONMS1
;
STUPENT	LDA	STUPTST
	ORA	A
	JZ	NOTVLD
	LXI	D,CMDBUF+1
	CALL	J$STUPR
	LDA	AUTDIAL		;using a Hayes-type modem?
	ORA	A
	JZ	XPRT		;if not, exit, otherwise
	MVI	B,'A'		;  send 'AT',CR to autodial modem
	CALL	SNDCHR		;  to insure its baud rate
	MVI	B,'T'		;  matches that just selected
	CALL	SNDCHR
	MVI	B,CR
	CALL	SNDCHR
	JMP	XPRT
;
NEWFILE	LDA	NFILFLG		;file open for disk save?
	ORA	A
	JZ	NFILOP		;if not, show "no file open" message
	LDA	FCB3+1		;check that file was requested
	CPI	' '
	JZ	NFILOP		;if no file, do not erase
	LXI	D,FCB3		;otherwise erase the old file
	MVI	C,ERASE
	CALL	BDOS
	XRA	A
	STA	NFILFLG		;no file mentioned, reset flags
	STA	SAVEFLG
	LXI	H,FCB3
	CALL	INITFCB
	LXI	H,BUFFER	;reset flags to bottom of ram just
	SHLD	HLSAV		; to insure they are there
	JMP	XPRT
;
WRFIL	LDA	NFILFLG		;saving memory for a disk file?
	ORA	A
	JZ	NFILOP		;not saving a file, don't bother writing
	CALL	WRFIL1		;close the file
	STA	SAVEFLG
	STA	WRFLG
	LXI	H,FCB3
	CALL	INITFCB		;blank out 'FCB' to written file
	LXI	H,BUFFER	;can not be erased
	SHLD	HLSAV		;reset to buffer start for next time
	JMP	XPRT
;
WRFIL1	LDA	FCB3+1		;check that file was requested
	CPI	' '
	RZ
	CALL	WRDSK		;write buffer to disk if not empty
;
WRFIL2	LXI	D,FCB3		;close the file
	MVI	C,CLOSE
	CALL	BDOS
	XRA	A
	STA	NFILFLG		;file written, reset flags
	RET
;
NFILOP	CALL	ILPRT
	DB	'++ No File Open ++',CR,LF,BELL,0
	JMP	XPRT
;
; THIS ROUTINE DISPLAYS THE PHONE NUMBERS IN THE LIBRARY
;
NUMPR	PUSH	H
	CALL	CLRTST
	CALL	ILPRT
	DB	'           Library of Phone Numbers of Remote Systems'
	DB	0
	MVI	C,18		;number of lines to move
	LXI	H,NUMLIB	;address of source memory
	LXI	D,BUFFER	;address of target memory
	CALL	NEWLINE		;start with CRLF
	STAX	D		;+LF
	INX	D		;and bump it
;
NUMPR1	INX	H		;skip PMMI dialing letter
	INX	H		;and equal sign
	MVI	B,LIBLEN-2	;number of bytes to move
	CALL	MOVE		;move to buffer
	CALL	SPACES		;2 entries + 3 spaces = 63 characters
	PUSH	H		;save source address
	PUSH	D		;save destination address
	INX	H		;skip next two characters
	INX	H
	LXI	D,(17*LIBLEN)	;get offset of 17 times entry length
	DAD	D		;add it to the source address
	POP	D		;restore destination address
	MVI	B,LIBLEN-2	;get length of library entry
	CALL	MOVE		;move another entry
	POP	H		;restore source address
	CALL	NEWLINE		;start next line
	DCR	C		;one less line to print
	JNZ	NUMPR1		;if not finished, do another
	MVI	A,'$'
	STAX	D
	MVI	C,PRINT
	LXI	D,BUFFER	;point to table of numbers to print
	CALL	BDOS
	CALL	CRLF
	CALL	CRLF
	POP	H
	JMP	XPRT		;finished, back to prompt
;
NEWLINE	MVI	A,CR		;puts CRLF at memory pointed by 'DE'
	STAX	D		;store it
	MVI	A,LF		;line feed
	INX	D		;bump pointer
	STAX	D		;store lf
	INX	D		;bump pointer
	RET
;
SPACES	MVI	A,' '		;space
	STAX	D
	INX	D		;1
	STAX	D
	INX	D		;2
	STAX	D
	INX	D		;3
	RET
;
COMPARE	MOV	B,M		;compares 'A' register with list
;
COMPLP	INX	H		;addressed by HL - first element
	CMP	M		;of list must be number of elements
	JZ	VALID		;being compared. returns with
	DCR	B		;carry set if 'A' reg. does not
	JNZ	COMPLP		;contain an element in list
	STC
;
VALID	RET
;
NXTSCR	CALL	ILPRT
	DB	'HIT any KEY to CONTINUE',0
;
NOKEY1	CALL	STAT		;get keyboard status
	JZ	NOKEY1		;keep looping until keypress
	CALL	KEYIN		;gobble up keypress
	CPI	'C'-40H		;control-c to abort?
	JNZ	CLRTST
	POP	H		;clear stack of return address
	CALL	CRLF		;turn up a blank line
	JMP	XPRT
;
CLRTST	LDA	SCRNTST
	ORA	A
	JNZ	CLRSCR
;
LOTSALF	MVI	A,CR
	CALL	TYPE
	MVI	B,12
	MVI	A,LF
;
LFLOOP	CALL	TYPE
	DCR	B
	JNZ	LFLOOP
	RET
;
CURPAR	CALL	CLRTST
	CALL	ILPRT
	DB	'                Current Settings',CR,LF,LF,0
	CALL	TGCRC1
	CALL	TGRUB1
	LDA	LSTTST
	ORA	A
	JZ	NOLIS1
	CALL	LSTMS
;
NOLIS1	CALL	STTIM1
	CALL	ILPRT
	DB	'Terminal mode file buffer is ',0
	LDA	NFILFLG		;saving memory for a disk file?
	ORA	A
	JNZ	ACTIVE		;if yes, go say "active"
	CALL	ILPRT
	DB	'in',0		;if not, say "inactive"
;
ACTIVE	CALL	ILPRT
	DB	'active',CR,LF,'Unused portion of buffer is ',0
	CALL	GETSPC
	CALL	ILPRT
	DB	' bytes',CR,LF,0
	CALL	TGLOC1
	CALL	TGLF1
	CALL	XOFFMSG
	CALL	XONMS
	CALL	SPDMSG
	CALL	CRLF
	CALL	CRLF
	CALL	CRLF
	JMP	XPRT
;
GETSPC	LXI	D,BUFTOP	;top of memory buffer
	LHLD	HLSAV		;current buffer location
	XCHG
	XRA	A		;clear the carry bit, if set
	SUB	E
	MOV	L,A
	MOV	A,H
	SBB	D
	MOV	H,A
	CALL	DECOUT		;print the space remaining
	RET
;
;***********************************************************************
;		DATA AREA
;***********************************************************************
;
COMLST	DB	6,'S','R','T','E','L','M'
;
; OPTION TABLE
;
OPTBL	EQU	$
ANSWFLG	DB	'A'
BCHFLG	DB	'B'
DISCFLG	DB	'D'
JMPCMD	DB	'J'
LOCLFG	DB	'L'
ORIGFLG	DB	'O'
QFLG	DB	'Q'
RSEEFLG	DB	'R'
SSEEFLG	DB	'S'
VSEEFLG	DB	'V'
XITFLG	DB	'X'
EPRITY	DB	'0'	;even parity sub-option (only in S or R mode)
OPRITY	DB	'1'	;odd parity sub-option	(only in S or R mode)
OPTBE	EQU	$	;transfer when program initially called.
;
; The following must be in the same order as the table above
;
RSTOPT	DB	'A','B','D','J','L','O','Q','R','S','V','X','0','1'
;
; The next 14 bytes equal the number of bytes between RECNOB and
; RECNOE.
;
RESTSN	DB	0,0,0,0,0,0
	DW	BUFFER
	DB	0,0,0,0,0,NAK
;
RECNOB	EQU	$		;start of table marker
RCVRNO	DB	0		;\
RECNO	DB	0,0		; \
ERRCT	DB	0		;  \
ERRCDE	DB	0		;   \
EOFLG	DB	0		;    \	14 bytes between table markers
RECPTR	DW	BUFFER		;    /
RECINBF	DB	0		;   /
MAXEXT	DB	0		;  /
RCNT	DB	0,0		; /
DATAFLG	DB	0		;/
BENHERE	DB	NAK		;
RECNOE	EQU	$		;end of table marker
;
; Additional 16-bit initialized storage
;
CRCVAL	DW	0
DIALCT	DW	0
HLSAV	DW	BUFFER
HLSAV1	DW	PBUFF
HLSAV2	DW	PBUFF
;
; Additional general purpose initialized storage
;
ABTFLG	DB	0
ACKFLG	DB	0
CRCFLAG	DB	0
CRFLAG	DB	0
CURRENT	DB	52		;PMMI 300 baud speed value
DLYFLG	DB	0		;  (defaults to 300)
ECHOFLG	DB	0
EXACFLG	DB	0
FIRSTME	DB	0
FNKFLG	DB	0		;function key activity flag
FSTFLG	DB	0
LISTFLG	DB	0
LOCFLG	DB	0
MFFLG1	DB	0
MDCTLB	DB	07FH
NFILFLG	DB	0
ONERR	DB	0
OPTION	DB	0
ORIGSAV	DB	0
RNGBKFL	DB	0
SAVEFLG	DB	0
UARTCT	DB	ORIGMOD		;for originate mode
WRFLG	DB	0
XFLG	DB	0
CMDBUF	DB	80H,0		;command buffer control area
;
; General purpose unitialized storage area
;
	DS	128		;storage area for 'CMDBUF'
BGNMS	DS	2
TIMFLG	DS	1
FLTRFLG	DS	1
CHRFLG	DS	1
TIMVAL	DS	2
QUIKTIM	DS	2
DISKNO	DS	1
DISKSAV	DS	1
DSTORE	DS	1
FILECT	DS	1
FTYCNT	DS	1
MAXRAM	DS	1
NAMECT	DS	1
NBSAVE	DS	2
OLDUSER	DS	1
SNDFLG	DS	1
SAVUSR	DS	1
;
FCB3	DS	33
FCB4	DS	33
FCBBUF	DS	15
MFNAM5	DS	12
MFNAM6	DS	12		;current name
	DS	100		;minimum stack depth
;
EVNPAGE	EQU	($+255)/256*256	;sets buffers on even page
;
	ORG	EVNPAGE
;
STACK	EQU	EVNPAGE-2	;store original stack pointer
CRCTBL	DS	512		;two tables of 128 bytes each
BUFFDSK	DS	128		;buffer for disk save
BUFFPNT	DS	128		;buffer for printer
BUFFER	DS	1024*BUFSIZ	;send/receive file buffer
BUFTOP	DS	0		;filled in when length is found
PBUFF	EQU	$		;printer buffer starts here
NAMEBUF	EQU	$		;batch-mode filenames buffer
;
; BDOS EQUATES
;
RDCON	EQU	1
WRCON	EQU	2
LIST	EQU	5
PRINT	EQU	9
RDBUF	EQU	10
CONST	EQU	11
CPMVER	EQU	12
RESET	EQU	13
SELDSK	EQU	14
OPEN	EQU	15
CLOSE	EQU	16
SRCHF	EQU	17
SRCHN	EQU	18
ERASE	EQU	19
READ	EQU	20
WRITE	EQU	21
MAKE	EQU	22
REN	EQU	23
CURDSK	EQU	25
STDMA	EQU	26
DSKALL	EQU	27
DSKPAR	EQU	31
USER	EQU	32
FILSIZ	EQU	35
BDOS	EQU	0005H
REIPL	EQU	0
FCB	EQU	5CH
FCBEXT	EQU	FCB+12
FCBSNO	EQU	FCB+32
FCBRNO	EQU	FCB+32
FCB2	EQU	6CH
TBUF	EQU	80H
;
	END
