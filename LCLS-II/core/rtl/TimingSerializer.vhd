-------------------------------------------------------------------------------
-- Title      : TimingSerializer
-------------------------------------------------------------------------------
-- File       : TimingSerializer.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-15
-- Last update: 2018-02-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generates a 16b serial stream of the LCLS-II timing message.
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
use work.StdRtlPkg.all;
use work.TimingPkg.all;
use work.CrcPkg.all;
use work.Ila_256Pkg.all;

library xil_defaultlib;

entity TimingSerializer is
   generic (
      TPD_G : time := 1 ns;
      STREAMS_C : integer := 1 );
   port (
      -- Clock and reset
      clk       : in  sl;
      rst       : in  sl;
      fiducial  : in  sl;
      streams   : in  TimingSerialArray(STREAMS_C-1 downto 0);
      streamIds : in  Slv4Array        (STREAMS_C-1 downto 0);
      advance   : out slv              (STREAMS_C-1 downto 0);
      data      : out slv(15 downto 0);
      dTrigO    : out DbgTrigType := DTRIG_INIT_C;
      dTrigI    : in  DbgTrigType := DTRIG_INIT_C;
      dataK     : out slv(1 downto 0));
end TimingSerializer;

-- Define architecture for top level module
architecture TimingSerializer of TimingSerializer is

   type StateType is (IDLE_S,  SOF_S, SOS_S, SEGMENT_S, EOF_S, CRC1_S, CRC2_S, CRC3_S);
   type RegType is
   record
      state      : StateType;
      stream     : integer range 0 to STREAMS_C-1;
      ready      : slv(STREAMS_C-1 downto 0);
      advance    : slv(STREAMS_C-1 downto 0);
      crcReset   : sl;
      crcValid   : sl;
      data       : slv(15 downto 0);
      dataK      : slv( 1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      state      => IDLE_S,
      stream     => 0,
      ready      => (others=>'0'),
      advance    => (others=>'0'),
      crcReset   => '0',
      crcValid   => '0',
      data       => (D_215_C & K_COM_C),
      dataK      => "01");

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  signal crc : slv(31 downto 0);
  signal dataLoc : slv(15 downto 0);
  signal dataKLoc : slv(1 downto 0);
  
begin

  advance  <= rin.advance;
  dataLoc     <= crc(15 downto  0) when r.state=CRC2_S else
              crc(31 downto 16) when r.state=CRC3_S else
              r.data;
  dataKLoc    <= r.dataK;
  
  data  <= dataLoc;
  dataK <= dataKLoc;
  
  
  U_CRC : entity work.Crc32Parallel
    generic map ( TPD_G=>TPD_G, BYTE_WIDTH_G => 2, CRC_INIT_G => x"FFFFFFFF" )
    port map ( crcOut       => crc,
               crcClk       => clk,
               crcDataValid => rin.crcValid,
               crcDataWidth => "001",
               crcIn        => rin.data,
               crcReset     => r.crcReset );

  U_Ila : component work.Ila_256Pkg.Ila_256
    port map (
      clk          => clk,
      trig_out     => dTrigO.sig,
      trig_out_ack => dTrigI.ack,
      trig_in      => dTrigI.sig,
      trig_in_ack  => dTrigO.ack,
      probe0(15 downto  0) => r.data,
      probe0(17 downto 16) => r.dataK,
      probe0(18          ) => r.crcReset,
      probe0(19          ) => r.crcValid,
      probe0(20          ) => fiducial,
      probe0(21          ) => r.advance(0),
      probe0(31 downto 22) => (others => '0'),
      probe0(63 downto 32) => crc,

      probe1(15 downto  0) => dataLoc,
      probe1(17 downto 16) => dataKLoc,
      probe1(18          ) => streams(0).ready,
      probe1(19          ) => streams(0).last,
      probe1(23 downto 20) => streamIds(0),
      probe1(30 downto 24) => streams(0).offset,
      probe1(31          ) => '0',
      probe1(47 downto 32) => streams(0).data,
      probe1(63 downto 48) => (others => '0'),
      probe2       => (others => '0'),
      probe3       => (others => '0')
    );
  
  comb: process (rst, fiducial, streams, streamIds, r)
    variable v    : RegType;
    variable istr : integer;
  begin 
      v := r;

      v.crcReset := '0';
      v.crcValid := '0';
      v.advance  := (others=>'0');
      
      case (r.state) is
        when IDLE_S => 
          if fiducial = '1' then
            v.data  := D_215_C & K_281_C; -- special 4-byte alignment comma
            v.state := SOF_S;
          else
            v.data  := D_215_C & K_COM_C;
            v.dataK := "01";
          end if;
        when SOF_S =>
          -- Queue the start of frame
          v.data  := D_215_C & K_SOF_C;
          v.dataK := "01";
          v.crcReset:= '1';
          -- Latch the streams that are ready to send
          v.state   := EOF_S;  -- if no streams are ready: empty frame
          v.ready   := (others=>'0');
          for i in STREAMS_C-1 downto 0 loop
            if (streams(i).ready='1') then
              v.ready(i) := '1';
              v.state    := SOS_S;
              v.stream   := i;
            end if;
          end loop;
        when SOS_S =>
          -- Queue the segment header
          v.data  := streamIds(r.stream) & "0000" & streams(r.stream).last & streams(r.stream).offset;
          v.dataK := "00";
          v.state   := SEGMENT_S;
          v.ready(r.stream) := '0';
          v.crcValid:= '1';
        when SEGMENT_S =>
          -- Check for end of stream
          if (streams(r.stream).ready='0') then
            v.data  := D_215_C & K_EOS_C;
            v.dataK := "01";
            v.state   := EOF_S;
            for i in STREAMS_C-1 downto 0 loop
              if (r.ready(i)='1') then
                v.state    := SOS_S;
                v.stream   := i;
              end if;
            end loop;
          else
            -- Send next word in stream
            v.data  := streams(r.stream).data;
            v.dataK := "00";
            v.advance(r.stream) := '1';
          end if;
          v.crcValid:= '1';
        when EOF_S =>
          v.data  := D_215_C & K_EOF_C;
          v.dataK := "01";
          v.state := CRC1_S;
          v.crcValid:= '1';
        when CRC1_S =>
          v.dataK := "00";
          v.state := CRC2_S;
        when CRC2_S =>
          v.dataK := "00";
          v.state := CRC3_S;
        when CRC3_S =>
          v.dataK := "01";
          v.data  := D_215_C & K_COM_C;
          v.state := IDLE_S;
        when others => null;
      end case;

      if (rst='1') then
        v := REG_INIT_C;
      end if;
      
      rin <= v;

   end process;

   process (clk)
   begin  -- process
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process;

end TimingSerializer;
