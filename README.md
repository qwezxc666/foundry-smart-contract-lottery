# 可证明随机抽奖合约
## 关于
这个代码是为了创建一个可以证明是随机的智能合约彩票。
## 我们希望它做什么?
1.用户可以通过付费入场
1.彩票费将在抽奖过程中交给获胜者2.经过X个时间段后，彩票会自动抽取一个中奖者
1.这将以编程方式完成
3.Chainlink VRF的使用与链路自动化
1.链链式RF=随机性
2.Chainlink自动化->基于时间的触发器

## Test
1.编写脚本在本地、测试网络

## bug
1--forge coverage     会自动运行你的所有测试用例，并在后台收集代码覆盖率数据。完成后，它会生成一份详细的报告，显示每个文件、每个函数和每个语句的覆盖情况。
this is a bug
2-- console 
导包感觉没问题，使用并且运行后控制台会报错   不知道为啥，一开始好好的。   查询资料后无果 例如：生成remapping.txt 也无效


## 感觉学的稀碎 ，heardhat好用多了

## 下面是学习总结

### 节省gas费
1、public 换为 exteranl
2、immutable的使用 ---在合约部署时初始化且之后不变
3、view(函数可以读取合约状态，但不能修改状态)、pure(函数不能读取也不能修改合约状态)  gas： view > pure
4、calldata 代替 memory  calldata只读不能修改 ,memory 可读可修改.  例如_randomWords并没有修改
5、revert 自定义错误 代替require  revert 的自定义错误消息是紧凑的，能更高效地处理错误。
6、减少代码冗余


### pure的理解
不与链上交互、独立计算不存储时使用、不会消耗任何 gas

### 命名规则
与我以往的大驼峰习惯不同
1、对于 immutable 变量（在合约部署时初始化且之后不变），一般使用全小写字母，并且可以带有下划线，例如：i_entranceFee, i_interval。
2、常量：常量的命名一般是全大写字母，单词之间用下划线分隔。例如：REQUEST_CONFIRMATIONS, NUM_WORDS。
3、状态变量： 状态变量通常使用 s_ 作为前缀，以表示它们是合约的状态变量（state variables）。例如：s_players, s_recentWinner。
4、事件：驼峰式命名（camelCase），即第一个单词首字母小写，后续单词的首字母大写
5、自定义错误：使用合约名称作为前缀+“__” +错误的性质或原因。 例如： Raffle__NotEnoughEthSent, Raffle__TransferFailed
6、私有变量或内部变量： 下划线开头 。  例如：_randomWords

### 安全方面
1、CEI  "Checks-Effects-Interactions"（检查-效果-交互）设计模式
Checks：在函数的最开始检查所有的前提条件。如果条件不满足，立即 revert 或 require。
Effects：检查通过后，立即更新合约的内部状态。这一步应该在与外部交互之前完成，以确保合约状态的一致性。
Interactions：最后执行与外部合约或地址的交互。将这部分代码放在最后，可以减少重入攻击等潜在安全问题的风险。


### 测试方面
1、AAA  "Arrange, Act, Assert"
Arrange: 准备测试环境和数据。
Act: 执行测试的关键操作。
Assert: 验证操作的结果是否符合预期。
2、对于测试感觉到很陌生和很难上手