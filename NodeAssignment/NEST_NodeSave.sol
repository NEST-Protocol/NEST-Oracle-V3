pragma solidity 0.5.10;

/**
 * @title Guardian node nest storage
 */
contract NEST_NodeSave {
    IBMapping mappingContract;                      
    IBNEST nestContract;                             
    
    /**
    * @dev Initialization method
    * @param map Mapping contract address
    */
    constructor (address map) public {
        mappingContract = IBMapping(address(map));              
        nestContract = IBNEST(address(mappingContract.checkAddress("nest")));            
    }
    
    /**
    * @dev Change mapping contract
    * @param map Mapping contract address
    */
    function changeMapping(address map) public onlyOwner {
        mappingContract = IBMapping(address(map));              
        nestContract = IBNEST(address(mappingContract.checkAddress("nest")));            
    }
    
    /**
    * @dev Transfer out nest
    * @param amount Transfer out quantity
    * @param to Transfer out target
    * @return Actual transfer out quantity
    */
    function turnOut(uint256 amount, address to) public onlyMiningCalculation returns(uint256) {
        uint256 leftNum = nestContract.balanceOf(address(this));
        if (leftNum >= amount) {
            nestContract.transfer(to, amount);
            return amount;
        } else {
            return 0;
        }
    }
    
    modifier onlyOwner(){
        require(mappingContract.checkOwners(msg.sender) == true);
        _;
    }

    modifier onlyMiningCalculation(){
        require(address(mappingContract.checkAddress("nodeAssignment")) == msg.sender);
        _;
    }
    
}

contract IBMapping {
    function checkAddress(string memory name) public view returns (address contractAddress);
    function checkOwners(address man) public view returns (bool);
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