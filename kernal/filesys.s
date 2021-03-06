; GEOS KERNAL by Berkeley Softworks
; reverse engineered by Maciej Witkowiak, Michael Steil
;
; BAM/VLIR filesystem driver

.include "const.inc"
.include "geossym.inc"
.include "geosmac.inc"
.include "config.inc"
.include "kernal.inc"
.include "diskdrv.inc"
.include "jumptab.inc"

; main.s
.import _MNLP

; load.s
.global GetStartHAddr

; var.s
.import RecordDirOffs
.import RecordDirTS
.import RecordTableTS
.import verifyFlag

.ifdef trap
.global SerialHiCompare
.endif

.ifdef useRamExp
; reu.s
.import RamExpRead
.import RamExpGetStat
.import DeskTopRecord
.import DeskTopOpen

; load.s
.import DeskTopName
.endif

; syscalls
.global _AppendRecord
.global _BldGDirEntry
.global _CloseRecordFile
.global _DeleteFile
.global _DeleteRecord
.global _FastDelFile
.global _FindFTypes
.global _FindFile
.global _FollowChain
.global _FreeFile
.global _GetFHdrInfo
.global _GetPtrCurDkNm
.global _InsertRecord
.global _NextRecord
.global _OpenRecordFile
.global _PointRecord
.global _PreviousRecord
.global _ReadByte
.global _ReadFile
.global _ReadRecord
.global _RenameFile
.global _SaveFile
.global _SetDevice
.global _SetGDirEntry
.global _UpdateRecordFile
.global _WriteFile
.global _WriteRecord

.segment "files1a"

.ifndef wheels
Add2:
	AddVW 2, r6
return:
	rts
.endif

ASSERT_NOT_BELOW_IO

.ifdef wheels_external_readwrite_file
OReadFile:
.else
_ReadFile:
.endif
	jsr EnterTurbo
.ifdef wheels
	beqx @X
	rts
@X:
.else
	bnex return
.endif
	jsr InitForIO
	PushW r0
	LoadW r4, diskBlkBuf
	LoadB r5L, 2
	MoveW r1, fileTrScTab+2
@1:	jsr ReadBlock
	bnex @7
	ldy #$fe
	lda diskBlkBuf
	bne @2
	ldy diskBlkBuf+1
.ifdef wheels
	beq @6
.endif
	dey
	beq @6
@2:	lda r2H
	bne @3
	cpy r2L
	bcc @3
	beq @3
	ldx #BFR_OVERFLOW
	bne @7
@3:	sty r1L
	LoadB CPU_DATA, RAM_64K
.ifdef wheels_external_readwrite_file
	; special case RAM area occupied by this code
	lda r7H
	cmp #>$4F00
	bcc @4
	cmp #>$5200
	bcs @4
	jsr L50A4
	bra @Y
.endif
@4:	lda diskBlkBuf+1,y
	dey
	sta (r7),y
	bne @4
@Y:	LoadB CPU_DATA, KRNL_IO_IN
	AddB r1L, r7L
	bcc @5
	inc r7H
@5:	SubB r1L, r2L
	bcs @6
	dec r2H
@6:	inc r5L
	inc r5L
	ldy r5L
	MoveB diskBlkBuf+1, r1H
	sta fileTrScTab+1,y
	MoveB diskBlkBuf, r1L
	sta fileTrScTab,y
	bne @1
	ldx #0
@7:	PopW r0
	jmp DoneWithIO

.ifdef wheels_external_readwrite_file
L50A4:	PushB r10L
	PushW r9
	PushW r3
	PushW r2
	PushW r1
	PushW r0
	ldx #0
	sty r10L
	MoveW r7, r9
@1:	lda r9H
	cmp #>$5000
	bne @2
	lda r9L
	cmp #<$5000
@2:	bcc @4
	lda r9H
	cmp #>$51C2
	bne @3
	lda r9L
	cmp #<$51C2
@3:	bcc @6
@4:	ldy #0
	lda diskBlkBuf+2,x
	sta (r9),y
	clc
	lda #1
	adc r9L
	sta r9L
	bcc @5
	inc r9H
@5:	inx
	cpx r10L
	bcc @1
	bcs @8
@6:	jsr @9
	clc
	lda r9L
	adc r2L
	sta r9L
	lda r9H
	adc r2H
	sta r9H
	clc
	lda r0L
	adc r2L
	bcs @8
	tax
	dex
	dex
	cpx r10L
	bcs @8
	ldy #0
@7:	lda diskBlkBuf+2,x
	sta (r9),y
	iny
	inx
	cpx r10L
	bcc @7
@8:	PopW r0
	PopW r1
	PopW r2
	PopW r3
	PopW r9
	PopB r10L
	rts
@9:	sec
	lda r9L
	sbc #<$5000
	sta r1L
	lda r9H
	sbc #>$5000
	sta r1H
	txa
	clc
	adc #2
	sta r0L
	lda #$80
	sta r0H
	stx r2L
	sec
	lda r10L
	sbc r2L
	sta r2L
	lda #$00
	sta r2H
	clc
	lda r1L
	adc r2L
	sta r3L
	lda r1H
	adc r2H
	sta r3H
	lda r3H
	cmp #$01
	bne @A
	lda r3L
	cmp #$C2
