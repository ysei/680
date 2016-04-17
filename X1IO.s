*************************************************
*						*
*   Ｘ１ I/O エミュレータ for X68000 Ver 1.00	*
*						*
*	 Copyright 1993/03/16 森田 浩次		*
*						*
*************************************************

*	d0  0000 ----
*	d1  0000 00-- (INP ---- ----)

*	a0  ---- ---- 
*	a1    A_IOB
*	a2  0000  SP

	.xdef	INITIO
	.xdef	INP,OUT

	.xdef	EXTCG
	.xdef	INITFM
	.xdef	GETKEYI
	.xdef	A_PALB,A_PALR,A_PALG
	.xdef	FD0,FD1,FD2,FD3
	.xdef	P_SUB
	.xdef	P_EMM,P_ROM
	.xdef	IPLROM,CGROM
	.xdef	A_IOB
	.xdef	END

	.xref	A_BAS
	.xref	T_OPC,T_ROM
	.xref	A_MEM,A_WOM
	.xref	S_CONT
	.xref	D_CONT,D_KEY
	.xref	D_CTC,C_CTC
	.xref	V_KEY,V_CTC
	.xref	F_REPT,F_SIFT,F_LOCK,F_KBF

*	.globl	I0700,O0700
*	.globl	I0F00,O0F00,DIRC,P_DISK
*	.globl	O1B00

BC	equ	d5
aPC	equ	a3
aME	equ	a5
aBS	equ	a6

OVAD	equ	4			* 非表示ＶＲＡＭ読み込み時のオフセット値

*---------------------------------------*
*	  Ｉ／Ｏポートアドレス		*
*---------------------------------------*

PwSCTXTY	equ	$E80016		* CRTC R11  テキストスクロール（Ｙ方向）
PwSCGP0Y	equ	$E8001A		* CRTC R13  グラフィックP0スクロール（Ｙ方向）
PwCRTC21	equ	$E8002A		* CRTC R21

PwTXTPAL	equ	$E82200		* テキストパレット

PwVCTRL2	equ	$E82500		* ビデオコントローラ Reg.2

PsMFPGPI	equ	$E88001		* MFP GPIP  汎用Ｉ／Ｏレジスタ
PsMFPIEB	equ	$E88009		* MFP IERB  割り込みイネーブルレジスタＢ
PsMFPIMA	equ	$E88013		* MFP IMRA  割り込みマスクレジスタＡ
PsMFPIMB	equ	$E88015		* MFP IMRB  割り込みマスクレジスタＢ
PsMFPDCR	equ	$E8801D		* MFP タイマＣ＆Ｄコントロールレジスタ
PsMFPCDR	equ	$E88023		* MFP タイマＣデータレジスタ
PsMFPDDR	equ	$E88025		* MFP タイマＤデータレジスタ
PsMFPUDR	equ	$E8802F		* MFP USART データレジスタ

PsPRNDAT	equ	$E8C001		* プリンタデータ
PsPRNSTO	equ	$E8C003		* プリンタストローブ

PsSYSPT2	equ	$E8E003		* システムポート＃２

PsOPMADR	equ	$E90001		* OPM アドレスポート
PsOPMDAT	equ	$E90003		* OPM データポート

PsSCCBCP	equ	$E98001		* SCC チャンネルＢコマンドポート
PsSCCBDP	equ	$E98003		* SCC チャンネルＢデータポート

PsJOYST1	equ	$E9A001		* ジョイスティック１
PsJOYST2	equ	$E9A003		* ジョイスティック２

PsINTSTA	equ	$E9C001		* 割り込みステータス

*---------------------------------------*
*	     ＩＮＩＴ Ｉ／Ｏ		*
*---------------------------------------*

	.text

EXTCG:
	lea	CGROM,a0
	lea	CROM2,a1
	move.w	#$100*8-1,d0
LPCG1:	swap	d0
	move.w	#8-1,d0
	move.b	(a0)+,d1
LPCG2:	add.b	d1,d1
	scs	(a1)+
	dbf	d0,LPCG2
	swap	d0
	dbf	d0,LPCG1

	lea	CROM2,a0
	lea	CROM2e,a1
	move.w	#$100*8*8-1,d0
LPCGe:	move.b	(a0)+,d1
	ext.w	d1
	move.w	d1,(a1)+
	dbf	d0,LPCGe

	rts


INITIO:
	bclr	#4,PsMFPIEB				* タイマーＤ　割り込み発生禁止
	bclr	#4,PsMFPIMB				* タイマーＤ　割り込み要求禁止

	jsr	INITFM					* ＦＭ音源初期化

	bclr	#4,PsMFPIMA				* キー割り込み禁止
	sf	F_KBF					* キーバッファクリア
	move.l	#$00FE00FE,F_KBF+1
	bset	#4,PsMFPIMA				* キー割り込み許可

	dc.w	$FF1F					* DOS _ALLCLOSE
	move.b	#$01,A_IOB+$0FFA			* ＦＤＣリセット
	move.l	#$00000000,TRACK+4*0
	move.l	#$00000000,TRACK+4*1
	move.l	#$00000000,TRACK+4*2
	move.l	#$00000000,TRACK+4*3

	lea	A_IOB+$2000,a0				* テキストアトリビュート初期化
	move.b	#$07,d1
	move.w	#$800-1,d0
LPIATR:	move.b	d1,(a0)+
	dbf	d0,LPIATR

	move.b	#$FF,A_IOB+$0E81

	lea	INPS,a0
	lea	INP,a1
	move.w	#(INPSe-INPS)-1,d0
LPIIO1:	move.b	(a0)+,(a1)+
	dbf	d0,LPIIO1
	lea	OUTS,a0
	lea	OUT,a1
	move.w	#(OUTSe-OUTS)-1,d0
LPIIO2:	move.b	(a0)+,(a1)+
	dbf	d0,LPIIO2

	lea	A_IOB,a1
	jsr	O1D00					* IPL ON

	rts

INITFM:							* ＦＭ音源初期化
	move.w	d0,-(sp)

	jsr	WAITOPMi
	move.b	#$08,PsOPMADR
	move.w	#7,d0
LPIFM:	jsr	WAITOPMi
	move.b	d0,PsOPMDAT
	dbf	d0,LPIFM

	jsr	WAITOPMi
	move.b	#$0F,PsOPMADR
	jsr	WAITOPMi
	move.b	#$00,PsOPMDAT

	move.w	(sp)+,d0
	rts

WAITOPMi:
	tst.b	PsOPMDAT
	bmi.s	WAITOPMi
	rts


*---------------------------------------*
*		  ＩＮ			*
*---------------------------------------*

INPS:
	clr.w	d0					*  4
	move.w	BC,-(sp)				*  8
	move.b	(sp)+,d0				*  8
	add.w	d0,d0					*  4
A_INP:	move.w	T_INP-(A_INP+2)+(INPS-INP)(pc,d0.w),d0	* 14
	jmp	(aBS,d0.w)				* 14
INPSe:

INPD:
	lea	OUTS-A_BAS(aBS),a0		*  8
	lea	OUT-A_BAS(aBS),a1		*  8
	moveq	#(OUTSe-OUTS)/2-1,d0		*  4
LPIND:	move.w	(a0)+,(a1)+			* 12
	dbf	d0,LPIND			* 14(10)

	move.l	#$42403F05,INP-A_BAS(aBS)	* 24	* clr.w d0 : move.w BC,-(sp)
	move.w	#%00_0000_0000,PwCRTC21		* 20
	lea	A_IOB,a1			* 12
	bra.w	INP				* 10
*	rts					* 16


*---------------------------------------*
*		 ＯＵＴ			*
*---------------------------------------*

OUTS:						* 52
	clr.w	d0					*  4
	move.w	BC,-(sp)				*  8
	move.b	(sp)+,d0				*  8
	add.w	d0,d0					*  4
A_OUT:	move.w	T_OUT-(A_OUT+2)+(OUTS-OUT)(pc,d0.w),d0	* 14
	jmp	(aBS,d0.w)				* 14
OUTSe:

OUTD:						* 26/38/28/40
	move.w	BC,d0			*  4
	bmi.s	OUTD8C			*  8(10)
	add.w	d0,d0			*  4
A_OD0:	bpl.w	DAMD0L+(OUTD-OUT)	* 12(10)
A_OD4:	bra.w	DAMD4L+(OUTD-OUT)	* 10

OUTD8C:	add.w	d0,d0			*  4
A_OD8:	bpl.w	DAMD8L+(OUTD-OUT)	* 12(10)
A_ODC:	bra.w	DAMDCL+(OUTD-OUT)	* 10
OUTDe:	


*---------------------------------------*
*	      ＯＵＴＩＰＬ		*
*---------------------------------------*

OUTIPL:
	move.l	#$42403F05,OUT				* clr.w d0 : move.w BC,-(sp)
	cmpa.l	#A_MEM+$001F,aPC
	bne.s	NOTRES

	move.w	#I1A00s-A_BAS,T_INP+$1A*2
	move.l	#$20002,C_I1As

NOTRES:	bra.w	OUT


*---------------------------------------*
*	  ＦＭ音源 (0700,0701)		*
*	  ＯＰＭ　ＹＭ２１５１		*
*---------------------------------------*

I0700:
	move.b	BC,d0			*  4
	subq.b	#1,d0			*  4		* $0701
	bne.s	SKNDAT			*  8(10)
	move.b	PsOPMDAT,d1		* 16
	rts				* 16
SKNDAT:
	subq.b	#3,d0			*  4		* $0704
	beq.w	I_CTC0			* 12(10)
	subq.b	#1,d0			*  4		* $0705
	beq.w	I_CTC1			* 12(10)
	subq.b	#1,d0			*  4		* $0706
	beq.w	I_CTC2			* 12(10)
	subq.b	#1,d0			*  4		* $0707
	beq.w	I_CTC3			* 12(10)

	clr.b	d1			*  4
	rts				* 16

O0700:
	move.b	BC,d0			*  4		* $0700
	beq.s	OPMADR			*  8(10)
	subq.b	#1,d0			*  4		* $0701
	beq.s	OPMDAT			*  8(10)

	subq.b	#3,d0			*  4		* $0704
	beq.w	O_CTC0			* 12(10)
	subq.b	#2,d0			*  4		* $0706
	beq.w	O_CTC2			* 12(10)
	subq.b	#1,d0			*  4		* $0707
	beq.w	O_CTC3			* 12(10)

	rts				* 16
OPMADR:
	move.b	d1,$0700(a1)		* 12
*	move.b	d1,PsOPMADR		* 16
	rts				* 16
OPMDAT:
	move.b	$0700(a1),d0		* 12

	cmpi.b	#$14,d0			*  8
	bcs.s	ST_DAT			*  8(10)
	cmpi.b	#$27,d0			*  8
	bhi.s	ST_DAT			*  8(10)

	beq.s	SF_CH8			*  8(10)
	cmpi.b	#$25,d0			*  8
	bhi.s	SF_CH7			*  8(10)
	beq.s	SF_CH6			*  8(10)
	cmpi.b	#$24,d0			*  8
	beq.s	SF_CH5			*  8(10)

	cmpi.b	#$1B,d0			*  8
	beq.s	ST_LFO			*  8(10)
	cmpi.b	#$14,d0			*  8
	beq.s	ST_TIM			*  8(10)
ST_DAT:
	lea	PsOPMDAT,a0		* 12
	bsr.w	WAITOPM			* 18
	move.b	d0,-2(a0)		* 12
	bsr.w	WAITOPM			* 18
	move.b	d1,(a0)			*  8
	rts				* 16
SF_CH5:
	st	F_PSG+0-A_MEM(aME)	* 16
	bra.s	ST_DAT			* 10
SF_CH6:
	st	F_PSG+1-A_MEM(aME)	* 16
	bra.s	ST_DAT			* 10
SF_CH7:
	st	F_PSG+2-A_MEM(aME)	* 16
	bra.s	ST_DAT			* 10
SF_CH8:
	st	F_PSG+3-A_MEM(aME)	* 16
	bra.s	ST_DAT			* 10
ST_LFO:
	moveq	#%00111111,d0		*  4
	and.b	d0,d1			*  4
	not.b	d0			*  4
	and.b	$0009DA,d0		* 16
	or.b	d0,d1			*  4
*	move.b	d1,$0009DA		* 16
	moveq	#$1B,d0			*  4
	bra.s	ST_DAT			* 10
ST_TIM:
	andi.b	#%11110011,d1		*  8
	bra.s	ST_DAT			* 10


*---------------------------------------*
*  Ｚ８０ ＣＴＣ (0704-0707/1FA8-1FAB)	*
*---------------------------------------*

I_CTC0:
	btst	#6,(a1,BC.w)		* 18		* bit6 = 1  カウンタ・モード
	bne.s	INC0COU			*  8(10)

	btst	#5,(a1,BC.w)		* 18		* bit5 = 1  プリスケーラ 1/256
	bne.s	INC0256			*  8(10)

	move.b	PsMFPDDR,d1		* 16
*	subq.b	#1,d1			*  4
	rts				* 16
INC0256:
	moveq	#$0F,d1			*  4
	and.w	C_CTC-A_BAS(aBS),d1	* 12
	bne.s	SK0256			*  8(10)
	moveq	#$10,d1			*  4
SK0256:	mulu	B_TCC0-A_MEM(aME),d1	*<78
	asr.w	#4,d1			* 14
	rts				* 16
INC0COU:
	move.b	PsMFPDDR,d1		* 16
	rts				* 16

I_CTC1:
I_CTC2:
	move.b	PsMFPCDR,d1		* 16
	rts				* 16

I_CTC3:
	btst	#5,-3(a1,BC.w)		* 18		* bit5 = 1  プリスケーラ 1/256
	beq.s	INC316			*  8(10)

	move.w	C_CTC-A_BAS(aBS),d1	* 12
	asr.w	#4,d1			* 14
	rts				* 16
INC316:
	move.b	C_CTC+1-A_BAS(aBS),d1	* 12
*	subq.b	#1,d1			*  4
	rts				* 16

*---------------------------------------

O_CTC0:
	bclr	#2,(a1,BC.w)		* 22		* bit2 = 1  ロード・タイムコンスタント
	bne.s	LTCCH0			*  8(10)

	btst	#0,d1			* 10		* bit0 = 0  ベクタセット
	beq.w	S_CTCV			* 12(10)

	move.b	d1,(a1,BC.w)		* 14

	move.b	#$70,PsMFPDCR		* 20
	btst	#1,d1			* 10		* bit1 = 1  リセット
	bne.s	CH0RES			*  8(10)
	move.b	#$73,PsMFPDCR		* 20		* 1/16
CH0RES:
	btst	#7,+3(a1,BC.w)		* 18
	bne.s	CH3EI			*  8(10)
	bclr	#4,PsMFPIEB		* 24
CH3EI:
	add.b	d1,d1			*  4		* bit7 = 1  割り込み可
	bcc.s	CH0DI			*  8(10)

	bset	#4,PsMFPIEB			* 24
	andi.b	#%11111001,V_CTC-A_BAS(aBS)	* 20
	move.w	#$0001,B_TCC3-A_MEM(aME)	* 16
CH0DI:
	add.b	d1,d1			*  4		* bit6 = 1  カウンタ・モード
	bcc.s	CH0TIM			*  8(10)
	move.b	#$70,PsMFPDCR		* 20
CH0TIM:
	move.w	B_TCC3-A_MEM(aME),d0	* 12
	add.b	d1,d1			*  4		* bit5 = 1  プリスケーラ 1/256
	bcc.s	CH0P16			*  8(10)
	asl.w	#4,d0			* 14
CH0P16:
	move.w	d0,D_CTC-A_BAS(aBS)	* 12
	rts				* 16

LTCCH0:
	move.b	d1,B_TCC0+1-A_MEM(aME)	* 12
	move.b	d1,PsMFPDDR		* 16
	move.b	#$70,PsMFPDCR		* 20

	btst	#6,(a1,BC.w)		* 18		* bit6 = 1  カウンタ・モード
	bne.s	TC0COU			*  8(10)

	move.b	#$73,PsMFPDCR		* 20		* 1/16
	bset	#4,PsMFPIMB		* 24

TC0COU:	rts				* 16

S_CTCV:
	andi.b	#%11111001,d1			*  8
	andi.b	#%00000110,V_CTC-A_BAS(aBS)	* 20
	or.b	d1,V_CTC-A_BAS(aBS)		* 16
	rts					* 16

*---------------------------------------

O_CTC1:
	rts				* 16

O_CTC2:
	bclr	#2,(a1,BC.w)		* 22		* bit2 = 1  ロード・タイムコンスタント
	bne.s	RT_CH2			*  8(10)

	btst	#0,d1			* 10		* bit0 = 0  ベクタセット
	beq.s	S_CTCV			*  8(10)

	move.b	d1,(a1,BC.w)		* 14
RT_CH2:	rts				* 16

*---------------------------------------

O_CTC3:
	bclr	#2,(a1,BC.w)		* 22		* bit2 = 1  ロード・タイムコンスタント
	bne.s	LTCCH3			*  8(10)

	move.b	d1,(a1,BC.w)		* 14

	move.b	#$70,PsMFPDCR		* 20
	btst	#1,d1			* 10		* bit1 = 1  リセット
	bne.s	CH3RES			*  8(10)
	move.b	#$73,PsMFPDCR		* 20		* 1/16
CH3RES:
	add.b	d1,d1			*  4		* bit7 = 1  割り込み可
	bcc.s	CH3DI			*  8(10)

	bset	#4,PsMFPIEB			* 24
	ori.b	#%00000110,V_CTC-A_BAS(aBS)	* 20
CH3DI:
	rts				* 16

LTCCH3:
	clr.w	d0			*  4
	move.b	d1,d0			*  4
	bne.s	TC3N00			*  8(10)
	move.w	#$0100,d0		*  8
TC3N00:
	move.w	d0,B_TCC3-A_MEM(aME)	* 12

	btst	#5,-3(a1,BC.w)		* 18		* bit5 = 1  プリスケーラ 1/256
	beq.s	SKLTC3			*  8(10)
	asl.w	#4,d0			* 14
SKLTC3:
	move.w	d0,D_CTC-A_BAS(aBS)	* 12
	move.b	#$73,PsMFPDCR		* 20		* 1/16
	bset	#4,PsMFPIMB		* 24
	rts				* 16


	.data
B_TCC0:	dc.w	$0000
B_TCC3:	dc.w	$0001
	.text


*---------------------------------------*
*	    立体ボード (0A00)		*
*	Ｚ８０ ＣＴＣ (0A04-0A07)	*
*---------------------------------------*

