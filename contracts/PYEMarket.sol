// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import 'hardhat/console.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import "./libraries/Whitelisted.sol";
import "./interfaces/IGame.sol";
import "./interfaces/IPool.sol";
import "./TOPIA.sol";
import "./interfaces/IRandomness.sol";
import "./interfaces/IBet.sol";

contract PYEMarket is IGame, ERC721Enumerable, Ownable, Pausable, Whitelisted {
    // mint price
    using Strings for uint256;

    uint256 public MINT_PRICE = .05 ether;
    bool public MINT_IN_TOPIA = false;
    // max number of tokens that can be minted - 50000 in production
    uint16 public MAX_TOKENS;
    
    // number of tokens have been minted so far
    uint16 public minted; 

    string public GAME_NAME="RunnerBull";

    uint80 public MIN_STAKE_EXIT_DAYS = 2 days;

    mapping(uint256=>uint16) public ids;
    uint256 private idsLength;

    mapping(uint256=>RunnerBull) private mintedTraits;
    // length of mintedTraits
    uint256 public uploadedTraitsLen;

    string public _contractURI;

    uint8 public MAX_MINT=10;
    uint8 public MIN_MINT=1;
    uint8 constant MAX_MINT_LIMIT=10;

    IRandomness private randomness;

    // nfttype index based on 1 to claim topia amount
    mapping(uint8=>uint256) public claimAmount;
    // nfttype index to rate percent, 100% = 100
    mapping(uint8=>uint16) public unstakeRiskRate;

    // number of workers in total minted
    uint16 public mintedWorkers;
    uint16 public mintedStealers;
    uint16 public mintedManagers;
    uint16 public mintedAlphas;

    // number of stolean workers in total minted
    uint16 public stolenWorkers;
    
    // number of stolean topias in total minted
    uint16 public stolenTopias;
    
    // reference to the Pool for choosing random stealer thieves
    IPool public pool;
    // reference to $TOPIA for burning on mint
    TOPIA public topia;

    // nfttypeindex to rate : 100% = 10000
    mapping(uint8=>uint16) public harvestRiskRate;
    mapping(uint8=>uint16) public harvestRiskDistributeRate;

        // index to tokenId
    mapping(uint16=>uint16) private stakedWorkers;
    mapping(uint16=>uint16) private stakedStealers;
    mapping(uint16=>uint16) private stakedManagers;
    mapping(uint16=>uint16) private stakedAlphas;
    uint16 public totalStakedWorkers;
    uint16 public totalStakedStealers;
    uint16 public totalStakedManagers;
    uint16 public totalStakedAlphas;

  // tokenId to harvest rewarded amount
    mapping(uint16=>uint256) private harvestRewards;

    struct PYEPrize {
        uint16 chance;
        uint256 topiaAmount;
    }

    PYEPrize private GoldenPYE;
    PYEPrize private FilledPYE;
    PYEPrize private DudPYE;
    
    
        
    struct PurchasePYE {
        uint80 lastStamp; // same with last claim timestamp
        uint8 purchasedCount; 
    }

    // tokenId to purchasePYE
    mapping(uint256=>PurchasePYE) private purchasedPYE;

    // nftTypeindex to Count
    mapping(uint8=>uint16) private limitPurchaseCountDaily;

    bool public revealed = false;

    string public hiddenMetadataUri;
    string private uriPrefix;
    string private uriSuffix = ".json";


    event UpdatedMaxMint(uint8 indexed _maxMint, address indexed member);
    event UpdatedMinMint(uint8 indexed _maxMint, address indexed member);
    event UpdatedMintPrice(uint256 indexed _mint_price, bool indexed _mint_in_topia, address indexed member);
    

    event PurchasedPYE(uint256 indexed _tokenId, uint256 indexed _prize, string indexed _label);


    /**
     * instantiates contract and rarity tables
     */
    constructor(
        address _topia,
        uint16 _maxTokens,
        address _randomness,
        string memory _gameName
    ) ERC721("MetaTopia Game", "MetaTopia")  {

        randomness = IRandomness(_randomness);
        topia = TOPIA(_topia);
        MAX_TOKENS = _maxTokens;  // normal 50000
        idsLength = _maxTokens;

        // Baker
        claimAmount[1] = 20 ether;
        // Foodie
        claimAmount[2] = 0 ether;
        // ShopOwner
        claimAmount[3] = 0 ether;
        //Alpha
        claimAmount[4] = 35 ether;

        unstakeRiskRate[1] = 1000;// Baker
        unstakeRiskRate[2] = 0; // Foodie
        unstakeRiskRate[3] = 0; // ShopOwner
        unstakeRiskRate[4] = 0; // Alpha

         // 100% = 10000
        harvestRiskRate[1] = 10000;// Baker
        harvestRiskRate[2] = 0; // Foodie
        harvestRiskRate[3] = 0; // ShopOwner
        harvestRiskRate[4] = 0; // Alpha

        harvestRiskDistributeRate[1] = 9000;// Baker   100% = 10000
        harvestRiskDistributeRate[2] = 666; // Foodie
        harvestRiskDistributeRate[3] = 333; // ShopOwner
        harvestRiskDistributeRate[4] = 0; // Alpha 
        // Total harvest rate : 10000 = 100%]
        
        limitPurchaseCountDaily[1] = 0;// Baker  
        limitPurchaseCountDaily[2] = 15; // Foodie
        limitPurchaseCountDaily[3] = 30; // ShopOwner
        limitPurchaseCountDaily[4] = 0; // Alpha 
        

        GoldenPYE.chance = 500;
        GoldenPYE.topiaAmount = 300 ether;

        FilledPYE.chance = 2500;
        FilledPYE.topiaAmount = 100 ether;
        
        DudPYE.chance = 7000;
        DudPYE.topiaAmount = 0 ether;


        GAME_NAME = _gameName;

    }

    /** EXTERNAL */

    function getMIN_STAKE_EXIT_DAYS() external view override returns (uint80){
        return MIN_STAKE_EXIT_DAYS;
    }

    function setMIN_STAKE_EXIT_DAYS(uint80 _days) public onlyOwner{
        MIN_STAKE_EXIT_DAYS = _days * 1 days;
    }

    function setGameName(string memory name) external onlyOwner {
        GAME_NAME = name;
    }

    function setTopia(address _topia) external onlyOwner {
        topia = TOPIA(_topia);
    }

    function setRandom(address _randomness) external onlyOwner {
        randomness = IRandomness(_randomness);
    }

    function setClaimAmount(uint8 nftTypeIndex, uint256 amount) public onlyOwner {
        claimAmount[nftTypeIndex] = amount;
    }

    function setRiskRate(uint8 nftTypeIndex, uint16 rate) public onlyOwner {
        unstakeRiskRate[nftTypeIndex] = rate;
    }

    function setHarvestRiskRate(uint8 nftTypeIndex, uint16 rate) public onlyOwner {
        harvestRiskRate[nftTypeIndex] = rate;
    }
    function setHarvestRiskDistributeRate(uint8 nftTypeIndex, uint16 rate) public onlyOwner {
        harvestRiskDistributeRate[nftTypeIndex] = rate;
    }


    function setMAX_MINT(uint8 _max_mint) external onlyWhitelisted{
        require(_max_mint <= MAX_MINT_LIMIT, "MAX MINT must be less than or equal to 10.");
        require(_max_mint >= MIN_MINT, "MAX MINT must be greater than or equal to MIN MINT.");
        require(_max_mint > 0, "MAX MINT must be greater than ZERO.");
        require(_max_mint < MAX_TOKENS / 5, "MAX MINT must be less than PAID TOKENS.");

        MAX_MINT = _max_mint;
        emit UpdatedMaxMint(MAX_MINT, _msgSender());
    
    }

    function setMIN_MINT(uint8 _min_mint) external onlyWhitelisted {
        require(_min_mint <= MAX_MINT, "MIN MINT must be less than or equal to MAX MINT.");
        require(_min_mint > 0, "MIN MINT must be greater than ZERO.");
        require(_min_mint < MAX_TOKENS / 5, "MIN MINT must be less than PAID TOKENS.");

        MIN_MINT = _min_mint;
        
        emit UpdatedMinMint(MIN_MINT, _msgSender());        
    }

    function setMintPrice(uint256 _mint_price, bool _mint_in_topia) external onlyOwner {
        
        require(_mint_price > 0, "MINT price must be greater than zero.");
        MINT_PRICE = _mint_price;
        MINT_IN_TOPIA = _mint_in_topia;

        emit UpdatedMintPrice(MINT_PRICE, MINT_IN_TOPIA, _msgSender());
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri)
        public
        onlyOwner
    {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }


    function getTotalStakedTokensFor(DataTypes.NFTType _nftType) external view override returns (uint16 _total) {
        if (DataTypes.NFTType.WORKER == _nftType) {
            _total = totalStakedWorkers;            
        }else if (DataTypes.NFTType.STEALER == _nftType) {
            _total =  totalStakedStealers;
            
        }else if (DataTypes.NFTType.MANAGER == _nftType) {
            _total =  totalStakedManagers;
            
        }else if (DataTypes.NFTType.ALPHA == _nftType) {
            _total =  totalStakedAlphas;
        } else {
            require(false, "Invalid nft type for get total staked tokens.");
        }
    }

    function getTotalStakedTokens() external view override returns (uint16 _total) {

        _total = totalStakedWorkers + totalStakedStealers + totalStakedManagers + totalStakedAlphas;
       
    }

    function getStakedTokenAtIndex(uint16 _index, DataTypes.NFTType _nftType) external view override returns (uint16 _tokenId) {
        
        if (DataTypes.NFTType.WORKER == _nftType) {
            require(_index <= totalStakedWorkers && _index > 0, "Invalid index for staked worker" );
            _tokenId = stakedWorkers[_index];
        }else if (DataTypes.NFTType.STEALER == _nftType) {
            require(_index <= totalStakedWorkers && _index > 0, "Invalid index for staked stealer" );
            _tokenId = stakedStealers[_index];
        }else if (DataTypes.NFTType.MANAGER == _nftType) {
            require(_index <= totalStakedWorkers && _index > 0, "Invalid index for staked manager" );
            _tokenId = stakedManagers[_index];            
        }else if (DataTypes.NFTType.ALPHA == _nftType) {
            require(_index <= totalStakedWorkers && _index > 0, "Invalid index for staked alpha" );
            _tokenId = stakedAlphas[_index];
        } else {
            require(false, "Invalid nft type for tokenId");
        }
    }


    function addStakedToken(uint16 _tokenId) external override  {
        
        DataTypes.NFTType _nftType = mintedTraits[_tokenId].nftType;

        if (DataTypes.NFTType.WORKER == _nftType) {
            totalStakedWorkers += 1;
            stakedWorkers[totalStakedWorkers] = _tokenId;
        }else if (DataTypes.NFTType.STEALER == _nftType) {
            totalStakedStealers += 1;
            stakedStealers[totalStakedStealers] = _tokenId;
        }else if (DataTypes.NFTType.MANAGER == _nftType) {
            totalStakedManagers += 1;
            stakedManagers[totalStakedManagers] = _tokenId;
        }else if (DataTypes.NFTType.ALPHA == _nftType) {
            totalStakedAlphas += 1;
            stakedAlphas[totalStakedAlphas] = _tokenId;
        } else {
            require(false, "Invalid nft type for tokenId");
        }
    }

  

    function removeStakedToken(uint16 _tokenId) external override  {            
            
        DataTypes.NFTType _nftType = mintedTraits[_tokenId].nftType;

        if (DataTypes.NFTType.WORKER == _nftType) {
            require(totalStakedWorkers > 0, "Empty staked workers");

            for (uint16 i = 1; i<=totalStakedWorkers; i++) {
                if (stakedWorkers[i] == _tokenId) {
                    if (i != totalStakedWorkers) {
                        stakedWorkers[i] = stakedWorkers[totalStakedWorkers];
                    }
                    delete stakedWorkers[totalStakedWorkers];
                    totalStakedWorkers -= 1;
                    break;
                }
            }
            
        }else if (DataTypes.NFTType.STEALER == _nftType) {
            require(totalStakedStealers > 0, "Empty staked workers");

            for (uint16 i = 1; i<=totalStakedStealers; i++) {
                if (stakedStealers[i] == _tokenId) {
                    if (i != totalStakedStealers) {
                        stakedStealers[i] = stakedStealers[totalStakedStealers];
                    }
                    delete stakedStealers[totalStakedStealers];
                    totalStakedStealers -= 1;
                    break;
                }
            }
      
        }else if (DataTypes.NFTType.MANAGER == _nftType) {
            require(totalStakedManagers > 0, "Empty staked workers");

            for (uint16 i = 1; i<=totalStakedManagers; i++) {
                if (stakedManagers[i] == _tokenId) {
                    if (i != totalStakedManagers) {
                        stakedManagers[i] = stakedManagers[totalStakedManagers];
                    }
                    delete stakedManagers[totalStakedManagers];
                    totalStakedManagers -= 1;
                    break;
                }
            }

        }else if (DataTypes.NFTType.ALPHA == _nftType) {
        
            require(totalStakedAlphas > 0, "Empty staked workers");

            for (uint16 i = 1; i<=totalStakedAlphas; i++) {
                if (stakedAlphas[i] == _tokenId) {
                    if (i != totalStakedAlphas) {
                        stakedAlphas[i] = stakedAlphas[totalStakedAlphas];
                    }
                    delete stakedAlphas[totalStakedAlphas];
                    totalStakedAlphas -= 1;
                    break;
                }
            }


        } else {
            require(false, "Invalid nft type for tokenId");
        }
    }


    modifier validNFTTypeIndex(uint8 _nftType) {
        require(_nftType >= 1 && _nftType <= 3, "Invalid nft type");
        _;
    }
    
    modifier mintReady() {
        require(uploadedTraitsLen >= MAX_TOKENS, "Mint is not available yet.");
        require(bytes(_baseURI()).length > 0, "Mint data is not available yet.");
        
        _;
    }

    modifier onlyPool() {
        require(_msgSender() == address(pool), "Only pool can access this function.");
        _;
    }
    

    function getHarvestRiskRateForTokenId(uint16 _tokenId) external view override returns (uint16) {        
        RunnerBull memory runnerBull = this.getTokenTraits(_tokenId);
        return harvestRiskRate[getNFTTypeIndex(runnerBull.nftType)];
    }

    function getHarvestRiskDistributeRateForTokenId(uint16 _tokenId) external view returns (uint16) {
        RunnerBull memory runnerBull = this.getTokenTraits(_tokenId);
        return harvestRiskDistributeRate[getNFTTypeIndex(runnerBull.nftType)];
    }

    function getClaimAmountBesideHarvestTax(uint256 _claimAmount, uint16 _tokenId) external view override returns (uint256 _netAmount) {

        require(_claimAmount > 0 , "Zero amount");
        
        uint16 rate = harvestRiskDistributeRate[getNFTTypeIndex(mintedTraits[_tokenId].nftType)];

        _netAmount = rate * _claimAmount / 10000;

    }

    function distributeHarvestRewards(uint256 _claimedAmountFrom, uint16 _fromTokenId) external override onlyPool {
        // only worker will have harvest tax
        require(_claimedAmountFrom > 0, "Zero amount");

        uint256 _totalAmountForWorker = _claimedAmountFrom * harvestRiskDistributeRate[getNFTTypeIndex(DataTypes.NFTType.WORKER)] / 10000;
        uint256 _totalAmountForStealer = _claimedAmountFrom * harvestRiskDistributeRate[getNFTTypeIndex(DataTypes.NFTType.STEALER)] / 10000;
        uint256 _totalAmountForManager = _claimedAmountFrom * harvestRiskDistributeRate[getNFTTypeIndex(DataTypes.NFTType.MANAGER)] / 10000;
        uint256 _totalAmountForAlpha = _claimedAmountFrom * harvestRiskDistributeRate[getNFTTypeIndex(DataTypes.NFTType.ALPHA)] / 10000;

        
        if (totalStakedWorkers > 0 && !this.isWorker(_fromTokenId)) {
            uint256 _rewardsForWorker = _totalAmountForWorker / totalStakedWorkers;
            if (_rewardsForWorker > 0) {
                for (uint16 i = 1; i <= totalStakedWorkers; i++) {
                    harvestRewards[stakedWorkers[i]] += _rewardsForWorker;
                }
            }
        }

        if (totalStakedStealers > 0  && !this.isStealer(_fromTokenId) ) {
            uint256 _rewardsForStealer = _totalAmountForStealer / totalStakedStealers;
            if (_rewardsForStealer > 0) {
                for (uint16 i = 1; i <= totalStakedStealers; i++) {
                    harvestRewards[stakedStealers[i]] += _rewardsForStealer;
                }
            }
        }

        if (totalStakedManagers > 0 && !this.isManager(_fromTokenId)) {
            uint256 _rewardsForManager = _totalAmountForManager / totalStakedManagers;
            if (_rewardsForManager > 0) {
                for (uint16 i = 1; i <= totalStakedManagers; i++) {
                    harvestRewards[stakedManagers[i]] += _rewardsForManager;
                }
            }
        }

        if (totalStakedAlphas > 0 && !this.isAlpha(_fromTokenId)) {
            uint256 _rewardsForAlpha = _totalAmountForAlpha / totalStakedAlphas;
            if (_rewardsForAlpha > 0) {
                for (uint16 i = 1; i <= totalStakedAlphas; i++) {
                    harvestRewards[stakedAlphas[i]] += _rewardsForAlpha;
                }
            }
        }

    }



    function getHarvestRewardsAmount (uint16 _tokenId) external view override returns (uint256 _rewards) {
        _rewards = harvestRewards[_tokenId];
    }

    function cleanHarvestRewards(uint16 _tokenId) external onlyPool override {
        harvestRewards[_tokenId] = 0;
    }


    function uploadTrait(address game, uint8 _nftType, uint256 _tokenId) public onlyOwner validNFTTypeIndex(_nftType) {
        require(address(this) == game, "Invalid trait for this game");

        if(mintedTraits[_tokenId].isValue == false) {
            uploadedTraitsLen = uploadedTraitsLen + 1;
        }
        
        RunnerBull memory data;

        data.gameAddr = game;
        data.nftType = getNFTType(_nftType);
        data.isValue = true;
        mintedTraits[_tokenId] = data;
        
    }

    function getNFTType(uint8 _nftTypeIndex) public pure returns(DataTypes.NFTType) {
        
        if (_nftTypeIndex == 1) {
            return DataTypes.NFTType.WORKER;
        } 
        if (_nftTypeIndex == 2) {
            return DataTypes.NFTType.STEALER;
        } 
        if (_nftTypeIndex == 3) {
            return DataTypes.NFTType.MANAGER;
        } 
        if (_nftTypeIndex == 4) {
            return DataTypes.NFTType.ALPHA;
        } 
        return DataTypes.NFTType.AVOID_ZERO;
    }

    function getNFTTypeIndex(DataTypes.NFTType _nftType) public pure returns(uint8) {
        
        if (_nftType == DataTypes.NFTType.WORKER) {
            return 1;
        } 
        if (_nftType == DataTypes.NFTType.STEALER) {
            return 2;
        } 
        if (_nftType == DataTypes.NFTType.MANAGER) {
            return 3;
        } 
        if (_nftType == DataTypes.NFTType.ALPHA) {
            return 4;
        } 
        return 0;
    }

    function burn(uint256 tokenId) external override whenNotPaused {
        require(_msgSender() == address(pool) || _msgSender() == owner(), "Only admin or pool can burn");
        _burn(tokenId);
    }
    /**
     * mint a token - 90% Worker, 10% Stealers
     * The first 20% are free to claim, the remaining cost $TOPIA
     */
    function mint(uint8 amount, bool stake) external payable whenNotPaused mintReady {
        require(tx.origin == _msgSender(), "Only EOA");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        require(amount >= MIN_MINT && amount <= MAX_MINT, "Invalid mint amount");
        
        uint256 totalTopiaCost = 0;
        //check mint price
        if (MINT_IN_TOPIA == true) {
            require(msg.value == 0);
            totalTopiaCost = mintCost(amount);
            uint256 senderTopiaBalance = topia.balanceOf(_msgSender());
            require(senderTopiaBalance >= totalTopiaCost, "Insuffcient topia balance.");
        } else {
            // NFT price in ETH
            require(amount * MINT_PRICE == msg.value, "Invalid payment amount");
        }
    
        uint16[] memory tokenIds = stake ? new uint16[](amount) : new uint16[](0);
    
        for (uint256 i = 0; i < amount; i++) {
            // minted++;
            uint256 seed = i + 1;
            uint256 _random = randomness.getRandom(seed);
            uint256 _pickedTokenId = _pickRandomUniqueId(_random);

            RunnerBull memory mintedNow = mintedTraits[_pickedTokenId];

            if (mintedNow.nftType == DataTypes.NFTType.WORKER) {
                mintedWorkers += 1;
                
            } else if(mintedNow.nftType == DataTypes.NFTType.STEALER) {
                mintedStealers += 1;
                
            } else if(mintedNow.nftType == DataTypes.NFTType.MANAGER) {
                mintedManagers += 1;
            } else if(mintedNow.nftType == DataTypes.NFTType.ALPHA) {
                mintedAlphas += 1;
            }

            address recipient = _msgSender();
                        
            if (!stake) {
                _safeMint(recipient, _pickedTokenId);
            } else {
                _safeMint(address(pool), _pickedTokenId);
            }
            tokenIds[i] = uint16(_pickedTokenId);
        }

        if (totalTopiaCost > 0) topia.burn(_msgSender(), totalTopiaCost);
        if (stake) pool.addManyToPool(_msgSender(), tokenIds, address(this));

    }

    function mintCost(uint8 amount) public view returns (uint256) {
        
        uint8 _amount = amount;
        if (amount >= 10) {
            uint8 rem = amount / 10;
            _amount = amount - rem;
        }
        return _amount*MINT_PRICE;
        
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        // Hardcode the madator's approval so that users don't have to waste gas approving
        if (_msgSender() != address(pool))
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: transfer caller is not owner nor approved"
            );
        _transfer(from, to, tokenId);
    }

    function _pickRandomUniqueId(uint256 _random) private returns (uint256 _id) {
        minted = minted + 1;
        uint256 len = idsLength - minted;
        
        require(len > 0, 'no ids left');
        uint256 randomIndex = _random % len;

        _id = (ids[randomIndex] != 0 ? ids[randomIndex] : randomIndex) + 1;
        
        ids[randomIndex] = uint16(ids[len - 1] == 0 ? len - 1 : ids[len - 1]);
        ids[len - 1] = 0;
        
    }


    /** READ */

    function getTokenTraits(uint256 _tokenId)
        external
        view
        override
        returns (RunnerBull memory)
    {
        require(
            _exists(_tokenId),
            "TokenTraits query for nonexistent token"
        );
        return mintedTraits[_tokenId];
    }

    function getClaimDailyTopiaForTokenId(uint16 _tokenId) public view returns (uint256) {
        RunnerBull memory runnerBull = this.getTokenTraits(_tokenId);
        return claimAmount[getNFTTypeIndex(runnerBull.nftType)];
    }

    function getUnstakeRiskRateForTokenId(uint16 _tokenId) external view override returns (uint16) {
        RunnerBull memory runnerBull = this.getTokenTraits(_tokenId);
        return unstakeRiskRate[getNFTTypeIndex(runnerBull.nftType)];
    }


    function getAvailableClaimAmount( uint16 _tokenId, uint80 _fromStamp, uint80 _toStamp) external view override returns(uint256) {
        
        uint256 dailyRewardsAmount = this.getClaimDailyTopiaForTokenId(_tokenId);
        
        uint80 stakedDaysFromLastClaim = uint80((_toStamp - _fromStamp) / 1 days);
        if (stakedDaysFromLastClaim >= MIN_STAKE_EXIT_DAYS ) {
            return  stakedDaysFromLastClaim * dailyRewardsAmount;
        } else {
            return 0;
        }
    }

    /** ADMIN */

    /**
     * called after deployment so that the contract can get random stealer thieves
     * @param _pool the address of the Pool
     */
    function setPool(address _pool) external onlyOwner {
        pool = IPool(_pool);
    }

    /**
     * allows owner to withdraw funds from minting
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    /** RENDER */

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {

        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }

    function getRandGameResult(uint256 seed, uint16 nftCount,uint16 nrOfWorker, uint16 nrOfStealer, uint16 nrOfManager ) 
        external 
        override 
        view 
        returns (bool _workerWin) 
    {
        uint256 _seed = uint256(keccak256(abi.encodePacked( seed, nftCount, nrOfWorker, nrOfStealer, nrOfManager)));
        uint256 _rand = randomness.getRandom(_seed);

        _workerWin = _rand >> 16 & 0x1 == 1;
    }

    function isWorker(uint256 tokenId) external view override returns (bool worker) {        
        return this.getTokenTraits(tokenId).nftType == DataTypes.NFTType.WORKER;
    }
    /**
     * checks if a token is a Stealer
     */
    function isStealer(uint256 tokenId) external view override returns (bool stealer) {
        return this.getTokenTraits(tokenId).nftType == DataTypes.NFTType.STEALER;
    }
    /**
     * checks if a token is a MANAGER
     */
    function isManager(uint256 tokenId) external view override returns (bool manager) {
        
        return this.getTokenTraits(tokenId).nftType == DataTypes.NFTType.MANAGER;

    }

    function isAlpha(uint256 tokenId) external view override returns (bool manager) {
        return this.getTokenTraits(tokenId).nftType == DataTypes.NFTType.ALPHA;
    }



    function getPrizeAmountForOwner(uint16 _tokenId, uint256 _betAmount, bool _betForWorker, bool _workerWin) external view override returns (uint256)  {

        if (this.isWorker(_tokenId)) {
            return _workerWin ? _betAmount * 12500 / 10000 : 0;
        } else  if (this.isStealer(_tokenId)) {
            return _workerWin ? 0: _betAmount * 12500 / 10000;
        } else  if (this.isManager(_tokenId)) {
            return _workerWin && _betForWorker ?  _betAmount * 2 : 0;
        } 

        return 0;         
    }
    function getPrizeAmountForBetPool(uint16 _tokenId, uint256 _betAmount, bool _betForWorker, bool _workerWin) external view override returns (uint256)  {

        if (this.isWorker(_tokenId)) {
            return _workerWin ? 0 : _betAmount * 7500 / 10000;
            
        } else  if (this.isStealer(_tokenId)) {
            return _workerWin ? _betAmount * 7500 / 10000: 0;

        } else  if (this.isManager(_tokenId)) {
            return _workerWin && _betForWorker ? 0  : _betAmount;
        } 

        return 0;         
    }
    function getPrizeAmountToManagers(uint16 _tokenId, uint256 _betAmount, bool _workerWin) external view override returns (uint256)  {

        if (this.isWorker(_tokenId)) {
            return _workerWin ? 0 : _betAmount * 2500 / 10000;            
        } else  if (this.isStealer(_tokenId)) {
            return _workerWin ? _betAmount * 2500 / 10000: 0;
        } 

        return 0;         
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }

// Opensea Automatic Collection Data


    function setContactURI(string memory _contURI) external onlyOwner{
        _contractURI = _contURI;
    }


    function contractURI() public view returns (string memory) {
        // Following link must return this json data.
        // {
        //   "name": "OpenSea Creatures",
        //   "description": "OpenSea Creatures are adorable aquatic beings primarily for demonstrating what can be done using the OpenSea platform. Adopt one today to try out all the OpenSea buying, selling, and bidding feature set.",
        //   "image": "external-link-url/image.png",
        //   "external_link": "external-link-url",
        //   "seller_fee_basis_points": 100, # Indicates a 1% seller fee.
        //   "fee_recipient": "0xA97F337c39cccE66adfeCB2BF99C1DdC54C2D721" # Where seller fees will be paid to.
        // }

        return _contractURI;
    }

    function updatePrizePYE(uint16 goldenChance,uint16 filledChance, uint16 dudChance, uint256 goldenAmount, uint256 filledAmount, uint256 dudAmount ) public onlyOwner {
        require(goldenChance + filledChance + dudChance == 10000, "Invalid chance value for 100% to 10000");
        

        GoldenPYE.chance = goldenChance;
        GoldenPYE.topiaAmount = goldenAmount;

        FilledPYE.chance = filledChance;
        FilledPYE.topiaAmount = filledAmount;
        
        DudPYE.chance = dudChance;
        DudPYE.topiaAmount = dudAmount;
    }


    function purchasePYEBy(uint256 _foodieTokenId) public {
        require(ownerOf(_foodieTokenId) == _msgSender(), "Invalid foodie owner");
        require(topia.balanceOf(_msgSender()) >= 20 ether, "Insufficent topia balance");

        if (purchasedPYE[_foodieTokenId].purchasedCount == 0 && purchasedPYE[_foodieTokenId].lastStamp == 0 ){
            purchasedPYE[_foodieTokenId].lastStamp = uint80(block.timestamp);
        }

        uint80 passingDays = (uint80(block.timestamp) - purchasedPYE[_foodieTokenId].lastStamp) / 1 days;

        if (passingDays > 0) {
            uint80 dailyCount =  purchasedPYE[_foodieTokenId].purchasedCount / passingDays;
            RunnerBull memory runnerBull = this.getTokenTraits(_foodieTokenId);
            require(dailyCount < limitPurchaseCountDaily[getNFTTypeIndex(runnerBull.nftType)], "Exceeds limit daily purcase PYE");
        }
                
        topia.burn(_msgSender(), 20 ether);

        if (totalStakedAlphas > 0) {
            
            uint256 _eachRewards = 20 ether / totalStakedAlphas;

            if (_eachRewards > 0) {
                for( uint16 i=1; i<=totalStakedAlphas; i++) {
                    uint16 _alphaTokenId = stakedAlphas[i];
                    topia.mint( ownerOf(_alphaTokenId) , _eachRewards);
                }
            }
        }

        uint256 seed = randomness.getRandom(_foodieTokenId + passingDays + totalStakedAlphas + topia.balanceOf(_msgSender()));
    
        uint256 _random = uint256(randomness.getRandom(seed) >> 6) / 10000;
        
        purchasedPYE[_foodieTokenId].purchasedCount += 1;
        if (_random < DudPYE.chance) {
            // No prize
            emit PurchasedPYE(_foodieTokenId, 0, "Dud");
        } else if (_random < DudPYE.chance + FilledPYE.chance) {
            topia.mint(ownerOf(_foodieTokenId), FilledPYE.topiaAmount);
            emit PurchasedPYE(_foodieTokenId, FilledPYE.topiaAmount, "Filled");
        } else {
            // GOlden Prize
            topia.mint(ownerOf(_foodieTokenId), GoldenPYE.topiaAmount);
            emit PurchasedPYE(_foodieTokenId, GoldenPYE.topiaAmount, "Golden");
        }
        
    } 

}
