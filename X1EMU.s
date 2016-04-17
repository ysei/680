*************************************************
*						*
*     Ｘ１エミュレータ for X68000 Ver 1.00	*
*						*
*	 Copyright 1993/03/21 森田 浩次		*
*						*
*************************************************

	.xdef	INTRQ
	.xdef	FCALL
	.xdef	S_CONT
	.xdef	D_CONT,D_KEY
	.xdef	D_CTC,C_CTC
	.xdef	V_KEY,V_CTC
	.xdef	F_REPT,F_SIFT,F_LOCK,F_KBF
	.xdef	A_RND

	.xref	Z80,A_BAS
	.xref	IFF1,V_INT
	.xref	A_MEM
	.xref	T_OPC,T_INT,T_NMI,T_RES

	.xref	EXTCG
	.xref	INITFM
	.xref	GETKEYI
	.xref	A_PALB,A_PALR,A_PALG
	.xref	FD0,FD1,FD2,FD3
	.xref	P_SUB
	.xref	P_EMM,P_ROM
	.xref	IPLROM,CGROM
	.xref	A_IOB
	.xref	END

D_CTC	equ	A_ICTC+2
V_CTC	equ	A_VCTC+3

aPC	equ	a3
aTO	equ	a4
aME	equ	a5
aBS	equ	a6


*---------------------------------------*
*	  Ｉ／Ｏポートアドレス		*
*---------------------------------------*

PwTEXTP2	equ	$E40000		* テキストプレーン２
PwTEXTP3	equ	$E60000		* テキストプレーン３
PwCRTC00	equ	$E80000		* CRTC R00
PsCRTC20	equ	$E80029		* CRTC R20 L
PwGRAPAL	equ	$E82000		* グラフィックパレット
PwTXTPAL	equ	$E82200		* テキストパレット
PsMFPGPI	equ	$E88001		* MFP GPIP  汎用Ｉ／Ｏレジスタ
PsMFPIEB	equ	$E88009		* MFP IERB  割り込みイネーブルレジスタＢ
PsMFPIMA	equ	$E88013		* MFP IMRA  割り込みマスクレジスタＡ
PsMFPIMB	equ	$E88015		* MFP IMRB  割り込みマスクレジスタＢ
PsMFPCDR	equ	$E88023		* MFP タイマＣデータレジスタ
PsMFPUDR	equ	$E8802F		* MFP USART データレジスタ
PsSCCBCP	equ	$E98001		* SCC チャンネルＢコマンドポート

A_RND	equ	PsMFPCDR


*---------------------------------------*
*		ＭＡＩＮ		*
*---------------------------------------*

	.text
START:
	jsr	SETBLOCK
	jsr	TITLE
	jsr	SWITCH
	jsr	CONFIG
	jsr	LDROM

	jsr	SUPER
	jsr	KEYLOCK
	jsr	SETVECT
	jsr	SETCRTC
	jsr	INITPAL
	jsr	EXTCG
	jsr	Z80

	jsr	INITFM
	jsr	RETCRTC
	jsr	RETVECT
	jsr	USER
EXIT:	dc.w	$FF00					* DOS _EXIT


*---------------------------------------*
*		SETBLOCK		*
*---------------------------------------*

SETBLOCK:
	move.l	#$F0+(END-START),-(sp)
	pea	$10(a0)
	dc.w	$FF4A					* DOS _SETBLOCK
	addq.l	#8,sp
	rts


*---------------------------------------*
*	      タイトル表示		*
*---------------------------------------*

TITLE:
	lea	MSTITL,a0
	jsr	PRINT
	rts

PRINT:
	pea	(a0)
	dc.w	$FF09					* DOS _PRINT
	addq.l	#4,sp
	rts


	.data
MSTITL:
	dc.b	'[1m'
	dc.b	'X1 Emulator for X68000'
	dc.b	'[m'
 	dc.b	' version 1.00',$0D,$0A
	dc.b	'Copyright 1993 Koji Morita',$0D,$0A
	dc.b	0

	.text


*---------------------------------------*
*	   LOAD IPLROM & CGROM		*
*---------------------------------------*

LDROM:
	lea	FNIPL,a0
	jsr	OPEN
	bmi.w	EROP
	lea	IPLROM,a1
	move.l	#$1000,d0
	jsr	READ
	bne.w	ERRD
	jsr	CLOSE

	lea	FNCG,a0
	jsr	OPEN
	bmi.w	EROP
	lea	CGROM,a1
	move.l	#$0800,d0
	jsr	READ
	bne.w	ERRD
	jsr	CLOSE

	rts

OPEN:
	move.w	#%0_0_000_00_00,-(sp)
	pea	(a0)
	dc.w	$FF3D					* DOS _OPEN
	addq.l	#6,sp
	move.w	d0,d2
	tst.l	d0
	rts

CLOSE:
	move.w	d2,-(sp)
	dc.w	$FF3E					* DOS _CLOSE
	addq.l	#2,sp
	rts

READ:
	move.l	d0,-(sp)
	move.l	d0,-(sp)
	pea	(a1)
	move.w	d2,-(sp)
	dc.w	$FF3F					* DOS _READ
	lea	10(sp),sp
	cmp.l	(sp)+,d0
	rts


EROP:	jsr	PRINT
	lea	MSEROP,a0
	bra.s	ERPRN

ERRD:	jsr	PRINT
	lea	MSERRD,a0
ERPRN:	jsr	PRINT
	dc.w	$FF00					* DOS _EXIT


	.data

FNIPL:	dc.b	'IPLROM.X1',0
FNCG:	dc.b	'CGROM.X1',0

MSEROP:	dc.b	' が見つかりません',$0D,$0A,0
MSERRD:	dc.b	' のサイズが違います',$0D,$0A,0

	.text


*---------------------------------------*
*		スイッチ		*
*---------------------------------------*

SWITCH:
	move.b	(a2)+,d0
	beq.s	RTSWT
SWTGET:
	jsr	SKIPSP
	beq.s	RTSWT
	cmpi.b	#'-',(a2)+
	bne.w	ERPAR
	move.b	(a2)+,d0
	jsr	CUPPER

	cmpi.b	#'F',d0
	beq.w	SWTCNF
	cmpi.b	#'D',d0
	beq.w	SWTFD
	cmpi.b	#'C',d0
	beq.s	SWTGET
	cmpi.b	#'E',d0
	beq.s	SWTGET
	cmpi.b	#'H',d0
	beq.w	SWTDSP
	cmpi.b	#'?',d0
	beq.w	SWTUSG
	bra.w	ERPAR

