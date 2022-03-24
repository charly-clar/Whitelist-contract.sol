
pragma solidity ^0.8.7;

/// @title Contract of NFTs collection
/// @author Clar Ch
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MonsterNFT is ERC721Enumerable, PaymentSplitter, Ownable, ReentrancyGuard {


    using Counters for Counters.Counter;


    using Strings for uint256;


    bytes32 public merkleRoot;


    Counters.Counter private _nftIdCounter;


    uint public constant MAX_SUPPLY = 7777;
 
    uint public max_mint_allowed = 3;

    uint public pricePresale = 0.00025 ether;

    uint public priceSale = 0.0003 ether;


    string public baseURI;

    string public notRevealedURI;

    string public baseExtension = ".json";


    bool public revealed = false;


    bool public paused = false;


    enum Steps {
        Before,
        Presale,
        Sale,
        SoldOut,
        Reveal
    }

    Steps public sellingStep;
    

    address private _owner;


    mapping(address => uint) nftsPerWallet;


    address[] private _team = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
    ];


    uint[] private _teamShares = [
        70,
        20, 
        10
    ];


    constructor(string memory _theBaseURI, string memory _notRevealedURI, bytes32 _merkleRoot) ERC721("NFTName", "NFTSymbol") PaymentSplitter(_team, _teamShares) {
        _nftIdCounter.increment();
        transferOwnership(msg.sender);
        sellingStep = Steps.Before;
        baseURI = _theBaseURI;
        notRevealedURI = _notRevealedURI;
        merkleRoot = _merkleRoot;
    }

    /**
    * @notice 
    *
    * @param _newMerkleRoot
    **/
    function changeMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
        merkleRoot = _newMerkleRoot;
    }

    /** 
    * @notice 
    *
    * @param _paused
    **/
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    /** 
    * @notice 
    *
    * @param _maxMintAllowed 
    **/
    function changeMaxMintAllowed(uint _maxMintAllowed) external onlyOwner {
        max_mint_allowed = _maxMintAllowed;
    }

    /**
    * @notice 
    *
    * @param _pricePresale 
    **/
    function changePricePresale(uint _pricePresale) external onlyOwner {
        pricePresale = _pricePresale;
    }

    /**
    * @notice 
    *
    * @param _priceSale 
    **/
    function changePriceSale(uint _priceSale) external onlyOwner {
        priceSale = _priceSale;
    }

    /**
    * @notice 
    *
    * @param _newBaseURI 
    **/
    function setBaseUri(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    /**
    * @notice
    *
    * @param _notRevealedURI 
    **/
    function setNotRevealURI(string memory _notRevealedURI) external onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    /**
    * @notice 
    **/
    function reveal() external onlyOwner{
        revealed = true;
    }

    /**
    * @notice 
    *
    * @return The 
    **/
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /**
    * @notice 
    *
    * @param _baseExtension 
    **/
    function setBaseExtension(string memory _baseExtension) external onlyOwner {
        baseExtension = _baseExtension;
    }

    /** 
    * @notice 
    **/
    function setUpPresale() external onlyOwner {
        sellingStep = Steps.Presale;
    }

    /** 
    * @notice 
    **/
    function setUpSale() external onlyOwner {
        require(sellingStep == Steps.Presale, "First the presale, then the sale.");
        sellingStep = Steps.Sale;
    }

    /**
    * @notice 
    *
    * @param _account 
    * @param _proof 
    **/
    function presaleMint(address _account, bytes32[] calldata _proof) external payable nonReentrant {

        require(sellingStep == Steps.Presale, "Presale has not started yet.");

        require(nftsPerWallet[_account] < 1, "You can only get 1 NFT on the Presale");

        require(isWhiteListed(_account, _proof), "Not on the whitelist");
  
        uint price = pricePresale;

        require(msg.value >= price, "Not enought funds.");
    
 
        _safeMint(_account, _nftIdCounter.current());

        _nftIdCounter.increment();
    }

    /**
    * @notice
    *
    * @param _ammount
    **/
    function saleMint(uint256 _ammount) external payable nonReentrant {

        uint numberNftSold = totalSupply();

        uint price = priceSale;
  
        require(sellingStep != Steps.SoldOut, "Sorry, no NFTs left.");
   
        require(sellingStep == Steps.Sale, "Sorry, sale has not started yet.");
   
        require(msg.value >= price * _ammount, "Not enought funds.");

        require(_ammount <= max_mint_allowed, "You can't mint more than 3 tokens");

        require(numberNftSold + _ammount <= MAX_SUPPLY, "Sale is almost done and we don't have enought NFTs left.");
 
        nftsPerWallet[msg.sender] += _ammount;

        if(numberNftSold + _ammount == MAX_SUPPLY) {
            sellingStep = Steps.SoldOut;   
        }

        for(uint i = 1 ; i <= _ammount ; i++) {
            _safeMint(msg.sender, numberNftSold + i);
        }
    }

    /**
    * @notice 
    *
    * @param _account 
    **/
    function gift(address _account) external onlyOwner {
        uint supply = totalSupply();
        require(supply + 1 <= MAX_SUPPLY, "Sold out");
        _safeMint(_account, supply + 1);
    }

    /**
    * @notice
    *
    * @param account
    * @param proof
    *
    * @return true
    **/
    function isWhiteListed(address account, bytes32[] calldata proof) internal view returns(bool) {
        return _verify(_leaf(account), proof);
    }

    /**
    * @notice
    *
    * @param account
    *
    * @return The 
    **/
    function _leaf(address account) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    /** 
    * @notice 
    *
    * @param leaf 
    * @param proof 
    *
    * @return True 
    **/
    function _verify(bytes32 leaf, bytes32[] memory proof) internal view returns(bool) {
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    /**
    * @notice 
    *
    * @param _nftId 
    *
    * @return The
    **/
    function tokenURI(uint _nftId) public view override(ERC721) returns (string memory) {
        require(_exists(_nftId), "This NFT doesn't exist.");
        if(revealed == false) {
            return notRevealedURI;
        }
        
        string memory currentBaseURI = _baseURI();
        return 
            bytes(currentBaseURI).length > 0 
            ? string(abi.encodePacked(currentBaseURI, _nftId.toString(), baseExtension))
            : "";
    }

}
