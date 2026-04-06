library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fft_wrapper is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;  -- active-high synchronous reset

        ----------------------------------------------------------------
        -- Valid-only upstream interface (from dispersion compensation)
        ----------------------------------------------------------------
        in_real         : in  signed(31 downto 0);
        in_imag         : in  signed(31 downto 0);
        in_valid        : in  std_logic;
        start_of_ascan  : in  std_logic;
        end_of_ascan    : in  std_logic;

        ----------------------------------------------------------------
        -- Valid-only downstream interface (to magnitude-squared block)
        ----------------------------------------------------------------
        out_real            : out signed(31 downto 0);
        out_imag            : out signed(31 downto 0);
        out_valid           : out std_logic;
        start_of_ascan_out  : out std_logic;

        ----------------------------------------------------------------
        -- Debug outputs from FFT IP
        ----------------------------------------------------------------
        dbg_event_frame_started         : out std_logic;
        dbg_event_tlast_unexpected      : out std_logic;
        dbg_event_tlast_missing         : out std_logic;
        dbg_event_status_channel_halt   : out std_logic;
        dbg_event_data_in_channel_halt  : out std_logic;
        dbg_event_data_out_channel_halt : out std_logic;
        dbg_cfg_done : out std_logic;

        ----------------------------------------------------------------
        -- Debug: asserted if upstream presented valid data while FFT
        -- input was not ready. This should NEVER happen in your intended
        -- operating mode.
        ----------------------------------------------------------------
        dbg_input_backpressure_violation : out std_logic
    );
end entity fft_wrapper;

