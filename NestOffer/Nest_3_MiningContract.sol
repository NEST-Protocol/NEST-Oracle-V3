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
    uint256 _attenuationTop = 90;                        //  衰减系数
    uint256 _attenuationBottom = 100;                    //  衰减系数
    uint256 _latestBlock;                                //  最新衰减区块
    uint256 _latestMining;                               //  最新报价区块
    mapping(uint256 => uint256) _blockAmountList;        //  衰减列表 区块号=>衰减系数
    Nest_3_VoteFactory _voteFactory;                     //  投票合约
    ERC20 _nestContract;                                 //  nest token合约
    address _abonusAddress;                              //  分红池地址
    address _offerFactoryAddress;                        //  报价工厂合约地址
    
    //  当前区块,当前块出矿量,本次手续费
    event OreDrawingLog(uint256 nowBlock, uint256 blockAmount, uint256 miningEth);
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));                  
        _abonusAddress = address(_voteFactory.checkAddress("nest.v3.abonus"));
        _offerFactoryAddress = address(_voteFactory.checkAddress("nest.v3.offerMain"));
        _nestContract = ERC20(address(_voteFactory.checkAddress("nest")));
        // _latestBlock = block.number.sub(388888);
        // _latestMining = block.number;
        // _blockAmountList[block.number.sub(2788888)] = 400 ether;
        // _blockAmountList[block.number.sub(388888)] = _blockAmountList[block.number.sub(2788888)].mul(_attenuationTop).div(_attenuationBottom);
        _latestBlock = block.number;
        _latestMining = block.number;
        _blockAmountList[block.number] = 400 ether;
    }
    
    /**
    * @dev 重置投票合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));                  
        _abonusAddress = address(_voteFactory.checkAddress("nest.v3.abonus"));
        _offerFactoryAddress = address(_voteFactory.checkAddress("nest.v3.offerMain"));
        _nestContract = ERC20(address(_voteFactory.checkAddress("nest")));
    }
    
    /**
    * @dev 报价出矿
    * @return 当前区块出矿量
    */
    function oreDrawing() public payable returns (uint256) {
        require(address(msg.sender) == _offerFactoryAddress, "No authority");
        //  更新出矿量列表
        uint256 miningAmount = changeBlockAmountList();
        //  转手续费
        repayEth(msg.value);
        //  转 nest
        if (_nestContract.balanceOf(address(this)) < miningAmount){
            miningAmount = 0;
        }
        if (miningAmount > 0) {
            _nestContract.transfer(address(msg.sender), miningAmount);
            emit OreDrawingLog(block.number,miningAmount,msg.value);
        }
        return miningAmount;
    }
    
    /**
    * @dev 更新出矿量列表
    */
    function changeBlockAmountList() private returns (uint256) {
        uint256 blockMining = 0;
        while(_latestBlock.add(_blockAttenuation) <= block.number) {
            uint256 newBlockAmount = _blockAmountList[_latestBlock].mul(_attenuationTop).div(_attenuationBottom);   
            _latestBlock = _latestBlock.add(_blockAttenuation);
            if (_latestMining < _latestBlock) {
                blockMining = blockMining.add((_blockAmountList[_latestBlock.sub(_blockAttenuation)]).mul(_latestBlock.sub(_latestMining)));
                _latestMining = _latestBlock;
            }
            _blockAmountList[_latestBlock] = newBlockAmount;
        }
        blockMining = blockMining.add(_blockAmountList[_latestBlock].mul(block.number.sub(_latestMining)));
        _latestMining = block.number;
        return blockMining;
    }
    
    /**
    * @dev 向分红池转手续费 
    */
    function repayEth(uint256 asset) private {
        address payable addr = _abonusAddress.make_payable();
        addr.transfer(asset);
    }
    
    /**
    * @dev 转移所有 NEST
    * @param target 转移目标地址
    */
    function takeOutNest(address target) public onlyOwner {
        _nestContract.transfer(address(target),_nestContract.balanceOf(address(this)));
    }

    //  查看区块衰减间隔
    function checkBlockAttenuation() public view returns(uint256) {
        return _blockAttenuation;
    }
    
    //  查看衰减系数
    function checkAttenuation() public view returns(uint256 top, uint256 bottom) {
        return (_attenuationTop, _attenuationBottom);
    }
    
    //  查看最新报价区块
    function checkLatestMining() public view returns(uint256) {
        return _latestMining;
    }
    
    //  查看衰减列表
    function checkBlockAmountList(uint256 blockNum) public view returns(uint256) {
        return _blockAmountList[blockNum];
    }
    
    //  查看当前出矿量
    function checkBlockAmountListLatest() public view returns(uint256) {
        return _blockAmountList[_latestBlock];
    }
    
    //  查看最新衰减区块
    function checkLatestBlock() public view returns(uint256) {
        return _latestBlock;
    }
    
    //  查看nest余额
    function checkNestBalance() public view returns(uint256) {
        return _nestContract.balanceOf(address(this));
    }
    
    //  修改区块衰减间隔
    function changeBlockAttenuation(uint256 blockNum) public onlyOwner {
        require(blockNum > 0);
        _blockAttenuation = blockNum;
    }
    
    //  修改衰减系数
    function changeAttenuation(uint256 top, uint256 bottom) public onlyOwner {
        require(top > 0, "Parameter needs to be greater than 0");
        require(bottom > 0, "Parameter needs to be greater than 0");
        _attenuationTop = top;
        _attenuationBottom = bottom;
    }
    
    //  仅限管理员操作
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







