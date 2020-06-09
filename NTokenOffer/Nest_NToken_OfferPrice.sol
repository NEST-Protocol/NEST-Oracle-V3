pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";

/**
 * @title 价格合约
 * @dev 包含token价格的增加修改
 */
contract Nest_NToken_OfferPrice {
    using SafeMath for uint256;
    
    Nest_3_VoteFactory _voteFactory;                                //  投票合约
    Nest_NToken_TokenMapping _tokenMapping;                         //  ntoken映射
    Nest_3_OfferPriceAdmin _offerPriceAdmin;                        //  价格调用管理合约
    address _offerMain;                                             //  报价工厂合约
    address _abonusAddress;                                         //  分红池
    struct PriceInfo {                                              //  区块价格
        uint256 ethAmount;                                          //  eth数量
        uint256 erc20Amount;                                        //  erc20数量
        uint256 endBlock;                                           //  生效区块
        address offerOwner;                                         //  报价地址
    }
    struct Price {                                                  //  价格结构体
        uint256 ethAmount;                                          //  eth数量                 
        uint256 erc20Amount;                                        //  erc20数量
    }
    struct TokenInfo {                                              //  token报价信息
        mapping(uint256 => PriceInfo) priceInfoList;                //  区块价格列表,区块号 => 区块价格
        mapping(uint256 => OfferBlockInfo) offerBlockList;          //  报价区块列表,区块号 => 报价区块信息
        uint256 latestOffer;                                        //  最新报价区块
        Price price;                                                //  最新价格
    }
    struct OfferBlockInfo {
        uint256[] priceBlock;                                       //  区块内有价格的区块
        uint256 frontOfferBlock;                                    //  上一个报价区块
    }
    mapping(address => TokenInfo) _tokenInfo;                       //  token报价信息
    uint256 priceCost = 1 ether;                                    //  价格费用
    uint256 priceCostUser = 1;                                      //  价格费用用户比例
    uint256 priceCostAbonus = 9;                                    //  价格费用分红池比例
    
    //  实时价格 toekn, eth数量,erc20数量
    event NowTokenPrice(address a, uint256 b, uint256 c);
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor (address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));
        _offerMain = address(_voteFactory.checkAddress("nest.nToken.offerMain"));
        _abonusAddress = address(_voteFactory.checkAddress("nest.v3.nTokenAbonus"));
        _tokenMapping = Nest_NToken_TokenMapping(address(_voteFactory.checkAddress("nest.nToken.tokenMapping")));
        _offerPriceAdmin = Nest_3_OfferPriceAdmin(address(_voteFactory.checkAddress("nest.v3.offerPriceAdmin")));
    }
    
    /**
    * @dev 修改投票合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));                                                                   
        _offerMain = address(_voteFactory.checkAddress("nest.nToken.offerMain"));
        _abonusAddress = address(_voteFactory.checkAddress("nest.v3.nTokenAbonus"));
        _tokenMapping = Nest_NToken_TokenMapping(address(_voteFactory.checkAddress("nest.nToken.tokenMapping")));
        _offerPriceAdmin = Nest_3_OfferPriceAdmin(address(_voteFactory.checkAddress("nest.v3.offerPriceAdmin")));
    }
    
    /**
    * @dev 增加价格
    * @param ethAmount eth数量
    * @param tokenAmount erc20数量
    * @param endBlock 报价生效区块
    * @param tokenAddress erc20地址
    * @param offerOwner 报价地址
    */
    function addPrice(uint256 ethAmount, uint256 tokenAmount, uint256 endBlock, address tokenAddress, address offerOwner) public onlyFactory {
        //  增加生效区块价格信息
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        PriceInfo storage priceInfo = tokenInfo.priceInfoList[endBlock];
        priceInfo.ethAmount = priceInfo.ethAmount.add(ethAmount);
        priceInfo.erc20Amount = priceInfo.erc20Amount.add(tokenAmount);
        priceInfo.offerOwner = offerOwner;
        //  加入生效价格区块记录
        tokenInfo.offerBlockList[block.number].priceBlock.push(endBlock);
        if (block.number != tokenInfo.latestOffer) {
            //  不同区块报价
            tokenInfo.offerBlockList[block.number].frontOfferBlock = tokenInfo.latestOffer;
            tokenInfo.latestOffer = block.number;
        }
    }
    
    /**
    * @dev 更新并查看最新价格
    * @param tokenAddress token地址 
    * @return ethAmount eth数量
    * @return erc20Amount erc20数量
    */
    function updateAndCheckPriceNow(address tokenAddress) public returns(uint256 ethAmount, uint256 erc20Amount) {
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        uint256 checkBlcok = tokenInfo.latestOffer;
        
        while(true) {
            if (checkBlcok == 0) {
                break;
            }
            OfferBlockInfo storage offerBlockInfo = tokenInfo.offerBlockList[checkBlcok];
            if (checkBlcok < block.number) {
                for (uint i = 0; i < offerBlockInfo.priceBlock.length; i++) {
                    if (offerBlockInfo.priceBlock[i] < block.number && tokenInfo.priceInfoList[offerBlockInfo.priceBlock[i]].ethAmount != 0) {
                        PriceInfo storage priceInfo = tokenInfo.priceInfoList[offerBlockInfo.priceBlock[i]];
                        tokenInfo.price.ethAmount = priceInfo.ethAmount;
                        tokenInfo.price.erc20Amount = priceInfo.erc20Amount;
                        //  报价合约调用 及 用户调用 不收费
                        if (msg.sender != tx.origin && msg.sender != address(_offerMain)) {
                            require(_offerPriceAdmin.checkUseNestPrice(address(msg.sender)));
                            //  收费
                            IERC20 nToken = IERC20(address(_tokenMapping.checkTokenMapping(tokenAddress)));
                            require(nToken.transferFrom(address(msg.sender), address(this), priceCost));
                            require(nToken.transfer(address(_abonusAddress), priceCost.mul(priceCostAbonus).div(10)));
                            require(nToken.transfer(priceInfo.offerOwner, priceCost.mul(priceCostAbonus).div(10)));
                        }
                        emit NowTokenPrice(tokenAddress,priceInfo.ethAmount, priceInfo.erc20Amount);
                        return (priceInfo.ethAmount,priceInfo.erc20Amount);
                    }
                }
            }
            checkBlcok = offerBlockInfo.frontOfferBlock;
        }
    }
    
    /**
    * @dev 更新并查看生效价格列表
    * @param tokenAddress token地址
    * @param num 查询条数
    * @return uint256[] 价格列表
    */
    function updateAndCheckPriceList(address tokenAddress, uint256 num) public payable returns (uint256[] memory) {
        require(_offerPriceAdmin.checkUseNestPrice(address(msg.sender)));
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        //  收费
        uint256 thisPay = uint256(1 ether).mul(num);
        if (thisPay < 10 ether) {
            thisPay = 10 ether;
        } else if (thisPay > 50 ether) {
            thisPay = 50 ether;
        }
        IERC20 nToken = IERC20(address(_tokenMapping.checkTokenMapping(tokenAddress)));
        require(nToken.transferFrom(address(msg.sender), address(this), thisPay));
        
        uint256 length = num.mul(3);
        uint256 index = 0;
        uint256[] memory data = new uint256[](length);
        address latestOfferOwner = address(0x0);
        uint256 checkBlcok = tokenInfo.latestOffer;
        while(index < length){
            if (checkBlcok == 0) {
                break;
            }
            OfferBlockInfo storage offerBlockInfo = tokenInfo.offerBlockList[checkBlcok];
            if (checkBlcok < block.number) {
                for (uint i = 0; i < offerBlockInfo.priceBlock.length; i++) {
                    if (offerBlockInfo.priceBlock[i] < block.number && tokenInfo.priceInfoList[offerBlockInfo.priceBlock[i]].ethAmount != 0) {
                        uint256 effectBlock = offerBlockInfo.priceBlock[i];
                        //  增加返回数据
                        data[index++] = tokenInfo.priceInfoList[effectBlock].ethAmount;
                        data[index++] = tokenInfo.priceInfoList[effectBlock].erc20Amount;
                        data[index++] = effectBlock;
                        if (latestOfferOwner == address(0x0)) {
                            latestOfferOwner = tokenInfo.priceInfoList[effectBlock].offerOwner;
                        }
                    }
                }
            }
            checkBlcok = offerBlockInfo.frontOfferBlock;
        }
        
        //  分配
        require(nToken.transfer(address(_abonusAddress), thisPay.mul(priceCostAbonus).div(10)));
        require(nToken.transfer(latestOfferOwner, thisPay.mul(priceCostAbonus).div(10)));
        
        return data;
    }
    
    /**
    * @dev 吃单修改价格
    * @param ethAmount eth数量 
    * @param tokenAmount erc20数量
    * @param tokenAddress token地址 
    * @param endBlock 生效价格区块 
    */
    function changePrice(uint256 ethAmount, uint256 tokenAmount, address tokenAddress, uint256 endBlock) public onlyFactory {
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        PriceInfo storage priceInfo = tokenInfo.priceInfoList[endBlock];
        priceInfo.ethAmount = priceInfo.ethAmount.sub(ethAmount);
        priceInfo.erc20Amount = priceInfo.erc20Amount.sub(tokenAmount);
    }
    
    //  查看历史区块价格合约-用户
    function checkPriceForBlock(address tokenAddress, uint256 blockNum) public view returns (uint256 ethAmount, uint256 erc20Amount) {
        require(msg.sender == tx.origin, "It can't be a contract");
        TokenInfo storage tokenInfo = _tokenInfo[tokenAddress];
        return (tokenInfo.priceInfoList[blockNum].ethAmount, tokenInfo.priceInfoList[blockNum].erc20Amount);
    }    
    
    //  查看实时价格-用户
    function checkPriceNow(address tokenAddress) public view returns (uint256 ethAmount, uint256 erc20Amount) {
        require(msg.sender == tx.origin, "It can't be a contract");
        TokenInfo memory tokenInfo = _tokenInfo[tokenAddress];
        return (tokenInfo.price.ethAmount,tokenInfo.price.erc20Amount);
    }
    
    //  查看价格费用分配比例
    function checkPriceCostProportion() public view returns(uint256 user, uint256 abonus) {
        return (priceCostUser, priceCostAbonus);
    }
    
    //  查看获取价格费用 
    function checkPriceCost() public view returns(uint256) {
        return priceCost;
    }
    
    //  修改价格费用分配比例
    function changePriceCostProportion(uint256 user, uint256 abonus) public onlyOwner {
        require(user.add(abonus) == 10, "Wrong expense allocation proportion");
        priceCostUser = user;
        priceCostAbonus = abonus;
    }
    
    //  修改获取价格费用
    function changePriceCost(uint256 amount) public onlyOwner {
        priceCost = amount;
    }
    
    //  仅限工厂
    modifier onlyFactory(){
        require(msg.sender == address(_voteFactory.checkAddress("nest.nToken.offerMain")), "No authority");
        _;
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

//  ntoken映射合约
interface Nest_NToken_TokenMapping {
    function checkTokenMapping(address token) external view returns (address);
}

//  价格调用管理合约
interface Nest_3_OfferPriceAdmin {
    //  查看是否可以调用价格
    function checkUseNestPrice(address target) external view returns (bool);
}

/**
 * @title ntoken合约
 * @dev 包含标准erc20方法，挖矿增发方法，挖矿数据
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


