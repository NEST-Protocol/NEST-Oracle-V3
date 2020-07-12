pragma solidity 0.5.10;

import "./SafeMath.sol";

/**
 * @title NestNode 领取数据
 */
contract NEST_NodeAssignmentData {
    using SafeMath for uint256;
    
    IBMapping mappingContract;                                  //  映射合约
    uint256 nodeAllAmount = 0;                                  //  节点分配 NEST 数量
    mapping(address => uint256) nodeLatestAmount;               //  上次领取数量
    
    /**
    * @dev 初始化方法
    * @param map 投票合约地址
    */
    constructor (address map) public {
        mappingContract = IBMapping(map); 
    }
    
    /**
    * @dev 重置投票合约
    * @param map 投票合约地址
    */
    function changeMapping(address map) public onlyOwner{
        mappingContract = IBMapping(map); 
    }
    
    // 增加nest
    function addNest(uint256 amount) public onlyNodeAssignment {
        nodeAllAmount = nodeAllAmount.add(amount);
    }
    
    // 查看累计总数
    function checkNodeAllAmount() public view returns (uint256) {
        return nodeAllAmount;
    }
    
    // 记录上次数量
    function addNodeLatestAmount(address add ,uint256 amount) public onlyNodeAssignment {
        nodeLatestAmount[add] = amount;
    }
    
    // 查看上次数量
    function checkNodeLatestAmount(address add) public view returns (uint256) {
        return nodeLatestAmount[address(add)];
    }
    
    // 仅限管理员
    modifier onlyOwner(){
        require(mappingContract.checkOwners(msg.sender) == true);
        _;
    }
    
    // 仅限分配合约
    modifier onlyNodeAssignment(){
        require(address(msg.sender) == address(mappingContract.checkAddress("nodeAssignment")));
        _;
    }
}

// 映射合约
contract IBMapping {
    // 查询地址
	function checkAddress(string memory name) public view returns (address contractAddress);
	// 查看是否管理员
	function checkOwners(address man) public view returns (bool);
}