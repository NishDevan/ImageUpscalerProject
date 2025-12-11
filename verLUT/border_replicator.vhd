-- Border Replicator (VHDL-93)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.img_types.all;

entity border_replicator is
    generic(
        IMG_WIDTH  : natural := 100;
        IMG_HEIGHT : natural := 100;
        BORDER_SZ  : natural := 3
    );
    port(
        clk         : in std_logic;
        rst_n       : in std_logic;
        trigger     : in std_logic;
        src_img     : in img_buffer(0 to IMG_WIDTH-1, 0 to IMG_HEIGHT-1);
        bordered_img: out img_buffer(0 to IMG_WIDTH+2*BORDER_SZ-1, 0 to IMG_HEIGHT+2*BORDER_SZ-1);
        complete    : out std_logic
    );
end entity border_replicator;

architecture behavioral of border_replicator is
    type replication_state is (WAIT_TRIGGER, COPY_CENTER, REPLICATE_BORDERS, FINISH);
    signal current_state : replication_state;
    signal output_buffer : img_buffer(0 to IMG_WIDTH+2*BORDER_SZ-1, 0 to IMG_HEIGHT+2*BORDER_SZ-1);
begin
    replication_proc: process(clk, rst_n)
        variable row, col : integer;
    begin
        if rst_n = '0' then
            current_state <= WAIT_TRIGGER;
            complete <= '0';
        elsif rising_edge(clk) then
            case current_state is
                when WAIT_TRIGGER =>
                    complete <= '0';
                    if trigger = '1' then
                        current_state <= COPY_CENTER;
                    end if;
                when COPY_CENTER =>
                    for row in 0 to IMG_HEIGHT-1 loop
                        for col in 0 to IMG_WIDTH-1 loop
                            output_buffer(row+BORDER_SZ, col+BORDER_SZ) <= src_img(row, col);
                        end loop;
                    end loop;
                    current_state <= REPLICATE_BORDERS;
                when REPLICATE_BORDERS =>
                    for col in 0 to IMG_WIDTH-1 loop
                        for row in 0 to BORDER_SZ-1 loop
                            output_buffer(row, col+BORDER_SZ) <= src_img(0, col);
                            output_buffer(IMG_HEIGHT+BORDER_SZ+row, col+BORDER_SZ) <= src_img(IMG_HEIGHT-1, col);
                        end loop;
                    end loop;
                    for row in 0 to IMG_HEIGHT-1 loop
                        for col in 0 to BORDER_SZ-1 loop
                            output_buffer(row+BORDER_SZ, col) <= src_img(row, 0);
                            output_buffer(row+BORDER_SZ, IMG_WIDTH+BORDER_SZ+col) <= src_img(row, IMG_WIDTH-1);
                        end loop;
                    end loop;
                    for row in 0 to BORDER_SZ-1 loop
                        for col in 0 to BORDER_SZ-1 loop
                            output_buffer(row, col) <= src_img(0, 0);
                            output_buffer(row, IMG_WIDTH+BORDER_SZ+col) <= src_img(0, IMG_WIDTH-1);
                            output_buffer(IMG_HEIGHT+BORDER_SZ+row, col) <= src_img(IMG_HEIGHT-1, 0);
                            output_buffer(IMG_HEIGHT+BORDER_SZ+row, IMG_WIDTH+BORDER_SZ+col) <= src_img(IMG_HEIGHT-1, IMG_WIDTH-1);
                        end loop;
                    end loop;
                    bordered_img <= output_buffer;
                    complete <= '1';
                    current_state <= FINISH;
                when FINISH =>
                    current_state <= WAIT_TRIGGER;
            end case;
        end if;
    end process replication_proc;
end architecture behavioral;
