# 关键字
## 1. 
#### (1) _attribute__((at(0X8010200))) - 绝对定位
- 定位到flash中，用于固化的信息：出厂设置的参数，上位机配置的参数，ID卡的ID号，flash标记
- 定位到RAM中，一般用于数据量比较大的缓存：串口的接收缓存，再就是某个位置的特定变量
[C语言中__attribute__ ((at())绝对定位的应用](https://www.cnblogs.com/CodeWorkerLiMing/p/12382711.html)