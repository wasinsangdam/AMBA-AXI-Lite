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
        test(NUM_REG, 0);
        repeat (100) @ (posedge ACLK);
        test(NUM_REG, 1);
        repeat (100) @ (posedge ACLK);
        test(NUM_REG, 2);
        repeat (100) @ (posedge ACLK);
        done = 1'b1;
        repeat (10) @ (posedge ACLK);
    end


    //================//
    //  Test options  //
    //================//
    // 0 : Write after Read in order        
    //   * Read Address : 0x00 ~ 0x3C, Write Address : 0x00 ~ 0x3C, Write Data : 1 ~ 16
    // 1 : READ and Write at the same time  
    //   * Read Address : 0x00 ~ 0x20, Write Address : 0x20 ~ 0x3C, Write Data : Random
    // 2 : Write random value at random address, Read in order
    //   * Read Address : 0x00 ~ 0x3C, Write Address : Random, Write Data : Random
        
    task test;
        input   integer                     nwords;
        input   integer                     option;

        reg     [M_AXI_ADDR_WIDTH-1 : 0]    rd_addr;
        reg     [M_AXI_DATA_WIDTH-1 : 0]    rd_data;
        reg     [M_AXI_ADDR_WIDTH-1 : 0]    wr_addr;
        reg     [M_AXI_DATA_WIDTH-1 : 0]    wr_data;
        
        integer                             i, j;

        integer                             random_ADDR;
        integer                             random_DATA;        

        begin
            // [Option 0] Write after Read in order
            if (option == 0) begin
                $display("\n[Write after Read in order]");
                $display("- Write");
                for (i = 0; i < nwords * 4; i = i + 4) begin
                    wr_addr = i;
                    wr_data = i/4 + 1;
                    axil_write(wr_addr, wr_data);
                    @ (posedge ACLK);
                    $display("[INFO] Write address 0x%x, Write Data : %3d", wr_addr, wr_data);
                end

                $display("- Read");
                for (j = 0; j < nwords * 4; j = j + 4) begin
                    rd_addr = j;
                    axil_read(rd_addr, rd_data);
                    @ (posedge ACLK);
                    $display("[INFO] Read  address 0x%x, Read  Data : %3d", rd_addr, rd_data);
                end
            end
            // [Option 1] Read and Write at the same time
            else if (option == 1) begin
                $display("\n[Read and Write at the same time]");
                fork 
                    begin
                        for (i = 0; i < (nwords * 4)/2; i = i + 4) begin
                            wr_addr = i;
                            wr_data = ($urandom % 10);
                            axil_write(wr_addr, wr_data);
                            @ (posedge ACLK);
                            $display("[INFO] Write address 0x%x, Write Data : %3d", wr_addr, wr_data);
                        end
                    end
                    begin
                        for (j = 32; j < nwords * 4; j = j + 4) begin
                            rd_addr = j;
                            axil_read(rd_addr, rd_data);
                            @ (posedge ACLK);
                            $display("[INFO] Read  address 0x%x, Read  Data : %3d", rd_addr, rd_data);
                        end
                    end
                join
            end
            // [Option 2] Write random value at random address, Read in order
            else if (option == 2) begin
                $display("\n[Write after Read out of order]");
                $display("- Write");
                for (i = 0; i < nwords * 4; i = i + 4) begin
                    wr_addr = ($urandom % 16) * 4;
                    wr_data = ($urandom % 10);
                    axil_write(wr_addr, wr_data);
                    @ (posedge ACLK);
                    $display("[INFO] Write address 0x%x, Write Data : %3d", wr_addr, wr_data);
                end

                $display("- Read");
                for (j = 0; j < nwords * 4; j = j + 4) begin
                    rd_addr = j;
                    axil_read(rd_addr, rd_data);
                    @ (posedge ACLK);
                    $display("[INFO] Read  address 0x%x, Read  Data : %3d", rd_addr, rd_data);
                end
            end
            else begin
                $display("Invalid option");
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

        /* Random value */
        integer                             random_AW_W;
        integer                             random_B;
        integer                             random_C_AW;
        integer                             random_C_W;
        integer                             random_C_B;

        begin
            
            /* Generate random value for AWVALID cycle */
            // range : 0 ~ 9 cycle(s)
            random_C_AW = ($urandom % 10);

            /* Generate random value for WVALID cycle */
            // range : 0 ~ 9 cycle(s)
            random_C_W = ($urandom % 10);

            /* Generate random value for BREADY cycle */
            // range : 0 ~ 9 cycle(s)
            random_C_B = ($urandom % 10);

            fork
                /* Write Address channel (AW) */
                begin
                    AWADDR  = wr_addr;                      // Set AWADDR
                    AWVALID = 1'b0;                         // Set AWVALID zero
                    repeat (random_C_AW) @ (posedge ACLK);  // After random cycle(s)
                    AWVALID = 1'b1;                         // Assert AWVALID
                    
                    wait (AWREADY & AWVALID);               // Wait AW channel handshake
                    @ (posedge ACLK);                       // After one cycle
                    AWVALID = 1'b0;                         // Set AWVALID zero
                end

                /* Write Data channel (W) */
                begin
                    fork 
                        begin
                            WDATA   = wr_data;                      // Set WDATA
                            WSTRB   = 4'b1111;                      // Set STRB
                            WVALID  = 1'b0;                         // Set WVALID zero
                            repeat (random_C_W) @ (posedge ACLK);   // After random cycle(s)
                            WVALID  = 1'b1;                         // Assert WVALID

                            wait (WREADY & WVALID);                 // Wait W channel handshake
                            @ (posedge ACLK);                       // After one cycle
                            WSTRB   = 4'b0000;                      // Set WSTRB zero 
                            WVALID  = 1'b0;                         // Set WVALID zero
                        end
                        begin
                            BREADY = 1'b0;                          // Set BREADY zero
                            repeat (random_C_B) @ (posedge ACLK);   // After random cycle(s)
                            BREADY = 1'b1;                          // Assert BREADY
                    
                            wait (BVALID & BVALID);                 // Wait B channel handshake
                            @ (posedge ACLK);                       // After one cycle
                            BREADY = 1'b0;                          // Set BREADY zero
                        end
                    join
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

        /* Random value */        
        integer                             random_C_AR;
        integer                             random_C_R;

        begin
            
            /* Generate random value for ARVALID cycle */
            // range : 0 ~ 9 cycle(s)
            random_C_AR = ($urandom % 10);

            /* Generate random value for RREADY cycle */
            // range : 0 ~ 9 cycle(s)
            random_C_R = ($urandom % 10);

            /* Read Address channel (AR) */
            fork 
                begin
                    ARADDR  = addr;                         // Set address
                    ARVALID = 1'b0;                         // Set ARVALID zero
                    repeat (random_C_AR) @ (posedge ACLK);  // After random cycle(s)
                    ARVALID = 1'b1;                         // Assert ARVALID

                    /* Read Data channel (R) */
                    wait (ARVALID & ARREADY);               // Wait AR channel handshake
                    @ (posedge ACLK);                       // After 1 cycle
                    ARVALID = 1'b0;                         // Set ARVALID zero
                end
                begin
                    RREADY  = 1'b0;                         // Set RREADY zero
                    repeat (random_C_R) @ (posedge ACLK);   // After random cycle(s)
                    RREADY  = 1'b1;                         // Assert RREADY 
                    wait (RREADY & RVALID);                 // Wait R channel handshake
                    data    = RDATA;                        // Return read data

                    @ (posedge ACLK);                       // After 1 cycle
                    RREADY  = 1'b0;                         // Set RREADY zero
                end
            join
        end

    endtask

endmodule