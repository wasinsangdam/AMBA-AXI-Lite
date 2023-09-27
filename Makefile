# Compiler
CC 		= iverilog
FLAGS 	= -Winfloop

# Simulator
VRUN	= vvp

# Waveform viewer
VIEWER 	= gtkwave

RTLDIR	:= ./rtl
RTLEXT	:= v

# Sources
SRCS 	:= $(notdir $(wildcard $(RTLDIR)/*.$(RTLEXT)))

# Target
EXE_TARGET = top
SIM_TARGET = wave.vcd

.PHONY: all sim clean

all : $(SIM_TARGET)

sim : 
	$(VIEWER) $(SIM_TARGET) &


$(EXE_TARGET) : $(addprefix $(RTLDIR)/,$(SRCS))
	$(CC) $(FLAGS) $(addprefix $(RTLDIR)/,$(SRCS)) -o $(EXE_TARGET)

$(SIM_TARGET) : $(EXE_TARGET)
	$(VRUN) $(EXE_TARGET)

clean : 
	rm -rf $(EXE_TARGET) $(SIM_TARGET)