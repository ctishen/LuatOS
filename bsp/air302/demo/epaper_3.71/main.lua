
-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "mqttairm2m"
VERSION = "1.0.0"

-- sys库是标配
_G.sys = require("sys")

local mqtt = require "mqtt"

_G.pm_sleep_sec = 60


function getsleeptime()
    adc.open(1)
    local _, bat = adc.read(1)
    local rate =fs_read_rate()
    adc.close(1)
    log.debug("Bat:", bat+0)
    if (bat>4000)then
        return pm_sleep_sec*rate
    end
    if (bat<4000 and bat>3800)then
        return pm_sleep_sec*rate--*5
    end
    if (bat<=3800 and bat>3600)then
        return pm_sleep_sec*rate--*10
    end
    if (bat<=3600 and bat>3400)then
        return pm_sleep_sec*rate--*20
    end
    if(bat<=3400) then
        return pm_sleep_sec*rate--*60
    end
end

function fs_write_rate(rate)
    local f = io.open("rate_time", "wb")
    if f then
        log.info("fs", "write c to file", rate, tostring(rate))
        f:write(tostring(rate))
        f:close()
    end
    return rate
end

function fs_read_rate()
    local f = io.open("rate_time", "rb")
    if f then
        local data = f:read("*a")
        log.info("fs", "data", data, data:toHex())
        rate = tonumber(data)
        f:close()
    end
    if rate ==nil then 
        rate =5
    end
    return rate
end

--//-----------------------------------------------------
-- 非预期唤醒监测函数, TODO 在固件内实现
function pm_enter_hib_mode(sec)

    lpmem.write(512, pack.pack(">HI", 0x5AA5, os.time()))
    pm.dtimerStart(0, sec*1000)
    pm.request(pm.HIB) 
    log.info("pm check",pm.check())
    sys.wait(sec*1000)
end

function pm_wakeup_time_check ()
    log.info("pm", pm.lastReson())
    if pm.lastReson() == 1 then
        local tdata = lpmem.read(512, 6) -- 0x5A 0xA5, 然后一个32bit的int
        local _, mark, tsleep = pack.unpack(tdata, ">HI")
        if mark == 0x5AA5 then
            local tnow = os.time()
            log.info("pm", "sleep time", tsleep, tnow)
			--下面的3600S根据休眠时间设置，最大可以设置休眠时间-12S。
            if tnow - tsleep < (getsleeptime() - 120) then
                pm.request(pm.HIB) -- 建议休眠
                return -- 是提前唤醒, 继续睡吧
            end
        end
    end
    return true
end



function DrawMultiLineString(x,y,lineheight,screenwidth,fontsize,inputstr)
    -- 计算字符串宽度
    -- 可以计算出字符宽度，用于显示使用
    --screenwidth为8的倍数,
   local lenInByte = #inputstr
   local width = 0
   local i = 1
   j=1
   local tb = {}
   while (i<=lenInByte) 
    do
        local curByte = string.byte(inputstr, i)
        local byteCount = 1;
        if curByte>0 and curByte<=127 then
            byteCount = 1                                           --1字节字符ascii
        elseif curByte>=192 and curByte<223 then
            byteCount = 2                                           --双字节字符
        elseif curByte>=224 and curByte<239 then
            byteCount = 3                                           --汉字
        elseif curByte>=240 and curByte<=247 then
            byteCount = 4                                           --4字节字符
        end

        local char = string.sub(inputstr, i, i+byteCount-1)
        table.insert(tb, char)
 
        if byteCount == 1 then
            width = width +  0.5
        else
            width = width + 1
            --print(char)
        end
        i = i + byteCount                                 -- 重置下一字节的索引
        --width = width + 1                                 -- 字符的个数（长度）
        print ('width',width)

        print(lenInByte)
        if width >=math.ceil(screenwidth/fontsize) or  i>=lenInByte-1 then
            print(table.concat(tb))                                                        
            eink.printcn(x, y+j*lineheight,table.concat(tb), 0, fontsize)
            j=j+1
            tb={}
            width=0 
        
        end



    end


    return width
end

-- 打印当天的信息
local _WEEK = { "星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六" }

local function getWeek()
    local d = os.time()
    local w = os.date("%w", d)
    return _WEEK[w + 1]
end



