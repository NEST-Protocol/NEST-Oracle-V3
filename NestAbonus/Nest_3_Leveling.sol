pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/AddressPayable.sol";

/**
 * @title 平准合约
 * @dev ETH转入与转出
 */
contract Nest_3_Leveling {
    using address_make_payable for address;
    using SafeMath for uint256;
    Nest_3_VoteFactory _voteFactory;                                //  投票合约
    mapping (address => uint256) ethMapping;                        //  Token对应 ETH 平准账本
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor (address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
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
    * @param token 对应锁仓 token
    * @param target 转出目标
    */
    function tranEth(uint256 amount, address token, address target) public returns (uint256) {
        require(address(msg.sender) == address(_voteFactory.checkAddress("nest.v3.tokenAbonus")), "No authority");
        uint256 tranAmount = amount;
        if (tranAmount > ethMapping[token]) {
            tranAmount = ethMapping[token];
        }
        ethMapping[token] = ethMapping[token].sub(tranAmount);
        address payable addr = target.make_payable();
        addr.transfer(tranAmount);
        return tranAmount;
    }
    
    /**
    * @dev 转入平准
    * @param token 对应锁仓 token
    */
    function switchToEth(address token) public payable {
        ethMapping[token] = ethMapping[token].add(msg.value);
    }
    
    //  查看token对应的平准数量
    function checkEthMapping(address token) public view returns (uint256) {
        return ethMapping[token];
    }
    
    //  取出ETH
    function turnOutAllEth(uint256 amount, address target) public onlyOwner {
        address payable addr = target.make_payable();
        addr.transfer(amount);  
    }
    
    //  仅限管理员
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(address(msg.sender)), "No authority");
        _;
    }
}

// 投票工厂
interface Nest_3_VoteFactory {
    //  查询地址
	function checkAddress(string calldata name) external view returns (address contractAddress);
	//  查看是否管理员
	function checkOwners(address man) external view returns (bool);
}