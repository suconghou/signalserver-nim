## signalserver

使用`nim`编写的信令服务器


nodejs版 https://github.com/suconghou/signalserver

## WS

ws 库为 https://github.com/treeform/ws


静态编译

`nimlang/nim`容器内编译

需要关闭多线程

```
nim --mm:orc --threads:off --passC:-flto --passL:-flto -d:release --passL:-s --passL:-static --opt:speed c main
```