RTSWT:	rts


SWTCNF:
	jsr	SKIPSP
	lea	FNCNF,a0
	st	(a0)
	beq.s	SKSWCF
	cmpi.b	#'-',(a2)
	beq.s	SKSWCF
	jsr	COPYFN
SKSWCF:	jmp	SWTGET

SWTFD:
	jsr	SKIPSP
	lea	CHRFD,a0
	jsr	CMATCH
	bne.w	ERPAR

	move.b	(a2)+,d0
	lea	FD0,a0
	cmpi.b	#'0',d0
	beq.s	SWTCFD
	lea	FD1,a0
	cmpi.b	#'1',d0
	beq.s	SWTCFD
	lea	FD2,a0
	cmpi.b	#'2',d0
	beq.s	SWTCFD
	lea	FD3,a0
	cmpi.b	#'3',d0
	bne.w	ERPAR
SWTCFD:
	cmpi.b	#'=',(a2)+
	bne.w	ERPAR

	lea	F_FDS,a1
	move.l	a0,d0
	subi.l	#FD0,d0
	asr.l	#7,d0
	st	(a1,d0.l)

	jsr	COPYFN
	jmp	SWTGET

SWTDSP:
	st	F_DISP+1
	move.b	#1,F_DISP
	jmp	SWTGET

SWTUSG:
	lea	MSUSG,a0
	jsr	PRINT
	dc.w	$FF00					* DOS _EXIT

ERPAR:
	lea	MSERPR,a0
	jmp	ERPRN


CUPPER:
	cmpi.b	#'a',d0
	bcs.s	RTCUP
	cmpi.b	#'z',d0
	bhi.s	RTCUP
	subi.b	#$20,d0
RTCUP:	rts


LPSKSP:	addq.l	#1,a2
SKIPSP:	move.b	(a2),d0
	beq.s	RTSKSP
	cmpi.b	#' ',d0
	beq.s	LPSKSP
	cmpi.b	#$09,d0
	beq.s	LPSKSP
RTSKSP:	rts

CMATCH:
	tst.b	(a0)
	beq.s	RTCMAT
	move.b	(a2)+,d0
	jsr	CUPPER
	cmp.b	(a0)+,d0
	beq.s	CMATCH
RTCMAT:	rts

COPYFN:
	move.b	(a2)+,d0
	move.b	d0,(a0)+
	beq.s	RTCFN
	cmpi.b	#' ',d0
	beq.s	RTCFN
	cmpi.b	#$09,d0
	bne.s	COPYFN
RTCFN:
	clr.b	-(a0)
	tst.b	-(a2)
	rts

COPYFN2:
	move.b	(a2)+,(a0)+
	bne.s	COPYFN2
	rts


	.data
CHRFD:	dc.b	'FD',0
MSERPR:	dc.b	'パラメータが無効です',$0D,$0A,0
MSUSG:	dc.b   'switch:	-F FileName		CONFIGファイルの指定',$0D,$0A
	dc.b   '	-D FD{0-3}=FileName	2Dファイルの指定',$0D,$0A
	dc.b   '	-H			24kHzモード',$0D,$0A
	dc.b	0
	.text

	.bss
FNCNF:	ds.b	$80
	.text


*---------------------------------------*
*	      ＣＯＮＦＩＧ		*
*---------------------------------------*

CONFIG:
	lea	FNCNF,a0
	lea	(a0),a1
	move.b	(a1),d0
	beq.s	CNFDF
	addq.b	#1,d0
	beq.s	RTCNF2
LPCNF:
	move.b	(a1)+,d0
	beq.s	CNFEXT
	cmpi.b	#'.',d0
	bne.s	LPCNF
	bra.s	SKCNF

CNFDF:
	lea	FNCFDF,a0
	jsr	OPEN
	bmi.w	RTCNF2
	bra.s	CNFGET

CNFEXT:
	subq.l	#1,a1
	move.b	#'.',(a1)+
	move.b	#'X',(a1)+
	move.b	#'1',(a1)+
	move.b	#$00,(a1)+

SKCNF:	jsr	OPEN
	bmi.w	EROP
CNFGET:
	move.w	d2,-(sp)
	pea	B_CNF
	dc.w	$FF1C					* DOS _FGETS
	addq.l	#6,sp
	tst.l	d0
	bmi.s	RTCNF
	jsr	CNFANA
	bra.s	CNFGET

RTCNF:	jsr	CLOSE
RTCNF2:	rts


CNFANA:
	lea	B_CNF+2,a2
	cmpi.b	#':',(a2)
	beq.s	RTCFAN
LPCFA1:	move.b	(a2)+,d0
	beq.s	BRCFAN
	cmpi.b	#$1A,d0
	bne.s	LPCFA1
	clr.b	-(a2)
BRCFAN:
	lea	CHRCNF,a0
LPCFA2:	movea.l	(a0)+,a1
	lea	B_CNF+2,a2
	jsr	SKIPSP
	beq.s	RTCFAN
	jsr	CMATCH
	beq.s	CNFMAT
LPCFA3:
	tst.b	(a0)+
	bpl.s	LPCFA3
	tst.l	(a0)
	bne.s	LPCFA2
	bra.w	ERCNF

RTCFAN:	rts

CNFMAT:
	jsr	SKIPSP
	beq.w	ERCNF
	cmpi.b	#'=',(a2)+
	bne.w	ERCNF
	jsr	SKIPSP
	beq.w	ERCNF
	jmp	(a1)


CNFFD0:	lea	FD0,a0
	bra.s	CNFCFD

CNFFD1:	lea	FD1,a0
	bra.s	CNFCFD

CNFFD2:	lea	FD2,a0
	bra.s	CNFCFD

CNFFD3:	lea	FD3,a0
CNFCFD:
	lea	F_FDS,a1
	move.l	a0,d0
	subi.l	#FD0,d0
	asr.l	#7,d0
	tst.b	(a1,d0.l)

	bne.s	RTCFFD
	jsr	COPYFN2
RTCFFD:	rts

