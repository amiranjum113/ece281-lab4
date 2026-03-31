library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_basys3 is
    port(
        clk     : in std_logic;
        sw      : in std_logic_vector(15 downto 0);
        btnU    : in std_logic; -- master reset
        btnL    : in std_logic; -- display reset
        btnR    : in std_logic;

        led : out std_logic_vector(15 downto 0);
        seg : out std_logic_vector(6 downto 0);
        an  : out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is

    signal slow_clk    : std_logic; -- 2Hz clock for elevator logic
    signal display_clk : std_logic; -- Fast clock for TDM switching
    signal floor1      : std_logic_vector(3 downto 0);
    signal floor2      : std_logic_vector(3 downto 0);
    signal tdm_data    : std_logic_vector(3 downto 0);
    signal tdm_sel     : std_logic_vector(3 downto 0);

    -- Components remain the same as original
    component sevenseg_decoder is
        port (
            i_Hex   : in  STD_LOGIC_VECTOR (3 downto 0);
            o_seg_n : out STD_LOGIC_VECTOR (6 downto 0)
        );
    end component;

    component elevator_controller_fsm is
        Port (
            i_clk        : in  STD_LOGIC;
            i_reset      : in  STD_LOGIC;
            is_stopped   : in  STD_LOGIC;
            go_up_down   : in  STD_LOGIC;
            o_floor      : out STD_LOGIC_VECTOR (3 downto 0)
        );
    end component;

    component TDM4 is
        generic ( constant k_WIDTH : natural := 4 );
        Port (
            i_clk   : in  STD_LOGIC;
            i_reset : in  STD_LOGIC;
            i_D3    : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D2    : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D1    : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D0    : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            o_data  : out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            o_sel   : out STD_LOGIC_VECTOR (3 downto 0)
        );
    end component;

    component clock_divider is
        generic ( constant k_DIV : natural := 25000000 );
        port (
            i_clk   : in std_logic;
            i_reset : in std_logic;
            o_clk   : out std_logic
        );
    end component;

begin

    -- 1. Elevator Clock: 0.5s update rate (2Hz)
    clkdiv_elev_inst : clock_divider
        generic map (k_DIV => 25000000) 
        port map(
            i_clk   => clk,
            i_reset => btnU,
            o_clk   => slow_clk
        );

    -- 2. TDM Clock: Fast enough to avoid flickering (4 millisec per digit with 4 digits displayed total)
    clkdiv_tdm_inst : clock_divider
        generic map (k_DIV => 400000) 
        port map(
            i_clk   => clk,
            i_reset => btnU,
            o_clk   => display_clk
        );

    -- Elevator FSM 1 (Uses 0.5s clock)
    elev1_inst : elevator_controller_fsm
        port map(
            i_clk      => slow_clk,
            i_reset    => btnU,
            is_stopped => sw(0),
            go_up_down => sw(1),
            o_floor    => floor1
        );

    -- Elevator FSM 2 (Uses 0.5s clock)
    elev2_inst : elevator_controller_fsm
        port map(
            i_clk      => slow_clk,
            i_reset    => btnU,
            is_stopped => sw(14),
            go_up_down => sw(15),
            o_floor    => floor2
        );

    -- TDM Display Controller (Must use display_clk, NOT slow_clk)
    tdm_inst : TDM4
        port map(
            i_clk   => display_clk,
            i_reset => btnL,
            i_D3    => x"F",  -- Leftmost (Anode 3)
            i_D2    => floor2,  -- Second from Left (Anode 2)
            i_D1    => x"F",  -- Second from Right (Anode 1)
            i_D0    => floor1,  -- Rightmost (Anode 0)
            o_data  => tdm_data,
            o_sel   => tdm_sel
        );

    seg_decoder_inst : sevenseg_decoder
        port map(
            i_Hex   => tdm_data,
            o_seg_n => seg
        );

    an <= tdm_sel;

    -- LEDs for debugging
    led(15) <= slow_clk;
    led(0)  <= sw(0);
    led(14) <= sw(14);

end top_basys3_arch;