function display_show(dset,bat,adc2,mycode,mydata,d1,d2,d3,d4,d5,d6)
    local t = os.date("%Y/%m/%d %H:%M")
    local width,height,rotate =eink.getWin()   --width280,height480
    --top
    if bat<=3600 or bat>=4100 then
        eink.bat(height-30, 5, tonumber(bat))
    end
    --eink.print(height-150, 5, t, 0, 12)
    --eink.print(height-25, 17, string.format("%d %d",rate,bat), 0, 12)
    --center
    if dset==1 then --显示单独行情数据
        eink.printcn(10, 25*1, mycode, 0, 24)
        eink.print( math.ceil( (height-string.len(tostring(mydata))*20 )/2 ), width/2-32/2, string.format("%0.2f",mydata), 0, 32)
        DrawMultiLineString(0,height-60,20,width-8,24,d6)
    end

    if dset==2 then --显示多条行情数据
        local center_width =width-10-24-50

        eink.printcn(10,  math.ceil(10+center_width/5*1), d1, 0, 24)
        eink.printcn(10,  math.ceil(10+center_width/5*2), d2, 0, 24)
        eink.printcn(10,  math.ceil(10+center_width/5*3), d3, 0, 24)
        eink.printcn(10,  math.ceil(10+center_width/5*4), d4, 0, 24)
        eink.printcn(10,  math.ceil(10+center_width/5*5), d5, 0, 24)
        DrawMultiLineString(0,height-60,20,width-8,24,d6)
    end

    if dset==3 then --日历功能
        --local tm = os.date("%d")
        --eink.printcn(10, 25*1, mycode, 0, 24)
        --eink.print( math.ceil( (height-string.len(tm)*20 )/2 ), width/2-32/2, tm, 0, 32)
        --DrawMultiLineString(0,height-80,20,width-8,24,d6)
        DrawMultiLineString(0,20,width/10,height-8,24,d6)
    end
    if dset==4 then --one功能
        local tm = os.date("%d")
        local t = os.date("%b,%Y %a")
        --eink.printcn(10, 25*1, mycode, 0, 24)
        eink.print(0, width/10, tm, 0, 32)
        eink.print(45, width/10*2, t, 0, 12)

        DrawMultiLineString(0,width/10*2.5,width/10,height-8,24,d6)
    end

    --bottom    
    --eink.print(0, 15+25*5, '_______________________', 0, 16)
    eink.show()
    sys.wait(3000) -- 3秒刷新一次

end