CNFDSP:
	tst.b	F_DISP+1
	bne.s	RTCFDS

	move.b	(a2)+,d0
	lsl.w	#8,d0
	move.b	(a2)+,d0

	move.b	#2,d1
	cmpi.w	#'31',d0
	beq.s	CNFSDP
	move.b	#1,d1
	cmpi.w	#'24',d0
	bne.w	ERCNF

CNFSDP:	move.b	d1,F_DISP
RTCFDS:	rts

CNFCON:
	jsr	CH2CHR
	bmi.w	ERCNF
	cmpi.b	#31,d1
	bhi.w	ERCNF
	move.b	d1,F_CONT
	rts

CNFEMM:
	jsr	CH2CHR
	bmi.w	ERCNF
	cmpi.b	#64,d1
	bhi.w	ERCNF
	lea	P_EMM,a0
	tst.b	d1
	bra.s	EWCFEM

LPCFEM:	move.l	#$050000,-(sp)
	dc.w	$FF48					* _DOS MALLOC
	addq.l	#4,sp
	tst.l	d0
	bmi.w	ERCFEM
	move.l	d0,(a0)+
	subq.b	#1,d1
EWCFEM:	bne.s	LPCFEM

	rts

CNFROM:
	move.l	#$010000,-(sp)
	dc.w	$FF48					* _DOS MALLOC
	addq.l	#4,sp
	tst.l	d0
	bmi.w	ERCFRM
	move.l	d0,P_ROM

	move.w	d2,-(sp)
	lea	(a2),a0
	jsr	OPEN
	bmi.w	EROP

	movea.l	P_ROM,a1
	move.l	#$010000,d0
	jsr	READ
	bhi.w	ERRD
	jsr	CLOSE
	move.w	(sp)+,d2

	rts

CNFCAP:
	lea	CHRON,a0
	jsr	CMATCH
	seq	F_CAPS
	rts

CNFKAN:
	lea	CHRON,a0
	jsr	CMATCH
	seq	F_KANA
	rts

CNFTVK:
	lea	CHRON,a0
	jsr	CMATCH
	bne.s	RTCFTK

	lea	T_KEY,a0
	move.w	#ONK52-D_KEY,$52*2(a0)
	move.w	#ONK53-D_KEY,$53*2(a0)
	move.w	#ONK54-D_KEY,$54*2(a0)
	move.w	#ONK68-D_KEY,$68*2(a0)
	move.w	#ONK69-D_KEY,$69*2(a0)
	move.w	#ONK6A-D_KEY,$6A*2(a0)
	move.w	#ONK6B-D_KEY,$6B*2(a0)
	move.w	#ONK6C-D_KEY,$6C*2(a0)

	move.w	#RETOFI-D_KEY,($100+$52*2)(a0)
	move.w	#RETOFI-D_KEY,($100+$53*2)(a0)
	move.w	#RETOFI-D_KEY,($100+$54*2)(a0)
	move.w	#RETOFI-D_KEY,($100+$68*2)(a0)
	move.w	#RETOFI-D_KEY,($100+$69*2)(a0)
	move.w	#RETOFI-D_KEY,($100+$6A*2)(a0)
	move.w	#RETOFI-D_KEY,($100+$6B*2)(a0)
	move.w	#RETOFI-D_KEY,($100+$6C*2)(a0)

RTCFTK:	rts

CNFCNF:
	tst.l	(sp)+
	jsr	CLOSE
	lea	(a2),a0
	jsr	OPEN
	bmi.w	EROP
	jmp	CNFGET

ERCNF:
	lea	MSERCF,a0
	jmp	ERPRN
ERCFEM:
	lea	MSEREM,a0
	jmp	ERPRN
ERCFRM:
	lea	MSERRM,a0
	jmp	ERPRN


CH2CHR:
	move.b	(a2)+,d0
	move.b	(a2)+,d1
	bne.s	SKCFC1
	move.b	d0,d1
	move.b	#'0',d0
SKCFC1:
	subi.b	#$30,d0
	cmpi.b	#$09,d0
	bhi.s	ERCH2C
	subi.b	#$30,d1
	cmpi.b	#$09,d1
	bhi.s	ERCH2C
	tst.b	d0
	bra.s	EWCFC2

LPCFCH:	addi.b	#10,d1
	subq.b	#1,d0
EWCFC2:	bne.s	LPCFCH

	rts

ERCH2C:	move.b	#$FF,d1
	rts


	.data
F_FDS:	dc.b	0,0,0,0
F_DISP:	dc.b	2,0
F_CONT:	dc.b	0
F_CAPS:	dc.b	0
F_KANA:	dc.b	0
FNCFDF:	dc.b	'CONFIG.X1',0
CHRON:	dc.b	'ON',0
CHROFF:	dc.b	'OFF',0
	.even
CHRCNF:
	dc.l	CNFFD0
	dc.b		'FD0',0,0,$FF
	dc.l	CNFFD1
	dc.b		'FD1',0,0,$FF
	dc.l	CNFFD2
	dc.b		'FD2',0,0,$FF
	dc.l	CNFFD3
	dc.b		'FD3',0,0,$FF
	dc.l	CNFDSP
	dc.b		'DISPLAY',0,0,$FF	* 31 / 24
	dc.l	CNFCON
	dc.b		'CONTRAST',0,$FF	* 0-31(0)
	dc.l	CNFEMM
	dc.b		'EMM',0,0,$FF		* 0-64(0)
	dc.l	CNFROM
	dc.b		'ROM',0,0,$FF
	dc.l	CNFCAP
	dc.b		'CAPS',0,$FF		* OFF / ON
	dc.l	CNFKAN
	dc.b		'KANA',0,$FF		* OFF / ON
	dc.l	CNFTVK
	dc.b		'TVKEY',0,0,$FF		* OFF / ON
	dc.l	CNFCNF
	dc.b		'CONFIG',0,$FF
	dc.l	0

MSERCF:	dc.b	'CONFIGファイルに誤りがあります',$0D,$0A,0
MSEREM:	dc.b	'EMM用のメモリが確保できません',$0D,$0A,0
MSERRM:	dc.b	'BASIC ROM用のメモリが確保できません',$0D,$0A,0

B_CNF:	dc.b	$80
	ds.b	1
	ds.b	$80+1
	.text


*---------------------------------------*
* スーパーバイザ/ユーザーモード切り替え	*
*---------------------------------------*

