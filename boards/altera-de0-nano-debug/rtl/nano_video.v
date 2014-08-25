// nano_video.v - simple VGA driver

// ACKNOWLEDGEMENT (Zet):
// Based on http://fpga4fun.com (pong.v)
// (c) fpga4fun.com

module nano_video(clk, vga_h_sync, vga_v_sync, vga_R, vga_G, vga_B, outstr);
input clk;
output vga_h_sync, vga_v_sync, vga_R, vga_G, vga_B;
input [127:0] outstr;		// 16 byte ASCII string

wire inDisplayArea;
wire [9:0] CounterX;
wire [8:0] CounterY;

hvsync_generator syncgen(.clk(clk), .vga_h_sync(vga_h_sync), .vga_v_sync(vga_v_sync), 
  .inDisplayArea(inDisplayArea), .CounterX(CounterX), .CounterY(CounterY));

// Simple character generator

wire [8:0] line = CounterY;
wire [8:0] invline = 9'd480 - line;		// Invert line coords so 0 is at bottom of screen
wire [4:0] row = invline[8:5];			// then divide by 16
wire [6:0] col = CounterX[9:3];

wire [11:0] charaddr;		// Top 8 bits is ASCII code, lower 4 is character line (a nibble to make ROM coding easier)
wire [7:0] charbits;

// Quick HACK, just display first 16 chars,
wire [7:0] charbyte =	col== 0 ? outstr[127:120] : col== 1 ? outstr[119:112] : col== 2 ? outstr[111:104] : col== 3 ? outstr[103:96] :
						col== 4 ? outstr[95:88] : col== 5 ? outstr[87:80] : col== 6 ? outstr[79:72] : col== 7 ? outstr[71:64] :
						col== 8 ? outstr[63:56] : col== 9 ? outstr[55:48] : col==10 ? outstr[47:40] : col==11 ? outstr[39:32] :
						col==12 ? outstr[31:24] : col==13 ? outstr[23:16] : col==14 ? outstr[15: 8] : col==15 ? outstr[ 7: 0] :
						8'h20;	// default (space char)
	
assign charaddr = { charbyte, line[4:1] };

vdu_char_rom char_rom (		// Use the Zet vdu character rom. Amazingly the address format is identical to my earier code,
							// except that the data bits are reversed and rotated by one (easily fixed in multiplexer below)
    .clk(clk),
    .addr(charaddr),
    .q(charbits)
  );

reg textbit;

always @(*)		// Multiplexer
begin
	case (CounterX[2:0])
		// The data bits are slightly mangled
		// Expected this...
	/*	7 : textbit = charbits[0];
		6 : textbit = charbits[1];
		5 : textbit = charbits[2];
		4 : textbit = charbits[3];
		3 : textbit = charbits[4];
		2 : textbit = charbits[5];
		1 : textbit = charbits[6];
		default: textbit = charbits[7]; */
		
		// Actually need to rotate by one...
		7 : textbit = charbits[1];
		6 : textbit = charbits[2];
		5 : textbit = charbits[3];
		4 : textbit = charbits[4];
		3 : textbit = charbits[5];
		2 : textbit = charbits[6];
		1 : textbit = charbits[7];
		default: textbit = charbits[0];
	endcase
end

wire B = (	((CounterX[3] ^ CounterY[3]) && (CounterX[2:0] == 0) && (CounterY[2:0] == 0) && (row > 0))	// Grid of dots
			|| (textbit && !(row > 0)) );																// Text
wire G = textbit && !(row > 0);
wire R = textbit && !(row > 0);

// Output blanking (required for TV PAL, not sure about VGA)
    
reg vga_R, vga_G, vga_B;
always @(posedge clk)
begin
	vga_R <= R & inDisplayArea;
	vga_G <= G & inDisplayArea;
	vga_B <= B & inDisplayArea;
end

endmodule