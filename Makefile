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


arc	:	X1V100G1.LZH
X1V100G1.LZH	:	X1.x X1DB.x X1.DOC X1VG.DOC SOURCE.LZH
	lha a $@ $^

SOURCE.LZH	:	Makefile X1EMU.has X1IO.has Z80.has Z80DB.has Z80DIS.has \
			TEST.Z8D TEST.Z80
	lha a $@ $^