I0A00:
	move.b	BC,d0			*  4
	subq.b	#4,d0			*  4		* $0A04
	beq.w	I_CTC0			* 12(10)

	subq.b	#1,d0			*  4		* $0A05
	beq.w	I_CTC1			* 12(10)

	subq.b	#1,d0			*  4		* $0A06
	beq.w	I_CTC2			* 12(10)

	subq.b	#1,d0			*  4		* $0A07
	beq.w	I_CTC3			* 12(10)

	clr.b	d1			*  4
	rts				* 16

O0A00:
	move.b	BC,d0			*  4		* $0A00
	beq.s	CTRL3D			*  8(10)

	subq.b	#4,d0			*  4		* $0A04
	beq.w	O_CTC0			* 12(10)

	subq.b	#2,d0			*  4		* $0A06
	beq.w	O_CTC2			* 12(10)

	subq.b	#1,d0			*  4		* $0A07
	beq.w	O_CTC3			* 12(10)

	rts				* 16

CTRL3D:
	moveq	#%11,d0			*  4
	and.b	d0,d1			*  4
	sub.b	d1,d0			*  4
	beq.s	CT3DOP			*  8(10)

	move.b	d1,PsSYSPT2					* 16
	move.b	#.low.(W403D0-(A_SC0+2)),A_SC0+1-A_BAS(aBS)	* 16
	move.b	#.low.(W403D1-(A_SC1+2)),A_SC1+1-A_BAS(aBS)	* 16
	rts							* 16
CT3DOP:
	move.b	d0,PsSYSPT2					* 16
	move.b	#.low.(W40SC0-(A_SC0+2)),A_SC0+1-A_BAS(aBS)	* 16
	move.b	#.low.(W40SC1-(A_SC1+2)),A_SC1+1-A_BAS(aBS)	* 16
	rts							* 16


*---------------------------------------*
* 外部ＲＡＭボード（ＥＭＭ）(0D00-0DFF)	*
*---------------------------------------*

I0D00:
	moveq	#$03,d0			*  4
	and.b	BC,d0			*  4
	subq.b	#$03,d0			*  4
	bne.s	RTIEMM			*  8(10)

	lea	P_EMM-A_MEM(aME),a0	*  8
	move.b	BC,d0			*  4
	move.l	-3(a0,d0.w),d1		* 14
	bmi.s	RTIEMM			*  8(10)

	movea.l	d1,a0			*  4
	moveq	#0,d0			*  4
	adda.w	BC,a1			*  8

	move.b	-(a1),d0		* 10
	cmpi.b	#$05,d0			*  8
	bcs.s	SKIEMM			*  8(10)

	clr.b	d0			*  4
SKIEMM:	swap	d0			*  4
	move.b	-(a1),-(sp)		* 14
	move.w	(sp)+,d0		*  8
	move.b	-(a1),d0		* 10

	move.b	(a0,d0.l),d1		* 14
	addq.l	#1,d0			*  8

	move.b	d0,(a1)+		*  8
	move.w	d0,-(sp)		*  8
	move.b	(sp)+,(a1)+		* 12
	swap	d0			*  4
	move.b	d0,(a1)+		*  8

	suba.w	BC,a1			*  8
	moveq	#0,d0			*  4
	rts				* 16

RTIEMM:	clr.b	d1			*  4
	rts				* 16

O0D00:
	moveq	#$03,d0			*  4
	and.b	BC,d0			*  4
	subq.b	#$03,d0			*  4
	bne.s	RTOEMM			*  8(10)

	lea	P_EMM-A_MEM(aME),a0	*  8
	move.b	BC,d0			*  4
	move.l	-3(a0,d0.w),d0		* 14
	bmi.s	RTOEM2			*  8(10)

	movea.l	d0,a0			*  4
	moveq	#0,d0			*  4
	adda.w	BC,a1			*  8

	move.b	-(a1),d0		* 10
	cmpi.b	#$05,d0			*  8
	bcs.s	SKOEMM			*  8(10)

	clr.b	d0			*  4
SKOEMM:	swap	d0			*  4
	move.b	-(a1),-(sp)		* 14
	move.w	(sp)+,d0		*  8
	move.b	-(a1),d0		* 10

	move.b	d1,(a0,d0.l)		* 14
	addq.l	#1,d0			*  8

	move.b	d0,(a1)+		*  8
	move.w	d0,-(sp)		*  8
	move.b	(sp)+,(a1)+		* 12
	swap	d0			*  4
	move.b	d0,(a1)+		*  8

	suba.w	BC,a1			*  8
RTOEM2:	moveq	#0,d0			*  4
	rts				* 16

RTOEMM:	move.b	d1,(a1,BC.w)		* 14
	rts				* 16


*---------------------------------------*
*    ＢＡＳＩＣ　ＲＯＭ (0E00-0E03)	*
*---------------------------------------*

INBROM:
	subq.b	#$03,d1			*  4
	bne.s	RTIBRM			*  8(10)

	move.l	P_ROM-A_MEM(aME),d1	* 16
	bmi.s	RTIBRM			*  8(10)

	movea.l	d1,a0			*  4
	moveq	#0,d0			*  4
	lea	+$0E00(a1),a1		*  8

	move.b	(a1)+,d0		*  8
	swap	d0			*  4
	move.b	(a1)+,-(sp)		* 12
	move.w	(sp)+,d0		*  8
	move.b	(a1)+,d0		*  8

	move.b	(a0,d0.l),d1		* 14
	lea	-$0E03(a1),a1		*  8
	moveq	#0,d0			*  4
	rts				* 16

RTIBRM:	clr.b	d1			*  4
	rts				* 16


*---------------------------------------*
*	 漢字ＲＯＭ (0E80-0E82)		*
*---------------------------------------*

I0E00:
	move.b	BC,d1			*  4
	bpl.s	INBROM			*  8(10)

	add.b	d1,d1			*  4
	beq.s	INKR80			*  8(10)

	subq.b	#$01*2,d1		*  4
	beq.s	INKR81			*  8(10)

	clr.b	d1			*  4
	rts				* 16

INKR80:
	move.b	PATLN-A_MEM(aME),d0	* 12
	bmi.s	KADR80			*  8(10)

	moveq	#%00011110,d1		*  4
	and.w	d1,d0			*  4
	movea.l	CGADR-A_MEM(aME),a0	* 20
	move.b	(a0,d0.w),d1		* 14

	addq.b	#$01,PATLN-A_MEM(aME)	* 16
	rts				* 16
KADR80:	
	clr.w	d0			*  4
	move.b	$0E80(a1),d0		* 12
	move.b	T_KAD(pc,d0.w),d1	* 14
	rts				* 16

INKR81:
	move.b	PATLN-A_MEM(aME),d0	* 12
	bmi.s	RTKR81			*  8(10)

	moveq	#%00011110,d1		*  4
	and.w	d1,d0			*  4
	addq.w	#%00000001,d0		*  4
	movea.l	CGADR-A_MEM(aME),a0	* 20
	move.b	(a0,d0.w),d1		* 14

	addq.b	#$01,PATLN-A_MEM(aME)	* 16
RTKR81:	rts				* 16

T_KAD:
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$01,$07,$0D,$13,$19,$1F,$25,$2B,$00,$00,$00,$00,$00,$00,$00
	dc.b	$40,$46,$4C,$52,$58,$5E,$64,$6A,$70,$76,$7C,$82,$88,$8E,$94,$9A
	dc.b	$A0,$A6,$AC,$B2,$B8,$BE,$C4,$CA,$D0,$D6,$DC,$E2,$E8,$EE,$F4,$FA
	dcb.b	$100-$50,$00

O0E00:
	move.b	BC,d0			*  4
	bpl.s	OTBROM			*  8(10)

	add.b	d0,d0			*  4
	beq.s	OTKR80			*  8(10)

	subq.b	#$01*2,d0		*  4
	beq.s	OTKR81			*  8(10)
	rts				* 16
OTBROM:
	move.b	d1,(a1,BC.w)		* 14
	rts				* 16

OTKR80:
	move.b	d1,$0E80(a1)		* 12

	move.b	$0E81(a1),-(sp)		* 16
	move.w	(sp)+,d0		*  8
	move.b	d1,d0			*  4
	bra.s	SCGADR			* 10
OTKR81:
	tst.b	d1			*  4
	seq	PATLN-A_MEM(aME)	* 16
	beq.s	RTKADR			*  8(10)

	move.b	d1,$0E81(a1)		* 12

	move.b	d1,-(sp)		*  8
	move.w	(sp)+,d0		*  8
	move.b	$0E80(a1),d0		* 12
SCGADR:
	subi.w	#$4000,d0		*  8
	bcs.s	SCGADR2			*  8(10)

	divu	#$0600,d0		*<144
	add.w	d0,d0			*  4
	add.w	d0,d0			*  4
	movea.l	T_KML(pc,d0.w),a0	* 18

	swap	d0			*  4
	ext.l	d0			*  4
	subi.w	#$0010,d0		*  8
	add.w	d0,d0			*  4

	adda.w	d0,a0			*  8
	move.l	a0,CGADR-A_MEM(aME)	* 16
RTKADR:	rts				* 16

SCGADR2:
	addi.w	#$3F00,d0		*  8
	cmpi.w	#$0010,d0		*  8
	bcs.s	RTKADR			*  8(10)

	divu	#$0600,d0		*<144
	add.w	d0,d0			*  4
	add.w	d0,d0			*  4
	movea.l	T_KML2(pc,d0.w),a0	* 18

	swap	d0			*  4
	ext.l	d0			*  4
	subi.w	#$0010,d0		*  8
	add.w	d0,d0			*  4

	adda.w	d0,a0			*  8
	move.l	a0,CGADR-A_MEM(aME)	* 16
	rts				* 16


T_KML2:	dc.l	$F00000,$F00BC0,$F01780,$F02340,$F02F00,$F03AC0,$F04680,$F05240
T_KML:	dc.l	$F05E00,$F069C0,$F07580,$F08140,$F08D00,$F098C0,$F0A480,$F0B040
	dc.l	$F0BC00,$F0C7C0,$F0D380,$F0DF40,$F0EB00,$F0F6C0,$F10280,$F10E40
	dc.l	$F11A00,$F125C0,$F13180,$F13D40,$F14900,$F154C0,$F16080,$F16C40
	dc.l	$F17800,$F183C0,$F18F80,$F19B40,$F1A700,$F1B2C0,$F1BE80,$F1CA40

	.data
CGADR:	ds.l	1
PATLN:	dc.b	$FF
	.even
	.text


*---------------------------------------*
*	５インチＦＤ (0FF8-0FFC)	*
*	 ＦＤＣ　ＭＢ８８７７Ａ		*
*---------------------------------------*

I0F00:
	move.b	BC,d0				*  4
	addq.b	#$05,d0				*  4		* $0FFB(DR)
	bne.s	INNODR				*  8(10)

	lea	P_DISK-A_MEM(aME),a0		*  8
	move.w	(a0),d0				*  8
	move.b	B_DISK-P_DISK(a0,d0.w),d1	* 14
A_RDAT:	cmpi.w	#$00FF,d0			*  8
	bcc.s	INNOCT				*  8(10)

	addq.w	#1,d0				*  4
	move.w	d0,(a0)				*  8
	rts					* 16
INNOCT:
	beq.s	INESCT				*  8(10)
	addq.w	#1,d0				*  4		* P_DISK = -1
	beq.s	RTIFFB				*  8(10)
	clr.w	d1				*  4		* P_DISK = -2
	move.w	d1,(a0)				*  8
*	move.b	#%00000011,$0FF8(a1)		* 16
	rts					* 16
INESCT:
	move.w	#-1,(a0)			* 12
	cmpi.w	#$0100-1,d0			*  8
	bls.s	RTIsSC				*  8(10)
	cmpi.w	#$1000-1,d0			*  8
	beq.s	RTImSC				*  8(10)
	move.b	#%00000100,$0FF8(a1)		* 16		* Lost Data
	rts					* 16
RTImSC:	move.b	#%00010000,$0FF8(a1)		* 16		* Record Not Found
	rts					* 16
RTIsSC:	move.b	#%00000000,$0FF8(a1)		* 16
	rts					* 16
INNODR:
	addq.b	#$03,d0				*  4		* $0FF8(STR)
	beq.s	RTIFF8				*  8(10)
	subq.b	#$01,d0				*  4		* $0FF9(TR)
	beq.s	RTIFF9				*  8(10)
	subq.b	#$01,d0				*  4		* $0FFA(SCR)
	beq.s	RTIFFA				*  8(10)
	clr.b	d1				*  4
	rts					* 16
RTIFF8:	move.b	$0FF8(a1),d1			* 12
	rts					* 16
RTIFF9:	move.b	$0FF9(a1),d1			* 12
	rts					* 16
RTIFFA:	move.b	$0FFA(a1),d1			* 12
	rts					* 16
RTIFFB:	move.b	$0FFB(a1),d1			* 12
	rts					* 16


*---------------------------------------

O0F00:
	move.b	BC,d0				*  4
	addq.b	#$05,d0				*  4		* $0FFB(DR)
	bne.s	OTNODR				*  8(10)

	lea	P_DISK-A_MEM(aME),a0		*  8
	move.w	(a0),d0				*  8
	move.b	d1,B_DISK-P_DISK(a0,d0.w)	* 14
A_WDAT:	cmpi.w	#$00FF,d0			*  8
	bcc.s	OTNOCT				*  8(10)

	addq.w	#1,d0				*  4
	move.w	d0,(a0)				*  8
	rts					* 16
OTNOCT:
	beq.s	OTESCT				*  8(10)
	move.b	d1,$0FFB(a1)			* 12
	rts					* 16
OTESCT:
	move.w	#-1,(a0)			* 12
	cmpi.w	#$0100-1,d0			*  8
	beq.w	WRTsSC				* 12(10)
	cmpi.w	#$1000-1,d0			*  8
	bne.w	WRTTRK				* 12(10)
	bra.w	WRTmSC				* 10
OTNODR:
	addq.b	#$03,d0				*  4		* $0FF8(CR)
	beq.s	O0FF8				*  8(10)
	subq.b	#$02,d0				*  4		* $0FFA(SCR)
	beq.s	O0FFA				*  8(10)
	subq.b	#$02,d0				*  4		* $0FFC(MOTOR ON/OFF)
	beq.s	O0FFC				*  8(10)
	move.b	d1,(a1,BC.w)			* 14
	rts					* 16


O0FF8:							* コマンドレジスタ
	ror.b	#2,d1				* 10
	moveq	#%00111100,d0			*  4
	and.w	d1,d0				*  4
	jmp	T_FDC(pc,d0.w)			* 14

T_FDC:
	bra.w	RESTORE				* 10	* 0000	RESTORE
	bra.w	SEEK				* 10	* 0001	SEEK
	bra.w	STEP				* 10	* 0010	STEP
	bra.w	STEPu				* 10	* 0011	 u
	bra.w	STEPIN				* 10	* 0100	STEP IN
	bra.w	STEPINu				* 10	* 0101	 u
	bra.w	STEPOUT				* 10	* 0110	STEP OUT
	bra.w	STEPOUTu			* 10	* 0111	 u
	bra.w	READDATA			* 10	* 1000	READ DATA
	bra.w	READDATAm			* 10	* 1001	 m
	bra.w	WRITDATA			* 10	* 1010	WRITE DATA
	bra.w	WRITDATAm			* 10	* 1011	 m
	bra.w	READADRS			* 10	* 1100	READ ADDRESS
	bra.w	FORCEINT			* 10	* 1101	FORCE INTERRUPT
	bra.w	READTRAK			* 10	* 1110	READ TRACK
	bra.w	WRITTRAK			* 10	* 1111	WRITE TRACK

O0FFA:							* セクタレジスタ
	move.b	d1,$0FFA(a1)			* 12
	subq.b	#1,d1				*  4
	move.b	d1,SECTOR-A_MEM(aME)		* 12
	rts					* 16

O0FFC:							* モーター ON/OFF etc.
	lea	CDRIVE-A_MEM(aME),a0		*  8
	moveq	#%00010000,d0			*  4
	and.b	d1,d0				*  4
	move.b	d0,HEAD-CDRIVE(a0)		* 12		* HEAD = $0000 or $1000

	andi.w	#%10000011,d1			*  8
	add.b	d1,d1				*  4
	bcc.s	MOTOROFF			*  8(10)

	add.w	d1,d1				*  4
	move.w	d1,(a0)				*  8		* CDRIVE = ドライブNo.*4
	tst.w	FILENO-CDRIVE(a0,d1.w)		* 14
	bmi.s	MOTORON				*  8(10)

	move.b	#%00000000,$0FF8(a1)		* 16
	rts					* 16
MOTORON:	* 8 654  10
	move.w	#%000000010,-(sp)		*  8		* MODE = 読み/書きモード
	moveq	#%00000000,d0			*  4
FOPEN:
	move.b	d0,FILENO+2-CDRIVE(a0,d1.w)	* 14		* FILENO+2 = STR
	move.b	d0,$0FF8(a1)			* 12
	move.l	P_FILE-CDRIVE(a0,d1.w),-(sp)	* 26		* NAMEPTR
	dc.w	$FF3D						* DOS _OPEN
	addq.w	#6,sp				*  4
	tst.l	d0				*  4
	bmi.s	MTONWP				*  8(10)
	move.w	d0,FILENO-CDRIVE(a0,d1.w)	* 14		* FILENO = ファイルハンドル
	moveq	#0,d0				*  4
	rts					* 16
MTONWP:
	cmpi.l	#-19,d0				* 14		* 書き込み禁止エラー
	bne.s	DEVERR				*  8(10)
		* 8 654  10
	move.w	#%000000000,-(sp)		*  8		* MODE = 読み込みモード
	moveq	#%01000000,d0			*  4		* Write Protect
	bra.s	FOPEN				* 10
MOTOROFF:
	add.w	d1,d1				*  4
	move.w	d1,(a0)				*  8		* CDRIVE = ドライブNo.*4
	move.w	FILENO-CDRIVE(a0,d1.w),d0	* 14
	bmi.s	SKMOOF				*  8(10)

	move.w	d0,-(sp)			*  8		* FILENO
	dc.w	$FF3E						* DOS _CLOSE
	addq.w	#2,sp				*  4
	tst.l	d0				*  4
	bmi.s	DEVERR				*  8(10)

	move.w	#$FFFF,FILENO-CDRIVE(a0,d1.w)	* 18		* FILENO = $FFFF