@A:	bcc @B
	sec
	lda r3L
	sbc #$C2
	sta r3L
	lda r3H
	sbc #$01
	sta r3H
	sec
	lda r2L
	sbc r3L
	sta r2L
	lda r2H
	sbc r3H
	sta r2H
@B:	clc
	lda #$27
	adc r1L
	sta r1L
	lda #$06
	adc r1H
	sta r1H
	lda ramExpSize
	sta r3L
	inc ramExpSize
	jsr StashRAM
	dec ramExpSize
	rts
.endif

.ifndef wheels_external_readwrite_file
FlaggedPutBlock:
	lda verifyFlag
	beq @1
	jmp VerWriteBlock
@1:	jmp WriteBlock
.endif

.segment "files1b"

.ifdef wheels_external_readwrite_file
OWriteFile:
.else
_WriteFile:
.endif
	jsr EnterTurbo
.ifdef wheels
	beqx @X
	rts
@X:
.else
	bnex @2
	sta verifyFlag
.endif
	jsr InitForIO
	LoadW r4, diskBlkBuf
	PushW r6
	PushW r7
.ifndef wheels
	jsr DoWriteFile
	PopW r7
	PopW r6
	bnex @1
	dec verifyFlag
	jsr DoWriteFile
@1:	jsr DoneWithIO
@2:	rts

.endif
DoWriteFile:
	ldy #0
	lda (r6),y
	beq @2
	sta r1L
	iny
	lda (r6),y
	sta r1H
	dey
.ifdef wheels ; XXX why?
	AddVW 2, r6
.else
	jsr Add2
.endif
	lda (r6),y
	sta (r4),y
	iny
	lda (r6),y
	sta (r4),y
	ldy #$fe
	LoadB CPU_DATA, RAM_64K
.ifdef wheels_external_readwrite_file
; special case RAM area occupied by this code
	lda r7H
	cmp #>$4F00
	bcc @1
	cmp #>$5200
	bcs @1
	jsr L5086
	bra @Y
.endif
@1:	dey
	lda (r7),y
	sta diskBlkBuf+2,y
	tya
	bne @1
@Y:	LoadB CPU_DATA, KRNL_IO_IN
.ifdef wheels
	jsr WriteBlock
	bnex @3
	clc
	lda #$FE
	adc r7L
	sta r7L
	bcc DoWriteFile
	inc r7H
	bne DoWriteFile
.else
	jsr FlaggedPutBlock
	bnex @3
	AddVW $fe, r7
	bra DoWriteFile
.endif
@2:	tax
@3:
.ifdef wheels
	PopW r7
	PopW r6
	jmp DoneWithIO
.else
	rts
.endif

.ifdef wheels_external_readwrite_file
L5086:	PushW r9
	PushW r3
	PushW r2
	PushW r1
	PushW r0
	ldx #2
	lda r7H
	sta r9H
	lda r7L
	sta r9L
@1:	lda r9H
	cmp #>$5000
	bne @2
	lda r9L
	cmp #<$5000
@2:	bcc @4
	lda r9H
	cmp #$51
	bne @3
	lda r9L
	cmp #$5F
@3:	bcc @6
@4:	ldy #$00
	lda (r9),y
	sta diskBlkBuf,x
	clc
	lda #1
	adc r9L
	sta r9L
	bcc @5
	inc r9H
@5:	inx
	bne @1
	beq @B
@6:	jsr @C
	ldx r0L
@7:	clc
	lda #$01
	adc r9L
	sta r9L
	bcc @8
	inc r9H
@8:	inx
	beq @B
	lda r9H
	cmp #$51
	bne @9
	lda r9L
	cmp #$5F
@9:	bcc @7
	ldy #$00
@A:	lda (r9),y
	sta diskBlkBuf,x
	iny
	inx
	bne @A
@B:	PopW r0
	PopW r1
	PopW r2
	PopW r3
	PopW r9
	rts
@C:	sec
	lda r9L
	sbc #$00
	sta r1L
	lda r9H
	sbc #$50
	sta r1H
	stx r0L
	lda #$80
	sta r0H
	dex
	txa
	eor #$FF
	sta r2L
	lda #$00
	sta r2H
	clc
	lda #$7B
	adc r1L
	sta r1L
	lda #$0D
	adc r1H
	sta r1H
	lda ramExpSize
	sta r3L
	inc ramExpSize
	jsr FetchRAM
	dec ramExpSize
	rts
.endif

ASSERT_NOT_BELOW_IO

.segment "files2"

.define DkNmTab DrACurDkNm, DrBCurDkNm, DrCCurDkNm, DrDCurDkNm
DkNmTabL:
	.lobytes DkNmTab
DkNmTabH:
	.hibytes DkNmTab

.segment "files3"

_GetPtrCurDkNm:
	ldy curDrive
	lda DkNmTabL-8,Y
	sta zpage,x
	lda DkNmTabH-8,Y
	sta zpage+1,x
	rts

.segment "files6"

_FollowChain:
.ifdef wheels
.import WheelsTemp
	php
	sei
	jsr LoadDiskBlkBuf
	PushB r3H
	lda #0
	sta WheelsTemp
@1:	jsr GetLink
@2:	bnex @5
	ldy WheelsTemp
	lda r1L
	sta (r3),y
	iny
	lda r1H
	sta (r3),y
	iny
	sty WheelsTemp
	bne @3
	inc r3H