SUPER:
	clr.l	-(sp)
	dc.w	$FF20					* DOS _SUPER
	addq.l	#4,sp
	move.l	d0,B_SSP
	rts

USER:
	move.l	B_SSP,-(sp)
	dc.w	$FF20					* DOS _SUPER
	addq.l	#4,sp
	rts


	.bss
B_SSP:	ds.l	1
	.text


*---------------------------------------*
*		画面設定		*
*---------------------------------------*

SETCRTC:
	move.w	#18,-(sp)				* MD カーソル非表示
	dc.w	$FF23					* DOS _CONCTRL
	addq.l	#2,sp

	move.w	#2,-(sp)				* MOD ファンクションキー行非表示
	move.w	#14,-(sp)				* MD
	dc.w	$FF23					* DOS _CONCTRL
	addq.l	#4,sp
	move.w	d0,B_FUNC

	move.w	#1,-(sp)				* MOD 高解像度 768*512 16色
	move.w	#16,-(sp)				* MD
	dc.w	$FF23					* DOS _CONCTRL
	addq.l	#4,sp
	move.w	d0,B_SCRN

	move.b	F_DISP,d0
	lea	DCRT24,a0
	cmpi.b	#1,d0
	beq.s	SKCRT
	lea	DCRT31,a0
SKCRT:
	lea	PwCRTC00,a1				* CRTC R00
	move.w	#9-1,d0
LPCRT:	move.w	(a0)+,(a1)+
	dbf	d0,LPCRT
	move.b	(a0)+,PsCRTC20				* CRTC R20 L

	lea	PwTEXTP3,a0
	move.l	#$FFFFFFFF,d0
	jsr	S_TXT
	rts

RETCRTC:
	move.l	a0,-(sp)
	move.w	d1,-(sp)
	move.l	d0,-(sp)

	move.w	B_SCRN,-(sp)				* MOD 画面モード復帰
	move.w	#16,-(sp)				* MD
	dc.w	$FF23					* DOS _CONCTRL
	addq.l	#4,sp

	move.w	B_FUNC,-(sp)				* MOD ファンクションキー行復帰
	move.w	#14,-(sp)				* MD
	dc.w	$FF23					* DOS _CONCTRL
	addq.l	#4,sp

	move.w	#17,-(sp)				* MD カーソル表示
	dc.w	$FF23					* DOS _CONCTRL
	addq.l	#2,sp

	lea	PwTEXTP2,a0
	clr.l	d0
	jsr	S_TXT

	lea	PwTEXTP3,a0
	jsr	S_TXT

	move.l	(sp)+,d0
	move.w	(sp)+,d1
	movea.l	(sp)+,a0
	rts

S_TXT:	move.w	#$10000/4-1,d1
LPSTXT:	move.l	d0,(a0)+		* 12
	dbf	d1,LPSTXT		* 14(10)
	rts


	.data
DCRT24:	dc.w	113,07,20,100,447,7,31,431,27
	dc.b	%00010001
	.even
DCRT31:	dc.w	137,14,28,108,567,5,40,440,27
	dc.b	%00010010
	.even
	.text


	.bss
B_SCRN:	ds.w	1
B_FUNC:	ds.w	1
	.text


*---------------------------------------*
*	      パレット設定		*
*---------------------------------------*

M_SETP	macro	AR					* 20

	move.w	(a0)+,d2			*  8
	or.w	d0,d2				*  4
	move.w	d2,AR				*  8

	endm

*---------------------------------------		

INITPAL:
	move.b	F_CONT,d0
	move.b	d0,D_CONT
	lea	A_BAS,aBS
S_CONT:	move.w	d2,-(sp)			*  8

	moveq	#%00111110,d1			*  4
	add.b	d0,d0				*  4
	and.b	d0,d1				*  4
	asl.w	#5,d0				* 16
	or.b	d1,d0				*  4
	asl.w	#5,d0				* 16
	or.b	d1,d0				*  4

	move.w	#%11111_11111_00000_1,d1	*  8
	or.w	d0,d1				*  4
	move.w	d1,A_PALB+2-A_BAS(aBS)		* 12
	move.w	#%11111_00000_11111_1,d1	*  8
	or.w	d0,d1				*  4
	move.w	d1,A_PALR+2-A_BAS(aBS)		* 12
	move.w	#%00000_11111_11111_1,d1	*  8
	or.w	d0,d1				*  4
	move.w	d1,A_PALG+2-A_BAS(aBS)		* 12

	lea	D_PAL+02-A_BAS(aBS),a0		*  8
	lea	FLAOF+04-A_BAS(aBS),a1		*  8
	M_SETP	(a1)+				* 20
	addq.w	#6,a1				*  4
	M_SETP	(a1)+				* 20
	M_SETP	(a1)+				* 20
	addq.w	#6,a1				*  4
	M_SETP	(a1)+				* 20
	M_SETP	(a1)+				* 20
	addq.w	#6,a1				*  4
	M_SETP	(a1)+				* 20

	lea	D_PAL+02-A_BAS(aBS),a0		*  8
	lea	FLAON+34-A_BAS(aBS),a1		*  8
	M_SETP	-(a1)				* 20
	subq.w	#6,a1				*  4
	M_SETP	-(a1)				* 20
	M_SETP	-(a1)				* 20
	subq.w	#6,a1				*  4
	M_SETP	-(a1)				* 20
	M_SETP	-(a1)				* 20
	subq.w	#6,a1				*  4
	M_SETP	-(a1)				* 20

	lea	D_PAL-A_BAS(aBS),a0		*  8
	lea	PwGRAPAL,a1			* 12	* グラフィックパレット
	move.w	(a0)+,(a1)+			* 12
	moveq	#7-1,d1				*  4
LPPAL1:	btst	#4,PsMFPGPI			* 20	* bit4 = 0  垂直帰線期間
	bne.s	LPPAL1				*  8(10)
	M_SETP	(a1)+				* 20
	dbf	d1,LPPAL1			* 14(10)

	lea	A_IOB+$1000,a0			* 12
	lea	PwTXTPAL+16*2,a1		* 12	* テキストパレット
	moveq	#8-1,d1				*  4
LPGPAL:	clr.w	d2				*  4
	btst	d1,(a0)				*  8
	beq.s	OFPALB				*  8(10)
	ori.w	#%00000_00000_11111_0,d2	*  8
OFPALB:	btst	d1,$100(a0)			* 12
	beq.s	OFPALR				*  8(10)
	ori.w	#%00000_11111_00000_0,d2	*  8