SKMOOF:	moveq	#%00000000,d0			*  4
	move.b	d0,$0FF8(a1)			* 12
	rts					* 16
DEVERR:
	moveq	#0,d0				*  4
SKMOOx:	move.b	#%10000000,$0FF8(a1)		* 16		* Not Ready
	rts					* 16


RESTORE:						* リストア
	moveq	#0,d1				*  4
	lea	$0FF8(a1),a0			*  8
	move.b	#%00000100,(a0)+		* 12		* Track00
	move.b	d1,(a0)+			*  8		* $0FF9(TR)=$00
	addq.w	#1,a0				*  4
	move.b	d1,(a0)+			*  8		* $0FFB(DR)=$00

	lea	CDRIVE-A_MEM(aME),a0		*  8
	move.b	d1,DIRC-CDRIVE(a0)		* 12		* DIRC=$00
	move.w	(a0),d0				*  8
	move.l	d1,TRACK-CDRIVE(a0,d0.w)	* 18		* TRACK=$00000000
	rts					* 16

STEPu:							* ステップ
	tst.b	DIRC-A_MEM(aME)			* 12
	bne.s	STEPINu				*  8(10)
	bra.s	STEPOUTu			* 10
STEP:
	tst.b	DIRC-A_MEM(aME)			* 12
	bne.s	STEPIN				*  8(10)
	bra.s	STEPOUT				* 10

STEPINu:						* ステップイン
	addq.b	#1,$0FF9(a1)			* 16
STEPIN:
	lea	CDRIVE-A_MEM(aME),a0		*  8
	st	DIRC-CDRIVE(a0)			* 16
	move.w	(a0),d0				*  8
	addi.l	#$2000,TRACK-CDRIVE(a0,d0.w)	* 34
	move.b	#%00000000,$0FF8(a1)		* 16
	rts					* 16

STEPOUTu:						* ステップアウト
	subq.b	#1,$0FF9(a1)			* 16
STEPOUT:
	lea	CDRIVE-A_MEM(aME),a0		*  8
	sf	DIRC-CDRIVE(a0)			* 16
	move.w	(a0),d0				*  8
	subi.l	#$2000,TRACK-CDRIVE(a0,d0.w)	* 34
	bls.s	TRACK00				*  8(10)
	move.b	#%00000000,$0FF8(a1)		* 16
	rts					* 16

SEEK:							* シーク
	lea	CDRIVE-A_MEM(aME),a0		*  8
	move.w	(a0),d1				*  8
	tst.w	FILENO-CDRIVE(a0,d1.w)		* 14
	bpl.s	SKMON				*  8(10)
	bsr.w	MOTORON				* 18
SKMON:
	move.b	$0FF9(a1),d0			* 12		* d0=TR
	move.b	$0FFB(a1),d1			* 12		* d1=DR
	move.b	d1,$0FF9(a1)			* 12
	sub.b	d0,d1				*  4		* d1=DR-TR

	ext.w	d1				*  4
	swap	d1				*  4
*	clr.w	d1				*  4
	asr.l	#3,d1				* 14		* d1=d1*$2000
*	lea	CDRIVE-A_MEM(aME),a0		*  8
	sgt	DIRC-CDRIVE(a0)			* 16

	move.w	(a0),d0				*  8
	add.l	d1,TRACK-CDRIVE(a0,d0.w)	* 26
	ble.s	TRACK00				*  8(10)
	moveq	#%00000000,d1			*  4
	move.b	d1,$0FF8(a1)			* 12
	rts					* 16
TRACK00:
	moveq	#0,d1				*  4
	move.l	d1,TRACK-CDRIVE(a0,d0.w)	* 18
	move.b	d1,$0FF9(a1)			* 12
	move.b	#%00000100,$0FF8(a1)		* 16		* Track00
	rts					* 16

READTRAK:						* リードトラック
	move.w	#$1900-1,A_RDAT+2-A_BAS(aBS)	* 16
	move.l	#$1900,-(sp)			* 20		* SIZE = $1900
	move.b	#$00,SECTOR-A_MEM(aME)		* 16
	bra.s	RDATA				* 10
READDATAm:
	move.w	#$1000-1,A_RDAT+2-A_BAS(aBS)	* 16
	move.l	#$1000,-(sp)			* 20		* SIZE = $1000
	bra.s	RDATA				* 10
READDATA:						* リードデータ
	move.w	#$0100-1,A_RDAT+2-A_BAS(aBS)	* 16
	move.l	#$0100,-(sp)			* 20		* SIZE =  $100
RDATA:
	lea	CDRIVE-A_MEM(aME),a0		*  8
	move.w	(a0),d1				*  8
	move.l	TRACK-CDRIVE(a0,d1.w),d0	* 18		*   TRACK
	add.w	HEAD-CDRIVE(a0),d0		* 12		* + HEAD
	add.w	SECTOR-CDRIVE(a0),d0		* 12		* + SECTOR

	move.w	#0,-(sp)			* 12		* MODE = 0 (先頭からのOFFSET)
	move.l	d0,-(sp)			* 12		* OFFSET = d0
	move.w	FILENO-CDRIVE(a0,d1.w),-(sp)	* 18		* FILENO = FILENO
	dc.w	$FF42						* DOS _SEEK
	addq.w	#8,sp				*  4
	tst.l	d0				*  4
	bmi.s	RDERR2				*  8(10)

	pea	B_DISK-CDRIVE(a0)		* 18		* DATAPTR = BDISK
	move.w	FILENO-CDRIVE(a0,d1.w),-(sp)	* 18		* FILENO = FILENO
	dc.w	$FF3F						* DOS _READ
	lea	10(sp),sp			*  8
	tst.l	d0				*  4
	bmi.s	RDERR				*  8(10)

	move.w	#-2,P_DISK-CDRIVE(a0)		* 16		* P_DISK = -2
	moveq	#%00000011,d0			*  4		* Data Request & Busy
*	moveq	#%00000000,d0			*  4
	move.b	d0,$0FF8(a1)			* 12
	rts					* 16

RDERR2:	addq.w	#4,sp				*  4
RDERR:	moveq	#%00010000,d0			*  4		* Record Not Found
	move.b	d0,$0FF8(a1)			* 12
	rts					* 16

READADRS:						* リードアドレス
	move.w	#$0006-1,A_RDAT+2-A_BAS(aBS)	* 16

	lea	CDRIVE-A_MEM(aME),a0		*  8
	move.w	#0,P_DISK-CDRIVE(a0)		* 16		* P_DISK = 0
	move.w	(a0),d1				*  8
	move.l	TRACK-CDRIVE(a0,d1.w),d0	* 18		*   TRACK
	move.b	HEAD-CDRIVE(a0),d1		* 12		* + HEAD
	swap	d0				*  4
	rol.l	#3,d0				* 14		* d0=d0/$2000
	ror.b	#4,d1				* 14
	move.b	d0,$0FFA(a1)			* 12

	lea	B_DISK-A_MEM(aME),a0		*  8
	move.b	d0,(a0)+			*  8		* トラックアドレス
	move.b	d1,(a0)+			*  8		* サイドナンバー

	moveq	#$0F,d0				*  4
	and.b	SCAD-A_MEM(aME),d0		* 12
	addq.b	#1,d0				*  4
	move.b	d0,SCAD-A_MEM(aME)		* 12
	move.b	d0,(a0)+			*  8		* セクタアドレス

	move.b	#$01,(a0)+			* 12		* セクタ長
	move.b	#$00,(a0)+			* 12		* ＣＲＣ１
	move.b	#$00,(a0)+			* 12		* ＣＲＣ２

	move.b	#%00000011,$0FF8(a1)		* 16		* Data Request & Busy
	rts					* 16

WRITTRAK:						* ライトトラック
	move.w	#$1900-1,A_WDAT+2-A_BAS(aBS)	* 16
	bra.s	WDATA				* 10
WRITDATAm:
	move.w	#$1000-1,A_WDAT+2-A_BAS(aBS)	* 16
	bra.s	WDATA				* 10
WRITDATA:						* ライトデータ
	move.w	#$0100-1,A_WDAT+2-A_BAS(aBS)	* 16
WDATA:
	lea	CDRIVE-A_MEM(aME),a0		*  8
	move.w	(a0),d1				*  8
	move.b	FILENO+2-CDRIVE(a0,d1.w),d0	* 14
	bne.s	WRITEP				*  8(10)

	move.w	#0,P_DISK-CDRIVE(a0)		* 16		* P_DISK = 0
	move.b	#%00000011,$0FF8(a1)		* 16		* Data Request & Busy
	rts					* 16
WRITEP:
	move.b	d0,$0FF8(a1)			* 12
	rts					* 16

WRTTRK:
	move.l	#$1000,-(sp)			* 20		* SIZE = $1900
	move.b	#%00000000,$0FF8(a1)		* 16
	move.b	#$00,SECTOR-A_MEM(aME)		* 16

	lea	B_DISK-A_MEM(aME),a0		*  8
	move.w	#$1000/4-1,d1			*  8
	moveq	#$FF,d0				*  4
LPWRTR:	move.l	d0,(a0)+			* 12
	dbf	d1,LPWRTR			* 14(10)

	bra.s	WRITE				* 10
WRTmSC:
	move.l	#$1000,-(sp)			* 20		* SIZE = $1000
	move.b	#%00010000,$0FF8(a1)		* 16		* Record Not Found
	bra.s	WRITE				* 10
WRTsSC:
	move.l	#$0100,-(sp)			* 20		* SIZE =  $100
	move.b	#%00000000,$0FF8(a1)		* 16
WRITE:
	lea	CDRIVE-A_MEM(aME),a0		*  8
	move.w	(a0),d1				*  8
	move.l	TRACK-CDRIVE(a0,d1.w),d0	* 18		*   TRACK
	add.w	HEAD-CDRIVE(a0),d0		* 12		* + HEAD
	add.w	SECTOR-CDRIVE(a0),d0		* 12		* + SECTOR

	move.w	#0,-(sp)			* 12		* MODE = 0 (先頭からのOFFSET)
	move.l	d0,-(sp)			* 12		* OFFSET = d0
	move.w	FILENO-CDRIVE(a0,d1.w),-(sp)	* 18		* FILENO = FILENO
	dc.w	$FF42						* DOS _SEEK
	addq.w	#8,sp				*  4
	tst.l	d0				*  4
	bmi.s	WTERR2				*  8(10)

	pea	B_DISK-CDRIVE(a0)		* 18		* DATAPTR = BDISK
	move.w	FILENO-CDRIVE(a0,d1.w),-(sp)	* 18		* FILENO = FILENO
	dc.w	$FF40						* DOS _WRITE
	lea	10(sp),sp			*  8
	tst.l	d0				*  4
	bmi.s	WTERR				*  8(10)

	moveq	#0,d0				*  4
	rts					* 16

WTERR2:	addq.w	#4,sp				*  4
WTERR:	moveq	#%00010000,d0			*  4		* Record Not Found
	move.b	d0,$0FF8(a1)			* 12
	rts					* 16

FORCEINT:
	move.w	#-1,P_DISK-A_MEM(aME)		* 16		* P_DISK = -1
	move.b	#%00000000,$0FF8(a1)		* 16
	rts					* 16


	.data

DIRC:	dc.b	$00
SCAD:	dc.b	$00
HEAD:	dc.w	$0000
SECTOR:	dc.w	$0000
CDRIVE:	dc.w	$0000

TRACK:	dcb.l	4,$00000000
FILENO:	dc.w	$FFFF,$0000
	dc.w	$FFFF,$0000
	dc.w	$FFFF,$0000
	dc.w	$FFFF,$0000
P_FILE:	dc.l	FD0
	dc.l	FD1
	dc.l	FD2
	dc.l	FD3

FD0:	ds.b	$80
FD1:	ds.b	$80
FD2:	ds.b	$80
FD3:	ds.b	$80

P_DISK:	dc.w	$FFFF
	ds.w	1
B_DISK:	ds.b	$1900

	.text


*---------------------------------------*
*    グラフィックパレット (10**-12**)	*
*---------------------------------------*

O1000:
	move.b	d1,$1000(a1)			* 12
	lea	PwTXTPAL+16*2,a0		* 12
	moveq	#8-1,d0				*  4

LP_O10:	btst	#4,PsMFPGPI			* 20		* bit4 = 0  垂直帰線期間
	bne.s	LP_O10				*  8(10)
	add.b	d1,d1				*  4
	bcs.s	ON_O10				*  8(10)
A_PALB:	andi.w	#%11111_11111_00000_1,-(a0)	* 18
	dbf	d0,LP_O10			* 14(10)
	rts
ON_O10:	ori.w	#%00000_00000_11111_0,-(a0)	* 18
	dbf	d0,LP_O10			* 14(10)
	rts

O1100:
	move.b	d1,$1100(a1)			* 12
	lea	PwTXTPAL+16*2,a0		* 12
	moveq	#8-1,d0				*  4

LP_O11:	btst	#4,PsMFPGPI			* 20		* bit4 = 0  垂直帰線期間
	bne.s	LP_O11				*  8(10)
	add.b	d1,d1				*  4
	bcs.s	ON_O11				*  8(10)
A_PALR:	andi.w	#%11111_00000_11111_1,-(a0)	* 18
	dbf	d0,LP_O11			* 14(10)
	rts
ON_O11:	ori.w	#%00000_11111_00000_0,-(a0)	* 18
	dbf	d0,LP_O11			* 14(10)
	rts

O1200:
	move.b	d1,$1200(a1)			* 12
	lea	PwTXTPAL+16*2,a0		* 12
	moveq	#8-1,d0				*  4

LP_O12:	btst	#4,PsMFPGPI			* 20		* bit4 = 0  垂直帰線期間
	bne.s	LP_O12				*  8(10)
	add.b	d1,d1				*  4
	bcs.s	ON_O12				*  8(10)
A_PALG:	andi.w	#%00000_11111_11111_1,-(a0)	* 18
	dbf	d0,LP_O12			* 14(10)
	rts
ON_O12:	ori.w	#%11111_00000_00000_0,-(a0)	* 18
	dbf	d0,LP_O12			* 14(10)
	rts


*---------------------------------------*
*	  プライオリティ (1300)		*
*---------------------------------------*

O1300:
	tst.b	BC					*  4
	bne.s	RTO13					*  8(10)
	tst.b	d1					*  4	* $00
	beq.s	PRW00					*  8(10)
	addq.b	#1,d1					*  4	* $FF
	beq.s	PRWFF					*  8(10)

	moveq	#0,d0					*  4
	jsr	S_CONT-A_BAS(aBS)			* 18
	move.w	#O1300c-A_BAS,(T_OUT+$13*2)-A_BAS(aBS)	* 16
PRWFF:	move.w	#%00_10_00_01_11_10_01_00,PwVCTRL2	* 20	* Ｘ１グラフィック優先
	rts						* 16
PRW00:	move.w	#%00_10_01_00_11_10_01_00,PwVCTRL2	* 20	* Ｘ１テキスト優先
RTO13:	rts						* 16
		*    SP TX GR P3 P2 P1 P0
O1300c:
	tst.b	BC					*  4
	bne.s	RTO13c					*  8(10)
	tst.b	d1					*  4	* $00
	beq.s	PRW00c					*  8(10)
	addq.b	#1,d1					*  4	* $FF
	bne.s	RTO13c					*  8(10)

	move.w	#%00_10_00_01_11_10_01_00,PwVCTRL2	* 20	* Ｘ１グラフィック優先
	bra.s	SKPRWc					* 10
PRW00c	move.w	#%00_10_01_00_11_10_01_00,PwVCTRL2	* 20	* Ｘ１テキスト優先
SKPRWc:	move.b	D_CONT-A_BAS(aBS),d0			* 12
	jsr	S_CONT-A_BAS(aBS)			* 18
	move.w	#O1300-A_BAS,(T_OUT+$13*2)-A_BAS(aBS)	* 16
RTO13c:	rts						* 16


*---------------------------------------*
*	   ＣＧ ＲＯＭ (14**)		*
*---------------------------------------*

I1400:
	move.w	VADR-A_MEM(aME),d0	* 12
	move.b	(a1,d0.w),d0		* 14
	andi.w	#$00FF,d0		*  8

	asl.w	#3,d0			* 12
	add.b	RAST-A_MEM(aME),d0	* 12
	addq.b	#1,RAST-A_MEM(aME)	* 16

	lea	CGROM-A_MEM(aME),a0	*  8
	move.b	(a0,d0.w),d1		* 14
	rts				* 16


*---------------------------------------*
*	   ＰＣＧ (15**-17**)		*
*---------------------------------------*

M_PCGI	macro	BN

	local	GETCH
	local	LPPCG
	local	RAST0
	local	SMCOL

	move.w	d2,-(sp)		*  8
	move.b	RAST-A_MEM(aME),d1	* 12
	beq.s	RAST0			*  8(10)
	cmp.w	PCGADR-A_MEM(aME),d0	* 12
	beq.s	SMCOL			*  8(10)
	subq.b	#1,d1			*  4
GETCH:
	clr.w	d0			*  4
	move.w	VADR-A_MEM(aME),d2	* 12
	move.b	(a1,d2.w),d0		* 14
	asl.w	#3,d0			* 12
	add.b	d1,d0			*  4
	asl.w	#3,d0			* 12

	lea	CGRAM,a0		* 12
	adda.w	d0,a0			*  8
	moveq	#BN,d1			*  4
	moveq	#8-1,d0			*  4
LPPCG:	btst	d1,(a0)+		*  8
	sne	d2			*  4/6
	add.w	d2,d2			*  4
	dbf	d0,LPPCG		* 14(10)

	move.w	d2,-(sp)		*  8
	move.b	(sp)+,d1		*  8
	move.w	(sp)+,d2		*  8
	rts				* 16

RAST0:	move.w	d0,PCGADR-A_MEM(aME)	* 12
SMCOL:	addq.b	#1,RAST-A_MEM(aME)	* 16
	bra.s	GETCH			* 10	

	endm


M_PCGO	macro	BN

	local	GETCH
	local	LPPCG
	local	COPYe
	local	ONPCG
	local	RAST0
	local	SMCOL

	move.w	d2,-(sp)		*  8
	move.b	d1,d2			*  4
	move.b	RAST-A_MEM(aME),d1	* 12
	beq.s	RAST0			*  8(10)
	cmp.w	PCGADR-A_MEM(aME),d0	* 12
	beq.s	SMCOL			*  8(10)
	subq.b	#1,d1			*  4