@3:	lda r1L
	beq @6
	lda diskBlkBuf
	bne @4
	jsr GetBlock
@4:	lda r3H
	cmp #>OS_VARS
	bcs @5
	MoveW diskBlkBuf, r1
	bne @1
	beq @2
@5:	ldx #BFR_OVERFLOW
@6:	PopB r3H
	plp
	rts
.else
	php
	sei
	PushB r3H
	ldy #0
@1:	lda r1L
	sta (r3),y
	iny
	lda r1H
	sta (r3),y
	iny
	bne @2
	inc r3H
@2:	lda r1L
	beq @3
	tya
	pha
	jsr ReadBuff
	pla
	tay
	bnex @4
	MoveW diskBlkBuf, r1
	bra @1
@3:	ldx #0
@4:	PopB r3H
	plp
	rts
.endif

.ifdef wheels ; common code
LoadDiskBlkBuf:
	LoadW r4, diskBlkBuf
	rts
.endif

_FindFTypes:
.ifdef wheels
.import fftIndicator
	bit fftIndicator
	bmi LD5FD
	lda r6H
	sta r1H
	lda r6L
	sta r1L
	lda #$00
	sta r0H
	lda r7H
	asl
	rol r0H
	asl
	rol r0H
	asl
	rol r0H
	asl
	rol r0H
	adc r7H
	sta r0L
	bcc LD5FA
	inc r0H
LD5FA:	jsr ClearRam
LD5FD:	jsr Get1stDirEntry
	txa
	bne LD661
LD603:	ldy #$00
	lda (r5),y
	beq LD658
	ldy #$16
	lda r7L
	cmp #$64
	beq LD624
	cmp #$65
	bne LD61B
	lda (r5),y
	beq LD658
	bne LD624
LD61B:	cmp (r5),y
	bne LD658
	jsr GetHeaderFileName
	bne LD658
LD624:	clc
	lda r5L
	adc #$03
	sta r0L
	lda r5H
	adc #$00
	sta r0H
	ldy #$00
LD633:	lda (r0),y
	cmp #$A0
	beq LD640
	sta (r6),y
	iny
	cpy #$10
	bne LD633
LD640:	lda #$00
	sta (r6),y
	bit fftIndicator
	bmi LD663
	clc
	lda #$11
	adc r6L
	sta r6L
	bcc LD654
	inc r6H
LD654:	dec r7H
	beq LD661
LD658:	jsr GetNxtDirEntry
	txa
	bne LD661
	tya
	beq LD603
LD661:	sec
	rts

LD663:	lda r5H
	sta LD685
	lda r5L
	sta LD684
	LoadW r5, LD677
	clc
	rts

LD677:	lda LD685
	sta r5H
	lda LD684
	sta r5L
	jmp LD658

LD684:	.byte 0
LD685:	.byte 0

.else
.ifdef useRamExp
	CmpWI r7, ($0100+SYSTEM)
	bne FFTypesStart
	CmpWI r6, $8b80
	bne FFTypesStart
	LoadB DeskTopOpen, 1
	LoadW r5, DeskTopName
	ldx #r5
	ldy #r6
	jmp CopyString
FFTypesStart:
.endif
	php
	sei
	MoveW r6, r1
	LoadB r0H, 0
	lda r7H
	asl
	rol r0H
	asl
	rol r0H
	asl
	rol r0H
	asl
	rol r0H
	adc r7H
	sta r0L
	bcc @1
	inc r0H
@1:	jsr ClearRam
	SubVW 3, r6
	jsr Get1stDirEntry
	bnex @7

.ifdef trap
	; sabotage code: breaks LdDeskAcc if
	; _UseSystemFont hasn't been called before this
	ldx #>GetSerialNumber
	lda #<GetSerialNumber
	jsr CallRoutine
	lda r0H
	cmp SerialHiCompare
	beq @2
	inc LdDeskAcc+1
.endif

@2:	ldy #OFF_CFILE_TYPE
	lda (r5),y
	beq @6
	ldy #OFF_GFILE_TYPE
	lda (r5),y
	cmp r7L
	bne @6
	jsr GetHeaderFileName
	bnex @7
	tya
	bne @6
	ldy #OFF_FNAME
@3:	lda (r5),y
	cmp #$a0
	beq @4
	sta (r6),y
	iny
	cpy #OFF_FNAME + $10
	bne @3
@4:	lda #NULL
	sta (r6),y
	clc
	lda #$11
	adc r6L
	sta r6L
	bcc @5
	inc r6H
@5:	dec r7H
	beq @7
@6:	jsr GetNxtDirEntry
	bnex @7
	tya
	beq @2
@7:	plp
	rts
.endif

SetBufTSVector:
	LoadW r6, fileTrScTab
	rts

GetStartHAddr:
	MoveW fileHeader + O_GHST_ADDR, r7
	rts

SetFHeadVector:
	LoadW r4, fileHeader
	rts

_FindFile:
.ifdef wheels
	sec
	lda r6L
	sbc #3
	sta r6L
	bcs @1
	dec r6H
@1:	jsr Get1stDirEntry
	txa
	bne @8
@2:	ldy #0
	lda (r5),y
	beq @5
	ldy #3
@3:	lda (r6),y
	beq @4
	cmp (r5),y
	bne @5
	iny
	bne @3