sys.taskInit(function()
    -- 先检查是否为想要的唤醒
    if not pm_wakeup_time_check() then
        sys.wait(10*60*1000)
    end

    log.info("eink", "begin setup")
	-- 设置屏幕为1.54寸墨水屏尺寸
	eink.model(eink.MODEL_3in7)
    -- 初始化必要的参数
    eink.setup(1, 0)
    -- 设置视窗大小
    eink.setWin(280, 480, 1)
    log.info("eink", "end setup")
    -- 稍微等一会,免得墨水屏没初始化完成
    sys.wait(1000)
    --eink.clear()
    --eink.print(16, 16, os.date(), 0, 12)
    --eink.show()
    --sys.wait(3000) -- 3秒刷新一次

    -- 服务器配置信息
    local host, port, selfid = "zhaopy.com", 1883, nbiot.imei()
    local mqttUsername ='taraxacum'
    local mqttPassword = '8492656'


    -- 等待联网成功
    while true do
        local i=0
        while not socket.isReady() do 
            if i<=180 then
                log.info("net", "wait for network ready",i)
                sys.waitUntil("NET_READY", 1000)
                i =i+1
            else
                sys.wait(500) -- 稍微等一会

                pm_enter_hib_mode(getsleeptime() ) -- 一小时一次够了吧
                break
            end

        end
        log.info("main", "Airm2m mqtt loop")
        
        local mqttc = mqtt.client(selfid, 120, mqttUsername,mqttPassword)
        while not mqttc:connect(host, port) do sys.wait(2000) end
        local topic_report = string.format("/device/%s/report", selfid)
        local topic_resp = string.format("/device/%s/resp", selfid)
        local device_set = string.format("%s", selfid)
        log.info("mqttc", "mqtt seem ok", "try subscribe", topic_req)
        if mqttc:subscribe(device_set) then
            log.info("mqttc", "mqtt subscribe ok", device_set)
            while true do
                log.info("mqttc", "wait for new msg")
                local r, data, param = mqttc:receive(120000, "pub_msg")
                log.info("mqttc", "mqttc:receive", r, data, param)
                if r then
                    if (data.topic==device_set) then
                        log.info("mqttc", "shenyang", data.payload or "nil", data.topic)   
                        local mydata=json.decode(data.payload) 
                        local db1=mydata["ime"]
                        cfg=tonumber(mydata["配置"])
                        local rate =tonumber(mydata["刷新"])
                        fs_write_rate(rate)
                        db=mydata["订阅"]
                        log.info("mqttc", "shenyang", db1,db[1],db[2],db[3],db[4],db[5],db[6],cfg,rate) 
                        sy1=db[1]
                        sy2=db[2]
                        sy3=db[3]
                        sy4=db[4]
                        sy5=db[5]
                        sy6=db[6]
                        table.sort(db)

                        --eink.print(10, 30+30*4, string.format("ime %s",db1), 0, 12)
                        --eink.print(10, 30+30*5, string.format("ime %s %s",db2[1],db2[2]), 0, 12)
                        --eink.show()
                        --sys.wait(500) -- 稍微等一会
                        break--跳出循环
                        --mqttc:subscribe(topic_req)
                    else
                        log.info("mqttc", "ok, something happen", "close connetion")
                        break
                    end                
                end
            end                          
        end

        local topic_req = string.format("%s/%s/%s/%s/%s/%s", db[1],db[2],db[3],db[4],db[5],db[6])--/device/%s/req", selfid)
        if mqttc:subscribe(topic_req) then
            log.info("mqttc", "mqtt subscribe ok", "try publish")
            --if mqttc:subscribe(device_set) then
                log.info("mqttc", "mqtt subscribe ok", device_set)
                --if mqttc:publish(topic_report, "test publish " .. os.date()  .. crypto.md5("12345"), 1) then
                while true do
                    log.info("mqttc", "wait for new msg")
                    local r, data, param = mqttc:receive(120000, "pub_msg")
                    log.info("mqttc", "mqttc:receive", r, data, param)
                    if r then
                        adc.open(1)
                        local _, bat = adc.read(1)
                        adc.close(1)
                        log.debug("Bat:", bat+0)

                        adc.open(0)
                        local _, cputemp = adc.read(0)
                        adc.close(0)
                        log.debug("cputemp:", cputemp+0)
                        
                        adc.open(2)
                        local _, adc2 = adc.read(2)
                        adc.close(2)
                        log.debug("adc2:", adc2+0)

                        --i2c.setup(0)
                        --local re, H, T = i2c.readSHT30(0)
                        --if re then
                        --    log.info("sht30", H, T)
                        --end
                        --i2c.close(0)
                    
                        -- 显示标题Title
                        log.info("mqttc", "get message from server", data.payload or "nil", data.topic)
                        if (data.topic==topic_req) then
                            local mydata=json.decode(data.payload)
                            local display1=string.format("%s %0.2f",mydata[sy1]["cncode"],mydata[sy1]["data"][1])
                            local display2=string.format("%s %0.2f",mydata[sy2]["cncode"],mydata[sy2]["data"][1])
                            local display3=string.format("%s %0.2f",mydata[sy3]["cncode"],mydata[sy3]["data"][1])
                            local display4=string.format("%s %0.2f",mydata[sy4]["cncode"],mydata[sy4]["data"][1])
                            local display5=string.format("%s %0.2f",mydata[sy5]["cncode"],mydata[sy5]["data"][1])
                            local display6=string.format("%s",mydata[sy6]["remark"])
                        
                            log.info("mqttc", "json parser ", mydata or "nil", data.topic)
                            display_show(cfg,bat,adc2,mydata[sy1]["cncode"],mydata[sy1]["data"][1],display1,display2,display3,display4,display5,display6)
                            sys.wait(500) -- 稍微等一会
                        end

                        adc.open(0) -- CPU温度
                        adc.open(2) -- 模块上的ADC0脚, 0-1.8v,不要超过范围使用!!!

                        local mytable ={}
                        mytable["imei"]=nbiot.imei()
                        mytable["time"]=os.date()
                        mytable["cputemp"]=cputemp
                        mytable["V"]=bat
                        --mytable["adc0"]=string.format("[%d,%d]",adc.read(2))
                        --mytable["H"]=H
                        --mytable["T"]=T
                        mytable["W"]=getsleeptime()
                        table.sort(mytable)
                        adc.close(0)
                        adc.close(2)
                        myjson=json.encode(mytable)
                        mytable=nil
                                    
                        mqttc:publish(topic_report, myjson, 1)
                        sys.wait(500) -- 稍微等一会
                        mqttc:disconnect()
                        pm_enter_hib_mode(getsleeptime() ) -- 一小时一次够了吧
                        --pm.force(pm.HIB)
                        --break
                    --elseif data == "pub_msg" then
                    --    log.info("mqttc", "send message to server", data, param)
                    --    mqttc:publish(topic_resp, "response " .. param)
                    --elseif data == "timeout" then
                    --    log.info("mqttc", "wait timeout, send custom report")
                    --    mqttc:publish(topic_report, "test publish " .. os.date() .. nbiot.imei())
                    else
                        log.info("mqttc", "ok, something happen", "close connetion")
                        break
                    end
                end
            --end
        end
        mqttc:disconnect()
        sys.wait(5000) -- 等待一小会, 免得疯狂重连
    end

end)

-- 用户代码已结束---------------------------------------------
-- 结尾总是这一句
sys.run()
-- sys.run()之后后面不要加任何语句!!!!!