GETCH:
	move.w	VADR-A_MEM(aME),d0	* 12
	move.b	(a1,d0.w),d0		* 14
	andi.w	#$00FF,d0		*  8
	asl.w	#3,d0			* 12
	add.b	d1,d0			*  4
	asl.w	#3,d0			* 12

	lea	CGRAM,a0		* 12
	lea	$4000(a0),a1		*  8
	adda.w	d0,a0			*  8
	add.w	d0,d0			*  4
	adda.w	d0,a1			*  8
	moveq	#BN,d1			*  4
	moveq	#8-1,d0			*  4
LPPCG:	add.b	d2,d2			*  4
	bcs.s	ONPCG			*  8(10)
	bclr	d1,(a0)+		* 12
	dbf	d0,LPPCG		* 14(10)
COPYe:
	subq.w	#$08,a0			*  4
	move.l	(a0)+,d0		* 12
	movep.l	d0,$00(a1)		* 24
	movep.l	d0,$01(a1)		* 24
	move.l	(a0)+,d0		* 12
	movep.l	d0,$08(a1)		* 24
	movep.l	d0,$09(a1)		* 24

	lea	A_IOB,a1		* 12
	moveq	#0,d0			*  4
	move.w	(sp)+,d2		*  8
	rts				* 16
ONPCG:
	bset	d1,(a0)+		* 12
	dbf	d0,LPPCG		* 14(10)
	bra.s	COPYe			* 10

RAST0:	move.w	d0,PCGADR-A_MEM(aME)	* 12
SMCOL:	addq.b	#1,RAST-A_MEM(aME)	* 16
	bra.s	GETCH			* 10	

	endm


I1500:	M_PCGI	0
I1600:	M_PCGI	1
I1700:	M_PCGI	2

O1500:	M_PCGO	0
O1600:	M_PCGO	1
O1700:	M_PCGO	2


	.data
PCGADR:	ds.w	1
RAST:	dc.b	0
	.even
	.text


*---------------------------------------*
*	  ＣＲＴＣ (18*0,18*1)		*
*	  ＨＤ４６５０５－ＳＰ		*
*---------------------------------------*

O1800:
	moveq	#$01,d0			*  4
	and.b	BC,d0			*  4
	bne.s	CRTCDAT			*  8(10)
	move.b	d1,$1800(a1)		* 12
	rts				* 16
CRTCDAT:
	cmpi.b	#12,$1800(a1)		* 16
	bne.s	RTCRTC			*  8(10)
	andi.b	#$07,d1			*  8
	move.b	d1,$1800+$80+12(a1)	* 12
A_SC1:	bne.s	W40SC1			*  8(10)
	btst	#6,$1A02(a1)		* 16
A_SC0:	bne.s	W40SC0			*  8(10)

	move.w	#$37D0+OVAD,VADR-A_MEM(aME)	* 16
	clr.w	d0				*  4
	move.w	d0,PwSCTXTY			* 16
	move.w	d0,PwSCGP0Y			* 16
RTCRTC:	rts					* 16

W403D0:	move.b	#%01,PsSYSPT2			* 20
W40SC0:	move.w	#$33E8+OVAD,VADR-A_MEM(aME)	* 16
	clr.w	d0				*  4
	move.w	d0,PwSCTXTY			* 16
	move.w	d0,PwSCGP0Y			* 16
	rts					* 16

W403D1:	move.b	#%10,PsSYSPT2			* 20
W40SC1:	move.w	#$37E8+OVAD,VADR-A_MEM(aME)	* 16
	move.w	#$0100,d0			*  8
	move.w	d0,PwSCTXTY			* 16
	move.w	d0,PwSCGP0Y			* 16
	rts					* 16

	.data
VADR:	ds.w	1
	.text


*---------------------------------------*
*     サブＣＰＵ ８０Ｃ４９ (1900)	*
*	    （８２５５＃１）		*
*---------------------------------------*

I1900:
*	moveq	#%00000011,d0		*  4
*	and.b	BC,d0			*  4
	tst.b	BC			*  4
	bne.s	RTISUB			*  8(10)

	lea	P_SUB-A_MEM(aME),a0	*  8
	move.w	(a0),d0			*  8
	move.b	B_SUB-P_SUB(a0,d0.w),d1	* 14
	subq.w	#1,d0			*  4
	bcs.s	RTSOBF			*  8(10)
	move.w	d0,(a0)			*  8
	rts				* 16
RTSOBF:	move.b	#%00100000,$1A01(a1)	* 16
	rts				* 16

RTISUB:	clr.b	d1			*  4
RTOSUB:	rts				* 16


O1900:
*	moveq	#%00000011,d0		*  4
*	and.b	BC,d0			*  4
	tst.b	BC			*  4
	bne.s	RTOSUB			*  8(10)

	move.b	$1900(a1),d0		* 12
	subi.b	#$E4,d0			*  8		* $E4 SETVCT
	beq.s	SETVCT			*  8(10)
	subq.b	#$03,d0			*  4		* $E7 TVCTRL
	beq.s	TVCTRL			*  8(10)
	subq.b	#$02,d0			*  4		* $E9 CMTCTL
	beq.s	CMTCTL			*  8(10)

*	moveq	#%01000000,d0		*  4
	moveq	#%00000000,d0		*  4
	move.b	d0,$1A01(a1)		* 12
	move.b	d1,$1900(a1)		* 12

	move.b	d1,d0			*  4
	subi.b	#$D0,d0			*  8
	bcs.s	RTSOBF			*  8(10)
	add.w	d0,d0			*  4
	lea	P_SUB-A_MEM(aME),a0	*  8
	move.w	T_SUB-P_SUB(a0,d0.w),d0	* 14
	jmp	(aBS,d0.w)		* 14


SETVCT:
	move.b	d0,$1900(a1)		* 12
	move.b	d1,V_KEY-A_BAS(aBS)	* 12
	rts				* 16
CMTCTL:
	move.b	d0,$1900(a1)		* 12
	move.b	d1,$1900+$E9(a1)	* 12
	rts				* 16
TVCTRL:
	move.b	d0,$1900(a1)		* 12
	move.b	d1,$1900+$E7(a1)	* 12

	andi.w	#%10011111,d1		*  8
	cmpi.b	#$80,d1			*  8
	bne.s	SKTVC1			*  8(10)
	moveq	#$07,d1			*  4
SKTVC1:	moveq	#%01111111,d0		*  4
	and.b	d1,d0			*  4
	subq.b	#$04,d0			*  4
	beq.b	RTTVK			*  8(10)
	subq.b	#$05,d0			*  4
	bne.s	SKTVC2			*  8(10)
	subq.b	#$05,d1			*  4
SKTVC2:	tst.b	d1			*  4
	bpl.s	SKTVC3			*  8(10)
	eori.b	#%10100000,d1		*  8
SKTVC3:
	moveq	#$0C,d0			*  4		* IOCS _TVCTRL
	trap	#15
	moveq	#0,d0			*  4
RTTVK:	rts				* 16

GETTVT:
	clr.b	B_SUB+6-1-A_MEM(aME)	* 16
	move.w	#6-1,P_SUB-A_MEM(aME)	* 16
	rts				* 16
GETCMT:
	move.b	$1900+$E9(a1),B_SUB-A_MEM(aME)	* 20
	rts					* 16
GETTVC:
	move.b	$1900+$E7(a1),B_SUB-A_MEM(aME)	* 20
	rts					* 16
GETSNS:
	move.b	#%10010000,B_SUB-A_MEM(aME)	* 16
	rts					* 16

GETDAT:
	moveq	#$54,d0			*  4		* IOCS _DATEGET
	trap	#15
	move.w	#3-1,(a0)+		* 12

	move.b	d0,(a0)+		*  8
	move.w	d0,-(sp)		*  8
	move.b	(sp)+,d1		*  8
	asl.b	#4,d1			* 14
	bcc.s	SKDATE			*  8(10)
	addi.b	#$A0,d1			*  8
SKDATE:	swap	d0			*  4
	move.w	d0,-(sp)		*  8
	or.b	(sp)+,d1		*  8
	move.b	d1,(a0)+		*  8
	addi.b	#$80,d0			*  8
	move.b	d0,(a0)+		*  8

	moveq	#0,d0			*  4
	rts				* 16

GETTIM:
	moveq	#$56,d0			*  4		* IOCS _TIMEGET
	trap	#15
	move.w	#3-1,(a0)+		* 12

	move.b	d0,(a0)+		*  8
	move.w	d0,-(sp)		*  8
	move.b	(sp)+,(a0)+		* 12
	swap	d0			*  4
	move.b	d0,(a0)+		*  8

	moveq	#0,d0			*  4
	rts				* 16

*---------------------------------------

GETKEYI:
	move.l	a1,-(sp)		* 12

	bsr.w	GKEY2			* 18
	move.b	d1,-(sp)		*  8
	bsr.w	GKEY1			* 18
	move.w	(sp)+,d0		*  8
	move.b	d1,d0			*  4

	movea.l	(sp)+,a1		* 12
	rts				* 16

GETKEY:
	move.w	#2-1,P_SUB-A_MEM(aME)	* 16
	lea	D_KEY-A_BAS(aBS),a0	*  8
	clr.w	d0			*  4
	move.b	(a0),d0			*  8
	beq.s	NULL			*  8(10)

	bsr.w	GKEY2			* 18
	move.b	d1,B_SUB+0-A_MEM(aME)	* 12
	bsr.w	GKEY1			* 18
	move.b	d1,B_SUB+1-A_MEM(aME)	* 12

	lea	A_IOB,a1		* 12
	rts				* 16
NULL:
	move.w	#$00FF,B_SUB-A_MEM(aME)	* 16
	rts				* 16

GKEY1:
	clr.b	d1			*  4
	cmpi.b	#$61,d0			*  8
	beq.s	SKMKEY			*  8(10)
	cmpi.b	#$36,d0			*  8
	bcs.s	SKMKEY			*  8(10)
	addq.b	#%00000100,d1		*  4	* BIT 7 FCKEY
SKMKEY:	addq.b	#%00000010,d1		*  4	* BIT 6	KEYIN
	sub.b	F_REPT+0-D_KEY(a0),d1	* 12	* BIT 5	REPEAT
	add.b	d1,d1			*  4
	sub.b	F_SIFT+2-D_KEY(a0),d1	* 12	* BIT 4	GRAPH
	add.b	d1,d1			*  4
	sub.b	F_LOCK+0-D_KEY(a0),d1	* 12	* BIT 3	CAPS LOCK
	add.b	d1,d1			*  4
	sub.b	F_LOCK+1-D_KEY(a0),d1	* 12	* BIT 2	ｶﾅ
	add.b	d1,d1			*  4
	sub.b	F_SIFT+0-D_KEY(a0),d1	* 12	* BIT 1	SHIFT
	add.b	d1,d1			*  4
	sub.b	F_SIFT+1-D_KEY(a0),d1	* 12	* BIT 0	CTRL
	not.b	d1			*  4
	rts

GKEY2:
	tst.b	F_SIFT+1-D_KEY(a0)	* 12
	bne.s	ONCTRL			*  8(10)
	tst.b	F_SIFT+2-D_KEY(a0)	* 12
	bne.s	ONGRAH			*  8(10)
	tst.b	F_LOCK+1-D_KEY(a0)	* 12
	bne.s	ONKANA			*  8(10)

	lea	T_XKEY,a1		* 12
	tst.b	F_SIFT+0-D_KEY(a0)	* 12
	beq.s	OFSIFT			*  8(10)
	lea	$80(a1),a1		*  8
OFSIFT:	move.b	(a1,d0.w),d1		* 14
	cmpi.b	#$31,d0			*  8
	bcc.s	OFCAPS			*  8(10)
	tst.b	F_LOCK+0-D_KEY(a0)	* 12
	beq.s	OFCAPS			*  8(10)

	cmpi.b	#'A',d1			*  8
	bcs.s	OFCAPS			*  8(10)
	cmpi.b	#'z',d1			*  8
	bhi.s	OFCAPS			*  8(10)
	cmpi.b	#'a',d1			*  8
	bcc.s	ONCAPS			*  8(10)
	cmpi.b	#'Z',d1			*  8
	bhi.s	OFCAPS			*  8(10)
ONCAPS:	eori.b	#$20,d1			*  8
OFCAPS:	rts				* 16

ONKANA:
	lea	T_XKEY+$100,a1		* 12
	tst.b	F_SIFT+0-D_KEY(a0)	* 12
	beq.s	OFSFTK			*  8(10)
	lea	$80(a1),a1		*  8
OFSFTK:	move.b	(a1,d0.w),d1		* 14
	rts				* 16
ONCTRL:
	lea	T_XKEY+$200,a1		* 12
	move.b	(a1,d0.w),d1		* 14
	rts				* 16
ONGRAH:
	lea	T_XKEY+$280,a1		* 12
	move.b	(a1,d0.w),d1		* 14
	rts				* 16


	.data

P_SUB:	dc.w	0
B_SUB:	ds.b	8
T_SUB:						*	       OUT IN
	dcb.w	1-$D0+$D7,.loww.(RTSOBF-A_BAS)	* D0-D7	SETTVT	6
	dcb.w	1-$D8+$DF,.loww.(GETTVT-A_BAS)	* D8-DF	GETTVT	    6
	dcb.w	1-$E0+$E3,.loww.(RTSOBF-A_BAS)	* E0-E3
	dc.w	RTSOBF-A_BAS			* $E4	SETVCT	1
	dc.w	RTSOBF-A_BAS			* $E5
	dc.w	GETKEY-A_BAS			* $E6	GETKEY	    2
	dc.w	RTSOBF-A_BAS			* $E7	TVCTRL	1
	dc.w	GETTVC-A_BAS			* $E8	GETTVC	    1
	dc.w	RTSOBF-A_BAS			* $E9	CMTCTL	1
	dc.w	GETCMT-A_BAS			* $EA	GETCMT	    1
	dc.w	GETSNS-A_BAS			* $EB	GETSNS	    1
	dc.w	RTSOBF-A_BAS			* $EC	SETDAT	3
	dc.w	GETDAT-A_BAS			* $ED	GETDAT	    3
	dc.w	RTSOBF-A_BAS			* $EE	SETTIM	3
	dc.w	GETTIM-A_BAS			* $EF	GETTIM	    3
	dcb.w	1-$F0+$FF,.loww.(RTSOBF-A_BAS)	* F0-FF

	.text


*---------------------------------------*
*   ８２５５＃２(メイン側) (1A*0-1A*3)	*
*	     ８２５５ Ｃ－５		*
*---------------------------------------*

*$1A01		IN			 $1A02		OUT

*bit 7	垂直帰線期間信号(0)	*	 bit 7	プリンタDATA STROBE(0-1)*
*    6	80C49 へ   OUT 禁止	*	     6	0=80 / 1=40 桁		*
*    5	80C49 から IN  禁止	*	     5	同時アクセスモード(1-0)	*
*    4	----------------	0	     4	スムーズスクロール(0)
*    3	プリンタBUSY		*	     3	----------------
*    2	垂直同期信号		*	     2	----------------
*    1	CMT READ DATA		0	     1	----------------
*    0	CMT BREAK信号(0)	1	     0	CMT WRITE DATA


I1A00s:
	moveq	#%01100000,d1		*  4
	subq.l	#1,C_I1As-A_MEM(aME)	* 24
	beq.s	EXI1As			*  8(10)
	rts				* 16
EXI1As:
	move.b	#%00100000,$1A01(a1)
	move.w	#I1A00-A_BAS,T_INP+$1A*2
	rts

	.data
C_I1As:	ds.l	1
	.text

*---------------------------------------

I1A00:
	move.w	BC,d0			*  4
	andi.b	#%00000011,d0		*  8
	move.b	(a1,d0.w),d1		* 14
	subq.b	#1,d0			*  4
	bne.s	RTI1A			*  8(10)

	move.b	d0,RAST-A_MEM(aME)	* 12
	btst	#4,PsMFPGPI		* 20		* bit4 = 0  垂直帰線期間
	beq.s	VDISP0			*  8(10)

	ori.b	#%10000001,d1		*  8
	btst	#5,PsINTSTA		* 20		* bit5 = 0  プリンタBUSY
	bne.s	RTI1A			*  8(10)
	addq.b	#%00001000,d1		*  4
	rts				* 16

VDISP0:	addq.b	#%00000101,d1		*  4
	btst	#5,PsINTSTA		* 20		* bit5 = 0  プリンタBUSY
	bne.s	RTI1A			*  8(10)
	addq.b	#%00001000,d1		*  4
RTI1A:	rts				* 16


O1A00:
	moveq	#%00000011,d0		*  4
	and.b	BC,d0			*  4
	beq.s	O1A00o			*  8(10)
	subq.b	#2,d0			*  4
	beq.s	O1A02			*  8(10)
	subq.b	#1,d0			*  4
	beq.s	O1A03			*  8(10)
	rts				* 16

O1A00o:
	move.b	d1,PsPRNDAT		* 16		* プリンタデータ
	rts				* 16

O1A02:
	move.b	d1,$1A02(a1)		* 12

	add.b	d1,d1			*  4
	scs	d0			*  4/6
	bsr.s	PCBIT7			* 18
	add.b	d1,d1			*  4
	scs	d0			*  4/6
	bsr.s	PCBIT6			* 18
	add.b	d1,d1			*  4
	scs	d0			*  4/6
	bra.s	PCBIT5			* 10

O1A03:
	andi.b	#%10001111,d1		*  8
	bmi	RTO1A3			*  8(10)

	lsr.b	#1,d1			*  8
	scs	d0			*  4/6
	bcs.s	SETPC			*  8(10)
	bclr	d1,$1A02(a1)		* 16
	bra.s	SKO13			* 10
SETPC:	bset	d1,$1A02(a1)		* 16
SKO13:
	subq.b	#$05,d1			*  4
	beq.s	PCBIT5			*  8(10)
	subq.b	#$01,d1			*  4
	beq.s	PCBIT6			*  8(10)
	subq.b	#$01,d1			*  4
	beq.s	PCBIT7			*  8(10)
RTO1A3:	rts				* 16

PCBIT7:						* プリンタデータSTROBE
	neg.b	d0			*  4
	move.b	d0,PsPRNSTO		* 16		* bit0 = 0  STROBE 'Low'
	rts				* 16

PCBIT5:						* (-1 - 0) 同時アクセスモード
	tst.b	d0			*  4
	bne.s	RTPC5			*  8(10)

	tst.b	$1A00+$A5(a1)		* 12	* $1A00+$80+$20+5
	bne.s	DAMODE			*  8(10)
RTPC5:	move.b	d0,$1A00+$A5(a1)	* 12
	rts				* 16