architecture rtl of fft_wrapper is

    component xfft_0
        port (
            aclk                        : in  std_logic;
            aresetn                     : in  std_logic;

            s_axis_config_tdata         : in  std_logic_vector(15 downto 0);
            s_axis_config_tvalid        : in  std_logic;
            s_axis_config_tready        : out std_logic;

            s_axis_data_tdata           : in  std_logic_vector(63 downto 0);
            s_axis_data_tvalid          : in  std_logic;
            s_axis_data_tready          : out std_logic;
            s_axis_data_tlast           : in  std_logic;

            m_axis_data_tdata           : out std_logic_vector(63 downto 0);
            m_axis_data_tvalid          : out std_logic;
            m_axis_data_tready          : in  std_logic;
            m_axis_data_tlast           : out std_logic;

            event_frame_started         : out std_logic;
            event_tlast_unexpected      : out std_logic;
            event_tlast_missing         : out std_logic;
            event_status_channel_halt   : out std_logic;
            event_data_in_channel_halt  : out std_logic;
            event_data_out_channel_halt : out std_logic
        );
    end component;

    --------------------------------------------------------------------
    -- Config channel
    --------------------------------------------------------------------
    signal s_cfg_tdata   : std_logic_vector(15 downto 0) := (others => '0');
    signal s_cfg_tvalid  : std_logic := '0';
    signal s_cfg_tready  : std_logic;

    --------------------------------------------------------------------
    -- AXI data channel into FFT
    --------------------------------------------------------------------
    signal s_data_tdata  : std_logic_vector(63 downto 0);
    signal s_data_tvalid : std_logic;
    signal s_data_tready : std_logic;
    signal s_data_tlast  : std_logic;

    --------------------------------------------------------------------
    -- AXI data channel out of FFT
    --------------------------------------------------------------------
    signal m_data_tdata  : std_logic_vector(63 downto 0);
    signal m_data_tvalid : std_logic;
    signal m_data_tready : std_logic := '1';
    signal m_data_tlast  : std_logic;

    --------------------------------------------------------------------
    -- Internal helper/debug signals
    --------------------------------------------------------------------
    signal aresetn_s : std_logic;

    signal event_frame_started_s         : std_logic := '0';
    signal event_tlast_unexpected_s      : std_logic := '0';
    signal event_tlast_missing_s         : std_logic := '0';
    signal event_status_channel_halt_s   : std_logic := '0';
    signal event_data_in_channel_halt_s  : std_logic := '0';
    signal event_data_out_channel_halt_s : std_logic := '0';

    signal input_backpressure_violation_s : std_logic := '0';

    signal out_real_reg        : signed(31 downto 0) := (others => '0');
    signal out_imag_reg        : signed(31 downto 0) := (others => '0');
    signal out_valid_reg       : std_logic := '0';
    signal start_of_ascan_reg  : std_logic := '0';
    signal out_frame_active    : std_logic := '0';

    constant FFT_CONFIG_FWD : std_logic_vector(15 downto 0) := (others => '0');
    
    signal cfg_done_s : std_logic := '0';
    signal cfg_valid_s : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Reset polarity conversion
    --------------------------------------------------------------------
    aresetn_s <= not rst;

    --------------------------------------------------------------------
    -- Valid-only upstream stream drives FFT input directly
    --
    -- Assumption: FFT input is always ready in intended operation.
    --------------------------------------------------------------------
    s_data_tdata  <= std_logic_vector(in_imag) & std_logic_vector(in_real);
    s_data_tvalid <= in_valid and cfg_done_s;
    s_data_tlast  <= end_of_ascan when cfg_done_s = '1' else '0';

    --------------------------------------------------------------------
    -- FFT always allowed to output
    --------------------------------------------------------------------
    m_data_tready <= '1';
    

    --------------------------------------------------------------------
    -- FFT instance
    --------------------------------------------------------------------
    u_fft : xfft_0
        port map (
            aclk                        => clk,
            aresetn                     => aresetn_s,

            s_axis_config_tdata         => s_cfg_tdata,
            s_axis_config_tvalid        => s_cfg_tvalid,
            s_axis_config_tready        => s_cfg_tready,

            s_axis_data_tdata           => s_data_tdata,
            s_axis_data_tvalid          => s_data_tvalid,
            s_axis_data_tready          => s_data_tready,
            s_axis_data_tlast           => s_data_tlast,

            m_axis_data_tdata           => m_data_tdata,
            m_axis_data_tvalid          => m_data_tvalid,
            m_axis_data_tready          => m_data_tready,
            m_axis_data_tlast           => m_data_tlast,

            event_frame_started         => event_frame_started_s,
            event_tlast_unexpected      => event_tlast_unexpected_s,
            event_tlast_missing         => event_tlast_missing_s,
            event_status_channel_halt   => event_status_channel_halt_s,
            event_data_in_channel_halt  => event_data_in_channel_halt_s,
            event_data_out_channel_halt => event_data_out_channel_halt_s
        );

    s_cfg_tvalid <= cfg_valid_s;
    dbg_cfg_done <= cfg_done_s;
    --------------------------------------------------------------------
    -- Send FFT config once after reset
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                s_cfg_tdata <= FFT_CONFIG_FWD;
                cfg_valid_s <= '0';
                cfg_done_s  <= '0';
            else
                -- Keep presenting config until FFT accepts it
                if cfg_done_s = '0' then
                    s_cfg_tdata <= FFT_CONFIG_FWD;
                    cfg_valid_s <= '1';
    
                    if s_cfg_tready = '1' then
                        cfg_valid_s <= '0';
                        cfg_done_s  <= '1';
                    end if;
                else
                    cfg_valid_s <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Latch any input backpressure violation
    --
    -- In your intended use, this should never happen:
    -- upstream is presenting a valid beat, but FFT says not ready.
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                input_backpressure_violation_s <= '0';
            else
                if in_valid = '1' and s_data_tready = '0' then
                    input_backpressure_violation_s <= '1';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Output handling
    --
    -- start_of_ascan_out pulses on the first FFT output beat of each frame.
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                out_real_reg       <= (others => '0');
                out_imag_reg       <= (others => '0');
                out_valid_reg      <= '0';
                start_of_ascan_reg <= '0';
                out_frame_active   <= '0';
            else
                out_valid_reg      <= '0';
                start_of_ascan_reg <= '0';

                if m_data_tvalid = '1' then
                    out_real_reg  <= signed(m_data_tdata(31 downto 0));
                    out_imag_reg  <= signed(m_data_tdata(63 downto 32));
                    out_valid_reg <= '1';

                    if out_frame_active = '0' then
                        start_of_ascan_reg <= '1';
                        out_frame_active   <= '1';
                    end if;

                    if m_data_tlast = '1' then
                        out_frame_active <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Drive outputs
    --------------------------------------------------------------------
    out_real           <= out_real_reg;
    out_imag           <= out_imag_reg;
    out_valid          <= out_valid_reg;
    start_of_ascan_out <= start_of_ascan_reg;

    dbg_event_frame_started          <= event_frame_started_s;
    dbg_event_tlast_unexpected       <= event_tlast_unexpected_s;
    dbg_event_tlast_missing          <= event_tlast_missing_s;
    dbg_event_status_channel_halt    <= event_status_channel_halt_s;
    dbg_event_data_in_channel_halt   <= event_data_in_channel_halt_s;
    dbg_event_data_out_channel_halt  <= event_data_out_channel_halt_s;
    dbg_input_backpressure_violation <= input_backpressure_violation_s;

end architecture rtl;