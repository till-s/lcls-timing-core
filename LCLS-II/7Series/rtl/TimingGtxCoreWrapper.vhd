-------------------------------------------------------------------------------
-- File       : TimingGtxCoreWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for GTX Core
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LCLS2 Timing Core', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.TimingPkg.all;

library unisim;
use unisim.vcomponents.all;

entity TimingGtCoreWrapper is
   generic (
      TPD_G            : time    := 1 ns;
      EXTREF_G         : boolean := false;
      AXIL_CLK_FREQ_G  : real    := 156.25E6;
      AXIL_BASE_ADDR_G : slv(31 downto 0));
   port (
      -- AXI-Lite Port
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      stableClk : in  sl;
      -- GTX FPGA IO
      gtRefClk  : in  sl;
      gtRefClkDiv2  : in  sl := '0';-- Unused in GTX, but used in GTHE4
      gtRxP     : in  sl;
      gtRxN     : in  sl;
      gtTxP     : out sl;
      gtTxN     : out sl;

      -- Rx ports
      rxControl      : in  TimingPhyControlType;
      rxStatus       : out TimingPhyStatusType;
      rxUsrClkActive : in  sl := '1';
      rxCdrStable    : out sl;
      rxUsrClk       : in  sl;
      rxData         : out slv(15 downto 0);
      rxDataK        : out slv(1 downto 0);
      rxDispErr      : out slv(1 downto 0);
      rxDecErr       : out slv(1 downto 0);
      rxOutClk       : out sl;

      -- Tx Ports
      txControl      : in  TimingPhyControlType;
      txStatus       : out TimingPhyStatusType;
      txUsrClk       : in  sl;
      txUsrClkActive : in  sl := '1';
      txData         : in  slv(15 downto 0);
      txDataK        : in  slv(1 downto 0);
      txOutClk       : out sl;

      -- Loopback
      loopback       : in slv(2 downto 0));
end entity TimingGtCoreWrapper;