DAMODE:
	move.b	d0,$1A00+$A5(a1)	* 12

	lea	OUTD-A_BAS(aBS),a0	*  8
	lea	OUT-A_BAS(aBS),a1	*  8
	moveq	#(OUTDe-OUTD)/2-1,d0	*  4
LPDAM:	move.w	(a0)+,(a1)+		* 12
	dbf	d0,LPDAM		* 14(10)

	move.l	#($6000*$10000)+.loww.(INPD-(INP+2)),INP-A_BAS(aBS)	* 24	* bra.w INPD
	lea	A_IOB,a1		* 12
	rts				* 16

PCBIT6:							* WIDTH (0=80/-1=40桁)
	move.w	d1,-(sp)			*  8
	lea	T_OUT+$20*2-A_MEM(aME),a0	*  8
	tst.b	d0				*  4
	bne.s	WIDTH40				*  8(10)
WIDTH80:
	move.w	#$37D0+OVAD,VADR-A_MEM(aME)	* 16
	move.w	#(O2000H-A_BAS),d1	*  8
	moveq	#$08-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(O2800H-A_BAS),d1	*  8
	moveq	#$08-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(O3000H-A_BAS),d1	*  8
	moveq	#$08-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(O3800H-A_BAS),d1	*  8
	moveq	#$08-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(O4000H-A_BAS),d1	*  8
	moveq	#$40-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(O8000H-A_BAS),d1	*  8
	moveq	#$40-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(OC000H-A_BAS),d1	*  8
	moveq	#$40-1,d0		*  4
	bsr.s	SBWIDT			* 18

	move.w	#(DAMD0H-OUT)+(OUTD-(A_OD0+2)),A_OD0+2-A_BAS(aBS)	* 16
	move.w	#(DAMD4H-OUT)+(OUTD-(A_OD4+2)),A_OD4+2-A_BAS(aBS)	* 16
	move.w	#(DAMD8H-OUT)+(OUTD-(A_OD8+2)),A_OD8+2-A_BAS(aBS)	* 16
	move.w	#(DAMDCH-OUT)+(OUTD-(A_ODC+2)),A_ODC+2-A_BAS(aBS)	* 16
	move.w	(sp)+,d1		*  8
	rts				* 16

WIDTH40:
	move.w	#$33E8+OVAD,d0		*  8
	tst.b	$1800+$80+12(a1)	* 12
	beq.s	SKDW40			*  8(10)
	move.w	#$37E8+OVAD,d0		*  8
SKDW40:
	move.w	d0,VADR-A_MEM(aME)	* 12
	move.w	#(O2000L-A_BAS),d1	*  8
	moveq	#$08-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(O2800L-A_BAS),d1	*  8
	moveq	#$08-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(O3000L-A_BAS),d1	*  8
	moveq	#$08-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(O3800L-A_BAS),d1	*  8
	moveq	#$08-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(O4000L-A_BAS),d1	*  8
	moveq	#$40-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(O8000L-A_BAS),d1	*  8
	moveq	#$40-1,d0		*  4
	bsr.s	SBWIDT			* 18
	move.w	#(OC000L-A_BAS),d1	*  8
	moveq	#$40-1,d0		*  4
	bsr.s	SBWIDT			* 18

	move.w	#(DAMD0L-OUT)+(OUTD-(A_OD0+2)),A_OD0+2-A_BAS(aBS)	* 16
	move.w	#(DAMD4L-OUT)+(OUTD-(A_OD4+2)),A_OD4+2-A_BAS(aBS)	* 16
	move.w	#(DAMD8L-OUT)+(OUTD-(A_OD8+2)),A_OD8+2-A_BAS(aBS)	* 16
	move.w	#(DAMDCL-OUT)+(OUTD-(A_ODC+2)),A_ODC+2-A_BAS(aBS)	* 16
	move.w	(sp)+,d1		*  8
	rts				* 16

SBWIDT:
	move.w	d1,(a0)+		*  8
	dbf	d0,SBWIDT		* 14(10)
	rts				* 16


*---------------------------------------*
*	   ＰＳＧ (1B**,1C**)		*
*	   ＡＹ－３－８９１０		*
*---------------------------------------*

I1B00:
	clr.w	d0			*  4
	lea	$1B00(a1),a0		*  8
	move.b	$0100(a0),d0		* 12

	cmpi.b	#14,d0			*  8
	beq.s	JOY1			*  8(10)
	cmpi.b	#15,d0			*  8
	beq.s	JOY2			*  8(10)
	move.b	(a0,d0.w),d1		* 14
RTPSG:	rts				* 16
JOY1:
	move.b	PsJOYST1,d1		* 16
	rts				* 16
JOY2:
	move.b	PsJOYST2,d1		* 16
	rts				* 16

O1B00:
	clr.w	d0			*  4
	lea	$1B00(a1),a0		*  8
	move.b	$0100(a0),d0		* 12

	cmpi.b	#16,d0			*  8
	bcc.s	RTPSG			*  8(10)
	move.b	d1,(a0,d0.w)		* 14
	add.w	d0,d0			*  4
	move.w	T_PSG(pc,d0.w),d0	* 14
	jmp	(aBS,d0.w)		* 14

O1C00:
	move.b	d1,$1C00(a1)		* 12
	rts				* 16

T_PSG:
	dc.w	PSG00-A_BAS
	dc.w	PSG01-A_BAS
	dc.w	PSG02-A_BAS
	dc.w	PSG03-A_BAS
	dc.w	PSG04-A_BAS
	dc.w	PSG05-A_BAS
	dc.w	PSG06-A_BAS
	dc.w	PSG07-A_BAS
	dc.w	PSG08-A_BAS
	dc.w	PSG09-A_BAS
	dc.w	PSG10-A_BAS
	dc.w	PSG11-A_BAS
	dc.w	PSG12-A_BAS
	dc.w	PSG13-A_BAS
	dc.w	PSG14-A_BAS
	dc.w	PSG15-A_BAS

PSG14:
PSG15:
	rts

PSG00:
	move.b	$1B00+01(a1),-(sp)	* 16
	move.w	(sp)+,d0		*  8
	move.b	d1,d0			*  4
	moveq	#$20+4,d1		*  4
	bra.s	TFREQ			* 10
PSG01:
	move.b	d1,-(sp)		*  8
	move.w	(sp)+,d0		*  8
	move.b	$1B00+00(a1),d0		* 12
	moveq	#$20+4,d1		*  4
	bra.s	TFREQ			* 10
PSG02:
	move.b	$1B00+03(a1),-(sp)	* 16
	move.w	(sp)+,d0		*  8
	move.b	d1,d0			*  4
	moveq	#$20+5,d1		*  4
	bra.s	TFREQ			* 10
PSG03:
	move.b	d1,-(sp)		*  8
	move.w	(sp)+,d0		*  8
	move.b	$1B00+02(a1),d0		* 12
	moveq	#$20+5,d1		*  4
	bra.s	TFREQ			* 10
PSG04:
	move.b	$1B00+05(a1),-(sp)	* 16
	move.w	(sp)+,d0		*  8
	move.b	d1,d0			*  4
	moveq	#$20+6,d1		*  4
	bra.s	TFREQ			* 10
PSG05:
	move.b	d1,-(sp)		*  8
	move.w	(sp)+,d0		*  8
	move.b	$1B00+04(a1),d0		* 12
	moveq	#$20+6,d1		*  4
	bra.s	TFREQ			* 10

ERT000:
	lea	PsOPMDAT,a0		* 12
	bsr.w	WAITOPM			* 18
	move.b	d1,-2(a0)		* 12
	bsr.w	WAITOPM			* 18
	move.b	#%00_111_101,(a0)	* 12
	rts				* 16
ERKF64:
	tst.w	12*4+2(a0)		* 12
	bmi.s	SKOCTU			*  8(10)
	add.w	12*4+2(a0),d2		* 12
	bra.s	SETFM			* 10
SKOCTU:	
	addi.b	#$10,d2			*  8
	bpl.s	SETFM			*  8(10)
EROCT8:
	move.w	#$007F,d2		*  8
	move.w	#$00FC,d0		*  8
	bra.s	SETFM			* 10
TFREQ:
	andi.w	#$0FFF,d0		*  8
	cmpi.w	#$0005,d0		*  8
	bls.s	ERT000			*  8(10)
	move.w	d2,-(sp)		*  8

	clr.w	d2			*  4
LPOCT:	cmpi.w	#3228,d0		*  8
	bcc.s	BKOCT			*  8(10)
	add.w	d0,d0			*  4
	addq.w	#%00001000,d2		*  4
	bra.s	LPOCT			* 10
BKOCT:
	add.b	d2,d2			*  4
	bmi.s	EROCT8			*  8(10)
	lea	D_PSG-A_MEM(aME),a0	*  8
LPNOTE:	cmp.w	(a0)+,d0		*  8
	bcs.s	LPNOTE			*  8(10)

	sub.w	-(a0),d0		* 10
	asl.w	#6,d0			* 18
*	ext.l	d0			*  4
	divu	12*2(a0),d0		*<148
	beq.s	ERKF64			*  8(10)
	subi.w	#64,d0			*  8
	neg.w	d0			*  4
	add.w	d0,d0			*  4
	add.w	d0,d0			*  4

	add.w	12*4(a0),d2		* 12
SETFM:	lea	PsOPMDAT,a0		* 12

	bsr.w	WAITOPM			* 18
	move.b	d1,-2(a0)		* 12
	bsr.w	WAITOPM			* 18
	move.b	#%11_111_101,(a0)	* 12

	addq.b	#$08,d1			*  4
	bsr.w	WAITOPM			* 18
	move.b	d1,-2(a0)		* 12
	bsr.w	WAITOPM			* 18
	move.b	d2,(a0)			*  8

	addq.b	#$08,d1			*  4
	bsr.w	WAITOPM			* 18
	move.b	d1,-2(a0)		* 12
	bsr.w	WAITOPM			* 18
	move.b	d0,(a0)			*  8

	moveq	#0,d0			*  4
	move.w	(sp)+,d2		*  8
	rts				* 16

	.data
D_PSG:	dc.w	6092,5750,5427,5123,4835,4564,4308,4066,3838,3622,3419,3228
	dc.w	0363,0342,0323,0304,0288,0271,0256,0242,0228,0216,0203,0191
	dc.w	$000,$001,$002,$004,$005,$006,$008,$009,$00A,$00C,$00D,$00E,$FFFF
	.text

PSG06:
	andi.b	#%00011111,d1		*  8
	ori.b	#%10000000,d1		*  8
	lea	PsOPMDAT,a0		* 12
	moveq	#$0F,d0			*  4
	bra.w	SETOPM			* 10

PSG07:
	lea	PsOPMDAT,a0		* 12

	move.l	F_PSG-A_MEM(aME),d0	* 16
	beq.s	SKPSGV			*  8(10)
	bsr.w	PSGVOI			* 18
SKPSGV:
	bsr.w	WAITOPM			* 18
	move.b	#$08,-2(a0)		* 16

	asl.b	#3,d1			* 12
	scc	F_ONN+2-A_MEM(aME)	* 16
	add.b	d1,d1			*  4
	scc	F_ONN+1-A_MEM(aME)	* 16
	add.b	d1,d1			*  4
	scc	F_ONN+0-A_MEM(aME)	* 16
PSGKON:
	moveq	#%0_1111_111,d0		*  4
	tst.l	F_ONN-A_MEM(aME)	* 16
	bne.s	PSGNON			*  8(10)
	moveq	#%0_0000_111,d0		*  4
PSGNON:	bsr.w	WAITOPM			* 18
	move.b	d0,(a0)			*  8

	moveq	#%0_1111_110,d0		*  4
	add.b	d1,d1			*  4
	bcc.s	PSGCON			*  8(10)
	moveq	#%0_0000_110,d0		*  4
PSGCON:	bsr.w	WAITOPM			* 18
	move.b	d0,(a0)			*  8

	moveq	#%0_1111_101,d0		*  4
	add.b	d1,d1			*  4
	bcc.s	PSGBON			*  8(10)
	moveq	#%0_0000_101,d0		*  4
PSGBON:	bsr.w	WAITOPM			* 18
	move.b	d0,(a0)			*  8

	moveq	#%0_1111_100,d0		*  4
	add.b	d1,d1			*  4
	bcc.s	PSGAON			*  8(10)
	moveq	#%0_0000_100,d0		*  4
PSGAON:	bsr.w	WAITOPM			* 18
	move.b	d0,(a0)			*  8

	rts				* 16

PSGVOI:
	move.b	d1,-(sp)		*  8

	tst.b	d0			*  4
	bpl.s	SKPSGN			*  8(10)
	moveq	#$20+7,d1		*  4
	bsr.w	VSETN			* 18
SKPSGN:
	swap	d0			*  4
	bpl.s	SKPSGC			*  8(10)
	moveq	#$20+6,d1		*  4
	bsr.w	VSETP			* 18
SKPSGC:
	tst.b	d0			*  4
	bpl.s	SKPSGB			*  8(10)
	moveq	#$20+5,d1		*  4
	bsr.w	VSETP			* 18
SKPSGB:
	tst.w	d0			*  4
	bpl.s	SKPSGA			*  8(10)
	moveq	#$20+4,d1		*  4
	bsr.w	VSETP			* 18
SKPSGA:
	moveq	#0,d0			*  4
	move.l	d0,F_PSG-A_MEM(aME)	* 16
	move.b	(sp)+,d1		*  8
	rts				* 16

PSG08:
	moveq	#$68+4,d0		*  4
	bra.s	SETVOL			* 10
PSG09:
	moveq	#$68+5,d0		*  4
	bra.s	SETVOL			* 10
PSG10:
	moveq	#$68+6,d0		*  4
	bra.s	SETVOL			* 10

	*	v00 v01 v02 v03 v04 v05 v06 v07 v08 v09 v10 v11 v12 v13 v14 v15
D_VOL:	dc.b	127,066,050,042,034,030,026,022,018,016,014,012,010,008,006,004

SETVOL:
	lea	PsOPMDAT,a0		* 12
	lea	F_ENV-A_MEM(aME),a1	*  8

	andi.w	#%00011111,d1		*  8
	bclr	#4,d1			*<14
	bne.s	SETENV			*  8(10)
	tst.b	0-($68+4)(a1,d0.w)	* 14
	bne.s	RESENV			*  8(10)
SETTL:
	move.b	D_VOL(pc,d1.w),d1	* 14
	tst.b	4-($68+4)(a1,d0.w)	* 14
	beq.s	SKSNOI			*  8(10)

	bsr.w	WAITOPM			* 18
	move.b	#$7F,-2(a0)		* 16
	bsr.w	WAITOPM			* 18
	move.b	d1,(a0)			*  8
SKSNOI:
	bsr.w	SETOPM			* 18
	addq.b	#8,d0			*  4
	bsr.w	SETOPM			* 18
	addq.b	#8,d0			*  4
	bsr.w	SETOPM			* 18

	lea	A_IOB,a1		* 12
	rts				* 16
RESENV:
	st	F_OFE-A_MEM(aME)	* 16
	sf	0-($68+4)(a1,d0.w)	* 18
	move.w	d1,-(sp)		*  8
	move.w	#$1F00,d1		*  8
	bra.s	JPSENV			* 10
SETENV:
	moveq	#15,d1			*  4
	tst.b	0-($68+4)(a1,d0.w)	* 14
	bne.s	SETTL			*  8(10)

	st	0-($68+4)(a1,d0.w)	* 18
	move.w	d1,-(sp)		*  8
	move.w	D_ENV-A_MEM(aME),d1	* 12
JPSENV:
	tst.b	4-($68+4)(a1,d0.w)	* 14
	beq.s	SKENOI			*  8(10)

	bsr.w	WAITOPM			* 18
	move.b	#$DF,-2(a0)		* 16		* ?
	bsr.w	WAITOPM			* 18
	move.b	d1,(a0)			*  8

	bsr.w	WAITOPM			* 18
	move.b	#$9F,-2(a0)		* 16
	bsr.w	WAITOPM			* 18
	move.w	d1,-(sp)		*  8
	move.b	(sp)+,(a0)		* 12
SKENOI:
	addi.b	#$60,d0			*  8
	bsr.w	SETOPM			* 18
	addq.b	#8,d0			*  4
	bsr.w	SETOPM			* 18
	addq.b	#8,d0			*  4
	bsr.w	SETOPM			* 18

	move.w	d1,-(sp)		*  8
	move.b	(sp)+,d1		*  8
	subi.b	#$50,d0			*  8
	bsr.w	SETOPM			* 18
	addq.b	#8,d0			*  4
	bsr.w	SETOPM			* 18
	addq.b	#8,d0			*  4
	bsr.w	SETOPM			* 18

	subi.b	#$30,d0			*  8
	move.w	(sp)+,d1		*  8
	bra.w	SETTL			* 10

PSG11:
PSG12:
	move.b	$1B00+13(a1),d1		* 12
PSG13:
	tst.b	F_OFE-A_MEM(aME)	* 12
	bne.s	SKOFE			*  8(10)
	tst.l	F_ENV-A_MEM(aME)	* 16
	beq.s	SKKONF			*  8(10)
SKOFE:
	sf	F_OFE-A_MEM(aME)	* 16
	lea	PsOPMDAT,a0		* 12
	bsr.w	WAITOPM			* 18
	move.b	#$08,-2(a0)		* 16

	moveq	#7,d0			*  4
LPKOFF:	bsr.w	WAITOPM			* 18
	move.b	d0,(a0)			*  8
	subq.b	#1,d0			*  4
	cmpi.b	#4,d0			*  8
	bcc.s	LPKOFF

	swap	d1			*  4
	move.b	$1B00+07(a1),d1		* 12
	asl.b	#5,d1			* 16
	bsr.w	PSGKON			* 18
	swap	d1			*  4
SKKONF:
	clr.w	d0			*  4
	move.b	$1B00+12(a1),d0		* 12
	asr.w	#3,d0			* 12

	andi.w	#%00001111,d1		*  8
	move.b	T_ENV(pc,d1.w),d1	* 14
	beq.s	SETENV0			*  8(10)
	subq.b	#1,d1			*  4
	beq.s	SETENV1			*  8(10)
	subq.b	#1,d1			*  4
	beq.s	SETENV2			*  8(10)
	subq.b	#1,d1			*  4
	beq.s	SETENV3			*  8(10)
RTENV:	rts				* 16

SETENV0:
	move.b	#31,D_ENV+0-A_MEM(aME)			* 16
	move.b	#00,D_ENV+1-A_MEM(aME)			* 16
	rts						* 16
