-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TPGMini.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-11-09
-- Last update: 2016-04-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.VCOMPONENTS.all;
use work.TPGPkg.all;
use work.StdRtlPkg.all;
use work.TimingPkg.all;

entity TPGMini is
  generic (
    NARRAYSBSA   : integer := 2
    );
  port (
    statusO : out TPGStatusType;
    configI : in  TPGConfigType;

    txClk      : in  sl;
    txRst      : in  sl;
    txRdy      : in  sl;
    txData     : out slv(15 downto 0);
    txDataK    : out slv(1 downto 0)
    );
end TPGMini;


-- Define architecture for top level module
architecture TPGMini of TPGMini is

  signal frame : TimingMessageType := TIMING_MESSAGE_INIT_C;

  signal baseEnable  : sl;
  signal baseEnabled : slv(4 downto 0);

  signal pulseIdn : slv(63 downto 0);

  signal pulseIdWr : sl;

  signal acTSn      : slv(2 downto 0);
  signal acTSPhasen : slv(11 downto 0);

  constant ACRateWidth : integer := 8;
  constant ACRateDepth : integer := ACRATEDEPTH;

  constant FixedRateWidth : integer := 20;
  constant FixedRateDepth : integer := FIXEDRATEDEPTH;

  signal syncReset : sl;

  signal pllChanged : slv(31 downto 0) := (others => '0');
  signal count186M  : slv(31 downto 0);
  signal countSyncE : slv(31 downto 0);

  -- Interval counters
  signal countRst              : sl;
  signal intervalCnt           : slv(31 downto 0);
  signal countBRT, countBRTn   : slv(31 downto 0);
  signal countSeq              : Slv32Array(MAXSEQDEPTH-1 downto 0);

  -- Delay registers (for closing timing)
  signal status : TPGStatusType := TPG_STATUS_INIT_C;
  signal config : TPGConfigType;

  -- Register delay for simulation
  constant tpd : time := 0.5 ns;

  constant TPG_ID : integer := 0;
  
  signal streams   : TimingSerialArray(0 downto 0);
  signal streamIds : Slv4Array(0 downto 0);
  signal advance   : slv(0 downto 0);
