-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TPGMiniReg.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-11-09
-- Last update: 2015-11-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Version.all;
use work.TPGPkg.all;

entity TPGMiniReg is
   generic (
      TPD_G            : time            := 1 ns;
      USE_WSTRB_G      : boolean         := false;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_OK_C);      
   port (
      -- PCIe Interface
      irqActive      : in  sl;
      irqEnable      : out sl;
      irqReq         : out sl;
      -- AXI-Lite Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- EVR Interface      
      status         : in  TPGStatusType;
      config         : out TPGConfigType;
      -- Clock and Reset
      axiClk         : in  sl;
      axiRst         : in  sl);
end TPGMiniReg;

architecture rtl of TPGMiniReg is

   constant CLKSEL     : integer := 0;
   constant BASE_CNTL  : integer := 1;
   constant PULSEIDU   : integer := 2;
   constant PULSEIDL   : integer := 3;
   constant TSTAMPU    : integer := 4;
   constant TSTAMPL    : integer := 5;
   constant FIXEDRATE0 : integer := 6;   -- 10 registers
   constant FIXEDRATE9 : integer := 15;
   constant RATERELOAD : integer := 16;
   constant HIST_CNTL  : integer := 17;
   constant FWVERSION  : integer := 18;
   constant RESOURCES  : integer := 19;
   constant BSACMPLU   : integer := 20;
   constant BSACMPLL   : integer := 21;
   constant BSADEF     : integer := 128;  -- 128 registers
   constant BSADEF_END : integer := 255;
   constant BSASTATUS  : integer := 256;  -- 64 registers
   constant BSASTATUS_END  : integer := 319;
   constant CNTPLL     : integer := 320;
   constant CNT186M    : integer := 321;
   constant CNTSYNCE   : integer := 322;
   constant CNTINTVL   : integer := 323;
   constant CNTBRT     : integer := 324;
  
   type RegType is record
                     pulseId           : slv(31 downto 0);
                     timeStamp         : slv(31 downto 0);
                     bsaComplete       : slv(63 downto 0);
                     bsaCompleteQ      : sl;
                     countUpdate       : sl;
                     FixedRateDivisors : Slv20Array(9 downto 0);
                     config            : TPGConfigType;
                     rdData            : slv(31 downto 0);
                     axiReadSlave      : AxiLiteReadSlaveType;
                     axiWriteSlave     : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
     pulseId           => (others=>'0'),
     timeStamp         => (others=>'0'),
     bsaComplete       => (others=>'0'),
     bsaCompleteQ      => '0',
     countUpdate       => '0',
     FixedRateDivisors => TPG_CONFIG_INIT_C.FixedRateDivisors,
     config            => TPG_CONFIG_INIT_C,
     rdData            => (others=>'0'),
     axiReadSlave      => AXI_LITE_READ_SLAVE_INIT_C,
     axiWriteSlave     => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, irqActive, r, status) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
      variable rdPntr       : natural;
      variable wrPntr       : natural;
      variable iseq         : natural;
      variable ichn         : natural;
      variable regWrData    : slv(31 downto 0);
      variable tmpRdData    : slv(31 downto 0);
      variable regAddr      : slv(31 downto 2);
   begin
      -- Latch the current value
      v := r;

      -- Calculate the address pointers
      wrPntr := conv_integer(axiWriteMaster.awaddr(10 downto 2));
      rdPntr := conv_integer(axiReadMaster .araddr(10 downto 2));
      regWrData := axiWriteMaster.wdata;
      
      -- Reset strobing signals
      v.config.pulseIdWrEn   := '0';
      v.config.timeStampWrEn := '0';
      v.config.intervalRst   := '0';
      
      -- Determine the transaction type

      -----------------------------
      -- AXI-Lite Write Logic
      -----------------------------      
      axiSlaveWaitWriteTxn(axiWriteMaster,v.axiWriteSlave,axiStatus.writeEnable);

      if (axiStatus.writeEnable = '1') then
        regAddr := axiWriteMaster.awaddr(regAddr'range);
        -- Check for alignment
        if axiWriteMaster.awaddr(1 downto 0) = "00" then
          -- Address is aligned
          axiWriteResp          := AXI_RESP_OK_C;

          case wrPntr is
            when BASE_CNTL => v.config.baseDivisor             := regWrData(15 downto 0);
            when PULSEIDU  => v.config.pulseId(63 downto 32)   := regWrData;
            when PULSEIDL  => v.config.pulseId(31 downto  0)   := regWrData;
                              v.config.pulseIdWrEn             := '1';
            when TSTAMPU   => v.config.timeStamp(63 downto 32) := regWrData;
            when TSTAMPL   => v.config.timeStamp(31 downto  0) := regWrData;
                              v.config.timeStampWrEn           := '1'                 ;
            when FIXEDRATE0+0 => v.FixedRateDivisors(0)        := regWrData(19 downto 0);
            when FIXEDRATE0+1 => v.FixedRateDivisors(1)        := regWrData(19 downto 0);
            when FIXEDRATE0+2 => v.FixedRateDivisors(2)        := regWrData(19 downto 0);
            when FIXEDRATE0+3 => v.FixedRateDivisors(3)        := regWrData(19 downto 0);
            when FIXEDRATE0+4 => v.FixedRateDivisors(4)        := regWrData(19 downto 0);
            when FIXEDRATE0+5 => v.FixedRateDivisors(5)        := regWrData(19 downto 0);
            when FIXEDRATE0+6 => v.FixedRateDivisors(6)        := regWrData(19 downto 0);
            when FIXEDRATE0+7 => v.FixedRateDivisors(7)        := regWrData(19 downto 0);
            when FIXEDRATE0+8 => v.FixedRateDivisors(8)        := regWrData(19 downto 0);
            when FIXEDRATE0+9 => v.FixedRateDivisors(9)        := regWrData(19 downto 0);
            when RATERELOAD => v.config.FixedRateDivisors      := v.FixedRateDivisors;
            when HIST_CNTL  => v.config.histActive             := regWrData(0);
            when BSACMPLU   => v.bsaComplete(63 downto 32)     := v.bsaComplete(63 downto 32) and not regWrData;
            when BSACMPLL   => v.bsaComplete(31 downto  0)     := v.bsaComplete(31 downto  0) and not regWrData;
            when BSADEF to BSADEF_END =>
              iseq               := conv_integer(regAddr(8 downto 3));
              if regAddr(2)='0' then
                v.config.bsadefv(iseq).rateSel  := regWrData(15 downto  0);
                v.config.bsadefv(iseq).destSel  := regWrData(31 downto 16);
                v.config.bsadefv(iseq).init     := '0';
              else
                v.config.bsadefv(iseq).nToAvg   := regWrData(15 downto  0);
                v.config.bsadefv(iseq).avgToWr  := regWrData(31 downto 16);
                v.config.bsadefv(iseq).init     := '1';
              end if;
            when CNTINTVL   => v.config.interval    := regWrData;
                               v.config.intervalRst := '1';
            when others  => axiWriteResp := AXI_ERROR_RESP_G;
          end case;
        else
          axiWriteResp := AXI_ERROR_RESP_G;
        end if;
        -- Send AXI response
        axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      end if;
      
      -----------------------------
      -- AXI-Lite Read Logic
      -----------------------------      

      axiSlaveWaitReadTxn(axiReadMaster,v.axiReadSlave,axiStatus.readEnable);

      if (axiStatus.readEnable = '1') then
        regAddr   := axiReadMaster.araddr(regAddr'range);
        tmpRdData := (others=>'0');
        -- Check for alignment
        if axiReadMaster.araddr(1 downto 0) = "00" then
          -- Address is aligned
          axiReadResp           := AXI_RESP_OK_C;
          -- Decode the read address
          case rdPntr is
            when BASE_CNTL  => tmpRdData(15 downto 0) := r.config.baseDivisor;
            when PULSEIDU   => tmpRdData              := status.pulseId(63 downto 32);
                               v.pulseId              := status.pulseId(31 downto  0);
            when PULSEIDL   => tmpRdData              := r.pulseId;
            when TSTAMPU    => tmpRdData              := status.timeStamp(63 downto 32);
                               v.timeStamp            := status.timeStamp(31 downto  0);
            when TSTAMPL    => tmpRdData              := r.timeStamp;
            when FIXEDRATE0+0 => tmpRdData(19 downto 0) := r.config.FixedRateDivisors(0);
            when FIXEDRATE0+1 => tmpRdData(19 downto 0) := r.config.FixedRateDivisors(1);
            when FIXEDRATE0+2 => tmpRdData(19 downto 0) := r.config.FixedRateDivisors(2);
            when FIXEDRATE0+3 => tmpRdData(19 downto 0) := r.config.FixedRateDivisors(3);
            when FIXEDRATE0+4 => tmpRdData(19 downto 0) := r.config.FixedRateDivisors(4);
            when FIXEDRATE0+5 => tmpRdData(19 downto 0) := r.config.FixedRateDivisors(5);
            when FIXEDRATE0+6 => tmpRdData(19 downto 0) := r.config.FixedRateDivisors(6);
            when FIXEDRATE0+7 => tmpRdData(19 downto 0) := r.config.FixedRateDivisors(7);
            when FIXEDRATE0+8 => tmpRdData(19 downto 0) := r.config.FixedRateDivisors(8);
            when FIXEDRATE0+9 => tmpRdData(19 downto 0) := r.config.FixedRateDivisors(9);
            when HIST_CNTL  => tmpRdData(0)                   := r.config.histActive;
            when FWVERSION  => tmpRdData                      := FPGA_VERSION_C;
            when RESOURCES  => tmpRdData(23 downto 0) := status.fifoaddrlen &
                                                         status.seqaddrlen &
                                                         status.narraysbsa &
                                                         status.nexptseq &
                                                         status.nbeamseq;
            when BSACMPLU   => tmpRdData              := r.bsaComplete(63 downto 32);
            when BSACMPLL   => tmpRdData              := r.bsaComplete(31 downto  0);
            when BSADEF to BSADEF_END =>
              iseq      := conv_integer(regAddr(8 downto 3));
              if regAddr(2)='0' then
                tmpRdData := r.config.bsadefv(iseq).destSel & r.config.bsadefv(iseq).rateSel;
              else
                tmpRdData := r.config.bsadefv(iseq).avgToWr & r.config.bsadefv(iseq).nToAvg;
              end if;
            when CNTPLL     => tmpRdData := status.pllChanged;
            when CNT186M    => tmpRdData := status.count186M;
            when CNTSYNCE   => tmpRdData := status.countSyncE;
            when CNTINTVL   => tmpRdData := r.config.interval;
            when CNTBRT     => tmpRdData := status.countBRT;
            when others     => axiReadResp := AXI_ERROR_RESP_G;
          end case;
          v.axiReadSlave.rdata := tmpRdData;
          -- Send AXI response
          axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
        else
          axiSlaveReadResponse(v.axiReadSlave, AXI_ERROR_RESP_G);
        end if;
      end if;
      
      -- Misc. Mapping and Logic
      if allBits(status.bcsFault,'0') then
        v.config.histActive := '0';
      end if;
      v.bsaComplete := v.bsaComplete or (status.bsaComplete and not r.bsaComplete);
      if allBits(r.bsaComplete,'0') then
        v.bsaCompleteQ := '0';
      else
        v.bsaCompleteQ := '1';
      end if;

      -- Synchronous Reset
      if axiRst = '1' then
        v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiWriteSlave   <= r.axiWriteSlave;
      axiReadSlave    <= r.axiReadSlave;
      config          <= r.config;

      irqEnable       <= '0';
      irqReq          <= '0';
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;