SETENV1:
	move.b	#31,D_ENV+0-A_MEM(aME)			* 16
	move.b	T_D2R(pc,d0.w),D_ENV+1-A_MEM(aME)	* 22
	rts						* 16
SETENV2:
	move.b	T_ATR(pc,d0.w),D_ENV+0-A_MEM(aME)	* 22
	move.b	#31,D_ENV+1-A_MEM(aME)			* 16
	rts						* 16
SETENV3:
	move.b	T_ATR(pc,d0.w),D_ENV+0-A_MEM(aME)	* 22
	move.b	#00,D_ENV+1-A_MEM(aME)			* 16
	rts						* 16

	*	0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
T_ENV:	dc.b	1,1,1,1,2,2,2,2,0,1,0,0,0,3,0,2

	*	00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15
T_ATR:	dc.b	31,10,08,07,06,05,05,04,04,03,03,03,03,02,02,02
	*	16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
	dc.b	02,02,02,02,02,02,02,02,02,02,02,02,02,02,02,02

	*	00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15
T_D2R:	dc.b	31,14,12,11,10,10,09,09,08,08,08,08,07,07,07,07
	*	16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
	dc.b	06,06,06,06,06,06,06,05,05,05,05,05,05,05,05,05

VSETN:
	lea	D_NOIV-A_MEM(aME),a1	*  8
	bra.s	JPVSET			* 10
VSETP:
	lea	D_PSGV-A_MEM(aME),a1	*  8
JPVSET:	move.w	d0,-(sp)		*  8

	bsr.w	SETOPM2			* 18
	addi.b	#$18,d1			*  8
	bsr.w	SETOPM2			* 18
	move.w	#4*6-1,d0		*  8
LPVSET:
	addq.b	#$08,d1			*  4
	bsr.w	SETOPM2			* 18
	dbf	d0,LPVSET		* 14(10)

	move.w	(sp)+,d0		*  8
	lea	A_IOB,a1		* 12
	rts				* 16
SETOPM2:
	bsr.s	WAITOPM			* 18
	move.b	d1,-2(a0)		* 12
	bsr.s	WAITOPM			* 18
	move.b	(a1)+,(a0)		* 12
	rts				* 16
SETOPM:
	bsr.s	WAITOPM			* 18
	move.b	d0,-2(a0)		* 12
	bsr.s	WAITOPM			* 18
	move.b	d1,(a0)			*  8
	rts				* 16
WAITOPM:
	tst.b	(a0)			*  8
	bmi.s	WAITOPM			*  8(10)
	rts				* 16


	.data

D_PSGV:	*	 RL FL  CON
	dc.b	%11_111_101,000	* PMS/AMS
	dc.b	002,001,001,001	* DT1/MUL
	dc.b	028,127,127,127	* TL
	dc.b	031,031,031,031	* KS/AR
	dc.b	000,000,000,000	* AMS EN/D1R
	dc.b	000,000,000,000	* DT2/D2R
	dc.b	015,015,015,015	* D1L/RR
	*	M1  M2  C1  C2

D_NOIV:	*	 RL FL  CON
	dc.b	%11_000_111,000	* PMS/AMS
	dc.b	001,001,001,001	* DT1/MUL
	dc.b	127,127,127,127	* TL
	dc.b	031,031,031,031	* KS/AR
	dc.b	000,000,000,000	* AMS EN/D1R
	dc.b	000,000,000,000	* DT2/D2R
	dc.b	015,015,015,015	* D1L/RR
	*	M1  M2  C1  C2

	.even
D_ENV:	dc.b	31,31
F_PSG:	dc.b	$FF,$FF,$FF,$FF
F_ENV:	dc.b	0,0,0,0
F_ONN:	dc.b	0,0,0,0
F_OFE:	dc.b	0
	.even

	.text


*---------------------------------------*
*   ＩＰＬ ＲＯＭ ON/OFF (1D**,1E**)	*
*---------------------------------------*

O1D00:						* IPL ROM ON
	move.l	#($6000*$10000)+.loww.(OUTIPL-(OUT+2)),OUT-A_BAS(aBS)	* 24	* bra.w OUTIPL
	tst.b	F_ROM-A_MEM(aME)	* 12
	bne.s	RTO1D			*  8(10)

	lea	(aME),a0		*  4
	lea	A_WOM,a1		* 12
	bsr.s	SBROM			* 18

	lea	(aME),a1		*  4
	moveq	#8-1,d1			*  4
LPO1D1:	lea	IPLROM-A_MEM(aME),a0	*  8
	move.w	#$1000/4-1,d0		*  8
LPO1D2:	move.l	(a0)+,(a1)+		* 20
	dbf	d0,LPO1D2		* 14(10)
	dbf	d1,LPO1D1		* 14(10)

	clr.w	d1			*  4
	lea	A_IOB,a1		* 12
RTO1D:	rts				* 16

O1E00:						* IPL ROM OFF
	tst.b	F_ROM-A_MEM(aME)	* 12
	beq.s	RTO1E			*  8(10)

	lea	A_WOM,a0		* 12
	lea	(aME),a1		*  4
	bsr.s	SBROM			* 18

	clr.w	d1			*  4
	lea	A_IOB,a1		* 12
RTO1E:	rts				* 16

SBROM:
	move.w	#$8000/4-1,d0		*  8
LPROM1:	move.l	(a0)+,(a1)+		* 20
	dbf	d0,LPROM1		* 14(10)

	lea	T_ROM-A_BAS(aBS),a0	*  8
	lea	T_OPC-A_BAS(aBS),a1	*  8
	move.w	(a0)+,d0		*  8
LPROM2:	add.w	d0,d0			*  4
	move.w	(a1,d0.w),d1		* 14
	move.w	(a0),(a1,d0.w)		* 18
	move.w	d1,(a0)+		*  8
	move.w	(a0)+,d0		*  8
	bpl.s	LPROM2			*  8(10)

	not.b	F_ROM-A_MEM(aME)	* 16
	rts				* 16


	.data
F_ROM:	dc.b	0
	.even
	.text


*---------------------------------------*
*      マウス（ＳＩＯ）(1F98-1F9B)	*
*      Ｚ８０  ＣＴＣ  (1FA8-1FAB)	*
*---------------------------------------*

I1F00:
	moveq	#$100-$98,d0		*  4
	add.b	BC,d0			*  4		* $1F98
	beq.s	ISIOAD			*  8(10)
	subq.b	#1,d0			*  4		* $1F99
	beq.s	ISIOAC			*  8(10)
	subq.b	#1,d0			*  4		* $1F9A
	beq.s	ISIOBD			*  8(10)
	subq.b	#1,d0			*  4		* $1F9B
	beq.s	ISIOBC			*  8(10)

	subi.b	#$0D,d0			*  8		* $1FA8
	beq.w	I_CTC0			* 12(10)
	subq.b	#1,d0			*  4		* $1FA9
	beq.w	I_CTC1			* 12(10)
	subq.b	#1,d0			*  4		* $1FAA
	beq.w	I_CTC2			* 12(10)
	subq.b	#1,d0			*  4		* $1FAB
	beq.w	I_CTC3			* 12(10)
	clr.b	d1			*  4
	rts				* 16

O1F00:
	moveq	#$100-$98,d0		*  4
	add.b	BC,d0			*  4		* $1F98
	beq.s	OSIOAD			*  8(10)
	subq.b	#1,d0			*  4		* $1F99
	beq.s	OSIOAC			*  8(10)
	subq.b	#1,d0			*  4		* $1F9A
	beq.s	OSIOBD			*  8(10)
	subq.b	#1,d0			*  4		* $1F9B
	beq.s	OSIOBC			*  8(10)

	subi.b	#$0D,d0			*  8		* $1FA8
	beq.w	O_CTC0			* 12(10)
	subq.b	#2,d0			*  4		* $1FAA
	beq.w	O_CTC2			* 12(10)
	subq.b	#1,d0			*  4		* $1FAB
	beq.w	O_CTC3			* 12(10)
	rts				* 16

ISIOAC:
ISIOAD:
	clr.b	d1			*  4
OSIOAC:
OSIOAD:
OSIOBD:
	rts				* 16


ISIOBC:
	tst.b	$1F9B(a1)		* 12
	bne.s	RTNRR0			*  8(10)

	moveq	#%00000001,d1		*  4
	and.b	PsSCCBCP,d1		* 16
*	addq.b	#%00000100,d1		*  4
	rts				* 16
RTNRR0:
	clr.b	d1			*  4
	move.b	d1,$1F9B(a1)		* 12
	rts				* 16

ISIOBD:
	move.b	PsSCCBDP,d1		* 16
	rts				* 16


OSIOBC:
	move.b	$1F9B(a1),d0		* 12
	beq.s	SIOCOM			*  8(10)
	clr.b	$1F9B(a1)		* 16

	subq.b	#5,d0			*  4
	bne.s	RTNWR5			*  8(10)

	andi.b	#%00000010,d1		*  8
	bne.s	MSCTRLL			*  8(10)

	tst.b	PsSCCBCP		* 12
	move.b	#5,PsSCCBCP		* 20
	move.b	#%01100000,PsSCCBCP	* 20
	move.b	#%01000001,PsMFPUDR	* 20
RTNWR5:	rts				* 16
MSCTRLL:
	tst.b	PsSCCBCP		* 12
	move.b	#5,PsSCCBCP		* 20
	move.b	#%01100010,PsSCCBCP	* 20
	move.b	#%01000000,PsMFPUDR	* 20
	rts				* 16
SIOCOM:	
	andi.b	#%00000111,d1		*  8
	move.b	d1,$1F9B(a1)		* 12
	rts				* 16


*---------------------------------------*
*  テキストアトリビュート (2000-27FF)	*
*---------------------------------------*

O2800L:
	lea	-$0800(a1),a0		*  8
	cmp.b	(a0,BC.w),d1		* 14
	bne.s	DFAT8L			*  8(10)
	rts				* 16
O2000L:
	cmp.b	(a1,BC.w),d1		* 14
	bne.s	DFAT0L			*  8(10)
	rts				* 16

DFAT8L:	lea	(a0),a1			*  4
DFAT0L:	adda.w	BC,a1			*  8
	move.b	d1,(a1)			*  8

	lea	+$1000(a1),a1		*  8
	move.b	(a1),d1			* 12
	bra.w	CHATRL			* 10

*---------------------------------------

O2800H:
	lea	-$0800(a1),a0		*  8
	cmp.b	(a0,BC.w),d1		* 14
	bne.s	DFAT8H			*  8(10)
	rts				* 16
O2000H:
	cmp.b	(a1,BC.w),d1		* 14
	bne.s	DFAT0H			*  8(10)
	rts				* 16

DFAT8H:	lea	(a0),a1			*  4
DFAT0H:	adda.w	BC,a1			*  8
	move.b	d1,(a1)			*  8

	lea	+$1000(a1),a1		*  8
	move.b	(a1),d1			* 12
	bra.w	CHATRH			* 10


*---------------------------------------*
*     テキストＶＲＡＭ (3000-37FF)	*
*---------------------------------------*

O3800L:
	lea	-$0800(a1),a1		*  8
O3000L:
	adda.w	BC,a1			*  8
	move.b	d1,(a1)			*  8
CHATRL:
	move.w	BC,d0			*  4
	andi.w	#$07FF,d0		*  8
	cmpi.w	#$0400,d0		*  8
	bcs.s	SCRNT0			*  8(10)
	add.w	#$0100,d0		*  8
SCRNT0:	divu	#40,d0			*<144
	ori.w	#$0300,d0		*  8
	swap	d0			*  4
	asl.w	#7,d0			* 20
	asr.l	#2,d0			* 12
	movea.l	d0,a0			*  4

	andi.w	#$00FF,d1		*  8
	asl.w	#7,d1			* 20

	move.b	-$1000(a1),d0		* 12
	cmpi.b	#7,d0			*  8
	bls.w	ATNOML			* 12(10)
	btst	#5,d0			* 10
	bne.s	ATPCGL			*  8(10)
ATCHKL:
	move.l	d2,-(sp)		* 12
	move.w	d1,-(sp)		*  8

	moveq	#%00000111,d1		*  4
	and.w	d0,d1			*  4
	add.w	d1,d1			*  4
	add.w	d1,d1			*  4
	move.l	PTATRL(pc,d1.w),d1	* 18

	moveq	#0,d2			*  4
	btst	#3,d0			* 10
	beq.s	SKBT3L			*  8(10)
	move.l	#$07070707,d2		* 12
SKBT3L:	btst	#4,d0			* 10
	beq.s	SKBT4L			*  8(10)
*	move.l	#$08080808,d2		* 12
	ori.l	#$08080808,d2		* 16
SKBT4L:
	andi.w	#%11100000,d0		*  8
	asr.w	#3,d0			* 12
	jmp	T_JMPL(pc,d0.w)		* 14

		* HVC
T_JMPL:	bra.w	AT000L			* 10
	bra.w	AT001L			* 10
	bra.w	AT010L			* 10
	bra.w	AT011L			* 10
	bra.w	AT100L			* 10
	bra.w	AT101L			* 10
	bra.w	AT110L			* 10
	bra.w	AT111L			* 10

*---------------------------------------

M_ATNL	macro	DISP				* 88

	move.l	(a1)+,d0		* 12
	and.l	d1,d0			*  8
	movep.l	d0,DISP+$00+1(a0)	* 24

	move.l	(a1)+,d0		* 12
	and.l	d1,d0			*  8
	movep.l	d0,DISP+$08+1(a0)	* 24

	endm

ATPCGL:
	cmpi.b	#%00100000+7,d0		*  8
	bhi.s	ATCHKL			*  8(10)
	andi.w	#%00000111,d0		*  8
	lea	CGRAMe,a1		* 12
	adda.w	d1,a1			*  8
	bra.s	JPNOML			* 10
PTATRL:
	dc.l	$00000000
	dc.l	$01010101
	dc.l	$02020202
	dc.l	$03030303
	dc.l	$04040404
	dc.l	$05050505
	dc.l	$06060606
	dc.l	$07070707
ATNOML:
	lea	CROM2e,a1		* 12
	adda.w	d1,a1			*  8

	ext.w	d0			*  4
JPNOML:	add.w	d0,d0			*  4
	add.w	d0,d0			*  4
	move.l	PTATRL(pc,d0.w),d1	* 18

	M_ATNL	$0000			* 88
	M_ATNL	$0010			* 88
	M_ATNL	$0800			* 88
	M_ATNL	$0810			* 88
	M_ATNL	$1000			* 88
	M_ATNL	$1010			* 88
	M_ATNL	$1800			* 88
	M_ATNL	$1810			* 88
	M_ATNL	$2000			* 88
	M_ATNL	$2010			* 88
	M_ATNL	$2800			* 88
	M_ATNL	$2810			* 88
	M_ATNL	$3000			* 88
	M_ATNL	$3010			* 88
	M_ATNL	$3800			* 88
	M_ATNL	$3810			* 88

	moveq	#0,d0			*  4
	moveq	#0,d1			*  4
	lea	A_IOB,a1		* 12
	rts				* 16

*---------------------------------------

M_ATCL	macro	DISP				* 104

	move.l	(a1)+,d0		* 12
	and.l	d1,d0			*  8
	eor.l	d2,d0			*  8
	movep.l	d0,DISP+$00+1(a0)	* 24

	move.l	(a1)+,d0		* 12
	and.l	d1,d0			*  8
	eor.l	d2,d0			*  8
	movep.l	d0,DISP+$08+1(a0)	* 24

	endm

AT001L:
	lea	CGRAMe,a1		* 12
	bra.s	JPATCL			* 10
AT000L:
	lea	CROM2e,a1		* 12
JPATCL:	adda.w	(sp)+,a1		* 12

	M_ATCL	$0000			* 104
	M_ATCL	$0010			* 104
	M_ATCL	$0800			* 104
	M_ATCL	$0810			* 104
	M_ATCL	$1000			* 104
	M_ATCL	$1010			* 104
	M_ATCL	$1800			* 104
	M_ATCL	$1810			* 104
	M_ATCL	$2000			* 104
	M_ATCL	$2010			* 104
	M_ATCL	$2800			* 104
	M_ATCL	$2810			* 104
	M_ATCL	$3000			* 104
	M_ATCL	$3010			* 104
	M_ATCL	$3800			* 104
	M_ATCL	$3810			* 104

	moveq	#0,d0			*  4
	moveq	#0,d1			*  4
	move.l	(sp)+,d2		* 12
	lea	A_IOB,a1		* 12
	rts				* 16

*---------------------------------------

M_ATVL	macro	DISP				* 152

	move.l	(a1)+,d0		* 12
	and.l	d1,d0			*  8
	eor.l	d2,d0			*  8
	movep.l	d0,DISP+$0000+1(a0)	* 24
	movep.l	d0,DISP+$0800+1(a0)	* 24

	move.l	(a1)+,d0		* 12
	and.l	d1,d0			*  8
	eor.l	d2,d0			*  8
	movep.l	d0,DISP+$0008+1(a0)	* 24
	movep.l	d0,DISP+$0808+1(a0)	* 24

	endm


M_CATV	macro	CGAD,DISP,LINE,JPAD
	local	SKIP

	btst	#6,-$1000-LINE(a1)	* 16
	beq.s	SKIP			*  8(10)
	move.b	(a1),d0			*  8
	cmp.b	-LINE(a1),d0		* 12
	bne.s	SKIP			*  8(10)
	lea	CGAD+DISP,a1		* 12
	bra.s	JPAD			* 10
SKIP:	lea	CGAD,a1			* 12

	endm

AT011L:
	M_CATV	CGRAMe,$40,40,JPATVL
	bra.s	JPATVL			* 10
AT010L:
	M_CATV	CROM2e,$40,40,JPATVL
JPATVL:	adda.w	(sp)+,a1		* 12

	M_ATVL	$0000			* 152
	M_ATVL	$0010			* 152
	M_ATVL	$1000			* 152
	M_ATVL	$1010			* 152
	M_ATVL	$2000			* 152
	M_ATVL	$2010			* 152
	M_ATVL	$3000			* 152
	M_ATVL	$3010			* 152

	moveq	#0,d0			*  4
	moveq	#0,d1			*  4
	move.l	(sp)+,d2		* 12
	lea	A_IOB,a1		* 12
	rts				* 16

*---------------------------------------

M_ATHs	macro	DISP				* 48

	move.w	(a1)+,d0		*  8
	and.w	d1,d0			*  4
	eor.w	d2,d0			*  4
	movep.w	d0,DISP+$00+1(a0)	* 16
	movep.w	d0,DISP+$04+1(a0)	* 16

	endm


