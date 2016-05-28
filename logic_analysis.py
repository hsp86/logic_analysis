#-*- coding: utf-8 -*-
import sys,os
import web
import serial
import time

import config

import struct

# reload(sys)#支持中文
# sys.setdefaultencoding('utf8')

urls = (
    '/','index',
    '/send_recv','send_recv'
    )

render = web.template.render(config.temp_dir)

class index:
    def GET(self):
        return render.index()

class send_recv:
    def GET(self):
        get_data = web.input(sample_rate={},sample_unit={},sample_point={})
        print "start!\nsample_rate = " + get_data.sample_rate + ";sample_unit = " + get_data.sample_unit + ";sample_point = " + get_data.sample_point
        # sample_rate = int(get_data.sample_rate) # 采样率
        # sample_unit = int(get_data.sample_unit) # 采样率的单位
        sample_point = int(get_data.sample_point) # 采样点数

        ser = serial.Serial(config.com_port,9600)
        # ser.write(struct.pack('B',0xff)) # 设定采样频率的分频值sample_rate与sample_unit计算
        ser.write("\xff") # 上面那种方式也可发送，这里都用这种方式
        ser.close() #这里都使用：打开->发送->关闭；发现连续发送，有时没发送出去，估计有缓存（用ser.flush()也没用？？）；所以发送一次命令就关闭，这样就一定发送了

        ser = serial.Serial(config.com_port,9600)
        ser.write("\x04") # 发送接收采样值命令
        ser.close()

        ser = serial.Serial(config.com_port,9600)
        ser.write("\x00") # 清除之前数据后才开始接收
        ser.close()

        ser = serial.Serial(config.com_port,9600)
        points = [] # 保存采样值
        i = sample_point
        while (i > 0): # 接收sample_point点
            c = ser.read(1)
            points.append(c)
            i = i - 1

        ser.close()

        ser = serial.Serial(config.com_port,9600)
        ser.write("\x02") # 发送接收重复计数命令
        ser.close()

        ser = serial.Serial(config.com_port,9600)
        repeat_cnt = [] # 保存采样值重复次数
        i = sample_point
        while (i > 0): # 也接收sample_point个
            c = ser.read(1)
            repeat_cnt.append(c)
            i = i - 1
        ser.close()

        return_str = ""
        for i in points:
            c = str(ord(i)) # 直接将这里的值替代下面的c会有类型错误？？
            return_str = return_str + c + ","

        return_str = return_str[0:-1] # 去掉最后那个逗号；直接用return_str[-2:-1] = ";"替换这两行会出错，提示str不能赋值
        return_str = return_str + ";" # 最后添加;
        for i in repeat_cnt:
            c = str(ord(i))
            return_str = return_str + c + ","
        return_str = return_str[0:-1] # 去掉最后那个逗号
        print "return value is:\n" + return_str
        return return_str

def nf():
    return web.notfound("胡祀鹏 提示：Sorry, the page you were looking for was not found.")

def ine():
    return web.internalerror("胡祀鹏 提示：Bad, bad server. No donut for you.")

if __name__ == '__main__':
    webpy_app = web.application(urls,globals())
    webpy_app.notfound = nf#自定义未找到页面
    webpy_app.internalerror = ine#自定义 500 错误消息
    webpy_app.run()