@4:	cpy #OFF_FNAME + $10
	beq @6
	lda (r5),y
	iny
	cmp #$A0
	beq @4
@5:	jsr GetNxtDirEntry
	txa
	bne @8
	tya
	beq @2
	ldx #FILE_NOT_FOUND
	rts
@6:	ldy #29
@7:	lda (r5),y
	sta dirEntryBuf,y
	dey
	bpl @7
@8:	rts
.else
	php
	sei
	SubVW 3, r6
	jsr Get1stDirEntry
	bnex @7
@1:	ldy #OFF_CFILE_TYPE
	lda (r5),y
	beq @4
	ldy #OFF_FNAME
@2:	lda (r6),y
	beq @3
	cmp (r5),y
	bne @4
	iny
	bne @2
@3:	cpy #OFF_FNAME + $10
	beq @5
	lda (r5),y
	iny
	cmp #$a0
	beq @3
@4:	jsr GetNxtDirEntry
	bnex @7
	tya
	beq @1
	ldx #FILE_NOT_FOUND
	bne @7
@5:	ldy #0
@6:	lda (r5),y
	sta dirEntryBuf,y
	iny
	cpy #$1e
	bne @6
	ldx #NULL
@7:	plp
	rts
.endif

_SetDevice:
.ifdef wheels
	tax
	beq @7
	cmp curDevice
	beq @2
	jsr IsCurDeviceValid
	bcs @1
	lda curDrive
	jsr IsDeviceValid
	bcs @1
	jsr ExitTurbo
@1:	stx curDevice
@2:	jsr IsCurDeviceValid
	bcs @6
	tay
	lda _driveType,y
	sta curType
	beq @7
	cpy curDrive
	beq @6
	sty curDrive
	lda SetDevDrivesTabL-8,y
	sta SetDevTab + 2
	lda SetDevDrivesTabH-8,y
	sta SetDevTab + 3
	ldx #6
@3:	lda r0,x
	pha
	lda SetDevTab,x
	sta r0,x
	dex
	bpl @3
	lda curType
	and #$0F
	cmp #DRV_1581
	bne @4
	dec r2H
@4:	jsr FetchRAM
	ldx #0
@5:	pla
	sta r0,x
	inx
	cpx #7
	bne @5
@6:	ldx #0
	rts
@7:	ldx #DEV_NOT_FOUND
	rts

IsCurDeviceValid:
	lda curDevice
IsDeviceValid:
	cmp #8
	bcc @1
	cmp #12
	rts
@1:	sec
	rts
.else
	nop
	cmp curDevice
	beq @2
	pha
	CmpBI curDevice, 8
	bcc @1
	cmp #12
	bcs @1
	jsr ExitTurbo
@1:	pla
	sta curDevice
@2:	cmp #8
	bcc @3
	cmp #12
	bcs @3
	tay
	lda _driveType,y
	sta curType
	cpy curDrive
	beq @3
	sty curDrive
	bbrf 6, sysRAMFlg, @3
	lda SetDevDrivesTabL - 8,y
	sta SetDevTab + 2
	lda SetDevDrivesTabH - 8,y
	sta SetDevTab + 3
	jsr PrepForFetch
	jsr FetchRAM
	jsr PrepForFetch
@3:	ldx #NULL
	rts

PrepForFetch:
	ldy #6
@1:	lda r0,y
	tax
	lda SetDevTab,y
	sta r0,y
	txa
	sta SetDevTab,y
	dey
	bpl @1
	rts
.endif

SetDevTab:
	.word DISK_BASE
.if .defined(cbmfiles) || .defined(wheels)
	; This should be initialized to 0, and will
	; be changed at runtime.
	; The cbmfiles version was created by dumping
	; KERNAL from memory after it had been running,
	; so it has a different value here.
	.word REUDskDrvSPC
.else
	.word 0
.endif
	.word DISK_DRV_LGH
	.byte 0

.define SetDevDrivesTab REUDskDrvSPC+0*DISK_DRV_LGH, REUDskDrvSPC+1*DISK_DRV_LGH, REUDskDrvSPC+2*DISK_DRV_LGH, REUDskDrvSPC+3*DISK_DRV_LGH
SetDevDrivesTabL:
	.lobytes SetDevDrivesTab
SetDevDrivesTabH:
	.hibytes SetDevDrivesTab

_GetFHdrInfo:
	ldy #OFF_GHDR_PTR
	lda (r9),y
	sta r1L
.ifdef wheels
	sta fileTrScTab
.endif
	iny
	lda (r9),y
	sta r1H
.ifdef wheels
	sta fileTrScTab+1
.else
	MoveW r1, fileTrScTab
.endif
	jsr SetFHeadVector
	jsr GetBlock
.ifdef wheels
	bne @1
.else
	bnex @1
.endif
	ldy #OFF_DE_TR_SC
.ifdef wheels
	jsr ReadR9
.else
	lda (r9),y
	sta r1L
	iny
	lda (r9),y
	sta r1H
.endif
	jsr GetStartHAddr
@1:	rts

.ifdef wheels
.global ReadR9
ReadR9:	lda (r9),y
	sta r1L
	iny
	lda (r9),y
	sta r1H
	rts
.endif

