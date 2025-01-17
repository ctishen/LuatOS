
-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "taraxacum"
VERSION = "1.0.5"
BUILD   = 5
PROJECT_KEY = "01kgGFLlsfAabFuwJosS4surDNWOQCVH"

-- sys库是标配
_G.sys = require("sys")

local mqtt = require "mqtt"

_G.pm_sleep_sec = 60


function getsleeptime()
    adc.open(1)
    local _, bat = adc.read(1)
    local rate,info =fs_read_rate()
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

function fs_write_rate(rate,info)
    local f = os.remove("rate_time");
    local f = io.open("rate_time", "wb")
    local recinfo={
        ['rate']=1,
        ['info']=1,
    }
    if f then
        recinfo['rate']=rate
        recinfo['info']=info
        recinfo = json.encode(recinfo)
        f:write(recinfo)
        log.info("fs", "write c to file", recinfo, recinfo)
    --    log.info("fs", "write c to file", rate, tostring(rate))
    --    f:write(tostring(rate))
        f:close()
        
    end
    --f,recinfo=nil
    return rate,info
end

function fs_read_rate()
    local f = io.open("rate_time", "rb")
    local rate,info
    if f then
        local readjson= f:read("*a") 
        if readjson ~= nil then
            local table =json.decode(readjson)
            if table ~=nil then

                log.info("fs", "readjson", readjson)
                rate =  tonumber(table['rate'])
                info = tonumber(table['info'])
                log.info("shenyang", "rate info", rate,info)
                f:close()
            end

        end
    end

    if rate ==nil then 
        rate =1
    end
    if info ==nil then 
        info =1
    end

    return rate,info
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
    if pm.lastReson() == 0 then
        write_center(" ")--显示系统重新启动
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
   local j=1
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

        if (byteCount == 1) or(byteCount == 2) then
            width = width +  1
        else
            width = width + 2
            --print(char)
        end

        i = i + byteCount                                 -- 重置下一字节的索引

        print('i,lenInByte,width',i,lenInByte,width)

        if width >math.floor(screenwidth/fontsize)*2 or  i>=lenInByte then
            print(table.concat(tb))                                                        
            eink.printcn(x, y+j*lineheight,table.concat(tb), 0, fontsize)
            j=j+1
            tb={}
            width=0 
        
        end

        
        --if math.floor(width) >math.floor(screenwidth/fontsize)*2 or  i>=lenInByte then
        --    print(table.concat(tb))                                                        
        --    eink.printcn(x, y+j*lineheight,table.concat(tb), 0, fontsize)
        --    j=j+1
        --    tb={}
        --    width=0 
        
        --end


     

    end

 

    return width
end



function initeink()
    log.info("eink", "begin setup")
	-- 设置屏幕为1.54寸墨水屏尺寸
	eink.model(eink.MODEL_1in54_V2)
    -- 初始化必要的参数
    eink.setup(0, 0)
    -- 设置视窗大小
    eink.setWin(200, 200, 0)
    log.info("eink", "end setup")
    -- 稍微等一会,免得墨水屏没初始化完成
    sys.wait(1000)

end


function write_center(center_string)
    initeink()


    local t = os.date("%Y/%m/%d %H:%M")
    local width,height,rotate =eink.getWin()   --width280,height480
    --top
    --if bat<=3600 or bat>=4100 then
    --    eink.bat(height-30, 5, tonumber(bat))
    --end

    --eink.print( math.ceil( (height-string.len(center_string)*20 )/2 ), width/2-32/2, center_string, 0, 24)
    DrawMultiLineString(0,width/10*2.5,width/10,height-8,16,center_string)

    eink.show()
    sys.wait(5000) -- 3秒刷新一次
end

function display_show(dset,bat,adc2,mycode,mydata,d1,d2,d3,d4,d5,d6)
    initeink()
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
        DrawMultiLineString(0,20,width/10,height-8,16,d6)
    end
    if dset==4 then --one功能
        local tm = os.date("%d")
        local t = os.date("%b,%Y %a    %H:%M")
        --eink.printcn(10, 25*1, mycode, 0, 24)
        eink.print(0, width/10, tm, 0, 32)
        eink.print(45, width/10*2, t, 0, 12)

        DrawMultiLineString(0,width/10*2.5,width/10,height-8,24,d6)
        DrawMultiLineString(0,width/10*8,width/10,height-8,16,d1..' '..d2)
    end
    if dset==5 then --无数据界面
        local tm = os.date("%d")
        local t = os.date("%b,%Y %a")
        eink.print(0, width/10, tm, 0, 32)
        eink.print(45, width/10*2, t, 0, 12)

        DrawMultiLineString(0,width/10*2.5,width/10,height-8,24,d6)
        --eink.printcn(0,  width/10*9, d1, 0, 16)
        --eink.printcn(height/2,  width/10*9, d2, 0, 16)
    end

    --t,width,height,rotate,center_width =nil

    --bottom    
    --eink.print(0, 15+25*5, '_______________________', 0, 16)
    eink.show()
    sys.wait(5000) -- 3秒刷新一次

end