architecture rtl of TimingGtCoreWrapper is

   component TimingGtx
      port (
         SYSCLK_IN : in STD_LOGIC;
         SOFT_RESET_TX_IN : in STD_LOGIC;
         SOFT_RESET_RX_IN : in STD_LOGIC;
         DONT_RESET_ON_DATA_ERROR_IN : in STD_LOGIC;
         GT0_TX_FSM_RESET_DONE_OUT : out STD_LOGIC;
         GT0_RX_FSM_RESET_DONE_OUT : out STD_LOGIC;
         GT0_DATA_VALID_IN : in STD_LOGIC;
         gt0_cpllfbclklost_out : out STD_LOGIC;
         gt0_cplllock_out : out STD_LOGIC;
         gt0_cplllockdetclk_in : in STD_LOGIC;
         gt0_cpllreset_in : in STD_LOGIC;
         gt0_gtrefclk0_in : in STD_LOGIC;
         gt0_gtrefclk1_in : in STD_LOGIC;
         gt0_drpaddr_in : in STD_LOGIC_VECTOR ( 8 downto 0 );
         gt0_drpclk_in : in STD_LOGIC;
         gt0_drpdi_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
         gt0_drpdo_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
         gt0_drpen_in : in STD_LOGIC;
         gt0_drprdy_out : out STD_LOGIC;
         gt0_drpwe_in : in STD_LOGIC;
         gt0_dmonitorout_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
         gt0_loopback_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
         gt0_eyescanreset_in : in STD_LOGIC;
         gt0_rxuserrdy_in : in STD_LOGIC;
         gt0_eyescandataerror_out : out STD_LOGIC;
         gt0_eyescantrigger_in : in STD_LOGIC;
         gt0_rxusrclk_in : in STD_LOGIC;
         gt0_rxusrclk2_in : in STD_LOGIC;
         gt0_rxdata_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
         gt0_rxdisperr_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_rxnotintable_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_gtxrxp_in : in STD_LOGIC;
         gt0_gtxrxn_in : in STD_LOGIC;
         gt0_rxphmonitor_out : out STD_LOGIC_VECTOR ( 4 downto 0 );
         gt0_rxphslipmonitor_out : out STD_LOGIC_VECTOR ( 4 downto 0 );
         gt0_rxdfelpmreset_in : in STD_LOGIC;
         gt0_rxmonitorout_out : out STD_LOGIC_VECTOR ( 6 downto 0 );
         gt0_rxmonitorsel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_rxoutclk_out : out STD_LOGIC;
         gt0_rxoutclkfabric_out : out STD_LOGIC;
         gt0_gtrxreset_in : in STD_LOGIC;
         gt0_rxpmareset_in : in STD_LOGIC;
         gt0_rxcharisk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_rxresetdone_out : out STD_LOGIC;
         gt0_gttxreset_in : in STD_LOGIC;
         gt0_txuserrdy_in : in STD_LOGIC;
         gt0_txusrclk_in : in STD_LOGIC;
         gt0_txusrclk2_in : in STD_LOGIC;
         gt0_txdata_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
         gt0_gtxtxn_out : out STD_LOGIC;
         gt0_gtxtxp_out : out STD_LOGIC;
         gt0_txoutclk_out : out STD_LOGIC;
         gt0_txoutclkfabric_out : out STD_LOGIC;
         gt0_txoutclkpcs_out : out STD_LOGIC;
         gt0_txcharisk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_txresetdone_out : out STD_LOGIC;
         gt0_txpolarity_in   : in  STD_LOGIC;
         gt0_rxpolarity_in   : in  STD_LOGIC;
         GT0_QPLLOUTCLK_IN : in STD_LOGIC;
         GT0_QPLLOUTREFCLK_IN : in STD_LOGIC
      );
   end component TimingGtx;

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) := (
      0               => (
         baseAddr     => (AXIL_BASE_ADDR_G+x"00000000"),
         addrBits     => 16,
         connectivity => x"FFFF"),
      1               => (
         baseAddr     => (AXIL_BASE_ADDR_G+x"00010000"),
         addrBits     => 16,
         connectivity => x"FFFF"));

   signal rxCtrl0Out       : slv(15 downto 0);
   signal rxCtrl1Out       : slv(15 downto 0);
   signal rxCtrl3Out       : slv(7 downto 0);
   signal txoutclk_out     : sl;
   signal txoutclkb        : sl;
   signal rxoutclk_out     : sl;
   signal rxoutclkb        : sl;

   signal rxDecErrLoc      : slv(1 downto 0);
   signal rxDispErrLoc     : slv(1 downto 0);

   signal drpClk           : sl;
   signal drpRst           : sl;
   signal drpAddr          : slv(8 downto 0);
   signal drpDi            : slv(15 downto 0);
   signal drpEn            : sl;
   signal drpWe            : sl;
   signal drpDo            : slv(15 downto 0);
   signal drpRdy           : sl;
   signal rxRst            : sl;
   signal bypassdone       : sl;
   signal bypasserr        : sl := '0';
   signal axilWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(1 downto 0);

   signal mAxilWriteMaster : AxiLiteWriteMasterType;
   signal mAxilWriteSlave  : AxiLiteWriteSlaveType;
   signal mAxilReadMaster  : AxiLiteReadMasterType;
   signal mAxilReadSlave   : AxiLiteReadSlaveType;

   signal probe0           : slv(63 downto 0) := (others => '0');
   signal probe1           : slv(63 downto 0) := (others => '0');

component Ila_256 is
    Port (
      clk : in STD_LOGIC;
      probe0 : in STD_LOGIC_VECTOR ( 63 downto 0 );
      probe1 : in STD_LOGIC_VECTOR ( 63 downto 0 );
      probe2 : in STD_LOGIC_VECTOR ( 63 downto 0 );
      probe3 : in STD_LOGIC_VECTOR ( 63 downto 0 )
    );
end component Ila_256;

