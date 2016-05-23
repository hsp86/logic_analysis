//**胡祀鹏
//**2015-09-13

// synopsys translate_off
`timescale 1 ns / 1 ps
// synopsys translate_on

module uart_tx #(
    parameter   FREQ_MHZ    = 50,                                       //  输入时钟(clk)频率（MHz）
    parameter   RATE_BPS    = 9600,                                     //  波特率（bps）
    parameter   CNT_WIDTH   = 32                                        //  波特率产生时任意分频方式（每次递增INCREASE）的计数器最大位宽，越大则精度越高
    )(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            din_vld,                                    //  输入发送的数据有效(1)
    output  reg             din_ack,                                    //  输入的数据被发送完的应答，一个周期有效
    input   wire    [7:0]   din,                                        //  输入发送的数据
    input   wire    [1:0]   check,                                      //  00:无校验；01:偶校验；10:奇校验；11：reserved(无校验)。
    output  reg             txd                                         //  数据输出管脚
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
    
    localparam IDLE     = 3'b000;
    localparam START    = 3'b001;
    localparam PUT_DATA = 3'b010;
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
                    next_state = PUT_DATA;
                end
                else
                begin
                    next_state = START;
                end
            end
            PUT_DATA:
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
                        next_state = PUT_DATA;
                    end
                end
                else
                begin
                    next_state = PUT_DATA;
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
    
    //**发送数据
    //**发送数据，包括开始位，数据，校验位和停止位
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            txd <= #1 1'b1;
        end
        else
        begin
            if(rate_en == 1'b1)
            begin
                case(next_state)
                    START:
                    begin
                        txd <= #1 1'b0;
                    end
                    PUT_DATA:
                    begin
                        case(data_cnt)
                            4'd0:txd <= #1 din[0];
                            4'd1:txd <= #1 din[1];
                            4'd2:txd <= #1 din[2];
                            4'd3:txd <= #1 din[3];
                            4'd4:txd <= #1 din[4];
                            4'd5:txd <= #1 din[5];
                            4'd6:txd <= #1 din[6];
                            4'd7:txd <= #1 din[7];
                            default:                                    //  4'd8，有校验时才有
                            begin
                                if(check == 2'b01)
                                begin
                                    txd <= #1 ^din;
                                end
                                else if(check == 2'b10)
                                begin
                                    txd <= #1 ~(^din);
                                end
                                else
                                begin
                                    txd <= #1 1'b1;
                                end
                            end
                        endcase
                    end
                    END:
                    begin
                        txd <= #1 1'b1;
                    end
                    default:
                    begin
                        txd <= #1 1'b1;
                    end
                endcase
            end
        end
    end
    
    //**发送数据计数
    //**在next_state == PUT_DATA时发送数据计数
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
                if(next_state == PUT_DATA)
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
            if(din_vld == 1'b0)                                         //  在发送期间，要保持一直有效才能发送
            begin
                start_en <= #1 1'b0;                                    //  如果这期间din_vld无效就停止发送
            end
            else if(cur_state == IDLE)
            begin
                start_en <= #1 1'b1;
            end
            else if(cur_state == END && rate_en == 1'b1)                //  一直到END状态转换为IDLE后才不使能
            begin
                start_en <= #1 1'b0;
            end
        end
    end
    
    //**发送完应答
    //**发送完成后应答，一个周期有效
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            din_ack <= #1 1'b0;
        end
        else
        begin
            if(cur_state == END && rate_en == 1'b1)                     //  一直到END状态转换为IDLE后才发送完，各处应答
            begin
                din_ack <= #1 1'b1;
            end
            else
            begin
                din_ack <= #1 1'b0;
            end
        end
    end
    
endmodule
