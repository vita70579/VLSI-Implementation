# Approximate Average
# 致謝
參考的課程專案資料來源為國立成功大學-陳培殷教授實驗室(Digital IC Design Lab)及課程助教提供，在此致上最誠摯的感謝!  
如有侵權煩請告知 vita70579@gmail.com
## (一) 簡介
Please design a computational system whose transfer function is defined as follow.
  A series of 8-bit positive integer is generated as the input of the computational system by the test bench. The output value Y is a 10-bit positive integer,
  which is calculated according to equations (1), (2), (3) and (4).
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Approximate%20averaging/Image/form.png)  
<p align="center">圖一、演算法描述式</p>
The computational system produces the output sequence according to the given input sequence.
  Each input and output data in the respective sequence is indexed.
  This index, in terms of hardware, is the relative time when the input data is given or the output data is ready.
  Thinking as a hardware designer, the approximate average is chosen from the last n input data which should be stored in the system.
  The system should be able to calculate the integral part of the real average of the last n input data first.
  The rules of calculation is detailed in the following. If integral part of the real average equals to any one of the last n input data,
  the approximate average is simply the integral part.
  Otherwise, the approximate average is the one which is one of the last n input data whose value is smaller than and closest to the integral part of the real average.
  The above descriptions stated the desired operations as those defined by equations (1), (2), and (3).
  After the approximate average is obtained, the output value can be calculated according to equation (4).
  First, the last n input value is added by the corresponding approximate average.
  Then they are summed up and divided by n-1. The output value is the quotient after division.
  For example, assume that n=4, X1=3, X2=24, X3=16, X4=8, and X5=3.
  After the first 5 input items are given, the system should store them and calculate the output value.
  The average of the first 4 input values is 12(only shows the quotient). Since it is not in the set of {X1, X2, X3, X4},
  the system selects one from {X1, X2, X3, X4} as the approximate average whose value is smaller than 12 and close to 12.
  In this case, the approximate average is 8. So the first output value is calculated n as ⌊[(3 + 8) + (24 + 8) + (16 + 8) + (8 + 8)] /[(4 − 1)]⌋ = 27.
  Similar to those described above, when the 5th input value is given, the system should store X2, X3, X4 and X5 and calculate the corresponding output value.
  The 2nd output value should be the same as the first one because the values stored in the system is the same.

## (二) 設計規格
### (1) Block Overview
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Approximate%20averaging/Image/block_overview.png)  
<p align="center">圖二、系統方塊圖</p>

### (2) I/O Interface
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Approximate%20averaging/Image/IO.png)

### (3) Function Description
The I/O timing diagram is as shown above. For this homework, n in equations (1)-(4) are fixed to 9.
The computational system is reset by asserting reset signal for 2 periods.
The input X is changed to the next at the negative edges of the clock while output Y is checked by the test bench at positive edges of the clock.
Note that the output should be stable around the positive edges of the clock.
The setup and hold time requirements for the output are listed in Table.
The first output data should be valid after the input data changes from 9th one to 10th and before the next positive clock edge.
After that, the output should be changed to the next at the next positive clock edge and so on,
that is to say, the test bench checks one output value per clock cycle.

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Approximate%20averaging/Image/timing_diogram.png)
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Approximate%20averaging/Image/symbol.png)
<p align="center">圖三、時序圖</p>

## (三) 設計構想
### (1) Xappr
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Approximate%20averaging/Image/approximate.png)
<p align="center">圖四、近似值比較演算法</p>

### (2) Notice
盡可能不使用迴圈，迴圈在合成時會unrolling將大幅增加硬體成本。
  
## (四) 合成模擬結果與資源使用率
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Approximate%20averaging/Image/result.png)
<p align="center">圖四、合成模擬結果</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Approximate%20averaging/Image/synthesis.png)
<p align="center">圖五、資源使用率</p>
