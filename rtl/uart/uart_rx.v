//**胡祀鹏
//**2015-09-13

// synopsys translate_off
`timescale 1 ns / 1 ps
// synopsys translate_on

module uart_rx #(
    parameter   FREQ_MHZ    = 50,                                       //  输入时钟(clk)频率（MHz）
    parameter   RATE_BPS    = 9600,                                     //  波特率（bps）
    parameter   CNT_WIDTH   = 32                                        //  波特率产生时任意分频方式（每次递增INCREASE）的计数器最大位宽，越大则精度越高
    )(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            uart_rt_en,                                 //  为1时使能本接收模块，在接收期间要一直为1
    output  wire            dout_vld,                                   //  输出接收的数据有效(1)，一个时钟周期
    output  wire    [7:0]   dout,                                       //  输出接收的数据（即使错误也会输出数据，但会同时会输出错误类型）
    input   wire            rxd,                                        //  数据输入管脚
    input   wire    [1:0]   check,                                      //  00:无校验；01:偶校验；10:奇校验；11：reserved(有校验位但两种校验总正确)。
    output  reg     [1:0]   err                                         //  接收数据错误类型，00：无错；01：开始错；10：校验错；11：结束错。优先级一次提高，与数据同时输出
    );
    
    reg start_en;
    wire rate_en;
    baud_rate #(
        .FREQ_MHZ   (   FREQ_MHZ    ),
        .RATE_BPS   (   RATE_BPS    ),
        .CNT_WIDTH  (   CNT_WIDTH   )
    ) baud_9600bps (
        .clk        (   clk         ),
        .rst_n      (   rst_n       ),
        .start_en   (   start_en    ),
        .rate_en    (   rate_en     )
    );
    
    
    //**接收开始
    //**接收rxd下降沿检测
    reg rxd_r0;
    reg rxd_r1;
    wire rxd_neg;
    assign rxd_neg = ((~rxd_r0) & rxd_r1);
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            rxd_r0 <= #1 1'b0;
            rxd_r1 <= #1 1'b0;
        end
        else
        begin
            rxd_r0 <= #1 rxd;
            rxd_r1 <= #1 rxd_r0;
        end
    end
    
    localparam IDLE     = 3'b000;
    localparam START    = 3'b001;
    localparam GET_DATA = 3'b010;
    localparam END      = 3'b100;
    
    reg     [2:0]       cur_state;
    reg     [2:0]       next_state;
    
    //**接收状态机三段
    //**接收各状态转换
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            cur_state <= #1 IDLE;
        end
        else
        begin
            cur_state <= #1 next_state;
        end
    end
    
    //**next_state获取
    //**通过组合逻辑计算next_state
    reg [3:0] data_cnt;
    always @(*)
    begin
        case(cur_state)
            IDLE:
            begin
                if(rate_en == 1'b1)
                begin
                    next_state = START;
                end
                else
                begin
                    next_state = IDLE;
                end
            end
            START:
            begin
                if(rate_en == 1'b1)
                begin
                    next_state = GET_DATA;
                end
                else
                begin
                    next_state = START;
                end
            end
            GET_DATA:
            begin
                if(rate_en == 1'b1)
                begin
                    if((check == 2'b0 && data_cnt == 4'd8)              //  没有校验时只要接收8位数据
                        || data_cnt == 4'd9)                            //  有校验接收9位
                    begin
                        next_state = END;
                    end
                    else
                    begin
                        next_state = GET_DATA;
                    end
                end
                else
                begin
                    next_state = GET_DATA;
                end
            end
            END:
            begin
                if(rate_en == 1'b1)
                begin
                    next_state = IDLE;
                end
                else
                begin
                    next_state = END;
                end
            end
            default:
            begin
                next_state = IDLE;
            end
        endcase
    end
    
    //**接收数据
    //**在next_state == GET_DATA时接收数据及校验位
    reg [8:0] datain;
    assign dout_vld = (rate_en == 1'b1 && cur_state == END);            //  注意不能用next_state==END,因为这时err可能正在赋值
    assign dout     = (check == 2'b00)?datain[8:1]:datain[7:0];
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            datain <= #1 9'b0;
        end
        else
        begin
            if(rate_en == 1'b1)
            begin
                if(next_state == GET_DATA)
                begin
                    datain <= #1 {rxd_r1,datain[8:1]};
                end
            end
        end
    end
    
    //**接收数据计数
    //**在next_state == GET_DATA时接收数据计数
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            data_cnt <= #1 4'b0;
        end
        else
        begin
            if(rate_en == 1'b1)
            begin
                if(next_state == GET_DATA)
                begin
                    data_cnt <= #1 data_cnt + 1'b1;
                end
                else                                                    //  其它状态如START时要归0为下次接收准备
                begin
                    data_cnt <= #1 4'b0;
                end
            end
        end
    end
    
    //**使能波特率产生
    //**在IDLE状态检测到rxd输入下降沿时使能波特率产生（本模块使用的cur_state）
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            start_en <= #1 1'b0;
        end
        else
        begin
            if(uart_rt_en == 1'b0)                                      //  添加使能位，其值为0就不再接收
            begin
                start_en <= #1 1'b0;
            end
            else if(cur_state == IDLE && rxd_neg == 1'b1)
            begin
                start_en <= #1 1'b1;
            end
            else if(cur_state == END && rate_en == 1'b1)                //  一直到END状态转换为IDLE后才不使能
            begin
                start_en <= #1 1'b0;
            end
        end
    end
    
    //**错误检测
    //**接收数据错误类型，00：无错；01：开始错；10：校验错；11：结束错。优先级依次提高，与数据同时输出
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            err <= #1 2'b0;
        end
        else
        begin
            if(rate_en == 1'b1)
            begin
                case(next_state)
                    START:
                    begin
                        if(rxd == 1'b1)
                        begin
                            err <= #1 2'b01;
                        end
                        else
                        begin
                            err <= #1 2'b00;                            //  作为初始化，当起始没错时输出err无错而不是上一次留下来的错误
                        end
                    end
                    GET_DATA:
                    begin
                        if(data_cnt == 4'd9)                            //  有校验接收9位
                        begin
                            case(check)
                                2'b01:                                  //  偶校验
                                begin
                                    if(rxd ^ (^datain[8:1]) == 1'b1)
                                    begin
                                        err <= #1 2'b10;
                                    end
                                end
                                2'b10:                                  //  奇校验
                                begin
                                    if(rxd ^ (^datain[8:1]) == 1'b0)
                                    begin
                                        err <= #1 2'b10;
                                    end
                                end
                                default:
                                begin
                                    err <= #1 err;
                                end
                            endcase
                        end
                    end
                    END:
                    begin
                        if(rxd == 1'b0)
                        begin
                            err <= #1 2'b11;
                        end
                    end
                    default:
                    begin
                        err <= #1 err;
                    end
                endcase
            end
        end
    end
    
endmodule