OFPALR:	btst	d1,$200(a0)			* 12
	beq.s	OFPALG				*  8(10)
	ori.w	#%11111_00000_00000_0,d2	*  8
OFPALG:	or.w	d0,d2				*  4
LPPAL3:	btst	#4,PsMFPGPI			* 20	* bit4 = 0  垂直帰線期間
	bne.s	LPPAL3				*  8(10)
	move.w	d2,-(a1)			*  8
	dbf	d1,LPGPAL			* 14(10)

	move.w	(sp)+,d2			*  8
	moveq	#0,d1				*  4
	lea	A_IOB,a1			* 12
	rts					* 16


D_CONT:	ds.b	1
	.even


	.data
*		   G     R     B   I
D_PAL:	dc.w	%00000_00000_00000_0
	dc.w	%00000_00000_11111_0
	dc.w	%00000_11111_00000_0
	dc.w	%00000_11111_11111_0
	dc.w	%11111_00000_00000_0
	dc.w	%11111_00000_11111_0
	dc.w	%11111_11111_00000_0
	dc.w	%11111_11111_11111_0

	.text


*---------------------------------------*
*	     キーロック設定		*
*---------------------------------------*

KEYLOCK:
	move.b	#%1_1111111,d0

	tst.b	F_CAPS
	beq.s	SKKL1
	andi.b	#%1_1110111,d0
	st	F_LOCK+0				* CAPS ON
SKKL1:
	tst.b	F_KANA
	beq.s	SKKL2
	andi.b	#%1_1111110,d0
	st	F_LOCK+1				* ｶﾅ ON
SKKL2:
	move.b	d0,PsMFPUDR				* USART データレジスタ
	rts


*---------------------------------------*
*	      ベクタセット		*
*---------------------------------------*

SETVECT:
	move.w	#$001F,d0				* ＮＭＩ
	lea	NMINT,a1
	jsr	INTVCS
	move.l	d0,B_NMIV

	move.w	#$0029,d0				* ブレークポイント
	lea	BREAKP,a1
	jsr	INTVCS
	move.l	d0,B_BKPV

	move.w	#$002E,d0				* エラー表示
	lea	ERROR,a1
	jsr	INTVCS
	move.l	d0,B_ERRV

	move.w	#$004C,d0				* キー入力
	lea	INTKEY,a1
	jsr	INTVCS
	move.l	d0,B_KEYV

	bclr	#4,PsMFPIEB				* タイマーＤ　割り込み発生禁止
	bclr	#4,PsMFPIMB				* タイマーＤ　割り込み要求禁止
	move.w	#$0044,d0				* タイマーＤ
	lea	INTCTC,a1
	jsr	INTVCS
	move.l	d0,B_TMDV

	moveq	#$6C,d0					* IOCS _VDISPST
	lea	0,a1					* 割り込み禁止
	trap	#15
	moveq	#$6C,d0					* IOCS _VDISPST
	lea	FLASH,a1
	move.w	#$001C,d1				* CFLASH カウンタ
	trap	#15

	moveq	#$6A,d0					* IOCS _OPMINTST
	lea	0,a1					* 割り込み禁止
	trap	#15

	lea	$000009B6,a1
	move.l	(a1),B_MOUS
	move.l	#A_RTS,(a1)
	tst.b	PsSCCBCP
	move.b	#1,PsSCCBCP
	move.b	#%000_00_000,PsSCCBCP			* SCC B（マウス）割り込み禁止

A_RTS:	rts

INTVCS:
	pea	(a1)
	move.w	d0,-(sp)
	dc.w	$FF25					* DOS _INTVCS
	addq.l	#6,sp
	rts


	.bss
B_NMIV:	ds.l	1
B_BKPV:	ds.l	1
B_ERRV:	ds.l	1
B_KEYV:	ds.l	1
B_TMDV:	ds.l	1
B_MOUS:	ds.l	1
	.text


*---------------------------------------*
*	       ベクタ復帰		*
*---------------------------------------*

RETVECT:
	move.l	a1,-(sp)
	move.w	d1,-(sp)
	move.l	d0,-(sp)

	move.w	#$001F,d0				* ＮＭＩ
	movea.l	B_NMIV,a1
	jsr	INTVCS

	move.w	#$0029,d0				* ブレークポイント
	movea.l	B_BKPV,a1
	jsr	INTVCS

	move.w	#$002E,d0				* エラー表示
	movea.l	B_ERRV,a1
	jsr	INTVCS

	move.w	#$004C,d0				* キー入力
	movea.l	B_KEYV,a1
	jsr	INTVCS

	bclr	#4,PsMFPIEB				* タイマーＤ　割り込み発生禁止
	bclr	#4,PsMFPIMB				* タイマーＤ　割り込み要求禁止
	move.w	#$0044,d0				* タイマーＤ
	movea.l	B_TMDV,a1
	jsr	INTVCS

	moveq	#$6C,d0					* IOCS _VDISPST
	lea	0,a1					* 割り込み禁止
	trap	#15

	moveq	#$6A,d0					* IOCS _OPMINTST
	lea	0,a1					* 割り込み禁止
	trap	#15

	tst.b	PsSCCBCP
	move.b	#1,PsSCCBCP
	move.b	#%000_10_000,PsSCCBCP			* SCC B（マウス）割り込み許可
	lea	$000009B6,a1
	move.l	B_MOUS,(a1)

	move.l	(sp)+,d0
	move.w	(sp)+,d1
	movea.l	(sp)+,a1
	rts


*---------------------------------------*
*   ＮＭＩ，ブレークポイント，エラー	*
*---------------------------------------*

NMINT:	move.l	B_NMIV,-(sp)
	bra.s	JMPINT

BREAKP:	move.l	B_BKPV,-(sp)
	bra.s	JMPINT

ERROR:	move.l	B_ERRV,-(sp)
JMPINT:	jsr	INITFM
	jsr	RETCRTC
	jsr	RETVECT
	rts


*---------------------------------------*
*	       ＦＣＡＬＬ		*
*---------------------------------------*

FCALL:
	cmpi.w	#$F000,d0		*  8
	bcc.s	DOSCALL			*  8(10)
	cmpi.w	#$0100,d0		*  8
	bcc.s	IOCSCALL		*  8(10)

	lea	T_FCALL-A_BAS(aBS),a0	*  8
	add.w	d0,d0			*  4
	move.w	(a0,d0.w),d0		* 14
	jmp	(aBS,d0.w)		* 14


