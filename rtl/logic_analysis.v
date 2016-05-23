//**胡祀鹏
//**2016-05-22
//**逻辑分析仪模块，8路

// synopsys translate_off
`timescale 1 ns / 1 ps
// synopsys translate_on

// uart发送入rdata:
// 8'bxxxx_xxx1:设定采样频率
// 8'b0000_0000:清除内部数据
// 8'b0000_0010:设置发送重复次数
// 8'b0000_0100:设置发送数据

module logic_analysis #(
    parameter   INPUT_WIDTH             = 8,                            //  逻辑分析输入的位宽
    parameter   CNT_WIDTH               = 20                            //  采样频率分频计数器的位宽，要大于等于DIV_NUM_POS*4
    )(
    input   wire                        clk,
    input   wire                        rst_n,
    
    input   wire    [INPUT_WIDTH-1:0]   din,                            //  逻辑分析输入数据
    input   wire                        rxd,                            //  数据输入管脚
    output  wire                        txd,                            //  数据输出管脚
    
    input   wire    [1:0]               check,                          //  00:无校验；01:偶校验；10:奇校验；11：reserved(有校验位但两种校验总正确)。
    output  wire    [1:0]               err                             //  接收数据错误类型，00：无错；01：开始错；10：校验错；11：结束错。优先级一次提高，与数据同时输出
    );
    
    wire            rreq;                                               //  读取请求，内部给出读取请求
    wire            rack;                                               //  请求的应答，应答后将接收的数据返回给，发出请求的内部模块
    wire    [7:0]   rdata;                                              //  发送读取请求后接收到的第一个数据
    
    reg             wreq;                                               //  写请求，内部给出写请求
    wire            wack;                                               //  请求的应答，将写入的数据发送完成后应答
    reg     [7:0]   wdata;                                              //  写入数据，即要发送的数据
    
    assign rreq = 1'b1;                                                 //  一直使能读取
    
    wire raccepted;
    assign raccepted = (rreq & rack);
    
    wire waccepted;
    assign waccepted = (wreq & wack);
    
    //**采样频率分频计数器
    //**使用递减计数，计数到0就恢复div_num
    localparam DIV_NUM_POS = 5;                                         //  设置div_num为rdata[DIV_NUM_POS:1]<<(rdata[7:6]*DIV_NUM_POS)
    reg [CNT_WIDTH-1:0] div_num;
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            div_num <= #1 {CNT_WIDTH{1'b0}};
        end
        else
        begin
            if(raccepted == 1'b1 && rdata[0] == 1'b1)                   //  接收到一个且最低位为1则表示设定分频
            begin
                case(rdata[7:6])
                    2'b00:div_num <= #1 {{(CNT_WIDTH-DIV_NUM_POS-DIV_NUM_POS*0){1'b0}},rdata[DIV_NUM_POS:1],{(DIV_NUM_POS*0){1'b0}}};
                    2'b01:div_num <= #1 {{(CNT_WIDTH-DIV_NUM_POS-DIV_NUM_POS*1){1'b0}},rdata[DIV_NUM_POS:1],{(DIV_NUM_POS*1){1'b0}}};
                    2'b10:div_num <= #1 {{(CNT_WIDTH-DIV_NUM_POS-DIV_NUM_POS*2){1'b0}},rdata[DIV_NUM_POS:1],{(DIV_NUM_POS*2){1'b0}}};
                    2'b11:div_num <= #1 {{(CNT_WIDTH-DIV_NUM_POS-DIV_NUM_POS*3){1'b0}},rdata[DIV_NUM_POS:1],{(DIV_NUM_POS*3){1'b0}}};
                    default:div_num <= #1 {{(CNT_WIDTH-DIV_NUM_POS-DIV_NUM_POS*0){1'b0}},rdata[DIV_NUM_POS:1],{(DIV_NUM_POS*0){1'b0}}};
                endcase
            end
        end
    end
    reg [CNT_WIDTH-1:0] div_cnt;
    wire div_cnt0;
    assign div_cnt0 = (div_cnt == {CNT_WIDTH{1'b0}});                   //  采样使能，即计数到0就采样
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            div_cnt <= #1 {CNT_WIDTH{1'b0}};
        end
        else
        begin
            if(div_cnt0 == 1'b1)                                        //  计数到0就恢复div_num
            begin
                div_cnt <= #1 div_num;
            end
            else
            begin
                div_cnt <= #1 div_cnt - 1'b1;
            end
        end
    end
    
    //**将输入数据打拍输入
    //**输入数据打3拍
    reg [INPUT_WIDTH-1:0]   din_r0;
    reg [INPUT_WIDTH-1:0]   din_r1;
    reg [INPUT_WIDTH-1:0]   din_r2;
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            din_r0 <= #1 {INPUT_WIDTH{1'b0}};
            din_r1 <= #1 {INPUT_WIDTH{1'b0}};
            din_r2 <= #1 {INPUT_WIDTH{1'b0}};
        end
        else
        begin
            if(div_cnt0 == 1'b1)
            begin
                din_r0 <= #1 din;
                din_r1 <= #1 din_r0;
                din_r2 <= #1 din_r1;
            end
        end
    end

    //**重复次数计数
    //**将相同数据计数
    reg [7:0] repeat_num;                                               //  计数一个数据重复的次数
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            repeat_num <= #1 8'b0;
        end
        else
        begin
            if(div_cnt0 == 1'b1 && din_r1 == din_r2)
            begin
                repeat_num <= #1 repeat_num + 1'b1;
            end
        end
    end

    //**fifo_data控制信号
    //**
    reg fifo_data_sclr;
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            fifo_data_sclr <= #1 1'b1;                                  //  复位就请FIFO
        end
        else
        begin
            if(raccepted == 1'b1 && rdata[0] == 1'b0 &&                 //  接收到一个且最低位为0则表示命令
                rdata[7:1] == 7'b0000_000)                              //  rdata[7:1]为7'b0000_001则为清除数据命令
            begin
                fifo_data_sclr <= #1 1'b1;
            end
            else
            begin
                fifo_data_sclr <= #1 1'b0;
            end
        end
    end
    wire repeat255;
    assign repeat255 = (div_cnt0 == 1'b1 && repeat_num == 8'hff);       //  或重复次数达到255
    wire data_diff;
    assign data_diff = (div_cnt0 == 1'b1 && din_r1 != din_r2);          //  前后输入的数据不同
    wire fifo_din_en;
    assign fifo_din_en = (repeat255 == 1'b1 || data_diff == 1'b1);      //  fifo_data写入使能信号
    wire fifo_data_wrreq;
    wire fifo_data_full;
    assign fifo_data_wrreq = (fifo_data_full == 1'b0)?fifo_din_en:1'b0; //  不满才能写入

    //  存数据的fifo
    wire    [7:0]   fifo_data_din;
    assign fifo_data_din = din_r2;                                      //  数据直接输入，是否真写入看fifo_data_wrreq
    reg             fifo_data_rdreq;
    wire            fifo_data_empty;
    wire    [7:0]   fifo_data_q;
    fifo8 fifo_data(
        .clock   (  clk                 ),
        .data    (  fifo_data_din       ),
        .rdreq   (  fifo_data_rdreq     ),
        .sclr    (  fifo_data_sclr      ),
        .wrreq   (  fifo_data_wrreq     ),
        .empty   (  fifo_data_empty     ),
        .full    (  fifo_data_full      ),
        .q       (  fifo_data_q         )
    );

    //  存数据个数的fifo(存数据fifo中的最高位为1的数据)
    wire    [7:0]   fifo_cnt_din;
    reg             fifo_cnt_rdreq;
    wire            fifo_cnt_sclr;
    wire            fifo_cnt_wrreq;
    wire            fifo_cnt_empty;
    wire            fifo_cnt_full;
    wire    [7:0]   fifo_cnt_q;
    fifo8 fifo_cnt(
        .clock   (  clk                 ),
        .data    (  fifo_cnt_din       ),
        .rdreq   (  fifo_cnt_rdreq     ),
        .sclr    (  fifo_cnt_sclr      ),
        .wrreq   (  fifo_cnt_wrreq     ),
        .empty   (  fifo_cnt_empty     ),
        .full    (  fifo_cnt_full      ),
        .q       (  fifo_cnt_q         )
    );

    //**fifo_cnt控制信号
    //**
    assign fifo_cnt_din = repeat_num;                                   //  输入重复次数，是否真写入看wreq
    assign fifo_cnt_wrreq = (fifo_cnt_full == 1'b0)?fifo_din_en:1'b0;   //  计数fifo不满才可写入
    assign fifo_cnt_sclr = fifo_data_sclr;                              //  两个FIFO使用同一清除信号

    uart #(
        .FREQ_MHZ   (   50          ),
        .RATE_BPS   (   9600        ),
        .CNT_WIDTH  (   32          )
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
    //**
    reg is_send_cnt;                                                    //  是否开始发送重复次数
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            is_send_cnt <= #1 1'b0;                                     //  默认发送数据
        end
        else
        begin
            if(raccepted == 1'b1 && rdata[0] == 1'b0)                   //  接收到一个且最低位为0则表示命令
            begin
                if(rdata[7:1] == 7'b0000_001)                           //  rdata[7:1]为7'b0000_001则为发送重复次数
                begin
                    is_send_cnt <= #1 1'b1;
                end
                else if(rdata[7:1] == 7'b0000_010)                      //  rdata[7:1]为7'b0000_010则为发送数据
                begin
                    is_send_cnt <= #1 1'b0;
                end
            end
        end
    end

    //  wreq延迟2拍：从fifo读出，从fifo输出到wdata
    reg wreq_r;
    reg wreq_r1;
    wire is_wreq;
    assign is_wreq = (wreq == 1'b1 || wreq_r == 1'b1 || wreq_r1 == 1'b1);// 只要其中一个为1就有请求
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            wreq_r <= #1 1'b0;
        end
        else
        begin
            if(is_wreq == 1'b0)
            begin
                if(is_send_cnt == 1'b1)                                 //  发送计数
                begin
                    wreq_r <= #1 (fifo_cnt_empty == 1'b1)?1'b0:1'b1;    //  不为空就发送
                end
                else                                                    //  发送数据
                begin
                    wreq_r <= #1 (fifo_data_empty == 1'b1)?1'b0:1'b1;   //  不为空就发送
                end
            end
            else if(waccepted == 1'b1)                                  //  直到发送完才清0请求
            begin
                wreq_r <= #1 1'b0;
            end
        end
    end
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            wreq_r1 <= #1 1'b0;
            wreq <= #1 1'b0;
        end
        else
        begin
            if(waccepted == 1'b1)                                       //  直到发送完全部请求清0
            begin
                wreq_r1 <= #1 1'b0;
                wreq <= #1 1'b0;
            end
            else
            begin
                wreq_r1 <= #1 wreq_r;
                wreq <= #1 wreq_r1;
            end
            
        end
    end

    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            wdata <= #1 8'b0;
        end
        else
        begin
            if(is_send_cnt == 1'b1)                                     //  发送计数
            begin
                wdata <= #1 fifo_cnt_q;
            end
            else                                                        //  发送数据
            begin
                wdata <= #1 fifo_data_q;
            end
        end
    end

    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            fifo_data_rdreq <= #1 1'b0;
        end
        else
        begin
            if(fifo_data_rdreq == 1'b1)                                 //  不会连续读两次
            begin
                fifo_data_rdreq <= #1 1'b0;
            end
            else if(is_wreq == 1'b0 || waccepted == 1'b1)               //  uart没有发送或发送完就检测是否发送
            begin
                if(is_send_cnt == 1'b0)                                 //  本次发送数据
                begin
                    fifo_data_rdreq <= #1 (fifo_data_empty == 1'b1)?1'b0:1'b1;//  不为空就读
                end
            end
        end
    end
    always @(posedge clk or negedge rst_n)
    begin
        if(rst_n == 1'b0)
        begin
            fifo_cnt_rdreq <= #1 1'b0;
        end
        else
        begin
            if(fifo_cnt_rdreq == 1'b1)                                  //  不会连续读两次
            begin
                fifo_cnt_rdreq <= #1 1'b0;
            end
            else if(is_wreq == 1'b0 || waccepted == 1'b1)               //  uart没有发送或发送完就检测是否发送
            begin
                if(is_send_cnt == 1'b1)                                 //  本次发送计数
                begin
                    fifo_cnt_rdreq <= #1 (fifo_cnt_empty == 1'b1)?1'b0:1'b1;//  不为空就读
                end
            end
        end
    end

endmodule
