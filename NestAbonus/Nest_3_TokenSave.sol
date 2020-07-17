pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";

/**
 * @title NEST及NToken锁仓合约
 * @dev NEST及NToken存入与取出
 */
contract Nest_3_TokenSave {
    using SafeMath for uint256;
    
    Nest_3_VoteFactory _voteFactory;                                 //  投票合约
    mapping(address => mapping(address => uint256))  _baseMapping;   //  总账本 Token=>用户=>数量 
    
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
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
    }
    
    /**
    * @dev 取出锁仓Token
    * @param num 取出数量
    * @param token 锁仓 token 地址
    * @param target 转账目标
    */
    function takeOut(uint256 num, address token, address target) public onlyContract {
        require(num <= _baseMapping[token][address(target)], "Insufficient storage balance");
        _baseMapping[token][address(target)] = _baseMapping[token][address(target)].sub(num);
        ERC20(token).transfer(address(target), num);
    }
    
    /**
    * @dev 存入锁仓Token
    * @param num 存入数量
    * @param token 锁仓 token 地址
    * @param target 存入目标
    */
    function depositIn(uint256 num, address token, address target) public onlyContract {
        require(ERC20(token).transferFrom(address(target),address(this),num), "Authorization transfer failed");  
        _baseMapping[token][address(target)] = _baseMapping[token][address(target)].add(num);
    }
    
    /**
    * @dev 查看额度
    * @param sender 查询地址
    * @param token 锁仓 token 地址
    * @return uint256 查询地址对应锁仓额度
    */
    function checkAmount(address sender, address token) public view returns(uint256) {
        return _baseMapping[token][address(sender)];
    }
    
    // 仅限管理员
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(address(msg.sender)), "No authority");
        _;
    }
    
    // 仅限分红逻辑合约
    modifier onlyContract(){
        require(_voteFactory.checkAddress("nest.v3.tokenAbonus") == address(msg.sender), "No authority");
        _;
    }
}

// EC20合约
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
    // 查询地址
	function checkAddress(string calldata name) external view returns (address contractAddress);
	// 查看是否管理员
	function checkOwners(address man) external view returns (bool);
}
