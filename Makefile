# Compiler
CC 		= iverilog
FLGAS 	= -Winfloop

# Simulator
SIM		= vvp

# Waveform viewer
VIEWER 	= gtkwave


# Sources
SRCS = $(wildcard *.v)

# # Dump file
# VCDS = $(wildcard *.vcd)



EXE_TARGET = top
SIM_TARGET = wave.vcd

all : $(SIM_TARGET)

view : 
	$(VIEWER) $(SIM_TARGET) &

$(EXE_TARGET) : $(SRCS)
	$(CC) $(FLGAS) $(SRCS) -o $(EXE_TARGET)

$(SIM_TARGET) : $(EXE_TARGET)
	$(SIM) $(EXE_TARGET)

clean : 
	rm -rf $(EXE_TARGET) $(SIM_TARGET)