GetHeaderFileName:
	ldx #0
	lda r10L
	ora r10H
	beq @2
	ldy #OFF_GHDR_PTR
	lda (r5),y
	sta r1L
	iny
	lda (r5),y
	sta r1H
	jsr SetFHeadVector
	jsr GetBlock
.ifdef wheels
        bne @4
.else
	bnex @4
.endif
	tay
@1:	lda (r10),y
	beq @2
	cmp fileHeader+O_GHFNAME,y
	bne @3
	iny
	bne @1
@2:	ldy #0
	rts
@3:	ldy #$ff
@4:	rts

.segment "files7"

.ifdef trap
SerialHiCompare:
.ifdef cbmfiles
	; This should be initialized to 0, and will
	; be changed at runtime.
	; The cbmfiles version was created by dumping
	; KERNAL from memory after it had been running,
	; so it has a pre-filled value here.
	.byte $58
.else
	.byte 0
.endif
.endif

.segment "files8"

_SaveFile:
	ldy #0
@1:	lda (r9),y
	sta fileHeader,y
	iny
	bne @1
	jsr GetDirHead
.ifdef wheels
	bne @2
.else
	bnex @2
.endif
	jsr GetDAccLength
	jsr SetBufTSVector
	jsr BlkAlloc
	bnex @2
	jsr SetBufTSVector
	jsr SetGDirEntry
	bnex @2
	jsr PutDirHead
.ifdef wheels
	bne @2
.else
	bnex @2
.endif
	sta fileHeader+O_GHINFO_TXT
.ifdef wheels
	MoveW_ dirEntryBuf+OFF_GHDR_PTR, r1
.else
	MoveW dirEntryBuf+OFF_GHDR_PTR, r1
.endif
	jsr SetFHeadVector
	jsr PutBlock
.ifdef wheels
	bne @2
.else
	bnex @2
.endif
	jsr ClearNWrite
	bnex @2
	jsr GetStartHAddr
	jsr WriteFile
@2:	rts

GetDAccLength:
.ifdef wheels
	jsr LD8D3
	jsr @1
	CmpBI fileHeader+O_GHSTR_TYPE, VLIR
	bne @2
@1:	clc
	lda #$fe
	adc r2L
	sta r2L
	bcc @2
	inc r2H
@2:	rts
.else
	lda fileHeader+O_GHEND_ADDR
	sub fileHeader+O_GHST_ADDR
	sta r2L
	lda fileHeader+O_GHEND_ADDR+1
	sbc fileHeader+O_GHST_ADDR+1
	sta r2H
	jsr @1
	CmpBI fileHeader+O_GHSTR_TYPE, VLIR
	bne @2
@1:	AddVW $fe, r2
@2:	rts
.endif

.ifdef wheels ; reused code
.global LD8D3
LD8D3:	lda fileHeader+O_GHEND_ADDR
	sub fileHeader+O_GHST_ADDR
	sta r2L
	lda fileHeader+O_GHEND_ADDR+1
	sbc fileHeader+O_GHST_ADDR+1
	sta r2H
	rts
.endif

ClearNWrite:
	ldx #0
	CmpBI dirEntryBuf+OFF_GSTRUC_TYPE, VLIR
	bne @2
	MoveW dirEntryBuf+OFF_DE_TR_SC, r1
	txa
	tay
@1:	sta diskBlkBuf,y
	iny
	bne @1
	dey
	sty diskBlkBuf+1
	jsr WriteBuff
@2:	rts

_SetGDirEntry:
	jsr BldGDirEntry
	jsr GetFreeDirBlk
	bnex SGDCopyDate_rts
.ifdef wheels
	sty r5L
	.assert <diskBlkBuf = 0, error, "diskBlkBuf must be page-aligned!"
.else
	tya
	addv <diskBlkBuf
	sta r5L
.endif
	lda #>diskBlkBuf
.ifndef wheels
	adc #0
.endif
	sta r5H
	ldy #$1d
@1:	lda dirEntryBuf,y
	sta (r5),y
	dey
	bpl @1
	jsr SGDCopyDate
	jmp WriteBuff

SGDCopyDate:
	ldy #$17
@1:	lda dirEntryBuf+$ff,y
	sta (r5),y
	iny
	cpy #$1c
	bne @1
SGDCopyDate_rts:
	rts

.ifdef wheels ; moved and optimized
Add2:	clc
        lda     #2
        adc     r6L
        sta     r6L
        bcc     @1
        inc     r6H
@1:	rts
.endif

_BldGDirEntry:
	ldy #$1d
	lda #0
@1:	sta dirEntryBuf,y
	dey
	bpl @1
.ifdef wheels
	ldy #1
	lda (r9),y
	sta r3H
	dey
	lda (r9),y
	sta r3L
@2:	lda (r3),y
	beq @3
	sta dirEntryBuf+OFF_FNAME,y
	iny
	cpy #16
	bcc @2
	bcs @5
@3:	lda #$a0
@4:	sta dirEntryBuf+OFF_FNAME,y
	iny
	cpy #16
	bcc @4
.else
	tay
	lda (r9),y
	sta r3L
	iny
	lda (r9),y
	sta r3H
	sty r1H
	dey
	ldx #OFF_FNAME
@2:	lda (r3),y
	bne @4
	sta r1H
@3:	lda #$a0
@4:	sta dirEntryBuf,x
	inx
	iny
	cpy #16
	beq @5
	lda r1H
	bne @2
	beq @3