function ota(isupdate,buildnum)

    if (isupdate == false)or(buildnum<=BUILD) then
        return
    end

    -- 生成OTA的URL
    local iot_url = "http://zhaopy.com/upgrade.bin"
    local ota_url = string.format("%s?project_key=%s&imei=%s&firmware_name=%s&version=%s", 
                        iot_url,
                        PROJECT_KEY, 
                        nbiot.imei(),
                        PROJECT .. "_" .. rtos.firmware(),
                        VERSION
                    )

    log.info("ota", "url", iot_url)


    if socket.isReady() then
        
        write_center(string.format("系统升级中(imei:%s,firmware:%s,version:%s,build:%s)...", nbiot.imei(),PROJECT .. "_" .. rtos.firmware(),VERSION,BUILD))
        sys.wait(2000)
        http.get(iot_url, {dw="/update.bin"}, function(code,headers,body)
            if code == 200 then
                -- 当且仅当服务器返回200时,升级文件下载成功
                log.info("ota", "http ota ok!!", "reboot!!")
                write_center(" ")
                sys.wait(2000)

                rtos.reboot()
            else
                log.info("ota", "resp", code, body)
            end
        end)
        sys.wait(3000) -- 一小时检查一次
    else
        sys.wait(3000)
    end

    iot_url,ota_url =nil

end


sys.taskInit(function()
    -- 先检查是否为想要的唤醒
    
    local rate,info =fs_read_rate()
    log.info("-------------------------", rate,info)
    if not pm_wakeup_time_check() then
        sys.wait(10*60*1000)
    end


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
        --上电开机，检查OTA
        --log.info("pm", pm.lastReson())
        --if pm.lastReson() == 0 then 
            --ota()
        --end

        log.info("main", "Airm2m mqtt loop")
        
        local mqttc = mqtt.client(selfid, 120, mqttUsername,mqttPassword)
        while not mqttc:connect(host, port) do sys.wait(2000) end
        local topic_report = string.format("/device/%s/report", selfid)
        local topic_resp = string.format("/device/%s/resp", selfid)
        local device_set = string.format("%s", selfid)
        local topic_req = ''
        local sy1,sy2,sy3,sy4,sy5,sy6,cfg,bat,info
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
                        --local db1=mydata["ime"]
                        cfg=tonumber(mydata["配置"])
                        local db=mydata["订阅"]
                        rate =tonumber(mydata["刷新"])
                        ota(mydata["sent"],mydata["build"])--update
                        log.info("mqttc", "shenyang", db[1],db[2],db[3],db[4],db[5],db[6],cfg,rate) 
                        sy1=db[1]
                        sy2=db[2]
                        sy3=db[3]
                        sy4=db[4]
                        sy5=db[5]
                        sy6=db[6]
                        table.sort(db)
                        topic_req = string.format("%s/%s/%s/%s/%s/%s", db[1],db[2],db[3],db[4],db[5],db[6])
                        
                        mydata,data,db=nil

                        collectgarbage("collect");--为了有干净的环境,先把可以收集的其他垃圾赶走先
                        local  c1 = collectgarbage("count")
                        print("最开始,Lua的内存为",c1)
                        break--跳出循环
                        --mqttc:subscribe(topic_req)
                    else
                        log.info("mqttc", "ok, something happen", "close connetion")
                        break
                    end                
                end
            end                          
        end

        --local topic_req = string.format("%s/%s/%s/%s/%s/%s", db[1],db[2],db[3],db[4],db[5],db[6])--/device/%s/req", selfid)
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
                            local sn=tonumber(mydata[sy6]["sn"])
                            
                            log.info("mqttc", "json parser ", mydata or "nil", data.topic)
                            data=nil
                            
                            collectgarbage("collect");--为了有干净的环境,先把可以收集的其他垃圾赶走先
                            local  c1 = collectgarbage("count")
                            print("最开始,Lua的内存为",c1)
                            
                            local _,info =fs_read_rate()
                            --log.info("rate,info",rate,info)
                            --log.info("display",cfg,bat,adc2,mydata[sy1]["cncode"],mydata[sy1]["data"][1],display1,display2,display3,display4,display5,display6) 
                            --log.info("info,sn",info,sn)
                            if info ~=sn or pm.lastReson() == 0 then

                                display_show(cfg,bat,adc2,mydata[sy1]["cncode"],mydata[sy1]["data"][1],display1,display2,display3,display4,display5,display6)
                                fs_write_rate(rate,sn)
                            end
                            sys.wait(500) -- 稍微等一会
                        end

                        mydata,sy1,sy2,sy3,sy4,sy5,sy6,display1,display2,display3,display4,display5,display6=nil

                        --“sys”系统内存, “lua”虚拟机内存, 默认为lua虚拟机内存
                        --log.info("mem.lua", rtos.meminfo())  
                        --log.info("mem.sys", rtos.meminfo("sys"))
                        collectgarbage("collect");--为了有干净的环境,先把可以收集的其他垃圾赶走先
                        local  c1 = collectgarbage("count")
                        print("最开始,Lua的内存为",c1)

                        local mytable ={}
                        mytable["time"]=os.date()
                        mytable["version"]=VERSION
                        mytable["imei"]=nbiot.imei()
                        mytable["imsi"]=nbiot.imsi()
                        mytable["iccid"]=nbiot.iccid()
                        mytable["cputemp"]=cputemp
                        mytable["lastReson"]=pm.lastReson()
                        mytable["bat"]=bat
                        mytable["sleeptime"]=getsleeptime()
                        table.sort(mytable)
                        local myjson=json.encode(mytable)


                        mqttc:publish(topic_report, myjson, 1)
                        log.info("msg_data", myjson)
                        sys.wait(3000) -- 稍微等一会
                        mqttc:disconnect()
                        mytable,myjson =nil
                        collectgarbage("collect");--为了有干净的环境,先把可以收集的其他垃圾赶走先
                        local  c1 = collectgarbage("count")
                        print("最开始,Lua的内存为",c1)



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
