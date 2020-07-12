pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/AddressPayable.sol";
import "../Lib/SafeERC20.sol";

/**
 * @title 价格合约
 * @dev 价格查询与调用
 */
contract Nest_3_OfferPrice{
    using SafeMath for uint256;
    using address_make_payable for address;
    using SafeERC20 for ERC20;
    
    Nest_3_VoteFactory _voteFactory;                                //  投票合约
    ERC20 _nestToken;                                               //  NestToken
    Nest_NToken_TokenMapping _tokenMapping;                         //  NToken映射
    Nest_3_OfferMain _offerMain;                                    //  报价工厂合约
    Nest_3_Abonus _abonus;                                          //  分红池
    address _nTokeOfferMain;                                        //  NToken报价工厂合约
    address _destructionAddress;                                    //  销毁合约地址
    address _nTokenAuction;                                         //  NToken拍卖合约地址
    struct PriceInfo {                                              //  区块价格
        uint256 ethAmount;                                          //  ETH 数量
        uint256 erc20Amount;                                        //  ERC20 数量
        uint256 frontBlock;                                         //  上一个生效区块
        address offerOwner;                                         //  报价地址
    }
    struct TokenInfo {                                              //  token报价信息
        mapping(uint256 => PriceInfo) priceInfoList;                //  区块价格列表,区块号 => 区块价格
        uint256 latestOffer;                                        //  最新生效区块
        uint256 priceCostLeast;                                     //  价格 ETH 最少费用
        uint256 priceCostMost;                                      //  价格 ETH 最多费用 
        uint256 priceCostSingle;                                    //  价格 ETH 单条数据费用
        uint256 priceCostUser;                                      //  价格 ETH 费用用户比例
    }
    uint256 destructionAmount = 10000 ether;                        //  调用价格销毁 NEST 数量
    uint256 effectTime = 1 days;                                    //  可以调用价格等待时间
    mapping(address => TokenInfo) _tokenInfo;                       //  token报价信息
    mapping(address => bool) _blocklist;                            //  禁止名单
    mapping(address => uint256) _addressEffect;                     //  调用价格地址生效时间
    mapping(address => bool) _offerMainMapping;                     //  报价合约映射

    //  实时价格 token, eth数量, erc20数量
    event NowTokenPrice(address a, uint256 b, uint256 c);
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor (address voteFactory) public {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;
        _offerMain = Nest_3_OfferMain(address(voteFactoryMap.checkAddress("nest.v3.offerMain")));
        _nTokeOfferMain = address(voteFactoryMap.checkAddress("nest.nToken.offerMain"));
        _abonus = Nest_3_Abonus(address(voteFactoryMap.checkAddress("nest.v3.abonus")));
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
        _nestToken = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
        _nTokenAuction = address(voteFactoryMap.checkAddress("nest.nToken.tokenAuction"));
        _offerMainMapping[address(_offerMain)] = true;
        _offerMainMapping[address(_nTokeOfferMain)] = true;
    }
    
    /**
    * @dev 修改投票射合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;                                   
        _offerMain = Nest_3_OfferMain(address(voteFactoryMap.checkAddress("nest.v3.offerMain")));
        _nTokeOfferMain = address(voteFactoryMap.checkAddress("nest.nToken.offerMain"));
        _abonus = Nest_3_Abonus(address(voteFactoryMap.checkAddress("nest.v3.abonus")));
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
        _nestToken = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
        _nTokenAuction = address(voteFactoryMap.checkAddress("nest.nToken.tokenAuction"));
        _offerMainMapping[address(_offerMain)] = true;
        _offerMainMapping[address(_nTokeOfferMain)] = true;
    }
    
    /**
    * @dev 初始化 token 价格收费参数
    * @param tokenAddress token地址
    */
    function addPriceCost(address tokenAddress) public {
        require(msg.sender == _nTokenAuction);
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        tokenInfo.priceCostLeast = 0.001 ether;
        tokenInfo.priceCostMost = 0.01 ether;
        tokenInfo.priceCostSingle = 0.0001 ether;
        tokenInfo.priceCostUser = 2;
    }
    
    /**
    * @dev 增加价格
    * @param ethAmount eth数量
    * @param tokenAmount erc20数量
    * @param endBlock 生效价格区块
    * @param tokenAddress erc20地址
    * @param offerOwner 报价地址
    */
    function addPrice(uint256 ethAmount, uint256 tokenAmount, uint256 endBlock, address tokenAddress, address offerOwner) public onlyOfferMain{
        // 增加生效区块价格信息
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        PriceInfo storage priceInfo = tokenInfo.priceInfoList[endBlock];
        priceInfo.ethAmount = priceInfo.ethAmount.add(ethAmount);
        priceInfo.erc20Amount = priceInfo.erc20Amount.add(tokenAmount);
        priceInfo.offerOwner = offerOwner;
        if (endBlock != tokenInfo.latestOffer) {
            // 不同区块报价
            priceInfo.frontBlock = tokenInfo.latestOffer;
            tokenInfo.latestOffer = endBlock;
        }
    }
    
    /**
    * @dev 吃单修改价格
    * @param ethAmount eth数量 
    * @param tokenAmount erc20数量
    * @param tokenAddress token地址 
    * @param endBlock 生效价格区块 
    */
    function changePrice(uint256 ethAmount, uint256 tokenAmount, address tokenAddress, uint256 endBlock) public onlyOfferMain {
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        PriceInfo storage priceInfo = tokenInfo.priceInfoList[endBlock];
        priceInfo.ethAmount = priceInfo.ethAmount.sub(ethAmount);
        priceInfo.erc20Amount = priceInfo.erc20Amount.sub(tokenAmount);
    }
    
    /**
    * @dev 更新并查看最新价格
    * @param tokenAddress token地址 
    * @return ethAmount eth数量
    * @return erc20Amount erc20数量
    * @return blockNum 价格区块
    */
    function updateAndCheckPriceNow(address tokenAddress) public payable returns(uint256 ethAmount, uint256 erc20Amount, uint256 blockNum) {
        require(checkUseNestPrice(address(msg.sender)));
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        uint256 checkBlock = tokenInfo.latestOffer;
        while(checkBlock > 0 && (checkBlock >= block.number || tokenInfo.priceInfoList[checkBlock].ethAmount == 0)) {
            checkBlock = tokenInfo.priceInfoList[checkBlock].frontBlock;
        }
        require(checkBlock != 0);
        PriceInfo memory priceInfo = tokenInfo.priceInfoList[checkBlock];
        address nToken = _tokenMapping.checkTokenMapping(tokenAddress);
        if (nToken == address(0x0)) {
            _abonus.switchToEth.value(tokenInfo.priceCostLeast.sub(tokenInfo.priceCostLeast.mul(tokenInfo.priceCostUser).div(10)))(address(_nestToken));
        } else {
            _abonus.switchToEth.value(tokenInfo.priceCostLeast.sub(tokenInfo.priceCostLeast.mul(tokenInfo.priceCostUser).div(10)))(address(nToken));
        }
        repayEth(priceInfo.offerOwner, tokenInfo.priceCostLeast.mul(tokenInfo.priceCostUser).div(10));
        repayEth(address(msg.sender), msg.value.sub(tokenInfo.priceCostLeast));
        emit NowTokenPrice(tokenAddress,priceInfo.ethAmount, priceInfo.erc20Amount);
        return (priceInfo.ethAmount,priceInfo.erc20Amount, checkBlock);
    }
    
    /**
    * @dev 更新并查看最新价格-内部使用
    * @param tokenAddress token地址 
    * @return ethAmount eth数量
    * @return erc20Amount erc20数量
    */
    function updateAndCheckPricePrivate(address tokenAddress) public view onlyOfferMain returns(uint256 ethAmount, uint256 erc20Amount) {
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        uint256 checkBlock = tokenInfo.latestOffer;
        while(checkBlock > 0 && (checkBlock >= block.number || tokenInfo.priceInfoList[checkBlock].ethAmount == 0)) {
            checkBlock = tokenInfo.priceInfoList[checkBlock].frontBlock;
        }
        if (checkBlock == 0) {
            return (0,0);
        }
        PriceInfo memory priceInfo = tokenInfo.priceInfoList[checkBlock];
        return (priceInfo.ethAmount,priceInfo.erc20Amount);
    }
    
    /**
    * @dev 更新并查看生效价格列表
    * @param tokenAddress token地址
    * @param num 查询条数
    * @return uint256[] 价格列表
    */
    function updateAndCheckPriceList(address tokenAddress, uint256 num) public payable returns (uint256[] memory) {
        require(checkUseNestPrice(address(msg.sender)));
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        // 收费
        uint256 thisPay = tokenInfo.priceCostSingle.mul(num);
        if (thisPay < tokenInfo.priceCostLeast) {
            thisPay=tokenInfo.priceCostLeast;
        } else if (thisPay > tokenInfo.priceCostMost) {
            thisPay = tokenInfo.priceCostMost;
        }
        
        // 提取数据
        uint256 length = num.mul(3);
        uint256 index = 0;
        uint256[] memory data = new uint256[](length);
        address latestOfferOwner = address(0x0);
        uint256 checkBlock = tokenInfo.latestOffer;
        while(index < length && checkBlock > 0){
            if (checkBlock < block.number && tokenInfo.priceInfoList[checkBlock].ethAmount != 0) {
                // 增加返回数据
                data[index++] = tokenInfo.priceInfoList[checkBlock].ethAmount;
                data[index++] = tokenInfo.priceInfoList[checkBlock].erc20Amount;
                data[index++] = checkBlock;
                if (latestOfferOwner == address(0x0)) {
                    latestOfferOwner = tokenInfo.priceInfoList[checkBlock].offerOwner;
                }
            }
            checkBlock = tokenInfo.priceInfoList[checkBlock].frontBlock;
        }
        require(latestOfferOwner != address(0x0));
        require(length == data.length);
        // 分配
        address nToken = _tokenMapping.checkTokenMapping(tokenAddress);
        if (nToken == address(0x0)) {
            _abonus.switchToEth.value(thisPay.sub(thisPay.mul(tokenInfo.priceCostUser).div(10)))(address(_nestToken));
        } else {
            _abonus.switchToEth.value(thisPay.sub(thisPay.mul(tokenInfo.priceCostUser).div(10)))(address(nToken));
        }
        repayEth(latestOfferOwner, thisPay.mul(tokenInfo.priceCostUser).div(10));
        repayEth(address(msg.sender), msg.value.sub(thisPay));
        return data;
    }
    
    // 激活使用价格合约
    function activation() public {
        _nestToken.safeTransferFrom(address(msg.sender), _destructionAddress, destructionAmount);
        _addressEffect[address(msg.sender)] = now.add(effectTime);
    }
    
    // 转ETH
    function repayEth(address accountAddress, uint256 asset) private {
        address payable addr = accountAddress.make_payable();
        addr.transfer(asset);
    }
    
    // 查看历史区块价格合约-用户
    function checkPriceForBlock(address tokenAddress, uint256 blockNum) public view returns (uint256 ethAmount, uint256 erc20Amount) {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        return (tokenInfo.priceInfoList[blockNum].ethAmount, tokenInfo.priceInfoList[blockNum].erc20Amount);
    }    
    
    // 查看实时价格-用户
    function checkPriceNow(address tokenAddress) public view returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum) {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        uint256 checkBlock = tokenInfo.latestOffer;
        while(checkBlock > 0 && (checkBlock >= block.number || tokenInfo.priceInfoList[checkBlock].ethAmount == 0)) {
            checkBlock = tokenInfo.priceInfoList[checkBlock].frontBlock;
        }
        if (checkBlock == 0) {
            return (0,0,0);
        }
        PriceInfo storage priceInfo = tokenInfo.priceInfoList[checkBlock];
        return (priceInfo.ethAmount,priceInfo.erc20Amount, checkBlock);
    }
    
    // 查看价格费用分配比例
    function checkPriceCostProportion(address tokenAddress) public view returns(uint256 user, uint256 abonus) {
        return (_tokenInfo[tokenAddress].priceCostUser, uint256(10).sub(_tokenInfo[tokenAddress].priceCostUser));
    }
    
    // 查看获取价格eth最少费用 
    function checkPriceCostLeast(address tokenAddress) public view returns(uint256) {
        return _tokenInfo[tokenAddress].priceCostLeast;
    }
    
    // 查看获取价格eth最多费用 
    function checkPriceCostMost(address tokenAddress) public view returns(uint256) {
        return _tokenInfo[tokenAddress].priceCostMost;
    }
    
    // 查看价格eth单条数据费用
    function checkPriceCostSingle(address tokenAddress) public view returns(uint256) {
        return _tokenInfo[tokenAddress].priceCostSingle;
    }
    
    // 查看是否可以调用价格
    function checkUseNestPrice(address target) public view returns (bool) {
        if (!_blocklist[target] && _addressEffect[target] < now && _addressEffect[target] != 0) {
            return true;
        } else {
            return false;
        }
    }
    
    // 查看地址是否在黑名单
    function checkBlocklist(address add) public view returns(bool) {
        return _blocklist[add];
    }
    
    // 查看调用价格销毁 nest数量
    function checkDestructionAmount() public view returns(uint256) {
        return destructionAmount;
    }
    
    // 查看可以调用价格等待时间 
    function checkEffectTime() public view returns (uint256) {
        return effectTime;
    }
    
    // 修改价格费用分配比例
    function changePriceCostProportion(uint256 user, address tokenAddress) public onlyOwner {
        _tokenInfo[tokenAddress].priceCostUser = user;
    }
    
    // 修改获取价格eth最低费用
    function changePriceCostLeast(uint256 amount, address tokenAddress) public onlyOwner {
        _tokenInfo[tokenAddress].priceCostLeast = amount;
    }
    
    // 修改获取价格eth最高费用
    function changePriceCostMost(uint256 amount, address tokenAddress) public onlyOwner {
        _tokenInfo[tokenAddress].priceCostMost = amount;
    }
    
    // 修改价格eth单条数据费用
    function checkPriceCostSingle(uint256 amount, address tokenAddress) public onlyOwner {
        _tokenInfo[tokenAddress].priceCostSingle = amount;
    }
    
    // 修改黑名单
    function changeBlocklist(address add, bool isBlock) public onlyOwner {
        _blocklist[add] = isBlock;
    }
    
    // 修改调用价格销毁 nest数量
    function changeDestructionAmount(uint256 amount) public onlyOwner {
        destructionAmount = amount;
    }
    
    // 修改可以调用价格等待时间
    function changeEffectTime(uint256 num) public onlyOwner {
        effectTime = num;
    }

    // 仅限报价合约
    modifier onlyOfferMain(){
        require(_offerMainMapping[address(msg.sender)], "No authority");
        _;
    }
    
    // 仅限投票修改
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

// NToken映射合约
interface Nest_NToken_TokenMapping {
    function checkTokenMapping(address token) external view returns (address);
}

// NEST报价工厂
interface Nest_3_OfferMain {
    function checkTokenAllow(address token) external view returns(bool);
}

// 分红池合约
interface Nest_3_Abonus {
    function switchToEth(address token) external payable;
}
