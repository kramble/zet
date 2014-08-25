/*
 *  Wishbone Flash RAM core for Altera DE2 board (90ns registered)
 *  Copyright (c) 2009  Zeus Gomez Marmolejo <zeus@opencores.org>
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

// in nano the flash module is repurposed for Virtual Wire (vw) bulk loading

module nano_flash (
    // Wishbone slave interface
    input             wb_clk_i,
    input             wb_rst_i,
    input      [15:0] wb_dat_i,
    output reg [15:0] wb_dat_o,
    input             wb_we_i,
    input             wb_adr_i,
    input      [ 1:0] wb_sel_i,
    input             wb_stb_i,
    input             wb_cyc_i,
    output reg        wb_ack_o,

	input     [255:0] vw_bulkdata_in,	// AltSourceProbe data
	output     [31:0] vw_bulkaddr_out,	// AltSourceProbe address

    // Pad signals						// not used in nano (TODO remove)
    output reg [22:0] flash_addr_,
    input      [ 7:0] flash_data_,
    output            flash_we_n_,
    output reg        flash_oe_n_,
    output reg        flash_ce_n_,
    output            flash_rst_n_
  );

  // Registers and nets
  wire        op;
  wire        wr_command;
  reg  [31:0] address = 0;

  wire        word;
  reg  [ 3:0] st = 0;					// overkill, TODO simplify (original implements word/byte logic)

  // nano bulk loader
  reg  [ 1:0] bulk_strobeA = 0;
  reg  [ 1:0] bulk_strobeB = 0;
  reg [255:0] bulk_data = 0;			// Init as empty
  assign vw_bulkaddr_out = address;
  
  // in original flash8_r2 we have four ports 0x0238 - 0x023b
  // two are writable (address low, high)
  // two are readable for byte or word access, in nano we just ignore the distinction and return word always
  
  // Combinatorial logic
  assign op      = wb_stb_i & wb_cyc_i;
  assign word    = wb_sel_i==2'b11;

  assign flash_rst_n_ = 1'b1;
  assign flash_we_n_  = 1'b1;

  assign wr_command  = op & wb_we_i;  // Wishbone write access Signal

  // Behaviour

  // wb_dat_o
  always @(posedge wb_clk_i)
    wb_dat_o <= wb_rst_i ? 16'h0
	// no longer use sel so same data is on both ports
      : (st[2] ? ( { 3'd0, bulk_data[252:248], bulk_data[7:0] } )	// count + one byte of data
               : wb_dat_o);

  // wb_ack_o
  always @(posedge wb_clk_i)
    wb_ack_o <= wb_rst_i ? 1'b0
      : (wb_ack_o ? 1'b0 : (op & (wb_we_i ? 1'b1 : st[2])));

  // st - state
  always @(posedge wb_clk_i)
    st <= wb_rst_i ? 4'h0
      : (op & !wb_we_i & st==4'h0 ? (word ? 4'b0001 : 4'b0100)		// NB no state change on write (else get rogue count increment)
                         : { st[2:0], 1'b0 });

  // --------------------------------------------------------------------
  // Register addresses and defaults
  // --------------------------------------------------------------------

  `define FLASH_ALO   1'h0    // Lower 16 bits of address lines
  `define FLASH_AHI   1'h1    // Upper  6 bits of address lines
  always @(posedge wb_clk_i)  // Synchrounous
    if(wb_rst_i)
      address <= 32'h00000000;  // Interupt Enable default
    else
      if(wr_command)          // If a write was requested
        case(wb_adr_i)        // Determine which register was written to
            `FLASH_ALO: address[15: 0] <= wb_dat_i;
            `FLASH_AHI: address[31:16] <= wb_dat_i;
            default:    ;     // Default
        endcase               // End of case

  // nano bulk loader (see console.tcl for comments)
  always @(posedge wb_clk_i)
  begin
	// NB Provided bulk_data is empty (count==0) there is no race between loading new data and reading it,
	//    since the console loader is much slower than the CPU, this will always be the case
    bulk_strobeA <= { bulk_strobeA[0] , vw_bulkdata_in[255] };		// sync to clock domain
    bulk_strobeB <= { bulk_strobeB[0] , vw_bulkdata_in[254] };

	if (wb_rst_i)
		bulk_data[255:248] <= 0;									// clear count on reset

	// Dual strobes double the data rate compared with a single strobe (they alternate)
	// NB This is backwards-compatible with single-strobe bulk data
	else if ((~bulk_strobeA[1] && bulk_strobeA[0]) || (~bulk_strobeB[1] && bulk_strobeB[0]))
		bulk_data <= vw_bulkdata_in;						// load bulk_data on strobe (this also sync's to clock domain)
	else if (st[2] && (bulk_data[252:248] != 0))			// decrement and shift on each read unless count is zero
	begin
		bulk_data[252:248] <= bulk_data[252:248] - 5'd1;	// decrement count
		bulk_data[247:0] <= { 8'd0, bulk_data[247:8] };		// shift data msb->lsb
	end
	
  end
	
endmodule
