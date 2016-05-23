//**胡祀鹏
//**2016-05-22
//**测试修改后的uart模块

// synopsys translate_off
`timescale 1 ns / 1 ps
// synopsys translate_on

module uart_test #(
    parameter   FREQ_MHZ    = 50,                                       //  输入时钟(clk)频率（MHz）
    parameter   RATE_BPS    = 9600,                                     //  要产生的波特率（bps）
    parameter   CNT_WIDTH   = 32                                        //  任意分频方式（每次递增INCREASE）的计数器最大位宽，越大则精度越高
    )(
    input   wire            clk,
    input   wire            rst_n,
    
    input   wire            rxd,                                        //  数据输入管脚
    output  wire            txd,                                        //  数据输出管脚
    
    input   wire    [1:0]   check,                                      //  00:无校验；01:偶校验；10:奇校验；11：reserved(有校验位但两种校验总正确)。
    output  wire    [1:0]   err                                         //  接收数据错误类型，00：无错；01：开始错；10：校验错；11：结束错。优先级一次提高，与数据同时输出
    );
    
    wire            rreq;                                               //  读取请求，内部给出读取请求
    wire            rack;                                               //  请求的应答，应答后将接收的数据返回给，发出请求的内部模块
    wire    [7:0]   rdata;                                              //  发送读取请求后接收到的第一个数据
    
    reg             wreq;                                               //  写请求，内部给出写请求
    wire            wack;                                               //  请求的应答，将写入的数据发送完成后应答
    reg     [7:0]   wdata;                                              //  写入数据，即要发送的数据
    
    assign rreq = 1'b1;
    
    wire raccepted;
    assign raccepted = (rreq & rack);
    
    wire waccepted;
    assign waccepted = (wreq & wack);
    
    uart #(
        .FREQ_MHZ   (   FREQ_MHZ    ),
        .RATE_BPS   (   RATE_BPS    ),
        .CNT_WIDTH  (   CNT_WIDTH   )
    ) uart1 (
        .clk        (   clk         ),
        .rst_n      (   rst_n       ),
    
        .rreq       (   rreq        ),                                  //  读取请求，内部给出读取请求
        .rack       (   rack        ),                                  //  请求的应答，应答后将接收的数据返回给，发出请求的内部模块
        .rdata      (   rdata       ),                                  //  发送读取请求后接收到的第一个数据
    
        .wreq       (   wreq        ),                                  //  写请求，内部给出写请求
        .wack       (   wack        ),                                  //  请求的应答，将写入的数据发送完成后应答
        .wdata      (   wdata       ),                                  //  写入数据，即要发送的数据
    
        .rxd        (   rxd         ),                                  //  数据输入管脚
        .txd        (   txd         ),                                  //  数据输出管脚
    
        .check      (   check       ),                                  //  00:无校验；01:偶校验；10:奇校验；11：reserved(有校验位但两种校验总正确)。
        .err        (   err         )                                   //  接收数据错误类型，00：无错；01：开始错；10：校验错；11：结束错。优先级一次提高，与数据同时输出
    );
    
    //**发送请求
    //**接收到一个就发送，发送完才取消请求
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            wreq <= #1 1'b0;
        end
        else
        begin
            if(raccepted == 1'b1)                                       //  接收到一个就发送
            begin
                wreq <= #1 1'b1;
            end
            else if(waccepted == 1'b1)                                  //  直到发送完才取消请求
            begin
                wreq <= #1 1'b0;
            end
        end
    end
    
    //**存储接收的数据
    //**接收到一个就将接收到的数据存储
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            wdata <= #1 8'b0;
        end
        else
        begin
            if(raccepted == 1'b1)                                       //  接收到一个就将接收到的数据存储
            begin
                wdata <= #1 rdata + 1'b1;
            end
        end
    end
    
    
    
endmodule
