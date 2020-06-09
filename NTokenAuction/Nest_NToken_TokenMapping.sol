pragma solidity 0.6.0;

/**
 * @title 报价token映射合约
 * @dev 包含报价token映射的添加修改查询 
 */
contract Nest_NToken_TokenMapping {
    
    mapping (address => address) _tokenMapping;                 //  token映射 报价token => nToken
    Nest_3_VoteFactory _voteFactory;                            //  投票合约
    
    event TokenMappingLog(address token, address nToken);
    
    /**
    * @dev 初始化方法
    * @param voteFactory 投票合约地址
    */
    constructor(address voteFactory) public {
        _voteFactory = Nest_3_VoteFactory(address(voteFactory));
    }
    
    /**
    * @dev 重置投票合约
    * @param voteFactory 投票合约地址
    */
    function changeMapping(address voteFactory) public onlyOwner {
    	_voteFactory = Nest_3_VoteFactory(address(voteFactory));
    }
    
    /**
    * @dev 增加token映射
    * @param token 报价token地址
    * @param nToken 挖矿ntoken地址
    */
    function addTokenMapping(address token, address nToken) public {
        require(address(msg.sender) == address(_voteFactory.checkAddress("nest.nToken.tokenAuction")), "No authority");
        require(_tokenMapping[token] == address(0x0), "Token already exists");
        _tokenMapping[token] = nToken;
        emit TokenMappingLog(token, nToken);
    }
    
    /**
    * @dev 更改token映射
    * @param token 报价token地址
    * @param nToken 挖矿ntoken地址
    */
    function changeTokenMapping(address token, address nToken) public onlyOwner {
        _tokenMapping[token] = nToken;
        emit TokenMappingLog(token, nToken);
    }
    
    /**
    * @dev 查询token映射
    * @param token 报价token地址
    * @return 挖矿ntoken地址
    */
    function checkTokenMapping(address token) public view returns (address) {
        return _tokenMapping[token];
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