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

.struct PlayerStruct
    PositionX db
    PositionY db
.endst

.ramsection "global variables" slot 3
    VDPRegister01       db
    VDPRegister02       db
    InputMap            db
    VBlankFlag          db
    DialogCurrentLine   db
    Player              INSTANCEOF PlayerStruct
.ends

.incdir "src"

.include "macros.asm"
.include "vdp.asm"
.include "sprite.asm"
.include "input.asm"
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
    push hl
        in a, (VDPStatus)               ; Satisfy the interrupt
        ld a, $01
        ld (VBlankFlag), a              ; Update VBlank flag
        ld hl, (ButtonStatus)
        ld (PreviousButtonStatus), hl   ; Store previously pressed buttons
        in a, (IOPortL)
        cpl
        ld hl, ButtonStatus
        ld (hl), a                      ; Store LOW byte of input
        in a, (IOPortH)
        cpl
        inc hl
        ld (hl), a                      ; Store HIGH byte of input
    pop hl
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

    LOAD_BANK MapTilesPalette
    ld hl, MapTilesPalette
    ld b, MapTilesPaletteSize
    ld c, $be
    otir

    ld hl, $0010 | CRAMWrite
    SET_VDP_ADDR

    ld hl, SpritePalette
    ld b, SpritePaletteSize
    ld c, VDPData
    otir

    ;==========================================================================
    ; Load font tiles
    ;==========================================================================
    ld hl, $4020
    SET_VDP_ADDR
    LOAD_BANK MapTiles
    ld hl, MapTiles
    ld bc, MapTilesSize
    call CopyToVDP

    ; Set VRAM write to 0x1400 ($1400 OR $4000)
    ld hl, $5400
    SET_VDP_ADDR

    LOAD_BANK fontTiles
    ld hl, fontTiles
    ld bc, fontTilesSize
    call CopyToVDP

    ; Set VRAM write to 0x1f60 ($1f60 OR $4000)
    ld hl, $5f60
    SET_VDP_ADDR

    LOAD_BANK DialogTiles
    ld hl, DialogTiles
    ld bc, DialogTilesEnd-DialogTiles
    call CopyToVDP

    ; Load sprite tiles
    ; Set VRAM write to 0x2000 ($2000 OR $4000)
    ld hl, $6020
    SET_VDP_ADDR

    ld hl, SpriteTiles
    ld bc, SpriteTilesSize
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

    call DialogYesNo
    or a

    jr nz, +
    call DrawDialogBottom
    ld hl, MessageTextNo
    call DrawDialogTextBottom
    jr ++

+:  call DrawDialogBottom
    ld hl, MessageTextYes
    call DrawDialogTextBottom
++:

    ld hl, Player.PositionX
    ld (hl), 100
    ld hl, Player.PositionY
    ld (hl), 83

    ;==========================================================================
    ; Looooooooooop
    ;==========================================================================
    Loop:
        call WaitForVBlank

        ;==========================================================================
        ; Spritessss
        ;==========================================================================
        call SpriteInit

        call UpdatePlayerPosition
        call AddPlayerSprites

        call SpriteCopyToSAT

        jp Loop

UpdatePlayerPosition:
    ld a, (ButtonStatus)
    and PORT_A_RIGHT
    jr z, +
    ld hl, Player.PositionX
    inc (hl)
+:  ld a, (ButtonStatus)
    and PORT_A_LEFT
    jr z, +
    ld hl, Player.PositionX
    dec (hl)
+:  ld a, (ButtonStatus)
    and PORT_A_DOWN
    jr z, +
    ld hl, Player.PositionY
    inc (hl)
+:  ld a, (ButtonStatus)
    and PORT_A_UP
    jr z, +
    ld hl, Player.PositionY
    dec (hl)
+:  ret

AddPlayerSprites:
    ld d, 1
    ld a, (Player.PositionX)
    ld e, a
    ld a, (Player.PositionY)
    call SpriteAdd

    ld d, 3
    ld a, (Player.PositionX)
    add 8
    ld e, a
    ld a, (Player.PositionY)
    call SpriteAdd

    ld d, 2
    ld a, (Player.PositionX)
    ld e, a
    ld a, (Player.PositionY)
    add 8
    call SpriteAdd

    ld d, 4
    ld a, (Player.PositionX)
    add 8
    ld e, a
    ld a, (Player.PositionY)
    add 8
    call SpriteAdd

    ret


PaletteData:
.db $01,$3f
PaletteDataEnd:

SpritePalette:
.incbin "assets/sprites_pal" FSIZE SpritePaletteSize

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

MessageTextYes:
.asc "You chose YES"
.db $80
MessageTextYesEnd:

MessageTextNo:
.asc "You chose NO!"
.db $80
MessageTextNoEnd:

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

SpriteTiles:
.incbin "assets/sprites" FSIZE SpriteTilesSize

MapTiles:
.incbin "assets/tiles" FSIZE MapTilesSize

MapTilesPalette:
.incbin "assets/tiles_pal" FSIZE MapTilesPaletteSize
