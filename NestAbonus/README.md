# Nest3.0分红操作

## NEST 投票合约（Nest_3_VoteFactory）
github地址：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/VoteContract/Nest_3_VoteFactory.sol

合约地址（主网）：0x6Cd5698E8854Fb6879d6B1C694223b389B465dea

合约地址（Ropsten）：0xa43f89dE7f9da44aa4d11106D7b829cf6ac0b561

### 建议
使用NEST系统合约进行操作或查询时，对应合约地址不建议设置固定值。可以通过通票合约checkAddress方法获取，动态获取对应合约的地址。避免合约升级后，链下更改代码。

```
// 获取 NEST Token 合约地址
_nestAddress = address(_voteFactory.checkAddress("nest"));
// 获取 NEST 系统收益分配逻辑合约地址
_tokenAbonus = _voteFactory.checkAddress("nest.v3.tokenAbonus");
.....
.....
.....
```


### NEST 系统收益池合约（Nest_3_Abonus）
github地址：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/NestAbonus/Nest_3_Abonus.sol

查询字段："nest.v3.abonus"

合约地址（主网）：0x43121397631551357EA511E62163B76e39D44852

合约地址（Ropsten）：0x559B1628ee6558EAb5E8a12A8951ecdF6f40EA28

### NEST 系统储蓄合约（Nest_3_Leveling）
github地址：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/NestAbonus/Nest_3_Leveling.sol

查询字段："nest.v3.leveling"

合约地址（主网）：0xaE2D09D7974a933c6dDC06b8039cF09783f4bAe8

合约地址（Ropsten）：0x9e9e49334a4e5506d5DA62e78602547EDf173C67

### NEST 系统收益锁仓验证合约（Nest_3_TokenSave）
github地址：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/NestAbonus/Nest_3_TokenSave.sol

查询字段："nest.v3.tokenSave"

合约地址（主网）：0x03904F4B9Fb54c61AAf96d0aCDD2e42a46c99102

合约地址（Ropsten）：0xdC912578B5e8f24b13E79ab072a1E9C86e659694

### NEST 系统收益分配逻辑合约（Nest_3_TokenAbonus）
github地址：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/NestAbonus/Nest_3_TokenAbonus.sol

查询字段："nest.v3.tokenAbonus"

合约地址（主网）：0x19E1d193A448bD13097EFC2aea867468726e67c5

合约地址（Ropsten）：0xDE83944619005d5EE4AAB951199748D599fCff44

### NEST Token 合约（ERC20）
github地址：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/NestToken/IBNEST.sol

查询字段："nest"

合约地址（主网）：0x04abEdA201850aC0124161F037Efd70c74ddC74C

合约地址（Ropsten）：0xf565422eBd4A8976e1e447a849b8B483C68EFD0C

## 操作
### 授权（存入Token前必须授权）- Nest_3_TokenSave
存入Nest或NToken前，需要调用ERC20合约授权方法，对 “NEST系统收益锁仓验证合约” 授权。

```
function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }
```

### 存入 - Nest_3_TokenAbonus
授权后，在非领取期（周一0点~周五12点），调用NEST系统收益分配逻辑合约（Nest_3_TokenAbonus），“depositIn”方法，存入对应的Token。
```
function depositIn(uint256 amount, address token) public
```
### 取出 - Nest_3_TokenAbonus
没有参与投票的情况下，任何时候都可以进行取出操作。调用NEST系统收益分配逻辑合约（Nest_3_TokenAbonus），“takeOut”方法，取出对应的Token。
```
function takeOut(uint256 amount, address token) public
```
### 领取分红 - Nest_3_TokenAbonus
领取期（周五12点~周日24点），调用NEST系统收益分配逻辑合约（Nest_3_TokenAbonus），“getAbonus”方法，领取对应token的分红。

```
function getAbonus(address token) public
```
### 查询分红信息 - Nest_3_TokenAbonus
输入参数 | 类型 | 描述
---|---|---
token | address | NEST或其他NToken地址

返回参数 | 类型 | 描述
---|---|---
nextTime | uint256 | 下次领取收益时间
getAbonusTime | uint256 | 本次领取收益截止时间
ethNum | uint256 | 收益池ETH数量
tokenValue | uint256 | 锁仓Token总流通量
myJoinToken | uint256 | 我存入的Token数量
getEth | uint256 | 我本期可领取的ETH数量
allowNum | uint256 | 我的锁仓Token对于‘NEST系统收益锁仓验证合约’的授权额度
leftNum | uint256 | 我的锁仓Token余额（个人钱包余额）
allowAbonus | bool | 本期是否已领取分红（true为已领取）

> 非领取期内或在领取期没有触发快照，ethNum和tokenValue显示实时数据。

> 在领取期内已经触发快照，ethNum和tokenValue显示快照数据。

> 本期没有领取过收益，getEth返回可以领取的额度。已经领取过收益，getEth返回0。

```
function getInfo(address token) public view returns (uint256 nextTime, uint256 getAbonusTime, uint256 ethNum, uint256 tokenValue, uint256 myJoinToken, uint256 getEth, uint256 allowNum, uint256 leftNum, bool allowAbonus)
```
### 查询储蓄基金金额 - Nest_3_Leveling
输入参数 | 类型 | 描述
---|---|---
token | address | NEST或其他NToken地址

返回参数 | 类型 | 描述
---|---|---
---| uint256 | 储蓄基金金额（实时数据）
```
function checkEthMapping(address token) public view returns (uint256)
```

### 查询收益池金额 - Nest_3_Abonus
输入参数 | 类型 | 描述
---|---|---
token | address | NEST或其他NToken地址

返回参数 | 类型 | 描述
---|---|---
---| uint256 | 收益池金额（实时数据）
```
function getETHNum(address token) public view returns (uint256) 
```
