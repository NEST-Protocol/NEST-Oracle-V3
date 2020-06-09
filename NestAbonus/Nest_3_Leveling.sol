pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/AddressPayable.sol";

/**
 * @title 平准合约
 * @dev eth转入与转出
 */
contract Nest_3_Leveling {
    using address_make_payable for address;
    using SafeMath for uint256;
    Nest_3_VoteFactory _voteFactory;                                //  投票合约
    uint256 _lightningCost = 1;                                     //  闪电贷收费比例
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor (address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory)); 
    }
    
    /**
    * @dev 修改投票合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
    }
    
    /**
    * @dev 转出平准
    * @param amount 转出数量
    * @param target 转出目标
    */
    function tranEth(uint256 amount, address target) public {
        require(address(msg.sender) == address(_voteFactory.checkAddress("nest.v3.nestAbonus")), "No authority");
        uint256 tranAmount = amount;
        if (amount > address(this).balance) {
            tranAmount = address(this).balance;
        }
        address payable addr = target.make_payable();
        addr.transfer(tranAmount);
    }
    
    /**
    * @dev 闪电贷
    * @param amount 借款数量
    */
    function flashing(uint256 amount) public payable {
        uint256 ethAmount = address(this).balance;
        require(amount <= ethAmount);
        require(msg.value == amount.mul(_lightningCost).div(1000));
        address payable addr = address(msg.sender).make_payable();
        addr.transfer(amount);
        Nest_3_FlashContract(address(msg.sender)).payBack();
        require(address(this).balance == ethAmount);
    }
    
    //  查看闪电贷收费比例
    function checkLightningCost() public view returns(uint256) {
        return _lightningCost;
    }
    
    //  修改闪电贷收费比例
    function changeLightningCost(uint256 num) public onlyOwner {
        _lightningCost = num;
    }
    
    fallback () external payable {
        
    }
    
    receive() external payable {
        
    }
    
    //  仅限管理员
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender) == true, "No authority");
        _;
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