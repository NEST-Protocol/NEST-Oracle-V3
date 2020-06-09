pragma solidity 0.6.0;

/**
 * @title nToken分红池
 * @dev nToken领取与查询
 */
contract Nest_3_NTokenAbonus {
    
    Nest_3_VoteFactory _voteFactory;                                        //  投票合约
    
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
    * @param target 转账目标地址
    * @param nToken nToken地址
    */
    function getNToken(uint256 num, address target, address nToken) public onlyContract {
        require(num <= getNTokenNum(nToken), "Insufficient storage balance");
        require(ERC20(address(nToken)).transfer(target, num), "Transfer failure");
    }
    
    /**
    * @dev 获取分红池余额
    * @param nToken nToken地址
    * @return uint256 分红池余额
    */
    function getNTokenNum(address nToken) public view returns (uint256) {
        return ERC20(address(nToken)).balanceOf(address(this));
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