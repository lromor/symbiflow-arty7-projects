module top (
            input [3:0]  sw,
            output [3:0] green_leds
            );

   assign green_leds = sw;

   //(* KEEP, DONT_TOUCH *)
   //LUT2 #( .INIT(3'b010) ) lut ( .O(green_leds));
endmodule
