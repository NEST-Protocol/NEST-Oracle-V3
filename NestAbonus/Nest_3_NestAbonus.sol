pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";
import "../Lib/AddressPayable.sol";

contract Nest_3_NestAbonus {
    using address_make_payable for address;
    using SafeMath for uint256;
    
    ERC20 _nestContract;
    Nest_3_NestSave _nestSave;                                                          //  锁仓合约
    Nest_3_Abonus _abonusContract;                                                      //  eth分红池
    Nest_3_VoteFactory _voteFactory;                                                    //  投票合约
    Nest_3_NTokenAbonus _nTokenAbonus;                                                  //  nToken分红池
    Nest_3_Leveling _nestLeveling;                                                      //  平准合约
    address _destructionAddress;                                                        //  销毁合约地址
    
    uint256 _timeLimit = 30 minutes;                                                    //  分红周期168
    uint256 _nextTime = 1589538600;                                                     //  下次分红时间
    uint256 _getAbonusTimeLimit = 20 minutes;                                           //  触发计算结算时间60
    uint256 _nestAllValue = 0;                                                          //  nest数量(流通)
    uint256 _times = 0;                                                                 //  分红账本
    uint256 _expectedIncrement = 3;                                                     //  预期分红增量比例
    uint256 _expectedMinimum = 100 ether;                                               //  预期最低分红
    uint256 _savingLevelOne = 10;                                                       //  储蓄阈值1级
    uint256 _savingLevelTwo = 20;                                                       //  储蓄阈值2级
    uint256 _savingLevelThree = 30;                                                     //  储蓄阈值3级
    
    mapping(address => uint256) _abonusMapping;                                         //  分红池快照
    mapping(uint256 => uint256) _nestAllValueMapping;                                   //  nest流通量快照
    mapping(uint256 => mapping(address => uint256)) _nestMapping;                       //  个人锁仓nest快照
    mapping(address => mapping(uint256 => bool)) _snapshot;                             //  是否快照
    mapping(uint256 => mapping(address => mapping(address => bool))) _getMapping;       //  领取记录账本
    
    //  领取日志,token地址,数量
    event GetTokenLog(address tokenAddress, uint256 tokenAmount);
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor (address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
        _nestContract = ERC20(address(_voteFactory.checkAddress("nest")));
        _nestSave = Nest_3_NestSave(address(_voteFactory.checkAddress("nest.v3.nestSave")));
        address payable addr = address(_voteFactory.checkAddress("nest.v3.abonus")).make_payable();
        _abonusContract = Nest_3_Abonus(addr);
        _nTokenAbonus = Nest_3_NTokenAbonus(address(_voteFactory.checkAddress("nest.v3.nTokenAbonus")));
        address payable levelingAddr = address(_voteFactory.checkAddress("nest.v3.leveling")).make_payable();
        _nestLeveling = Nest_3_Leveling(levelingAddr);
        _destructionAddress = address(_voteFactory.checkAddress("nest.nToken.destruction"));
    }
    
    /**
    * @dev 修改投票合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
        _voteFactory = Nest_3_VoteFactory(voteFactory); 
        _nestContract = ERC20(address(_voteFactory.checkAddress("nest")));
        _nestSave = Nest_3_NestSave(address(_voteFactory.checkAddress("nest.v3.nestSave")));
        address payable addr = address(_voteFactory.checkAddress("nest.v3.abonus")).make_payable();
        _abonusContract = Nest_3_Abonus(addr);
        _nTokenAbonus = Nest_3_NTokenAbonus(address(_voteFactory.checkAddress("nest.v3.nTokenAbonus")));
        address payable levelingAddr = address(_voteFactory.checkAddress("nest.v3.leveling")).make_payable();
        _nestLeveling = Nest_3_Leveling(levelingAddr);
        _destructionAddress = address(_voteFactory.checkAddress("nest.v3.destruction"));
    }
    
    /**
    * @dev 存入
    * @param amount 存入数量
    */
    function depositIn(uint256 amount) public {
        uint256 nowTime = now;
        //  禁止
        if (nowTime < _nextTime) {
            //  已触发分红
            require(!(nowTime >= _nextTime.sub(_timeLimit) && nowTime <= _nextTime.sub(_timeLimit).add(_getAbonusTimeLimit)));
        } else {
            //  未触发分红
            require(!(nowTime >= _nextTime && nowTime <= _nextTime.add(_getAbonusTimeLimit)));
            uint256 time = (nowTime.sub(_nextTime)).div(_timeLimit);
            uint256 startTime = _nextTime.add((time).mul(_timeLimit));                                                              //  计算应该分红的时间
            uint256 endTime = startTime.add(_getAbonusTimeLimit);                                                                   //  计算应该停止分红的时间
            require(!(nowTime >= startTime && nowTime <= endTime));
        }
        _nestSave.depositIn(amount, address(msg.sender));                                                                           //  存入
    }
    
    /**
    * @dev 取出
    * @param amount 取出数量
    */
    function takeOut(uint256 amount) public {
        require(amount > 0, "Parameter needs to be greater than 0");                                                                //  不能取出0个
        require(amount <= _nestSave.checkAmount(address(msg.sender)), "Insufficient storage balance");
        require(_voteFactory.checkVoteNow(address(tx.origin)), "Voting");
        _nestSave.takeOut(amount, address(msg.sender));                                                                             //  转出
    }                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
    
    /**
    * @dev 领取
    * @param token 领取token地址
    */
    function getAbonus(address token) public {
        reloadTimeAndMapping(token);                                                                                                //  时间超过优先结算，结算后分红
        uint256 nowTime = now;
        require(nowTime >= _nextTime.sub(_timeLimit) && nowTime <= _nextTime.sub(_timeLimit).add(_getAbonusTimeLimit), "Not time to draw");
        require(_getMapping[_times.sub(1)][token][address(msg.sender)] != true, "Have received");                                   //  上期分红没有领取记录 
        uint256 nestAmount = _nestSave.checkAmount(address(msg.sender));
        if (nestAmount != _nestMapping[_times.sub(1)][address(msg.sender)]) {
            _nestMapping[_times.sub(1)][address(msg.sender)] = nestAmount;                                                          //  个人锁仓nest快照
        }
        require(nestAmount > 0, "Insufficient storage balance");
        require(_nestAllValue > 0, "Total flux error");
        uint256 selfNum = nestAmount.mul(_abonusMapping[token]).div(_nestAllValue);
        require(selfNum > 0, "No limit available");
        
        _getMapping[_times.sub(1)][token][address(msg.sender)] = true;
        if (token == address(0x0)) {
            _abonusContract.getETH(selfNum, address(msg.sender));                                                                   //  转账eth
        } else {
            _nTokenAbonus.getNToken(selfNum, address(msg.sender), token);                                                           //  转账ntoken
        }
        emit GetTokenLog(token, selfNum);
    }
    
    /**
    * @dev 更新分红时间、更新阶段账本
    * @param token 领取token地址
    */
    function reloadTimeAndMapping(address token) private {
        uint256 nowTime = now;
        if (nowTime >= _nextTime) {                                                                                                 //  当前时间必须超过分红时间
            levelingResult();                                                                                                       //  触发平准
            uint256 time = (nowTime.sub(_nextTime)).div(_timeLimit);
            uint256 startTime = _nextTime.add((time).mul(_timeLimit));                                                              //  计算应该分红的时间
            uint256 endTime = startTime.add(_getAbonusTimeLimit);                                                                   //  计算应该停止分红的时间
            if (nowTime >= startTime && nowTime <= endTime) {
                _nextTime = getNextTime();                                                                                          //  设置下次分红时间
                _nestAllValue = allValue();                                                                                         //  快照 nest流通量
                _nestAllValueMapping[_times] = allValue();
                _times = _times.add(1);                                                                                             //  账本封存
            }
        }
        if (_snapshot[token][_times.sub(1)] == false) {
            if (token == address(0x0)) {
                _abonusMapping[address(0x0)] = _abonusContract.getETHNum();                                                         //  快照 eth 数量
            } else {
                _abonusMapping[address(token)] = ERC20(address(token)).balanceOf(address(_nTokenAbonus));                           //  快照 token数量
            }
            _snapshot[token][_times.sub(1)] = true;
        }
    }
    
    /**
    * @dev 批量领取ntoken
    * @param tokenArray 领取token地址数组
    */
    function getMoreNToken(address[] memory tokenArray) public {
        uint256 nowTime = now;
        require(nowTime >= _nextTime.sub(_timeLimit) && nowTime <= _nextTime.sub(_timeLimit).add(_getAbonusTimeLimit), "Not time to draw");
        for (uint256 i = 0; i < tokenArray.length; i++) {
            require(tokenArray[i] != address(0x0), "Token address cannot be 0x0");
            reloadTimeAndMapping(tokenArray[i]);                                                                                    //  时间超过优先结算，结算后分红
            if (_getMapping[_times.sub(1)][tokenArray[i]][address(msg.sender)] != true) {                                           //  上期分红没有领取记录 
                uint256 nestAmount = _nestSave.checkAmount(address(msg.sender));
                if (nestAmount != _nestMapping[_times.sub(1)][address(msg.sender)]) {
                    _nestMapping[_times.sub(1)][address(msg.sender)] = nestAmount;                                                  //  个人锁仓nest快照
                }
                uint256 selfNum = nestAmount.mul(_abonusMapping[tokenArray[i]]).div(_nestAllValue);
                _getMapping[_times.sub(1)][tokenArray[i]][address(msg.sender)] = true;
                _nTokenAbonus.getNToken(selfNum, address(msg.sender), tokenArray[i]);                                               //  转账ntoken
                emit GetTokenLog(tokenArray[i], selfNum);
            }     
        }
    }
    
    /**
    * @dev 平准结算
    */
    function levelingResult() private {
        uint256 thisAbonus = _abonusContract.getETHNum();
        if (thisAbonus > 10000 ether) {
            _abonusContract.getETH(thisAbonus.mul(_savingLevelThree).div(100), address(_nestLeveling));
        } else if (thisAbonus > 1000 ether) {
            _abonusContract.getETH(thisAbonus.mul(_savingLevelTwo).div(100), address(_nestLeveling));
        } else if (thisAbonus > 100 ether) {
            _abonusContract.getETH(thisAbonus.mul(_savingLevelOne).div(100), address(_nestLeveling));
        }
        
        uint256 miningAmount = allValue().div(100000000 ether);
        uint256 minimumAbonus = _expectedMinimum;
        for (uint256 i = 0; i < miningAmount; i++) {
            minimumAbonus = minimumAbonus.add(minimumAbonus.mul(_expectedIncrement).div(100));
        }
        uint256 nowEth = _abonusContract.getETHNum();
        if (nowEth < minimumAbonus) {
            _nestLeveling.tranEth(minimumAbonus.sub(nowEth), address(_abonusContract));
        }
    }
    
     //  下次分红时间，本次分红截止时间，ETH数，nest数, 参与分红的nest, 可领取分红,授权金额，余额，是否可以分红
    function getInfo() public view returns (uint256 nextTime, uint256 getAbonusTime, uint256 ethNum, uint256 nestValue, uint256 myJoinNest, uint256 getEth, uint256 allowNum, uint256 leftNum, bool allowAbonus)  {
        uint256 nowTime = now;
        if (nowTime >= _nextTime.sub(_timeLimit) && nowTime <= _nextTime.sub(_timeLimit).add(_getAbonusTimeLimit)) {
            //  已经触发分红，并且在本次分红的时段内,显示快照数据
            allowAbonus = _getMapping[_times.sub(1)][address(0x0)][address(msg.sender)];
            ethNum = _abonusMapping[address(0x0)];
            nestValue = _nestAllValue;
            
        } else {
            //  1.没人触发分红，nextTime没更新（now > nextTime） 2.超过分红时段.  显示实时数据
            ethNum = _abonusContract.getETHNum();
            nestValue = allValue();
            allowAbonus = _getMapping[_times][address(0x0)][address(msg.sender)];
        }
        myJoinNest = _nestSave.checkAmount(address(msg.sender));
        if (allowAbonus == true) {
            getEth = 0; 
        } else {
            getEth = myJoinNest.mul(ethNum).div(nestValue);
        }
        
        nextTime = getNextTime();
        getAbonusTime = nextTime.sub(_timeLimit).add(_getAbonusTimeLimit);
        allowNum = _nestContract.allowance(address(msg.sender), address(_nestSave));
        leftNum = _nestContract.balanceOf(address(msg.sender));
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
    function allValue() public view returns (uint256) {
        uint256 all = 10000000000 ether;
        uint256 leftNum = all.sub(_nestContract.balanceOf(address(_voteFactory.checkAddress("nest.v3.miningSave")))).sub(_nestContract.balanceOf(address(_destructionAddress)));
        return leftNum;
    }
    
    /**
    * @dev 查看分红周期
    * @return 分红周期
    */
    function checkTimeLimit() public view returns(uint256) {
        return _timeLimit;
    }
    
    /**
    * @dev 查看领取分红周期
    * @return 领取分红周期
    */
    function checkGetAbonusTimeLimit() public view returns(uint256) {
        return _getAbonusTimeLimit;
    }
    
    /**
    * @dev 查看当前最低预期分红
    * @return 当前最低预期分红
    */
    function checkMinimumAbonus() public view returns(uint256) {
        uint256 miningAmount = allValue().div(100000000 ether);
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
    function checkSnapshot(address token) public view returns(bool) {
        return _snapshot[token][_times.sub(1)];
    }
    
    /**
    * @dev 查看预期分红增量比例
    * @return 预期分红增量比例
    */
    function checkeExpectedIncrement() public view returns(uint256) {
        return _expectedIncrement;
    }
    
    /**
    * @dev 查看预期最低分红
    * @return 预期最低分红
    */
    function checkExpectedMinimum() public view returns(uint256) {
        return _expectedMinimum;
    }
    
    /**
    * @dev 查看储蓄阈值
    * @return 储蓄阈值
    */
    function checkSavingLevelOne() public view returns(uint256) {
        return _savingLevelOne;
    }
    function checkSavingLevelTwo() public view returns(uint256) {
        return _savingLevelTwo;
    }
    function checkSavingLevelThree() public view returns(uint256) {
        return _savingLevelThree;
    }
    
    /**
    * @dev 查看nest流通量快照
    * @param times 前置账本数
    */
    function checkAllValueMapping(uint256 times) public view returns(uint256) {
        return _nestAllValueMapping[_times.sub(times)];
    }
    
    /**
    * @dev 查看个人锁仓nest快照
    * @param times 前置账本数
    * @param user 用户地址
    */
    function checkNestMapping(uint256 times, address user) public view returns(uint256) {
        return _nestMapping[_times.sub(times)][user];
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
    * @dev 查看nToken数据
    * @return allNtoken 所有nToken
    * @return myNotken 我的nToken
    * @return get 是否可以领取
    */
    function checkNtokenInfo(address token) public view returns(uint256 allNtoken, uint256 myNotken, bool get) {
        uint256 nowTime = now;
        uint256 myJoinNest = _nestSave.checkAmount(address(msg.sender));
        uint256 nestValue;
        if (nowTime >= _nextTime.sub(_timeLimit) && nowTime <= _nextTime.sub(_timeLimit).add(_getAbonusTimeLimit) && checkSnapshot(token)) {
            nestValue = _nestAllValue;
            allNtoken = _abonusMapping[address(token)];
            get = _getMapping[_times.sub(1)][token][address(msg.sender)];
        } else {
            nestValue = allValue();
            allNtoken = ERC20(address(token)).balanceOf(address(_nTokenAbonus));
            get = true;
        }
        myNotken = allNtoken.mul(myJoinNest).div(nestValue);
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
    
    //  仅限管理员
    modifier onlyOwner(){
        require(_voteFactory.checkOwners(msg.sender) == true, "No authority");
        _;
    }
}

interface Nest_3_NestSave {
    function depositIn(uint256 num, address target) external;
    function checkAmount(address sender) external view returns(uint256);
    function takeOut(uint256 num, address target) external;
}

interface Nest_3_Abonus {
    function getETH(uint256 num, address target) external;
    function getETHNum() external view returns (uint256);
}

interface Nest_3_NTokenAbonus {
    function getNToken(uint256 num, address target, address nToken) external;
}

interface Nest_3_Leveling {
    function tranEth(uint256 amount, address target) external;
}

// 投票工厂
interface Nest_3_VoteFactory {
    //  查看是否有正在参与的投票 
    function checkVoteNow(address user) external view returns(bool);
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