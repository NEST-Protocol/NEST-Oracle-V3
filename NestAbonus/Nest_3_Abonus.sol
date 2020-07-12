pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/AddressPayable.sol";

/**
 * @title ETH分红池
 * @dev ETH领取与查询
 */
contract Nest_3_Abonus {
    using address_make_payable for address;
    using SafeMath for uint256;
    
    Nest_3_VoteFactory _voteFactory;                                //  投票合约
    address _nestAddress;                                           //  NEST 合约地址
    mapping (address => uint256) ethMapping;                        //  token对应 ETH 分红账本
    uint256 _mostDistribution = 40;                                 //  最高NEST分红池分配比例
    uint256 _leastDistribution = 20;                                //  最低NEST分红池分配比例
    uint256 _distributionTime = 1200000;                            //  NEST分红池分配比例每次衰减时间间隔
    uint256 _distributionSpan = 5;                                  //  NEST分红池分配比例每次衰减程度
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(voteFactory);
        _nestAddress = address(_voteFactory.checkAddress("nest"));
    }
 
    /**
    * @dev 重置投票合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner{
        _voteFactory = Nest_3_VoteFactory(voteFactory);
        _nestAddress = address(_voteFactory.checkAddress("nest"));
    }
    
    /**
    * @dev 转入分红
    * @param token 对应锁仓 NToken
    */
    function switchToEth(address token) public payable {
        ethMapping[token] = ethMapping[token].add(msg.value);
    }
    
    /**
    * @dev 转入分红-nToken报价手续费
    * @param token 对应锁仓 NToken
    */
    function switchToEthForNTokenOffer(address token) public payable {
        Nest_NToken nToken = Nest_NToken(token);
        (uint256 createBlock,) = nToken.checkBlockInfo();
        uint256 subBlock = block.number.sub(createBlock);
        uint256 times = subBlock.div(_distributionTime);
        uint256 distributionValue = times.mul(_distributionSpan);
        uint256 distribution = _mostDistribution;
        if (_leastDistribution.add(distributionValue) > _mostDistribution) {
            distribution = _leastDistribution;
        } else {
            distribution = _mostDistribution.sub(distributionValue);
        }
        uint256 nestEth = msg.value.mul(distribution).div(100);
        ethMapping[_nestAddress] = ethMapping[_nestAddress].add(nestEth);
        ethMapping[token] = ethMapping[token].add(msg.value.sub(nestEth));
    }
    
    /**
    * @dev 领取
    * @param num 领取数量
    * @param token 对应锁仓 NToken
    * @param target 转账目标
    */
    function getETH(uint256 num, address token, address target) public onlyContract {
        require(num <= ethMapping[token], "Insufficient storage balance");
        ethMapping[token] = ethMapping[token].sub(num);
        address payable addr = target.make_payable();
        addr.transfer(num);
    }
    
    /**
    * @dev 获取分红池余额
    * @param token 对应锁仓 NToken
    * @return uint256 分红池余额
    */
    function getETHNum(address token) public view returns (uint256) {
        return ethMapping[token];
    }
    
    // 查看 NEST 地址
    function checkNestAddress() public view returns(address) {
        return _nestAddress;
    }
    
    // 查看最高 NEST 分红池分配比例
    function checkMostDistribution() public view returns(uint256) {
        return _mostDistribution;
    }
    
    // 查看最低 NEST 分红池分配比例
    function checkLeastDistribution() public view returns(uint256) {
        return _leastDistribution;
    }
    
    // 查看 NEST 分红池分配比例每次衰减时间间隔
    function checkDistributionTime() public view returns(uint256) {
        return _distributionTime;
    }
    
    // 查看 NEST 分红池分配比例每次衰减程度
    function checkDistributionSpan() public view returns(uint256) {
        return _distributionSpan;
    }
    
    // 修改最高 NEST 分红池分配比例
    function changeMostDistribution(uint256 num) public onlyOwner  {
        _mostDistribution = num;
    }
    
    // 修改最低 NEST 分红池分配比例
    function changeLeastDistribution(uint256 num) public onlyOwner  {
        _leastDistribution = num;
    }
    
    // 修改 NEST 分红池分配比例每次衰减时间间隔
    function changeDistributionTime(uint256 num) public onlyOwner  {
        _distributionTime = num;
    }
    
    // 修改 NEST 分红池分配比例每次衰减程度
    function changeDistributionSpan(uint256 num) public onlyOwner  {
        _distributionSpan = num;
    }
    
    // 取出ETH
    function turnOutAllEth(uint256 amount, address target) public onlyOwner {
        address payable addr = target.make_payable();
        addr.transfer(amount);  
    }
    
    // 仅限分红逻辑合约
    modifier onlyContract(){
        require(_voteFactory.checkAddress("nest.v3.tokenAbonus") == address(msg.sender), "No authority");
        _;
    }
    
    // 仅限管理员
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(address(msg.sender)), "No authority");
        _;
    }
}

// 投票工厂
interface Nest_3_VoteFactory {
    // 查询地址
	function checkAddress(string calldata name) external view returns (address contractAddress);
	// 查看是否管理员
	function checkOwners(address man) external view returns (bool);
}

// NToken
interface Nest_NToken {
    // 增发
    function increaseTotal(uint256 value) external;
    // 查询挖矿信息
    function checkBlockInfo() external view returns(uint256 createBlock, uint256 recentlyUsedBlock);
    // 查询创建者
    function checkOwner() external view returns(address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}