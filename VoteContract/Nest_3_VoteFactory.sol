pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";

/**
 * @title 投票工厂+ 映射
 * @dev 创建与投票方法
 */
contract Nest_3_VoteFactory {
    using SafeMath for uint256;
    
    uint256 _limitTime = 7 days;                                    //  投票持续时间
    uint256 _NNLimitTime = 1 days;                                  //  NestNode筹集时间
    uint256 _circulationProportion = 51;                            //  通过票数比例
    uint256 _NNUsedCreate = 10;                                     //  创建投票合约最小 NN 数量
    uint256 _NNCreateLimit = 100;                                   //  开启投票需要筹集 NN 最小数量
    uint256 _emergencyTime = 0;                                     //  紧急状态启动时间
    uint256 _emergencyTimeLimit = 3 days;                           //  紧急状态持续时间
    uint256 _emergencyNNAmount = 1000;                              //  切换紧急状态需要nn数量
    ERC20 _NNToken;                                                 //  守护者节点Token（NestNode）
    ERC20 _nestToken;                                               //  NestToken
    mapping(string => address) _contractAddress;                    //  投票合约映射
    mapping(address => bool) _modifyAuthority;                      //  修改权限
    mapping(address => address) _myVote;                            //  我的投票
    mapping(address => uint256) _emergencyPerson;                   //  紧急状态个人存储量
    mapping(address => bool) _contractData;                         //  投票合约集合
    bool _stateOfEmergency = false;                                 //  紧急状态
    address _destructionAddress;                                    //  销毁合约地址

    event ContractAddress(address contractAddress);
    
    /**
    * @dev 初始化方法
    */
    constructor () public {
        _modifyAuthority[address(msg.sender)] = true;
    }
    
    /**
    * @dev 重置合约
    */
    function changeMapping() public onlyOwner {
        _NNToken = ERC20(checkAddress("nestNode"));
        _destructionAddress = address(checkAddress("nest.v3.destruction"));
        _nestToken = ERC20(address(checkAddress("nest")));
    }
    
    /**
    * @dev 创建投票合约
    * @param implementContract 投票可执行合约地址
    * @param nestNodeAmount 质押 NN 数量
    */
    function createVote(address implementContract, uint256 nestNodeAmount) public {
        require(address(tx.origin) == address(msg.sender), "It can't be a contract");
        require(nestNodeAmount >= _NNUsedCreate);
        Nest_3_VoteContract newContract = new Nest_3_VoteContract(implementContract, _stateOfEmergency, nestNodeAmount);
        require(_NNToken.transferFrom(address(tx.origin), address(newContract), nestNodeAmount), "Authorization transfer failed");
        _contractData[address(newContract)] = true;
        emit ContractAddress(address(newContract));
    }
    
    /**
    * @dev 使用 nest 投票
    * @param contractAddress 投票合约地址
    */
    function nestVote(address contractAddress) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(_contractData[contractAddress], "It's not a voting contract");
        require(!checkVoteNow(address(msg.sender)));
        Nest_3_VoteContract newContract = Nest_3_VoteContract(contractAddress);
        newContract.nestVote();
        _myVote[address(tx.origin)] = contractAddress;
    }
    
    /**
    * @dev 使用 nestNode 投票
    * @param contractAddress 投票合约地址
    * @param NNAmount 质押 NN 数量
    */
    function nestNodeVote(address contractAddress, uint256 NNAmount) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(_contractData[contractAddress], "It's not a voting contract");
        Nest_3_VoteContract newContract = Nest_3_VoteContract(contractAddress);
        require(_NNToken.transferFrom(address(tx.origin), address(newContract), NNAmount), "Authorization transfer failed");
        newContract.nestNodeVote(NNAmount);
    }
    
    /**
    * @dev 执行投票
    * @param contractAddress 投票合约地址
    */
    function startChange(address contractAddress) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(_contractData[contractAddress], "It's not a voting contract");
        Nest_3_VoteContract newContract = Nest_3_VoteContract(contractAddress);
        require(_stateOfEmergency == newContract.checkStateOfEmergency());
        addSuperManPrivate(address(newContract));
        newContract.startChange();
        deleteSuperManPrivate(address(newContract));
    }
    
    /**
    * @dev 切换紧急状态-转入NestNode
    * @param amount 转入 NestNode 数量
    */
    function sendNestNodeForStateOfEmergency(uint256 amount) public {
        require(_NNToken.transferFrom(address(tx.origin), address(this), amount));
        _emergencyPerson[address(tx.origin)] = _emergencyPerson[address(tx.origin)].add(amount);
    }
    
    /**
    * @dev 切换紧急状态-取出NestNode
    */
    function turnOutNestNodeForStateOfEmergency() public {
        require(_emergencyPerson[address(tx.origin)] > 0);
        require(_NNToken.transfer(address(tx.origin), _emergencyPerson[address(tx.origin)]));
        _emergencyPerson[address(tx.origin)] = 0;
        uint256 nestAmount = _nestToken.balanceOf(address(this));
        require(_nestToken.transfer(address(_destructionAddress), nestAmount));
    }
    
    /**
    * @dev 修改紧急状态
    */
    function changeStateOfEmergency() public {
        if (_stateOfEmergency) {
            require(now > _emergencyTime.add(_emergencyTimeLimit));
            _stateOfEmergency = false;
            _emergencyTime = 0;
        } else {
            require(_emergencyPerson[address(msg.sender)] > 0);
            require(_NNToken.balanceOf(address(this)) >= _emergencyNNAmount);
            _stateOfEmergency = true;
            _emergencyTime = now;
        }
    }
    
    /**
    * @dev 查看是否有正在参与的投票 
    * @param user 参与投票地址
    * @return bool 是否正在参与投票
    */
    function checkVoteNow(address user) public view returns (bool) {
        if (_myVote[user] == address(0x0)) {
            return false;
        } else {
            Nest_3_VoteContract vote = Nest_3_VoteContract(_myVote[user]);
            if (vote.checkContractEffective() || vote.checkPersonalAmount(user) == 0) {
                return false;
            }
            return true;
        }
    }
    
    /**
    * @dev 查看我的投票
    * @param user 参与投票地址
    * @return address 最近参与的投票合约地址
    */
    function checkMyVote(address user) public view returns (address) {
        return _myVote[user];
    }
    
    //  查看投票时间
    function checkLimitTime() public view returns (uint256) {
        return _limitTime;
    }
    
    //  查看NestNode筹集时间
    function checkNNLimitTime() public view returns (uint256) {
        return _NNLimitTime;
    }
    
    //  查看通过投票比例
    function checkCirculationProportion() public view returns (uint256) {
        return _circulationProportion;
    }
    
    //  查看创建投票合约最小 NN 数量
    function checkNNUsedCreate() public view returns (uint256) {
        return _NNUsedCreate;
    }
    
    //  查看创建投票筹集 NN 最小数量
    function checkNNCreateLimit() public view returns (uint256) {
        return _NNCreateLimit;
    }
    
    //  查看是否是紧急状态
    function checkStateOfEmergency() public view returns (bool) {
        return _stateOfEmergency;
    }
    
    //  查看紧急状态启动时间 
    function checkEmergencyTime() public view returns (uint256) {
        return _emergencyTime;
    }
    
    //  查看紧急状态持续时间 
    function checkEmergencyTimeLimit() public view returns (uint256) {
        return _emergencyTimeLimit;
    }
    
    //  查看个人 NN 存储量
    function checkEmergencyPerson(address user) public view returns (uint256) {
        return _emergencyPerson[user];
    }
    
    //  查看紧急状态需要 NN 数量
    function checkEmergencyNNAmount() public view returns (uint256) {
        return _emergencyNNAmount;
    }
    
    //  验证投票合约
    function checkContractData(address contractAddress) public view returns (bool) {
        return _contractData[contractAddress];
    }
    
    //  修改投票时间
    function changeLimitTime(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _limitTime = num;
    }
    
    //  修改NestNode筹集时间
    function changeNNLimitTime(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _NNLimitTime = num;
    }
    
    //  修改通过投票比例
    function changeCirculationProportion(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _circulationProportion = num;
    }
    
    //  修改创建投票合约最小 NN 数量
    function changeNNUsedCreate(uint256 num) public onlyOwner {
        _NNUsedCreate = num;
    }
    
    //  修改创建投票筹集 NN 最小数量
    function checkNNCreateLimit(uint256 num) public onlyOwner {
        _NNCreateLimit = num;
    }
    
    //  修改紧急状态持续时间
    function changeEmergencyTimeLimit(uint256 num) public onlyOwner {
        require(num > 0);
        _emergencyTimeLimit = num.mul(1 days);
    }
    
    //  修改紧急状态需要 NN 数量
    function changeEmergencyNNAmount(uint256 num) public onlyOwner {
        require(num > 0);
        _emergencyNNAmount = num;
    }
    
    //  查询地址
    function checkAddress(string memory name) public view returns (address contractAddress) {
        return _contractAddress[name];
    }
    
    //  添加合约映射地址
    function addContractAddress(string memory name, address contractAddress) public onlyOwner {
        _contractAddress[name] = contractAddress;
    }
    
    //  增加管理地址
    function addSuperMan(address superMan) public onlyOwner {
        _modifyAuthority[superMan] = true;
    }
    function addSuperManPrivate(address superMan) private {
        _modifyAuthority[superMan] = true;
    }
    
    //  删除管理地址
    function deleteSuperMan(address superMan) public onlyOwner {
        _modifyAuthority[superMan] = false;
    }
    function deleteSuperManPrivate(address superMan) private {
        _modifyAuthority[superMan] = false;
    }
    
    //  删除投票合约集合
    function deleteContractData(address contractAddress) public onlyOwner {
        _contractData[contractAddress] = false;
    }
    
    //  查看是否管理员
    function checkOwners(address man) public view returns (bool) {
        return _modifyAuthority[man];
    }
    
    //  仅限管理员操作
    modifier onlyOwner() {
        require(checkOwners(msg.sender), "No authority");
        _;
    }
}

