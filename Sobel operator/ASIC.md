設備與環境設定
=============
1. VMware 16.0虛擬機掛載 centos7作業系統
2. Synopsys Design compiler-2016
3. TSMC090製程

時脈規格
=======
1. clock period (Tclk) = 3ns
2. source latency = 0.7ns
3. network latency = 0.3ns
4. clock skew = 0.03ns
5. jitter = 0.04ns
6. setup magin = 0.05ns
7. transition = 0.12ns
8. register setup time = 0.2ns

- 由4.5.6.可得setup uncertainty = 0.3 + 0.3 + 0.04 + 0.05 = 0.15ns

環境條件
=======
1. input ports(drivers):
  >- Specify a drive on all inputs, except **clk, reset, ready** and **busy**, using the buffer **bufbd1** in the library.
  - The 
 
系統方塊圖
=========
