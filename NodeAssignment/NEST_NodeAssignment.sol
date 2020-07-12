pragma solidity 0.5.10;

import "./SafeMath.sol";

/**
 * @title 节点分配合约
 */
contract NEST_NodeAssignment {
    
    using SafeMath for uint256;
    IBMapping mappingContract;                              //  映射合约
    IBNEST nestContract;                                    //  NEST 合约
    SuperMan supermanContract;                              //  NestNode 合约
    NEST_NodeSave nodeSave;                                 //  NestNode NEST锁仓
    NEST_NodeAssignmentData nodeAssignmentData;             //  NestNode 领取数据

    /**
    * @dev 初始化方法
    * @param map 投票合约地址
    */
    constructor (address map) public {
        mappingContract = IBMapping(map); 
        nestContract = IBNEST(address(mappingContract.checkAddress("nest")));
        supermanContract = SuperMan(address(mappingContract.checkAddress("nestNode")));
        nodeSave = NEST_NodeSave(address(mappingContract.checkAddress("nestNodeSave")));
        nodeAssignmentData = NEST_NodeAssignmentData(address(mappingContract.checkAddress("nodeAssignmentData")));
    }
    
    /**
    * @dev 重置投票合约
    * @param map 投票合约地址
    */
    function changeMapping(address map) public onlyOwner{
        mappingContract = IBMapping(map); 
        nestContract = IBNEST(address(mappingContract.checkAddress("nest")));
        supermanContract = SuperMan(address(mappingContract.checkAddress("nestNode")));
        nodeSave = NEST_NodeSave(address(mappingContract.checkAddress("nestNodeSave")));
        nodeAssignmentData = NEST_NodeAssignmentData(address(mappingContract.checkAddress("nodeAssignmentData")));
    }
    
    /**
    * @dev 存入 NEST
    * @param amount 存入 NEST 数量
    */
    function bookKeeping(uint256 amount) public {
        require(amount > 0);
        require(nestContract.transferFrom(address(msg.sender), address(nodeSave), amount));
        nodeAssignmentData.addNest(amount);
    }
    
    // NestNode 领取结算
    function nodeGet() public {
        require(address(msg.sender) == address(tx.origin));
        require(supermanContract.balanceOf(address(msg.sender)) > 0);
        uint256 allAmount = nodeAssignmentData.checkNodeAllAmount();
        uint256 amount = allAmount.sub(nodeAssignmentData.checkNodeLatestAmount(address(msg.sender)));
        uint256 getAmount = amount.mul(supermanContract.balanceOf(address(msg.sender))).div(1500);
        require(nestContract.balanceOf(address(nodeSave)) >= getAmount);
        nodeSave.turnOut(getAmount,address(msg.sender));
        nodeAssignmentData.addNodeLatestAmount(address(msg.sender),allAmount);
    }
    
    // NestNode 转账结算
    function nodeCount(address fromAdd, address toAdd) public {
        require(address(supermanContract) == address(msg.sender));
        require(supermanContract.balanceOf(address(fromAdd)) > 0);
        uint256 allAmount = nodeAssignmentData.checkNodeAllAmount();
        uint256 amountFrom = allAmount.sub(nodeAssignmentData.checkNodeLatestAmount(address(fromAdd)));
        uint256 getAmountFrom = amountFrom.mul(supermanContract.balanceOf(address(fromAdd))).div(1500);
        if (nestContract.balanceOf(address(nodeSave)) >= getAmountFrom) {
            nodeSave.turnOut(getAmountFrom,address(fromAdd));
            nodeAssignmentData.addNodeLatestAmount(address(fromAdd),allAmount);
        }
        uint256 amountTo = allAmount.sub(nodeAssignmentData.checkNodeLatestAmount(address(toAdd)));
        uint256 getAmountTo = amountTo.mul(supermanContract.balanceOf(address(toAdd))).div(1500);
        if (nestContract.balanceOf(address(nodeSave)) >= getAmountTo) {
            nodeSave.turnOut(getAmountTo,address(toAdd));
            nodeAssignmentData.addNodeLatestAmount(address(toAdd),allAmount);
        }
    }
    
    // 超级节点可领取金额
    function checkNodeNum() public view returns (uint256) {
         uint256 allAmount = nodeAssignmentData.checkNodeAllAmount();
         uint256 amount = allAmount.sub(nodeAssignmentData.checkNodeLatestAmount(address(msg.sender)));
         uint256 getAmount = amount.mul(supermanContract.balanceOf(address(msg.sender))).div(1500);
         return getAmount; 
    }
    
    // 仅限管理员
    modifier onlyOwner(){
        require(mappingContract.checkOwners(msg.sender));
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

// NestNode NEST锁仓
contract NEST_NodeSave {
    function turnOut(uint256 amount, address to) public returns(uint256);
}

// NestNode 领取数据
contract NEST_NodeAssignmentData {
    function addNest(uint256 amount) public;
    function addNodeLatestAmount(address add ,uint256 amount) public;
    function checkNodeAllAmount() public view returns (uint256);
    function checkNodeLatestAmount(address add) public view returns (uint256);
}

// NestNode 合约
interface SuperMan {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// NEST 合约
contract IBNEST {
    function totalSupply() public view returns (uint supply);
    function balanceOf( address who ) public view returns (uint value);
    function allowance( address owner, address spender ) public view returns (uint _allowance);
    function transfer( address to, uint256 value) external;
    function transferFrom( address from, address to, uint value) public returns (bool ok);
    function approve( address spender, uint value ) public returns (bool ok);
    event Transfer( address indexed from, address indexed to, uint value);
    event Approval( address indexed owner, address indexed spender, uint value);
}