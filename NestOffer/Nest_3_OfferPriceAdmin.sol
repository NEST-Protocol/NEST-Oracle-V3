pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/SafeERC20.sol";

contract Nest_3_OfferPriceAdmin {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    
    Nest_3_VoteFactory _voteFactory;                                //  投票合约
    ERC20 _nestToken;                                               //  NestToken
    mapping(address => bool) _blackList;                            //  黑名单
    mapping(address => uint256) _addressEffect;                     //  调用价格地址生效时间
    address _destructionAddress;                                    //  销毁合约地址
    
    uint256 destructionAmount = 100000 ether;                       //  调用价格销毁 nest数量
    uint256 effectTime = 10 minutes;                                //  可以调用价格等待时间 
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor (address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));
        _destructionAddress = address(_voteFactory.checkAddress("nest.v3.destruction"));
        _nestToken = ERC20(address(_voteFactory.checkAddress("nest")));
    }
    
    /**
    * @dev 修改投票射合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));                                   
        _destructionAddress = address(_voteFactory.checkAddress("nest.v3.destruction"));
        _nestToken = ERC20(address(_voteFactory.checkAddress("nest")));
    }
    
    /**
    * @dev 激活使用价格合约
    */
    function activation() public {
        _nestToken.safeTransferFrom(address(msg.sender), _destructionAddress, destructionAmount);
        _addressEffect[msg.sender] = now.add(effectTime);
    }
    
    //  查看是否可以调用价格
    function checkUseNestPrice(address target) public view returns (bool) {
        if (_blackList[target] == false && _addressEffect[target] < now && _addressEffect[target] != 0) {
            return true;
        } else {
            return false;
        }
    }
    
    //  查看地址是否在黑名单
    function checkBlackList(address add) public view returns(bool) {
        return _blackList[add];
    }
    
    //  查看调用价格销毁 nest数量
    function checkDestructionAmount() public view returns(uint256) {
        return destructionAmount;
    }
    
    //  查看可以调用价格等待时间 
    function checkEffectTime() public view returns (uint256) {
        return effectTime;
    }
    
    //  修改黑名单
    function changeBlackList(address add, bool isBlack) public onlyOwner {
        _blackList[add] = isBlack;
    }
    
    //  修改调用价格销毁 nest数量
    function changeDestructionAmount(uint256 amount) public onlyOwner {
        destructionAmount = amount;
    }
    
    //  修改可以调用价格等待时间
    function changeEffectTime(uint256 num) public onlyOwner {
        effectTime = num.mul(1 days);
    }
    
    //  仅限投票修改
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender) == true, "No authority");
        _;
    }
    
}

//  投票合约
interface Nest_3_VoteFactory {
    //  查询地址
	function checkAddress(string calldata name) external view returns (address contractAddress);
	//  查看是否管理员
	function checkOwners(address man) external view returns (bool);
}