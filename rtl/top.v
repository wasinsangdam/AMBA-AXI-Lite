`timescale 1ns/1ps

module top;

    localparam  AXI_ADDR_WIDTH = 6,
                AXI_DATA_WIDTH = 32;

    // Global
    reg                                     ACLK    ;
    reg                                     ARESET  ;

    // Write Address Channel (AW)
    wire    [AXI_ADDR_WIDTH-1 : 0]          AWADDR  ;
    wire                                    AWVALID ;
    wire                                    AWREADY ;

    // Write Data Channel (W)
    wire    [AXI_DATA_WIDTH-1 : 0]          WDATA   ;
    wire                                    WVALID  ;
    wire                                    WREADY  ;
    wire    [AXI_DATA_WIDTH/8-1 : 0]        WSTRB   ;

    // Write Response Channel (B)
    wire    [1 : 0]                         BRESP   ;
    wire                                    BVALID  ;
    wire                                    BREADY  ;

    // Read Address Channel (AR)
    wire    [AXI_ADDR_WIDTH-1 : 0]          ARADDR  ;
    wire                                    ARVALID ;
    wire                                    ARREADY ;

    // Read Data Channel (R)
    wire    [AXI_DATA_WIDTH-1 : 0]          RDATA   ;
    wire    [1 : 0]                         RRESP   ;
    wire                                    RVALID  ;
    wire                                    RREADY  ;


    //===================//
    //  Master Instance  //
    //===================//
    m_axil_register_bfm # (
        .M_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .M_AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    )
    u_master (
        .ACLK       (ACLK   ),
        .ARESET     (ARESET ),

        .AWADDR     (AWADDR ),
        .AWVALID    (AWVALID),
        .AWREADY    (AWREADY),

        .WDATA      (WDATA  ),
        .WVALID     (WVALID ),
        .WREADY     (WREADY ),
        .WSTRB      (WSTRB  ),

        .BRESP      (BRESP  ),
        .BVALID     (BVALID ),
        .BREADY     (BREADY ),

        .ARADDR     (ARADDR ),
        .ARVALID    (ARVALID),
        .ARREADY    (ARREADY),

        .RDATA      (RDATA  ),
        .RRESP      (RRESP  ),
        .RVALID     (RVALID ),
        .RREADY     (RREADY )
    );

    //==================//
    //  Slave Instance  //
    //==================//
    s_axil_register # (
        .S_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .S_AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    )
    u_slave (
        .ACLK       (ACLK   ),
        .ARESET     (ARESET ),

        .AWADDR     (AWADDR ),
        .AWVALID    (AWVALID),
        .AWREADY    (AWREADY),

        .WDATA      (WDATA  ),
        .WVALID     (WVALID ),
        .WREADY     (WREADY ),
        .WSTRB      (WSTRB  ),

        .BRESP      (BRESP  ),
        .BVALID     (BVALID ),
        .BREADY     (BREADY ),

        .ARADDR     (ARADDR ),
        .ARVALID    (ARVALID),
        .ARREADY    (ARREADY),

        .RDATA      (RDATA  ),
        .RRESP      (RRESP  ),
        .RVALID     (RVALID ),
        .RREADY     (RREADY )
    );

    //=========================//
    //  Initial value & Reset  //
    //=========================//
    initial begin
        ACLK    = 1'b0;
        ARESET  = 1'b0;

        #100
        ARESET  = 1'b1;

        #50
        ARESET  = 1'b0;
    end

    //=========================//
    //  Create Clock (100MHz)  //
    //=========================//
    always #5 ACLK = ~ACLK;


    //=================//
    //  Main function  //
    //=================//
    initial begin
        wait(ARESET == 1'b0);
        wait(ARESET == 1'b1);

        repeat (10) @ (posedge ACLK);
        wait(u_master.done == 1'b1);
        repeat (10) @ (posedge ACLK);

        $finish;
    end

    //=============//
    //  Dump file  //
    //=============//
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0);
    end

endmodule
