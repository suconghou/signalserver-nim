## signalserver

使用`nim`编写的信令服务器


nodejs版 https://github.com/suconghou/signalserver

## WS

ws 库为 https://github.com/treeform/ws


静态编译

`docker pull nimlang/nim:latest-alpine-slim`

需要关闭多线程

```
nim -d:release --passL:-s --passL:-static --mm:orc --threads:off c main
```
