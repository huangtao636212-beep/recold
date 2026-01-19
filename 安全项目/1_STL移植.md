# 1 整体查看
## 1.1 先定三条总原则（后面所有实现都围绕它）
- 上电默认安全：POST 未完成前，所有安全相关输出必须保持去能量（硬件优先，软件只是补充）。
- 放行门禁：进入 RUN / 释放安全输出的条件 = 本 MCU POST_OK 且 对端 POST_OK 且 MCU 间安全通信 OK（新鲜度/CRC/计数器/超时）。
- 运行期持续证明健康：POST 证明“t=0 健康”，运行期诊断证明“持续健康”。任一失效 → 统一故障链路 → Safe State（更保守决策）。

## 1.2 三大阶段要做的事情
### 1.2.1 Boot/Reset 后、进入 STL 之前（最早期安全落地）

### 1.2.2 POST阶段
#### (1) 硬件安全态建立
- 安全输出去能量（继电器/MOSFET 关闭、雷达 SAFE ZONE、STO/主接触器断开等）
- 关键引脚设置为安全值并锁住（必要时用硬件拉/外部安全链路确保）
#### (2) 最小系统可运行
- 时钟/电源监控基础就绪（最小的 SysTick/Timer、必要的 SRAM 可用）
#### (3) STL POST（能在启动做完的尽量做完）
- CPU/ALU/寄存器类测试
- Clock/频率监控类测试（或最小频率合理性检测）
- Flash/ROM 完整性（常见：CRC/HASH 对关键区域）
- RAM 测试：
  - 强烈建议：启动阶段至少覆盖“安全关键 RAM 区 + STL 自己用的 RAM 区 + 堆栈相关区”（你已经在 scatter/section 上做隔离了，这里就很好落地）
  - 对 noinit/证据区/备份区要明确“测不测、怎么测”，避免破坏保留数据
#### (4) 安全基础设施初始化
- Watchdog 策略进入确定态（什么时候启用、POST 期间怎么喂狗/怎么超时都要固定）
- Fault Manager / Evidence Log 初始化（记录 reset cause、POST 结果、版本号、配置 CRC 等）
#### (5) 生成 POST 摘要并互发确认
- post_digest（建议包含：固件版本/配置CRC、启用的测试位图、每项结果码、计数器/nonce）
- 通过 安全帧互发 + 校验新鲜度
- 进入 RUN 的条件：local_post_ok && peer_post_ok && comm_ok
### 1.2.3 运行期诊断（Run-time / Cyclic STL）

### 1.2.3 实现方式
#### (1) 你可以把诊断组织成三个模块（都走同一 Fault 链路）：
  - **diag_post_stl()**：只在启动跑，产出 post_digest
  - **diag_runtime_stl_step()**：每周期固定预算跑一步
  - **diag_peer_comm_step()**：每周期处理安全帧 + 一致性检查
最后统一进入：fault_trigger(classify)->reaction->evidence_log
#### (2)测试前必须先搭好“观测与证据”三件套（不然跑了也没法证明）
**A. 观测点（建议最少 3 个）**
- 串口/日志：打印 POST start/end、每项 test 的 PASS/FAIL + errcode、进入 Safe State 的原因
- GPIO 时间戳：POST 入口拉高、POST 结束拉低（示波器/逻辑分析仪量耗时）
- Evidence Log：故障发生时写入：fault_id/test_id/errcode/timestamp/mode/mcu_role/peer_state
**B. Safe State 必须可确认**
- 一旦 FAIL：安全输出（继电器/MOSFET/区域选择/STO permit）要立刻去能量
- 最好加一个“安全输出状态灯/测点”，让你肉眼/仪器能确认真的断了
**C. 测试开关（故障注入）**
- 你已经有 SVC_STL_FAULT_INJECT 结构体那种思路就很好：
- 编译期宏开关（默认关闭，测试时打开）
- 运行期注入配置（shell 命令/串口命令设置一次性 oneshot）

