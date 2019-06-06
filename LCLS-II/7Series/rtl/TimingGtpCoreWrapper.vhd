-------------------------------------------------------------------------------
-- File       : TimingGtpCoreWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for GTP Core
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
      AXIL_CLK_FREQ_G  : real    := 156.25E6;
      AXIL_BASE_ADDR_G : slv(31 downto 0));
   port (
      -- AXI-Lite Port
      axilClk          : in  sl;
      axilRst          : in  sl;
      axilReadMaster   : in  AxiLiteReadMasterType;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType;
      axilWriteSlave   : out AxiLiteWriteSlaveType;

      stableClk        : in  sl;

      -- GTP FPGA IO
      gtRefClk         : in  sl;
      gtRefClkDiv2     : in  sl := '0';-- Unused in GTHE3, but used in GTHE4
      gtRxP            : in  sl;
      gtRxN            : in  sl;
      gtTxP            : out sl;
      gtTxN            : out sl;

      -- Clock PLL selection: bit 1: rx/txoutclk, bit 0: rx/tx data path
      gtRxPllSel       : in slv(1 downto 0) := "00";
      gtTxPllSel       : in slv(1 downto 0) := "00";

      -- Rx ports
      rxControl        : in  TimingPhyControlType;
      rxStatus         : out TimingPhyStatusType;
      rxUsrClkActive   : in  sl := '1';
      rxCdrStable      : out sl;
      rxUsrClk         : in  sl;
      rxData           : out slv(15 downto 0);
      rxDataK          : out slv(1 downto 0);
      rxDispErr        : out slv(1 downto 0);
      rxDecErr         : out slv(1 downto 0);
      rxOutClk         : out sl;

      -- Tx Ports
      txControl        : in  TimingPhyControlType;
      txStatus         : out TimingPhyStatusType;
      txUsrClk         : in  sl;
      txUsrClkActive   : in  sl := '1';
      txData           : in  slv(15 downto 0);
      txDataK          : in  slv(1 downto 0);
      txOutClk         : out sl;

      -- Loopback
      loopback         : in slv(2 downto 0));
end entity TimingGtCoreWrapper;

