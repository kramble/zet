/*
 *  Wishbone Compatible BIOS ROM core using megafunction ROM
 *  Copyright (C) 2010  Donna Polehn <dpolehn@verizon.net>
 *
 *  This file is part of the Zet processor. This processor is free
 *  hardware; you can redistribute it and/or modify it under the terms of
 *  the GNU General Public License as published by the Free Software
 *  Foundation; either version 3, or (at your option) any later version.
 *
 *  Zet is distrubuted in the hope that it will be useful, but WITHOUT
 *  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 *  or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
 *  License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Zet; see the file COPYING. If not, see
 *  <http://www.gnu.org/licenses/>.
 */

// The following is to get rid of the warning about not initializing the ROM
// altera message_off 10030

// nano - this is now a RAM but written to only by the console vw interface
// we still initialize to the bootrom contents so it's usable without the console
// (once I modify the flash interface)

module nano_bootrom (
    input clk,
    input rst,
	
	// console vw interface
	input  [31:0] vw_console_data,

    // Wishbone slave interface
    input  [15:0] wb_dat_i,
    output [15:0] wb_dat_o,
    input  [19:1] wb_adr_i,
    input         wb_we_i,
    input         wb_tga_i,
    input         wb_stb_i,
    input         wb_cyc_i,
    input  [ 1:0] wb_sel_i,
    output        wb_ack_o
  );

  // Net declarations
  reg  [15:0] rom[0:127];  // Instantiate the ROM

  wire [ 6:0] rom_addr;
  wire        stb;

  // Combinatorial logic
  assign rom_addr = wb_adr_i[7:1];
  assign stb      = wb_stb_i & wb_cyc_i;
  assign wb_ack_o = stb;
  assign wb_dat_o = rom[rom_addr];

  initial $readmemh("bootnano.dat", rom);

  // console vw interface to write rom contents
  // TODO use separate channel coded in this file, but for now using ZETC from top module
  
  // vw_console_data is 4 bytes as follows
  wire [7:0] vw_control = vw_console_data[31:24];
  wire [7:0] vw_addr = vw_console_data[23:16];		// NB word addressing 0..127
  wire [15:0] vw_data = vw_console_data[15:0];
  
  wire vw_control_we = vw_control[0];			// Write flag, we write on positive edge
  reg [1:0] vw_control_we_d = 0;				// Synchronization to avoid race and detect edge

  always @ (posedge clk)
  begin
    vw_control_we_d[1:0] <= { vw_control_we_d[0], vw_control_we };
	if (vw_control_we_d[0] && ~vw_control_we_d[1])
		rom[vw_addr] <= vw_data[15:0];		// NB instantiates dual ported ram
  end

endmodule
