-- Testbench
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.img_types.all;
use std.textio.all;
use std.env.finish;

entity tb_lanczos3_scaler is
end entity tb_lanczos3_scaler;

architecture sim of tb_lanczos3_scaler is
    type bmp_header is array(0 to 53) of character;
    constant IMG_W : natural := 50;
    constant IMG_H : natural := 50;
    constant SCALE : natural := 4;
    constant CLK_T : time := 100 ps;
    signal clock, reset_n, start_proc, end_proc : std_logic;
    signal input_img : img_buffer(0 to IMG_W-1, 0 to IMG_H-1);
    signal output_img : img_buffer(0 to IMG_W*SCALE-1, 0 to IMG_H*SCALE-1);
    signal status : std_logic_vector(1 downto 0);
    signal proc_done, sys_ready : std_logic;
    signal header_sig : bmp_header;
begin
    DUT: entity work.lanczos3_scaler
        generic map(WIDTH => IMG_W, HEIGHT => IMG_H, SCALE => SCALE)
        port map(clock => clock, reset_n => reset_n, start_proc => start_proc, end_proc => end_proc,
                 input_img => input_img, output_img => output_img,
                 status => status, proc_done => proc_done, sys_ready => sys_ready);

    clk_gen: process
    begin
        clock <= '0'; wait for CLK_T/2; clock <= '1'; wait for CLK_T/2;
    end process clk_gen;

    test_seq: process
        type bmp_file_t is file of character;
        file input_bmp : bmp_file_t open read_mode is "test.bmp";
        file output_bmp : bmp_file_t open write_mode is "out.bmp";
        variable hdr : bmp_header;
        variable ch : character;
        variable idx, w_in, h_in, w_out, h_out, pad_in, pad_out, fsize, imgsize : integer;
    begin
        wait for CLK_T*3;
        end_proc <= '0'; start_proc <= '0'; reset_n <= '0';
        wait for CLK_T*3; reset_n <= '1'; wait for CLK_T*3;

        idx := 0;
        while idx < 54 loop read(input_bmp, hdr(idx)); idx := idx+1; end loop;
        header_sig <= hdr;
        assert hdr(0)='B' and hdr(1)='M' report "Invalid BMP" severity failure;

        w_in := character'pos(hdr(18)) + character'pos(hdr(19))*256 + 
                character'pos(hdr(20))*65536 + character'pos(hdr(21))*16777216;
        h_in := character'pos(hdr(22)) + character'pos(hdr(23))*256 + 
                character'pos(hdr(24))*65536 + character'pos(hdr(25))*16777216;
        report "Input: " & integer'image(w_in) & "x" & integer'image(h_in);

        w_out := IMG_W*SCALE; h_out := IMG_H*SCALE;
        report "Output: " & integer'image(w_out) & "x" & integer'image(h_out);

        hdr(18) := character'val(w_out mod 256);
        hdr(19) := character'val((w_out/256) mod 256);
        hdr(20) := character'val((w_out/65536) mod 256);
        hdr(21) := character'val(w_out/16777216);
        hdr(22) := character'val(h_out mod 256);
        hdr(23) := character'val((h_out/256) mod 256);
        hdr(24) := character'val((h_out/65536) mod 256);
        hdr(25) := character'val(h_out/16777216);

        pad_out := (4 - (w_out*3) mod 4) mod 4;
        imgsize := (w_out*3 + pad_out)*h_out;
        hdr(34) := character'val(imgsize mod 256);
        hdr(35) := character'val((imgsize/256) mod 256);
        hdr(36) := character'val((imgsize/65536) mod 256);
        hdr(37) := character'val(imgsize/16777216);
        fsize := 54 + imgsize;
        hdr(2) := character'val(fsize mod 256);
        hdr(3) := character'val((fsize/256) mod 256);
        hdr(4) := character'val((fsize/65536) mod 256);
        hdr(5) := character'val(fsize/16777216);

        pad_in := (4 - IMG_W*3 mod 4) mod 4;
        reset_n <= '0'; wait for CLK_T; reset_n <= '1'; wait for CLK_T;
        assert sys_ready='1' report "System not ready!" severity failure;
        wait for CLK_T;

        for row in 0 to IMG_H-1 loop
            for col in 0 to IMG_W-1 loop
                read(input_bmp, ch);
                input_img(IMG_H-1-row, col).b <= to_integer(to_unsigned(character'pos(ch), 8));
                read(input_bmp, ch);
                input_img(IMG_H-1-row, col).g <= to_integer(to_unsigned(character'pos(ch), 8));
                read(input_bmp, ch);
                input_img(IMG_H-1-row, col).r <= to_integer(to_unsigned(character'pos(ch), 8));
            end loop;
            for idx in 1 to pad_in loop read(input_bmp, ch); end loop;
        end loop;

        start_proc <= '1'; wait for CLK_T; start_proc <= '0'; wait for CLK_T;
        wait until status = "10"; wait for CLK_T*2;
        assert proc_done='1' report "Processing incomplete!" severity error;
        wait for CLK_T;

        report "Writing output...";
        for idx in 0 to 53 loop write(output_bmp, hdr(idx)); end loop;

        for row in 0 to h_out-1 loop
            for col in 0 to w_out-1 loop
                write(output_bmp, character'val(output_img(h_out-1-row, col).b));
                write(output_bmp, character'val(output_img(h_out-1-row, col).g));
                write(output_bmp, character'val(output_img(h_out-1-row, col).r));
            end loop;
            for idx in 1 to pad_out loop write(output_bmp, character'val(0)); end loop;
        end loop;

        file_close(input_bmp); file_close(output_bmp);
        report "Complete!";
        finish;
    end process test_seq;
end architecture sim;