begin

   rxStatus.resetDone    <= bypassdone;
   rxStatus.bufferByDone <= bypassdone;
   rxStatus.bufferByErr  <= bypasserr;

   rxCdrStable           <= bypassdone; -- CDR locked not routed out by wizard

   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => 2,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteMasters(1) => mAxilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiWriteSlaves(1)  => mAxilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadMasters(1)  => mAxilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         sAxiReadSlaves(1)   => mAxilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   U_AlignCheck : entity work.GthRxAlignCheck
      generic map (
         TPD_G            => TPD_G,
         GT_TYPE_G        => "GTX2",
         REF_CLK_FREQ_G   => AXIL_CLK_FREQ_G,
         DRP_ADDR_G       => AXI_CROSSBAR_MASTERS_CONFIG_C(1).baseAddr)
      port map (
         txClk            => txoutclkb,
         rxClk            => rxoutclkb,
         -- GTH Status/Control Interface
         resetIn          => rxControl.reset,
         resetDone        => bypassdone,
         resetErr         => bypasserr,
         resetOut         => rxRst,
         locked           => rxStatus.locked,
         -- Clock and Reset
         axilClk          => axilClk,
         axilRst          => axilRst,
         -- Slave AXI-Lite Interface
         mAxilReadMaster  => mAxilReadMaster,
         mAxilReadSlave   => mAxilReadSlave,
         mAxilWriteMaster => mAxilWriteMaster,
         mAxilWriteSlave  => mAxilWriteSlave,
         -- Slave AXI-Lite Interface
         sAxilReadMaster  => axilReadMasters(0),
         sAxilReadSlave   => axilReadSlaves(0),
         sAxilWriteMaster => axilWriteMasters(0),
         sAxilWriteSlave  => axilWriteSlaves(0));

   U_AxiLiteToDrp : entity work.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         COMMON_CLK_G     => true,
         EN_ARBITRATION_G => false,
         TIMEOUT_G        => 4096,
         ADDR_WIDTH_G     => 9,
         DATA_WIDTH_G     => 16)
      port map (
         -- AXI-Lite Port
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(1),
         axilReadSlave   => axilReadSlaves(1),
         axilWriteMaster => axilWriteMasters(1),
         axilWriteSlave  => axilWriteSlaves(1),
         -- DRP Interface
         drpClk          => axilClk,
         drpRst          => axilRst,
         drpRdy          => drpRdy,
         drpEn           => drpEn,
         drpWe           => drpWe,
         drpAddr         => drpAddr,
         drpDi           => drpDi,
         drpDo           => drpDo);

   drpClk <= axilClk;
   drpRst <= axilRst;

   U_TimingGtxCore : component TimingGtx
      port map (
         sysclk_in                       =>      axilClk,
         soft_reset_tx_in                =>      txControl.reset,
         soft_reset_rx_in                =>      rxRst,
         dont_reset_on_data_error_in     =>      '0',
         gt0_tx_fsm_reset_done_out       =>      txStatus.resetDone,
         gt0_rx_fsm_reset_done_out       =>      bypassdone,
         gt0_data_valid_in               =>      '1',

         --_____________________________________________________________________
         --_____________________________________________________________________
         --GT0  (X1Y0)

         --------------------------------- CPLL Ports -------------------------------
         gt0_cpllfbclklost_out           =>      probe0(0),
         gt0_cplllock_out                =>      probe0(1),
         gt0_cplllockdetclk_in           =>      stableClk,
         gt0_cpllreset_in                =>      txControl.pllreset,
         -------------------------- Channel - Clocking Ports ------------------------
         gt0_gtrefclk0_in                =>      '0',
         gt0_gtrefclk1_in                =>      gtRefClk,
         ---------------------------- Channel - DRP Ports  --------------------------
         gt0_drpaddr_in                  =>      drpAddr,
         gt0_drpclk_in                   =>      drpClk,
         gt0_drpdi_in                    =>      drpDi,
         gt0_drpdo_out                   =>      drpDo,
         gt0_drpen_in                    =>      drpEn,
         gt0_drprdy_out                  =>      drpRdy,
         gt0_drpwe_in                    =>      drpWe,
         --------------------------- Digital Monitor Ports --------------------------
         gt0_dmonitorout_out             =>      open,
         ------------------------------- Loopback Ports -----------------------------
         gt0_loopback_in                 =>      loopback,
         --------------------- RX Initialization and Reset Ports --------------------
         gt0_eyescanreset_in             =>      '0',
         gt0_rxuserrdy_in                =>      '1',
         -------------------------- RX Margin Analysis Ports ------------------------
         gt0_eyescandataerror_out        =>      open,
         gt0_eyescantrigger_in           =>      '0',
         ------------------ Receive Ports - FPGA RX Interface Ports -----------------
         gt0_rxusrclk_in                 =>      rxUsrClk,
         gt0_rxusrclk2_in                =>      rxUsrClk,
         ------------------ Receive Ports - FPGA RX interface Ports -----------------
         gt0_rxdata_out                  =>      rxData,
         ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
         gt0_rxdisperr_out               =>      rxDispErrLoc,
         gt0_rxnotintable_out            =>      rxDecErrLoc,
         --------------------------- Receive Ports - RX AFE -------------------------
         gt0_gtxrxp_in                   =>      gtRxP,
         ------------------------ Receive Ports - RX AFE Ports ----------------------
         gt0_gtxrxn_in                   =>      gtRxN,
         ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
         gt0_rxphslipmonitor_out         =>      open,
         --------------------- Receive Ports - RX Equalizer Ports -------------------
         gt0_rxdfelpmreset_in            =>      '0',
         gt0_rxmonitorout_out            =>      open,
         gt0_rxmonitorsel_in             =>      "00",
         --------------- Receive Ports - RX Fabric Output Control Ports -------------
         gt0_rxoutclk_out                =>      rxoutclk_out,
         gt0_rxoutclkfabric_out          =>      open,
         ------------- Receive Ports - RX Initialization and Reset Ports ------------
         gt0_gtrxreset_in                =>      '0',
         gt0_rxpmareset_in               =>      '0',
         ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
         gt0_rxcharisk_out               =>      rxDataK,
         -------------- Receive Ports -RX Initialization and Reset Ports ------------
         gt0_rxresetdone_out             =>      open,
         --------------------- TX Initialization and Reset Ports --------------------
         gt0_gttxreset_in                =>      '0',
         gt0_txuserrdy_in                =>      '1',
         ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
         gt0_txusrclk_in                 =>      txUsrClk,
         gt0_txusrclk2_in                =>      txUsrClk,
         ------------------ Transmit Ports - TX Data Path interface -----------------
         gt0_txdata_in                   =>      txData,
         ---------------- Transmit Ports - TX Driver and OOB signaling --------------
         gt0_gtxtxn_out                  =>      gtTxN,
         gt0_gtxtxp_out                  =>      gtTxP,
         ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
         gt0_txoutclk_out                =>      txoutclk_out,
         gt0_txoutclkfabric_out          =>      open,
         gt0_txoutclkpcs_out             =>      open,
         --------------------- Transmit Ports - TX Gearbox Ports --------------------
         gt0_txcharisk_in                =>      txDataK,
         ------------- Transmit Ports - TX Initialization and Reset Ports -----------
         gt0_txresetdone_out             =>      open,
         ----------------- Transmit Ports - TX Polarity Control Ports ---------------
         gt0_txpolarity_in               =>      txControl.polarity,
         gt0_rxpolarity_in               =>      rxControl.polarity,
         gt0_qplloutclk_in               =>      '0',
         gt0_qplloutrefclk_in            =>      '0'
      );


   TIMING_TXCLK_BUFG : BUFG
      port map (
         I       => txoutclk_out,
         O       => txoutclkb);

   TIMING_RECCLK_BUFG : BUFG
      port map (
         I       => rxoutclk_out,
         O       => rxoutclkb);

   txOutClk <= txoutclkb;
   rxOutClk <= rxoutclkb;

   probe0(63 downto 2) <= (others => '0');

   U_ILA_TIMING : component Ila_256
      port map (
         clk    => rxoutclkb,
         probe0( 1 downto  0) => rxDecErrLoc,
         probe0( 3 downto  2) => rxDispErrLoc,
         probe0(           4) => bypassdone,
         probe0(63 downto  5) => (others => '0'),
         probe1 => (others => '0'),
         probe2 => (others => '0'),
         probe3 => (others => '0')
      );

   rxDecErr  <= rxDecErrLoc;
   rxDispErr <= rxDispErrLoc;


   U_ILA : component Ila_256
      port map (
         clk    => axilClk,
         probe0 => probe0,
         probe1 => probe1,
         probe2 => (others => '0'),
         probe3 => (others => '0')
      );

end architecture rtl;