.endif
@5:	ldy #O_GHCMDR_TYPE
	lda (r9),y
	sta dirEntryBuf+OFF_CFILE_TYPE
.ifndef wheels
	ldy #O_GHSTR_TYPE
	lda (r9),y
	sta dirEntryBuf+OFF_GSTRUC_TYPE
.endif
	ldy #NULL
	sty fileHeader
	dey
	sty fileHeader+1
	MoveW fileTrScTab, dirEntryBuf+OFF_GHDR_PTR
	jsr Add2
	MoveW fileTrScTab+2, dirEntryBuf+OFF_DE_TR_SC
.ifdef wheels
	ldy #O_GHSTR_TYPE
	lda (r9),y
	sta dirEntryBuf+OFF_GSTRUC_TYPE
	cmp #VLIR
.else
	CmpBI dirEntryBuf+OFF_GSTRUC_TYPE, VLIR
.endif
	bne @6
	jsr Add2
@6:	ldy #O_GHGEOS_TYPE
	lda (r9),y
	sta dirEntryBuf+OFF_GFILE_TYPE
	MoveW r2, dirEntryBuf+OFF_SIZE
	rts

_DeleteFile:
	jsr FindNDelete
	beqx @1
	rts
@1:	LoadW r9, dirEntryBuf
_FreeFile:
	php
	sei
	jsr GetDirHead
.ifdef wheels
	bne @3
.else
	bnex @3
.endif
	ldy #OFF_GHDR_PTR
	lda (r9),y
	beq @1
	sta r1L
	iny
	lda (r9),y
	sta r1H
	jsr FreeBlockChain
	bnex @3
@1:	ldy #OFF_DE_TR_SC
.ifdef wheels
	jsr ReadR9
	jsr SetFHeadVector
	jsr GetBlock
	bne @3
.else
	lda (r9),y
	sta r1L
	iny
	lda (r9),y
	sta r1H
.endif
	jsr FreeBlockChain
	bnex @3
	ldy #OFF_GSTRUC_TYPE
	lda (r9),y
.ifdef onlyVLIR
	beq @2
.else
	cmp #VLIR
	bne @2
.endif
	jsr DeleteVlirChains
	bnex @3
@2:	jsr PutDirHead
@3:	plp
	rts

DeleteVlirChains:
.ifdef wheels
	ldx #2
@1:	lda fileHeader+1,x
	sta r1H
	lda fileHeader,x
	sta r1L
	beq @2
	txa
	pha
	jsr FreeBlockChain
	pla
	cpx #0
	bne @3
	tax
@2:	inx
	inx
	bne @1
@3:	rts
.else
	ldy #0
@1:	lda diskBlkBuf,y
	sta fileHeader,y
	iny
	bne @1
	ldy #2
@2:	tya
	beq @3
	lda fileHeader,y
	sta r1L
	iny
	lda fileHeader,y
	sta r1H
	iny
	lda r1L
	beq @2
	tya
	pha
	jsr FreeBlockChain
	pla
	tay
	beqx @2
@3:	rts
.endif

FreeBlockChain:
.ifdef wheels
	php
	sei
	MoveW r1, r6
	jsr LoadDiskBlkBuf
	LoadW_ r2, 0
@1:	jsr FreeBlock
	beqx @2
	cpx #BAD_BAM
	bne @4
@2:	inc r2L
	bne @3
	inc r2H
@3:	jsr GetLink
	txa
	bne @4
	lda diskBlkBuf+1
	sta r6H
	sta r1H
	lda diskBlkBuf
	sta r6L
	sta r1L
	bne @1
@4:	plp
	rts
.else
	MoveW r1, r6
	LoadW_ r2, 0
@1:	jsr FreeBlock
	bnex @4
	inc r2L
	bne @2
	inc r2H
@2:	PushW r2
	MoveW r6, r1
	jsr ReadBuff
	PopW r2
	bnex @4
	lda diskBlkBuf
	beq @3
	sta r6L
	lda diskBlkBuf+1
	sta r6H
	bra @1
@3:	ldx #NULL
@4:	rts
.endif

FindNDelete:
	MoveW r0, r6
	jsr FindFile
.ifdef wheels
	bnex LDAB8
.else
	bnex @1
	lda #0
.endif
	tay
	sta (r5),y
.ifdef wheels
	jmp WriteBuff
.else
	jsr WriteBuff
@1:	rts
.endif

_FastDelFile:
	PushW r3
	jsr FindNDelete
	PopW r3
.ifdef wheels_size_and_speed ; inlined
	bnex LDAB8
	PushW r3
	jsr GetDirHead
	PopW r3
@X:	ldy #0
	lda (r3),y
	beq @Y
	sta r6L
	iny
	lda (r3),y
	sta r6H
	jsr FreeBlock
	txa
	bne LDAB8
	clc
	lda #2
	adc r3L
	sta r3L
	bcc @X
	inc r3H
	bne @X
@Y:	jmp PutDirHead
LDAB8:	rts
.else
	bnex @1
	jsr FreeChainByTab
@1:	rts

FreeChainByTab:
	PushW r3
	jsr GetDirHead
	PopW r3
@1:	ldy #0
	lda (r3),y
	beq @2
	sta r6L
	iny
	lda (r3),y
	sta r6H
	jsr FreeBlock
	bnex @3
	AddVW 2, r3
	bra @1
