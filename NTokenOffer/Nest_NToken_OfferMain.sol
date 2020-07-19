pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/AddressPayable.sol";
import "../Lib/SafeERC20.sol";

/**
 * @title 报价合约
 * @dev 包含报价逻辑和挖矿逻辑
 */
contract Nest_NToken_OfferMain {
    
    using SafeMath for uint256;
    using address_make_payable for address;
    using SafeERC20 for ERC20;
    
    // 报价单数据结构
    struct Nest_NToken_OfferPriceData {
        // 唯一标识通过报价单在数组中的位置确定，通过固定的算法（toIndex(), toAddress()）来互相转化
        address owner;                              // 报价单拥有者
        bool deviate;                               // 是否偏离
        address tokenAddress;                       // 目标报价token的ERC20合约地址
        
        uint256 ethAmount;                          // 报价单中的eth资产账本
        uint256 tokenAmount;                        // 报价单中的token资产账本
        
        uint256 dealEthAmount;                      // 剩余可成交eth数量
        uint256 dealTokenAmount;                    // 剩余可成交token数量
        
        uint256 blockNum;                           // 报价单所在的区块编号
        uint256 serviceCharge;                      // 挖矿手续费
        // 通过判断ethAmount、tokenAmount、serviceCharge都为0来确定是否已经领取资产
    }
    
    Nest_NToken_OfferPriceData [] _prices;                              //  用于保存报价单的数组
    Nest_3_VoteFactory _voteFactory;                                    //  投票合约
    Nest_3_OfferPrice _offerPrice;                                      //  价格合约
    Nest_NToken_TokenMapping _tokenMapping;                             //  nToken映射合约
    ERC20 _nestToken;                                                   //  nestToken
    Nest_3_Abonus _abonus;                                              //  分红池
    uint256 _miningETH = 10;                                            //  报价挖矿手续费挖矿比例
    uint256 _tranEth = 1;                                               //  吃单手续费比例
    uint256 _tranAddition = 2;                                          //  交易加成
    uint256 _leastEth = 10 ether;                                       //  最少报价eth
    uint256 _offerSpan = 10 ether;                                      //  报价eth跨度
    uint256 _deviate = 10;                                              //  价格偏差 10%
    uint256 _deviationFromScale = 10;                                   //  偏离资产规模
    uint256 _ownerMining = 5;                                           //  创建者比例
    uint256 _afterMiningAmount = 0.4 ether;                             //  平稳期出矿量
    uint32 _blockLimit = 25;                                            //  区块间隔上限
    
    uint256 _blockAttenuation = 2400000;                                //  区块衰减间隔
    mapping(uint256 => mapping(address => uint256)) _blockOfferAmount;  //  区块报价次数 区块号=>token地址=>报价手续费
    mapping(uint256 => mapping(address => uint256)) _blockMining;       //  报价区块出矿量 区块号=>token地址=>出矿量
    uint256[10] _attenuationAmount;                                     //  挖矿数量衰减
    
    //  log个人资产合约
    event OfferTokenContractAddress(address contractAddress);           
    //  log,报价合约, token地址,eth数量,erc20数量,延时区块,挖矿手续费
    event OfferContractAddress(address contractAddress, address tokenAddress, uint256 ethAmount, uint256 erc20Amount, uint256 continued,uint256 mining);         
    //  log交易，交易发起人，交易token地址，交易token数量，买进token地址，买进token数量，被交易报价合约地址，被交易用户地址
    event OfferTran(address tranSender, address tranToken, uint256 tranAmount,address otherToken, uint256 otherAmount, address tradedContract, address tradedOwner);        
    //  当前区块,当前块出矿量,token地址
    event OreDrawingLog(uint256 nowBlock, uint256 blockAmount, address tokenAddress);
    //  报价区块，token地址，token报价次数
    event MiningLog(uint256 blockNum, address tokenAddress, uint256 offerTimes);
    
    /**
     * 初始化方法
     * @param voteFactory 投票合约地址
     **/
    constructor (address voteFactory) public {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;                                                                 
        _offerPrice = Nest_3_OfferPrice(address(voteFactoryMap.checkAddress("nest.v3.offerPrice")));            
        _nestToken = ERC20(voteFactoryMap.checkAddress("nest"));                                                          
        _abonus = Nest_3_Abonus(voteFactoryMap.checkAddress("nest.v3.abonus"));
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
        
        uint256 blockAmount = 4 ether;
        for (uint256 i = 0; i < 10; i ++) {
            _attenuationAmount[i] = blockAmount;
            blockAmount = blockAmount.mul(8).div(10);
        }
    }
    
    /**
     * 重置投票合约方法
     * @param voteFactory 投票合约地址
     **/
    function changeMapping(address voteFactory) public onlyOwner {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;                                                          
        _offerPrice = Nest_3_OfferPrice(address(voteFactoryMap.checkAddress("nest.v3.offerPrice")));      
        _nestToken = ERC20(voteFactoryMap.checkAddress("nest"));                                                   
        _abonus = Nest_3_Abonus(voteFactoryMap.checkAddress("nest.v3.abonus"));
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
    }
    
    /**
     * 报价方法
     * @param ethAmount ETH数量
     * @param erc20Amount erc20Token数量
     * @param erc20Address erc20Token地址
     **/
    function offer(uint256 ethAmount, uint256 erc20Amount, address erc20Address) public payable {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        address nTokenAddress = _tokenMapping.checkTokenMapping(erc20Address);
        require(nTokenAddress != address(0x0));
        //  判断价格是否偏离
        uint256 ethMining;
        bool isDeviate = comparativePrice(ethAmount,erc20Amount,erc20Address);
        if (isDeviate) {
            require(ethAmount >= _leastEth.mul(_deviationFromScale), "EthAmount needs to be no less than 10 times of the minimum scale");
            ethMining = _leastEth.mul(_miningETH).div(1000);
        } else {
            ethMining = ethAmount.mul(_miningETH).div(1000);
        }
        require(msg.value >= ethAmount.add(ethMining), "msg.value needs to be equal to the quoted eth quantity plus Mining handling fee");
        uint256 subValue = msg.value.sub(ethAmount.add(ethMining));
        if (subValue > 0) {
            repayEth(address(msg.sender), subValue);
        }
        //  创建报价单
        createOffer(ethAmount, erc20Amount, erc20Address,isDeviate, ethMining);
        // 转入报价资产erc20-交易资产到当前合约
        ERC20(erc20Address).safeTransferFrom(address(msg.sender), address(this), erc20Amount);
        _abonus.switchToEthForNTokenOffer.value(ethMining)(nTokenAddress);
        // 挖矿
        if (_blockOfferAmount[block.number][erc20Address] == 0) {
            uint256 miningAmount = oreDrawing(nTokenAddress);
            Nest_NToken nToken = Nest_NToken(nTokenAddress);
            nToken.transfer(nToken.checkBidder(), miningAmount.mul(_ownerMining).div(100));
            _blockMining[block.number][erc20Address] = miningAmount.sub(miningAmount.mul(_ownerMining).div(100));
        }
        _blockOfferAmount[block.number][erc20Address] = _blockOfferAmount[block.number][erc20Address].add(ethMining);
    }
    
    /**
     * 生成报价单方法
     * @param ethAmount ETH数量
     * @param erc20Amount erc20Token数量
     * @param erc20Address erc20Token地址
     **/
    function createOffer(uint256 ethAmount, uint256 erc20Amount, address erc20Address, bool isDeviate, uint256 mining) private {
        // 检查报价条件
        require(ethAmount >= _leastEth, "Eth scale is smaller than the minimum scale");                                                 
        require(ethAmount % _offerSpan == 0, "Non compliant asset span");
        require(erc20Amount % (ethAmount.div(_offerSpan)) == 0, "Asset quantity is not divided");
        require(erc20Amount > 0);
        // 创建报价合约
        emit OfferContractAddress(toAddress(_prices.length), address(erc20Address), ethAmount, erc20Amount,_blockLimit,mining);
        _prices.push(Nest_NToken_OfferPriceData(
            msg.sender,
            isDeviate,
            erc20Address,
            
            ethAmount,
            erc20Amount,
            
            ethAmount, 
            erc20Amount, 
            
            block.number,
            mining
        ));
        // 记录价格
        _offerPrice.addPrice(ethAmount, erc20Amount, block.number.add(_blockLimit), erc20Address, address(msg.sender));
    }
    
    // 将报价单地址转化为在报价单数组中的索引
    function toIndex(address contractAddress) public pure returns(uint256) {
        return uint256(contractAddress);
    }
    
    // 将报价单在报价单数组中的索引转化为报价单地址
    function toAddress(uint256 index) public pure returns(address) {
        return address(index);
    }
    
    /**
     * 取出报价单资金
     * @param contractAddress 报价单地址
     **/
    function turnOut(address contractAddress) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        uint256 index = toIndex(contractAddress);
        Nest_NToken_OfferPriceData storage offerPriceData = _prices[index];
        require(checkContractState(offerPriceData.blockNum) == 1, "Offer status error");
        // 取出ETH
        if (offerPriceData.ethAmount > 0) {
            uint256 payEth = offerPriceData.ethAmount;
            offerPriceData.ethAmount = 0;
            repayEth(offerPriceData.owner, payEth);
        }
        // 取出ERC20
        if (offerPriceData.tokenAmount > 0) {
            uint256 payErc = offerPriceData.tokenAmount;
            offerPriceData.tokenAmount = 0;
            ERC20(address(offerPriceData.tokenAddress)).transfer(offerPriceData.owner, payErc);
            
        }
        // 挖矿结算
        if (offerPriceData.serviceCharge > 0) {
            mining(offerPriceData.blockNum, offerPriceData.tokenAddress, offerPriceData.serviceCharge);
            offerPriceData.serviceCharge = 0;
        }
    }
    
    /**
    * @dev 吃单-支出ETH 买入ERC20
    * @param ethAmount 本次报价 eth数量
    * @param tokenAmount 本次报价 erc20数量
    * @param contractAddress 吃单目标地址
    * @param tranEthAmount 吃单交易 eth数量
    * @param tranTokenAmount 吃单交易 erc20数量
    * @param tranTokenAddress 吃单交易 erc20地址
    */
    function sendEthBuyErc(uint256 ethAmount, uint256 tokenAmount, address contractAddress, uint256 tranEthAmount, uint256 tranTokenAmount, address tranTokenAddress) public payable {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        uint256 serviceCharge = tranEthAmount.mul(_tranEth).div(1000);
        require(msg.value == ethAmount.add(tranEthAmount).add(serviceCharge), "msg.value needs to be equal to the quotation eth quantity plus transaction eth plus");
        require(tranEthAmount % _offerSpan == 0, "Transaction size does not meet asset span");
        
        // 获取报价单数据结构
        uint256 index = toIndex(contractAddress);
        Nest_NToken_OfferPriceData memory offerPriceData = _prices[index]; 
        //  检测价格, 当前报价对比上一个有效价格
        bool thisDeviate = comparativePrice(ethAmount,tokenAmount,tranTokenAddress);
        bool isDeviate;
        if (offerPriceData.deviate == true) {
            isDeviate = true;
        } else {
            isDeviate = thisDeviate;
        }
        // 限制吃单报价每次只能是吃单规模的两倍，防止大额攻击
        if (offerPriceData.deviate) {
            //  被吃单偏离 x2
            require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
        } else {
            if (isDeviate) {
                //  被吃单正常，本次偏离 x10
                require(ethAmount >= tranEthAmount.mul(_deviationFromScale), "EthAmount needs to be no less than 10 times of transaction scale");
            } else {
                //  被吃单正常，本次正常 x2
                require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
            }
        }
        
        // 检查吃单条件是否满足
        require(checkContractState(offerPriceData.blockNum) == 0, "Offer status error");
        require(offerPriceData.dealEthAmount >= tranEthAmount, "Insufficient trading eth");
        require(offerPriceData.dealTokenAmount >= tranTokenAmount, "Insufficient trading token");
        require(offerPriceData.tokenAddress == tranTokenAddress, "Wrong token address");
        require(tranTokenAmount == offerPriceData.dealTokenAmount * tranEthAmount / offerPriceData.dealEthAmount, "Wrong token amount");
        
        // 更新报价单信息
        offerPriceData.ethAmount = offerPriceData.ethAmount.add(tranEthAmount);
        offerPriceData.tokenAmount = offerPriceData.tokenAmount.sub(tranTokenAmount);
        offerPriceData.dealEthAmount = offerPriceData.dealEthAmount.sub(tranEthAmount);
        offerPriceData.dealTokenAmount = offerPriceData.dealTokenAmount.sub(tranTokenAmount);
        _prices[index] = offerPriceData;
        // 创建一个新报价
        createOffer(ethAmount, tokenAmount, tranTokenAddress, isDeviate, 0);
        // 转入报价资产erc20-交易资产到当前合约
        if (tokenAmount > tranTokenAmount) {
            ERC20(tranTokenAddress).safeTransferFrom(address(msg.sender), address(this), tokenAmount.sub(tranTokenAmount));
        } else {
            ERC20(tranTokenAddress).safeTransfer(address(msg.sender), tranTokenAmount.sub(tokenAmount));
        }

        // 修改价格
        _offerPrice.changePrice(tranEthAmount, tranTokenAmount, tranTokenAddress, offerPriceData.blockNum.add(_blockLimit));
        emit OfferTran(address(msg.sender), address(0x0), tranEthAmount, address(tranTokenAddress), tranTokenAmount, contractAddress, offerPriceData.owner);
        
        // 转手续费
        if (serviceCharge > 0) {
            address nTokenAddress = _tokenMapping.checkTokenMapping(tranTokenAddress);
            _abonus.switchToEth.value(serviceCharge)(nTokenAddress);
        }
    }
    
    /**
    * @dev 吃单-支出erc20 买入ETH
    * @param ethAmount 本次报价 eth数量
    * @param tokenAmount 本次报价 erc20数量
    * @param contractAddress 吃单目标地址
    * @param tranEthAmount 吃单交易 eth数量
    * @param tranTokenAmount 吃单交易 erc20数量
    * @param tranTokenAddress 吃单交易 erc20地址
    */
    function sendErcBuyEth(uint256 ethAmount, uint256 tokenAmount, address contractAddress, uint256 tranEthAmount, uint256 tranTokenAmount, address tranTokenAddress) public payable {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        uint256 serviceCharge = tranEthAmount.mul(_tranEth).div(1000);
        require(msg.value == ethAmount.sub(tranEthAmount).add(serviceCharge), "msg.value needs to be equal to the quoted eth quantity plus transaction handling fee");
        require(tranEthAmount % _offerSpan == 0, "Transaction size does not meet asset span");
        // 获取报价单数据结构
        uint256 index = toIndex(contractAddress);
        Nest_NToken_OfferPriceData memory offerPriceData = _prices[index]; 
        //  检测价格, 当前报价对比上一个有效价格
        bool thisDeviate = comparativePrice(ethAmount,tokenAmount,tranTokenAddress);
        bool isDeviate;
        if (offerPriceData.deviate == true) {
            isDeviate = true;
        } else {
            isDeviate = thisDeviate;
        }
        // 限制吃单报价每次只能是吃单规模的两倍，防止大额攻击
        if (offerPriceData.deviate) {
            //  被吃单偏离 x2
            require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
        } else {
            if (isDeviate) {
                //  被吃单正常，本次偏离 x10
                require(ethAmount >= tranEthAmount.mul(_deviationFromScale), "EthAmount needs to be no less than 10 times of transaction scale");
            } else {
                //  被吃单正常，本次正常 x2
                require(ethAmount >= tranEthAmount.mul(_tranAddition), "EthAmount needs to be no less than 2 times of transaction scale");
            }
        }
        // 检查吃单条件是否满足
        require(checkContractState(offerPriceData.blockNum) == 0, "Offer status error");
        require(offerPriceData.dealEthAmount >= tranEthAmount, "Insufficient trading eth");
        require(offerPriceData.dealTokenAmount >= tranTokenAmount, "Insufficient trading token");
        require(offerPriceData.tokenAddress == tranTokenAddress, "Wrong token address");
        require(tranTokenAmount == offerPriceData.dealTokenAmount * tranEthAmount / offerPriceData.dealEthAmount, "Wrong token amount");
        // 更新报价单信息
        offerPriceData.ethAmount = offerPriceData.ethAmount.sub(tranEthAmount);
        offerPriceData.tokenAmount = offerPriceData.tokenAmount.add(tranTokenAmount);
        offerPriceData.dealEthAmount = offerPriceData.dealEthAmount.sub(tranEthAmount);
        offerPriceData.dealTokenAmount = offerPriceData.dealTokenAmount.sub(tranTokenAmount);
        _prices[index] = offerPriceData;
        // 创建一个新报价
        createOffer(ethAmount, tokenAmount, tranTokenAddress, isDeviate, 0);
        // 转入买ETH的资产+报价资产到当前合约
        ERC20(tranTokenAddress).safeTransferFrom(address(msg.sender), address(this), tranTokenAmount.add(tokenAmount));
        // 修改价格
        _offerPrice.changePrice(tranEthAmount, tranTokenAmount, tranTokenAddress, offerPriceData.blockNum.add(_blockLimit));
        emit OfferTran(address(msg.sender), address(tranTokenAddress), tranTokenAmount, address(0x0), tranEthAmount, contractAddress, offerPriceData.owner);
        // 转手续费
        if (serviceCharge > 0) {
            address nTokenAddress = _tokenMapping.checkTokenMapping(tranTokenAddress);
            _abonus.switchToEth.value(serviceCharge)(nTokenAddress);
        }
    }
    
    /**
     * 报价出矿
     * @param ntoken NToken地址
     **/
    function oreDrawing(address ntoken) private returns(uint256) {
        Nest_NToken miningToken = Nest_NToken(ntoken);
        (uint256 createBlock, uint256 recentlyUsedBlock) = miningToken.checkBlockInfo();
        uint256 attenuationPointNow = block.number.sub(createBlock).div(_blockAttenuation);
        uint256 miningAmount = 0;
        uint256 attenuation;
        if (attenuationPointNow > 9) {
            attenuation = _afterMiningAmount;
        } else {
            attenuation = _attenuationAmount[attenuationPointNow];
        }
        miningAmount = attenuation.mul(block.number.sub(recentlyUsedBlock));
        miningToken.increaseTotal(miningAmount);
        emit OreDrawingLog(block.number, miningAmount, ntoken);
        return miningAmount;
    }
    
    /**
     * 取回挖矿
     * @param token token地址
     **/
    function mining(uint256 blockNum, address token, uint256 serviceCharge) private returns(uint256) {
        //  区块出矿量 * 手续费 / 区块报价手续费
        uint256 miningAmount = _blockMining[blockNum][token].mul(serviceCharge).div(_blockOfferAmount[blockNum][token]);        
        //  转账 nToken
        Nest_NToken nToken = Nest_NToken(address(_tokenMapping.checkTokenMapping(token)));
        require(nToken.transfer(address(tx.origin), miningAmount), "Transfer failure");
        
        emit MiningLog(blockNum, token,_blockOfferAmount[blockNum][token]);
        return miningAmount;
    }
    
    // 比较吃单价格
    function comparativePrice(uint256 myEthValue, uint256 myTokenValue, address token) private view returns(bool) {
        (uint256 frontEthValue, uint256 frontTokenValue) = _offerPrice.updateAndCheckPricePrivate(token);
        if (frontEthValue == 0 || frontTokenValue == 0) {
            return false;
        }
        uint256 maxTokenAmount = myEthValue.mul(frontTokenValue).mul(uint256(100).add(_deviate)).div(frontEthValue.mul(100));
        if (myTokenValue <= maxTokenAmount) {
            uint256 minTokenAmount = myEthValue.mul(frontTokenValue).mul(uint256(100).sub(_deviate)).div(frontEthValue.mul(100));
            if (myTokenValue >= minTokenAmount) {
                return false;
            }
        }
        return true;
    }
    
    // 查看合约状态
    function checkContractState(uint256 createBlock) public view returns (uint256) {
        if (block.number.sub(createBlock) > _blockLimit) {
            return 1;
        }
        return 0;
    }
    
    // 转账 ETH
    function repayEth(address accountAddress, uint256 asset) private {
        address payable addr = accountAddress.make_payable();
        addr.transfer(asset);
    }
    
    // 查看区块间隔上限
    function checkBlockLimit() public view returns(uint256) {
        return _blockLimit;
    }
    
    // 查看交易手续费
    function checkTranEth() public view returns (uint256) {
        return _tranEth;
    }
    
    // 查看交易加成
    function checkTranAddition() public view returns(uint256) {
        return _tranAddition;
    }
    
    // 查看最少报价eth
    function checkleastEth() public view returns(uint256) {
        return _leastEth;
    }
    
    // 查看报价eth跨度
    function checkOfferSpan() public view returns(uint256) {
        return _offerSpan;
    }

    // 查看区块报价次数
    function checkBlockOfferAmount(uint256 blockNum, address token) public view returns (uint256) {
        return _blockOfferAmount[blockNum][token];
    }
    
    // 查看报价区块出矿量
    function checkBlockMining(uint256 blockNum, address token) public view returns (uint256) {
        return _blockMining[blockNum][token];
    }
    
    // 查看报价挖矿数量
    function checkOfferMining(uint256 blockNum, address token, uint256 serviceCharge) public view returns (uint256) {
        if (serviceCharge == 0) {
            return 0;
        } else {
            return _blockMining[blockNum][token].mul(serviceCharge).div(_blockOfferAmount[blockNum][token]);
        }
    }
    
    // 查看拥有者分配比例
    function checkOwnerMining() public view returns(uint256) {
        return _ownerMining;
    }
    
    // 查看挖矿数量衰减
    function checkAttenuationAmount(uint256 num) public view returns(uint256) {
        return _attenuationAmount[num];
    }
    
    // 修改吃单手续费比例
    function changeTranEth(uint256 num) public onlyOwner {
        _tranEth = num;
    }
    
    // 修改区块间隔上限
    function changeBlockLimit(uint32 num) public onlyOwner {
        _blockLimit = num;
    }
    
    // 修改交易加成
    function changeTranAddition(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _tranAddition = num;
    }
    
    // 修改最少报价eth
    function changeLeastEth(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _leastEth = num;
    }
    
    // 修改报价eth跨度
    function changeOfferSpan(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _offerSpan = num;
    }
    
    // 修改价格偏差
    function changekDeviate(uint256 num) public onlyOwner {
        _deviate = num;
    }
    
    // 修改偏离资产规模
    function changeDeviationFromScale(uint256 num) public onlyOwner {
        _deviationFromScale = num;
    }
    
    // 修改拥有者分配比例
    function changeOwnerMining(uint256 num) public onlyOwner {
        _ownerMining = num;
    }
    
    // 修改挖矿数量衰减
    function changeAttenuationAmount(uint256 firstAmount, uint256 top, uint256 bottom) public onlyOwner {
        uint256 blockAmount = firstAmount;
        for (uint256 i = 0; i < 10; i ++) {
            _attenuationAmount[i] = blockAmount;
            blockAmount = blockAmount.mul(top).div(bottom);
        }
    }
    
    // 仅限投票修改
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender), "No authority");
        _;
    }
    
    /**
     * 获取报价数组中累计存储的报价单数量
     * @return 报价数组中累计存储的报价单数量
     **/
    function getPriceCount() view public returns (uint256) {
        return _prices.length;
    }
    
    /**
     * 根据索引获取报价单信息
     * @param priceIndex 报价单索引
     * @return 报价单信息字符串
     **/
    function getPrice(uint256 priceIndex) view public returns (string memory) {
        // 用于生成结果字符串的缓冲数组
        bytes memory buf = new bytes(500000);
        uint256 index = 0;
        index = writeOfferPriceData(priceIndex, _prices[priceIndex], buf, index);
        // 生成结果字符串并返回
        bytes memory str = new bytes(index);
        while(index-- > 0) {
            str[index] = buf[index];
        }
        return string(str);
    }
    
    /**
     * 查找目标账户的合约单（倒序）
     * @param start 从给定的合约地址对应的索引向前查询（不包含start对应的记录）
     * @param count 最多返回的记录条数
     * @param maxFindCount 最多查找maxFindCount记录
     * @param owner 目标账户地址
     * @return 合约单记录，字段之间用,分割：
     * uuid,owner,tokenAddress,ethAmount,tokenAmount,dealEthAmount,dealTokenAmount,blockNum,serviceCharge
     **/
    function find(address start, uint256 count, uint256 maxFindCount, address owner) view public returns (string memory) {
        // 用于生成结果字符串的缓冲数组
        bytes memory buf = new bytes(500000);
        uint256 index = 0;
        // 计算查找区间i和end
        uint256 i = _prices.length;
        uint256 end = 0;
        if (start != address(0)) {
            i = toIndex(start);
        }
        if (i > maxFindCount) {
            end = i - maxFindCount;
        }
        // 循环查找，将符合条件的记录写入缓冲区
        while (count > 0 && i-- > end) {
            Nest_NToken_OfferPriceData memory price = _prices[i];
            if (price.owner == owner) {
                --count;
                index = writeOfferPriceData(i, price, buf, index);
            }
        }
        // 生成结果字符串并返回
        bytes memory str = new bytes(index);
        while(index-- > 0) {
            str[index] = buf[index];
        }
        return string(str);
    }
    
    /**
     * 分页获取报价单列表
     * @param offset 跳过开始的offset条记录
     * @param count 最多返回的记录条数
     * @param order 排序规则。0表示倒序，非0表示正序
     * @return 合约单记录，字段之间用,分割：
     * uuid,owner,tokenAddress,ethAmount,tokenAmount,dealEthAmount,dealTokenAmount,blockNum,serviceCharge
     **/
    function list(uint256 offset, uint256 count, uint256 order) view public returns (string memory) {
        
        // 用于生成结果字符串的缓冲数组
        bytes memory buf = new bytes(500000);
        uint256 index = 0;
        
        // 找区间i和end
        uint256 i = 0;
        uint256 end = 0;
        
        if (order == 0) {
            // 倒序，默认
            // 计算查找区间i和end
            if (offset < _prices.length) {
                i = _prices.length - offset;
            } 
            if (count < i) {
                end = i - count;
            }
            
            // 将目标区间内的记录写入缓冲区
            while (i-- > end) {
                index = writeOfferPriceData(i, _prices[i], buf, index);
            }
        } else {
            // 升序
            // 计算查找区间i和end
            if (offset < _prices.length) {
                i = offset;
            } else {
                i = _prices.length;
            }
            end = i + count;
            if(end > _prices.length) {
                end = _prices.length;
            }
            
            // 将目标区间内的记录写入缓冲区
            while (i < end) {
                index = writeOfferPriceData(i, _prices[i], buf, index);
                ++i;
            }
        }
        
        // 生成结果字符串并返回
        bytes memory str = new bytes(index);
        while(index-- > 0) {
            str[index] = buf[index];
        }
        return string(str);
    }   
     
    // 将报价单数据结构写入缓冲区，并返回缓冲区索引
    function writeOfferPriceData(uint256 priceIndex, Nest_NToken_OfferPriceData memory price, bytes memory buf, uint256 index) pure private returns (uint256) {
        
        index = writeAddress(toAddress(priceIndex), buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeAddress(price.owner, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeAddress(price.tokenAddress, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.ethAmount, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.tokenAmount, buf, index);
        buf[index++] = byte(uint8(44));
       
        index = writeUInt(price.dealEthAmount, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.dealTokenAmount, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.blockNum, buf, index);
        buf[index++] = byte(uint8(44));
        
        index = writeUInt(price.serviceCharge, buf, index);
        buf[index++] = byte(uint8(44));
        
        return index;
    }
     
    // 将整数转成10进制字符串写入缓冲区，并返回缓冲区索引
    function writeUInt(uint256 iv, bytes memory buf, uint256 index) pure public returns (uint256) {
        uint256 i = index;
        do {
            buf[index++] = byte(uint8(iv % 10 +48));
            iv /= 10;
        } while (iv > 0);
        
        for (uint256 j = index; j > i; ++i) {
            byte t = buf[i];
            buf[i] = buf[--j];
            buf[j] = t;
        }
        
        return index;
    }

    // 将地址转成16进制字符串写入缓冲区，并返回缓冲区索引
    function writeAddress(address addr, bytes memory buf, uint256 index) pure private returns (uint256) {
        
        uint256 iv = uint256(addr);
        uint256 i = index + 40;
        do {
            uint256 w = iv % 16;
            if(w < 10) {
                buf[index++] = byte(uint8(w +48));
            } else {
                buf[index++] = byte(uint8(w +87));
            }
            
            iv /= 16;
        } while (index < i);
        
        i -= 40;
        for (uint256 j = index; j > i; ++i) {
            byte t = buf[i];
            buf[i] = buf[--j];
            buf[j] = t;
        }
        
        return index;
    }
}

// 价格合约
interface Nest_3_OfferPrice {
    // 增加价格数据
    function addPrice(uint256 ethAmount, uint256 tokenAmount, uint256 endBlock, address tokenAddress, address offerOwner) external;
    // 修改价格
    function changePrice(uint256 ethAmount, uint256 tokenAmount, address tokenAddress, uint256 endBlock) external;
    function updateAndCheckPricePrivate(address tokenAddress) external view returns(uint256 ethAmount, uint256 erc20Amount);
}

// 投票合约
interface Nest_3_VoteFactory {
    // 查询地址
	function checkAddress(string calldata name) external view returns (address contractAddress);
	// 查看是否管理员
	function checkOwners(address man) external view returns (bool);
}

// NToken合约
interface Nest_NToken {
    // 增发
    function increaseTotal(uint256 value) external;
    // 查询挖矿信息
    function checkBlockInfo() external view returns(uint256 createBlock, uint256 recentlyUsedBlock);
    // 查询创建者
    function checkBidder() external view returns(address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// NToken映射合约
interface Nest_NToken_TokenMapping {
    // 查看token映射
    function checkTokenMapping(address token) external view returns (address);
}

// 分红池合约
interface Nest_3_Abonus {
    function switchToEth(address token) external payable;
    function switchToEthForNTokenOffer(address token) external payable;
}






