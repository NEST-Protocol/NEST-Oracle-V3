

## NEST Vote Contract（Nest_3_VoteFactory）
github address：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/VoteContract/Nest_3_VoteFactory.sol

contract address（mainnet）：0x6Cd5698E8854Fb6879d6B1C694223b389B465dea

contract address（Ropsten）：0xa43f89dE7f9da44aa4d11106D7b829cf6ac0b561

### Suggestions
When using the NEST system contract for operations or quer, it is not recommended to set a fixed value for `contract address`. It can be obtained through the `checkAddress` method of the vote contract to dynamically obtain the address of the corresponding contract. Avoid changing the code off-chain after the contract is upgraded.

```
_nestAddress = address(_voteFactory.checkAddress("nest"));
_tokenAbonus = _voteFactory.checkAddress("nest.v3.tokenAbonus");
.....
.....
.....
```


### NEST bonus pool contract（Nest_3_Abonus）
github address：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/NestAbonus/Nest_3_Abonus.sol

query field："nest.v3.abonus"

contract address（mainnet）：0x43121397631551357EA511E62163B76e39D44852

contract address（Ropsten）：0x559B1628ee6558EAb5E8a12A8951ecdF6f40EA28

### NEST leveling contract（Nest_3_Leveling）
github address：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/NestAbonus/Nest_3_Leveling.sol

query field："nest.v3.leveling"

contract address（mainnet）：0xaE2D09D7974a933c6dDC06b8039cF09783f4bAe8

contract address（Ropsten）：0x9e9e49334a4e5506d5DA62e78602547EDf173C67

### NEST abonus save contract（Nest_3_TokenSave）
github address：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/NestAbonus/Nest_3_TokenSave.sol

query field："nest.v3.tokenSave"

contract address（mainnet）：0x03904F4B9Fb54c61AAf96d0aCDD2e42a46c99102

contract address（Ropsten）：0xdC912578B5e8f24b13E79ab072a1E9C86e659694

### NEST bonus logic contract（Nest_3_TokenAbonus）
github address：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/NestAbonus/Nest_3_TokenAbonus.sol

query field："nest.v3.tokenAbonus"

contract address（mainnet）：0x19E1d193A448bD13097EFC2aea867468726e67c5

contract address（Ropsten）：0xDE83944619005d5EE4AAB951199748D599fCff44

### NEST Token contract（ERC20）
github address：https://github.com/NEST-Protocol/NEST-oracle-V3/blob/master/NestToken/IBNEST.sol

query field："nest"

contract address（mainnet）：0x04abEdA201850aC0124161F037Efd70c74ddC74C

contract address（Ropsten）：0xf565422eBd4A8976e1e447a849b8B483C68EFD0C

## Operations
### Approval（Approval should be done before depositing Tokens）- Nest_3_TokenSave
Before depositing Nest or NToken，you should call ERC20 Approval method for "NestNode bonus save contract".

```
function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }
```

### Depositing - Nest_3_TokenAbonus
After the approcal，in non-receiving period ( Monday 0h - Friday 12h），call  `depositIn` method in "NEST bonus logic contract"（Nest_3_TokenAbonus)，and deposit Tokens。
```
function depositIn(uint256 amount, address token) public
```
### Withdrawing - Nest_3_TokenAbonus
In the condition of not participating in voting，withdrawing can be performed at any time. Call `takeOut` method in "NEST bonus logic contract"（Nest_3_TokenAbonus），and withdraw Tokens.
```
function takeOut(uint256 amount, address token) public
```
### Getting bonus - Nest_3_TokenAbonus
Receiving period（Friaday 12h~Sunday 24h），call `getAbonus` method in "NEST bonus logic contract"（Nest_3_TokenAbonus)，receive bonus of tokens.

```
function getAbonus(address token) public
```
### Checking bonus information - Nest_3_TokenAbonus
input parameter | type | description 
---|---|---
token | address | NEST or other NToken address 

returned parameter | type | description 
---|---|---
nextTime | uint256 | Next bonus time 
getAbonusTime | uint256 | Deadline to receive bonus in this period 
ethNum | uint256 | Amount of ETH in bonus pool 
tokenValue | uint256 | circulation of locked Tokens 
myJoinToken | uint256 | The amount of my deposited Tokens 
getEth | uint256 | The amount of ETH I can receive in this period 
allowNum | uint256 | My approved allowance to "NestNode bonus save contract" 
leftNum | uint256 | My balance of approved Token (in personal wallet) 
allowAbonus | bool | Whether bonus is received in this period（true for received） 

> In non-receiving period or snapshot is not triggered in receiving period, ethNum and tokenValue show real-time data.

> In receiving period or snapshot is triggered, ethNum and tokenValue show snapshot data.

> When bonus is not received in this period，getEth returns the amount to receive. When bonus is received, getEth returns 0. 

```
function getInfo(address token) public view returns (uint256 nextTime, uint256 getAbonusTime, uint256 ethNum, uint256 tokenValue, uint256 myJoinToken, uint256 getEth, uint256 allowNum, uint256 leftNum, bool allowAbonus)
```
### Checking fund amount of leveling savings - Nest_3_Leveling
input parameter | type | description 
---|---|---
token | address | NEST or other NToken address 

returned parameter | type | description 
---|---|---
---| uint256 | leveling savings amount (real-time data) 
```
function checkEthMapping(address token) public view returns (uint256)
```

### Checking fund amount of bonus pool - Nest_3_Abonus
input parameter | type | description 
---|---|---
token | address | NEST or other NToken address 

returned parameter | type | description 
---|---|---
---| uint256 | bonus pool  amount (real-time data) 
```
function getETHNum(address token) public view returns (uint256) 
```