begin

  frame.version <= TIMING_MESSAGE_VERSION_C;

  -- Dont know about these inputs yet
  frame.bcsFault <= (others => '0');

  frame.mpsValid       <= '0';
  frame.mpsLimits      <= (others => (others => '0'));
  frame.calibrationGap <= '0';
  frame.historyActive  <= config.histActive;

  -- resources
  status.nbeamseq    <= slv(conv_unsigned(0, status.nbeamseq'length));
  status.nexptseq    <= slv(conv_unsigned(0, status.nexptseq'length));
  status.narraysbsa  <= slv(conv_unsigned(NARRAYSBSA, 8));
  status.seqaddrlen  <= slv(conv_unsigned(0, 4));
  status.fifoaddrlen <= x"0";

  status.pulseId    <= frame.pulseId;
  status.outOfSync  <= frame.syncStatus;
  status.bcsFault   <= frame.bcsFault;
  status.pllChanged <= pllChanged;
  status.count186M  <= count186M;
  status.countSyncE <= countSyncE;

  syncReset        <= '0';
  frame.resync     <= '0';
  frame.syncStatus <= '0';

  BaseEnableDivider : entity work.Divider
    generic map (
      Width => 16)
    port map (
      sysClk   => txClk,
      sysReset => syncReset,
      enable   => '1',
      clear    => '0',
      divisor  => config.baseDivisor,
      trigO    => baseEnable);

  frame.acRates <= (others=>'0');

  FixedDivider_loop : for i in 0 to FixedRateDepth-1 generate
    U_FixedDivider_1 : entity work.Divider
      generic map (
        Width => FixedRateWidth)
      port map (
        sysClk   => txClk,
        sysReset => txRst,
        enable   => baseEnable,
        clear    => '0',
        divisor  => config.FixedRateDivisors(i),
        trigO    => frame.fixedRates(i));
  end generate FixedDivider_loop;

  NoSeqBeam: for i in 0 to MAXBEAMSEQDEPTH-1 generate
    status.seqRdData(i) <= (others=>'0');
    status.seqState (i) <= SEQUENCER_STATE_INIT_C;
    countSeq        (i) <= (others=>'0');
  end generate NoSeqBeam;

  NoSeqExpt: for i in MAXBEAMSEQDEPTH to MAXBEAMSEQDEPTH+MAXEXPSEQDEPTH-1 generate
    status.seqRdData(i) <= (others=>'0');
    status.seqState (i) <= SEQUENCER_STATE_INIT_C;
    countSeq        (i) <= (others=>'0');
  end generate NoSeqExpt;

  frame.control     <= (others=>(others=>'0'));
  frame.beamRequest <= (others=>'0');
  
  BsaLoop : for i in 0 to NARRAYSBSA-1 generate
    U_BsaControl : entity work.BsaControl
      generic map (ASYNC_REGCLK_G => false)
      port map (
        sysclk     => txClk,
        sysrst     => txRst,
        bsadef     => config.bsadefv(i),
        nToAvgOut  => status.bsaStatus(i)(15 downto 0),
        avgToWrOut => status.bsaStatus(i)(31 downto 16),
        txclk      => txClk,
        txrst      => txRst,
        enable     => baseEnabled(4),
        fixedRate  => frame.fixedRates,
        acRate     => frame.acRates,
        acTS       => frame.acTimeSlot,
        beamSeq    => frame.beamRequest,
        expSeq     => frame.control,
        bsaInit    => frame.bsaInit(i),
        bsaActive  => frame.bsaActive(i),
        bsaAvgDone => frame.bsaAvgDone(i),
        bsaDone    => frame.bsaDone(i));
  end generate BsaLoop;

  GEN_NULL_BSA: if NARRAYSBSA<64 generate
    status.bsaStatus(63 downto NARRAYSBSA) <= (others => (others => '0'));
    frame.bsaInit   (63 downto NARRAYSBSA) <= (others => '0');
    frame.bsaActive (63 downto NARRAYSBSA) <= (others => '0');
    frame.bsaAvgDone(63 downto NARRAYSBSA) <= (others => '0');
    frame.bsaDone   (63 downto NARRAYSBSA) <= (others => '0');
  end generate GEN_NULL_BSA;

  U_TSerializer : entity work.TimingSerializer
    generic map ( STREAMS_C => 1 )
    port map ( clk       => txClk,
               rst       => txRst,
               fiducial  => baseEnabled(0),
               streams   => streams,
               streamIds => streamIds,
               advance   => advance,
               data      => txData,
               dataK     => txDataK );
  
  U_TPSerializer : entity work.TPSerializer
    generic map ( Id => TPG_ID )
    port map ( txClk      => txClk,
               txRst      => txRst,
               fiducial   => baseEnable,
               msg        => frame,
               advance    => advance  (0),
               stream     => streams  (0),
               streamId   => streamIds(0) );

  status.irqFifoData  <= (others=>'0');
  status.irqFifoFull  <= '0';
  status.irqFifoEmpty <= '1';

  pulseIdn <= config.pulseId when pulseIdWr = '1' else
              frame.pulseId+1 when baseEnable = '1' else
              frame.pulseId;

  acTSn      <= "001";
  acTSPhasen <= (others => '0');

  countBRTn <= (others => '0') when countRst = '1' else
               countBRT+1 when baseEnable = '1' else
               countBRT;

  process (txClk, txRst, txRdy, config)
    variable outOfSyncd : sl;
    variable txRdyd     : sl;
  begin  -- process
    if rising_edge(txClk) then
      frame.pulseId         <= pulseIdn                                              after tpd;
      pulseIdWr             <= '0';
      frame.acTimeSlot      <= acTSn                                                 after tpd;
      frame.acTimeSlotPhase <= acTSPhasen                                            after tpd;
      baseEnabled           <= baseEnabled(baseEnabled'left-1 downto 0) & baseEnable after tpd;
      count186M             <= count186M+1;
      if (frame.syncStatus = '1' and outOfSyncd = '0') then
        countSyncE <= countSyncE+1;
      end if;
      if (txRdy /= txRdyd) then
        pllChanged <= pllChanged+1;
      end if;
      outOfSyncd := frame.syncStatus;
      txRdyd     := txRdy;
      countBRT   <= countBRTn;
      if allBits(intervalCnt, '0') then  -- need to execute this when
                                         -- intervalReg is changed
        countRst         <= '1';
        status.countBRT  <= countBRT;
        status.countSeq  <= countSeq;
        intervalCnt      <= config.interval;
      else
        countRst    <= '0';
        intervalCnt <= intervalCnt-1;
      end if;
    end if;
    if txRst = '1' then
      frame.acTimeSlot      <= "001";
      frame.acTimeSlotPhase <= (others => '0');
      baseEnabled           <= (others => '0');
      count186M             <= (others => '0');
      countSyncE            <= (others => '0');
      outOfSyncd            := '1';
      countRst              <= '1';
      status.countTrig      <= (others => (others => '0'));
      status.countBRT       <= (others => '0');
      status.countSeq       <= (others => (others => '0'));
    end if;
    if config.intervalRst = '1' then
      intervalCnt <= (others => '0');
    end if;
    if config.pulseIdWrEn = '1' then
      pulseIdWr <= '0';
    end if;
  end process;

  process (txClk, txRst, countRst, frame)
    variable countUpdate : slv(1 downto 0);
    variable bsaComplete : Slv64Array(1 downto 0);
    variable bsaDoneQ    : slv(63 downto 0);
  begin  -- process
    bsaDoneQ                      := (others => '0');
    bsaDoneQ(frame.bsaDone'range) := frame.bsaDone;

    if rising_edge(txClk) then
      status.countUpdate <= countUpdate(1);
      countUpdate        := countUpdate(0) & '0';
      status.bsaComplete <= bsaComplete(1);
      bsaComplete        := (bsaComplete(0), (others => '0'));
    end if;
    if txRst = '1' then
      status.countUpdate <= '0';
      status.bsaComplete <= (others => '0');
    end if;
    if countRst = '1' then
      countUpdate := "01";
    end if;
    bsaComplete(1) := bsaComplete(1) and not bsaDoneQ;
    bsaComplete(0) := bsaComplete(0) or bsaDoneQ;
  end process;

  U_ClockTime : entity work.ClockTime
    port map (
      rst    => txRst,
      clkA   => txClk,
      wrEnA  => config.timeStampWrEn,
      wrData => config.timeStamp,
      rdData => status.timeStamp,
      clkB   => txClk,
      wrEnB  => baseEnable,
      dataO  => frame.timeStamp);

  statusO <= status;
  config  <= configI;
  
end TPGMini;
