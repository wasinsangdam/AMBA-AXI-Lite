`timescale 1ns/1ps

module s_axil_register # (
    parameter   S_AXI_ADDR_WIDTH = 6,
                S_AXI_DATA_WIDTH = 32
)
(   
    // Global
    input                                   ACLK    ,
    input                                   ARESET  ,

    // Write Address Channel (AW)
    input   [S_AXI_ADDR_WIDTH-1 : 0]        AWADDR  ,
    input                                   AWVALID ,
    output                                  AWREADY ,

    // Write Data Channel (W)
    input   [S_AXI_DATA_WIDTH-1 : 0]        WDATA   ,
    input                                   WVALID  ,
    output                                  WREADY  ,
    input   [S_AXI_DATA_WIDTH/8-1 : 0]      WSTRB   ,

    // Write Response Channel (B)
    output  [1 : 0]                         BRESP   ,
    output                                  BVALID  ,
    input                                   BREADY  ,

    // Read Address Channel (AR)
    input   [S_AXI_ADDR_WIDTH-1 : 0]        ARADDR  ,
    input                                   ARVALID ,
    output                                  ARREADY ,

    // Read Data Channel (R)
    output  [S_AXI_DATA_WIDTH-1 : 0]        RDATA   ,
    output  [1 : 0]                         RRESP   ,
    output                                  RVALID  ,
    input                                   RREADY
);  
    //======================================//
    //  Relationships between the channels  //
    //======================================//
    // * Write response must always follow the last write transfer
    //   in the write transaction of which it is a part.
    // * Read data must always follow the address to which the data relates.
    // * Channel handshakes must conform to the dependencies.

    //==================================================//
    //  Dependencies between channel handshake signals  //
    //==================================================//
    // * VALID signal of the AXI interface sending information must not be dependent
    //   on the READY signal of the AXI interface receiving that information.
    // * AXI interface that is receiving information can wait until it detects 
    //   a VALID signal before it asserts its corresponding READY signal.
    // * It is acceptable to assert READY before detecting the corresponding VALID.
    //   This can result in a more efficient design.

    //====================//
    //  Register Address  //
    //====================//
    localparam  ADDR_REG_0 = 'h00, ADDR_REG_8 = 'h20,
                ADDR_REG_1 = 'h04, ADDR_REG_9 = 'h24,
                ADDR_REG_2 = 'h08, ADDR_REG_A = 'h28,
                ADDR_REG_3 = 'h0C, ADDR_REG_B = 'h2C,
                ADDR_REG_4 = 'h10, ADDR_REG_C = 'h30,
                ADDR_REG_5 = 'h14, ADDR_REG_D = 'h34,
                ADDR_REG_6 = 'h18, ADDR_REG_E = 'h38,
                ADDR_REG_7 = 'h1C, ADDR_REG_F = 'h3C;

    //============//
    //  Register  //
    //============//
    reg     [S_AXI_DATA_WIDTH-1 : 0]    registers [0 : 15];


    //=========================================//
    //  Write Transaction Dependencies (Slave) //
    //=========================================//
    // * Slave can wait for AWVALID or WVALID, or both before asserting AWREADY.
    // * Slave can assert AWREADY before AWVALID or WVALID, or both, are asserted.
    // * Slave can assert WREADY before AWVALID or WVALID, or both, are asserted.
    // * Slave must wait for both WVALID and WREADY to be asseted before asserting BVALID.
    // * Slave must not wait for the master to assert BREADY before asserting BVALID.

    
    //=====================//
    //  Write Address FSM  //
    //=====================//
    localparam  ST_AW_IDLE = 1'd0,
                ST_AW_DONE = 1'd1;

    reg                                 aw_state, aw_next;
    reg     [S_AXI_ADDR_WIDTH-1 : 0]    aw_reg;
    wire                                aw_hs;

    always @ (posedge ACLK) begin
        if (ARESET)     aw_state <= ST_AW_IDLE;
        else            aw_state <= aw_next;
    end

    always @ (*) begin
        aw_next = aw_state;
        case (aw_state)
            ST_AW_IDLE : if (AWVALID)   aw_next = ST_AW_DONE;
                         else           aw_next = ST_AW_IDLE;
            ST_AW_DONE :                aw_next = ST_AW_IDLE;
            default    :                aw_next = ST_AW_IDLE;
        endcase
    end

    assign aw_hs   = (AWVALID & AWREADY);
    assign AWREADY = (aw_state == ST_AW_IDLE);

    always @ (posedge ACLK) begin
        if      (ARESET)    aw_reg <= 'h0;
        else if (aw_hs)     aw_reg <= AWADDR;
    end

    //==================//
    //  Write Data FSM  //
    //==================//
    localparam  ST_W_IDLE = 2'd0,
                ST_W_DATA = 2'd1,
                ST_W_DONE = 2'd2;

    reg     [1 : 0]                     w_state, w_next;
    wire    [S_AXI_DATA_WIDTH-1 : 0]    w_mask;
    wire                                w_hs;


    always @ (posedge ACLK) begin
        if (ARESET)     w_state <= ST_W_IDLE;
        else            w_state <= w_next;
    end

    always @ (*) begin
        w_next = w_state;
        case (w_state)
            ST_W_IDLE : if (WVALID)     w_next = ST_W_DATA;
                        else            w_next = ST_W_IDLE;
            ST_W_DATA : if (BREADY)     w_next = ST_W_DONE;
                        else            w_next = ST_W_DATA;
            ST_W_DONE :                 w_next = ST_W_IDLE;
            default   :                 w_next = ST_W_IDLE;
        endcase
    end

    assign w_hs   = (WVALID & WREADY);
    assign w_mask = { {8{WSTRB[3]}}, {8{WSTRB[2]}}, {8{WSTRB[1]}}, {8{WSTRB[0]}} };
    assign WREADY = (w_state == ST_W_IDLE);
    assign BVALID = (w_state == ST_W_DATA);
    assign BRESP  = 2'b00;


    integer i;

    always @ (posedge ACLK) begin
        if (ARESET) begin
            for (i = 0; i < 16; i = i + 1) registers[i] <= 'h0;
        end
        else if (w_hs) begin
            case (aw_reg)
                ADDR_REG_0 : registers[0]  <= (WDATA & w_mask) | (registers[0]  & ~w_mask); 
                ADDR_REG_1 : registers[1]  <= (WDATA & w_mask) | (registers[1]  & ~w_mask); 
                ADDR_REG_2 : registers[2]  <= (WDATA & w_mask) | (registers[2]  & ~w_mask); 
                ADDR_REG_3 : registers[3]  <= (WDATA & w_mask) | (registers[3]  & ~w_mask); 
                ADDR_REG_4 : registers[4]  <= (WDATA & w_mask) | (registers[4]  & ~w_mask); 
                ADDR_REG_5 : registers[5]  <= (WDATA & w_mask) | (registers[5]  & ~w_mask); 
                ADDR_REG_6 : registers[6]  <= (WDATA & w_mask) | (registers[6]  & ~w_mask); 
                ADDR_REG_7 : registers[7]  <= (WDATA & w_mask) | (registers[7]  & ~w_mask); 
                ADDR_REG_8 : registers[8]  <= (WDATA & w_mask) | (registers[8]  & ~w_mask); 
                ADDR_REG_9 : registers[9]  <= (WDATA & w_mask) | (registers[9]  & ~w_mask); 
                ADDR_REG_A : registers[10] <= (WDATA & w_mask) | (registers[10] & ~w_mask); 
                ADDR_REG_B : registers[11] <= (WDATA & w_mask) | (registers[11] & ~w_mask); 
                ADDR_REG_C : registers[12] <= (WDATA & w_mask) | (registers[12] & ~w_mask); 
                ADDR_REG_D : registers[13] <= (WDATA & w_mask) | (registers[13] & ~w_mask); 
                ADDR_REG_E : registers[14] <= (WDATA & w_mask) | (registers[14] & ~w_mask); 
                ADDR_REG_F : registers[15] <= (WDATA & w_mask) | (registers[15] & ~w_mask);  
            endcase
        end
    end

    //========================================//
    //  Read Transaction Dependencies (Slave) //
    //========================================//
    // * Slave can wait for ARVALID to be asserted before it asserts ARREADY.
    // * Slave can assert ARREADY before ARVALID is asserted.
    // * Slave must wait for both ARVALID and ARREADY to be asserted before it asserts RVALID.
    // * Slave must not wait for the master to assert RREADY before asserting RVALID.

    //============//
    //  Read FSM  //
    //============//
    localparam  ST_R_IDLE = 2'd0,
                ST_R_DATA = 2'd1,
                ST_R_DONE = 2'd2;

    reg     [1 : 0]                     r_state, r_next;
    reg     [S_AXI_ADDR_WIDTH-1 : 0]    ar_reg;
    wire                                ar_hs;
    reg     [S_AXI_DATA_WIDTH-1 : 0]    r_reg;
    wire                                r_hs;

    always @ (posedge ACLK) begin
        if (ARESET)     r_state <= ST_R_IDLE;
        else            r_state <= r_next;
    end

    always @ (*) begin
        r_next = r_state;
        case (r_state)
            ST_R_IDLE : if (ARVALID)    r_next = ST_R_DATA;
                        else            r_next = ST_R_IDLE;
            ST_R_DATA : if (RREADY)     r_next = ST_R_DONE;
                        else            r_next = ST_R_DATA;
            ST_R_DONE :                 r_next = ST_R_IDLE;
            default   :                 r_next = ST_R_IDLE;
        endcase
    end

    assign ar_hs   = (ARREADY & ARVALID);
    assign r_hs    = (RREADY & RVALID);
    assign ARREADY = (r_state == ST_R_IDLE);
    assign RVALID  = (r_state == ST_R_DATA);
    assign RRESP   = 2'b00;
    assign RDATA   = r_reg;

    always @ (posedge ACLK) begin
        if      (ARESET)    ar_reg <= 'h0;
        else if (ar_hs)     ar_reg <= ARADDR;
    end


    always @ (posedge ACLK) begin
        if (ARESET) 
            r_reg <= 'h0;
        else if (r_hs) begin
            case (ar_reg)
                ADDR_REG_0 : r_reg <= registers[0];
                ADDR_REG_1 : r_reg <= registers[1];
                ADDR_REG_2 : r_reg <= registers[2];
                ADDR_REG_3 : r_reg <= registers[3];
                ADDR_REG_4 : r_reg <= registers[4];
                ADDR_REG_5 : r_reg <= registers[5];
                ADDR_REG_6 : r_reg <= registers[6];
                ADDR_REG_7 : r_reg <= registers[7];
                ADDR_REG_8 : r_reg <= registers[8];
                ADDR_REG_9 : r_reg <= registers[9];
                ADDR_REG_A : r_reg <= registers[10];
                ADDR_REG_B : r_reg <= registers[11];
                ADDR_REG_C : r_reg <= registers[12];
                ADDR_REG_D : r_reg <= registers[13];
                ADDR_REG_E : r_reg <= registers[14];
                ADDR_REG_F : r_reg <= registers[15];
            endcase
        end
    end

    

    //===============//
    //  Debug State  //
    //===============//

    // synthesis translate_off
    reg     [8*7-1 : 0]     AW_STATE;
    always @ (*) begin
        case (aw_state)
            ST_AW_IDLE : AW_STATE = "AW_IDLE";
            ST_AW_DONE : AW_STATE = "AW_DONE";
            default    : AW_STATE = "XX_XXXX";
        endcase
    end

    reg     [8*7-1 : 0]     W_STATE;
    always @ (*) begin
        case (w_state)
            ST_W_IDLE : W_STATE = "WR_IDLE";
            ST_W_DATA : W_STATE = "WR_DATA";
            ST_W_DONE : W_STATE = "WR_DONE";
            default   : W_STATE = "XX_XXXX";
        endcase
    end

    reg     [8*7-1 : 0]     RD_STATE;
    always @ (*) begin
        case (r_state)
            ST_R_IDLE : RD_STATE = "RD_IDLE";
            ST_R_DATA : RD_STATE = "RD_DATA";
            ST_R_DONE : RD_STATE = "RD_DONE";
            default   : RD_STATE = "XX_XXXX";
        endcase
    end

    reg     [S_AXI_DATA_WIDTH : 0]  reg_0, reg_1, reg_2, reg_3, 
                                    reg_4, reg_5, reg_6, reg_7,
                                    reg_8, reg_9, reg_A, reg_B, 
                                    reg_C, reg_D, reg_E, reg_F;
    always @ (*) begin
        reg_0 = registers[0];
        reg_1 = registers[1];
        reg_2 = registers[2];
        reg_3 = registers[3];
        reg_4 = registers[4];
        reg_5 = registers[5];
        reg_6 = registers[6];
        reg_7 = registers[7];
        reg_8 = registers[8];
        reg_9 = registers[9];
        reg_A = registers[10];
        reg_B = registers[11];
        reg_C = registers[12];
        reg_D = registers[13];
        reg_E = registers[14];
        reg_F = registers[15];
    end

    // synthesis translate_on


endmodule