## 1.3 STL究竟要做什么，有哪些故障，和如何注入以及如何手工注入
### 1.3.0 故障模型
##### (1) stuck-at(卡死)
- 含义（逻辑层）：某个节点/位永远读成 0 或永远读成 1（写不进去、翻不过去）。
- 物理直觉：晶体管短路/开路、存储单元失效、位线/字线缺陷，导致该位失去可控性。
- 表现：
  - CPU：某条控制信号/寄存器位/组合逻辑点卡死 → 某些指令结果永远错或某种分支永远走不对。
  - SRAM：某 bit 无论写 0/1，总是读回固定值。
  - Flash：某 bit 退化成“写不回去”或“总像 1/0”，但 Flash 更常被归入“corruption/retention”语义去描述。
##### (2) bridging / coupling（桥接/耦合）
- bridging（桥接）：两根原本独立的线（位线/数据线/相邻节点）被短接或形成导通路径 → 读写时会互相拉扯，出现相关性错误（写 A 会把 B 一起带偏）。
- coupling（耦合）：不一定短接，也可能是寄生电容、邻线串扰等 → 出现模式相关的错误（相邻位写特定模式时更容易出错）
- 它们是非常“硬件味”的随机故障模型，尤其在 SRAM/总线类结构里常见
##### (3) data retention（保持性）
- 含义（逻辑层）：你写进去了，但随着时间/温度/电压，内容慢慢漂移变错（即使你没再写）。
- 物理直觉：
  - SRAM：泄漏电流导致节点电荷保持不住（SRAM 理论上不靠电荷存储，但节点电平仍会受漏电影响）。
  - Flash：浮栅电荷泄漏、隧穿、老化 → 长期保持能力下降。
##### (4) data corruption（数据损坏）
- 含义：存储内容出现非预期改变（被改写、位翻转、读出错误等）。
### 1.3.1 STL覆盖哪些故障
#### 1.3.1.1 硬件异常
##### (0) 概述
- 表示测试模块认为被测(CPU/Flash/SRAM)出现了硬件层面的错误
- 任何 CPU TM 检出故障，都应把 CPU 视为不再可靠工作
##### (1) CPU
- CPU:覆盖`stuck-at`、`bridging/coupling`，但`又不足以覆盖CPU子系统全部`
- TM1-TM12：本质是一组功能/寄存器/算数/访存/控制流/Cache/MPU相关的测试向量
- 硬件内部有短路/卡死 → 最终表现为“某些运算/控制流/访存行为不再符合规格” → 被测试向量捕捉到
- 不够：CPU不只有内核，NVIC、BusMatrix、调试、系统总线接口、某些外围互连、时钟/复位域、甚至安全相关的系统配置都可能影响“危险行为”。

##### (2) RAM
- RAM 测试模块使用`March C-`算法 == 通过一系列`有方向、有顺序的读写操作`去激活并观测多种RAM故障类别
- 对应故障模型：`stuck-at` 、`bridging/coupling`、`retention`
- STL RAM 测试需要`backup buffer`来在运行中保护原数据，并按`shots/blocks`分段覆盖，避免一次性长阻塞。
- 边界：
  - 测试的subset，备份区本身也要被保护，测试周期
##### (3) Flash CRC校验
- Flash TM 的本质是：对“你声明的那段 Flash 内容”做 CRC 指纹比对。
- 对应错误模型：`data corruption`、`data retrntion`
- 边界
  - 只覆盖你纳入 subset 的区域（不在 subset 内的坏了，STL 不会知道）
  - 依赖“参考 CRC 自身可靠”（CRC 表/存放区如果也被破坏，或生成流程不对，可能出现“错的参考去对比错的内容”）
  - CRC 也有“理论碰撞概率”（非常小，但在严格论证里属于残余风险的一部分）

#### 1.3.1.2 接口/配置/运行条件不满足
##### (0) 概述
- 这是STL的`防御式编程检查`或"状态机/配置合法性检查"发现问题：
  - 如参数指针为NULL、状态不允许、配置不合法、运行上下文不满足
##### (1)
### 1.3.2 如何查看故障
### 1.3.3 人为注入故障清单


























