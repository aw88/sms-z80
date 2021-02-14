.ramsection "input variables" slot 3
    ButtonStatus            dw
    PreviousButtonStatus    dw
.ends

.define IOPortL         $dc
.define IOPortH         $dd

.define PORT_A_UP       $01
.define PORT_A_DOWN     $02
.define PORT_A_LEFT     $04
.define PORT_A_RIGHT    $08
.define PORT_A_1        $10
.define PORT_A_2        $20

.section "input handling" free
; Waits for any button press
; Returns: a = Pressed button
WaitForButton:
-:  call WaitForVBlank
    ld a, (ButtonStatus)
    or a
    jr z, -
    ret

; Checks if a button was pressed this frame
; Input: BC - input mask to check against
; TODO: Use both bytes of input to check against 2nd pad?
IsButtonPressed:
    ; ButtonStatus & ^PreviousButtonStatus
    ld a, (PreviousButtonStatus)
    cpl
    ld hl, ButtonStatus
    and (hl)
    and c
    ret
.ends
