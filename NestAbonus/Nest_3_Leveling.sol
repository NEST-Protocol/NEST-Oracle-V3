pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/AddressPayable.sol";

/**
 * @title Leveling contract
 * @dev ETH transfer in and transfer out
 */
contract Nest_3_Leveling {
    using address_make_payable for address;
    using SafeMath for uint256;
    Nest_3_VoteFactory _voteFactory;                                //  Vote contract
    mapping (address => uint256) ethMapping;                        //  Corresponded ETH leveling ledger of token
    
    /**
    * @dev Initialization method
    * @param voteFactory Voting contract address
    */
    constructor (address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
    }
    
    /**
    * @dev Modifying voting contract
    * @param voteFactory Voting contract address
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
    }
    
    /**
    * @dev Transfer out leveling
    * @param amount Transfer-out amount
    * @param token Corresponding lock-up token
    * @param target Transfer-out target
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
    * @dev Transfer in leveling 
    * @param token Corresponded locked token
    */
    function switchToEth(address token) public payable {
        ethMapping[token] = ethMapping[token].add(msg.value);
    }
    
    //  Check the leveled amount corresponding to the token
    function checkEthMapping(address token) public view returns (uint256) {
        return ethMapping[token];
    }
    
    //  Withdraw ETH
    function turnOutAllEth(uint256 amount, address target) public onlyOwner {
        address payable addr = target.make_payable();
        addr.transfer(amount);  
    }
    
    //  Administrator only
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(address(msg.sender)), "No authority");
        _;
    }
}

// Voting factory
interface Nest_3_VoteFactory {
    //  Check address
    function checkAddress(string calldata name) external view returns (address contractAddress);
    //  Check whether the administrator
    function checkOwners(address man) external view returns (bool);
}