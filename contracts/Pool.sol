// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IGame.sol";
import "./TOPIA.sol";
import "./interfaces/IRandomness.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IBet.sol";


contract Pool is
    IPool,
    Ownable,
    IERC721Receiver,
    Pausable,
    ReentrancyGuard
{
    // owner address to gameAddress to index to tokenID
    mapping(address =>mapping(address=>mapping(uint16 => uint16))) private _stakedTokensOfOwner;
    // owner address to game address to number of staked tokens
    mapping(address => mapping(address=>uint16)) private _nrOfStakedTokensOfOwner;
    /** game address to tokenId to owner account */
    mapping(address => mapping(uint16 => address)) private ownerOfToken;


    // struct to store a stake's token, owner, and earning values
    struct Stake {
        // uint16 tokenId;
        uint80 value; // same with last claim timestamp
        address owner;
        
    }

    event TokenStaked(address indexed owner, uint16 indexed tokenId, uint256 value, address indexed _game);

    event WorkerClaimed(uint16 indexed tokenId, uint256 earned, bool indexed unstaked, address indexed _game);
    event StealerClaimed(uint256 indexed tokenId, uint256  earned, bool indexed unstaked, address indexed _game);
    event ManagerClaimed(uint256 indexed tokenId, uint256  earned, bool indexed unstaked, address indexed _game);
    event AlphaClaimed(uint256 indexed tokenId, uint256  earned, bool indexed unstaked, address indexed _game);

    // reference to the Stealer NFT contract
    // Bull public bull;
    // reference to the $TOPIA contract for minting $TOPIA earnings
    TOPIA public topia;

    IRandomness randomness;

    IBet bet;
    // maps game address to  tokenId to stake
    mapping(address=>mapping(uint256 => Stake)) public pool;
    // maps alpha to all Stealer stakes with that alpha
    
    // amount of $TOPIA earned so far
    uint256 public totalClaimedTopia;
    

    // emergency rescue to allow unstaking without any checks but without $TOPIA
    // bool public rescueEnabled = false;

    /**
     * @param  _topia reference to the $TOPIA token
     * @param _randomenss reference to the randomness contract
     */
    constructor(
        address _topia,
        address _randomenss        
    )  {
        topia = TOPIA(_topia);
        randomness = IRandomness(_randomenss);

    }

    function setBet(address _bet) external onlyOwner {
        bet = IBet(_bet);
    }

    function setRandomness(address _randomness) external onlyOwner {
        randomness = IRandomness(_randomness);
    }

    function setTopia(address _topia) external onlyOwner{
        topia = TOPIA(_topia);
    }
  
    function getNrOfStakedTokenIds(address account, address _game)external view returns(uint16){
        return _nrOfStakedTokensOfOwner[account][_game];
    }

    function getStakedTokenIdOfOwner(address account,uint16 index, address _game)external view returns (uint16) {
        return _stakedTokensOfOwner[account][_game][index];
    }

    /** get owner address of staked token at pool */
    function getOwnerOfStakedToken( uint16 _tokenId, address _game) external view override returns (address) {
        return ownerOfToken[_game][_tokenId];
    }

    /** STAKING */

    /**
     * adds Worker and Stealers to the Pool and Pack
     * @param account the address of the staker
     * @param tokenIds the IDs of the Worker and Stealers to stake
     */
    function addManyToPool(address account, uint16[] calldata tokenIds, address _game)
        external
        override
    {
        require(
            account == _msgSender() || _msgSender() == _game,
            "DONT GIVE YOUR TOKENS AWAY"
        );
        IERC721 gameERC721 = IERC721(_game);

        for (uint256 i = 0; i < tokenIds.length; i++) {

            if (_msgSender() != _game) {
                // dont do this step if its a mint + stake
                require(
                    gameERC721.ownerOf(tokenIds[i]) == _msgSender(),
                    "AINT YO TOKEN"
                );
                
            } else if (tokenIds[i] == 0) {
                continue; // there may be gaps in the array for stolen tokens
            }

            gameERC721.transferFrom(_msgSender(), address(this), tokenIds[i]);
            ownerOfToken[_game][tokenIds[i]] = account;
            _addNFTToPool(account, tokenIds[i], _game);
        }
    }



    /**
     * adds a single Worker to the Pool
     * @param account the address of the staker
     * @param tokenId the ID of the Worker to add to the Pool
     */
    function _addNFTToPool(address account, uint16 tokenId, address _game)
        internal
        whenNotPaused
        nonReentrant
    {
        pool[_game][tokenId] = Stake({
            owner: account,
            // tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        });
        
        _stakedTokensOfOwner[account][_game][_nrOfStakedTokensOfOwner[account][_game]] = tokenId;
        _nrOfStakedTokensOfOwner[account][_game] += 1;

        IGame _gameCont = IGame(_game);

        _gameCont.addStakedToken(tokenId);
        
        emit TokenStaked(account, tokenId, block.timestamp, _game);
    }

    function isStaked(address _game, uint16 _tokenId) external view override returns(bool){

        return pool[_game][_tokenId].value > 0;
    }


    /** CLAIMING / UNSTAKING */

    /**
     * realize $TOPIA earnings and optionally unstake tokens from the Pool / Pack
     * to unstake a Worker it will require it has 2 days worth of $TOPIA unclaimed
     * @param tokenIds the IDs of the tokens to claim earnings from
     * @param unstake whether or not to unstake ALL of the tokens listed in tokenIds
     */
    function claimManyFromPool(uint16[] calldata tokenIds, bool unstake, address _game)
        external
        whenNotPaused
        nonReentrant
    {
        uint80 MIN_STAKE_EXIT_DAYS = IGame(_game).getMIN_STAKE_EXIT_DAYS();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            Stake storage stake = pool[_game][tokenIds[i]];
            require(stake.value > 0 , "Token is not staked on pool.");
            require(
                (block.timestamp - stake.value >= MIN_STAKE_EXIT_DAYS),
                "GONNA BE CLAIM WITHOUT TWO DAY'S TOPIA");         
            require(unstake && bet.isOnBet(_game, tokenIds[i]) == false, "Bet token can't be unstake");
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            claimTokenFromPool(_msgSender(), tokenIds[i], _game, unstake);
        }       
    }

    function claimTokenFromPool(address account, uint16 _tokenId, address _game, bool unstake) internal {

        IGame game = IGame(_game);

        Stake storage stake = pool[_game][_tokenId];

        uint16 _harvestRisk = game.getHarvestRiskRateForTokenId(_tokenId);        
        uint256 _seed = _tokenId + _harvestRisk;
        uint256 _random = randomness.getRandom(_seed);

        bool stolenHarvest = false;
        if (_harvestRisk > 0) {
            stolenHarvest = (_random % _harvestRisk) < (_harvestRisk * _harvestRisk / 10000);
        }

        uint256 _claimedAmount = game.getAvailableClaimAmount(_tokenId, stake.value, uint80(block.timestamp));
        uint256 _realClaimedAmount = _claimedAmount;
        if (stolenHarvest && _claimedAmount > 0) {
            game.distributeHarvestRewards(_claimedAmount, _tokenId);
            _realClaimedAmount = game.getClaimAmountBesideHarvestTax(_claimedAmount, _tokenId);
        }

        _realClaimedAmount += game.getHarvestRewardsAmount(_tokenId);
        
        if(_realClaimedAmount > 0 ) {

            topia.mint(account, _realClaimedAmount);
            totalClaimedTopia += _realClaimedAmount;
            stake.value = uint80(block.timestamp);
            
            game.cleanHarvestRewards(_tokenId);

            if (game.isWorker(_tokenId)) {
                emit WorkerClaimed( _tokenId, _realClaimedAmount, unstake, _game);
            } else if (game.isStealer(_tokenId)) {
                emit StealerClaimed( _tokenId, _realClaimedAmount, unstake, _game);
            } else if (game.isManager(_tokenId)) {
                emit ManagerClaimed( _tokenId, _realClaimedAmount, unstake, _game);
            } else if (game.isAlpha(_tokenId)) {
                emit AlphaClaimed( _tokenId, _realClaimedAmount, unstake, _game);
            }
            
        }

        if (unstake) {
            uint16 _unstakeRisk = game.getUnstakeRiskRateForTokenId(_tokenId);
            if (_unstakeRisk > 0) {
                _seed = _tokenId + _unstakeRisk;
                _random = randomness.getRandom(_seed);
                uint256 rate = _random % _unstakeRisk;
                
                if (rate < _unstakeRisk * _unstakeRisk / 10000 ) {
                    // burn
                    /** token is tramppled */
                    game.burn(_tokenId);
                    removeFromStakedTokenOfOwner(account, _tokenId, _game);
                } else {
                    // return
                    returnTokenToSender(account, _tokenId, _game);
                }

            } else {
                returnTokenToSender(account, _tokenId, _game);
            }

            game.removeStakedToken(_tokenId);
            delete pool[_game][_tokenId];            
        }

    }

    function returnTokenToSender(address account,  uint16 _tokenId, address _game)  internal {
        IERC721 gameERC721 = IERC721(_game);

        gameERC721.safeTransferFrom(
            address(this),
            account,
            _tokenId,
            ""
        ); 
        
        removeFromStakedTokenOfOwner(account, _tokenId, _game);
    }

    function removeFromStakedTokenOfOwner(address account,uint16 tokenId, address _game)internal{
        delete ownerOfToken[_game][tokenId];

        uint16 _count = 0;
        for(uint16 i = 0; i < _nrOfStakedTokensOfOwner[account][_game]; i++) {
            if(tokenId == _stakedTokensOfOwner[account][_game][i]){
                delete _stakedTokensOfOwner[account][_game][i];
                _count += 1;
                break;
            }
        }
        _nrOfStakedTokensOfOwner[account][_game] -= _count;
    }

    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    /** READ ONLY */


    
    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send tokens to Pool directly");
        return IERC721Receiver.onERC721Received.selector;
    }

}