@2:
	jsr PutDirHead
@3:
	rts
.endif

_RenameFile:
	PushW r0
	jsr FindFile
	PopW r0
	bnex @4
	AddVW OFF_FNAME, r5
	ldy #0
@1:	lda (r0),y
	beq @2
	sta (r5),y
	iny
	cpy #16
	bcc @1
	bcs @3
@2:	lda #$a0
	sta (r5),y
	iny
	cpy #16
	bcc @2
@3:
.ifdef wheels
	jmp WriteBuff
.else
	jsr WriteBuff
.endif
@4:	rts

_OpenRecordFile:
.ifdef useRamExp
	lda DeskTopOpen
	bmi OpRFile1
	LoadW r6, DeskTopName
	ldx #r0
	ldy #r6
	jsr CmpString
	bne OpRFile1
	LoadB DeskTopOpen,1
	ldx #0
	rts
OpRFile1:
	LoadB DeskTopOpen,0
.endif
	MoveW r0, r6
	jsr FindFile
	bnex ClearRecordTableTS
	ldx #10
	ldy #OFF_CFILE_TYPE
	lda (r5),y
	and #%00111111
	cmp #USR
	bne ClearRecordTableTS
	ldy #OFF_GSTRUC_TYPE
	lda (r5),y
.ifdef onlyVLIR
	beq ClearRecordTableTS
.else
	cmp #VLIR
	bne ClearRecordTableTS
.endif
	ldy #OFF_DE_TR_SC
	lda (r5),y
	sta RecordTableTS
	iny
	lda (r5),y
	sta RecordTableTS+1
	MoveW r1, RecordDirTS
	MoveW r5, RecordDirOffs
	MoveW dirEntryBuf+OFF_SIZE, fileSize
	jsr GetVLIRTab
	bnex ClearRecordTableTS
	sta usedRecords
	ldy #2
@1:	lda fileHeader,y
	ora fileHeader+1,y
	beq @2
	inc usedRecords
	iny
	iny
	bne @1
@2:	ldy #0
	lda usedRecords
	bne @3
	dey
@3:	sty curRecord
	ldx #NULL
	stx fileWritten
	rts

_CloseRecordFile:
	jsr _UpdateRecordFile
ClearRecordTableTS:
	LoadB RecordTableTS, NULL
	rts

_UpdateRecordFile:
	ldx #0
	lda fileWritten
	beq @1
	jsr PutVLIRTab
	bnex @1
	MoveW RecordDirTS, r1
	jsr ReadBuff
.ifdef wheels
	bne @1
.else
	bnex @1
.endif
	MoveW RecordDirOffs, r5
	jsr SGDCopyDate
	ldy #OFF_SIZE
	lda fileSize
	sta (r5),y
	iny
	lda fileSize+1
	sta (r5),y
	jsr WriteBuff
.ifdef wheels
	bne @1
.else
	bnex @1
.endif
	jsr PutDirHead
	lda #NULL
	sta fileWritten
@1:	rts

.ifdef useRamExp
_NextRecord:
	lda curRecord
	addv 1
	bra _PointRcrdSt
_PreviousRecord:
	lda curRecord
	subv 1
	bra _PointRcrdSt

_PointRecord:
	ldx DeskTopOpen
	beq _PointRcrdSt
	sta DeskTopRecord
	ldx #0
	rts
_PointRcrdSt:
.else
_NextRecord:
	lda curRecord
	addv 1
	bra _PointRecord
_PreviousRecord:
	lda curRecord
	subv 1
_PointRecord:
.endif

	tax
	bmi @1
	cmp usedRecords
	bcs @1
	sta curRecord
	jsr GetVLIRChainTS
.ifdef wheels
	tay
.else
	ldy r1L
.endif
	ldx #0
	beq @2
@1:	ldx #INV_RECORD
@2:	lda curRecord
	rts

_DeleteRecord:
.ifdef wheels_size
	jsr ReadyForUpdVLIR2
.else
	ldx #INV_RECORD
	lda curRecord
	bmi return2
	jsr ReadyForUpdVLIR
.endif
	bnex return2
	jsr GetVLIRChainTS
	MoveB curRecord, r0L
	jsr MoveBackVLIRTab
	bnex return2
	CmpB curRecord, usedRecords
	bcc @1
	dec curRecord
@1:	ldx #NULL
	lda r1L
	beq return2
	jsr FreeBlockChain
	bnex return2
	SubB r2L, fileSize
	bcs @2
	dec fileSize+1
@2:
.ifndef wheels
	ldx #NULL
.endif
return2:
	rts

_InsertRecord:
.ifdef wheels_size ; use common code
	jsr ReadyForUpdVLIR2
	bnex return2
	lda curRecord
	sta r0L
	jmp MoveForwVLIRTab
.else
	ldx #INV_RECORD
	lda curRecord
	bmi @1
	jsr ReadyForUpdVLIR
	bnex @1
	lda curRecord
	sta r0L
	jsr MoveForwVLIRTab
@1:	rts
.endif

.ifdef wheels_size ; reused code
ReadyForUpdVLIR2:
	ldx #INV_RECORD
	lda curRecord
	bmi return2
	jmp ReadyForUpdVLIR
.endif