architecture rtl of TimingGtCoreWrapper is

   component TimingGtp
      port (
         SYSCLK_IN : in STD_LOGIC;
         SOFT_RESET_TX_IN : in STD_LOGIC;
         SOFT_RESET_RX_IN : in STD_LOGIC;
         DONT_RESET_ON_DATA_ERROR_IN : in STD_LOGIC;
         GT0_DRP_BUSY_OUT : out STD_LOGIC;
         GT0_TX_FSM_RESET_DONE_OUT : out STD_LOGIC;
         GT0_RX_FSM_RESET_DONE_OUT : out STD_LOGIC;
         GT0_DATA_VALID_IN : in STD_LOGIC;
         gt0_drpaddr_in : in STD_LOGIC_VECTOR ( 8 downto 0 );
         gt0_drpclk_in : in STD_LOGIC;
         gt0_drpdi_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
         gt0_drpdo_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
         gt0_drpen_in : in STD_LOGIC;
         gt0_drprdy_out : out STD_LOGIC;
         gt0_drpwe_in : in STD_LOGIC;
         gt0_rxsysclksel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_txsysclksel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_loopback_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
         gt0_eyescanreset_in : in STD_LOGIC;
         gt0_rxuserrdy_in : in STD_LOGIC;
         gt0_eyescandataerror_out : out STD_LOGIC;
         gt0_eyescantrigger_in : in STD_LOGIC;
         gt0_rxdata_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
         gt0_rxusrclk_in : in STD_LOGIC;
         gt0_rxusrclk2_in : in STD_LOGIC;
         gt0_rxcharisk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_rxdisperr_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_rxnotintable_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_gtprxn_in : in STD_LOGIC;
         gt0_gtprxp_in : in STD_LOGIC;
         gt0_rxphmonitor_out : out STD_LOGIC_VECTOR ( 4 downto 0 );
         gt0_rxphslipmonitor_out : out STD_LOGIC_VECTOR ( 4 downto 0 );
         gt0_dmonitorout_out : out STD_LOGIC_VECTOR ( 14 downto 0 );
         gt0_rxlpmhfhold_in : in STD_LOGIC;
         gt0_rxlpmlfhold_in : in STD_LOGIC;
         gt0_rxoutclk_out : out STD_LOGIC;
         gt0_rxoutclkfabric_out : out STD_LOGIC;
         gt0_gtrxreset_in : in STD_LOGIC;
         gt0_rxlpmreset_in : in STD_LOGIC;
         gt0_rxpolarity_in : in STD_LOGIC;
         gt0_rxresetdone_out : out STD_LOGIC;
         gt0_gttxreset_in : in STD_LOGIC;
         gt0_txuserrdy_in : in STD_LOGIC;
         gt0_txdata_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
         gt0_txusrclk_in : in STD_LOGIC;
         gt0_txusrclk2_in : in STD_LOGIC;
         gt0_txcharisk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
         gt0_gtptxn_out : out STD_LOGIC;
         gt0_gtptxp_out : out STD_LOGIC;
         gt0_txoutclk_out : out STD_LOGIC;
         gt0_txoutclkfabric_out : out STD_LOGIC;
         gt0_txoutclkpcs_out : out STD_LOGIC;
         gt0_txresetdone_out : out STD_LOGIC;
         gt0_txpolarity_in : in STD_LOGIC;
         GT0_PLL0OUTCLK_IN : in STD_LOGIC;
         GT0_PLL0OUTREFCLK_IN : in STD_LOGIC;
         GT0_PLL0RESET_OUT : out STD_LOGIC;
         GT0_PLL0LOCK_IN : in STD_LOGIC;
         GT0_PLL0REFCLKLOST_IN : in STD_LOGIC;
         GT0_PLL1OUTCLK_IN : in STD_LOGIC;
         GT0_PLL1OUTREFCLK_IN : in STD_LOGIC
      );
   end component TimingGtp;

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

   signal pll0outclk_i     : sl;
   signal pll0outrefclk_i  : sl;
   signal pll1outclk_i     : sl;
   signal pll1outrefclk_i  : sl;

   signal pll0_reset_i     : sl;
   signal pll0_pd_i        : sl;

   signal pll_rail_reset_i : sl;
   signal pll_reset_i      : sl;
   signal pll_locked_i     : sl;
   signal pll_refclklost_i : sl;

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

   U_TimingGtpCore : component TimingGtp
      port map (
         sysclk_in                       =>      axilClk,
         soft_reset_tx_in                =>      txControl.reset,
         soft_reset_rx_in                =>      rxRst,
         dont_reset_on_data_error_in     =>      '0',
         gt0_drp_busy_out                =>      open,
         gt0_tx_fsm_reset_done_out       =>      txStatus.resetDone,
         gt0_rx_fsm_reset_done_out       =>      bypassdone,
         gt0_data_valid_in               =>      '1',
 
         --_____________________________________________________________________
         --_____________________________________________________________________
         --GT0  (X1Y0)
         ---------------------------- Channel - DRP Ports  --------------------------
         gt0_drpaddr_in                  =>      drpAddr,
         gt0_drpclk_in                   =>      drpClk,
         gt0_drpdi_in                    =>      drpDi,
         gt0_drpdo_out                   =>      drpDo,
         gt0_drpen_in                    =>      drpEn,
         gt0_drprdy_out                  =>      drpRdy,
         gt0_drpwe_in                    =>      drpWe,
         --------------------------- Selection of reference PLL ---------------------
         gt0_rxsysclksel_in              =>      gtRxPllSel,
         gt0_txsysclksel_in              =>      gtTxPllSel,
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
         gt0_rxdisperr_out               =>      rxDispErr,
         gt0_rxnotintable_out            =>      rxDecErr,
         --------------------------- Receive Ports - RX AFE -------------------------
         gt0_gtprxp_in                   =>      gtRxP,
         ------------------------ Receive Ports - RX AFE Ports ----------------------
         gt0_gtprxn_in                   =>      gtRxN,
         ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
         gt0_rxphmonitor_out             =>      open,
         gt0_rxphslipmonitor_out         =>      open,
         --------------------- Receive Ports - RX Equalizer Ports -------------------
         gt0_rxlpmhfhold_in               =>      '0',
         gt0_rxlpmlfhold_in               =>      '0',

         --------------- Receive Ports - RX Fabric Output Control Ports -------------
         gt0_rxoutclk_out                =>      rxoutclk_out,
         gt0_rxoutclkfabric_out          =>      open,
         ------------- Receive Ports - RX Initialization and Reset Ports ------------
         gt0_gtrxreset_in                =>      '0',
         gt0_rxlpmreset_in               =>      '0',
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
         gt0_gtptxn_out                  =>      gtTxN,
         gt0_gtptxp_out                  =>      gtTxP,
         ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
         gt0_txoutclk_out                =>      txoutclk_out,
         gt0_txoutclkfabric_out          =>      open,
         gt0_txoutclkpcs_out             =>      open,
         --------------------- Transmit Ports - TX Gearbox Ports --------------------
         gt0_txcharisk_in                =>      txDataK,
         ------------- Transmit Ports - TX Initialization and Reset Ports -----------
         gt0_txresetdone_out             =>      open,

         gt0_rxpolarity_in               =>      rxControl.polarity,
         gt0_txpolarity_in               =>      txControl.polarity,
 
         gt0_pll0outclk_in               =>      pll0outclk_i,
         gt0_pll0outrefclk_in            =>      pll0outrefclk_i,
         gt0_pll1outclk_in               =>      pll1outclk_i,
         gt0_pll1outrefclk_in            =>      pll1outrefclk_i,

         GT0_PLL0RESET_OUT               =>      pll_reset_i,
         GT0_PLL0LOCK_IN                 =>      pll_locked_i,
         GT0_PLL0REFCLKLOST_IN           =>      pll_refclklost_i
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

  cpll_railing_pll0_q0_clk1_refclk_i : entity work.TimingGtp_cpll_railing
  generic map(
           USE_BUFG       => 0
   )
   port map
   (
        cpll_reset_out => pll_rail_reset_i,
        cpll_pd_out => pll0_pd_i,
        refclk_out => open,
        refclk_in => gtRefClk
   );

   pll0_reset_i <= pll_rail_reset_i or pll_reset_i or txControl.reset;
   
   TIMING_COMMON_TMP : entity work.TimingGtp_common
      port map (
         DRPADDR_COMMON_IN    => x"00",
         DRPCLK_COMMON_IN     => drpClk,
         DRPDI_COMMON_IN      => x"0000",
         DRPDO_COMMON_OUT     => open,
         DRPEN_COMMON_IN      => '0',
         DRPRDY_COMMON_OUT    => open,
         DRPWE_COMMON_IN      => '0',
         PLL0OUTCLK_OUT       => pll0outclk_i,
         PLL0OUTREFCLK_OUT    => pll0outrefclk_i,
         PLL0LOCK_OUT         => pll_locked_i,
         PLL0LOCKDETCLK_IN    => axilClk,
         PLL0REFCLKLOST_OUT   => pll_refclklost_i,
         PLL0RESET_IN         => pll0_reset_i,
         PLL0REFCLKSEL_IN     => "010",
         PLL0PD_IN            => pll0_pd_i,
         PLL1OUTCLK_OUT       => pll1outclk_i,
         PLL1OUTREFCLK_OUT    => pll1outrefclk_i,
         GTREFCLK1_IN         => gtRefClk,
         GTREFCLK0_IN         => '0'
      );

end architecture rtl;
