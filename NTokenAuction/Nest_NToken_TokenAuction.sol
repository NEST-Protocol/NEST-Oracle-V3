pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/AddressPayable.sol";
import "../Lib/SafeERC20.sol";

/**
 * @title 拍卖报价token合约
 * @dev 上币拍卖并生成nToken
 */
contract Nest_NToken_TokenAuction {
    using SafeMath for uint256;
    using address_make_payable for address;
    using SafeERC20 for ERC20;
    
    Nest_3_VoteFactory _voteFactory;                            //  投票合约
    Nest_NToken_TokenMapping _tokenMapping;                     //  NToken 映射合约
    ERC20 _nestToken;                                           //  NestToken
    Nest_3_OfferPrice _offerPrice;                              //  价格合约
    address _destructionAddress;                                //  销毁合约地址
    uint256 _duration = 5 days;                                 //  拍卖持续时间
    uint256 _minimumNest = 100000 ether;                        //  最小拍卖金额
    uint256 _tokenNum = 1;                                      //  拍卖 token 编号
    uint256 _incentiveRatio = 50;                               //  激励比例
    uint256 _minimumInterval = 10000 ether;                     //  最小拍卖区间
    mapping(address => AuctionInfo) _auctionList;               //  拍卖列表
    mapping(address => bool) _tokenBlackList;                   //  拍卖黑名单
    struct AuctionInfo {
        uint256 endTime;                                        //  开始时间
        uint256 auctionValue;                                   //  拍卖价格
        address latestAddress;                                  //  最高拍卖者
        uint256 latestAmount;                                   //  最后nest资产
    }
    address[] _allAuction;                                      //  拍卖列表数组
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor (address voteFactory) public {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
        _nestToken = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
        _offerPrice = Nest_3_OfferPrice(address(voteFactoryMap.checkAddress("nest.v3.offerPrice")));
    }
    
    /**
    * @dev 重置投票合约 
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap;
        _tokenMapping = Nest_NToken_TokenMapping(address(voteFactoryMap.checkAddress("nest.nToken.tokenMapping")));
        _nestToken = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
        _offerPrice = Nest_3_OfferPrice(address(voteFactoryMap.checkAddress("nest.v3.offerPrice")));
    }
    
    /**
    * @dev 发起拍卖
    * @param token 拍卖token地址
    * @param auctionAmount 初始拍卖资金
    */
    function startAnAuction(address token, uint256 auctionAmount) public {
        require(_tokenMapping.checkTokenMapping(token) == address(0x0), "Token already exists");
        require(_auctionList[token].endTime == 0, "Token is on sale");
        require(auctionAmount >= _minimumNest, "AuctionAmount less than the minimum auction amount");
        require(_nestToken.transferFrom(address(msg.sender), address(this), auctionAmount), "Authorization failed");
        require(!_tokenBlackList[token]);
        // 验证
        ERC20 tokenERC20 = ERC20(token);
        tokenERC20.safeTransferFrom(address(msg.sender), address(this), 1);
        require(tokenERC20.balanceOf(address(this)) >= 1);
        tokenERC20.safeTransfer(address(msg.sender), 1);
        AuctionInfo memory thisAuction = AuctionInfo(now.add(_duration), auctionAmount, address(msg.sender), auctionAmount);
        _auctionList[token] = thisAuction;
        _allAuction.push(token);
    }
    
    /**
    * @dev 拍卖
    * @param token 拍卖token地址
    * @param auctionAmount 拍卖资金
    */
    function continueAuction(address token, uint256 auctionAmount) public {
        require(now <= _auctionList[token].endTime && _auctionList[token].endTime != 0, "Auction closed");
        require(auctionAmount > _auctionList[token].auctionValue, "Insufficient auction amount");
        uint256 subAuctionAmount = auctionAmount.sub(_auctionList[token].auctionValue);
        require(subAuctionAmount >= _minimumInterval);
        uint256 excitation = subAuctionAmount.mul(_incentiveRatio).div(100);
        require(_nestToken.transferFrom(address(msg.sender), address(this), auctionAmount), "Authorization failed");
        require(_nestToken.transfer(_auctionList[token].latestAddress, _auctionList[token].auctionValue.add(excitation)), "Transfer failure");
        // 更新拍卖信息
        _auctionList[token].auctionValue = auctionAmount;
        _auctionList[token].latestAddress = address(msg.sender);
        _auctionList[token].latestAmount = _auctionList[token].latestAmount.add(subAuctionAmount.sub(excitation));
    }
    
    /**
    * @dev 上币
    * @param token 拍卖token地址
    */
    function auctionSuccess(address token) public {
        Nest_3_TokenAbonus nestAbonus = Nest_3_TokenAbonus(_voteFactory.checkAddress("nest.v3.tokenAbonus"));
        uint256 nowTime = now;
        uint256 nextTime = nestAbonus.getNextTime();
        uint256 timeLimit = nestAbonus.checkTimeLimit();
        uint256 getAbonusTimeLimit = nestAbonus.checkGetAbonusTimeLimit();
        require(!(nowTime >= nextTime.sub(timeLimit) && nowTime <= nextTime.sub(timeLimit).add(getAbonusTimeLimit)), "Not time to auctionSuccess");
        require(nowTime > _auctionList[token].endTime && _auctionList[token].endTime != 0, "Token is on sale");
        //  初始化 NToken
        Nest_NToken nToken = new Nest_NToken(strConcat("NToken", getAddressStr(_tokenNum)), strConcat("N", getAddressStr(_tokenNum)), address(_voteFactory), address(_auctionList[token].latestAddress));
        //  拍卖资金销毁
        require(_nestToken.transfer(_destructionAddress, _auctionList[token].latestAmount), "Transfer failure");
        //  加入 NToken 映射
        _tokenMapping.addTokenMapping(token, address(nToken));
        //  初始化收费参数
        _offerPrice.addPriceCost(token);
        _tokenNum = _tokenNum.add(1);
    }
    
    function strConcat(string memory _a, string memory _b) public pure returns (string memory){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory ret = new string(_ba.length + _bb.length);
        bytes memory bret = bytes(ret);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) {
            bret[k++] = _ba[i];
        } 
        for (uint i = 0; i < _bb.length; i++) {
            bret[k++] = _bb[i];
        } 
        return string(ret);
    } 
    
    // 转换4位数字字符串
    function getAddressStr(uint256 iv) public pure returns (string memory) {
        bytes memory buf = new bytes(64);
        uint256 index = 0;
        do {
            buf[index++] = byte(uint8(iv % 10 + 48));
            iv /= 10;
        } while (iv > 0 || index < 4);
        bytes memory str = new bytes(index);
        for(uint256 i = 0; i < index; ++i) {
            str[i] = buf[index - i - 1];
        }
        return string(str);
    }
    
    // 查看拍卖持续时间
    function checkDuration() public view returns(uint256) {
        return _duration;
    }
    
    // 查看最小拍卖金额
    function checkMinimumNest() public view returns(uint256) {
        return _minimumNest;
    }
    
    // 查看已发起拍卖tokens数量
    function checkAllAuctionLength() public view returns(uint256) {
        return _allAuction.length;
    }
    
    // 查看已拍卖 token 地址
    function checkAuctionTokenAddress(uint256 num) public view returns(address) {
        return _allAuction[num];
    }
    
    // 查看拍卖黑名单
    function checkTokenBlackList(address token) public view returns(bool) {
        return _tokenBlackList[token];
    }
    
    // 查看拍卖token信息
    function checkAuctionInfo(address token) public view returns(uint256 endTime, uint256 auctionValue, address latestAddress) {
        AuctionInfo memory info = _auctionList[token];
        return (info.endTime, info.auctionValue, info.latestAddress);
    }
    
    // 查看token编号
    function checkTokenNum() public view returns (uint256) {
        return _tokenNum;
    }
    
    // 修改拍卖持续时间
    function changeDuration(uint256 num) public onlyOwner {
        _duration = num.mul(1 days);
    }
    
    // 修改最小拍卖金额
    function changeMinimumNest(uint256 num) public onlyOwner {
        _minimumNest = num;
    }
    
    // 修改拍卖黑名单
    function changeTokenBlackList(address token, bool isBlack) public onlyOwner {
        _tokenBlackList[token] = isBlack;
    }
    
    // 仅限管理员操作
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender), "No authority");
        _;
    }
    
}

