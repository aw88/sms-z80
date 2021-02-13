.memorymap
defaultslot 0
slotsize $7ff0        ; ROM (not paged)
slot 0 $0000
slotsize $0010        ; SEGA ROM header (not paged)
slot 1 $7ff0
slotsize $4000        ; ROM (paged!)
slot 2 $8000
slotsize $2000        ; RAM
slot 3 $c000
.endme

.rombankmap
bankstotal 8
banksize $7ff0        ; 32kb - 16 bytes
banks 1
banksize $0010        ; 16 bytes - SEGA ROM header
banks 1
banksize $4000        ; 16kb each
banks 6            ; x6 - 128kb total
.endro

.sdsctag 1.00, "Hello World!", "Prototype SMS stuff", "Alex W"

.asciitable
    MAP " " to "z" = $a0
.enda

.ramsection "global variables" slot 3
    VDPRegister01       db
    VDPRegister02       db
    InputMap            db
    VBlankFlag          db
    DialogCurrentLine   db
.ends

.incdir "src"

.include "macros.asm"
.include "vdp.asm"
.include "dialog.asm"
.include "sram.asm"

.bank 0 slot 0

;==============================================================================
; Boot
;==============================================================================
.org $0000
.section "Startup" force
    di
    im 1
    ld sp, $dff0
    jr InitMapper
.ends

.org $0008
.section "RST Vector" force
    ; Sets the VDP write address to HL
    ld c, VDPControl
    di
    out (c), l
    out (c), h
    ei
    ret
.ends

.org $0018
.section "RST Vector 2" force
    ; Writes HL to VDP data port
    ld a, l                          ; (respecting VRAM time costraints)
    out (VDPData), a                ; 11
    ld a,h                          ; 4
    sub $00                         ; 7
    nop                             ; 4 = 26 (VRAM SAFE)
    out (VDPData), a
    ret
.ends

;==============================================================================
; Interrupt service routine
;==============================================================================
.org $0038
.section "Interrupt handler" force
    push af
        in a, (VDPStatus)               ; Satisfy the interrupt
        ld a, $01
        ld (VBlankFlag), a              ; Update flag
    pop af
    ei
    reti
.ends

;==============================================================================
; Pause handler
;==============================================================================
.org $0066
.section "Pause handler" force
    retn
.ends

;==============================================================================
; Initialise mappers
;==============================================================================
.org $0400
.section "Initialise mappers" semisubfree
InitMapper:
    ld de, $fffc
    ld hl, InitialMapperValues
    ld bc, $0004
    ldir

    xor a
    ld hl, $c000
    ld (hl), a
    ld de, $c001
    ld bc, $1ff0
    ldir

    jp main

InitialMapperValues:
    .db $00, $00, $01, $02
.ends

; .section "Input handler" semisubfree
; InputHandler:
;     push af
;     push hl
;     in
; .ends

;==============================================================================
; Main
;==============================================================================
main:
    ld sp, $dff0

    call InitialiseSRAM

    ;==========================================================================
    ; Setup VDP registers
    ;==========================================================================
    ld hl, VdpData
    ld b, VdpDataEnd-VdpData
    ld c, VDPControl
    otir

    ;==========================================================================
    ; Clear VRAM
    ;==========================================================================
    ld hl, $0000 | VRAMWrite
    SET_VDP_ADDR

    ld bc, $4000
    ClearVRAMLoop:
        ld a, $00
        out ($be), a
        dec bc
        ld a, b
        or c
        jp nz, ClearVRAMLoop

    ;==========================================================================
    ; Load palettes
    ;==========================================================================
    ld hl, $0000 | CRAMWrite
    SET_VDP_ADDR

    ld hl, PaletteData
    ld b, PaletteDataEnd-PaletteData
    ld c, $be
    otir

    ld hl, $0010 | CRAMWrite
    SET_VDP_ADDR
    ld hl, PlayerSpritePalette
    ld b, PlayerSpritePaletteSize
    ld c, VDPData
    otir

    ;==========================================================================
    ; Load font tiles
    ;==========================================================================
    ; Set VRAM write to 0x1400 ($1400 OR $4000)
    ld hl, $5400
    SET_VDP_ADDR

    LOAD_BANK fontTiles
    ld hl, fontTiles
    ld bc, fontTilesSize
    call CopyToVDP

    ld hl, $5f60
    SET_VDP_ADDR

    LOAD_BANK DialogTiles
    ld hl, DialogTiles
    ld bc, DialogTilesEnd-DialogTiles
    call CopyToVDP

    ;==========================================================================
    ; Enable display
    ;==========================================================================
    ld a, VDP_DISPLAY_ENABLE|VDP_VBLANK_ENABLE
    out (VDPControl), a
    ld a, $81
    out (VDPControl), a

    ld a, VDP_LEFT_COL_BLANK|$0004
    out (VDPControl), a
    ld a, $80
    out (VDPControl), a

    ;==========================================================================
    ; Draw the dialog box
    ;==========================================================================
    call DrawDialogTop
    ld hl, MessageText
    call DrawDialogTextTop

    call DrawDialogBottom
    ld hl, MessageText2
    call DrawDialogTextBottom

    ;==========================================================================
    ; Looooooooooop
    ;==========================================================================
    Loop:
        halt
        jp Loop


PaletteData:
.db $00,$3f
PaletteDataEnd:

PlayerSpritePalette:
.incbin "assets/sprites_pal" FSIZE PlayerSpritePaletteSize

.macro toASCII
.redefine _out \1+128
.endm

MessageText:
.asc "Hello, world! :)"
.db $81 ; New line
.asc "What's this?!"
.db $81
.asc "  MORE ROWS NEEDED"
.db $81
.asc "and another one. why not."
.db $80
MessageTextEnd:

MessageText2:
.asc "Hello, world! :)"
.db $81 ; New line
.asc "Here's some more text"
.db $81
.asc "But this text shows"
.db $81
.asc "    at the bottom!"
.db $80
MessageText2End:

.bank 7 slot 2

.org $0000

fontTiles:
.incbin "assets/font" FSIZE fontTilesSize

DialogTiles:
.db %00111111, $00, $00, $00
.db %01111111, $00, $00, $00
.db %11100000, $00, $00, $00
.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00

.db %11111111, $00, $00, $00
.db %11111111, $00, $00, $00
.db %00000000, $00, $00, $00
.db %00000000, $00, $00, $00
.db %00000000, $00, $00, $00
.db %00000000, $00, $00, $00
.db %00000000, $00, $00, $00
.db %00000000, $00, $00, $00

.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00
.db %11000000, $00, $00, $00
DialogTilesEnd:
