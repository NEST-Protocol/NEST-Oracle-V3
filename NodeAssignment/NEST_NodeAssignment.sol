pragma solidity 0.5.10;

import "./SafeMath.sol";

//  节点分配合约
contract NEST_NodeAssignment {
    
    using SafeMath for uint256;
    IBMapping mappingContract;  //映射合约
    IBNEST nestContract;                                   //  nest token
    SuperMan supermanContract;                              //  节点 token
    NEST_NodeSave nodeSave;
    NEST_NodeAssignmentData nodeAssignmentData;
    // uint256 nodeAllAmount = 0;                                 //  节点数量
    // mapping(address => uint256) nodeLatestAmount;              //  上次领取数量

    constructor (address map) public {
        mappingContract = IBMapping(map); 
        nestContract = IBNEST(address(mappingContract.checkAddress("nest")));
        supermanContract = SuperMan(address(mappingContract.checkAddress("nestNode")));
        nodeSave = NEST_NodeSave(address(mappingContract.checkAddress("nestNodeSave")));
        nodeAssignmentData = NEST_NodeAssignmentData(address(mappingContract.checkAddress("nodeAssignmentData")));
    }
    
    //  修改映射合约
    function changeMapping(address map) public onlyOwner{
        mappingContract = IBMapping(map); 
        nestContract = IBNEST(address(mappingContract.checkAddress("nest")));
        supermanContract = SuperMan(address(mappingContract.checkAddress("nestNode")));
        nodeSave = NEST_NodeSave(address(mappingContract.checkAddress("nestNodeSave")));
        nodeAssignmentData = NEST_NodeAssignmentData(address(mappingContract.checkAddress("nodeAssignmentData")));
    }
    
    //  NEST请求
    function bookKeeping(uint256 amount) public {
        require(amount > 0);
        require(nestContract.balanceOf(address(msg.sender)) >= amount);
        require(nestContract.allowance(address(msg.sender), address(this)) >= amount);
        require(nestContract.transferFrom(address(msg.sender), address(nodeSave), amount));
        // require(nestContract.transferFrom(address(msg.sender), address(0xA38afc5c1E33f85B06D4b8C2b4312c1DC1054882), amount));
        // nodeAllAmount = nodeAllAmount.add(amount);
        nodeAssignmentData.addNest(amount);
    }
    
    //  超级节点领取
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
    
    //  转让结算
    function nodeCount(address fromAdd, address toAdd) public {
        require(address(supermanContract) == address(msg.sender));
        require(supermanContract.balanceOf(address(fromAdd)) > 0);
        uint256 allAmount = nodeAssignmentData.checkNodeAllAmount();
        
        uint256 amountFrom = allAmount.sub(nodeAssignmentData.checkNodeLatestAmount(address(fromAdd)));
        uint256 getAmountFrom = amountFrom.mul(supermanContract.balanceOf(address(fromAdd))).div(1500);
        require(nestContract.balanceOf(address(nodeSave)) >= getAmountFrom);
        nodeSave.turnOut(getAmountFrom,address(fromAdd));
        nodeAssignmentData.addNodeLatestAmount(address(fromAdd),allAmount);
        
        uint256 amountTo = allAmount.sub(nodeAssignmentData.checkNodeLatestAmount(address(toAdd)));
        uint256 getAmountTo = amountTo.mul(supermanContract.balanceOf(address(toAdd))).div(1500);
        require(nestContract.balanceOf(address(nodeSave)) >= getAmountTo);
        nodeSave.turnOut(getAmountTo,address(toAdd));
        nodeAssignmentData.addNodeLatestAmount(address(toAdd),allAmount);
    }
    
    //  超级节点可领取金额
    function checkNodeNum() public view returns (uint256) {
         uint256 allAmount = nodeAssignmentData.checkNodeAllAmount();
         uint256 amount = allAmount.sub(nodeAssignmentData.checkNodeLatestAmount(address(msg.sender)));
         uint256 getAmount = amount.mul(supermanContract.balanceOf(address(msg.sender))).div(1500);
         return getAmount; 
    }
    
    //  仅限管理员
    modifier onlyOwner(){
        require(mappingContract.checkOwners(msg.sender) == true);
        _;
    }
}

//  映射合约
contract IBMapping {
    //  查询地址
	function checkAddress(string memory name) public view returns (address contractAddress);
	//  查看是否管理员
	function checkOwners(address man) public view returns (bool);
}

contract NEST_NodeSave {
    function turnOut(uint256 amount, address to) public returns(uint256);
}

contract NEST_NodeAssignmentData {
    function addNest(uint256 amount) public;
    function addNodeLatestAmount(address add ,uint256 amount) public;
    function checkNodeAllAmount() public view returns (uint256);
    function checkNodeLatestAmount(address add) public view returns (uint256);
}

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

contract IBNEST {
    function totalSupply() public view returns (uint supply);
    function balanceOf( address who ) public view returns (uint value);
    function allowance( address owner, address spender ) public view returns (uint _allowance);

    function transfer( address to, uint256 value) external;
    function transferFrom( address from, address to, uint value) public returns (bool ok);
    function approve( address spender, uint value ) public returns (bool ok);

    event Transfer( address indexed from, address indexed to, uint value);
    event Approval( address indexed owner, address indexed spender, uint value);
    
    function balancesStart() public view returns(uint256);
    function balancesGetBool(uint256 num) public view returns(bool);
    function balancesGetNext(uint256 num) public view returns(uint256);
    function balancesGetValue(uint256 num) public view returns(address, uint256);
}