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
    uint256 _lightningCost = 1;                                     //  闪电贷收费比例
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(voteFactory);
    }
 
    /**
    * @dev 重置投票合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner{
        _voteFactory = Nest_3_VoteFactory(voteFactory);
    }
    
    /**
    * @dev 领取
    * @param num 领取数量
    * @param target 转账目标
    */
    function getETH(uint256 num, address target) public onlyContract {
        require(num <= getETHNum(), "Insufficient storage balance");
        address payable addr = target.make_payable();
        addr.transfer(num);                                                                             
    }
    
    /**
    * @dev 获取分红池余额
    * @return uint256 分红池余额
    */
    function getETHNum() public view returns (uint256) {
        return address(this).balance;
    }
    
    /**
    * @dev 闪电贷
    * @param amount 借款数量
    */
    function flashing(uint256 amount) public payable {
        uint256 ethAmount = getETHNum();
        require(amount <= ethAmount);
        require(msg.value == amount.mul(_lightningCost).div(1000));
        address payable addr = address(msg.sender).make_payable();
        addr.transfer(amount);
        Nest_3_FlashContract(address(msg.sender)).payBack();
        require(getETHNum() == ethAmount);
    }
    
    //  仅限分红逻辑合约
    modifier onlyContract(){
        require(_voteFactory.checkAddress("nest.v3.nestAbonus") == msg.sender, "No authority");
        _;
    }
    
    //  仅限管理员
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender) == true, "No authority");
        _;
    }
    
    //  查看闪电贷收费比例
    function checkLightningCost() public view returns(uint256) {
        return _lightningCost;
    }
    
    //  修改闪电贷收费比例
    function changeLightningCost(uint256 num) public onlyOwner {
        _lightningCost = num;
    }
    
    fallback () external payable  {
        
    }
    
    receive() external payable {
        
    }
}

interface Nest_3_FlashContract {
    function payBack() external;
}

// 投票工厂
interface Nest_3_VoteFactory {
    //  查看是否有正在参与的投票 
    function checkVoteNow(address user) external view returns(bool);
    //  查询地址
	function checkAddress(string calldata name) external view returns (address contractAddress);
	//  查看是否管理员
	function checkOwners(address man) external view returns (bool);
}