// 分红逻辑合约
interface Nest_3_TokenAbonus {
    // 下次分红时间
    function getNextTime() external view returns (uint256);
    // 分红周期
    function checkTimeLimit() external view returns (uint256);
    // 领取分红周期
    function checkGetAbonusTimeLimit() external view returns (uint256);
}

// 投票合约
interface Nest_3_VoteFactory {
    // 查询地址
	function checkAddress(string calldata name) external view returns (address contractAddress);
	// 查看是否管理员
	function checkOwners(address man) external view returns (bool);
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

contract Nest_NToken is IERC20 {
    using SafeMath for uint256;
    
    mapping (address => uint256) private _balances;                                 //  账本
    mapping (address => mapping (address => uint256)) private _allowed;             //  授权账本
    uint256 private _totalSupply = 0 ether;                                         //  总量
    string public name;                                                             //  名称
    string public symbol;                                                           //  简称
    uint8 public decimals = 18;                                                     //  精度
    uint256 public _createBlock;                                                    //  创建区块
    uint256 public _recentlyUsedBlock;                                              //  最近使用区块
    Nest_3_VoteFactory _voteFactory;                                                //  投票合约
    address _bidder;                                                                //  拥有者
    
    /**
    * @dev 初始化方法
    * @param _name token名称
    * @param _symbol token简称
    * @param voteFactory 投票合约地址
    * @param bidder 中标者地址
    */
    constructor (string memory _name, string memory _symbol, address voteFactory, address bidder) public {
    	name = _name;                                                               
    	symbol = _symbol;
    	_createBlock = block.number;
    	_recentlyUsedBlock = block.number;
    	_voteFactory = Nest_3_VoteFactory(address(voteFactory));
    	_bidder = bidder;
    }
    
    /**
    * @dev 重置投票合约方法
    * @param voteFactory 投票合约地址
    */
    function changeMapping (address voteFactory) public onlyOwner {
    	_voteFactory = Nest_3_VoteFactory(address(voteFactory));
    }
    
    /**
    * @dev 增发
    * @param value 增发数量
    */
    function increaseTotal(uint256 value) public {
        address offerMain = address(_voteFactory.checkAddress("nest.nToken.offerMain"));
        require(address(msg.sender) == offerMain, "No authority");
        _balances[offerMain] = _balances[offerMain].add(value);
        _totalSupply = _totalSupply.add(value);
        _recentlyUsedBlock = block.number;
    }

    /**
    * @dev 查询token总量
    * @return token总量
    */
    function totalSupply() override public view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev 查询地址余额
    * @param owner 要查询的地址
    * @return 返回对应地址的余额
    */
    function balanceOf(address owner) override public view returns (uint256) {
        return _balances[owner];
    }
    
    /**
    * @dev 查询区块信息
    * @return createBlock 初始区块数
    * @return recentlyUsedBlock 最近挖矿增发区块
    */
    function checkBlockInfo() public view returns(uint256 createBlock, uint256 recentlyUsedBlock) {
        return (_createBlock, _recentlyUsedBlock);
    }

    /**
     * @dev 查询 owner 对 spender 的授权额度
     * @param owner 发起授权的地址
     * @param spender 被授权的地址
     * @return 已授权的金额
     */
    function allowance(address owner, address spender) override public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
    * @dev 转账方法
    * @param to 转账目标
    * @param value 转账金额
    * @return 转账是否成功
    */
    function transfer(address to, uint256 value) override public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 授权方法
     * @param spender 授权目标
     * @param value 授权数量
     * @return 授权是否成功
     */
    function approve(address spender, uint256 value) override public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev 已授权状态下，从 from地址转账到to地址
     * @param from 转出的账户地址 
     * @param to 转入的账户地址
     * @param value 转账金额
     * @return 授权转账是否成功
     */
    function transferFrom(address from, address to, uint256 value) override public returns (bool) {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        emit Approval(from, msg.sender, _allowed[from][msg.sender]);
        return true;
    }

    /**
     * @dev 增加授权额度
     * @param spender 授权目标
     * @param addedValue 增加的额度
     * @return 增加授权额度是否成功
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev 减少授权额度
     * @param spender 授权目标
     * @param subtractedValue 减少的额度
     * @return 减少授权额度是否成功
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].sub(subtractedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
    * @dev 转账方法
    * @param to 转账目标
    * @param value 转账金额
    */
    function _transfer(address from, address to, uint256 value) internal {
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }
    
    /**
    * @dev 查询创建者
    * @return 创建者地址
    */
    function checkBidder() public view returns(address) {
        return _bidder;
    }
    
    /**
    * @dev 转让创建者
    * @param bidder 新创建者地址
    */
    function changeBidder(address bidder) public {
        require(address(msg.sender) == _bidder);
        _bidder = bidder; 
    }
    
    // 仅限管理员操作
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender));
        _;
    }
}

// NToken 映射合约
interface Nest_NToken_TokenMapping {
    //  增加映射
    function addTokenMapping(address token, address nToken) external;
    function checkTokenMapping(address token) external view returns (address);
}

// 价格合约
interface Nest_3_OfferPrice {
    function addPriceCost(address tokenAddress) external;
}
