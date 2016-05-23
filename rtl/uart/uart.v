//**胡祀鹏
//**2015-09-13
//**这里相对于其他两个uart，更改为请求应答方式封装（方便封装为AXI或wishbone）

// synopsys translate_off
`timescale 1 ns / 1 ps
// synopsys translate_on

module uart #(
    parameter   FREQ_MHZ    = 50,                                       //  输入时钟(clk)频率（MHz）
    parameter   RATE_BPS    = 9600,                                     //  要产生的波特率（bps）
    parameter   CNT_WIDTH   = 32                                        //  任意分频方式（每次递增INCREASE）的计数器最大位宽，越大则精度越高
    )(
    input   wire            clk,
    input   wire            rst_n,
    
    input   wire            rreq,                                       //  读取请求，内部给出读取请求
    output  wire            rack,                                       //  请求的应答，应答后将接收的数据返回给，发出请求的内部模块
    output  wire    [7:0]   rdata,                                      //  发送读取请求后接收到的第一个数据
    
    input   wire            wreq,                                       //  写请求，内部给出写请求
    output  wire            wack,                                       //  请求的应答，将写入的数据发送完成后应答
    input   wire    [7:0]   wdata,                                      //  写入数据，即要发送的数据
    
    input   wire            rxd,                                        //  数据输入管脚
    output  wire            txd,                                        //  数据输出管脚
    
    input   wire    [1:0]   check,                                      //  00:无校验；01:偶校验；10:奇校验；11：reserved(有校验位但两种校验总正确)。
    output  wire    [1:0]   err                                         //  接收数据错误类型，00：无错；01：开始错；10：校验错；11：结束错。优先级一次提高，与数据同时输出
    );
    
    uart_rx #(
        .FREQ_MHZ   (   FREQ_MHZ    ),
        .RATE_BPS   (   RATE_BPS    ),
        .CNT_WIDTH  (   CNT_WIDTH   )
     )uart_rx1(
        .clk        (   clk         ),
        .rst_n      (   rst_n       ),
        .uart_rt_en (   rreq        ),
        .dout_vld   (   rack        ),
        .dout       (   rdata       ),
        .rxd        (   rxd         ),
        .check      (   check       ),
        .err        (   err         )
     );
     
    uart_tx #(
        .FREQ_MHZ   (   FREQ_MHZ    ),
        .RATE_BPS   (   RATE_BPS    ),
        .CNT_WIDTH  (   CNT_WIDTH   )
     )uart_tx1(
        .clk        (   clk         ),
        .rst_n      (   rst_n       ),
        .din_vld    (   wreq        ),
        .din_ack    (   wack        ),
        .din        (   wdata       ),
        .txd        (   txd         ),
        .check      (   check       )
     );
    
endmodule
