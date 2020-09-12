# RC4 Encryption and Decryption Circuit IP
# 致謝
參考的課程專案資料來源為國立成功大學-陳培殷教授實驗室(Digital IC Design Lab)及課程助教提供，在此致上最誠摯的感謝!  
如有侵權煩請告知 vita70579@gmail.com
## (一) 簡介
在密碼學中，RC4（來自 Rivest Cipher 4的縮寫）是一種流加密算法，密鑰長度可變。它加解密使用相同的密鑰，因此也屬於對稱加密算法。
  RC4是有線等效加密（WEP）中採用的加密算法，也曾經是TLS可採用的算法之一。
  由於 RC4算法存在弱點，2015年 2月所發布的RFC7465規定禁止在TLS中使用 RC4加密算法。
  RC4由偽隨機數生成器和異或運算組成。RC4的密鑰長度可變，範圍是[1,255]。RC4一個字節一個字節地加解密。
  給定一個密鑰，偽隨機數生成器接受密鑰並產生一個Sbox。 Sbox用來加密數據，而且在加密過程中Sbox會變化。
  由於異或運算的對合性，RC4加密解密使用同一套算法。
  此次作業請實作一個RC4加解密的電路，其中密鑰的長度固定為32bytes，明文的長度為不固定，最長長度不超過2048bytes，
  Sbox大小為64bytes利用輸入金鑰對明文進行加密，然後將加密完的字元輸出，再將所輸出加密的字元輸入，進行解密，還原出原本的明文。

## (二) 設計規格
### (1) Block Overview
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/block_overview.png)  
<p align="center">圖一、系統方塊圖</p>

### (2) I/O Interface
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/IO.png)

### (3) Function Description
本系統的key長度為32bytes，而明文的長度為不固定，最長為2048bytes，key的資料儲存於testfixture中，
  在系統進行reset之後，下一個cycle 會先輸出key_valid= high然後再過一個cycle後輸出key的值，
  當key_valid為high(除了第一個cycle)時代表key 值有效，當key 值輸入完畢後，同學需先將key跟Sbox進行打亂，
  Sbox一開始為0~63，利用圖四的Pseudo code進行打亂後，再利用打亂後的Sbox進行加密，加密演算法如圖五的Pseudo code，
  當加密完成後的密文請利用cipher_write和cipher_out將其結果輸出至testfixture的記憶體中，當plain_in_valid等於high時代表明文為有效輸入，
  當plain_in_valid為low時代表明文輸入完畢，當明文輸入完畢後，方可藉由cipher_read來控制密文的輸入
  （注意：若明文加密後有錯，輸入的密文也是錯誤的)，當cipher_in_valid 等於high時代表密文為有效輸入，
  當cipher_in_valid為low時代表為密文輸入完畢，解密的演算法流程與加密相同，若系統已經將加解密動作完成時，請將done 設為high，即可驗證加密。
  圖六為key_in輸入的時序圖，key_valid為high後下一個clk cycle 便將key值輸入。
  圖七為cipher data及plain data的讀取時序圖，當read設為high的下一個clk將會把資料輸入。
  圖八為cipher data及plain data的資料結束時序圖，當plain_in_valid或cipher_in_valid由high轉low時代表資料輸入結束。

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/加密流程圖.png)
<p align="center">圖二、加密流程圖</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/解密流程圖.png)
<p align="center">圖三、解密流程圖</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/KSA.png)
<p align="center">圖四、Key-scheduling algorithm (KSA)</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/加密演算法.png)
<p align="center">圖五、加解密演算法</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/key_in.png)
<p align="center">圖六、key_in時序圖</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/plain_data_and_cipher_data.png)
<p align="center">圖七、plain data及cipher data時序圖</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/end.png)
<p align="center">圖八、plain data及cipher data結束時序圖</p>

## (三) 設計構想
### (1) State machine
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/state_machine.png)
<p align="center">圖九、狀態機與控制訊號</p>

### (2) Control Unit
採用2C(combinatorial logic)1S(Sequential logic)標準寫法，其中Output logic與Datapath合併在一個always block中。
* Next-state logic (C1)  
  Next-state logic負責接收Datapath或Output logic傳送來的控制訊號，並輸出狀態控制訊號給next_state暫存器。  
  input:  
    - key_valid: 當key準備好時，會先將key_valid設成high，然後在下一個負緣輸出key值。
    - cycle: 用於判斷當下狀態為第幾個循環。
    - j: KSA演算法的迴圈次數
    - plain_in_valid: 因為明文長度不固定，所以當輸入的明文為有效時，plain_in_valid為high，若無效時plain_in_valid為low。
    - cipher_in_valid: 因為密文長度不固定，所以當輸入的密文為有效時，cipher_in_valid為high，若無效時cipher_in_valid為low。
    
  output:
    - next_state: 將被賦值為下一個狀態。
* Output logic (C2)  
  - cipher_out: 加密後運算結果記憶體寫出訊號，由8bits 整數(MSB)組成，為無號數。
  - plain_out: 解密後運算結果記憶體寫出訊號，由8bits 整數(MSB)組成，為無號數。
* State logic (S)  
  負責將next_state暫存器的值在正緣觸發時鎖進current_state。
  
## (四) 合成模擬結果與資源使用率
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/result_tb1.png)
![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/result_tb2.png)
<p align="center">圖十、合成模擬結果</p>

![Image](https://github.com/vita70579/VLSI-Implementation/raw/master/RC4/Image/synthesis.png)
<p align="center">圖十一、資源使用率</p>
