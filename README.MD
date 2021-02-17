##

使用`nim`编写的信令服务器


## WS

https://github.com/treeform/ws


静态编译

`docker pull nimlang/nim:alpine`

```
nim -d:release --passL:-static --opt:size c main && strip -s main
```

在 `nim` 中,迭代中不能删除或添加被迭代的对象,
否则报错

`len(a) == L` the length of the seq changed while iterating over it