M_ATHL	macro	DISP				* 196

	M_ATHs	DISP+$00		* 48
	M_ATHs	DISP+$08		* 48
	M_ATHs	DISP+$10		* 48
	M_ATHs	DISP+$18		* 48
	addq.w	#8,a1			*  4

	endm

AT101L:
	lea	CGRAMe,a1		* 12
	bra.s	JPATHL			* 10
AT100L:
	lea	CROM2e,a1		* 12
JPATHL:	btst	#0,BC			* 10
	beq.s	SKATHL			*  8(10)
	addq.w	#8,a1			*  4
SKATHL:	adda.w	(sp)+,a1		* 12

	M_ATHL	$0000			* 196
	M_ATHL	$0800			* 196
	M_ATHL	$1000			* 196
	M_ATHL	$1800			* 196
	M_ATHL	$2000			* 196
	M_ATHL	$2800			* 196
	M_ATHL	$3000			* 196
	M_ATHL	$3800			* 196

	moveq	#0,d0			*  4
	moveq	#0,d1			*  4
	move.l	(sp)+,d2		* 12
	lea	A_IOB,a1		* 12
	rts				* 16

*---------------------------------------

M_ATSs	macro	DISP				* 80

	move.w	(a1)+,d0		*  8
	and.w	d1,d0			*  4
	eor.w	d2,d0			*  4
	movep.w	d0,DISP+$0000+1(a0)	* 16
	movep.w	d0,DISP+$0004+1(a0)	* 16
	movep.w	d0,DISP+$0800+1(a0)	* 16
	movep.w	d0,DISP+$0804+1(a0)	* 16

	endm


M_ATSL	macro	DISP				* 324

	M_ATSs	DISP+$00		* 80
	M_ATSs	DISP+$08		* 80
	M_ATSs	DISP+$10		* 80
	M_ATSs	DISP+$18		* 80
	addq.w	#8,a1			*  4

	endm

AT111L:
	M_CATV	CGRAMe,$40,40,JPATSL
	bra.s	JPATSL			* 10
AT110L:
	M_CATV	CROM2e,$40,40,JPATSL
JPATSL:	btst	#0,BC			* 10
	beq.s	SKATSL			*  8(10)
	addq.w	#8,a1			*  4
SKATSL:	adda.w	(sp)+,a1		* 12

	M_ATSL	$0000			* 324
	M_ATSL	$1000			* 324
	M_ATSL	$2000			* 324
	M_ATSL	$3000			* 324

	moveq	#0,d0			*  4
	moveq	#0,d1			*  4
	move.l	(sp)+,d2		* 12
	lea	A_IOB,a1		* 12
	rts				* 16

*---------------------------------------
*---------------------------------------

O3800H:
	lea	-$0800(a1),a1		*  8
O3000H:
	adda.w	BC,a1			*  8
	move.b	d1,(a1)			*  8
CHATRH:
	move.w	BC,d0			*  4
	andi.w	#$07FF,d0		*  8
	divu	#80,d0			*<144
	ori.w	#$0300,d0		*  8
	swap	d0			*  4
	asl.w	#6,d0			* 18
	asr.l	#2,d0			* 12
	movea.l	d0,a0			*  4

	andi.w	#$00FF,d1		*  8
	asl.w	#6,d1			* 18

	move.b	-$1000(a1),d0		* 12
	cmpi.b	#7,d0			*  8
	bls.w	ATNOMH			* 12(10)
	btst	#5,d0			* 10
	bne.s	ATPCGH			*  8(10)
ATCHKH:
	move.l	d2,-(sp)		* 12
	move.w	d1,-(sp)		*  8

	moveq	#%00000111,d1		*  4
	and.w	d0,d1			*  4
	add.w	d1,d1			*  4
	add.w	d1,d1			*  4
	move.l	PTATRH(pc,d1.w),d1	* 18

	moveq	#0,d2			*  4
	btst	#3,d0			* 10
	beq.s	SKBT3H			*  8(10)
	move.l	#$07070707,d2		* 12
SKBT3H:	btst	#4,d0			* 10
	beq.s	SKBT4H			*  8(10)
*	move.l	#$08080808,d2		* 12
	ori.l	#$08080808,d2		* 16
SKBT4H:
	andi.w	#%11100000,d0		*  8
	asr.w	#3,d0			* 12
	jmp	T_JMPH(pc,d0.w)		* 14

		* HVC
T_JMPH:	bra.w	AT000H			* 10
	bra.w	AT001H			* 10
	bra.w	AT010H			* 10
	bra.w	AT011H			* 10
	bra.w	AT100H			* 10
	bra.w	AT101H			* 10
	bra.w	AT110H			* 10
	bra.w	AT111H			* 10

*---------------------------------------

M_ATNH	macro	DISP				* 44

	move.l	(a1)+,d0		* 12
	and.l	d1,d0			*  8
	movep.l	d0,DISP+1(a0)		* 24

	endm

ATPCGH:
	cmpi.b	#%00100000+7,d0		*  8
	bhi.s	ATCHKH			*  8(10)
	andi.w	#%00000111,d0		*  8
	lea	CGRAM,a1		* 12
	adda.w	d1,a1			*  8
	bra.s	JPNOMH			* 10
PTATRH:
	dc.l	$00000000
	dc.l	$01010101
	dc.l	$02020202
	dc.l	$03030303
	dc.l	$04040404
	dc.l	$05050505
	dc.l	$06060606
	dc.l	$07070707
ATNOMH:
	lea	CROM2,a1		* 12
	adda.w	d1,a1			*  8

	ext.w	d0			*  4
JPNOMH:	add.w	d0,d0			*  4
	add.w	d0,d0			*  4
	move.l	PTATRH(pc,d0.w),d1	* 18

	M_ATNH	$0000			* 44
	M_ATNH	$0008			* 44
	M_ATNH	$0800			* 44
	M_ATNH	$0808			* 44
	M_ATNH	$1000			* 44
	M_ATNH	$1008			* 44
	M_ATNH	$1800			* 44
	M_ATNH	$1808			* 44
	M_ATNH	$2000			* 44
	M_ATNH	$2008			* 44
	M_ATNH	$2800			* 44
	M_ATNH	$2808			* 44
	M_ATNH	$3000			* 44
	M_ATNH	$3008			* 44
	M_ATNH	$3800			* 44
	M_ATNH	$3808			* 44

	moveq	#0,d0			*  4
	moveq	#0,d1			*  4
	lea	A_IOB,a1		* 12
	rts				* 16

*---------------------------------------

M_ATCH	macro	DISP				* 52

	move.l	(a1)+,d0		* 12
	and.l	d1,d0			*  8
	eor.l	d2,d0			*  8
	movep.l	d0,DISP+1(a0)		* 24

	endm

AT001H:
	lea	CGRAM,a1		* 12
	bra.s	JPATCH			* 10
AT000H:
	lea	CROM2,a1		* 12
JPATCH:	adda.w	(sp)+,a1		* 12

	M_ATCH	$0000			* 52
	M_ATCH	$0008			* 52
	M_ATCH	$0800			* 52
	M_ATCH	$0808			* 52
	M_ATCH	$1000			* 52
	M_ATCH	$1008			* 52
	M_ATCH	$1800			* 52
	M_ATCH	$1808			* 52
	M_ATCH	$2000			* 52
	M_ATCH	$2008			* 52
	M_ATCH	$2800			* 52
	M_ATCH	$2808			* 52
	M_ATCH	$3000			* 52
	M_ATCH	$3008			* 52
	M_ATCH	$3800			* 52
	M_ATCH	$3808			* 52

	moveq	#0,d0			*  4
	moveq	#0,d1			*  4
	move.l	(sp)+,d2		* 12
	lea	A_IOB,a1		* 12
	rts				* 16

*---------------------------------------

M_ATVH	macro	DISP				* 76

	move.l	(a1)+,d0		* 12
	and.l	d1,d0			*  8
	eor.l	d2,d0			*  8
	movep.l	d0,DISP+$0000+1(a0)	* 24
	movep.l	d0,DISP+$0800+1(a0)	* 24

	endm

AT011H:
	M_CATV	CGRAM,$20,80,JPATVH
	bra.s	JPATVH			* 10
AT010H:
	M_CATV	CROM2,$20,80,JPATVH
JPATVH:	adda.w	(sp)+,a1		* 12

	M_ATVH	$0000			* 76
	M_ATVH	$0008			* 76
	M_ATVH	$1000			* 76
	M_ATVH	$1008			* 76
	M_ATVH	$2000			* 76
	M_ATVH	$2008			* 76
	M_ATVH	$3000			* 76
	M_ATVH	$3008			* 76

	moveq	#0,d0			*  4
	moveq	#0,d1			*  4
	move.l	(sp)+,d2		* 12
	lea	A_IOB,a1		* 12
	rts				* 16

*---------------------------------------

M_ATHH	macro	DISP				* 108

	M_ATCH	DISP+$00		* 52
	M_ATCH	DISP+$08		* 52
	addq.w	#8,a1			*  4

	endm

AT101H:
	lea	CGRAMe,a1		* 12
	bra.s	JPATHH			* 10
AT100H:
	lea	CROM2e,a1		* 12
JPATHH:	btst	#0,BC			* 10
	beq.s	SKATHH			*  8(10)
	addq.w	#8,a1			*  4
SKATHH:	adda.w	(sp),a1			* 12
	adda.w	(sp)+,a1		* 12

	M_ATHH	$0000			* 108
	M_ATHH	$0800			* 108
	M_ATHH	$1000			* 108
	M_ATHH	$1800			* 108
	M_ATHH	$2000			* 108
	M_ATHH	$2800			* 108
	M_ATHH	$3000			* 108
	M_ATHH	$3800			* 108

	moveq	#0,d0			*  4
	moveq	#0,d1			*  4
	move.l	(sp)+,d2		* 12
	lea	A_IOB,a1		* 12
	rts				* 16

*---------------------------------------

M_ATSH	macro	DISP				* 156

	M_ATVH	DISP+$00		* 76
	M_ATVH	DISP+$08		* 76
	addq.w	#8,a1			*  4

	endm

AT111H:
	M_CATV	CGRAMe,$40,80,JPATSH
	bra.s	JPATSH			* 10
AT110H:
	M_CATV	CROM2e,$40,80,JPATSH
JPATSH:	btst	#0,BC			* 10
	beq.s	SKATSH			*  8(10)
	addq.w	#8,a1			*  4
SKATSH:	adda.w	(sp),a1			* 12
	adda.w	(sp)+,a1		* 12

	M_ATSH	$0000			* 156
	M_ATSH	$1000			* 156
	M_ATSH	$2000			* 156
	M_ATSH	$3000			* 156

	moveq	#0,d0			*  4
	moveq	#0,d1			*  4
	move.l	(sp)+,d2		* 12
	lea	A_IOB,a1		* 12
	rts				* 16


*---------------------------------------*
*    グラフィックＲＡＭ (4000-FFFF)	*
*---------------------------------------*

M_GRL	macro	ADR
	local	SCRNG0

	andi.w	#$00FF,d1		*  8
	add.w	d1,d1			*  4
	lea	T_GPT-A_MEM(aME),a0	*  8
	move.w	(a0,d1.w),d0		* 14

	move.w	BC,d1			*  4
	andi.w	#$03FF,d1		*  8
	divu	#40,d1			*<140 

	move.b	d1,-(sp)		*  8
	move.w	(sp)+,d1		*  8
	move.w	BC,-(sp)		*  8
	move.b	(sp)+,d1		*  8

	andi.b	#$38,d1			*  8
	add.b	d1,d1			*  4
	add.b	d1,d1			*  4
	add.w	d1,d1			*  4
	add.w	d1,d1			*  4
	movea.w	d1,a0			*  4

	move.w	#ADR,d1			*  8
	swap	d1			*  4
	add.w	d1,d1			*  4

	btst	#10,BC			* 10
	beq.s	SCRNG0			*  8(10)
	addi.w	#$8000,d1		*  8
SCRNG0:	move.w	d0,(a0,d1.l)		* 14
	moveq	#0,d1			*  4
	rts				* 16

	endm

O4000L:
	move.b	d1,(a1,BC.w)		* 14
	M_GRL	$00E0
O8000L:
	move.b	d1,(a1,BC.w)		* 14
	M_GRL	$00E2
OC000L:
	move.b	d1,(a1,BC.w)		* 14
	M_GRL	$00E4
DAMD0L:
	lea	(a1,BC.w),a0		* 12
	move.b	d1,$4000(a0)		* 12
	move.b	d1,$8000(a0)		* 12
	move.b	d1,$C000(a0)		* 12
	move.w	#%01_0111_0000,PwCRTC21	* 20
	M_GRL	$00E0
DAMD4L:
	lea	(a1,BC.w),a0		* 12
	move.b	d1,$8000(a0)		* 12
	move.b	d1,$C000(a0)		* 12
	move.w	#%01_0110_0000,PwCRTC21	* 20
	M_GRL	$00E0
DAMD8L:
	lea	(a1,BC.w),a0		* 12
	move.b	d1,$4000(a0)		* 12
	move.b	d1,$C000(a0)		* 12
	move.w	#%01_0101_0000,PwCRTC21	* 20
	M_GRL	$00E0
DAMDCL:
	lea	(a1,BC.w),a0		* 12
	move.b	d1,$4000(a0)		* 12
	move.b	d1,$8000(a0)		* 12
	move.w	#%01_0011_0000,PwCRTC21	* 20
	M_GRL	$00E0

*---------------------------------------

M_GRH	macro	ADR

	move.w	BC,d0			*  4
	andi.w	#$07FF,d0		*  8
	divu	#80,d0			*<140 

	move.b	d0,-(sp)		*  8
	move.w	(sp)+,d0		*  8
	move.w	BC,-(sp)		*  8
	move.b	(sp)+,d0		*  8

	andi.b	#$38,d0			*  8
	add.b	d0,d0			*  4
	add.b	d0,d0			*  4
	add.w	d0,d0			*  4
	add.w	d0,d0			*  4
	movea.w	d0,a0			*  4

	move.w	#ADR,d0			*  8
	swap	d0			*  4
	move.b	d1,(a0,d0.l)		* 14
	moveq	#0,d0			*  4
	rts				* 16

	endm

O4000H:
	move.b	d1,(a1,BC.w)		* 14
	M_GRH	$00E0
O8000H:
	move.b	d1,(a1,BC.w)		* 14
	M_GRH	$00E2
OC000H:
	move.b	d1,(a1,BC.w)		* 14
	M_GRH	$00E4
DAMD0H:
	lea	(a1,BC.w),a0		* 12
	move.b	d1,$4000(a0)		* 12
	move.b	d1,$8000(a0)		* 12
	move.b	d1,$C000(a0)		* 12
	move.w	#%01_0111_0000,PwCRTC21	* 20
	M_GRH	$00E0
DAMD4H:
	lea	(a1,BC.w),a0		* 12
	move.b	d1,$8000(a0)		* 12
	move.b	d1,$C000(a0)		* 12
	move.w	#%01_0110_0000,PwCRTC21	* 20
	M_GRH	$00E0
DAMD8H:
	lea	(a1,BC.w),a0		* 12
	move.b	d1,$4000(a0)		* 12
	move.b	d1,$C000(a0)		* 12
	move.w	#%01_0101_0000,PwCRTC21	* 20
	M_GRH	$00E0
DAMDCH:
	lea	(a1,BC.w),a0		* 12
	move.b	d1,$4000(a0)		* 12
	move.b	d1,$8000(a0)		* 12
	move.w	#%01_0011_0000,PwCRTC21	* 20
	M_GRH	$00E0


*---------------------------------------*
*	      ＲＥＴＵＲＮ		*
*---------------------------------------*

RETI:
	move.b	(a1,BC.w),d1		* 14
	rts				* 16
RETIN:
	clr.b	d1			*  4
	rts				* 16
RETIT:
	move.w	BC,d0			*  4
	andi.w	#$F7FF,d0		*  8
	move.b	(a1,d0.w),d1		* 14
	rts				* 16
RETO:
*	move.b	d1,(a1,BC.w)		* 14
	rts				* 16

RETIA	equ	.loww.(RETI-A_BAS).w
RETINA	equ	.loww.(RETIN-A_BAS).w
RETITA	equ	.loww.(RETIT-A_BAS).w
RETOA	equ	.loww.(RETO-A_BAS).w

*---------------------------------------*
*	 ＩＮＰ　＆　ｔａｂｌｅ		*
*---------------------------------------*

INP:	ds.b	$20

T_INP:	dcb.w	1-$00+$06,RETINA
	dc.w	I0700-A_BAS	* 0700		ＦＭ音源／ＣＴＣ
	dcb.w	1-$08+$09,RETINA
	dc.w	I0A00-A_BAS	* 0A00		（立体ボード）／ＣＴＣ
	dcb.w	1-$0B+$0C,RETINA
	dc.w	I0D00-A_BAS	* 0D00		ＥＭＭ
	dc.w	I0E00-A_BAS	* 0E00		ＢＡＳＩＣ　ＲＯＭ／漢字ＲＯＭ
	dc.w	I0F00-A_BAS	* 0F00		５インチＦＤ
	dc.w	RETIN-A_BAS	* 1000		（パレット　Ｂ）
	dc.w	RETIN-A_BAS	* 1100		（パレット　Ｒ）
	dc.w	RETIN-A_BAS	* 1200		（パレット　Ｇ）
	dc.w	RETIN-A_BAS	* 1300		（プライオリティ）
	dc.w	I1400-A_BAS	* 1400		ＣＧ　ＲＯＭ
	dc.w	I1500-A_BAS	* 1500		ＰＣＧ　Ｂ
	dc.w	I1600-A_BAS	* 1600		ＰＣＧ　Ｒ
	dc.w	I1700-A_BAS	* 1700		ＰＣＧ　Ｇ
	dc.w	RETIN-A_BAS	* 1800		（ＣＲＴＣ）
	dc.w	I1900-A_BAS	* 1900		８２５５＃１
	dc.w	I1A00-A_BAS	* 1A00		８２５５＃２
	dc.w	I1B00-A_BAS	* 1B00		ＰＳＧデータ
	dc.w	RETIN-A_BAS	* 1C00		（ＰＳＧレジスタＮｏ．）
	dc.w	RETIN-A_BAS	* 1D00		（ＩＰＬ　ＲＯＭ　ＯＮ）
	dc.w	RETIN-A_BAS	* 1E00		（ＩＰＬ　ＲＯＭ　ＯＦＦ）
	dc.w	I1F00-A_BAS	* 1F00		マウス／ＣＴＣ

	dcb.w	1-$20+$27,RETIA	* 2000-27FF	テキストアトリビュート
	dcb.w	1-$28+$2F,RETITA
	dcb.w	1-$30+$37,RETIA	* 3000-37FF	テキストＶＲＡＭ
	dcb.w	1-$38+$3F,RETITA

	dcb.w	1-$40+$7F,RETIA	* 4000-7FFF	ＧＲＡＭ　Ｂ
	dcb.w	1-$80+$BF,RETIA	* 8000-BFFF	ＧＲＡＭ　Ｒ
	dcb.w	1-$C0+$FF,RETIA	* C000-FFFF	ＧＲＡＭ　Ｇ

