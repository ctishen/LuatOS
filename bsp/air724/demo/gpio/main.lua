
PROJECT = "gpiodemo"
VERSION = "1.0.0"

local sys = require "sys"

pmd.ldoset(3000, pmd.LDO_VLCD)
pmd.ldoset(3300, pmd.LDO_VIBR)

sys.taskInit(function()
    netled = gpio.setup(1, 0)
    netmode = gpio.setup(4, 0)
    while 1 do
        netled(1)
        netmode(0)
        sys.wait(500)
        netled(0)
        netmode(1)
        sys.wait(500)
        log.info("luatos", "hi", os.date())
    end
end)


-- 用户代码已结束---------------------------------------------
-- 结尾总是这一句
sys.run()
-- sys.run()之后后面不要加任何语句!!!!!
