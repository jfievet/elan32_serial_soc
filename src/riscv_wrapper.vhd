library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity riscv_wrapper is
    generic (
        USE_ASYNC_RESET    : boolean   := TRUE;
        USE_SYNC_RESET     : boolean   := TRUE;
        ASYNC_RESET_ACTIVE : std_logic := '1';
        SYNC_RESET_ACTIVE  : std_logic := '1';
        start_address      : std_logic_vector(31 downto 0) := x"00000000";
        enable_multiplier  : boolean := true;
        enable_divider     : boolean := true
    );
    port (
        -- Clock and reset
        clock_i       : in std_logic;
        async_reset : in std_logic;
        sync_reset  : in std_logic;

        -- CPU control
        stall_i : in std_logic;
        fault_i : in std_logic;
        fault_o : out std_logic;

        -- Debug interface
        registers_debug_o : out std_logic_vector(1023 downto 0);
        pc_debug_o        : out std_logic_vector(31 downto 0);
        previous_pc_debug_o : out std_logic_vector(31 downto 0);

        -- AXI4-Lite write address channel
        m_axi_awaddr_o  : out std_logic_vector(31 downto 0);
        m_axi_awprot_o  : out std_logic_vector(2 downto 0);
        m_axi_awvalid_o : out std_logic;
        m_axi_awready_i : in std_logic;

        -- AXI4-Lite write data channel
        m_axi_wdata_o  : out std_logic_vector(31 downto 0);
        m_axi_wstrb_o  : out std_logic_vector(3 downto 0);
        m_axi_wvalid_o : out std_logic;
        m_axi_wready_i : in std_logic;

        -- AXI4-Lite write response channel
        m_axi_bresp_i  : in std_logic_vector(1 downto 0);
        m_axi_bvalid_i : in std_logic;
        m_axi_bready_o : out std_logic;

        -- AXI4-Lite read address channel
        m_axi_araddr_o  : out std_logic_vector(31 downto 0);
        m_axi_arprot_o  : out std_logic_vector(2 downto 0);
        m_axi_arvalid_o : out std_logic;
        m_axi_arready_i : in std_logic;

        -- AXI4-Lite read data channel
        m_axi_rdata_i  : in std_logic_vector(31 downto 0);
        m_axi_rresp_i  : in std_logic_vector(1 downto 0);
        m_axi_rvalid_i : in std_logic;
        m_axi_rready_o : out std_logic
    );
end entity;

architecture rtl of riscv_wrapper is

    -- Internal reset
    signal reset_n : std_logic;

    -- Reset synchronization
    signal reset_sync_1 : std_logic;
    signal reset_sync_2 : std_logic;

    -- Debug
    signal debug_ready  : std_logic;
    signal debug_valid  : std_logic;
    signal debug_data   : std_logic_vector(31 downto 0);

begin

    --------------------------------------------------------------------
    -- Reset controller
    --------------------------------------------------------------------

    -- Asynchronous assertion, synchronous release
    process (clock_i, async_reset)
    begin
        if (USE_ASYNC_RESET and async_reset = ASYNC_RESET_ACTIVE) then
            reset_sync_1 <= '0';
            reset_sync_2 <= '0';

        elsif rising_edge(clock_i) then
            if (USE_SYNC_RESET and sync_reset = SYNC_RESET_ACTIVE) then
                reset_sync_1 <= '0';
                reset_sync_2 <= '0';
            else
                reset_sync_1 <= '1';
                reset_sync_2 <= reset_sync_1;
            end if;
        end if;
    end process;

    reset_n <= reset_sync_2 when (USE_ASYNC_RESET or USE_SYNC_RESET)
               else '1';

    -- Legacy interface compatibility
    -- No stall support in ELAN-S
    -- stall_i is intentionally unused

    -- Multiplier and divider generics are intentionally unused
    -- enable_multiplier
    -- enable_divider

    -- Legacy parallel register debug is not supported
    registers_debug_o <= (others => '0');

    --------------------------------------------------------------------
    -- ELAN-S RISC-V bit-serial processor
    --------------------------------------------------------------------

    u_elan_core : entity work.elans_core
        generic map (
            use_async_reset    => false,
            use_sync_reset     => true,
            async_reset_active => '1',
            sync_reset_active  => '0',
            reset_pc           => start_address,
            rf_organization    => "a"
        )
        port map (
            -- Clock and reset
            clock_i       => clock_i,
            async_reset_i => '0',
            sync_reset_i  => reset_n,

            -- CPU control
            fault_i => fault_i,
            fault_o => fault_o,

            -- Debug interface
            pc_o            => pc_debug_o,
            previous_pc_o   => previous_pc_debug_o,
            debug_request_i => '0',
            debug_index_i   => (others => '0'),
            debug_ready_o   => debug_ready,
            debug_data_o    => debug_data,
            debug_valid_o   => debug_valid,

            -- AXI4-Lite write address channel
            awaddr_o  => m_axi_awaddr_o,
            awprot_o  => m_axi_awprot_o,
            awvalid_o => m_axi_awvalid_o,
            awready_i => m_axi_awready_i,

            -- AXI4-Lite write data channel
            wdata_o  => m_axi_wdata_o,
            wstrb_o  => m_axi_wstrb_o,
            wvalid_o => m_axi_wvalid_o,
            wready_i => m_axi_wready_i,

            -- AXI4-Lite write response channel
            bresp_i  => m_axi_bresp_i,
            bvalid_i => m_axi_bvalid_i,
            bready_o => m_axi_bready_o,

            -- AXI4-Lite read address channel
            araddr_o  => m_axi_araddr_o,
            arprot_o  => m_axi_arprot_o,
            arvalid_o => m_axi_arvalid_o,
            arready_i => m_axi_arready_i,

            -- AXI4-Lite read data channel
            rdata_i  => m_axi_rdata_i,
            rresp_i  => m_axi_rresp_i,
            rvalid_i => m_axi_rvalid_i,
            rready_o => m_axi_rready_o
        );

end architecture rtl;
