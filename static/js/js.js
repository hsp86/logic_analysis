$(function(){
    var freq = 50000;//默认50MHz

    // 从采样频率部分的选择计算出采样频率
    function get_freq()
    {
        var f = $("#sample_rate").val()
        var b = $("#sample_unit").val()
        if(parseInt(f) == 0)
        {
            freq = 50000;
        }
        else
        {
            freq = 50000/((parseInt(f)+1)*Math.pow(32,parseInt(b)));
        }
        
    }

    // 设置采样频率和等待时间的显示
    function set_msg()
    {
        var f = freq*1000;
        var u = 0;
        while(f>1000)
        {
            u++;
            f = f / 1000;
        }
        var s = f.toFixed(3);//取3位小数
        switch(u)
        {
            case 0:
                s = s + "Hz";
                break;
            case 1:
                s = s + "KHz";
                break;
            case 2:
                s = s + "MHz";
                break;
            default:
                s = s + "Hz";
                break;
        }
        var p = $("#sample_point").val();
        var pt_ms = 1000/freq;
        if(pt_ms < 8000)// 一个点采集时间小于8ms则用8ms来计算时间，因为uart传输一点至少8ms（9600bps）
        {
            pt_ms = 8000;
        }
        var m = pt_ms*p/1000;
        $(".prompt").text("采样率为"+ s +"；至少等待"+ m.toFixed(3) +"秒");
    }

    // 将msg字符串格式转化为数字并存入一下数组
    var data = [];
    var cnt = [];
    var pos_w = 1;//一个点的宽度
    var wave_width = (1400-100);//绘制波形的宽度
    function get_pos_w()//经过输入的点数计算一个点的位宽
    {
        var cnt_sum = 0;
        for(i in cnt)
        {
            cnt_sum += cnt[i];
        }
        if(cnt_sum == 0)
        {
            pos_w = 1;
        }
        else
        {
            pos_w = wave_width/cnt_sum;
        }
    }
    function str2num(msg)
    {
        var msgs = msg.split(';');
        var datas = msgs[0].split(',');
        var cnts = msgs[1].split(',');
        for(var i = 0; i < datas.length; i++)
        {
            data.push(parseInt(datas[i]));//将字符串转换为int
        }
        for(var i = 0; i < cnts.length; i++)
        {
            cnt.push(parseInt(cnts[i])+1);//将字符串转换为int，值加1
        }
    }
    //将以上转化的数字数组绘制为波形
    function get_bit(data,i)
    {
        if((data%Math.pow(2,(i+1)))/Math.pow(2,i) >= 1)
        {
            return 1;
        }
        else
        {
            return 0;
        }
    }
    function paint1(data,cnt,pos)
    {
        var bit0;
        var bit1;
        var tag = "";
        bit0 = get_bit(data[0],pos);
        tag = tag + '<text x="' + 50 +'" y="' + ((pos+1)*50-20) + '" style="stroke:black;stroke-width:1;font-size:14px;text-anchor:end;">ch' + pos + '</text>';
        tag = tag + '<path d="M 70,';
        if(bit0 == 1)
        {
            tag = tag + ((pos+1)*50-40);
        }
        else
        {
            tag = tag + ((pos+1)*50-10);
        }
        var cnt_sum = 0;
        var attr_d = "";
        for(var i = 0; i < data.length; i++)
        {
            bit1 = bit0;
            bit0 = get_bit(data[i],pos);
            if(bit1 == 1 && bit0 == 0)//下降沿
            {
                attr_d = attr_d + ' h ' + (cnt_sum*pos_w) + 'v 30';
                cnt_sum = cnt[i];
            }
            else if(bit1 == 0 && bit0 == 1)//上升沿
            {
                attr_d = attr_d + ' h ' + (cnt_sum*pos_w) + 'v -30';
                cnt_sum = cnt[i];
            }
            else//累积计数
            {
                cnt_sum = cnt_sum + cnt[i];
            }
        }
        attr_d = attr_d + ' h ' + (cnt_sum*pos_w);
        tag = tag + attr_d + '" style="fill:none;stroke:black;stroke-width:2;" />';
        return tag;
    }

    function paint_ruler()
    {
        var y = 410;//(50*8+10)
        var ruler = '<path d="M 70,' + y;
        for (var i = 0; i < wave_width; i = i + 100)
        {
            ruler = ruler + 'v -10 h 0 v 10 h 50 v -5 h 0 v 5 h 50 ';
        }
        ruler = ruler + 'v -10 h 0 v 10';
        ruler = ruler + '" style="fill:none;stroke:black;stroke-width:0.5;" />';
        for (var i = 0; i <= wave_width; i = i + 100)
        {
            ruler = ruler + '<text x="' + (i+70) +'" y="' + (y+20) + '" style="stroke:black;stroke-width:0.5;font-size:14px;text-anchor:middle;">' + (i/pos_w).toFixed(0) + '</text>';
        }
        return ruler;
    }
    function repaint()
    {
        var $svg = $('svg');
        var wave = "";
        get_pos_w();
        for (var i = 0; i < 8; i++)//绘制0~7个波形
        {
            wave = wave + paint1(data,cnt,i);
        }
        $svg.html(wave+paint_ruler());
    }
    function draw_cursor(show2,offset,e)
    {
        x=e.pageX-offset.left;
        y=e.pageY-offset.top;
        if(x < 70)//限制到有效区域
        {
            x = 70;
        }
        else if(x > 1370)
        {
            x = 1370;
        }
        if(y < 0)
        {
            y = 0;
        }
        else if(y > 400)
        {
            y = 400;
        }
        show2.moveTo(x,0);
        show2.lineTo(x,400);
        // show2.moveTo(70,y);//不用横向标记，就注释这里
        // show2.lineTo(1370,y);
        show2.stroke();
    }
    var sigle_cursor = false;//单光标关闭
    function draw(targetclass)
    {
        var $show2=$("#"+targetclass);
        var show2=$show2[0].getContext('2d');
        var x=0,y=0;
        show2.strokeStyle = '#55f';
        $show2.bind("mousedown",function(e){
            if(3 == e.which)//鼠标右键
            {
                show2.clearRect(0,0,1400,450);
                show2.beginPath();//beginPath一下，清除path内容
            }
            else if(1 == e.which)//鼠标左键
            {
                var offset=$(this).offset();
                if(!sigle_cursor)//多光标
                {
                    draw_cursor(show2,offset,e);
                }
            }
            // return false;//这里不能真正屏蔽右键
        })
        .bind('mousemove',function(e) {
            var offset=$(this).offset();
            if(sigle_cursor)//单光标
            {
                show2.clearRect(0,0,1400,450);
                show2.beginPath();//beginPath一下，清除path内容
                draw_cursor(show2,offset,e);
            }
        })
        .bind('contextmenu', function(e) {
            return false;//屏蔽右键
        });
    }
    
    // 初始化采样频率选择部分
    (function init(rate_num,unit_num)
    {
        $rate = $("#sample_rate");
        for (var i = 1; i < rate_num; i++)
        {
            $rate.append('<option>'+i+'</option>');
        }
        $unit = $("#sample_unit");
        for (var i = 1; i < unit_num; i++)
        {
            $unit.append('<option>'+i+'</option>');
        }
        get_freq();
        set_msg();
        draw('paint_cursor');
    })(32,4);
    $("#sample_rate").bind('change', function(event) {
        get_freq();
        set_msg();
    });
    $("#sample_unit").bind('change', function(event) {
        get_freq();
        set_msg();
    });
    $("#sample_point").bind('change', function(event) {
        set_msg();
    });
    $("#clear").bind('click', function(event) {
        data = [];
        cnt = [];
        repaint();
    });
    $("#sigle_cursor").bind('click', function(event) {
        sigle_cursor = this.checked;
    });

    $('#start').bind('click', function(event) {
        var method = "get";
        var action = '/send_recv';
        var sample_rate = $("#sample_rate").val();
        var sample_unit = $("#sample_unit").val();
        var sample_point = $("#sample_point").val();
        var search_data = "sample_rate="+sample_rate+"&sample_unit="+sample_unit+"&sample_point="+sample_point;
        $.ajax({
            url: action,
            type: method,
            data: search_data,
            success: function(msg){
                str2num(msg);
                repaint();
            }
        });
    });
})