DOSCALL:
	move.b	d0,A_DOSC+1-A_BAS(aBS)	* 12
	lea	(sp),a0			*  4

	moveq	#$0F,d1			*  4
	move.w	d0,-(sp)		*  8
	and.b	(sp)+,d1		*  8
	move.w	d1,d0			*  4
	asr.w	#1,d0			*  8
	beq.s	A_DOSC			*  8(10)
	subq.w	#1,d0			*  4

LPDOSC:	move.b	(aPC)+,-(sp)		* 12
	move.b	(aPC)+,1(sp)		* 16
	dbf	d0,LPDOSC		* 14(10)

A_DOSC:	dc.w	$FF00
	lea	(a0),sp			*  4
	asr.w	#1,d1			*  8
	bcc.s	NRETC			*  8(10)

	swap	d0			*  4
	move.w	d0,-(sp)		*  8
	move.b	(sp)+,(aPC)+		* 12
	move.b	d0,(aPC)+		*  8
	swap	d0			*  4
	move.w	d0,-(sp)		*  8
	move.b	(sp)+,(aPC)+		* 12
	move.b	d0,(aPC)+		*  8

NRETC:	moveq	#0,d0			*  4
	rts				* 16


IOCSCALL:
	movem.l	d2-d6/a1-a2,-(sp)	* 64
	move.w	d0,-(sp)		*  8
	moveq	#%0111_0000,d0		*  4
	and.b	(sp),d0			*  8
	lsr.b	#4,d0			* 14
	subq.w	#2,d0			*  4
	bmi.s	SKICRD			*  8(10)

	lea	-4*8(sp),a0		*  8
LPICRD:	move.b	(aPC)+,(a0)+		* 12
	move.b	(aPC)+,(a0)+		* 12
	move.b	(aPC)+,(a0)+		* 12
	move.b	(aPC)+,(a0)+		* 12
	dbf	d0,LPICRD		* 14(10)

SKICRD:	tst.b	(sp)			*  8
	bpl.s	SKICRA			*  8(10)

	lea	-4*2(sp),a0		*  8
	clr.w	(a0)+			* 12
	move.b	(aPC)+,1(a0)		* 16
	move.b	(aPC)+,(a0)		* 12
	addq.w	#2,a0			*  4
	clr.w	(a0)+			* 12
	move.b	(aPC)+,1(a0)		* 16
	move.b	(aPC)+,(a0)		* 12

SKICRA:	movem.l	-4*8(sp),d1-d6/a1-a2	* 80
	adda.l	aME,a1			*  8
	adda.l	aME,a2			*  8
	move.w	(sp),d0			*  8
	andi.w	#$00FF,d0		*  8
	trap	#15			* 34+

	suba.l	aME,a1			*  8
	suba.l	aME,a2			*  8
	lea	-4*9(sp),a0		*  8
	movem.l	d0-d6/a1-a2,(a0)	* 80
	moveq	#%0000_0111,d0		*  4
	and.b	(sp),d0			*  8
	subq.w	#1,d0			*  4
	bmi.s	SKICWD			*  8(10)

LPICWD:	move.b	(a0)+,(aPC)+		* 12
	move.b	(a0)+,(aPC)+		* 12
	move.b	(a0)+,(aPC)+		* 12
	move.b	(a0)+,(aPC)+		* 12
	dbf	d0,LPICWD		* 14(10)

SKICWD:	btst	#3,(sp)+		* 12
	beq.s	SKICWA			*  8(10)

	lea	-(2+4*2-2)(sp),a0	*  8
	move.b	1(a0),(aPC)+		* 16
	move.b	(a0),(aPC)+		* 12
	addq.w	#4,a0			*  4
	move.b	1(a0),(aPC)+		* 16
	move.b	(a0),(aPC)+		* 12

SKICWA:	movem.l	(sp)+,d2-d6/a1-a2	* 68
	moveq	#0,d1			*  4
	rts				* 16


*---------------------------------------

FC_00:
	rts				* 16

FC_01:
	move.b	(aPC)+,d0		*  8
	bsr.w	S_CONT			* 18
	rts				* 16


*---------------------------------------

	.data
T_FCALL:
	dc.w	FC_00-A_BAS
	dc.w	FC_01-A_BAS
	dcb.w	$100-$02,FC_00-A_BAS

	.text


*---------------------------------------*
*	      ＣＦＬＡＳＨ		*
*---------------------------------------*

FLASH:	bra.w	FLAON							* 10

FLAOF:	move.l	#%00000_00000_00000_0_00000_00000_11111_0,PwGRAPAL+08*2	* 28
	move.l	#%00000_11111_00000_0_00000_11111_11111_0,PwGRAPAL+10*2	* 28
	move.l	#%11111_00000_00000_0_11111_00000_11111_0,PwGRAPAL+12*2	* 28
	move.l	#%11111_11111_00000_0_11111_11111_11111_0,PwGRAPAL+14*2	* 28
	move.w	#FLAON-(FLASH+2),FLASH+2				* 20
	rte								* 20

FLAON:	move.l	#%11111_11111_11111_0_11111_11111_00000_0,PwGRAPAL+08*2	* 28
	move.l	#%11111_00000_11111_0_11111_00000_00000_0,PwGRAPAL+10*2	* 28
	move.l	#%00000_11111_11111_0_00000_11111_00000_0,PwGRAPAL+12*2	* 28
	move.l	#%00000_00000_11111_0_00000_00000_00000_0,PwGRAPAL+14*2	* 28
	move.w	#FLAOF-(FLASH+2),FLASH+2				* 20
	rte								* 20


*---------------------------------------*
*	     ＣＴＣ割り込み		*
*---------------------------------------*

INTCTC:
	subq.w	#1,C_CTC		* 20
	beq.s	A_ICTC			*  8(10)
	rte				* 20

A_ICTC:	move.w	#$0001,C_CTC		* 20
	tst.b	IFF1			* 16
	beq.s	RTICTC			*  8(10)

	cmpa.l	#T_OPC,aTO		* 14
	bne.s	RTICTC			*  8(10)

A_VCTC:	move.b	#$00,V_INT		* 20
	lea	T_INT,aTO		* 12
