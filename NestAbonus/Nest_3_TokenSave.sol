pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";

/**
 * @title NEST and NToken lock-up contract
 * @dev NEST and NToken deposit and withdrawal
 */
contract Nest_3_TokenSave {
    using SafeMath for uint256;
    
    Nest_3_VoteFactory _voteFactory;                                 //  Voting contract
    mapping(address => mapping(address => uint256))  _baseMapping;   //  Ledger token=>user=>amount
    
    /**
    * @dev initialization method
    * @param voteFactory Voting contract address
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
    }
    
    /**
    * @dev Reset voting contract
    * @param voteFactory Voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
    }
    
    /**
    * @dev Withdrawing
    * @param num Withdrawing amount
    * @param token Lock-up token address
    * @param target Transfer target
    */
    function takeOut(uint256 num, address token, address target) public onlyContract {
        require(num <= _baseMapping[token][address(target)], "Insufficient storage balance");
        _baseMapping[token][address(target)] = _baseMapping[token][address(target)].sub(num);
        ERC20(token).transfer(address(target), num);
    }
    
    /**
    * @dev Depositing
    * @param num Depositing amount
    * @param token Lock-up token address
    * @param target Depositing target
    */
    function depositIn(uint256 num, address token, address target) public onlyContract {
        require(ERC20(token).transferFrom(address(target),address(this),num), "Authorization transfer failed");  
        _baseMapping[token][address(target)] = _baseMapping[token][address(target)].add(num);
    }
    
    /**
    * @dev Check the amount
    * @param sender Check address
    * @param token Lock-up token address
    * @return uint256 Check address corresponding lock-up limit 
    */
    function checkAmount(address sender, address token) public view returns(uint256) {
        return _baseMapping[token][address(sender)];
    }
    
    // Administrators only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(address(msg.sender)), "No authority");
        _;
    }
    
    // Only for bonus logic contract
    modifier onlyContract(){
        require(_voteFactory.checkAddress("nest.v3.tokenAbonus") == address(msg.sender), "No authority");
        _;
    }
}

// ERC20 contract
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

// Voting factory
interface Nest_3_VoteFactory {
    // Check address
    function checkAddress(string calldata name) external view returns (address contractAddress);
    // Check whether the administrator
    function checkOwners(address man) external view returns (bool);
}
