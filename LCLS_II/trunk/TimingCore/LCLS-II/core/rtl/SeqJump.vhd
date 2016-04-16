-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SeqJump.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-15
-- Last update: 2016-04-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Calculates automated jumps in sequencer instruction RAM.
--   Reacts to BCS fault state change, MPS state change, and manual reset.
--   The manual reset is highest priority, followed by BCS, and MPS.
--   Any state change that isn't acted upon because of a higher priority reaction
--   will be enacted on the following cycle.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
LIBRARY ieee;
use work.all;

USE ieee.std_logic_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
use work.TPGPkg.all;
use work.StdRtlPkg.all;

entity SeqJump is
  generic ( MPSCHANS : integer := 5 );
  port ( 
      -- Clock and reset
      clk                : in  sl;
      rst                : in  sl;
      config             : in  TPGJumpConfigType;
      manReset           : in  sl;
      bcsFault           : in  sl;
      mpsFault           : in  slv(2 downto 0);
      jumpEn             : in  sl;
      jumpReq            : out sl;
      jumpAddr           : out SeqAddrType
      );
end SeqJump;

-- Define architecture for top level module
architecture mapping of SeqJump is 

  type RegType is record
     config     : TPGJumpConfigType;
     bcsLatch   : sl;
     mpsLatch   : slv(2 downto 0);
     jump       : sl;
     addr       : SeqAddrType;
  end record;
  constant REG_INIT_C : RegType := (
     config    => TPG_JUMPCONFIG_INIT_C,
     bcsLatch  => '0',
     mpsLatch  => (others=>'0'),
     jump => '0',
     addr  => (others=>'0') );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
begin

  jumpReq  <= r.jump;
  jumpAddr <= r.addr;
  
  comb: process (r, config, manReset, bcsFault, mpsFault, jumpEn)
     variable v : RegType;
  begin  -- process
    v      := r;
    v.jump := '0';

    --  Read in the new configuration on manual reset
    if (manReset='1') then
       v.config   := config;
    end if;

    --  Activate new jump if any state has changed
    if (jumpEn='1') then
       --  Highest priority
       if (manReset='1') then
          v.jump     := '1';
          v.addr     := config.syncJump;
       elsif (bcsFault /= r.bcsLatch) then
          v.jump     := '1';
          v.addr     := r.config.bcsJump;
          v.bcsLatch := bcsFault;
       elsif (mpsFault /= r.mpsLatch) then
          v.jump     := '1';
          v.addr     := r.config.mpsJump(conv_integer(mpsFault));
          v.mpsLatch := mpsFault;
       end if;
    end if;   
      
    rin <= v;
  end process comb;

  seq: process (clk) is
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process seq;
  
end mapping;
