library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.common_pack.all;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity cmdProc is
port(
 clk:		in std_logic;
 reset:		in std_logic;
 rxnow:		in std_logic;
 rxData:    in std_logic_vector (7 downto 0);
 txData:	out std_logic_vector (7 downto 0);
 rxdone:	out std_logic;
 ovErr:		in std_logic;
 framErr:	in std_logic;
 txnow:		out std_logic;
 txdone:	in std_logic;
 start:     out std_logic;
 numWords_bcd:out BCD_ARRAY_TYPE(2 downto 0);
 dataReady: in std_logic;
 byte:      in std_logic_vector(7 downto 0);
 maxIndex:  in BCD_ARRAY_TYPE(2 downto 0);
 dataResults:in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
 seqDone:   in std_logic
  );
end;

ARCHITECTURE myarch OF cmdProc IS

  COMPONENT counter
	PORT(
	     clk: in std_logic;
             rst: in std_logic;
       	     en: in std_logic;
             cntOut: out std_logic_vector(5 downto 0)
	     );
  END COMPONENT;
  SIGNAL rst0, en0:STD_LOGIC;
  SIGNAL cnt0Out:STD_LOGIC_VECTOR(5 downto 0);
  
  COMPONENT reg
    PORT(
	 clk: in std_logic;
	 regreset: in std_logic;
         load: in std_logic;
         D: in std_logic_vector(7 downto 0);
         Q: out std_logic_vector(7 downto 0)
         );
    END COMPONENT;
	SIGNAL regreset0, load0: std_logic;
	SIGNAL D0, Q0: std_logic_vector(7 downto 0);
	
	COMPONENT shift
	   PORT (
        shift_in : in std_logic_vector(7 downto 0); -- DATA IN
        en_shift : in std_logic; -- CHIP ENABLE
        load_shift : in std_logic;
        clk : in std_logic; -- CLOCK
        shift_out : out BCD_ARRAY_TYPE(2 downto 0) -- SHIFTER OUTPUT
        );
    END COMPONENT;
    SIGNAL shift_in: std_logic_vector(7 downto 0);              
    SIGNAL shift_out: BCD_ARRAY_TYPE(2 downto 0);
    SIGNAL en1, load1 : std_logic;
     
  FOR cnt0: counter USE ENTITY work.myCounter(Behavioral); 
  FOR reg0: reg USE ENTITY work.myRegister(Behavioral);
  FOR shift0: shift USE ENTITY work.shift(shift_arch);  
  TYPE state_type IS (STATE1,INIT,COUNT_CHECK, A_CHECK, NUM_CHECK, ERROR, CORRECT_WORD, SHIFTER,WAIT_SHIFT, START1, TRANSMIT, TRANSMIT2, TRANSMIT2_OFF, data_check, Data_Ready); 
  SIGNAL curState, nextState: state_type;


