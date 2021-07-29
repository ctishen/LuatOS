
-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "mqttairm2m"
VERSION = "1.0.0"

-- sys库是标配
_G.sys = require("sys")

local mqtt = require "mqtt"

_G.pm_sleep_sec = 180

function getsleeptime()
    adc.open(1)
    local _, bat = adc.read(1)
    adc.close(1)
    log.debug("Bat:", bat+0)
    if (bat>4000)then
        return pm_sleep_sec
    end
    if (bat<4000 and bat>3800)then
        return pm_sleep_sec*5
    end
    if (bat<=3800 and bat>3600)then
        return pm_sleep_sec*10
    end
    if (bat<=3600 and bat>3400)then
        return pm_sleep_sec*20
    end
    if(bat<=3400) then
        return pm_sleep_sec*60
    end
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


sys.taskInit(function()
    -- 先检查是否为想要的唤醒
    if not pm_wakeup_time_check() then
        sys.wait(10*60*1000)
    end

    log.info("eink", "begin setup")
	-- 设置屏幕为1.54寸墨水屏尺寸
	eink.model(eink.MODEL_2in9)
    -- 初始化必要的参数
    eink.setup(0, 0)
    -- 设置视窗大小
    eink.setWin(128, 296, 1)
    log.info("eink", "end setup")

    -- 稍微等一会,免得墨水屏没初始化完成
    sys.wait(1000)

    -- 服务器配置信息
    local host, port, selfid = "broker.mqtt-dashboard.com", 1883, nbiot.imei()


    -- 等待联网成功
    while true do
        while not socket.isReady() do 
            log.info("net", "wait for network ready")
            sys.waitUntil("NET_READY", 1000)
        end
        log.info("main", "Airm2m mqtt loop")
        
        local mqttc = mqtt.client(selfid, nil, nil, false)
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
                        db=mydata["订阅"]
                        table.sort(db)
                        log.info("mqttc", "shenyang", db1,db[1],db[2],db[3],db[4],db[5]) 
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

        local topic_req = string.format("%s/%s/%s/%s/%s", db[1],db[2],db[3],db[4],db[5])--/device/%s/req", selfid)
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

                        i2c.setup(0)
                        local re, H, T = i2c.readSHT30(0)
                        if re then
                            log.info("sht30", H, T)
                        end
                        i2c.close(0)
                    
                        -- 显示标题Title
                        log.info("mqttc", "get message from server", data.payload or "nil", data.topic)
                        if (data.topic==topic_req) then
                            local mydata=json.decode(data.payload)
                            local db1=mydata[db[1]]["data"]
                            local db2=mydata[db[2]]["data"]
                            local db3=mydata[db[3]]["data"]
                            local db4=mydata[db[4]]["data"]
                            local db5=mydata[db[5]]["data"]
                        
                            log.info("mqttc", "json parser ", mydata or "nil", data.topic)
                            eink.bat(170, 2, tonumber(bat))
                            eink.print(10, 16, os.date(), 0, 12)
                            eink.printcn(10, 16+16, string.format("%s %0.2f",mydata[db[1]]["cncode"],db1[1]), 0, 16)
                            eink.printcn(10, 16+16*2, string.format("%s %0.2f",mydata[db[2]]["cncode"],db2[1]), 0, 16)
                            eink.printcn(10, 16+16*3, string.format("%s %0.2f",mydata[db[3]]["cncode"],db3[1]), 0, 16)
                            eink.printcn(10, 16+16*4, string.format("%s %0.2f",mydata[db[4]]["cncode"],db4[1]), 0, 16)
                            eink.printcn(10, 16+16*5, string.format("%s %0.2f",mydata[db[5]]["cncode"],db5[1]), 0, 16)
                            --eink.print(10, 25+16*5, string.format("V %d T %d H %d W %d",bat,T,H,getsleeptime()), 0, 12)
                            eink.show()
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
                        mytable["H"]=H
                        mytable["T"]=T
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
