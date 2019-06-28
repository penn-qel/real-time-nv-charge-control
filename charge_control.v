
`timescale 1 ns / 1 ps

module charge_control #
(
		// Define the portss here
    input wire  S_AXI_ACLK,// Global Clock Signal
    input [13:0] signal_in, // read in control lines form the AWG
    output reg [14:0] awg_out, // output lines for the event trigger and recording data
        		
		
                
    // Create some internal registers for keeping track of stuff
    reg[31:0] threshold_0, threshold_1;
    reg[8:0] counts, seq_pos;
    reg count_on_flag;
    reg count_reset;
    reg was_counting;
      
    // Initialize the registers at start up  
    initial begin
          awg_out <= 15'b0;

          counts <= 8'b0;
          seq_pos <= 8'b0;
          count_on_flag <= 0;
          was_counting <= 0;
          threshold_0 <= 32'b1;
          threshold_1 <= 32'b10;
          threshold_0 <= signal_in[8:7];
          threshold_1 <= signal_in[10:8];

          end
              // Some look up tables for keeping track of bits and their purpose
              //
              // signal_in[0] is the enable signal
              // signal_in[1] is the reset signal
              // signal_in[2] is the count_on signal
              // signal_in[3] is the photon count signal line
              // signal_in[5:4] are the routine bits in bit1/bit0. 00 - dynamic stop, 11 - wait until falling edge of count_on
              // signal_in[6] is the sequence line count signal
              // signal_in[8:7] are the threshold_0 bits bit1/bit0
              // signal_in[10:9] are the threshold_1 bits bit1/bit0

              //awg_out[0] output for counting begins
              //awg_out[1] is for counting finished 
              //awg_out[2] is if threshold reached
              //awg_out[7:3] is for output of counts
              //awg_out[12:8] is for the sequence position (32 lines supported)
              
              
	// ****Control Module****
	//
	// control status is updated every global clock cycle
	always @(posedge S_AXI_ACLK) begin

		// Enter the active loop    
		if(signal_in[0]) begin
			//enable signal turned on start updating controls

			threshold_0 <= signal_in[8:7];
			threshold_1 <= signal_in[10:9];

			// count_on enabled. FPGA should start counting
			if(signal_in[2]) begin
				was_counting <= 1;
				count_on_flag <= 1;

				// Continuously update the output register with the number of counts
				// The DAQ won't sample these until the measurement has completed
				awg_out[8:3] <= counts[5:0]; // Update the output count register with the value
				awg_out[14:9] <= seq_pos[5:0]; // Update the current measured sequence position

			// Check to see if the counts have exceeded the specificed threshold and
			// we are supposed to be initializing.
			// If so, trigger the AWG on the specified output line.
			if(counts >= threshold_0 && !signal_in[4] && !signal_in[5]) begin
				awg_out[2] <= 1; // Trigger the AWG
			end 
			end
		end    


		// Reset signal detected
		if(signal_in[1]) begin 
			awg_out <= 15'b0;
			count_on_flag <= 0;
		end

	  end  

	// ****Photon Counting Module****
	always @(posedge signal_in[3] or posedge signal_in[1]) begin

		// the reset of the counter must occur in the module
		if(signal_in[1]) begin //count reset
			counts <= 8'b0;
		end    

		// If the control flags sigal counting, increment on every positive edge
		else if(signal_in[0] && signal_in[2]) begin
		    counts <= counts + 1;
		 end
	end 
                
	// ****Sequence Line Counting Module****
	always @(posedge signal_in[6] or posedge signal_in[1]) begin

		// the reset of the counter must occur in the module
		if(signal_in[1]) begin //count reset
			seq_pos <= 8'b0;
		end 

		// If the control flags sigal counting, increment on every positive edge
		else if(signal_in[0] && !signal_in[2]) begin
			seq_pos <= seq_pos + 1;
		end
	end
endmodule
