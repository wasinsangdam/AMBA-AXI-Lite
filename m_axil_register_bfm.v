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

        reg     [M_AXI_ADDR_WIDTH-1 : 0]    rd_addr;
        reg     [M_AXI_DATA_WIDTH-1 : 0]    rd_data;
        reg     [M_AXI_ADDR_WIDTH-1 : 0]    wr_addr;
        reg     [M_AXI_DATA_WIDTH-1 : 0]    wr_data;
        
        integer                             i, j;
        // begin
        //     /* Generate random value for READ and WRITE */ 
        //     // 0 : READ and Write at the same time
        //     // 1 : Write after Read

            
            
        //     // /* Generate random value for */
        //     // for (i = 0; i < nwords * 4; i = i + 4) begin
                
        //     // end
        // end

        begin
            wr_data = 'h0;
            for (i = 0; i < nwords * 4; i = i + 4) begin
                wr_addr = i;
                wr_data = i/4 + 1;
                axil_write(wr_addr, wr_data);
                repeat (1) @ (posedge ACLK);
                $display("Write Data : %d", wr_data);

            end

            for (j = 0; j < nwords * 4; j = j + 4) begin
                rd_addr = j;
                axil_read(rd_addr, rd_data);
                repeat (1) @ (posedge ACLK);

                $display("Read Data : %d", rd_data);
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
        input   [M_AXI_ADDR_WIDTH-1 : 0]    wr_addr;
        input   [M_AXI_DATA_WIDTH-1 : 0]    wr_data;

        integer                             random_AW_W;
        integer                             random_B;
        integer                             random_C_AW;
        integer                             random_C_W;
        integer                             random_C_B;

        begin

            /* Generate random value for AW and W */
            // 0 : AW and W at the same time
            // 1 : AW after W
            // 2 : W after AW
            // integer random_AW_W;
            random_AW_W = $urandom % 3;

            /* Generate random value for BVALID and BREADY */
            // 0 : wait for BVALID before asserting BREADY
            // 1 : assert BREADY before BVALID is asserted
            random_B = $urandom % 2;

            /* Generate random value for AWVALID cycle */
            // range : 1 ~ 5 cycle(s)
            random_C_AW = ($urandom % 5) + 1;

            /* Generate random value for WVALID cycle */
            // range : 1 ~ 5 cycle(s)
            random_C_W = ($urandom % 5) + 1;

            /* Generate random value for BREADY cycle */
            // range : 1 ~ 5 cycle(s)
            random_C_B = ($urandom % 5) + 1;

            fork
                begin
                    AWADDR  = wr_addr;
                    repeat (random_C_AW) @ (posedge ACLK);
                    AWVALID = 1'b1;
                    
                    wait (AWREADY & AWVALID);
                    @ (posedge ACLK);
                    AWVALID = 1'b0;
                end
                begin
                    WDATA   = wr_data;
                    WSTRB   = 4'b1111;
                    repeat (random_C_W) @ (posedge ACLK);
                    WVALID  = 1'b1;

                    wait (WREADY & WVALID);
                    @ (posedge ACLK);
                    WSTRB   = 4'b1111;
                    WVALID  = 1'b0;


                    repeat (random_C_B) @ (posedge ACLK);
                    BREADY = 1'b1;
                    
                    wait (BVALID & BVALID);
                    @ (posedge ACLK);
                    BREADY = 1'b0;
                end 
            join
            // @ (posedge ACLK);
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

        // Generate random value for RVALID and RREADY
        // 0 : wait for RVALID to be asserted before it asserts RREADY.
        // 1 : assert RREADY before RVALID is asserted.

        // Generate random value for ARVALID cycle
        // range : 1 ~ 10 cycle(s)

        // Generate random value for RREADY cycle
        // range : 1 ~ 10 cycle(s)

        begin
            ARADDR  = addr;                 // Set address
            ARVALID = 1'b1;                 // Give ARVALID to slave
            wait (ARVALID && ARREADY);      // Wait AR channel handshake
            @ (posedge ACLK);               // After 1 cycle
            ARVALID = 1'b0;                 // Turn off ARVALID
            
            repeat (2) @ (posedge ACLK);
            RREADY  = 1'b1;                 // Give RREADY to slave
            wait (RREADY && RVALID);        // Wait R channel handshake
            @ (posedge ACLK);               // After 1 cycle
            RREADY  = 1'b0;                 // Turn off RREADY

            data    = RDATA;
        end
    endtask



endmodule