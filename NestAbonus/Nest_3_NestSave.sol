pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";

/**
 * @title nest锁仓合约
 * @dev nest存入与取出
 */
contract Nest_3_NestSave {
    using SafeMath for uint256;
    
    ERC20 _nestContract;                                        //  NEST合约
    Nest_3_VoteFactory _voteFactory;                            //  投票合约
    mapping (address => uint256) _baseMapping;                  //  总账本
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
        _nestContract = ERC20(address(_voteFactory.checkAddress("nest")));
    }
    
    /**
    * @dev 重置投票合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
        _nestContract = ERC20(address(_voteFactory.checkAddress("nest")));
    }
    
    /**
    * @dev 取出nest
    * @param num 取出数量
    * @param target 转账目标
    */
    function takeOut(uint256 num, address target) public onlyContract {
        require(num <= _baseMapping[address(target)], "Insufficient storage balance");
        _baseMapping[address(target)] = _baseMapping[address(target)].sub(num);
        _nestContract.transfer(address(target), num);
    }
    
    /**
    * @dev 存入nest
    * @param num 存入数量
    * @param target 存入目标
    */
    function depositIn(uint256 num, address target) public onlyContract {
        require(_nestContract.transferFrom(address(target),address(this),num), "Authorization transfer failed");  
        _baseMapping[address(target)] = _baseMapping[address(target)].add(num);
    }
    
    /**
    * @dev 查看额度
    * @param sender 查询地址
    * @return uint256 查询地址对应锁仓额度
    */
    function checkAmount(address sender) public view returns(uint256) {
        return _baseMapping[address(sender)];
    }
    
    //  仅限管理员
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender) == true, "No authority");
        _;
    }
    
    //  仅限分红逻辑合约
    modifier onlyContract(){
        require(_voteFactory.checkAddress("nest.v3.nestAbonus") == msg.sender, "No authority");
        _;
    }
}

interface ERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
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