RTICTC:	rte				* 20


C_CTC:	dc.w	$0001


*---------------------------------------*
*	 ＥＩ直後のキー割り込み		*
*---------------------------------------*

INTRQ:
	tst.b	F_KBF-A_BAS(aBS)	* 12
	beq.s	RTINTR			*  8(10)

	bclr	#4,PsMFPIMA		* 24		* キー割り込み禁止
	lea	P_RKB-A_BAS(aBS),a0	*  8
	move.w	(a0),d0			*  8
	addq.b	#2,d0			*  4
	move.w	d0,(a0)			*  8
	cmp.w	-(a0),d0		* 10
	sne	-(a0)			* 14
	bset	#4,PsMFPIMA		* 24		* キー割り込み許可

	move.b	V_KEY-A_BAS(aBS),V_INT-A_BAS(aBS)	* 20
	lea	T_INT-A_BAS(aBS),aTO			*  8
	move.w	B_KEY-F_KBF(a0,d0.w),P_SUB+2-A_MEM(aME)	* 22
	move.w	#2-1,P_SUB-A_MEM(aME)			* 16
	move.b	#%00000000,$1A01(a1)			* 16
RTINTR:	rts						* 16


*---------------------------------------*
*	      キー割り込み		*
*---------------------------------------*

INTKEY:
	move.l	a0,-(sp)		* 12
	move.w	d1,-(sp)		*  8
	move.w	d0,-(sp)		*  8

	lea	D_KEY(pc),a0		*  8
	clr.w	d0			*  4
	move.b	PsMFPUDR,d0		* 16		* キーデータ

	move.w	d0,d1			*  4
	add.w	d1,d1			*  4
	move.w	T_KEY-D_KEY(a0,d1.w),d1	* 14
	jmp	(a0,d1.w)		* 14


RETOFI:	sf	F_REPT-D_KEY(a0)	* 16
	clr.b	(a0)			* 12
	tst.b	V_KEY-D_KEY(a0)		* 12
	beq.s	RETNOI			*  8(10)
	move.w	#$00FF,d0		*  8
	bra.s	SKOFFK			* 10

RETINT:	cmp.b	(a0),d0			*  8
	seq	F_REPT-D_KEY(a0)	* 16
	move.b	d0,(a0)			*  8		* D_KEY
	tst.b	V_KEY-D_KEY(a0)		* 12
	beq.s	RETNOI			*  8(10)
	jsr	GETKEYI			* 20
SKOFFK:
	tst.b	IFF1			* 16
	beq.s	RETKDI			*  8(10)
	cmpa.l	#T_OPC,aTO		* 14
	bne.s	RETKDI			*  8(10)

*	bne.s	RETNOI			*  8(10)
*	beq.s	EXEINT			*  8(10)
*	cmpa.l	#T_INT,aTO		* 14
*	bne.s	RETKDI			*  8(10)
*	move.b	V_KEY(pc),d1		* 12
*	cmp.b	V_INT,d1		* 16
*	beq.s	RETKDI			*  8(10)
EXEINT:
	move.b	V_KEY(pc),V_INT		* 24
	lea	T_INT,aTO		* 12
	move.w	d0,P_SUB+2		* 16
	move.w	#2-1,P_SUB		* 20
	move.b	#%00000000,A_IOB+$1A01	* 20
RETNOI:
	move.w	(sp)+,d0		*  8
	move.w	(sp)+,d1		*  8
	movea.l	(sp)+,a0		* 12
	rte				* 20

RETKDI:
	lea	P_WKB(pc),a0		*  8
	move.w	(a0)+,d1		*  8
	addq.b	#2,d1			*  4
	cmp.w	(a0),d1			*  8
	beq.s	BUFFUL			*  8(10)

	move.w	d1,-(a0)		*  8
	st	-(a0)			* 14
	move.w	d0,B_KEY-F_KBF(a0,d1.w)	* 14
BUFFUL:
	move.w	(sp)+,d0		*  8
	move.w	(sp)+,d1		*  8
	movea.l	(sp)+,a0		* 12
	rte				* 20

*---------------------------------------

IRES:
	cmpa.l	#T_OPC,aTO
	bne.w	RETNOI
	lea	T_RES,aTO
	bra.w	RETNOI

INMI:
	cmpa.l	#T_OPC,aTO
	bne.w	RETNOI
	lea	T_NMI,aTO
	dc.w	$FF1F					* DOS _ALLCLOSE
	bra.w	RETNOI

CVECT:
*	jsr	RETCRTC
*	jsr	RETVECT
	bra.w	RETNOI

EXITK:
	jsr	INITFM
	jsr	RETCRTC
	jsr	RETVECT
	dc.w	$FF00					* DOS _EXIT

*---------------------------------------

ONK52:							* REW
ONK53:							* STOP
ONK54:							* FAST
	bra.w	RETINT			* 10


ONK68:							* CHANNEL DOWN
	move.b	#$0C,d1			*  8
	bra.s	TVCTRL			* 10
ONK69:							* CHANNEL UP
	move.b	#$0B,d1			*  8
	bra.s	TVCTRL			* 10
ONK6A:							* VOLUME DOWN
	move.b	#$02,d1			*  8
	bra.s	TVCTRL			* 10
ONK6B:							* VOLUME UP
	move.b	#$01,d1			*  8
	bra.s	TVCTRL			* 10
ONK6C:							* COMPUTER/TV
	move.b	#$08,d1			*  8

TVCTRL:	move.b	d1,A_IOB+$1900+$E7	* 16
	move.b	d1,PsMFPUDR		* 16
	bra.w	RETINT			* 10


ONK5D:							* CAPS LOCK
	not.b	F_LOCK+0-D_KEY(a0)	* 16
	bra.s	LEDMOD			* 10
ONK5A:							* ｶﾅ
	not.b	F_LOCK+1-D_KEY(a0)	* 16

LEDMOD:	clr.b	d1			*  4
	sub.b	F_LOCK+0-D_KEY(a0),d1	* 12
	lsl.b	#3,d1			* 12
	sub.b	F_LOCK+1-D_KEY(a0),d1	* 12
	not.b	d1			*  4

	move.b	d1,PsMFPUDR		* 16
	bra.w	RETNOI			* 10


ONK73:							* OPT.2
	st	F_SIFT+3-D_KEY(a0)	* 16
	bra.w	RETNOI			* 10
