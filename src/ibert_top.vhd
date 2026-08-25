library ieee;
use ieee.std_logic_1164.all;

entity ibert_top is
  port (
    p_lf_r0_ad, n_lf_r0_ad : in std_logic;
    p_lf_r0_af, n_lf_r0_af : in std_logic;
    p_lf_r0_r,  n_lf_r0_r  : in std_logic;
    p_lf_r0_u,  n_lf_r0_u  : in std_logic;
    p_lf_r0_w,  n_lf_r0_w  : in std_logic;
    p_lf_r0_y,  n_lf_r0_y  : in std_logic;
    p_rt_r0_n,  n_rt_r0_n  : in std_logic;
    p_rt_r0_p,  n_rt_r0_p  : in std_logic;
    p_rt_r0_b,  n_rt_r0_b  : in std_logic;
    p_rt_r0_e,  n_rt_r0_e  : in std_logic;
    p_rt_r0_g,  n_rt_r0_g  : in std_logic;
    p_rt_r0_i,  n_rt_r0_i  : in std_logic;

    p_ff1_recv, n_ff1_recv : in  std_logic_vector(11 downto 0);
    p_ff1_xmit, n_ff1_xmit : out std_logic_vector(11 downto 0);
    p_ff2_recv, n_ff2_recv : in  std_logic_vector(11 downto 0);
    p_ff2_xmit, n_ff2_xmit : out std_logic_vector(11 downto 0);
    p_ff3_recv, n_ff3_recv : in  std_logic_vector(11 downto 0);
    p_ff3_xmit, n_ff3_xmit : out std_logic_vector(11 downto 0);
    p_ff4_recv, n_ff4_recv : in  std_logic_vector(11 downto 0);
    p_ff4_xmit, n_ff4_xmit : out std_logic_vector(11 downto 0);
    p_ff5_recv, n_ff5_recv : in  std_logic_vector(3 downto 0);
    p_ff5_xmit, n_ff5_xmit : out std_logic_vector(3 downto 0);
    p_ff6_recv, n_ff6_recv : in  std_logic_vector(3 downto 0);
    p_ff6_xmit, n_ff6_xmit : out std_logic_vector(3 downto 0);

    p_a_recv, n_a_recv : in std_logic_vector(3 downto 0); p_a_xmit, n_a_xmit : out std_logic_vector(3 downto 0);
    p_b_recv, n_b_recv : in std_logic_vector(3 downto 0); p_b_xmit, n_b_xmit : out std_logic_vector(3 downto 0);
    p_c_recv, n_c_recv : in std_logic_vector(3 downto 0); p_c_xmit, n_c_xmit : out std_logic_vector(3 downto 0);
    p_d_recv, n_d_recv : in std_logic_vector(3 downto 0); p_d_xmit, n_d_xmit : out std_logic_vector(3 downto 0);
    p_e_recv, n_e_recv : in std_logic_vector(3 downto 0); p_e_xmit, n_e_xmit : out std_logic_vector(3 downto 0);
    p_f_recv, n_f_recv : in std_logic_vector(3 downto 0); p_f_xmit, n_f_xmit : out std_logic_vector(3 downto 0);
    p_g_recv, n_g_recv : in std_logic_vector(3 downto 0); p_g_xmit, n_g_xmit : out std_logic_vector(3 downto 0);
    p_h_recv, n_h_recv : in std_logic_vector(3 downto 0); p_h_xmit, n_h_xmit : out std_logic_vector(3 downto 0);
    p_i_recv, n_i_recv : in std_logic_vector(3 downto 0); p_i_xmit, n_i_xmit : out std_logic_vector(3 downto 0);
    p_j_recv, n_j_recv : in std_logic_vector(3 downto 0); p_j_xmit, n_j_xmit : out std_logic_vector(3 downto 0);
    p_m_recv, n_m_recv : in std_logic_vector(3 downto 0); p_m_xmit, n_m_xmit : out std_logic_vector(3 downto 0);
    p_n_recv, n_n_recv : in std_logic_vector(3 downto 0); p_n_xmit, n_n_xmit : out std_logic_vector(3 downto 0);
    p_o_recv, n_o_recv : in std_logic_vector(3 downto 0); p_o_xmit, n_o_xmit : out std_logic_vector(3 downto 0);
    p_p_recv, n_p_recv : in std_logic_vector(3 downto 0); p_p_xmit, n_p_xmit : out std_logic_vector(3 downto 0);
    left_refclk_odiv2  : out std_logic_vector(5 downto 0);
    right_refclk_odiv2 : out std_logic_vector(5 downto 0);
    left_ibert_sysclk  : out std_logic;
    right_ibert_sysclk : out std_logic
  );
end entity ibert_top;

