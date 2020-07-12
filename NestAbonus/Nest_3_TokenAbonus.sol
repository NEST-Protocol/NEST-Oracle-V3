pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/AddressPayable.sol";

contract Nest_3_TokenAbonus {
    using address_make_payable for address;
    using SafeMath for uint256;
    
    ERC20 _nestContract;
    Nest_3_TokenSave _tokenSave;                                                                //  锁仓合约
    Nest_3_Abonus _abonusContract;                                                              //  eth分红池
    Nest_3_VoteFactory _voteFactory;                                                            //  投票合约
    Nest_3_Leveling _nestLeveling;                                                              //  平准合约
    address _destructionAddress;                                                                //  销毁合约地址
    
    uint256 _timeLimit = 168 hours;                                                             //  分红周期
    uint256 _nextTime = 1594958400;                                                             //  下次分红时间
    uint256 _getAbonusTimeLimit = 60 hours;                                                     //  触发计算结算时间
    uint256 _times = 0;                                                                         //  分红账本
    uint256 _expectedIncrement = 3;                                                             //  预期分红增量比例
    uint256 _expectedSpanForNest = 100000000 ether;                                             //  NEST预期分红增量阈值
    uint256 _expectedSpanForNToken = 1000000 ether;                                             //  Ntoken预期分红增量阈值
    uint256 _expectedMinimum = 100 ether;                                                       //  预期最低分红
    uint256 _savingLevelOne = 10;                                                               //  储蓄阈值1级
    uint256 _savingLevelTwo = 20;                                                               //  储蓄阈值2级
    uint256 _savingLevelTwoSub = 100 ether;                                                     //  储蓄阈值2级函数参数
    uint256 _savingLevelThree = 30;                                                             //  储蓄阈值3级
    uint256 _savingLevelThreeSub = 600 ether;                                                   //  储蓄阈值3级函数参数
    
    mapping(address => uint256) _abonusMapping;                                                 //  分红池快照  token地址(nest或ntoken) => 分红池中 eth 数量 
    mapping(address => uint256) _tokenAllValueMapping;                                          //  token数量(流通) token地址(nest或ntoken) => 总流通量
    mapping(address => mapping(uint256 => uint256)) _tokenAllValueHistory;                      //  nest或ntoken流通量快照 token地址(nest或ntoken) => 期数 => 总流通量
    mapping(address => mapping(uint256 => mapping(address => uint256))) _tokenSelfHistory;      //  个人锁仓nest或ntoken快照 token地址(nest或ntoken) => 期数 => 用户地址 => 总流通量
    mapping(address => mapping(uint256 => bool)) _snapshot;                                     //  是否快照 token地址(nest或ntoken) => 期数 => 是否快照
    mapping(uint256 => mapping(address => mapping(address => bool))) _getMapping;               //  领取记录账本 期数 => token地址(nest或ntoken) => 用户地址 => 是否已经领取
    
    //  log token地址,数量
    event GetTokenLog(address tokenAddress, uint256 tokenAmount);
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor (address voteFactory) public {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap; 
        _nestContract = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _tokenSave = Nest_3_TokenSave(address(voteFactoryMap.checkAddress("nest.v3.tokenSave")));
        address payable addr = address(voteFactoryMap.checkAddress("nest.v3.abonus")).make_payable();
        _abonusContract = Nest_3_Abonus(addr);
        address payable levelingAddr = address(voteFactoryMap.checkAddress("nest.v3.leveling")).make_payable();
        _nestLeveling = Nest_3_Leveling(levelingAddr);
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
    }
    
    /**
    * @dev 修改投票合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
        Nest_3_VoteFactory voteFactoryMap = Nest_3_VoteFactory(address(voteFactory));
        _voteFactory = voteFactoryMap; 
        _nestContract = ERC20(address(voteFactoryMap.checkAddress("nest")));
        _tokenSave = Nest_3_TokenSave(address(voteFactoryMap.checkAddress("nest.v3.tokenSave")));
        address payable addr = address(voteFactoryMap.checkAddress("nest.v3.abonus")).make_payable();
        _abonusContract = Nest_3_Abonus(addr);
        address payable levelingAddr = address(voteFactoryMap.checkAddress("nest.v3.leveling")).make_payable();
        _nestLeveling = Nest_3_Leveling(levelingAddr);
        _destructionAddress = address(voteFactoryMap.checkAddress("nest.v3.destruction"));
    }
    
    /**
    * @dev 存入
    * @param amount 存入数量
    * @param token 锁仓 token 地址
    */
    function depositIn(uint256 amount, address token) public {
        uint256 nowTime = now;
        uint256 nextTime = _nextTime;
        uint256 timeLimit = _timeLimit;
        if (nowTime < nextTime) {
            //  已触发分红
            require(!(nowTime >= nextTime.sub(timeLimit) && nowTime <= nextTime.sub(timeLimit).add(_getAbonusTimeLimit)));
        } else {
            //  未触发分红
            uint256 times = (nowTime.sub(_nextTime)).div(_timeLimit);
            //  计算应该分红的时间
            uint256 startTime = _nextTime.add((times).mul(_timeLimit));  
            //  计算应该停止分红的时间
            uint256 endTime = startTime.add(_getAbonusTimeLimit);                                                                    
            require(!(nowTime >= startTime && nowTime <= endTime));
        }
        _tokenSave.depositIn(amount, token, address(msg.sender));                 
    }
    
    /**
    * @dev 取出
    * @param amount 取出数量
    * @param token 锁仓 token 地址
    */
    function takeOut(uint256 amount, address token) public {
        require(amount > 0, "Parameter needs to be greater than 0");                                                                
        require(amount <= _tokenSave.checkAmount(address(msg.sender), token), "Insufficient storage balance");
        if (token == address(_nestContract)) {
            require(!_voteFactory.checkVoteNow(address(tx.origin)), "Voting");
        }
        _tokenSave.takeOut(amount, token, address(msg.sender));                                                             
    }                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
    
    /**
    * @dev 领取
    * @param token 领取 token 地址
    */
    function getAbonus(address token) public {
        uint256 tokenAmount = _tokenSave.checkAmount(address(msg.sender), token);
        require(tokenAmount > 0, "Insufficient storage balance");
        reloadTime();
        reloadToken(token);                                                                                                      
        uint256 nowTime = now;
        require(nowTime >= _nextTime.sub(_timeLimit) && nowTime <= _nextTime.sub(_timeLimit).add(_getAbonusTimeLimit), "Not time to draw");
        require(!_getMapping[_times.sub(1)][token][address(msg.sender)], "Have received");                                     
        _tokenSelfHistory[token][_times.sub(1)][address(msg.sender)] = tokenAmount;                                         
        require(_tokenAllValueMapping[token] > 0, "Total flux error");
        uint256 selfNum = tokenAmount.mul(_abonusMapping[token]).div(_tokenAllValueMapping[token]);
        require(selfNum > 0, "No limit available");
        _getMapping[_times.sub(1)][token][address(msg.sender)] = true;
        _abonusContract.getETH(selfNum, token,address(msg.sender)); 
        emit GetTokenLog(token, selfNum);
    }
    
    /**
    * @dev 更新分红时间、更新阶段账本
    */
    function reloadTime() private {
        uint256 nowTime = now;
        //  当前时间必须超过分红时间
        if (nowTime >= _nextTime) {                                                                                                 
            uint256 time = (nowTime.sub(_nextTime)).div(_timeLimit);
            uint256 startTime = _nextTime.add((time).mul(_timeLimit));                                                              
            uint256 endTime = startTime.add(_getAbonusTimeLimit);                                                                   
            if (nowTime >= startTime && nowTime <= endTime) {
                _nextTime = getNextTime();                                                                                      
                _times = _times.add(1);                                                                                       
            }
        }
    }
    
    /**
    * @dev 快照 token数量
    * @param token 领取token地址
    */
    function reloadToken(address token) private {
        if (!_snapshot[token][_times.sub(1)]) {
            levelingResult(token);                                                                                          
            _abonusMapping[token] = _abonusContract.getETHNum(token); 
            _tokenAllValueMapping[token] = allValue(token);
            _tokenAllValueHistory[token][_times.sub(1)] = allValue(token);
            _snapshot[token][_times.sub(1)] = true;
        }
    }
    
    /**
    * @dev 平准结算
    * @param token 领取token地址
    */
    function levelingResult(address token) private {
        uint256 steps;
        if (token == address(_nestContract)) {
            steps = allValue(token).div(_expectedSpanForNest);
        } else {
            steps = allValue(token).div(_expectedSpanForNToken);
        }
        uint256 minimumAbonus = _expectedMinimum;
        for (uint256 i = 0; i < steps; i++) {
            minimumAbonus = minimumAbonus.add(minimumAbonus.mul(_expectedIncrement).div(100));
        }
        uint256 thisAbonus = _abonusContract.getETHNum(token);
        if (thisAbonus > minimumAbonus) {
            uint256 levelAmount = 0;
            if (thisAbonus > 5000 ether) {
                levelAmount = thisAbonus.mul(_savingLevelThree).div(100).sub(_savingLevelThreeSub);
            } else if (thisAbonus > 1000 ether) {
                levelAmount = thisAbonus.mul(_savingLevelTwo).div(100).sub(_savingLevelTwoSub);
            } else {
                levelAmount = thisAbonus.mul(_savingLevelOne).div(100);
            }
            if (thisAbonus.sub(levelAmount) < minimumAbonus) {
                _abonusContract.getETH(thisAbonus.sub(minimumAbonus), token, address(this));
                _nestLeveling.switchToEth.value(thisAbonus.sub(minimumAbonus))(token);
            } else {
                _abonusContract.getETH(levelAmount, token, address(this));
                _nestLeveling.switchToEth.value(levelAmount)(token);
            }
        } else {
            uint256 ethValue = _nestLeveling.tranEth(minimumAbonus.sub(thisAbonus), token, address(this));
            _abonusContract.switchToEth.value(ethValue)(token);
        }
    }
    
     //  下次分红时间，本次分红截止时间，ETH数，nest数, 参与分红的nest, 可领取分红,授权金额，余额，是否可以分红
    function getInfo(address token) public view returns (uint256 nextTime, uint256 getAbonusTime, uint256 ethNum, uint256 tokenValue, uint256 myJoinToken, uint256 getEth, uint256 allowNum, uint256 leftNum, bool allowAbonus)  {
        uint256 nowTime = now;
        if (nowTime >= _nextTime.sub(_timeLimit) && nowTime <= _nextTime.sub(_timeLimit).add(_getAbonusTimeLimit)) {
            //  已经触发分红，并且在本次分红的时段内,显示快照数据
            allowAbonus = _getMapping[_times.sub(1)][token][address(msg.sender)];
            ethNum = _abonusMapping[token];
            tokenValue = _tokenAllValueMapping[token];
        } else {
            //  显示实时数据
            ethNum = _abonusContract.getETHNum(token);
            tokenValue = allValue(token);
            allowAbonus = _getMapping[_times][token][address(msg.sender)];
        }
        myJoinToken = _tokenSave.checkAmount(address(msg.sender), token);
        if (allowAbonus == true) {
            getEth = 0; 
        } else {
            getEth = myJoinToken.mul(ethNum).div(tokenValue);
        }
        nextTime = getNextTime();
        getAbonusTime = nextTime.sub(_timeLimit).add(_getAbonusTimeLimit);
        allowNum = ERC20(token).allowance(address(msg.sender), address(_tokenSave));
        leftNum = ERC20(token).balanceOf(address(msg.sender));
    }
    
    /**
    * @dev 下次分红时间
    * @return 下次分红时间
    */
    function getNextTime() public view returns (uint256) {
        uint256 nowTime = now;
        if (_nextTime > nowTime) { 
            return _nextTime; 
        } else {
            uint256 time = (nowTime.sub(_nextTime)).div(_timeLimit);
            return _nextTime.add(_timeLimit.mul(time.add(1)));
        }
    }
    
    /**
    * @dev 查看总流通量
    * @return 总流通量
    */
    function allValue(address token) public view returns (uint256) {
        if (token == address(_nestContract)) {
            uint256 all = 10000000000 ether;
            uint256 leftNum = all.sub(_nestContract.balanceOf(address(_voteFactory.checkAddress("nest.v3.miningSave")))).sub(_nestContract.balanceOf(address(_destructionAddress)));
            return leftNum;
        } else {
            return ERC20(token).totalSupply();
        }
    }
    
    /**
    * @dev 查看分红周期
    * @return 分红周期
    */
    function checkTimeLimit() public view returns (uint256) {
        return _timeLimit;
    }
    
    /**
    * @dev 查看领取分红周期
    * @return 领取分红周期
    */
    function checkGetAbonusTimeLimit() public view returns (uint256) {
        return _getAbonusTimeLimit;
    }
    
    /**
    * @dev 查看当前最低预期分红
    * @return 当前最低预期分红
    */
    function checkMinimumAbonus(address token) public view returns (uint256) {
        uint256 miningAmount;
        if (token == address(_nestContract)) {
            miningAmount = allValue(token).div(_expectedSpanForNest);
        } else {
            miningAmount = allValue(token).div(_expectedSpanForNToken);
        }
        uint256 minimumAbonus = _expectedMinimum;
        for (uint256 i = 0; i < miningAmount; i++) {
            minimumAbonus = minimumAbonus.add(minimumAbonus.mul(_expectedIncrement).div(100));
        }
        return minimumAbonus;
    }
    
    /**
    * @dev 查看分红 token 是否快照
    * @param token token 地址
    * @return 是否快照
    */
    function checkSnapshot(address token) public view returns (bool) {
        return _snapshot[token][_times.sub(1)];
    }
    
    /**
    * @dev 查看预期分红增量比例
    * @return 预期分红增量比例
    */
    function checkeExpectedIncrement() public view returns (uint256) {
        return _expectedIncrement;
    }
    
    /**
    * @dev 查看预期最低分红
    * @return 预期最低分红
    */
    function checkExpectedMinimum() public view returns (uint256) {
        return _expectedMinimum;
    }
    
    /**
    * @dev 查看储蓄阈值
    * @return 储蓄阈值
    */
    function checkSavingLevelOne() public view returns (uint256) {
        return _savingLevelOne;
    }
    function checkSavingLevelTwo() public view returns (uint256) {
        return _savingLevelTwo;
    }
    function checkSavingLevelThree() public view returns (uint256) {
        return _savingLevelThree;
    }
    
    /**
    * @dev 查看nest流通量快照
    * @param token 锁仓 token 地址
    * @param times 分红快照期数
    */
    function checkTokenAllValueHistory(address token, uint256 times) public view returns (uint256) {
        return _tokenAllValueHistory[token][times];
    }
    
    /**
    * @dev 查看个人锁仓nest快照
    * @param times 分红快照期数
    * @param user 用户地址
    * @return 个人锁仓nest快照数量
    */
    function checkTokenSelfHistory(address token, uint256 times, address user) public view returns (uint256) {
        return _tokenSelfHistory[token][times][user];
    }
    
    // 查看分红账本期数
    function checkTimes() public view returns (uint256) {
        return _times;
    }
    
    // NEST预期分红增量阈值
    function checkExpectedSpanForNest() public view returns (uint256) {
        return _expectedSpanForNest;
    }
    
    // NToken预期分红增量阈值
    function checkExpectedSpanForNToken() public view returns (uint256) {
        return _expectedSpanForNToken;
    }
    
    // 查看储蓄阈值2级函数参数
    function checkSavingLevelTwoSub() public view returns (uint256) {
        return _savingLevelTwoSub;
    }
    
    // 查看储蓄阈值3级函数参数
    function checkSavingLevelThreeSub() public view returns (uint256) {
        return _savingLevelThreeSub;
    }
    
    /**
    * @dev 更新分红周期
    * @param hour 分红周期(小时)
    */
    function changeTimeLimit(uint256 hour) public onlyOwner {
        require(hour > 0, "Parameter needs to be greater than 0");
        _timeLimit = hour.mul(1 hours);
    }
    
    /**
    * @dev 更新领取周期
    * @param hour 领取周期(小时)
    */
    function changeGetAbonusTimeLimit(uint256 hour) public onlyOwner {
        require(hour > 0, "Parameter needs to be greater than 0");
        _getAbonusTimeLimit = hour;
    }
    
    /**
    * @dev 更新预期分红增量比例
    * @param num 预期分红增量比例
    */
    function changeExpectedIncrement(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _expectedIncrement = num;
    }
    
    /**
    * @dev 更新预期最低分红
    * @param num 预期最低分红
    */
    function changeExpectedMinimum(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _expectedMinimum = num;
    }
    
    /**
    * @dev 更新储蓄阈值
    * @param threshold 储蓄阈值
    */
    function changeSavingLevelOne(uint256 threshold) public onlyOwner {
        _savingLevelOne = threshold;
    }
    function changeSavingLevelTwo(uint256 threshold) public onlyOwner {
        _savingLevelTwo = threshold;
    }
    function changeSavingLevelThree(uint256 threshold) public onlyOwner {
        _savingLevelThree = threshold;
    }
    
    /**
    * @dev 更新储蓄阈值2级函数参数
    */
    function changeSavingLevelTwoSub(uint256 num) public onlyOwner {
        _savingLevelTwoSub = num;
    }
    
    /**
    * @dev 更新储蓄阈值3级函数参数
    */
    function changeSavingLevelThreeSub(uint256 num) public onlyOwner {
        _savingLevelThreeSub = num;
    }
    
    /**
    * @dev 更新NEST预期分红增量阈值
    * @param num 阈值
    */
    function changeExpectedSpanForNest(uint256 num) public onlyOwner {
        _expectedSpanForNest = num;
    }
    
    /**
    * @dev 更新NToken预期分红增量阈值
    * @param num 阈值
    */
    function changeExpectedSpanForNToken(uint256 num) public onlyOwner {
        _expectedSpanForNToken = num;
    }
    
    receive() external payable {
        
    }
    
    // 仅限管理员
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(address(msg.sender)), "No authority");
        _;
    }
}

// NEST及NToken锁仓合约
interface Nest_3_TokenSave {
    function depositIn(uint256 num, address token, address target) external;
    function checkAmount(address sender, address token) external view returns(uint256);
    function takeOut(uint256 num, address token, address target) external;
}

// ETH分红池
interface Nest_3_Abonus {
    function getETH(uint256 num, address token, address target) external;
    function getETHNum(address token) external view returns (uint256);
    function switchToEth(address token) external payable;
}

// 平准合约
interface Nest_3_Leveling {
    function tranEth(uint256 amount, address token, address target) external returns (uint256);
    function switchToEth(address token) external payable;
}

// 投票工厂
interface Nest_3_VoteFactory {
    // 查看是否有正在参与的投票 
    function checkVoteNow(address user) external view returns(bool);
    // 查询地址
	function checkAddress(string calldata name) external view returns (address contractAddress);
	// 查看是否管理员
	function checkOwners(address man) external view returns (bool);
}

// ERC20合约
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