## signalserver

使用`nim`编写的信令服务器


nodejs版 https://github.com/suconghou/signalserver

## WS

ws 库为 https://github.com/treeform/ws


静态编译

`docker pull nimlang/nim:alpine`

```
nim -d:release --passC:-flto --passL:-flto --passL:-s --passL:-static --opt:size c main
```