architecture rtl of ibert_top is
  function reverse_bits(value : std_logic_vector) return std_logic_vector is
    variable result : std_logic_vector(value'range);
  begin
    for index in value'range loop
      result(index) := value(value'left + value'right - index);
    end loop;
    return result;
  end function;

  signal left_refclk_p  : std_logic_vector(5 downto 0);
  signal left_refclk_n  : std_logic_vector(5 downto 0);
  signal right_refclk_p : std_logic_vector(5 downto 0);
  signal right_refclk_n : std_logic_vector(5 downto 0);

  signal left_rx_p  : std_logic_vector(55 downto 0);
  signal left_rx_n  : std_logic_vector(55 downto 0);
  signal left_tx_p  : std_logic_vector(55 downto 0);
  signal left_tx_n  : std_logic_vector(55 downto 0);
  signal right_rx_p : std_logic_vector(55 downto 0);
  signal right_rx_n : std_logic_vector(55 downto 0);
  signal right_tx_p : std_logic_vector(55 downto 0);
  signal right_tx_n : std_logic_vector(55 downto 0);
begin
  -- Pack each generated-IBERT formal into one signal. Vivado does not permit
  -- multiple slice associations of the same formal port in a port map.
  left_refclk_p  <= p_lf_r0_y & p_lf_r0_w & p_lf_r0_u & p_lf_r0_r & p_lf_r0_af & p_lf_r0_ad;
  left_refclk_n  <= n_lf_r0_y & n_lf_r0_w & n_lf_r0_u & n_lf_r0_r & n_lf_r0_af & n_lf_r0_ad;
  right_refclk_p <= p_rt_r0_i & p_rt_r0_g & p_rt_r0_e & p_rt_r0_b & p_rt_r0_p & p_rt_r0_n;
  right_refclk_n <= n_rt_r0_i & n_rt_r0_g & n_rt_r0_e & n_rt_r0_b & n_rt_r0_p & n_rt_r0_n;

  -- FireFly 3 is numbered opposite the GTY site order (130/3 down to 128/0).
  left_rx_p <= p_ff4_recv & p_ff6_recv & reverse_bits(p_ff3_recv) & p_ff2_recv & p_ff5_recv & p_ff1_recv;
  left_rx_n <= n_ff4_recv & n_ff6_recv & reverse_bits(n_ff3_recv) & n_ff2_recv & n_ff5_recv & n_ff1_recv;

  p_ff1_xmit <= left_tx_p(11 downto 0);
  n_ff1_xmit <= left_tx_n(11 downto 0);
  p_ff5_xmit <= left_tx_p(15 downto 12);
  n_ff5_xmit <= left_tx_n(15 downto 12);
  p_ff2_xmit <= left_tx_p(27 downto 16);
  n_ff2_xmit <= left_tx_n(27 downto 16);
  p_ff3_xmit <= reverse_bits(left_tx_p(39 downto 28));
  n_ff3_xmit <= reverse_bits(left_tx_n(39 downto 28));
  p_ff6_xmit <= left_tx_p(43 downto 40);
  n_ff6_xmit <= left_tx_n(43 downto 40);
  p_ff4_xmit <= left_tx_p(55 downto 44);
  n_ff4_xmit <= left_tx_n(55 downto 44);

  right_rx_p <= p_j_recv & p_i_recv & p_h_recv & p_g_recv & p_f_recv & p_e_recv &
                p_d_recv & p_c_recv & p_b_recv & p_a_recv & p_p_recv & p_o_recv &
                p_n_recv & p_m_recv;
  right_rx_n <= n_j_recv & n_i_recv & n_h_recv & n_g_recv & n_f_recv & n_e_recv &
                n_d_recv & n_c_recv & n_b_recv & n_a_recv & n_p_recv & n_o_recv &
                n_n_recv & n_m_recv;

  p_m_xmit <= right_tx_p(3 downto 0);    n_m_xmit <= right_tx_n(3 downto 0);
  p_n_xmit <= right_tx_p(7 downto 4);    n_n_xmit <= right_tx_n(7 downto 4);
  p_o_xmit <= right_tx_p(11 downto 8);   n_o_xmit <= right_tx_n(11 downto 8);
  p_p_xmit <= right_tx_p(15 downto 12);  n_p_xmit <= right_tx_n(15 downto 12);
  p_a_xmit <= right_tx_p(19 downto 16);  n_a_xmit <= right_tx_n(19 downto 16);
  p_b_xmit <= right_tx_p(23 downto 20);  n_b_xmit <= right_tx_n(23 downto 20);
  p_c_xmit <= right_tx_p(27 downto 24);  n_c_xmit <= right_tx_n(27 downto 24);
  p_d_xmit <= right_tx_p(31 downto 28);  n_d_xmit <= right_tx_n(31 downto 28);
  p_e_xmit <= right_tx_p(35 downto 32);  n_e_xmit <= right_tx_n(35 downto 32);
  p_f_xmit <= right_tx_p(39 downto 36);  n_f_xmit <= right_tx_n(39 downto 36);
  p_g_xmit <= right_tx_p(43 downto 40);  n_g_xmit <= right_tx_n(43 downto 40);
  p_h_xmit <= right_tx_p(47 downto 44);  n_h_xmit <= right_tx_n(47 downto 44);
  p_i_xmit <= right_tx_p(51 downto 48);  n_i_xmit <= right_tx_n(51 downto 48);
  p_j_xmit <= right_tx_p(55 downto 52);  n_j_xmit <= right_tx_n(55 downto 52);

  u_ibert_left : entity work.ibert_ultrascale_gty_l
    port map (
      gty_refclk0p_i       => left_refclk_p,
      gty_refclk0n_i       => left_refclk_n,
      gty_refclk0_odiv2_o => left_refclk_odiv2,
      gty_sysclk_o         => left_ibert_sysclk,
      gty_rxp_i            => left_rx_p,
      gty_rxn_i            => left_rx_n,
      gty_txp_o            => left_tx_p,
      gty_txn_o            => left_tx_n
    );

  u_ibert_right : entity work.ibert_ultrascale_gty_r
    port map (
      gty_refclk0p_i       => right_refclk_p,
      gty_refclk0n_i       => right_refclk_n,
      gty_refclk0_odiv2_o => right_refclk_odiv2,
      gty_sysclk_o         => right_ibert_sysclk,
      gty_rxp_i            => right_rx_p,
      gty_rxn_i            => right_rx_n,
      gty_txp_o            => right_tx_p,
      gty_txn_o            => right_tx_n
    );
end architecture;