BEGIN 
 cnt0: counter PORT MAP(clk, rst0, en0, cnt0Out);
 reg0: reg PORT MAP(clk, regreset0, load0, D0, Q0); 
 shift0: shift PORT MAP(shift_in,en1,load1,clk,shift_out);
 
 combi_nextState: PROCESS(curState, rxNow, rxData, cnt0Out)
  BEGIN    
    CASE curState IS
	
	WHEN STATE1 =>
	nextState <= INIT;
	
	WHEN INIT =>
	 if rxNow = '1' then 
		nextState <= COUNT_CHECK;
	 else 
		nextState <= curState;
	 end if; 
	 
	WHEN COUNT_CHECK =>
	 if cnt0Out = "000000" then
	    nextState <= A_CHECK;
	 else
		nextState <= NUM_CHECK;
	 end if;
	 
	WHEN A_CHECK =>
	 if rxData = "01000001" then --if dataIn = A
	    nextState <= CORRECT_WORD;
	 elsif rxData = "01100001" then --if dataIn = a
	    nextState <= CORRECT_WORD;
	 else
		nextState<= ERROR;
	 end if;
	 
	WHEN NUM_CHECK =>
	 if rxData = "00110000" then  --0
		nextState <= CORRECT_WORD;
	elsif rxData = "00110001" then --1
		nextState <= CORRECT_WORD;
	elsif rxData = "00110010" then --2
		nextState <= CORRECT_WORD;
	elsif rxData = "00110011" then --3
		nextState <= CORRECT_WORD;
	elsif rxData = "00110100" then --4
		nextState <= CORRECT_WORD;
	elsif rxData = "00110101" then --5
		nextState <= CORRECT_WORD;
	elsif rxData = "00110110" then --6
		nextState <= CORRECT_WORD;
	elsif rxData = "00110111" then --7
		nextState <= CORRECT_WORD;
	elsif rxData = "00111000" then --8
		nextState <= CORRECT_WORD;
	elsif rxData = "00111001" then --9
		nextState <= CORRECT_WORD;
	else 
		nextState <= INIT;
	end if; 
	
	WHEN ERROR => 
		nextState <= INIT;
	
	WHEN CORRECT_WORD =>
	  if (cnt0Out <= "000011") and (cnt0Out > "000000" ) then
	  nextState <= SHIFTER;                                 
	  elsif 
             cnt0Out = "000000" then 
		nextState <= INIT;
	  else
	  nextState <= curState;
	  end if; 
	
	
	
	  
   WHEN SHIFTER =>
	 if cnt0Out >= "000100" then 
	 NextState <= WAIT_SHIFT;        
	 else  
	   nextState <= INIT;
	 end if;
	
	WHEN WAIT_SHIFT =>
	  nextState <= START1;

	WHEN START1 =>
	  nextState <= TRANSMIT; 
	
		
	WHEN TRANSMIT2 =>
	  nextState <= TRANSMIT2_OFF;
	  
	WHEN TRANSMIT2_OFF =>
	  if txDone = '1' then 
	    nextState <= data_check;
	  else
	  nextState <= curState; 
          end if;
		
	WHEN data_check =>
	  if seqDone = '1' then 
 	    nextState <= Data_Ready; 
	  else 
	    nextState <= TRANSMIT2_OFF;
	  end if; 
	
	WHEN Data_Ready =>
	  nextState <= INIT; 
	  
	 WHEN others =>
	   nextState <= INIT;
	
    end CASE;
  end PROCESS; 

  combi_out: PROCESS(curState)
  BEGIN
  
  --inital conditions 
  en0 <= '0';
  rst0 <= '0';
  regreset0 <= '0';
  load0 <= '0';
  load1 <= '0';
  rxdone <= '0';
  txData <= Q0;
  en1 <= '0';
  shift_in <= rxdata;
  start <= '0';
  numWords_bcd <= shift_out;
  --if curState = INIT then 
  --INITIAL CONDITIONS 
  --end if;
  if curState = STATE1 then
  rst0 <= '1';
  end if;
  
  if curState = COUNT_CHECK then
  D0 <= rxData;
  end if;
  
  if curState = A_CHECK then 
  load0 <= '1';
  end if; 
  
  if curState = NUM_CHECK then 
  load0 <= '1'; 
  end if; 
  
  if curState = ERROR then 
  rst0 <= '1';
  rxdone <= '1';
  txData <= Q0;
  end if; 
  
  if curState = CORRECT_WORD then 
  en0 <= '1';
  rxdone <= '1';
  txData <= Q0;-- need to find number of clock cycles for when there are 3 numbers. 
  end if; 
  
  if curState = SHIFTER then
  en1 <= '1';
  end if;

  if curState = WAIT_SHIFT then 
  load1 <= '1'; 
  --NNN
  end if; 
  
  if curState = START1 then   
  start <= '1';               
  end if; 
  
  if curState = TRANSMIT2_OFF then 
  txNow <= '0'; 
  end if; 
  
  END PROCESS; 

  seq_state: PROCESS (clk, reset)
  BEGIN
    if reset = '1' then
      curState <= STATE1;
    elsif clk'EVENT AND clk='1' then
      curState <= nextState;
    end if;
  end PROCESS;
end;