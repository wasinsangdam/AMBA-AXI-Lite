`timescale 1ns/1ps

module m_axil_register_bfm # (
    parameter   M_AXI_DATA_WIDTH = 6,
                M_AXI_ADDR_WIDTH = 32
)   
(
    // Global
    input                                       ACLK    ,
    input                                       ARESET  ,       

    // Write Address Channel (AW)
    output  reg     [M_AXI_ADDR_WIDTH-1 : 0]    AWADDR  ,
    output  reg                                 AWVALID ,
    input                                       AWREADY ,

    // Write Data Channel (W)
    output  reg     [M_AXI_DATA_WIDTH-1 : 0]    WDATA   ,
    output  reg                                 WVALID  ,
    input                                       WREADY  ,
    output  reg     [M_AXI_DATA_WIDTH/8-1 : 0]  WSTRB   ,

    // Write Response Channel (B)
    input           [1 : 0]                     BRESP   ,
    input                                       BVALID  ,
    output  reg                                 BREADY  ,

    // Read Address Channel (AR)
    output  reg     [M_AXI_ADDR_WIDTH-1 : 0]    ARADDR  ,
    output  reg                                 ARVALID ,
    input                                       ARREADY ,

    // Read Data Channel (R)
    input           [M_AXI_DATA_WIDTH-1 : 0]    RDATA   ,
    input           [1 : 0]                     RRESP   ,                   
    input                                       RVALID  ,
    output  reg                                 RREADY  
);

    localparam  NUM_REG     = 16;

    //================//
    // Test Scenario  //
    //================//
    // 1. Write 1 ~ 16 value 
    // 2. Random interval
    // 3. 

    reg         done = 1'b0;

    initial begin
        AWADDR      = 'h0;
        AWVALID     = 'h0;
        
        WDATA       = 'h0;
        WVALID      = 'h0;
        WSTRB       = 'h0;

        BREADY      = 'h0;

        ARADDR      = 'h0;
        ARVALID     = 'h0;

        RREADY      = 'h0;

        wait(ARESET == 1'b0);
        wait(ARESET == 1'b1);

        repeat (10) @ (posedge ACLK);
        test(NUM_REG);
        repeat (10) @ (posedge ACLK);
        done = 1'b1;
        repeat (10) @ (posedge ACLK);
    end


    task test;
        input   integer                     nwords;

        reg     [M_AXI_ADDR_WIDTH-1 : 0]    addr;
        reg     [M_AXI_DATA_WIDTH-1 : 0]    data;
        reg     [M_AXI_DATA_WIDTH-1 : 0]    value;
        
        integer                             i, j;

        begin
            data = 'h0;
            for (i = 0; i < nwords * 4; i = i + 4) begin
                addr = i;
                data = i/4 + 1;
                axil_write(addr, data);
                repeat (1) @ (posedge ACLK);
            end

            addr = 'h0;

            for (j = 0; j < nwords * 4; j = j + 4) begin
                addr = j;
                axil_read(addr, data);
                repeat (1) @ (posedge ACLK);
            end
        end

    endtask

    //==========================================//
    // Write Transaction Dependencies (Master)  //
    //==========================================//
    // * Master must not wait for the slave to assert AWREADY or WREADY  
    //   before asserting AWVALID or WVALID.
    // * Master can wait for BVALID before asserting BREADY.
    // * Master can assert BREADY before BVALID is asserted.

    task axil_write;
        input   [M_AXI_ADDR_WIDTH-1 : 0]    addr;
        input   [M_AXI_DATA_WIDTH-1 : 0]    data;

        begin
            fork
                begin
                    AWADDR  = addr;
                    AWVALID = 1'b1;
                    @ (posedge ACLK);
                    while (AWREADY == 1'b0) @ (posedge ACLK);
                    AWVALID = 1'b0;
                end
                begin
                    @ (posedge ACLK);
                    WDATA   = data;
                    WVALID  = 1'b1;
                    WSTRB   = 4'b1111;
                    @ (posedge ACLK);
                    while (WREADY == 1'b0) @ (posedge ACLK);
                    WSTRB   = 4'b0000;
                    WVALID  = 1'b0;
                end
                begin
                    @ (posedge ACLK);
                    BREADY = 1'b1;
                    @ (posedge ACLK);
                    while (BVALID == 1'b0) @ (posedge ACLK);
                    BREADY = 1'b0;
                end 
            join
        end
    endtask

    //=========================================//
    // Read Transaction Dependencies (Master)  //
    //=========================================//
    // * Master must not wait for the slave to assert ARREADY before asserting ARVALID.
    // * Master can wait for RVALID to be asserted before it asserts RREADY.
    // * Master can assert RREADY before RVALID is asserted.

    task axil_read;
        input   [M_AXI_ADDR_WIDTH-1 : 0]    addr;
        output  [M_AXI_DATA_WIDTH-1 : 0]    data;

        begin
            fork 
                begin
                    ARADDR  = addr;
                    ARVALID = 1'b1;
                    @ (posedge ACLK);
                    while (ARREADY == 1'b0) @ (posedge ACLK);
                    ARVALID = 1'b0;
                end
                begin
                    repeat (2) @ (posedge ACLK);
                    RREADY  = 1'b1;
                    @ (posedge ACLK);
                    while (RVALID == 1'b0) @ (posedge ACLK);
                    RREADY  = 1'b0;
                    data    = RDATA;

                end
            join
        end
    endtask



endmodule