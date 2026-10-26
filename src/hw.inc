; hw.inc - Oric Atmos hardware for Juggernaut
;
; 48K machine, ROM left in place but never called: the game owns the VIA,
; the ULA and the AY-3-8912 from hw_init onwards.

VIA_ORB  = $0300
VIA_DDRB = $0302
VIA_DDRA = $0303
VIA_T1CL = $0304
VIA_T1CH = $0305
VIA_T2CL = $0308
VIA_T2CH = $0309
VIA_ACR  = $030B
VIA_PCR  = $030C
VIA_IFR  = $030D
VIA_IER  = $030E
VIA_ORA  = $030F

; video
HIRES    = $A000                ; 200 lines x 40 bytes, 6 pixels per byte
TEXTBASE = $BB80                ; text page; its first byte holds the mode attribute
TEXTROWS = $BF68                ; 3 character rows below the HIRES picture
MODEREG  = $BFDF                ; the ULA's serial input port
CHARSET  = $9800                ; 128 glyphs of 8 bytes in HIRES mode
VID_END  = $BF40                ; one past the last HIRES byte

; A HIRES byte holds six pixels in bits 0-5 (bit 5 = leftmost); bit 6 must be
; set or the ULA treats the byte as an attribute byte, bit 7 inverts the six
; pixels.  BLANK is therefore $40 and not $00.
BLANK    = $40
INVERT   = $80

; screen geometry
SCR_W    = 240                  ; pixels
SCR_BYTES= 40                   ; bytes per line
DASH_H   = 64                   ; dashboard lines
VIEW_Y   = 64                   ; first line of the driving view
VIEW_H   = 128                  ; lines of driving view
VIEW_YE  = VIEW_Y + VIEW_H

; town tile numbers, matching tools/gen_town.py
T_ROAD   = 0
T_BUILD  = 1
T_PAVE   = 2
T_BAY    = 3
T_MARK_H = 4                    ; the depot
T_MARK_G = 5                    ; garage
T_MARK_T = 6                    ; timber yard
T_MARK_C = 7                    ; coal merchant
T_MARK_O = 8                    ; oil depot
T_MARK_F = 9                    ; fruit and veg
T_MARK_P = 10                   ; police station
T_ZEBRA  = 11
T_GRASS  = 12
T_ROUND  = 13
T_MARK_B = 14                   ; telephone

; keyboard matrix positions.  The Oric matrix is eight rows of eight columns
; and the QWERTY layout is spread across it in a scramble, so these were taken
; from the matrix table rather than guessed from the keyboard picture:
;
;   row 0 7 n 5 v RCTRL 1 x 3      row 4 SPACE , . UP LSHIFT LEFT DOWN RIGHT
;   row 1 j t r f -     ESC q d    row 5 u i o p LALT BACKSPACE ] [
;   row 2 m 6 b 4 LCTRL z 2 c      row 6 y h g e RALT a s w
;   row 3 k 9 ; - #     \ '        row 7 8 l 0 / RSHIFT RETURN ` =
K_A_ROW  = 6
K_A_COL  = $20
K_Z_ROW  = 2
K_Z_COL  = $20
K_O_ROW  = 5
K_O_COL  = $04
K_P_ROW  = 5
K_P_COL  = $08
K_M_ROW  = 2
K_M_COL  = $01
K_S_ROW  = 6
K_S_COL  = $40
K_SP_ROW = 4
K_SP_COL = $01

; Oric colour numbers
C_BLACK  = 0
C_RED    = 1
C_GREEN  = 2
C_YELLOW = 3
C_BLUE   = 4
C_MAGENTA= 5
C_CYAN   = 6
C_WHITE  = 7
