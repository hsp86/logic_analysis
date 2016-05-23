# logic_analysis
本工程用verilog（FPGA）和python实现一个简单的8路输入逻辑分析仪；数据通过uart传入电脑通过python接收，再通过网页显示波形

* 本工程使用FPGA 为Altera的EP2C5T144C8N；当然也可以用其它类似芯片，只要能提供两个n*8bit FIFO即可，使用系统时钟为50MHz；
* FPGA使用了两个IP：n*8bit FIFO；n越大所能采集的数据越多；
* 可以设置采样率50MHz~47.7Hz，分频值计算方法 = [4:0] << ([6:5] * 5),最后才频率=50000/分频值(单位KHz)；
* 可通过uart发送命令,命令有:
// 8'bxxxx_xxx1:设定采样频率
// 8'b0000_0000:清除内部FIFO数据
// 8'b0000_0010:设置发送重复次数
// 8'b0000_0100:设置发送数据

使用python库：
* webpy
* pyserial
