
# 投票合约文档
## 普通状态投票
1. 部署执行合约，合约内包含修改内容，开源。
2. 部署投票合约，质押至少 10 枚 NestNode并提交已创建的执行合约地址。
3. 投票合约创建 1 天内，投票合约内的 NN 数量大于等于100，可以进入 Nest 投票流程。
4. 投票中的个人Nest投票数量根据当前个人锁仓量计算，Nest投票超过总流通量的51%（大于等于），通票通过。
5. 投票合约创建7天后可以执行已经投票通过的合约。

## 紧急状态投票
1. 投票工厂内需要有大于等于1000个NestNode，切换紧急状态并设置紧急状态时间。
2. 紧急状态中，使用 10 个NestNode 创建紧急投票。紧急投票合约创建 1 天内，紧急投票合约内的 NN 数量大于等于100，可以进入 Nest 投票流程。
3. 紧急投票合约中的总流通量根据分红前2期快照数据计算，紧急投票中的个人Nest投票数量，根据分红前2期个人锁仓Nest快照数据计算。
4. 紧急投票中Nest投票超过51%，可以立即执行修改内容。
5. 超过紧急状态持续时间（3天）。任何人可以触发切换回普通状态。

### 触发紧急状态的判断条件
1. 投票工厂合约内的NestNode数量大于等于1000
2. 当前状态不是紧急状态
3. 任何参与存入1000个NestNode的用户地址都可以切换紧急状态

### 切换回普通状态的判断条件
1. 当前状态是紧急状态
2. 紧急状态持续超过 3 天
3. 任何人可以触发切换回普通状态

## 注意
1. 个人Nest票数读取个人Nest锁仓数量
2. 一个地址在同一之间只能参与一个合约的投票。如果发生冲突，需要取消之前的投票合约，然后重新投票。
3. 用户地址参与投票后，该投票合约结束前，用户地址无法取出锁仓Nest（存入Nest、领取分红不受影响）。


## 属性

属性| 描述
---|---
_limitTime | 投票持续时间，默认 7 days
_NNLimitTime | NestNode筹集时间，默认 1 days
_circulationProportion | 通过票数比例，默认 51%
_NNUsedCreate | 创建投票合约最小 NN 数量，默认 10个
_NNCreateLimit | 开启投票需要筹集 NN 最小数量，默认 100个
_emergencyTime | 紧急状态启动时间
_emergencyTimeLimit | 紧急状态持续时间，默认 3 days
_emergencyNNAmount | 切换紧急状态需要nn数量，默认 1000 个
_NNToken | 守护者节点Token（NestNode）
_nestToken | NestToken
_contractAddress | 投票合约映射，查询系统内合约地址。字符串 => 合约地址
_modifyAuthority | 系统修改权限。地址 => Bool
_myVote | 我最近的投票。用户地址 => 投票合约地址
_emergencyPerson | 紧急状态个人NN存储量。用户地址 => 转入的NN数量
_contractData | 投票合约集合。投票合约地址 => Bool
_stateOfEmergency | 紧急状态
_destructionAddress | 销毁合约地址

## 公开方法

### 创建投票合约

输入参数 | 描述
---|---
implementContract| 投票可执行合约地址
nestNodeAmount | 质押 NN 数量，至少 10 个
```
function createVote(address implementContract, uint256 nestNodeAmount) public
```

### 使用 nest 投票

输入参数 | 描述
---|---
contractAddress| 投票合约地址

```
function nestVote(address contractAddress) public
```

### 使用 nestNode 投票

输入参数 | 描述
---|---
contractAddress| 投票合约地址
NNAmount| 质押 NN 数量

```
function nestNodeVote(address contractAddress, uint256 NNAmount) public
```

### 执行投票

输入参数 | 描述
---|---
contractAddress| 投票合约地址

```
function startChange(address contractAddress) public
```

### 切换紧急状态-转入NestNode

输入参数 | 描述
---|---
amount| 转入 NestNode 数量

```
function sendNestNodeForStateOfEmergency(uint256 amount) public
```

### 切换紧急状态-取出NestNode

```
function turnOutNestNodeForStateOfEmergency() public
```

### 修改紧急状态

```
function changeStateOfEmergency() public
```

