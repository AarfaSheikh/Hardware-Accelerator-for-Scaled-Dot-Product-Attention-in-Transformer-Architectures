//---------------------------------------------------------------------------
// DUT - 564/464 Project
//---------------------------------------------------------------------------
`include "common.vh"

module MyDesign(
//---------------------------------------------------------------------------
//System signals
  input wire reset_n                      ,  
  input wire clk                          ,

//---------------------------------------------------------------------------
//Control signals
  input wire dut_valid                    , 
  output wire dut_ready                   ,

//---------------------------------------------------------------------------
//input SRAM interface
  output wire                           dut__tb__sram_input_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_write_address ,
  output wire [`SRAM_DATA_RANGE     ]   dut__tb__sram_input_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_read_address  , 
  input  wire [`SRAM_DATA_RANGE     ]   tb__dut__sram_input_read_data     ,     

//weight SRAM interface
  output wire                           dut__tb__sram_weight_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_write_address ,
  output wire [`SRAM_DATA_RANGE     ]   dut__tb__sram_weight_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_read_address  , 
  input  wire [`SRAM_DATA_RANGE     ]   tb__dut__sram_weight_read_data     ,     

//result SRAM interface
  output wire                           dut__tb__sram_result_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_write_address ,
  output wire [`SRAM_DATA_RANGE     ]   dut__tb__sram_result_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_read_address  , 
  input  wire [`SRAM_DATA_RANGE     ]   tb__dut__sram_result_read_data     ,   

//scratchpad SRAM interface
  output wire                           dut__tb__sram_scratchpad_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_scratchpad_write_address ,
  output wire [`SRAM_DATA_RANGE     ]   dut__tb__sram_scratchpad_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_scratchpad_read_address  , 
  input  wire [`SRAM_DATA_RANGE     ]   tb__dut__sram_scratchpad_read_data  

);

// State registers
reg [4:0] current_state, next_state;

parameter [4:0]
   S0 = 5'b00000, //IDLE state
   S1 = 5'b00001, //read dimensions from SRAM
   S2 = 5'b00010, 
   S3 = 5'b00011, 
   S4 = 5'b00100,  
   S5 = 5'b00101,  
   S6 = 5'b00110,
   S7 = 5'b00111,
   S8 = 5'b01000,
   S9 = 5'b01001,
   S10 = 5'b01010, // End of Q, K, V calculation
   S11 = 5'b01011, // Wait state
   S12 = 5'b01100, // Start first element read from result and scratchpad SRAM for Q and K^T
   S13 = 5'b01101,
   S14 = 5'b01110,
   S15 = 5'b01111,
   S16 = 5'b10000,
   S17 = 5'b10001,
   S18 = 5'b10010,
   S19 = 5'b10011, // End of S calculation
   S20 = 5'b10100,
   S21 = 5'b10101,
   S22 = 5'b10110,
   S23 = 5'b10111,
   S24 = 5'b11000,
   S25 = 5'b11001,
   S26 = 5'b11010,
   S27 = 5'b11011;

// SRAM address registers
reg [11:0] sram_input_read_address;
reg [11:0] sram_weight_read_address; 
reg [31:0] sram_input_read_data;
reg [31:0] sram_weight_read_data;
reg [31:0] sram_result_read_data;
reg [31:0] sram_scratchpad_read_data;

reg [11:0] sram_result_read_address;
reg [11:0] sram_result_write_address;
reg [11:0] sram_scratchpad_read_address;
reg [11:0] sram_scratchpad_write_address;   

reg sram_result_write_enable;
reg sram_scratchpad_write_enable;
reg [31:0] sram_result_write_data;
reg [31:0] sram_scratchpad_write_data;

// Select lines
reg [1:0] compute_mac;
reg [1:0] read_addr_sel;
reg accum_result_sel, write_result_enable_sel, write_scratchpad_enable_sel;
reg sram_write_enable_r, sram_write_enable_s;
reg dut_ready_sel;
reg get_dimensions;
reg final_result_sel;
reg S_done;

reg [31:0] final_result;

// Matrix dimensions
reg [15:0] matrix_a_rows, matrix_a_cols, matrix_b_cols, matrix_b_rows; // a=I, b=W
reg [15:0] matrix_c_rows, matrix_c_cols; // Dimensions of matrix C
reg [15:0] matrix_transpose_b_cols, matrix_transpose_b_rows; 

reg [1:0] all_element_read_completed;
reg [1:0] matrix_done; // 00-Nothing done, 01-Q done, 10-K done, 11-V done & all W_matrix done
reg [31:0] accum_result;
reg [31:0] mac_result_z;
reg compute_complete;

// Counters
reg [11:0] C_row_counter, C_col_counter, matrix_a_rows_COUNTER, matrix_b_cols_COUNTER, matrix_a_cols_counter, matrix_b_rows_counter;

assign dut__tb__sram_input_write_enable = 1'b0;
assign dut__tb__sram_weight_write_enable = 1'b0;

always@(posedge clk or negedge reset_n)
begin
  if (!reset_n)   begin 
    current_state <= S0;
  end
  else begin
    current_state <= next_state;
  end
end

always @(*) begin 
  case (current_state)
  // IDLE State
  S0 : begin 
    if (dut_valid) begin
      // $display("I am in S0");
      dut_ready_sel           = 1'b0;
      get_dimensions = 0;
      next_state          = S1;
      // Read address select
      read_addr_sel       = 2'b00;
      // Compute mac lines
      compute_mac = 0;
      accum_result = 0;
    final_result_sel = 0;
      // Write selects
      write_result_enable_sel  = 1'b0;
      write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
    end
    else begin
      dut_ready_sel           = 1'b1;
      get_dimensions = 0;
      next_state          = S0;
      // Read address select
      read_addr_sel       = 2'b00;
      // Compute mac lines
      compute_mac = 0;
      accum_result = 0;
    final_result_sel = 0;
      // Write selects
      write_result_enable_sel  = 1'b0;
      write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
    end
    end

  // Get dimension values
  S1  : begin
      // $display("I am in S1");
    dut_ready_sel         = 1'b0;
    next_state            = S2;
    get_dimensions = 1'b1;
    // Read address select
    read_addr_sel       = 2'b00;
    // Compute mac lines
    compute_mac = 0;
    final_result_sel = 0;
    accum_result = 0;
    // Write selects
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

  S2: begin
      // $display("I am in S2");
    dut_ready_sel         = 1'b0;
    next_state            = S3;
    get_dimensions = 1'b1;
    read_addr_sel       = 2'b00;
    // Compute mac lines
    compute_mac = 0;
    final_result_sel = 0;
    accum_result = 0;
    // Write selects
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

  // Read First matrix elements - first multipliers for which accum=0
  S3: begin
      // $display("I am in S3");
    dut_ready_sel           = 1'b0;   
    get_dimensions = 0; 
    next_state          = S4; //(row_done == 1'b1)? S3: S4;
    // Read address select
    read_addr_sel = 2'b01; // increment read address
    // Compute mac lines
    compute_mac = 0;
    final_result_sel = 0;
    accum_result = 0;
    // Write selects
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

  // Read Next matrix elements
  S4: begin 
      // $display("I am in S4");
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    //modified-no
    next_state  = S5;
    // Read address select
    read_addr_sel = 2'b01; // increment read address
    // Compute mac lines
    compute_mac = 0; 
    accum_result = 0;
    final_result_sel = 0;
    // Write selects
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

  // Multiply elements with Accum=0
  S5: begin
    // $display("I am in S5");
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    //modified-no
    next_state = S6;
    // Read address select
    read_addr_sel = 2'b01; // increment read address
    // Compute mac lines
    compute_mac = 2'b01; 
    accum_result = 0;
    final_result_sel = 0;
    // Write selects
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

// Multiply elements with Accum=MAC_result
  S6: begin
    // $display("I am in S6");
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    next_state = S7;
    // Read address select
    read_addr_sel = 2'b01; // increment read address
    // Compute mac lines
    compute_mac = 2'b01; 
    final_result_sel = 0;
    accum_result = mac_result_z;
    // Write selects
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

  // Write to Result SRAM
  S7: begin
    // $display("I am in S7");
    dut_ready_sel  = 1'b0;
    get_dimensions = 0;
    next_state = (all_element_read_completed == 2'b01) ? S7 : (all_element_read_completed == 2'b10)? S7:S8; 
    // Read address select
    read_addr_sel = 2'b01; // Increment address
    // Compute mac lines
    compute_mac = 2'b01; 
    final_result_sel = 0;
    accum_result= mac_result_z;
    // Write selects
    write_result_enable_sel  = 1'b0; // enable write
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

  // Wait to write and check if Matrix is done or not
  S8: begin
    // $display("I am in S8");
    dut_ready_sel             = 1'b0;
      get_dimensions = 0;
      next_state = S9;
    // Read address select
    read_addr_sel = 2'b10; // Hold address
    // Compute mac lines
    compute_mac = 2'b01; 
    accum_result = mac_result_z;
    final_result_sel = 0;
    // Write selects
    write_result_enable_sel  = 1'b1; // enable write
    write_scratchpad_enable_sel  = 1'b1; // enable write in scratchpad SRAM
      S_done = 0;
  end

  //
  S9: begin
    // $display("I am in S9");
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    next_state = S10;
    // Read address select
    read_addr_sel = 2'b10; //Hold address
    // Compute mac lines
    compute_mac = 2'b01; 
    accum_result = mac_result_z;
    final_result_sel = 0;
    // Write selects
    write_result_enable_sel  = 1'b1; // enable write
    write_scratchpad_enable_sel  = 1'b1; // enable write in scratchpad SRAM
      S_done = 0;
  end

  S10: begin
    // $display("I am in S10");
    dut_ready_sel             = 1'b0;
      get_dimensions = 0;
    if (matrix_done == 2'b00)
      next_state = S3;//S2;
    else if(matrix_done == 2'b01)
      next_state = S3;
    else if(matrix_done == 2'b10)
      next_state = S3;
    else if(matrix_done == 2'b11)
      next_state = S11;
    // Read address select
    read_addr_sel = 2'b10; // Hold address
    // Compute mac lines
    compute_mac = 0; 
    accum_result = 0;
    final_result_sel = 1; //added
    // Write selects
    write_result_enable_sel  = 1'b0; // enable write
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

  // Wait state to reset all the counters
  S11: begin
    dut_ready_sel             = 1'b0; 
    next_state = S12;
    read_addr_sel = 2'b00;  
    compute_mac = 0;
    accum_result= 0;
    final_result_sel = 0;
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
    get_dimensions = 0;  
      S_done = 0;
  end

// Like S3
  S12: begin
    // $display("I am in S13");
    dut_ready_sel             = 1'b0; 
    next_state = (matrix_done!=0)? S19:S13;
    get_dimensions = 0;
    // Read address select
    read_addr_sel = 2'b11; // increment read address
    // Compute mac lines
    compute_mac = 0;
    final_result_sel = 0;
    accum_result = 0;
    // Write selects ---------check write enables --------
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

// Like S4
  S13: begin
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    //modified-no
    next_state  = (matrix_done!=0)? S19:S14; //changed 21 to 20
    // Read address select
    read_addr_sel = 2'b11; // increment read address
    // Compute mac lines
    compute_mac = 0; 
    accum_result = 0;
    final_result_sel = 0;
    // Write selects
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

// Like S5
  S14: begin
    // $display("I am in S14");
    dut_ready_sel         = 1'b0;
    get_dimensions = 0;
    next_state = (matrix_done!=0)? S19:S15;
    // Read address select
    read_addr_sel = 2'b11; // increment read address
    // Compute mac lines
    compute_mac = 2'b11; 
    accum_result = 0;
    final_result_sel = 0;
    // Write selects
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

// Like S6 - read address is 11 instead of 01
  S15: begin
    // $display("I am in S15");
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    next_state = (all_element_read_completed == 2'b00) ? S15:S16;
    // Read address select
    read_addr_sel = 2'b11; // increment read address
    // Compute mac lines
    compute_mac = 2'b11; 
    accum_result = mac_result_z;
    final_result_sel = 0;
    // Write selects ---???
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

//Like S8
  S16: begin
    // $display("I am in S17");
    dut_ready_sel     = 1'b0;
    get_dimensions = 0;
    next_state = (matrix_done!=0)? S19:S17;
    // Read address select
    read_addr_sel = 2'b10; // Hold address
    // Compute mac lines
    // compute_mac = 2'b11; 
    final_result_sel = 1;
    compute_mac = 2'b00;
    accum_result = 0;
    // accum_result = mac_result_z;
    // Write selects
    write_result_enable_sel  = 1'b0; // enable write
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

// Like S9
  S17: begin
    // $display("I am in S18");
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    next_state = S18;
    // Read address select
    read_addr_sel = 2'b10; //Hold address
    final_result_sel = 0;
    // $display("Final result: %d", final_result);
    compute_mac = 2'b00;
    accum_result = 0;
    // Write selects ---???
    write_result_enable_sel  = 1'b1; // enable write
    write_scratchpad_enable_sel  = 1'b0;
      S_done = 0;
  end

// Like S10
  S18: begin
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    next_state = (matrix_done==0) ? S12:S19;
    read_addr_sel = 2'b10; // Hold address
    // Compute mac lines
    compute_mac = 0; 
    accum_result = 0;
    // Write selects
    write_result_enable_sel  = 1'b0; // enable write
    write_scratchpad_enable_sel  = 1'b0;
    final_result_sel = 0;
      S_done = 0;
  end

  ///// Done tile S Matrix //////
  
  //Like S11 - Wait state to reset all counters
  S19: begin
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;  
    next_state = S20;
    read_addr_sel = 2'b00;  
    compute_mac = 0;
    accum_result= 0;
    final_result_sel = 0;
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0; 
    final_result_sel = 0;
    S_done = 0;
  end
//Like S3
  S20: begin
    dut_ready_sel = 1'b0; 
    next_state = S21;
    get_dimensions = 0;
    // Read address select
    read_addr_sel = 2'b11; // increment read address
    // Compute mac lines
    compute_mac = 0;
    final_result_sel = 0;
    accum_result = 0;
    // Write selects ---------check write enables --------
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
    S_done = 1'b1;
  end
//Like S4
  S21: begin
    dut_ready_sel  = 1'b0;
    get_dimensions = 0;
    //modified-no
    next_state  = (matrix_done!=0)? S27:S22;
    // Read address select
    read_addr_sel = 2'b11; // increment read address
    // Compute mac lines
    compute_mac = 0; 
    accum_result = 0;
    final_result_sel = 0;
    // Write selects --- check these
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
    S_done = 1'b1;
  end
//Like S5
  S22: begin
    dut_ready_sel         = 1'b0;
    get_dimensions = 0;
    //modified-no
    next_state = (all_element_read_completed == 2'b00) ? S23:S24;
    // Read address select
    read_addr_sel = 2'b11; // increment read address
    // Compute mac lines
    compute_mac = 2'b11; 
    accum_result = 0;
    final_result_sel = 0;
    // Write selects
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
    S_done = 1'b1;
  end
//Like S6
  S23: begin
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    next_state = (all_element_read_completed == 2'b00) ? S23:S24;
    // Read address select
    read_addr_sel = 2'b11; // increment read address
    // Compute mac lines
    compute_mac = 2'b11; 
    accum_result = mac_result_z;
    final_result_sel = 0;
    // Write selects ---???
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
    S_done = 1'b1;
  end

//Like S8
  S24: begin
    dut_ready_sel     = 1'b0;
    get_dimensions = 0;
    next_state = S25;
    // Read address select
    read_addr_sel = 2'b10; // Hold address
    // Compute mac lines
    // compute_mac = 2'b11; 
    final_result_sel = 1;
    compute_mac = 2'b00;
    accum_result = 0;
    // accum_result = mac_result_z;
    // Write selects
    write_result_enable_sel  = 1'b0; // enable write
    write_scratchpad_enable_sel  = 1'b0;
    S_done = 1'b1;
  end
//Like S9
  S25: begin
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    next_state = S26;
    // Read address select
    read_addr_sel = 2'b10; //Hold address
    final_result_sel = 0;
    compute_mac = 2'b00;
    accum_result = 0;
    write_result_enable_sel  = 1'b1; // enable write
    write_scratchpad_enable_sel  = 1'b0;
    S_done = 1'b1;
  end

  S26: begin
    dut_ready_sel             = 1'b0;
    get_dimensions = 0;
    next_state = (matrix_done==0) ? S20:S27;
    read_addr_sel = 2'b10; // Hold address
    // Compute mac lines
    compute_mac = 0; 
    accum_result = 0;
    // Write selects
    write_result_enable_sel  = 1'b0; // enable write
    write_scratchpad_enable_sel  = 1'b0;
    final_result_sel = 0;
    S_done = 1'b1;
  end

  // Done for now
  S27: begin
    dut_ready_sel             = 1'b1;    
    next_state = S0;
    read_addr_sel = 2'b00; 
    compute_mac = 0;
    accum_result= 0;
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
    get_dimensions = 0;
    final_result_sel = 0;
  end

default      :  begin
    dut_ready_sel       = 1'b1;     
    next_state      = S0;
    read_addr_sel = 2'b00; 
    get_dimensions = 0;
    compute_mac = 0;
    accum_result = 0;
    write_result_enable_sel  = 1'b0;
    write_scratchpad_enable_sel  = 1'b0;
    final_result_sel = 0;
    end

  endcase
end

// DUT ready handshake logic
always @(posedge clk) begin
  if(!reset_n) begin
    compute_complete <= 0;
  end else begin
    compute_complete <= (dut_ready_sel) ? 1'b1 : 1'b0;
  end
end
assign dut_ready = compute_complete;

// get dimensions logic
always @(posedge clk) begin
  if(!reset_n) begin
    matrix_a_rows <= 0;
    matrix_a_cols <= 0;
    matrix_b_rows <= 0;
    matrix_b_cols <= 0;
    matrix_c_rows <= 0;
    matrix_c_cols <= 0;
    matrix_transpose_b_cols <= 0;
    matrix_transpose_b_rows <= 0; 
  end else begin
    if(get_dimensions == 1'b1) begin
      matrix_a_rows <= tb__dut__sram_input_read_data[31:16];
      matrix_a_cols <= tb__dut__sram_input_read_data[15:0];
      matrix_b_rows <= tb__dut__sram_weight_read_data[31:16];
      matrix_b_cols <= tb__dut__sram_weight_read_data[15:0];
      matrix_c_rows <= matrix_a_rows;
      matrix_c_cols <= matrix_b_cols;
      matrix_transpose_b_cols <= matrix_a_rows;
      matrix_transpose_b_rows <= matrix_b_cols;
    end
    else begin
      matrix_a_rows <= matrix_a_rows;
      matrix_a_cols <= matrix_a_cols;
      matrix_b_rows <= matrix_b_rows;
      matrix_b_cols <= matrix_b_cols;
      matrix_c_rows <= matrix_c_rows;
      matrix_c_cols <= matrix_c_cols;
      matrix_transpose_b_cols <= matrix_a_rows;
      matrix_transpose_b_rows <= matrix_b_cols; 
    end
  end
end


// SRAM read address generator
always@(posedge clk) begin
  if(!reset_n) begin
    sram_input_read_address <= 12'b0;
    sram_weight_read_address <= 12'b0;
    all_element_read_completed <= 0;
    //Counters
    matrix_done <= 2'b00;
    C_row_counter <= 0;
    C_col_counter <= 0;
    matrix_a_cols_counter <= 0;
    matrix_b_rows_counter <= 0;
    matrix_a_rows_COUNTER <= 0;
    matrix_b_cols_COUNTER <= 0;
  end
  else begin
    if(read_addr_sel == 2'b00) begin // Initialize address
      sram_input_read_address <= 12'b0;
      sram_weight_read_address <= 12'b0;
      all_element_read_completed <= 0;
      //Counters
      matrix_done <= 2'b00;
      C_row_counter <= 0;
      C_col_counter <= 0;
      matrix_a_cols_counter <= 0;
      matrix_b_rows_counter <= 0;
      matrix_a_rows_COUNTER <= 0;
      matrix_b_cols_COUNTER <= 0;
    end
    else if (read_addr_sel == 2'b01) begin // Increment address
    //// Start of Matrix Multiplication Logic
    if(C_row_counter < matrix_c_rows) begin
        if(C_col_counter < matrix_c_cols) begin
          if(matrix_a_cols_counter < matrix_a_cols) begin
            all_element_read_completed <= 0;
            sram_input_read_address <= matrix_a_cols * matrix_a_rows_COUNTER + 1 + matrix_a_cols_counter;
            if(matrix_done == 2'b00) begin
              sram_weight_read_address <= matrix_b_rows * matrix_b_cols_COUNTER + 1 + matrix_b_rows_counter;
            end
            else if(matrix_done == 2'b01) begin
            // $display("I am in K read addr %d", current_state);
              sram_weight_read_address <= matrix_b_rows * matrix_b_cols_COUNTER + 1 + matrix_b_rows_counter + matrix_b_cols*matrix_b_rows;  
            end 
            else if(matrix_done == 2'b10) begin
              // $display("I am in V read addr %d", current_state);
              sram_weight_read_address <= matrix_b_rows * matrix_b_cols_COUNTER + 1 + matrix_b_rows_counter + 2*matrix_b_cols*matrix_b_rows;
            end
            //  $display("B addr: %b", sram_weight_read_address);
            matrix_a_cols_counter <= matrix_a_cols_counter + 1;
            matrix_b_rows_counter <= matrix_b_rows_counter + 1;
          end
          else begin 
            all_element_read_completed <= all_element_read_completed + 1;
            if(matrix_done == 2'b00) begin
              sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols; 
              sram_scratchpad_write_address <= C_col_counter + C_row_counter * matrix_c_cols; 
            end
            else if(matrix_done == 2'b01) begin
              sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols + matrix_b_cols*matrix_a_rows; 
              sram_scratchpad_write_address <= C_col_counter + C_row_counter * matrix_c_cols + matrix_b_cols*matrix_a_rows; 
            end
            else if(matrix_done == 2'b10) begin // if(matrix_done == 2'b10) 
              sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols + 2*matrix_b_cols*matrix_a_rows;
              sram_scratchpad_write_address <= C_col_counter + C_row_counter * matrix_c_cols + 2*matrix_b_cols*matrix_a_rows;
            end
              matrix_b_cols_COUNTER <= matrix_b_cols_COUNTER + 1;
              C_col_counter <= C_col_counter + 1;
          end
        end
        else begin
          all_element_read_completed <= all_element_read_completed + 1;
          
          if(matrix_done == 2'b00) begin
            sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols; 
            sram_scratchpad_write_address <= C_col_counter + C_row_counter * matrix_c_cols; 
          end
          else if(matrix_done == 2'b01) begin
            sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols + matrix_b_cols*matrix_a_rows; 
            sram_scratchpad_write_address <= C_col_counter + C_row_counter * matrix_c_cols + matrix_b_cols*matrix_a_rows;// - 1; 
          end
          else if(matrix_done == 2'b10) begin// if(matrix_done == 2'b10)
            sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols + 2*matrix_b_cols*matrix_a_rows;// - 1;
            sram_scratchpad_write_address <= C_col_counter + C_row_counter * matrix_c_cols + 2*matrix_b_cols*matrix_a_rows;// - 1;
          end

            matrix_a_rows_COUNTER <= matrix_a_rows_COUNTER + 1;  
            matrix_b_cols_COUNTER <= 0;
            C_col_counter <= 0;
            C_row_counter <= C_row_counter + 1;
        end
      end
      else begin
        all_element_read_completed <= 2'b01;
        matrix_done <= matrix_done + 1;
        if(matrix_done == 2'b00) begin
          sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols; 
          sram_scratchpad_write_address <= C_col_counter + C_row_counter * matrix_c_cols; 
        end
        else if(matrix_done == 2'b01) begin
          sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols + matrix_b_cols*matrix_a_rows; 
          sram_scratchpad_write_address <= C_col_counter + C_row_counter * matrix_c_cols + matrix_b_cols*matrix_a_rows; 
        end
        else begin // if(matrix_done == 2'b10)
          sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols + 2*matrix_b_cols*matrix_a_rows;
          sram_scratchpad_write_address <= C_col_counter + C_row_counter * matrix_c_cols + 2*matrix_b_cols*matrix_a_rows;
        end

        matrix_a_rows_COUNTER <= 0;  
        matrix_b_cols_COUNTER <= 0;
        C_col_counter <= 0;
        C_row_counter <= 0;
      end
    //// End of Matrix Multiplication Logic
    end
    else if (read_addr_sel == 2'b10) begin // Hold address
      sram_input_read_address <= sram_input_read_address;
      sram_weight_read_address <= sram_weight_read_address;

      all_element_read_completed <= 0;
      
      matrix_a_rows_COUNTER <= matrix_a_rows_COUNTER;  
      matrix_b_cols_COUNTER <= matrix_b_cols_COUNTER;
      C_col_counter <= C_col_counter;
      C_row_counter <= C_row_counter;
      matrix_a_cols_counter <= 0;
      matrix_b_rows_counter <= 0;
    end
    else if (read_addr_sel == 2'b11) begin // To read from Sratchpad SRAM

      if(S_done == 1'b0) begin
        if(C_row_counter < matrix_a_rows) begin
          if(C_col_counter < matrix_a_rows) begin
            if(matrix_a_cols_counter < matrix_b_cols) begin
              all_element_read_completed <= 0;
              sram_result_read_address <= matrix_b_cols * matrix_a_rows_COUNTER + matrix_a_cols_counter; // Reading Q from result SRAM
              
              sram_scratchpad_read_address <= matrix_transpose_b_rows * matrix_b_cols_COUNTER + matrix_b_rows_counter + matrix_b_cols*matrix_a_rows; // Reading K^T from scratchpad SRAM
              
              matrix_a_cols_counter <= matrix_a_cols_counter + 1;
              matrix_b_rows_counter <= matrix_b_rows_counter + 1;
            end
            else begin 
              all_element_read_completed <= all_element_read_completed + 1;
              sram_result_write_address <= C_col_counter + C_row_counter * matrix_a_rows + 3*matrix_b_cols*matrix_a_rows;
                matrix_a_cols_counter <= 0;
                matrix_b_rows_counter <= 0;
                matrix_b_cols_COUNTER <= matrix_b_cols_COUNTER + 1;
                C_col_counter <= C_col_counter + 1;
            end
          end
          else begin
            all_element_read_completed <= all_element_read_completed + 1;
            matrix_a_cols_counter <= 0;
            matrix_b_rows_counter <= 0;

            sram_result_write_address <= C_col_counter + C_row_counter * matrix_a_rows + 3*matrix_b_cols*matrix_a_rows - 1;

            matrix_a_rows_COUNTER <= matrix_a_rows_COUNTER + 1;  
            matrix_b_cols_COUNTER <= 0;
            C_col_counter <= 0;
            C_row_counter <= C_row_counter + 1;
          end
        end
        else begin
          all_element_read_completed <= 2'b01;
          matrix_done <= 2'b01;
          
          sram_result_write_address <= C_col_counter + C_row_counter * matrix_a_rows + 3*matrix_b_cols*matrix_a_rows;
          matrix_a_rows_COUNTER <= 0;  
          matrix_b_cols_COUNTER <= 0;
          C_col_counter <= 0;
          C_row_counter <= 0;

            matrix_a_cols_counter <= 0;
            matrix_b_rows_counter <= 0;
        end
      end // End of S_done
      // For Z calculation//////////
      else begin // S_done == 1'b1
      // For Z calculation//////////////
        if(C_row_counter < matrix_c_rows) begin
          if(C_col_counter < matrix_c_cols) begin
            if(matrix_a_cols_counter < matrix_a_rows) begin
              all_element_read_completed <= 0;
              sram_result_read_address <= matrix_a_rows * matrix_a_rows_COUNTER + matrix_a_cols_counter + 3*matrix_b_cols*matrix_a_rows; 
              //  $display("A addr: %b", sram_result_read_address);
              // sram_scratchpad_read_address <= matrix_a_rows * matrix_b_cols_COUNTER + matrix_b_rows_counter + 2*matrix_b_cols*matrix_a_rows;
              sram_scratchpad_read_address <= 1 * matrix_b_cols_COUNTER + matrix_b_rows_counter + 2*matrix_b_cols*matrix_a_rows;
              //  $display("B addr: %b", sram_scratchpad_read_address);
              matrix_a_cols_counter <= matrix_a_cols_counter + 1;
              matrix_b_rows_counter <= matrix_b_rows_counter + matrix_b_cols;
            end
            else begin
              all_element_read_completed <= 1;
              sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols + 3*matrix_b_cols*matrix_a_rows + matrix_a_rows*matrix_a_rows;
              matrix_a_cols_counter <= 0;
              matrix_b_rows_counter <= 0;
              matrix_b_cols_COUNTER <= matrix_b_cols_COUNTER + 1;
              C_col_counter <= C_col_counter + 1;
            end
          end
          else begin
            all_element_read_completed <= 1;
            sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols + 3*matrix_b_cols*matrix_a_rows + matrix_a_rows*matrix_a_rows - 1;
            matrix_a_cols_counter <= 0;
            matrix_b_rows_counter <= 0;
            matrix_a_rows_COUNTER <= matrix_a_rows_COUNTER + 1;  
            matrix_b_cols_COUNTER <= 0;
            C_col_counter <= 0;
            C_row_counter <= C_row_counter + 1;
          end
        end
        else begin
          all_element_read_completed <= 2'b01;
          matrix_done <= 1;
          sram_result_write_address <= C_col_counter + C_row_counter * matrix_c_cols + 3*matrix_b_cols*matrix_a_rows + matrix_a_rows*matrix_a_rows;
          matrix_a_rows_COUNTER <= 0;  
          matrix_b_cols_COUNTER <= 0;
          C_col_counter <= 0;
          C_row_counter <= 0;
        end
      end  
    end
  end
end
assign dut__tb__sram_input_read_address = sram_input_read_address;
assign dut__tb__sram_weight_read_address = sram_weight_read_address;
assign dut__tb__sram_scratchpad_read_address = sram_scratchpad_read_address;
assign dut__tb__sram_result_read_address = sram_result_read_address;


// Compute MAC logic 
always @(posedge clk) begin
  if(!reset_n) begin
    sram_input_read_data <= 0;
    sram_weight_read_data <= 0;
    sram_result_read_data <= 0;
    sram_scratchpad_read_data <= 0;
    mac_result_z <= 0;
  end else begin
    if (compute_mac == 2'b01) begin
      sram_input_read_data <= tb__dut__sram_input_read_data;
      sram_weight_read_data <= tb__dut__sram_weight_read_data;
      mac_result_z <= tb__dut__sram_input_read_data*tb__dut__sram_weight_read_data + accum_result;
    end
    else if (compute_mac == 2'b11) begin
      sram_result_read_data <= tb__dut__sram_result_read_data;
      sram_scratchpad_read_data <= tb__dut__sram_scratchpad_read_data;
      
      mac_result_z <= tb__dut__sram_scratchpad_read_data*tb__dut__sram_result_read_data + accum_result;
      // $display("Mac result is for addr %d is %d = %d*%d + %d, current_state=%d", sram_result_write_address, mac_result_z, tb__dut__sram_result_read_data, tb__dut__sram_scratchpad_read_data, accum_result, current_state);
    end
    else begin // (compute_mac == 2'b00) begin
      sram_input_read_data <= tb__dut__sram_input_read_data; //tb__dut__sram_input_read_data;
      sram_weight_read_data <= tb__dut__sram_weight_read_data; //tb__dut__sram_input_read_data;
      sram_result_read_data <= tb__dut__sram_result_read_data;
      sram_scratchpad_read_data <= tb__dut__sram_scratchpad_read_data;
      mac_result_z <= mac_result_z;
    end
  end
end

// result SRAM write enable logic
always @(posedge clk) begin
  if(!reset_n) begin
    sram_write_enable_r <= 1'b0;
  end else begin
    sram_write_enable_r <= write_result_enable_sel ? 1'b1 : 1'b0;
  end
end
assign sram_result_write_enable = sram_write_enable_r;
assign dut__tb__sram_result_write_enable = sram_result_write_enable;

// Scratchpad SRAM write enable logic
always @(posedge clk) begin
  if(!reset_n) begin
    sram_write_enable_s <= 1'b0;
  end else begin
    sram_write_enable_s <= write_scratchpad_enable_sel ? 1'b1 : 1'b0;
  end
end
assign sram_scratchpad_write_enable = sram_write_enable_s;
assign dut__tb__sram_scratchpad_write_enable = sram_scratchpad_write_enable;

//Store mac_result in final_result
always @(posedge clk) begin
  if(!reset_n) begin
    final_result <= 0;
  end
  else begin
    if(final_result_sel)
      final_result <= mac_result_z;
    else
      final_result <= final_result;
  end
end

// Write data logic
always @(posedge clk) begin
  if(!reset_n) begin
    sram_result_write_data <= 0;
    sram_scratchpad_write_data <= 0;
  end
  else begin
    if(write_result_enable_sel == 1'b1) begin
      sram_result_write_data <= mac_result_z; //mac_result
    end
    else
      sram_result_write_data <= final_result;

    if(write_scratchpad_enable_sel == 1'b1) begin
      sram_scratchpad_write_data <= mac_result_z;
    end
    else
      sram_scratchpad_write_data <= sram_scratchpad_write_data;
  end
end
assign dut__tb__sram_result_write_address = sram_result_write_address;
assign dut__tb__sram_scratchpad_write_address = sram_scratchpad_write_address;
assign dut__tb__sram_result_write_data = sram_result_write_data;
assign dut__tb__sram_scratchpad_write_data = sram_scratchpad_write_data;

endmodule

