// hvsync_generator.v

// ACKNOWLEDGEMENT (Zet):
// Based on http://fpga4fun.com (hvsync_generator.v)
// (c) fpga4fun.com

// nano modified to use 12.5MHz clk (fpga4fun used 25MHz)

module hvsync_generator(clk, vga_h_sync, vga_v_sync, inDisplayArea, CounterX, CounterY);
input clk;
output vga_h_sync, vga_v_sync;
output inDisplayArea;
output [9:0] CounterX;
output [8:0] CounterY;

//////////////////////////////////////////////////
reg [9:0] CounterX = 0;
reg [8:0] CounterY = 0;
// wire CounterXmaxed = (CounterX==10'h2FF);		// 25MHz
wire CounterXmaxed = (CounterX==10'h17F);			// 12.5MHz

always @(posedge clk)
if(CounterXmaxed)
	CounterX <= 0;
else
	CounterX <= CounterX + 10'd1;

always @(posedge clk)
if(CounterXmaxed) CounterY <= CounterY + 9'd1;

reg	vga_HS = 0, vga_VS = 0;
always @(posedge clk)
begin
	// change this value to move the display horizontally
	// vga_HS <= (CounterX[9:4]==6'h2D);	// 25MHz
		
	// 12.5Mhz (NB also sync pulse is doubled in length cf 25Mhz
	// since determined by count of low 4 bits of CounterX)
	// vga_HS <= (CounterX[9:4]==6'h16);	// works but first few pixels of line are off screen
	vga_HS <= (CounterX[9:3]==7'b0101011) || (CounterX[9:3]==7'b0101100);	// this is better
	
	vga_VS <= (CounterY==500); // change this value to move the display vertically
end

reg inDisplayArea = 0;
always @(posedge clk)
if(inDisplayArea==0)
	inDisplayArea <= (CounterXmaxed) && (CounterY<480);
else
	inDisplayArea <= !(CounterX==639);
	
assign vga_h_sync = ~vga_HS;
assign vga_v_sync = ~vga_VS;

endmodule
