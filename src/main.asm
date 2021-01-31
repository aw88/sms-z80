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

;==============================================================================
; SMS Defines
;==============================================================================
.define VDPControl              $bf
.define VDPStatus               $bf
.define VDPData                 $be
.define VRAMWrite               $4000
.define CRAMWrite               $c000

.define VDP_EXTRA_HEIGHT        %00000010
.define VDP_SHIFT_SPRITES       %00001000
.define VDP_LEFT_COL_BLANK      %00100000
.define VDP_LOCK_HSCROLL        %00000100
.define VDP_LOCK_VSCROLL        %00001000

.define VDP_ZOOM_SPRITES        %00000001
.define VDP_TALL_SPRITES        %00000010
.define VDP_MD_MODE_5           %00000100
.define VDP_30_ROW              %00001000
.define VDP_28_ROW              %00010000
.define VDP_VBLANK_ENABLE       %00100000
.define VDP_DISPLAY_ENABLE      %01000000

.define TILE_FLIP_X             $0200
.define TILE_FLIP_Y             $0400
.define TILE_USE_SPRITE_PAL     $0800
.define TILE_PRIORITY           $1000

.ramsection "global variables" slot 3
    VDPRegister01       db
    VDPRegister02       db
    InputMap            db
    VBlankFlag          db
.ends

;==============================================================================
; Macros
;==============================================================================

; Set the VDP address to HL
.macro SET_VDP_ADDR
    rst $08
.endm

.macro WRITE_VDP_DATA
    rst $18
.endm

.macro TILE_XY_TO_ADDR ARGS TILE_X, TILE_Y
    ld hl, $4000|($3800+(TILE_Y.w<<6)+(TILE_X.w<<1))
.endm

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
    ld a,l                          ; (respecting VRAM time costraints)
        out (VDPData), a                ; 11
        ld a,h                          ; 4
        sub $00                         ; 7
        nop                             ; 4 = 26 (VRAM SAFE)
        out (VDPData), a
        ret
.ends

.org $0038
.section "Interrupt handler" force
    push af
        in a, (VDPStatus)
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

CopyToVDP:
; Copies data to the VDP
; hl = start address, bc = data length
; Affects: a, hl, bc
-:      ld a, (hl)
        out (VDPData), a
        inc hl
        dec bc
        ld a, b
        or c
        jr nz, -
        ret

;==============================================================================
; Main
;==============================================================================
main:
    ld sp, $dff0

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

    ld hl, fontTiles
    ld bc, fontTilesSize
    call CopyToVDP

    ld hl, $5f60
    SET_VDP_ADDR

    ld hl, DialogTiles
    ld bc, DialogTilesEnd-DialogTiles
    call CopyToVDP

    ;==========================================================================
    ; Draw the dialog box
    ;==========================================================================
    call DrawDialogBottom

    TILE_XY_TO_ADDR 2, 19
    SET_VDP_ADDR

    ld hl, MessageText
    ld bc, MessageTextEnd-MessageText
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
    ; Looooooooooop
    ;==========================================================================
    Loop:
            jp Loop

DrawDialogBottom:
    TILE_XY_TO_ADDR 1, 18
    SET_VDP_ADDR
    ld hl, $00fb
    WRITE_VDP_DATA
    ld hl, $00fc
    .repeat 29
        WRITE_VDP_DATA
    .endr
    ld hl, $00fb|TILE_FLIP_X
    WRITE_VDP_DATA
    ld hl, $0000
    WRITE_VDP_DATA

    ld b, 4
    -:
        ld hl, $00fd
        WRITE_VDP_DATA
        ld hl, $00a0
        .repeat 29
            WRITE_VDP_DATA
        .endr
        ld hl, $00fd|TILE_FLIP_X
        WRITE_VDP_DATA
        ld hl, $0000
        WRITE_VDP_DATA
        djnz -
    
    ld hl, $00fb|TILE_FLIP_Y
    WRITE_VDP_DATA
    ld hl, $00fc|TILE_FLIP_Y
    .repeat 29
        WRITE_VDP_DATA
    .endr
    ld hl, $00fb|TILE_FLIP_X|TILE_FLIP_Y
    WRITE_VDP_DATA
    ld hl, $0000
    WRITE_VDP_DATA

    ret

DrawDialogText:
    ret


VdpData:
.db $04, $80    ; 0: Mode 4
.db $00, $81    ; 1: 
.db $ff, $82
.db $ff, $85
.db $ff, $86
.db $ff, $87
.db $00, $88
.db $00, $89
.db $ff, $8a
VdpDataEnd:

PaletteData:
.db $00,$3f
PaletteDataEnd:

PlayerSpritePalette:
.incbin "assets/sprites_pal" FSIZE PlayerSpritePaletteSize

.macro toASCII
.redefine _out \1+128
.endm

MessageText:
.dwm toASCII "Hello, world!"
MessageTextEnd:

fontTiles:
.incbin "assets/font" FSIZE fontTilesSize

DialogTiles:
.db %11111111, $00, $00, $00
.db %11111111, $00, $00, $00
.db %11000000, $00, $00, $00
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
