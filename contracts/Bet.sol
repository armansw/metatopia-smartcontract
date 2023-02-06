// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IGame.sol";
import "./TOPIA.sol";
import "./interfaces/IRandomness.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IBet.sol";

import "./libraries/Adminlisted.sol";
import "./libraries/Gamelisted.sol";



contract Bet is
    IBet,
    Pausable,
    ReentrancyGuard,
    Adminlisted,
    Gamelisted
{

    using Address for address;

    event EnteredBet(address indexed game, uint16 indexed tokenId, uint256 indexed amount, uint80 betat, bool betForWorker);
    event OpenedBet(address indexed game);    
    event ClosedBet(address indexed game, bool indexed gameDone);
    event UpdatedPrize(address indexed _game,uint16 indexed _tokenId, address indexed _owner, uint256 _newAmount, bool gameDone);
    event ClaimedPrize(address owner, uint256 amount);
    // game to betRoom
    // each game has only one betroom
    mapping(address=>BetRoom) private rooms;    

    /** Total prizes of token owners */
    mapping(address => uint256) private ownerPrize;

    uint256 public MIN_BET_AMOUNT_PER_TOKEN = 100 ether;
    uint256 public BET_ENTRANCE_FEE = 10 ether;
    uint256 public MIN_BET_CLOSE_DAYS = 2 days;

    IPool private pool;
    TOPIA public topia;

    constructor(address _pool, address _topia){
        pool = IPool(_pool);
        topia = TOPIA(_topia);
    }

    /** Define Modifiers */
    /**
        Only tokens staked on pool
     */
    modifier onlyStakedToken(address _game, uint16 _tokenId) {
        require(pool.isStaked(_game, _tokenId), "No staked on pool.");
        _;
    }
    modifier onlyOwnerOfStakedToken(address _game, uint16 _tokenId) {
        require(pool.getOwnerOfStakedToken(_tokenId, _game) == _msgSender(), "Only owner of token can bet.");
        _;
    }
    modifier noBetAlready(address _game, uint16 _tokenId) {
        require(rooms[_game].betAmount[_tokenId] == 0, "Token is on bet already.");
        _;
    }

    modifier onlyOpenedRoom(address _game) {
        require(rooms[_game].opened, "Closed bet.");
        _;
    }


    function setMIN_BET_AMOUNT_PER_TOKEN(uint256 _amount) public nonReentrant onlyOwner{
        require(_amount > BET_ENTRANCE_FEE, "MIN_BET_AMOUNT_PER_TOKEN must be greater than BET_ENTRANCE_FEE.");
        MIN_BET_AMOUNT_PER_TOKEN = _amount;
    }

    function setBET_ENTRANCE_FEE(uint256 _fee) public nonReentrant onlyOwner {
        require(_fee < MIN_BET_AMOUNT_PER_TOKEN, "Fee must be less than MIN_BET_AMOUNT_PER_TOKEN");
        BET_ENTRANCE_FEE = _fee;
    }

    function setMIN_BET_CLOSE_DAYS(uint80 _days) public nonReentrant onlyOwner {
        MIN_BET_CLOSE_DAYS = _days * 1 days;
    }


    function isOnBet(address _game, uint16 _tokenId) external view override returns (bool){
        return rooms[_game].betAmount[_tokenId] > 0;
    }

    function entranceWorkerStealer(address _game, uint16[] calldata _tokenIds, uint256 _amount) 
        external 
        onlyGamelisted(_game)
        onlyOpenedRoom(_game)
        nonReentrant
    {
        require(_msgSender().isContract() == false, "This must be called by user.");
        require(topia.allowance(_msgSender(), address(this)) >= _amount, "No enough approved amount to spend.");
        uint256 eachAmount = _amount / _tokenIds.length - BET_ENTRANCE_FEE;
        require( eachAmount >= MIN_BET_AMOUNT_PER_TOKEN && topia.balanceOf(_msgSender()) >= _amount, "Insufficient balance to bet.");

        for(uint16 i=0; i<_tokenIds.length; i++){
            entranceToken(_game, _tokenIds[i], eachAmount, false);
        }
        // topia transfer to bet 
        topia.transferFrom(_msgSender(), address(this), _amount);
        
    }

    function entranceSpectator(address _game, uint16 _tokenId, bool _betForWorker, uint256 _amount) 
        external 
        onlyGamelisted(_game)
        onlyOpenedRoom(_game)
        nonReentrant
    {
        require(_msgSender().isContract() == false, "This must be called by user.");
        IGame _gameCont = IGame(_game);
        require(_gameCont.isManager(_tokenId), "Only Manager can bet as spectator.");
        require(topia.allowance(_msgSender(), address(this)) >= _amount, "No enough approved amount to spend.");
        uint256 _betAmount = _amount - BET_ENTRANCE_FEE;
        require( _betAmount >= MIN_BET_AMOUNT_PER_TOKEN && topia.balanceOf(_msgSender()) >= _amount, "Insufficient balance to bet.");

        entranceToken(_game, _tokenId, _betAmount, _betForWorker);
        topia.transferFrom(_msgSender(), address(this), _amount);
    }

    function entranceToken(address _game, uint16 _tokenId, uint256 _amount, bool _betForWorker) 
        internal
        onlyStakedToken(_game, _tokenId)
        noBetAlready(_game, _tokenId)
        onlyOwnerOfStakedToken(_game, _tokenId)
        
    {        
        rooms[_game].betAmount[_tokenId] = _amount - BET_ENTRANCE_FEE;              
        rooms[_game].nftCount += 1;
        rooms[_game].tokenIds[rooms[_game].nftCount-1] = _tokenId;
        
        IGame _gameCont = IGame(_game);
        if (_gameCont.isWorker(_tokenId)) {
            rooms[_game].nrOfWorker += 1;
        } else if (_gameCont.isStealer(_tokenId)) {
            rooms[_game].nrOfStealer += 1;
        }else if (_gameCont.isManager(_tokenId)) {
            rooms[_game].nrOfManager += 1;
            rooms[_game].betForWorker[_tokenId] = _betForWorker;
        }
        
        emit EnteredBet(_game, _tokenId, _amount, uint80(block.timestamp), _betForWorker);
    }

    function openBet(address _game) external onlyGamelisted(_game) onlyAdminlisted nonReentrant {
        require(rooms[_game].opened == true, "Already room opened set.");
        rooms[_game].opened = true;
        rooms[_game].openedAt = uint80(block.timestamp);
        
        emit OpenedBet(_game);        
    } 

    /**
     *  when admin close bet, there are 2 cases.
     ** betroom contains enough worker, stealer
     ** betroom has no worker or stealer
     ** 
     */
    function closeBet(address _game) external nonReentrant onlyAdminlisted onlyOpenedRoom(_game) {
        /**  */
        require((uint80(block.timestamp) - rooms[_game].openedAt) >= MIN_BET_CLOSE_DAYS, "Bet room can be closed after MIN_BET_CLOSE_DAYS at least.");

        if (rooms[_game].nrOfWorker == 0 || rooms[_game].nrOfStealer == 0) {
            // game can't be played, close bet and return topias subtracted by fee to owners 

            for(uint16 i=0; i<rooms[_game].nftCount; i++){
                uint16 _tokenId = rooms[_game].tokenIds[i];
                address _owner = pool.getOwnerOfStakedToken(_tokenId, _game);
                ownerPrize[_owner] = ownerPrize[_owner] + rooms[_game].betAmount[_tokenId];
                emit UpdatedPrize(_game, _tokenId, _owner, ownerPrize[_owner], false);
            }
            delete rooms[_game];
            emit ClosedBet(_game, false);
        } else {
            /**
            * ramoize game result
             */
            
            IGame _gameCont = IGame(_game);
            bool _workerWin = _gameCont.getRandGameResult(uint256(block.timestamp), rooms[_game].nftCount, rooms[_game].nrOfWorker, rooms[_game].nrOfStealer, rooms[_game].nrOfManager );
            uint256 prizeToManagersInRoom;
            uint16[] memory _managerTokenIds = new uint16[](rooms[_game].nrOfManager);
            uint256 _indexOfManager = 0;

            for(uint16 i=0; i<rooms[_game].nftCount; i++){
                uint16 _tokenId = rooms[_game].tokenIds[i];
                address _owner = pool.getOwnerOfStakedToken(_tokenId, _game);

                uint256 _betAmount = rooms[_game].betAmount[_tokenId];
                bool _betForWorker = rooms[_game].betForWorker[_tokenId];

                uint256 _prize = _gameCont.getPrizeAmountForOwner(_tokenId, _betAmount, _betForWorker, _workerWin);
                
                ownerPrize[_owner] = ownerPrize[_owner] + _prize;

                if(_prize > 0 ) {
                    emit UpdatedPrize(_game, _tokenId, _owner, ownerPrize[_owner], true);
                }

                if(_gameCont.isManager(_tokenId)) {
                    _managerTokenIds[_indexOfManager] = _tokenId;
                    _indexOfManager -= 1;
                }
                
                prizeToManagersInRoom += _gameCont.getPrizeAmountToManagers(_tokenId, _betAmount, _workerWin);

            }

            uint256 eachPrizeToManager = prizeToManagersInRoom / rooms[_game].nrOfManager;

            if (eachPrizeToManager > 0) {
                for(uint16 i=0; i<rooms[_game].nrOfManager; i++){
                    address _owner = pool.getOwnerOfStakedToken(_managerTokenIds[i], _game);
                    ownerPrize[_owner] = ownerPrize[_owner] + eachPrizeToManager;
                    emit UpdatedPrize(_game, _managerTokenIds[i], _owner, ownerPrize[_owner], true);
                }
            }
            
            delete rooms[_game];
            emit ClosedBet(_game, true);
        }

    }

    function claimPrizeOfOwner(uint256 _amount) external nonReentrant {
        require(_amount > MIN_BET_AMOUNT_PER_TOKEN, "Amount must be greater than MIN_BET_AMOUNT_PER_TOKEN");
        require(ownerPrize[_msgSender()] >= _amount, "Insufficient prize to claim.");
        require(_msgSender().isContract() == false, "This must be called from owner.");
        require(topia.balanceOf(address(this)) > _amount, "Bet pool does not have enough balance.");

        if(topia.allowance(address(this), _msgSender()) < _amount) {
            topia.approve(_msgSender(), _amount);
        }

        topia.transferFrom(address(this), _msgSender() , _amount);
        ownerPrize[_msgSender()] -= _amount;
        
        emit ClaimedPrize(_msgSender(), _amount);
    }


    

}