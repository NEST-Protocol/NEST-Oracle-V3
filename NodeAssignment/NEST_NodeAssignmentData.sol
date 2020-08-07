pragma solidity 0.5.10;

import "./SafeMath.sol";

/**
 * @title Guardian node receives data
 */
contract NEST_NodeAssignmentData {
    using SafeMath for uint256;
    IBMapping mappingContract;              
    uint256 nodeAllAmount = 9546345842385995696603;                                 
    mapping(address => uint256) nodeLatestAmount;               
    
    /**
    * @dev Initialization method
    * @param map Mapping contract address
    */
    constructor (address map) public {
        mappingContract = IBMapping(map); 
    }
    
    /**
    * @dev Change mapping contract
    * @param map Mapping contract address
    */
    function changeMapping(address map) public onlyOwner{
        mappingContract = IBMapping(map); 
    }
    
    //  Add nest
    function addNest(uint256 amount) public onlyNodeAssignment {
        nodeAllAmount = nodeAllAmount.add(amount);
    }
    
    //  View cumulative total
    function checkNodeAllAmount() public view returns (uint256) {
        return nodeAllAmount;
    }
    
    //  Record last received quantity
    function addNodeLatestAmount(address add ,uint256 amount) public onlyNodeAssignment {
        nodeLatestAmount[add] = amount;
    }
    
    //  View last received quantity
    function checkNodeLatestAmount(address add) public view returns (uint256) {
        return nodeLatestAmount[address(add)];
    }
    
    modifier onlyOwner(){
        require(mappingContract.checkOwners(msg.sender) == true);
        _;
    }
    
    modifier onlyNodeAssignment(){
        require(address(msg.sender) == address(mappingContract.checkAddress("nodeAssignment")));
        _;
    }
}

contract IBMapping {
    function checkAddress(string memory name) public view returns (address contractAddress);
    function checkOwners(address man) public view returns (bool);
}