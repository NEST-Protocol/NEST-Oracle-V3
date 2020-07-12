pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/AddressPayable.sol";

/**
 * @title 挖矿合约
 * @dev 矿池存储 + 出矿逻辑
 */
contract Nest_3_MiningContract {
    
    using address_make_payable for address;
    using SafeMath for uint256;
    
    uint256 _blockAttenuation = 2400000;                 //  区块衰减间隔
    uint256[10] _attenuationAmount;                      //  挖矿数量衰减
    uint256 _afterMiningAmount = 40 ether;               //  平稳期出矿量
    uint256 _firstBlockNum;                              //  起始挖矿区块 
    uint256 _latestMining;                               //  最新报价区块
    Nest_3_VoteFactory _voteFactory;                     //  投票合约
    ERC20 _nestContract;                                 //  NEST 合约
    address _offerFactoryAddress;                        //  报价工厂合约地址
    
    //  当前区块,当前块出矿量
    event OreDrawingLog(uint256 nowBlock, uint256 blockAmount);
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));                  
        _offerFactoryAddress = address(_voteFactory.checkAddress("nest.v3.offerMain"));
        _nestContract = ERC20(address(_voteFactory.checkAddress("nest")));
        // 初始化挖矿参数
        _firstBlockNum = 6236588;
        _latestMining = block.number;
        uint256 blockAmount = 400 ether;
        for (uint256 i = 0; i < 10; i ++) {
            _attenuationAmount[i] = blockAmount;
            blockAmount = blockAmount.mul(8).div(10);
        }
    }
    
    /**
    * @dev 重置投票合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));                  
        _offerFactoryAddress = address(_voteFactory.checkAddress("nest.v3.offerMain"));
        _nestContract = ERC20(address(_voteFactory.checkAddress("nest")));
    }
    
    /**
    * @dev 报价出矿
    * @return 当前区块出矿量
    */
    function oreDrawing() public returns (uint256) {
        require(address(msg.sender) == _offerFactoryAddress, "No authority");
        //  更新出矿量列表
        uint256 miningAmount = changeBlockAmountList();
        //  转 NEST
        if (_nestContract.balanceOf(address(this)) < miningAmount){
            miningAmount = _nestContract.balanceOf(address(this));
        }
        if (miningAmount > 0) {
            _nestContract.transfer(address(msg.sender), miningAmount);
            emit OreDrawingLog(block.number,miningAmount);
        }
        return miningAmount;
    }
    
    /**
    * @dev 更新出矿量列表
    */
    function changeBlockAmountList() private returns (uint256) {
        uint256 createBlock = _firstBlockNum;
        uint256 recentlyUsedBlock = _latestMining;
        uint256 attenuationPointNow = block.number.sub(createBlock).div(_blockAttenuation);
        uint256 miningAmount = 0;
        uint256 attenuation;
        if (attenuationPointNow > 9) {
            attenuation = _afterMiningAmount;
        } else {
            attenuation = _attenuationAmount[attenuationPointNow];
        }
        miningAmount = attenuation.mul(block.number.sub(recentlyUsedBlock));
        _latestMining = block.number;
        return miningAmount;
    }
    
    /**
    * @dev 转移所有 NEST
    * @param target 转移目标地址
    */
    function takeOutNest(address target) public onlyOwner {
        _nestContract.transfer(address(target),_nestContract.balanceOf(address(this)));
    }

    // 查看区块衰减间隔
    function checkBlockAttenuation() public view returns(uint256) {
        return _blockAttenuation;
    }
    
    // 查看最新报价区块
    function checkLatestMining() public view returns(uint256) {
        return _latestMining;
    }
    
    // 查看挖矿数量衰减
    function checkAttenuationAmount(uint256 num) public view returns(uint256) {
        return _attenuationAmount[num];
    }
    
    // 查看 NEST 余额
    function checkNestBalance() public view returns(uint256) {
        return _nestContract.balanceOf(address(this));
    }
    
    // 修改区块衰减间隔
    function changeBlockAttenuation(uint256 blockNum) public onlyOwner {
        require(blockNum > 0);
        _blockAttenuation = blockNum;
    }
    
    // 修改挖矿数量衰减
    function changeAttenuationAmount(uint256 firstAmount, uint256 top, uint256 bottom) public onlyOwner {
        uint256 blockAmount = firstAmount;
        for (uint256 i = 0; i < 10; i ++) {
            _attenuationAmount[i] = blockAmount;
            blockAmount = blockAmount.mul(top).div(bottom);
        }
    }
    
    // 仅限管理员操作
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender), "No authority");
        _;
    }
}

// 投票合约
interface Nest_3_VoteFactory {
    // 查询地址
	function checkAddress(string calldata name) external view returns (address contractAddress);
	// 查看是否管理员
	function checkOwners(address man) external view returns (bool);
}

// EC20
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