_AppendRecord:
	jsr ReadyForUpdVLIR
	bnex @1
	lda curRecord
	addv 1
	sta r0L
	jsr MoveForwVLIRTab
	bnex @1
	MoveB r0L, curRecord
@1:	rts

_ReadRecord:
.ifdef useRamExp
	ldx DeskTopOpen
	beq ReaRec0
	jsr RamExpGetStat
	ldx DeskTopRecord
	lda diskBlkBuf+DTOP_CHAIN,x
	sta r1L
	lda diskBlkBuf+DTOP_CHAIN+1,x
	sub r1L
	sta r2H
	LoadB r1H, 0
	MoveW r7, r0
	jsr RamExpRead
	ldx #0
	rts
ReaRec0:
.endif
	ldx #INV_RECORD
	lda curRecord
	bmi @1
	jsr GetVLIRChainTS
.ifndef wheels
	lda r1L
.endif
	tax
	beq @1
	jsr ReadFile
	lda #$ff
@1:	rts

_WriteRecord:
.ifndef wheels
	ldx #INV_RECORD
	lda curRecord
	bmi @5
.endif
	PushW r2
.ifdef wheels_size
	jsr ReadyForUpdVLIR2
.else
	jsr ReadyForUpdVLIR
.endif
	PopW r2
	bnex @5
	jsr GetVLIRChainTS
.ifndef wheels
	lda r1L
.endif
	bne @1
	ldx #0
	lda r2L
	ora r2H
.ifdef wheels
	bne @3
@5:	rts
.else
	beq @5
	bne @3
.endif
@1:	PushW r2
	PushW r7
	jsr FreeBlockChain
	MoveB r2L, r0L
	PopW r7
	PopW r2
	bnex @5
	SubB r0L, fileSize
	bcs @2
	dec fileSize+1
@2:	lda r2L
	ora r2H
	beq @4
@3:	jmp WriteVLIRChain
@4:	ldy #$FF
	sty r1H
	iny
	sty r1L
.ifdef wheels
	jmp PutVLIRChainTS
.else
	jsr PutVLIRChainTS
@5:	rts
.endif

GetVLIRTab:
	jsr SetVLIRTable
	bnex @1
	jsr GetBlock
@1:	rts

PutVLIRTab:
	jsr SetVLIRTable
	bnex @1
	jsr PutBlock
@1:	rts

SetVLIRTable:
	ldx #UNOPENED_VLIR
	lda RecordTableTS
	beq @1
	sta r1L
	lda RecordTableTS+1
	sta r1H
	jsr SetFHeadVector
	ldx #NULL
@1:	rts

MoveBackVLIRTab:
	ldx #INV_RECORD
	lda r0L
	bmi @3
	asl
	tay
	lda #$7e
	sub r0L
	asl
	tax
	beq @2
@1:	lda fileHeader+4,y
	sta fileHeader+2,y
	iny
	dex
	bne @1
@2:	stx fileHeader+$fe
	stx fileHeader+$ff
	dec usedRecords
@3:	rts

MoveForwVLIRTab:
	ldx #OUT_OF_RECORDS
	CmpBI usedRecords, $7f
	bcs @3
	ldx #INV_RECORD
	lda r0L
	bmi @3
	ldy #$fe
	lda #$7e
	sub r0L
	asl
	tax
	beq @2
@1:	lda fileHeader-1,y
	sta fileHeader+1,y
	dey
	dex
	bne @1
@2:	txa
	sta fileHeader,y
	lda #$ff
	sta fileHeader+1,y
	inc usedRecords
@3:	rts

GetVLIRChainTS:
	lda curRecord
	asl
	tay
.ifdef wheels
	lda fileHeader+3,y
	sta r1H
	lda fileHeader+2,y
	sta r1L
.else
	lda fileHeader+2,y
	sta r1L
	lda fileHeader+3,y
	sta r1H
.endif
	rts

PutVLIRChainTS:
	lda curRecord
	asl
	tay
	lda r1L
	sta fileHeader+2,y
	lda r1H
	sta fileHeader+3,y
	rts

WriteVLIRChain:
	jsr SetBufTSVector
	PushW r7
	jsr BlkAlloc
	PopW r7
	bnex @1
	PushB r2L
	jsr SetBufTSVector
	jsr WriteFile
	PopB r2L
	bnex @1
	MoveW fileTrScTab, r1
	jsr PutVLIRChainTS
	bnex @1
	AddB r2L, fileSize
	bcc @1
	inc fileSize+1
@1:	rts

ReadyForUpdVLIR:
	ldx #NULL
	lda fileWritten
	bne @1
	jsr GetDirHead
.ifdef wheels
	bne @1
.else
	bnex @1
.endif
	lda #$ff
	sta fileWritten
@1:	rts

_ReadByte:
	ldy r5H
	cpy r5L
	beq @2
	lda (r4),y
	inc r5H
	ldx #NULL
@1:	rts
@2:	ldx #BFR_OVERFLOW
	lda r1L
	beq @1
	jsr GetBlock
.ifdef wheels
	bne @1
.else
	bnex @1
.endif
	ldy #2
	sty r5H
	dey
	lda (r4),y
	sta r1H
	tax
	dey
	lda (r4),y
	sta r1L
	beq @3
	ldx #$ff
@3:	inx
	stx r5L
	bra _ReadByte

