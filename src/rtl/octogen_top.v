// src/rtl/octogen_top.v
module octogen_top (
    input  wire clk,
    input  wire rst_n
    // TODO: add ADC / Ethernet / debug I/O later
);

  // Example pipeline instance
  my_pipeline u_pipeline (
    .clk   (clk),
    .rst_n (rst_n)
  );

endmodule