/**
 * @title 投票合约
 */
contract Nest_3_VoteContract {
    using SafeMath for uint256;
    
    Nest_3_Implement _implementContract;                //  可执行合约
    Nest_3_TokenSave _tokenSave;                        //  锁仓合约 
    Nest_3_VoteFactory _voteFactory;                    //  投票工厂合约
    Nest_3_TokenAbonus _tokenAbonus;                    //  分红逻辑合约
    ERC20 _nestToken;                                   //  NestToken
    ERC20 _NNToken;                                     //  守护者节点
    address _miningSave;                                //  矿池合约
    address _implementAddress;                          //  执行地址
    address _destructionAddress;                        //  销毁合约地址
    uint256 _createTime;                                //  创建时间
    uint256 _endTime;                                   //  结束时间
    uint256 _totalAmount;                               //  总投票数
    uint256 _circulation;                               //  通过票数
    uint256 _destroyedNest;                             //  已销毁 NEST
    uint256 _NNLimitTime;                               //  NestNode筹集时间
    uint256 _NNCreateLimit;                             //  创建投票筹集 NN最小数量
    uint256 _abonusTimes;                               //  紧急状态使用的快照期数
    uint256 _allNNAmount;                               //  NN总数
    bool _effective = false;                            //  是否生效
    bool _nestVote = false;                             //  是否可进行 NEST 投票
    bool _isChange = false;                             //  是否已执行
    bool _stateOfEmergency;                             //  是否为紧急状态
    mapping(address => uint256) _personalAmount;        //  个人投票数
    mapping(address => uint256) _personalNNAmount;      //  NN个人投票数
    
    /**
    * @dev 初始化方法
    * @param contractAddress 可执行合约地址
    * @param stateOfEmergency 是否为紧急状态 
    * @param NNAmount NN数量
    */
    constructor (address contractAddress, bool stateOfEmergency, uint256 NNAmount) public {
        Nest_3_VoteFactory voteFactory = Nest_3_VoteFactory(address(msg.sender));
        _voteFactory = voteFactory;
        _nestToken = ERC20(voteFactory.checkAddress("nest"));
        _NNToken = ERC20(voteFactory.checkAddress("nestNode"));
        _implementContract = Nest_3_Implement(address(contractAddress));
        _implementAddress = address(contractAddress);
        _destructionAddress = address(voteFactory.checkAddress("nest.v3.destruction"));
        _personalNNAmount[address(tx.origin)] = NNAmount;
        _allNNAmount = NNAmount;
        _createTime = now;                                    
        _endTime = _createTime.add(voteFactory.checkLimitTime());
        _NNLimitTime = voteFactory.checkNNLimitTime();
        _NNCreateLimit = voteFactory.checkNNCreateLimit();
        _stateOfEmergency = stateOfEmergency;
        if (stateOfEmergency) {
            //  紧急状态读取前两期分红锁仓及总流通量数据
            _tokenAbonus = Nest_3_TokenAbonus(voteFactory.checkAddress("nest.v3.tokenAbonus"));
            _abonusTimes = _tokenAbonus.checkTimes().sub(2);
            require(_abonusTimes > 0);
            _circulation = _tokenAbonus.checkTokenAllValueHistory(address(_nestToken),_abonusTimes).mul(voteFactory.checkCirculationProportion()).div(100);
        } else {
            _miningSave = address(voteFactory.checkAddress("nest.v3.miningSave"));
            _tokenSave = Nest_3_TokenSave(voteFactory.checkAddress("nest.v3.tokenSave"));
            _circulation = (uint256(10000000000 ether).sub(_nestToken.balanceOf(address(_miningSave))).sub(_nestToken.balanceOf(address(_destructionAddress)))).mul(voteFactory.checkCirculationProportion()).div(100);
        }
        if (_allNNAmount >= _NNCreateLimit) {
            _nestVote = true;
        }
    }
    
    /**
    * @dev NEST投票
    */
    function nestVote() public onlyFactory {
        require(now <= _endTime, "Voting time exceeded");
        require(!_effective, "Vote in force");
        require(_nestVote);
        require(_personalAmount[address(tx.origin)] == 0, "Have voted");
        uint256 amount;
        if (_stateOfEmergency) {
            //  紧急状态读取前两期分红锁仓
            amount = _tokenAbonus.checkTokenSelfHistory(address(_nestToken),_abonusTimes, address(tx.origin));
        } else {
            amount = _tokenSave.checkAmount(address(tx.origin), address(_nestToken));
        }
        _personalAmount[address(tx.origin)] = amount;
        _totalAmount = _totalAmount.add(amount);
        ifEffective();
    }
    
    /**
    * @dev NEST取消投票
    */
    function nestVoteCancel() public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(now <= _endTime, "Voting time exceeded");
        require(!_effective, "Vote in force");
        require(_personalAmount[address(tx.origin)] > 0, "No vote");                     
        _totalAmount = _totalAmount.sub(_personalAmount[address(tx.origin)]);
        _personalAmount[address(tx.origin)] = 0;
    }
    
    /**
    * @dev  NestNode投票
    * @param NNAmount NN数量
    */
    function nestNodeVote(uint256 NNAmount) public onlyFactory {
        require(now <= _createTime.add(_NNLimitTime), "Voting time exceeded");
        require(!_nestVote);
        _personalNNAmount[address(tx.origin)] = _personalNNAmount[address(tx.origin)].add(NNAmount);
        _allNNAmount = _allNNAmount.add(NNAmount);
        if (_allNNAmount >= _NNCreateLimit) {
            _nestVote = true;
        }
    }
    
    /**
    * @dev 取出抵押 NN
    */
    function turnOutNestNode() public {
        if (_nestVote) {
            //  正常 NEST 投票
            if (!_stateOfEmergency || !_effective) {
                //  非紧急状态
                require(now > _endTime, "Vote unenforceable");
            }
        } else {
            //  NN 投票
            require(now > _createTime.add(_NNLimitTime));
        }
        require(_personalNNAmount[address(tx.origin)] > 0);
        //  转回 NN
        require(_NNToken.transfer(address(tx.origin), _personalNNAmount[address(tx.origin)]));
        _personalNNAmount[address(tx.origin)] = 0;
        //  销毁 NEST
        uint256 nestAmount = _nestToken.balanceOf(address(this));
        _destroyedNest = _destroyedNest.add(nestAmount);
        require(_nestToken.transfer(address(_destructionAddress), nestAmount));
    }
    
    /**
    * @dev 执行修改合约
    */
    function startChange() public onlyFactory {
        require(!_isChange);
        _isChange = true;
        if (_stateOfEmergency) {
            require(_effective, "Vote unenforceable");
        } else {
            require(_effective && now > _endTime, "Vote unenforceable");
        }
        //  将执行合约加入管理集合
        _voteFactory.addSuperMan(address(_implementContract));
        //  执行
        _implementContract.doit();
        //  将执行合约删除
        _voteFactory.deleteSuperMan(address(_implementContract));
    }
    
    /**
    * @dev 判断是否生效
    */
    function ifEffective() private {
        if (_totalAmount >= _circulation) {
            _effective = true;
        }
    }
    
    /**
    * @dev 查看投票合约是否结束
    */
    function checkContractEffective() public view returns (bool) {
        if (_effective || now > _endTime) {
            return true;
        } 
        return false;
    }
    
    //  查看执行合约地址 
    function checkImplementAddress() public view returns (address) {
        return _implementAddress;
    }
    
    //  查看投票开始时间
    function checkCreateTime() public view returns (uint256) {
        return _createTime;
    }
    
    //  查看投票结束时间
    function checkEndTime() public view returns (uint256) {
        return _endTime;
    }
    
    //  查看当前总投票数
    function checkTotalAmount() public view returns (uint256) {
        return _totalAmount;
    }
    
    //  查看通过投票数
    function checkCirculation() public view returns (uint256) {
        return _circulation;
    }
    
    //  查看个人投票数
    function checkPersonalAmount(address user) public view returns (uint256) {
        return _personalAmount[user];
    }
    
    //  查看已经销毁 NEST
    function checkDestroyedNest() public view returns (uint256) {
        return _destroyedNest;
    }
    
    //  查看合约是否生效
    function checkEffective() public view returns (bool) {
        return _effective;
    }
    
    //  查看是否是紧急状态 
    function checkStateOfEmergency() public view returns (bool) {
        return _stateOfEmergency;
    }
    
    //  查看 NestNode 筹集时间
    function checkNNLimitTime() public view returns (uint256) {
        return _NNLimitTime;
    }
    
    //  查看创建投票筹集 NN 最小数量
    function checkNNCreateLimit() public view returns (uint256) {
        return _NNCreateLimit;
    }
    
    //  查看紧急状态使用的快照期数
    function checkAbonusTimes() public view returns (uint256) {
        return _abonusTimes;
    }
    
    //  查看 NN 个人投票数
    function checkPersonalNNAmount(address user) public view returns (uint256) {
        return _personalNNAmount[address(user)];
    }
    
    //  查看 NN 总数
    function checkAllNNAmount() public view returns (uint256) {
        return _allNNAmount;
    }
    
    //  查看是否可进行 NEST 投票
    function checkNestVote() public view returns (bool) {
        return _nestVote;
    }
    
    //  查看是否已执行
    function checkIsChange() public view returns (bool) {
        return _isChange;
    }
    
    //  仅限工厂合约
    modifier onlyFactory() {
        require(address(_voteFactory) == address(msg.sender), "No authority");
        _;
    }
}

//  执行合约
interface Nest_3_Implement {
    //  执行
    function doit() external;
}

//  NEST锁仓合约
interface Nest_3_TokenSave {
    //  查看锁仓金额
    function checkAmount(address sender, address token) external view returns (uint256);
}

//  分红逻辑合约
interface Nest_3_TokenAbonus {
    //  查看 NEST 流通量快照
    function checkTokenAllValueHistory(address token, uint256 times) external view returns (uint256);
    //  查看 NEST 流通量快照
    function checkTokenSelfHistory(address token, uint256 times, address user) external view returns (uint256);
    //  查看分红账本期数
    function checkTimes() external view returns (uint256);
}

//  ERC20合约
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
