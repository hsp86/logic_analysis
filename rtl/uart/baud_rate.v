//**胡祀鹏
//**2015-09-13

// synopsys translate_off
`timescale 1 ns / 1 ps
// synopsys translate_on

module baud_rate #(
    parameter   FREQ_MHZ    = 50,                                       //  输入时钟(clk)频率（MHz）
    parameter   RATE_BPS    = 9600,                                     //  要产生的波特率（bps）
    parameter   CNT_WIDTH   = 32                                        //  任意分频方式（每次递增INCREASE）的计数器最大位宽，越大则精度越高
    )(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            start_en,                                   //  有效(1)开始产生波特率
    output  wire            rate_en                                     //  输出波特率有效（用于采样或发送），一个时钟周期有效(1)
    );
    
    localparam INCREASE = (2**(CNT_WIDTH-2))/(10**4) * RATE_BPS/((FREQ_MHZ*10**2)/4); //  计数器每次递增值,计算的中间值也不能大于2**31(integer位32位有符号数)，所以CNT_WIDTH-2且FREQ_MHZ/4;另外先做除法在*RATE_BPS
    // localparam INCREASE = 824634;
    // localparam INCREASE = (2**(CNT_WIDTH-2))/(FREQ_MHZ/4)/(10**4) * RATE_BPS; //  just for test
    
    //**任意分频计数器
    //**每次递增INCREASE计数器
    reg [CNT_WIDTH-1:0] cnt;
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            cnt <= #1 {CNT_WIDTH{1'b0}};
        end
        else
        begin
            if(start_en == 1'b1)                                        //  开始就一直循环计数
            begin
                cnt <= #1 cnt + INCREASE;
            end
            else                                                        //  没有开始使能就归0等待开始
            begin
                cnt <= #1 {CNT_WIDTH{1'b0}};
            end
        end
    end
    
    //**任意分频波形产生
    //**由计数器产生的波特率相同频率的波形
    reg div_clk;
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            div_clk <= #1 1'b0;
        end
        else
        begin
            if(cnt < {1'b0,{(CNT_WIDTH-1){1'b1}}})                      //  小于最大计数的1/2
            begin
                div_clk <= #1 1'b0;
            end
            else
            begin
                div_clk <= #1 1'b1;
            end
        end
    end
    
    //**分频后时钟上升沿采样
    //**用于一周期波特率使能输出
    reg div_clk_r;
    assign rate_en = ((~div_clk_r) & div_clk);
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            div_clk_r <= #1 1'b0;
        end
        else
        begin
            div_clk_r <= #1 div_clk;
        end
    end
    
endmodule
