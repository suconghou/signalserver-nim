
## WS

https://github.com/treeform/ws


静态编译

`docker pull nimlang/nim:alpine`

```
nim --gc:regions -d:release --passL:-static --opt:size c main && strip -s main
```