ONK72:							* OPT.1(GRAPH)
	st	F_SIFT+2-D_KEY(a0)	* 16
	tst.b	F_SIFT+3-D_KEY(a0)	* 12		* OPT.2+OPT.1
	bne.w	EXITK			* 12(10)
	tst.b	F_SIFT+0-D_KEY(a0)	* 12		* SHIFT+OPT.1
	bne.w	CVECT			* 12(10)
	bra.w	RETNOI			* 10
ONK71:							* CTRL
	st	F_SIFT+1-D_KEY(a0)	* 16
	bra.w	RETNOI			* 10
ONK70:							* SHIFT
	st	F_SIFT+0-D_KEY(a0)	* 16
	bra.w	RETNOI			* 10


OFK73:							* OPT.2
	sf	F_SIFT+3-D_KEY(a0)	* 16
	tst.b	F_SIFT+1-D_KEY(a0)	* 12		* CTRL+OPT.2
	bne.w	INMI			* 12(10)
	bra.w	RETNOI			* 10
OFK72:							* OPT.1(GRAPH)
	sf	F_SIFT+2-D_KEY(a0)	* 16
	tst.b	F_SIFT+1-D_KEY(a0)	* 12		* CTRL+OPT.1
	bne.w	IRES			* 12(10)
	bra.w	RETNOI			* 10
OFK71:							* CTRL
	sf	F_SIFT+1-D_KEY(a0)	* 16
	bra.w	RETNOI			* 10
OFK70:							* SHIFT
	sf	F_SIFT+0-D_KEY(a0)	* 16
	bra.w	RETNOI			* 10


RETTVK:
	tst.b	F_SIFT+3-D_KEY(a0)	* 12		* OPT.2+
	bne.w	RETNOI			* 12(10)
	tst.b	F_SIFT+0-D_KEY(a0)	* 12		* SHIFT+
	bne.w	RETNOI			* 12(10)

	bra.w	RETINT			* 10


RETOFT:
	tst.b	F_SIFT+3-D_KEY(a0)	* 12		* OPT.2+
	bne.w	RETNOI			* 12(10)
	tst.b	F_SIFT+0-D_KEY(a0)	* 12		* SHIFT+
	bne.w	RETNOI			* 12(10)

	bra.w	RETOFI			* 10


V_KEY:	dc.b	0
D_KEY:	dc.b	0

F_REPT:	dc.b	0
F_SIFT:	dc.b	0,0,0,0
F_LOCK:	dc.b	0,0
	.even

RETINTA	equ	.loww.(RETINT-D_KEY).w
RETTVKA	equ	.loww.(RETTVK-D_KEY).w
RETNOIA	equ	.loww.(RETNOI-D_KEY).w
RETOFIA	equ	.loww.(RETOFI-D_KEY).w
RETOFTA	equ	.loww.(RETOFT-D_KEY).w

T_KEY:
	dcb.w	1-$00+$00,RETNOIA
	dcb.w	1-$01+$36,RETINTA
	dcb.w	1-$37+$3A,RETNOIA
	dcb.w	1-$3B+$3E,RETTVKA
	dcb.w	1-$3F+$3F,RETNOIA
	dcb.w	1-$40+$4D,RETTVKA
	dcb.w	1-$4E+$4E,RETINTA
	dcb.w	1-$4F+$51,RETTVKA
	dc.w	RETNOI-D_KEY	* $52	記号入力	REW
	dc.w	RETNOI-D_KEY	* $53	登録		STOP
	dc.w	RETNOI-D_KEY	* $54	HELP		FAST
	dcb.w	1-$55+$59,RETNOIA
	dc.w	ONK5A-D_KEY	* $5A	かな		ｶﾅ
	dcb.w	1-$5B+$5C,RETNOIA
	dc.w	ONK5D-D_KEY	* $5D	CAPS		CAPS LOCK
	dcb.w	1-$5E+$60,RETNOIA
	dcb.w	1-$61+$61,RETINTA
	dcb.w	1-$62+$62,RETNOIA
	dcb.w	1-$63+$67,RETINTA
	dc.w	RETNOI-D_KEY	* $68	F6		CHANNEL DOWN
	dc.w	RETNOI-D_KEY	* $69	F7		CHANNEL UP
	dc.w	RETNOI-D_KEY	* $6A	F8		VOLUME DOWN
	dc.w	RETNOI-D_KEY	* $6B	F9		VOLUME UP
	dc.w	RETNOI-D_KEY	* $6C	F10		COMPUTER/TV
	dcb.w	1-$6D+$6F,RETNOIA
	dc.w	ONK70-D_KEY	* $70	SHIFT		SHIFT
	dc.w	ONK71-D_KEY	* $71	CTRL		CTRL
	dc.w	ONK72-D_KEY	* $72	OPT.1		GRAPH
	dc.w	ONK73-D_KEY	* $73	OPT.2
	dcb.w	1-$74+$7F,RETNOIA

	dcb.w	1-$00+$00,RETNOIA
	dcb.w	1-$01+$36,RETOFIA
	dcb.w	1-$37+$3A,RETNOIA
	dcb.w	1-$3B+$3E,RETOFTA
	dcb.w	1-$3F+$3F,RETNOIA
	dcb.w	1-$40+$4D,RETOFTA
	dcb.w	1-$4E+$4E,RETOFIA
	dcb.w	1-$4F+$51,RETOFTA
	dcb.w	1-$52+$54,RETNOIA
	dcb.w	1-$55+$60,RETNOIA
	dcb.w	1-$61+$61,RETOFIA
	dcb.w	1-$62+$62,RETNOIA
	dcb.w	1-$63+$67,RETOFIA
	dcb.w	1-$68+$6C,RETNOIA
	dcb.w	1-$6D+$6F,RETNOIA
	dc.w	OFK70-D_KEY	* $F0	SHIFT		SHIFT
	dc.w	OFK71-D_KEY	* $F1	CTRL		CTRL
	dc.w	OFK72-D_KEY	* $F2	OPT.1		GRAPH
	dc.w	OFK73-D_KEY	* $F3	OPT.2
	dcb.w	1-$74+$7F,RETNOIA

	ds.b	1
F_KBF:	dc.b	0
P_WKB:	dc.w	$00FE
P_RKB:	dc.w	$00FE
B_KEY:	ds.b	$100


	.end
