x	:	X1.x X1DB.x

X1.x		:	DMYZ80DB.o X1EMU.o Z801.o Z802.o X1IO.o
	hlk $^ -o $@

X1DB.x		:	Z80DB.o Z80DIS.o X1EMUDB.o Z801_DB.o Z802_DB.o X1IO.o
	hlk $^ -o $@

X1EMU.o		:	X1EMU.has
	has -w $^ -s Z80DEBUG=0 -o $@

X1EMUDB.o	:	X1EMU.has
	has -w $^ -s Z80DEBUG=1 -o $@

Z801.o		:	Z80.has
	has -w $^ -s F_ROM=0 -s Z80DEBUG=0 -o $@ > err.err

Z802.o		:	Z80.has
	has -w $^ -s F_ROM=1 -s Z80DEBUG=0 -o $@ > err.err

Z801_DB.o	:	Z80.has
	has -w $^ -s F_ROM=0 -s Z80DEBUG=1 -o $@ > err.err

Z802_DB.o	:	Z80.has
	has -w $^ -s F_ROM=1 -s Z80DEBUG=1 -o $@ > err.err

X1IO.o		:	X1IO.has
	has -w $^ > err.err

Z80DB.o		:	Z80DB.has
	has -w $^ -s DUMMYDB=0 -o $@ > err.err

DMYZ80DB.o	:	Z80DB.has
	has -w $^ -s DUMMYDB=1 -o $@ > err.err

Z80DIS.o	:	Z80DIS.has
	has -w $^ > err.err


arc	:	X1V100G2.LZH
X1V100G2.LZH	:	X1.x X1DB.x CONFIG.X1 X1.DOC X1VG.DOC SOURCE.LZH 2DTOOL.LZH X1FILE.LZH
	lha a $@ $^

SOURCE.LZH	:	Makefile X1EMU.has X1IO.has Z80.has Z80DB.has Z80DIS.has \
			TEST.Z8D TEST.Z80
	lha a $@ $^

2DTOOL.LZH	:	2DTOOL/2DMAKE.EXE 2DTOOL/2DBACK.EXE 2DTOOL/MAKEFILE 2DTOOL/2DMAKE.C 2DTOOL/2DBACK.C
	lha a -x $@ $^

X1FILE.LZH	:	X1FILE/X1FILE.x X1FILE/Makefile X1FILE/X1FILE.c X1FILE/X1MAIN.c X1FILE/COMMON.H X1FILE/CONFIG.H
	lha a -x $@ $^


