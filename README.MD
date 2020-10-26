
## WS

https://github.com/treeform/ws


静态编译

`docker pull nimlang/nim:alpine`

```
nim -d:release --passL:-static --opt:size c main && strip -s main
```

`--gc:regions` 编译出来的貌似有内存泄露

`len(a) == L` the length of the seq changed while iterating over it