*---------------------------------------*
*	 ＯＵＴ　＆　ｔａｂｌｅ		*
*---------------------------------------*

OUT:	ds.b	$20

T_OUT:	dcb.w	1-$00+$06,RETOA
	dc.w	O0700-A_BAS	* 0700		ＦＭ音源／ＣＴＣ
	dcb.w	1-$08+$09,RETOA
	dc.w	O0A00-A_BAS	* 0A00		立体ボード／ＣＴＣ
	dcb.w	1-$0B+$0C,RETOA
	dc.w	O0D00-A_BAS	* 0D00		ＥＭＭ
	dc.w	O0E00-A_BAS	* 0E00		ＢＡＳＩＣ　ＲＯＭ／漢字ＲＯＭ
	dc.w	O0F00-A_BAS	* 0F00		５インチＦＤ
	dc.w	O1000-A_BAS	* 1000		パレット　Ｂ
	dc.w	O1100-A_BAS	* 1100		パレット　Ｒ
	dc.w	O1200-A_BAS	* 1200		パレット　Ｇ
	dc.w	O1300-A_BAS	* 1300		プライオリティ
	dc.w	RETO-A_BAS	* 1400		（ＣＧ　ＲＯＭ）
	dc.w	O1500-A_BAS	* 1500		ＰＣＧ　Ｂ
	dc.w	O1600-A_BAS	* 1600		ＰＣＧ　Ｒ
	dc.w	O1700-A_BAS	* 1700		ＰＣＧ　Ｇ
	dc.w	O1800-A_BAS	* 1800		ＣＲＴＣ
	dc.w	O1900-A_BAS	* 1900		８２５５＃１
	dc.w	O1A00-A_BAS	* 1A00		８２５５＃２
	dc.w	O1B00-A_BAS	* 1B00		ＰＳＧデータ
	dc.w	O1C00-A_BAS	* 1C00		ＰＳＧレジスタＮｏ．
	dc.w	O1D00-A_BAS	* 1D00		ＩＰＬ　ＲＯＭ　ＯＮ
	dc.w	O1E00-A_BAS	* 1E00		ＩＰＬ　ＲＯＭ　ＯＦＦ
	dc.w	O1F00-A_BAS	* 1F00		マウス／ＣＴＣ

	dcb.w	1-$20+$27,.loww.(O2000L-A_BAS)	* 2000-27FF	テキストアトリビュート
	dcb.w	1-$28+$2F,.loww.(O2800L-A_BAS)
	dcb.w	1-$30+$37,.loww.(O3000L-A_BAS)	* 3000-37FF	テキストＶＲＡＭ
	dcb.w	1-$38+$3F,.loww.(O3800L-A_BAS)

	dcb.w	1-$40+$7F,.loww.(O4000L-A_BAS)	* 4000-7FFF	ＧＲＡＭ　Ｂ
	dcb.w	1-$80+$BF,.loww.(O8000L-A_BAS)	* 8000-BFFF	ＧＲＡＭ　Ｒ
	dcb.w	1-$C0+$FF,.loww.(OC000L-A_BAS)	* C000-FFFF	ＧＲＡＭ　Ｇ

*---------------------------------------*
*  X1 key data / 320*200 dot pat. etc.	*
*---------------------------------------*

	.data

T_XKEY:
*		    ESC  1   2   3   4   5   6   7   8   9   0   -   ^   \   BS
	dc.b	$00,$1B,'1','2','3','4','5','6','7','8','9','0','-','^','\',$08
*
*		TAB  q   w   e   r   t   y   u   i   o   p   @   [   CR  a   s
	dc.b	$09,'q','w','e','r','t','y','u','i','o','p','@','[',$0D,'a','s'
*
*		 d   f   g   h   j   k   l   ;   :   ]   z   x   c   v   b   n
	dc.b	'd','f','g','h','j','k','l',';',':',']','z','x','c','v','b','n'
*
*		 m   ,   .   /  (_) SP HOME DEL RLu RLd UNDO Cl  Cu  Cr  Cd CLR
	dc.b	'm',',','.','/',$00,' ',$0B,$00,$00,$00,$00,$1D,$1E,$1C,$1F,$00
*
*		 /   *   -   7   8   9   +   4   5   6   =   1   2   3 ENTER 0
	dc.b	'/','*','-','7','8','9','+','4','5','6','=','1','2','3',$0D,'0'
*
*		 ,   .  記号登録HELPXF1 XF2 XF3 XF4 XF5  ｶﾅ ﾛｰﾏ ｺｰﾄﾞCAPSINSﾋﾗｶﾞﾅ
	dc.b	',','.','ﾄ','ﾁ','ﾃ',$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
*
*		全角BREKCOPY F1  F2  F3  F4  F5  F6  F7  F8  F9 F10
	dc.b	$00,$13,$00,'q','r','s','t','u',$EC,$EB,$E2,$E1,$E8,$00,$00,$00
*
*		SIFTCTRLOP1 OP2
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


* SHIFT +
*		    ESC  1   2   3   4   5   6   7   8   9   0   -   ^   \   BS
	dc.b	$00,$1B,'!','"','#','$','%','&',$27,'(',')',$00,'=','~','|',$12
*
*		TAB  q   w   e   r   t   y   u   i   o   p   @   [   CR  a   s
	dc.b	$09,'Q','W','E','R','T','Y','U','I','O','P','`','{',$0D,'A','S'
*
*		 d   f   g   h   j   k   l   ;   :   ]   z   x   c   v   b   n
	dc.b	'D','F','G','H','J','K','L','+','*','}','Z','X','C','V','B','N'
*
*		 m   ,   .   /  (_) SP HOME DEL RLu RLd UNDO Cl  Cu  Cr  Cd CLR
	dc.b	'M','<','>','?','_',' ',$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00
*
*		 /   *   -   7   8   9   +   4   5   6   =   1   2   3 ENTER 0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0D,$00
*
*		 ,   .  記号登録HELPXF1 XF2 XF3 XF4 XF5  ｶﾅ ﾛｰﾏ ｺｰﾄﾞCAPSINSﾋﾗｶﾞﾅ
	dc.b	$00,$00,'ﾆ','ﾀ','ﾅ',$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
*
*		全角BREKCOPY F1  F2  F3  F4  F5  F6  F7  F8  F9 F10
	dc.b	$00,$03,$00,'v','w','x','y','z',$00,$00,$00,$00,$00,$00,$00,$00
*
*		SIFTCTRLOP1 OP2
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


* ｶﾅ +
*		    ESC  1   2   3   4   5   6   7   8   9   0   -   ^   \   BS
	dc.b	$00,$1B,'ﾇ','ﾌ','ｱ','ｳ','ｴ','ｵ','ﾔ','ﾕ','ﾖ','ﾜ','ﾎ','ﾍ','ｰ',$08
*
*		TAB  q   w   e   r   t   y   u   i   o   p   @   [   CR  a   s
	dc.b	$09,'ﾀ','ﾃ','ｲ','ｽ','ｶ','ﾝ','ﾅ','ﾆ','ﾗ','ｾ','ﾞ','ﾟ',$0D,'ﾁ','ﾄ'
*
*		 d   f   g   h   j   k   l   ;   :   ]   z   x   c   v   b   n
	dc.b	'ｼ','ﾊ','ｷ','ｸ','ﾏ','ﾉ','ﾘ','ﾚ','ｹ','ﾑ','ﾂ','ｻ','ｿ','ﾋ','ｺ','ﾐ'
*
*		 m   ,   .   /  (_) SP HOME DEL RLu RLd UNDO Cl  Cu  Cr  Cd CLR
	dc.b	'ﾓ','ﾈ','ﾙ','ﾒ','ﾛ',' ',$0B,$00,$00,$00,$00,$1D,$1E,$1C,$1F,$00
*
*		 /   *   -   7   8   9   +   4   5   6   =   1   2   3 ENTER 0
	dc.b	'/','*','-','7','8','9','+','4','5','6','=','1','2','3',$0D,'0'
*
*		 ,   .  記号登録HELPXF1 XF2 XF3 XF4 XF5  ｶﾅ ﾛｰﾏ ｺｰﾄﾞCAPSINSﾋﾗｶﾞﾅ
	dc.b	',','.','ﾄ','ﾁ','ﾃ',$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
*
*		全角BREKCOPY F1  F2  F3  F4  F5  F6  F7  F8  F9 F10
	dc.b	$00,$13,$00,'q','r','s','t','u',$EC,$EB,$E2,$E1,$E8,$00,$00,$00
*
*		SIFTCTRLOP1 OP2
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


* ｶﾅ + SHIFT +
*		    ESC  1   2   3   4   5   6   7   8   9   0   -   ^   \   BS
	dc.b	$00,$1B,'ﾇ','ﾌ','ｧ','ｩ','ｪ','ｫ','ｬ','ｭ','ｮ','ｦ','ﾎ','ﾍ','ｰ',$12
*
*		TAB  q   w   e   r   t   y   u   i   o   p   @   [   CR  a   s
	dc.b	$09,'ﾀ','ﾃ','ｨ','ｽ','ｶ','ﾝ','ﾅ','ﾆ','ﾗ','ｾ','ﾞ','｢',$0D,'ﾁ','ﾄ'
*
*		 d   f   g   h   j   k   l   ;   :   ]   z   x   c   v   b   n
	dc.b	'ｼ','ﾊ','ｷ','ｸ','ﾏ','ﾉ','ﾘ','ﾚ','ｹ','｣','ｯ','ｻ','ｿ','ﾋ','ｺ','ﾐ'
*
*		 m   ,   .   /  (_) SP HOME DEL RLu RLd UNDO Cl  Cu  Cr  Cd CLR
	dc.b	'ﾓ','､','｡','･',$00,' ',$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00
*
*		 /   *   -   7   8   9   +   4   5   6   =   1   2   3 ENTER 0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0D,$00
*
*		 ,   .  記号登録HELPXF1 XF2 XF3 XF4 XF5  ｶﾅ ﾛｰﾏ ｺｰﾄﾞCAPSINSﾋﾗｶﾞﾅ
	dc.b	$00,$00,'ﾆ','ﾀ','ﾅ',$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
*
*		全角BREKCOPY F1  F2  F3  F4  F5  F6  F7  F8  F9 F10
	dc.b	$00,$03,$00,'v','w','x','y','z',$00,$00,$00,$00,$00,$00,$00,$00
*
*		SIFTCTRLOP1 OP2
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


* CTRL +
*		    ESC  1   2   3   4   5   6   7   8   9   0   -   ^   \   BS
	dc.b	$00,$1B,'1','2','3','4','5','6','7','8','9','0',$00,$1E,$1C,$08
*
*		TAB  q   w   e   r   t   y   u   i   o   p   @   [   CR  a   s
	dc.b	$09,$11,$17,$05,$12,$14,$19,$15,$09,$0F,$10,'@',$1B,$0D,$01,$13
*
*		 d   f   g   h   j   k   l   ;   :   ]   z   x   c   v   b   n
	dc.b	$04,$06,$07,$08,$0A,$0B,$0C,';',':',$1D,$1A,$18,$03,$16,$02,$0E
*
*		 m   ,   .   /  (_) SP HOME DEL RLu RLd UNDO Cl  Cu  Cr  Cd CLR
	dc.b	$0D,$00,$00,$00,$1F,' ',$0B,$00,$00,$00,$00,$1D,$1E,$1C,$1F,$00
*
*		 /   *   -   7   8   9   +   4   5   6   =   1   2   3 ENTER 0
	dc.b	'/','*','-','7','8','9','+','4','5','6','=','1','2','3',$0D,'0'
*
*		 ,   .  記号登録HELPXF1 XF2 XF3 XF4 XF5  ｶﾅ ﾛｰﾏ ｺｰﾄﾞCAPSINSﾋﾗｶﾞﾅ
	dc.b	',','.','ﾄ','ﾁ','ﾃ',$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
*
*		全角BREKCOPY F1  F2  F3  F4  F5  F6  F7  F8  F9 F10
	dc.b	$00,$13,$00,$00,$00,$00,$00,$00,$EC,$EB,$E2,$E1,$E8,$00,$00,$00
*
*		SIFTCTRLOP1 OP2
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


* GRAPH +
*		    ESC  1   2   3   4   5   6   7   8   9   0   -   ^   \   BS
	dc.b	$00,$00,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$8C,$8B,$FB,$00
*
*		TAB  q   w   e   r   t   y   u   i   o   p   @   [   CR  a   s
	dc.b	$00,$E0,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$F0,$8D,$8A,$FC,$00,$7F,$E9
*
*		 d   f   g   h   j   k   l   ;   :   ]   z   x   c   v   b   n
	dc.b	$EA,$EB,$EC,$ED,$EE,$EF,$8E,$89,$FD,$E8,$80,$81,$82,$83,$84,$85
*
*		 m   ,   .   /  (_) SP HOME DEL RLu RLd UNDO Cl  Cu  Cr  Cd CLR
	dc.b	$86,$87,$88,$FE,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
*
*		 /   *   -   7   8   9   +   4   5   6   =   1   2   3 ENTER 0
	dc.b	$9E,$9B,$9C,$9A,$93,$97,$9D,$95,$96,$94,$90,$99,$92,$98,$00,$8F
*
*		 ,   .  記号登録HELPXF1 XF2 XF3 XF4 XF5  ｶﾅ ﾛｰﾏ ｺｰﾄﾞCAPSINSﾋﾗｶﾞﾅ
	dc.b	$9F,$91,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
*
*		全角BREKCOPY F1  F2  F3  F4  F5  F6  F7  F8  F9 F10
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
*
*		SIFTCTRLOP1 OP2
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


T_GPT:
	dc.w	$0000,$0003,$000C,$000F,$0030,$0033,$003C,$003F
	dc.w	$00C0,$00C3,$00CC,$00CF,$00F0,$00F3,$00FC,$00FF
	dc.w	$0300,$0303,$030C,$030F,$0330,$0333,$033C,$033F
	dc.w	$03C0,$03C3,$03CC,$03CF,$03F0,$03F3,$03FC,$03FF
	dc.w	$0C00,$0C03,$0C0C,$0C0F,$0C30,$0C33,$0C3C,$0C3F
	dc.w	$0CC0,$0CC3,$0CCC,$0CCF,$0CF0,$0CF3,$0CFC,$0CFF
	dc.w	$0F00,$0F03,$0F0C,$0F0F,$0F30,$0F33,$0F3C,$0F3F
	dc.w	$0FC0,$0FC3,$0FCC,$0FCF,$0FF0,$0FF3,$0FFC,$0FFF

	dc.w	$3000,$3003,$300C,$300F,$3030,$3033,$303C,$303F
	dc.w	$30C0,$30C3,$30CC,$30CF,$30F0,$30F3,$30FC,$30FF
	dc.w	$3300,$3303,$330C,$330F,$3330,$3333,$333C,$333F
	dc.w	$33C0,$33C3,$33CC,$33CF,$33F0,$33F3,$33FC,$33FF
	dc.w	$3C00,$3C03,$3C0C,$3C0F,$3C30,$3C33,$3C3C,$3C3F
	dc.w	$3CC0,$3CC3,$3CCC,$3CCF,$3CF0,$3CF3,$3CFC,$3CFF
	dc.w	$3F00,$3F03,$3F0C,$3F0F,$3F30,$3F33,$3F3C,$3F3F
	dc.w	$3FC0,$3FC3,$3FCC,$3FCF,$3FF0,$3FF3,$3FFC,$3FFF

	dc.w	$C000,$C003,$C00C,$C00F,$C030,$C033,$C03C,$C03F
	dc.w	$C0C0,$C0C3,$C0CC,$C0CF,$C0F0,$C0F3,$C0FC,$C0FF
	dc.w	$C300,$C303,$C30C,$C30F,$C330,$C333,$C33C,$C33F
	dc.w	$C3C0,$C3C3,$C3CC,$C3CF,$C3F0,$C3F3,$C3FC,$C3FF
	dc.w	$CC00,$CC03,$CC0C,$CC0F,$CC30,$CC33,$CC3C,$CC3F
	dc.w	$CCC0,$CCC3,$CCCC,$CCCF,$CCF0,$CCF3,$CCFC,$CCFF
	dc.w	$CF00,$CF03,$CF0C,$CF0F,$CF30,$CF33,$CF3C,$CF3F
	dc.w	$CFC0,$CFC3,$CFCC,$CFCF,$CFF0,$CFF3,$CFFC,$CFFF

	dc.w	$F000,$F003,$F00C,$F00F,$F030,$F033,$F03C,$F03F
	dc.w	$F0C0,$F0C3,$F0CC,$F0CF,$F0F0,$F0F3,$F0FC,$F0FF
	dc.w	$F300,$F303,$F30C,$F30F,$F330,$F333,$F33C,$F33F
	dc.w	$F3C0,$F3C3,$F3CC,$F3CF,$F3F0,$F3F3,$F3FC,$F3FF
	dc.w	$FC00,$FC03,$FC0C,$FC0F,$FC30,$FC33,$FC3C,$FC3F
	dc.w	$FCC0,$FCC3,$FCCC,$FCCF,$FCF0,$FCF3,$FCFC,$FCFF
	dc.w	$FF00,$FF03,$FF0C,$FF0F,$FF30,$FF33,$FF3C,$FF3F
	dc.w	$FFC0,$FFC3,$FFCC,$FFCF,$FFF0,$FFF3,$FFFC,$FFFF


P_EMM:	dcb.w	64*2,$FFFF
P_ROM:	dc.l	$FFFFFFFF
	.even
IPLROM:	ds.b	$1000
CGROM:	ds.b	$0800


	.bss

	.even
	ds.b	$8000
A_IOB:	ds.b	$8000

CROM2:	ds.b	8*8*$100
CROM2e:	ds.b	8*8*$100*2
CGRAM:	ds.b	8*8*$100
CGRAMe:	ds.b	8*8*$100*2

END:

	.end
