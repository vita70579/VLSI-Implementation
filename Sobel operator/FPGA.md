Sobel Operator IP
=================
# 致謝
參考的課程專案資料來源為國立成功大學-陳培殷教授實驗室(Digital IC Design Lab)及課程助教提供，在此致上最誠摯的感謝!  
如有侵權煩請告知 vita70579@gmail.com

## (一) 簡介
> 索伯算子（Sobel operator）是圖像處理中的算子之一，有時又稱為索伯-費德曼算子或索貝濾波器，在影像處理及電腦視覺領域中常被用來做邊緣檢測。
在技術上，它是一離散性差分算子，用來運算圖像亮度函數的梯度之近似值。在圖像的任何一點使用此算子，索伯算子的運算將會產生對應的梯度向量或是其範數。<br>
概念上，索伯算子就是一個小且是整數的濾波器對整張影像在水平及垂直方向上做捲積，因此它所需的運算資源相對較少，另一方面，對於影像中的頻率變化較高的地方，
它所得的梯度之近似值也比較粗糙。<br>
此次作業請實作一圖像邊緣偵測系統，利用 Gx和 Gy對圖像進行捲積得出sobelX圖像及sobelY圖像，再利用得出的sobelX圖像及 sobelY圖像相加除以二得出sobelCombine的圖像。
  
## (二) 設計規格
> (1) Block overview <br>
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/block_overview.png)  
<p align="center">圖一、系統方塊圖</p>

> (2) I/O Interface <br>
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/IO.png)

> (3) Function Description <br>
本系統的輸入圖片大小為256x256存放於testfixture 的記憶體中，灰階圖像各pixels與其記憶體的對應方式如下圖四.說明。<br>
動作時序上SOBEL電路需利用iaddr發送欲索取圖像資料的位址到testfixture(如圖三t1時間點)，testfixture在每個時脈負緣後會將iaddr所指示位址之pixel資料利用idata送入SOBEL電路(如圖三t2時間點)。
本系統已經將zero_padding後的資料存於記憶體中，利用Gx、Gy分別作捲積，得出Sobel X及Sobel Y的圖，在做Sobel運算時，若值超過255就將其設定為255，
若小於0就將其值設定為0，得出Sobel X及Sobel Y的圖後，利用(sobel X+sobel Y)/2然後四捨五入的方式得到Sobel combine，當結束運算，將busy訊號拉為0，之後會開始驗證答案是否正確。<br>
本系統的記憶體存取方式，各層輸出資料記憶體L0_MEM0、L0_MEM1、L0_MEM2皆為RAM model且控制方式及時序皆相同，都可進行寫入及讀取動作。
採用不同的csel設定值啟動各層輸出相對應的記憶體，使用cwr作為寫入致能訊號，crd作為讀取致能訊號。讀取時，使用caddr_rd為記憶體位址，cdata_rd作為讀取資料訊號。<br>
動作時序如下圖五說明，當時脈正緣觸發時若crd為High，則會在觸發後立刻將caddr_rd所指示位址的資料讀取到cdata_rd上(如圖五t1時間點)。
寫入時，使用 caddr_wr為記憶體位址，cdata_wr作為寫入資料訊號。動作時序如下圖六說明，當時時脈正緣觸發時若cwr為High，則會將這時cdata_wr的資料寫入到caddr_wr所指示位址上(如圖六t1時間點)。
最終將Sobel X的資料存入記憶體L0_MEM0（2’b01），Sobel Y的資料存入記憶體L0_MEM1（2’b10），Sobel ombine的資料存入記憶體L0_MEM2（2’b11）。

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/sobel.png)
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/kernel.png)
<p align="center">圖二、Sobel operator and CNN kernel</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/timing_diogram.png)
<p align="center">圖三、timing diogram</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/memory.png)
<p align="center">圖四、灰階圖像記憶體位址</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/read.png)
<p align="center">圖五、輸出資料記憶體L0_MEM0、L0_MEM1、L0_MEM2讀取動作時序圖</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/write.png)
<p align="center">圖六、輸出資料記憶體L0_MEM0、L0_MEM1、L0_MEM2寫入動作時序圖</p>

## (三) 設計構想
### (1) State machine

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/state_machine.png)
<p align="center">圖七、狀態機與控制訊號</p>

### (2) 獨立的組合邏輯
### 2-1 計算位址的組合邏輯
以每次捲積圖像區域的左上角位址為pointer，捲積圖像位址計算方式為:  
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/addr.png)
<p align="center">圖八、捐積圖像計算位址</p>
並且pointer每經一個clock則+1，當pointer=255時則+3，直到pointer=66045 (最後一個捲積圖像左上角位址為66045)。

### 2-2 計算Sobel combine的組合邏輯
Sobel combine = (sobel X + sobel Y) / 2 可以用 comb = (convx_res + convy_res +1'b1) >> 1'b1; 來實現。

### (3) Control Unit
採用2C(combinatorial logic)1S(Sequential logic)標準寫法，其中Output logic、State logic、Datapath合併在一個always block中。
* Next-state logic (C1)  
  Next-state logic負責接收Datapath或Output logic傳送來的控制訊號，並輸出狀態控制訊號給next_state暫存器。  
  input:  
    - ready: 灰階圖像準備完成指示訊號。當訊號為 High時，表示灰階圖像準備完成，此時SOBEL才可以開始向 testfixture發送輸入灰階圖像資料索取位址。
    - conv_done: 捲積狀態完成，將進行下一個狀態(輸出捲積結果)。
    - pointer: 每次捲積圖像區域的左上角位址。
    
  output:
    - next_state: 將被賦值為下一個狀態。
* Output logic (C2)  
  - cwr: SOBEL運算輸出記憶體寫入致能訊號。當時脈正緣觸發時，若此訊號為High，表示要進行寫入動作。testfixture會將cdata_wr內容寫到caddr_wr所指示之位址。
  - csel: SOBLE運算處理結果寫入/讀取記憶體選擇訊號。此訊號指示目前寫入/讀取資料為SOBEL電路中哪一個的運算結果。
  - caddr_wr: SOBEL運算結果記憶體寫出訊號，由8bits整數(MSB)組成，為無號數。SOBEL電路的運算結果利用此訊號輸出至testfixture。
* State logic (S)  
  負責將next_state暫存器的值在正緣觸發時鎖進current_state。
  
## (四) 合成模擬結果與資源使用率
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/result.png)
<p align="center">圖九、合成模擬結果</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/Sobel%20operator/Image/synthesis.png)
<p align="center">圖十、資源使用率</p>
