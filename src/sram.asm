.define     SRAMBank    $fffc
.define     SRAMStart   $8000

SRAMHeader:
    .db "ditto is my fave"
SRAMHeaderEnd:

InitialiseSRAM:
    ; Enable SRAM bank
    ld a, $08
    ld (SRAMBank), a

    ; Check if SRAM header is present
    call CheckSRAMHeader
    or a
    jr nz, +

    ; If not, clear SRAM and write header
    call ClearSRAM
    call WriteSRAMHeader

    ; Disable SRAM bank
+:  ld a, $80
    ld ($fffc), a

    ret

CheckSRAMHeader:
    ld de, SRAMHeader
    ld hl, SRAMStart                    ; First byte of SRAM

    ld b, SRAMHeaderEnd-SRAMHeader

-:  
    ld c, (hl)
    ld a, (de)
    cp c
    jr z, +
    xor a           ; Invalid
    ret
+:  inc de
    inc hl
    djnz -

    ld a, $01       ; Valid
    ret

WriteSRAMHeader:
    ld hl, SRAMHeader
    ld de, SRAMStart
    ld bc, SRAMHeaderEnd-SRAMHeader
    ldir

    ret

ClearSRAM:
    ld hl, SRAMStart
    ld de, SRAMStart+1
    ld bc, $1FFB
    ld (hl), l
    ldir

    ret