1）测试路线图（按这个顺序，成功率最高）
Phase 1：单 MCU 先跑通（强烈建议先这样）

目标：先证明 STL 能在你工程里稳定工作，不被双 MCU/通信干扰。

只启用 1~2 个 STL POST 测试
建议顺序：CPU → RAM（分段） → Flash CRC → Clock

PASS：能稳定进入 RUN（输出仍保持你定义的放行逻辑）

FAIL：任一测试失败 → 进入 Safe State + 锁存 + Evidence Log 有记录

做一次 故障注入，确认 FAIL 路径闭环

单 MCU 成功后，再进双 MCU。否则一出问题你很难定位是 STL、链接脚本、还是互检通信。

Phase 2：双 MCU POST 门禁测试

目标：证明“两边都 POST_OK 且通信 OK 才放行”。

用例：

两边都 PASS → RUN 放行 ✅

MCU1 注入 FAIL、MCU2 PASS → 仍禁止 RUN/进入 Safe State ✅

MCU1 PASS、MCU2 PASS，但通信异常（CRC/计数器/超时）→ 禁止 RUN ✅

输出证据：

两边各自 post_digest 记录（含版本/配置CRC/测试位图/结果）

互发成功/失败的原因（counter/timeout/CRC err）

Phase 3：运行期分片诊断 + 稳定性

目标：证明运行期不会破坏确定性周期，也能在规定时间内发现故障。

用例：

运行期 STL 分片任务持续运行 30 分钟 / 2 小时 / 24 小时（你自己定目标）

测量：每周期 STL 的 最大耗时 WCET（用 GPIO 或 DWT 计时）

注入“运行中 RAM fault” → 在规定检测窗口内触发 Safe State

输出证据：

WCET 最大值

覆盖周期（比如 “每 10ms 测 256B，多久覆盖完目标 RAM 区”）

触发到 Safe State 的时间（检测+反应总延迟）

2）一张“必须做”的测试用例清单（SIL3 很关键）
A. STL 自检类（本 MCU 内部）

CPU test：注入 FAIL（例如强制返回错误码）→ Safe State

RAM test：

注入：对被测段写坏一个字（或模拟 March 失败）→ Safe State

验证：不会误伤 noinit/证据区/栈区（map + 运行行为）

Flash/ROM CRC：

注入：期望 CRC 改错 / 校验范围改错 → 必须能 FAIL

Clock test：

注入：切换到错误分频/异常频率阈值 → FAIL

B. 安全通信类（链路完整性）

CRC 错误：随机翻转 payload 1 bit → 接收端必须丢弃 + 计数错误

计数器错误：重复帧 / 跳号帧 → 必须诊断

超时：连续丢帧 T ms → 必须进入 Safe State（或你定义的降级策略）

C. 双 MCU 一致性互检（语义一致性）

MCU1/MCU2 输出请求不一致 → 进入 Safe State（更保守）

任一 MCU 宣称 “request_safe_state” → 双方都必须进入 Safe State

任一 MCU health_digest 标记异常 → 禁止输出 permit

3）通过判据（你每个用例都要写这 4 条）

每个测试用例你都按这个格式写，后面直接能进测试报告：

触发条件：注入方式/故障条件是什么

期望检测：由谁检测（本地 STL / 通信监控 / 一致性检查）

期望反应：进入 Safe State/锁存/是否允许受控恢复

时间要求：从故障发生到输出去能量的最大时间（你项目 SRS 里那条）

4）你现在“立刻开始”的第一轮测试（今天就能做）

按下面 6 步走，不需要额外等任何东西：

先只开 MCU1（或只看 MCU1），启用 CPU POST

确认 PASS：能走完整启动链路，记录 POST 耗时

打开 CPU 故障注入：一次性 oneshot 让 CPU test FAIL

确认 FAIL：Safe State + 锁存 + Evidence Log 有 test_id/errcode

再加 RAM POST（只测你专用 stl_ram_test_section）

重复：PASS 一次 + 注入 FAIL 一次

这轮通过后，你就具备“STL 在工程里能跑、能失败、失败会安全”的最小闭环。