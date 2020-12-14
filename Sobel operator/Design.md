設計構想
=======
# 1. State machine

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/state_machine.png)
<p align="center">圖七、狀態機與控制訊號</p>

# 2. 獨立的組合邏輯
># 2-1 計算位址的組合邏輯
以每次捲積圖像區域的左上角位址為pointer，捲積圖像位址計算方式為:  
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/addr.png)
<p align="center">圖八、捐積圖像計算位址</p>
並且pointer每經一個clock則+1，當pointer=255時則+3，直到pointer=66045 (最後一個捲積圖像左上角位址為66045)。

># 2-2 計算Sobel combine的組合邏輯
Sobel combine = (sobel X + sobel Y) / 2 可以用 comb = (convx_res + convy_res +1'b1) >> 1'b1; 來實現。

# 3. Control Unit
採用2C(combinatorial logic)1S(Sequential logic)標準寫法，其中Output logic、State logic、Datapath合併在一個always block中。
># Next-state logic (C1)  
  Next-state logic負責接收Datapath或Output logic傳送來的控制訊號，並輸出狀態控制訊號給next_state暫存器。  
  >>input:  
    - ready: 灰階圖像準備完成指示訊號。當訊號為 High時，表示灰階圖像準備完成，此時SOBEL才可以開始向 testfixture發送輸入灰階圖像資料索取位址。
    - conv_done: 捲積狀態完成，將進行下一個狀態(輸出捲積結果)。
    - pointer: 每次捲積圖像區域的左上角位址。
    
  >>output:
    - next_state: 將被賦值為下一個狀態。
># Output logic (C2)  
  - cwr: SOBEL運算輸出記憶體寫入致能訊號。當時脈正緣觸發時，若此訊號為High，表示要進行寫入動作。testfixture會將cdata_wr內容寫到caddr_wr所指示之位址。
  - csel: SOBLE運算處理結果寫入/讀取記憶體選擇訊號。此訊號指示目前寫入/讀取資料為SOBEL電路中哪一個的運算結果。
  - caddr_wr: SOBEL運算結果記憶體寫出訊號，由8bits整數(MSB)組成，為無號數。SOBEL電路的運算結果利用此訊號輸出至testfixture。
># State logic (S)  
  負責將next_state暫存器的值在正緣觸發時鎖進current_state。
  
# 4. 合成模擬結果與資源使用率
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/result.png)
<p align="center">圖九、合成模擬結果</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/synthesis.png)
<p align="center">圖十、資源使用率</p>
