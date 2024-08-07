// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity =0.8.26;

import "@pixelaunch/extensions/Whitelistable.sol";
import "@pixelaunch/RoyaltyPaymentSplitter.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PixelaunchNFT is ERC721, ERC721Enumerable, ERC721Pausable, ERC2981, ReentrancyGuard, Whitelistable, Ownable {
    struct FundsBeneficiary {
        address recipient;
        uint96 shares;
    }

    struct ConstructorParams {
        string name;
        string symbol;
        uint256 maxSupply;
        uint256 maxWhitelistSupply;
        uint256 reservedSupply;
        address reservedSupplyRecipient;
        uint256 whitelistMintDuration;
        FundsBeneficiary[] mintFundsBeneficiaries;
        FundsBeneficiary[] royaltyFundsBeneficiaries;
        uint256 mintStartTimestamp;
        uint256 publicMintPrice;
        uint256 whitelistMintPrice;
        uint256 maxWhitelistMintPerTx;
        uint256 maxPublicMintPerTx;
        uint256 maxWhitelistMintPerWallet;
        uint256 maxPublicMintPerWallet;
        uint96 royaltyBps;
        string baseURI;
    }

    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable MAX_WHITELIST_SUPPLY;
    uint256 public immutable RESERVED_SUPPLY;
    address public immutable RESERVED_SUPPLY_RECIPIENT;

    uint256 public mintStartTimestamp;
    uint256 public whitelistMintDuration;
    uint256 public totalWhitelistSupply;

    uint256 public publicMintPrice;
    uint256 public whitelistMintPrice;

    uint256 public maxWhitelistMintPerTx;
    uint256 public maxPublicMintPerTx;
    uint256 public maxWhitelistMintPerWallet;
    uint256 public maxPublicMintPerWallet;

    // these will be a PaymentSplitter contract if there are multiple beneficiaries
    address payable public mintFundsBeneficiary;
    address payable public royaltyFundsBeneficiary;

    string public baseURI;

    mapping(address wallet => uint256) public _whitelistMintCount;
    mapping(address wallet => uint256) public _publicMintCount;
    uint256 private _nextTokenId;

    event WhitelistMintPriceChanged(uint256 previousMintPrice, uint256 newMintPrice);
    event PublicMintPriceChanged(uint256 previousMintPrice, uint256 newMintPrice);
    event MintStartTimestampChanged(uint256 previousMintStartTimestamp, uint256 newMintStartTimestamp);
    event BaseURIChanged(string previousBaseURI, string newBaseURI);
    event WhitelistMint(address indexed minter, uint256 tokenId);
    event PublicMint(address indexed minter, uint256 tokenId);

    error InvalidMaxSupply();
    error InvalidMaxWhitelistSupply();
    error InvalidReservedSupply();
    error MaxSupplyReached();
    error MaxWhitelistSupplyReached();
    error InvalidAmount();
    error MintPriceNotPaid();
    error MintingNotStarted();
    error MintingAlreadyStarted();
    error WhitelistMintingEnded();
    error NonExistentTokenId();
    error ArrayLengthMismatch();
    error RoyaltyTooHigh();
    error TimestampInThePast();
    error TransferFailed(address recipient);
    error MaxWhitelistMintPerTxExceeded();
    error MaxPublicMintPerTxExceeded();
    error MaxWhitelistMintPerWalletExceeded();
    error MaxPublicMintPerWalletExceeded();

    modifier whenMintNotStarted() {
        if (block.timestamp >= mintStartTimestamp) {
            revert MintingAlreadyStarted();
        }
        _;
    }

    constructor(ConstructorParams memory params) ERC721(params.name, params.symbol) Ownable(msg.sender) {
        if (params.maxSupply == 0) {
            revert InvalidMaxSupply();
        }

        if (params.reservedSupply > params.maxSupply) {
            revert InvalidReservedSupply();
        }

        if (params.maxWhitelistSupply + params.reservedSupply > params.maxSupply) {
            revert InvalidMaxWhitelistSupply();
        }

        if (params.mintStartTimestamp < block.timestamp) {
            revert TimestampInThePast();
        }

        if (params.royaltyBps > 1500) {
            revert RoyaltyTooHigh();
        }

        MAX_SUPPLY = params.maxSupply;
        RESERVED_SUPPLY = params.reservedSupply;
        RESERVED_SUPPLY_RECIPIENT = params.reservedSupplyRecipient;
        MAX_WHITELIST_SUPPLY = params.maxWhitelistSupply;

        whitelistMintDuration = params.whitelistMintDuration;
        mintStartTimestamp = params.mintStartTimestamp;
        publicMintPrice = params.publicMintPrice;
        whitelistMintPrice = params.whitelistMintPrice;
        maxWhitelistMintPerTx = params.maxWhitelistMintPerTx;
        maxPublicMintPerTx = params.maxPublicMintPerTx;
        maxWhitelistMintPerWallet = params.maxWhitelistMintPerWallet;
        maxPublicMintPerWallet = params.maxPublicMintPerWallet;
        baseURI = params.baseURI;

        if (params.mintFundsBeneficiaries.length == 1) {
            mintFundsBeneficiary = payable(params.mintFundsBeneficiaries[0].recipient);
        } else {
            address[] memory recipients = new address[](params.mintFundsBeneficiaries.length);
            uint256[] memory shares = new uint256[](params.mintFundsBeneficiaries.length);

            for (uint256 i = 0; i < params.mintFundsBeneficiaries.length; i++) {
                recipients[i] = params.mintFundsBeneficiaries[i].recipient;
                shares[i] = params.mintFundsBeneficiaries[i].shares;
            }

            mintFundsBeneficiary = payable((new RoyaltyPaymentSplitter(recipients, shares)));
        }

        if (params.royaltyFundsBeneficiaries.length == 1) {
            royaltyFundsBeneficiary = payable(params.royaltyFundsBeneficiaries[0].recipient);
        } else {
            address[] memory recipients = new address[](params.royaltyFundsBeneficiaries.length);
            uint256[] memory shares = new uint256[](params.royaltyFundsBeneficiaries.length);

            for (uint256 i = 0; i < params.royaltyFundsBeneficiaries.length; i++) {
                recipients[i] = params.royaltyFundsBeneficiaries[i].recipient;
                shares[i] = params.royaltyFundsBeneficiaries[i].shares;
            }

            royaltyFundsBeneficiary = payable((new RoyaltyPaymentSplitter(recipients, shares)));
        }

        super._setDefaultRoyalty(royaltyFundsBeneficiary, params.royaltyBps);

        if (RESERVED_SUPPLY > 0) {
            for (uint256 i = 0; i < RESERVED_SUPPLY; i++) {
                _mint(RESERVED_SUPPLY_RECIPIENT);
            }
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _mint(address to) private {
        if (_nextTokenId == MAX_SUPPLY) {
            revert MaxSupplyReached();
        }

        super._mint(to, _nextTokenId);
        _nextTokenId++;
    }

    function publicMint(uint256 amount) public payable whenNotPaused nonReentrant {
        if (block.timestamp < mintStartTimestamp + whitelistMintDuration) {
            revert MintingNotStarted();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        if (amount > maxPublicMintPerTx) {
            revert MaxPublicMintPerTxExceeded();
        }

        if (_publicMintCount[msg.sender] + amount > maxPublicMintPerWallet) {
            revert MaxPublicMintPerWalletExceeded();
        }

        uint256 totalMintPrice = publicMintPrice * amount;
        if (msg.value < totalMintPrice) {
            revert MintPriceNotPaid();
        }

        for (uint256 i = 0; i < amount; i++) {
            _publicMintCount[msg.sender]++; // increment here to keep mint count consistent between mints
            _mint(msg.sender);
            emit PublicMint(msg.sender, _nextTokenId - 1);
        }

        (bool success, ) = mintFundsBeneficiary.call{value: totalMintPrice}("");
        if (!success) {
            revert TransferFailed(mintFundsBeneficiary);
        }

        uint256 excessPayment = msg.value - totalMintPrice;
        if (excessPayment == 0) {
            return;
        }

        (success, ) = msg.sender.call{value: excessPayment}("");
        if (!success) {
            revert TransferFailed(msg.sender);
        }
    }

    function whitelistMint(uint256 amount) public payable whenNotPaused nonReentrant {
        if (block.timestamp < mintStartTimestamp) {
            revert MintingNotStarted();
        }

        if (totalWhitelistSupply + amount > MAX_WHITELIST_SUPPLY) {
            revert MaxWhitelistSupplyReached();
        }

        if (block.timestamp >= mintStartTimestamp + whitelistMintDuration) {
            revert WhitelistMintingEnded();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        if (amount > maxWhitelistMintPerTx) {
            revert MaxWhitelistMintPerTxExceeded();
        }

        if (_whitelistMintCount[msg.sender] + amount > maxWhitelistMintPerWallet) {
            revert MaxWhitelistMintPerWalletExceeded();
        }

        uint256 totalMintPrice = whitelistMintPrice * amount;
        if (msg.value < totalMintPrice) {
            revert MintPriceNotPaid();
        }

        _removeWhitelistSpots(msg.sender, amount); // will revert if not enough spots

        for (uint256 i = 0; i < amount; i++) {
            // increment here to keep supply and mint count consistent between mints
            totalWhitelistSupply++;
            _whitelistMintCount[msg.sender]++;
            _mint(msg.sender);
            emit WhitelistMint(msg.sender, _nextTokenId - 1);
        }

        (bool success, ) = mintFundsBeneficiary.call{value: totalMintPrice}("");
        if (!success) {
            revert TransferFailed(mintFundsBeneficiary);
        }

        uint256 excessPayment = msg.value - totalMintPrice;
        if (excessPayment == 0) {
            return;
        }

        (success, ) = msg.sender.call{value: excessPayment}("");
        if (!success) {
            revert TransferFailed(msg.sender);
        }
    }

    function addWhitelistSpots(address _addr, uint256 _amount) public onlyOwner {
        _addWhitelistSpots(_addr, _amount);
    }

    function addWhitelistSpots(address[] calldata _addresses, uint256[] calldata _amounts) public onlyOwner {
        if (_addresses.length != _amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < _addresses.length; i++) {
            addWhitelistSpots(_addresses[i], _amounts[i]);
        }
    }

    function removeWhitelistSpots(address _addr, uint256 _amount) public onlyOwner {
        _removeWhitelistSpots(_addr, _amount);
    }

    function clearWhitelistSpots(address _addr) public onlyOwner {
        _clearWhitelistSpots(_addr);
    }

    function setPublicMintPrice(uint256 _mintPrice) public onlyOwner {
        uint256 previousMintPrice = publicMintPrice;
        publicMintPrice = _mintPrice;
        emit PublicMintPriceChanged(previousMintPrice, publicMintPrice);
    }

    function setWhitelistMintPrice(uint256 _mintPrice) public onlyOwner {
        uint256 previousMintPrice = whitelistMintPrice;
        whitelistMintPrice = _mintPrice;
        emit WhitelistMintPriceChanged(previousMintPrice, whitelistMintPrice);
    }

    function setMintStartTimestamp(uint256 _mintStartTimestamp) public onlyOwner whenMintNotStarted {
        if (_mintStartTimestamp < block.timestamp) {
            revert TimestampInThePast();
        }
        uint256 previousMintStartTimestamp = mintStartTimestamp;
        mintStartTimestamp = _mintStartTimestamp;
        emit MintStartTimestampChanged(previousMintStartTimestamp, mintStartTimestamp);
    }

    function setWhitelistMintDuration(uint256 _whitelistMintDuration) public onlyOwner whenMintNotStarted {
        whitelistMintDuration = _whitelistMintDuration;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        string memory previousBaseURI = baseURI;
        baseURI = baseURI_;
        emit BaseURIChanged(previousBaseURI, baseURI_);
    }

    function setDefaultRoyalty(address recipient, uint96 royaltyBps) public onlyOwner {
        if (royaltyBps > 1500) {
            revert RoyaltyTooHigh();
        }

        super._setDefaultRoyalty(recipient, royaltyBps);
    }

    function setRoyaltyFundsBeneficiaries(FundsBeneficiary[] memory fundsBeneficiaries) public onlyOwner {
        if (fundsBeneficiaries.length == 1) {
            royaltyFundsBeneficiary = payable(fundsBeneficiaries[0].recipient);
        } else {
            address[] memory recipients = new address[](fundsBeneficiaries.length);
            uint256[] memory shares = new uint256[](fundsBeneficiaries.length);

            for (uint256 i = 0; i < fundsBeneficiaries.length; i++) {
                recipients[i] = fundsBeneficiaries[i].recipient;
                shares[i] = fundsBeneficiaries[i].shares;
            }

            royaltyFundsBeneficiary = payable((new RoyaltyPaymentSplitter(recipients, shares)));
        }

        super._setDefaultRoyalty(royaltyFundsBeneficiary, fundsBeneficiaries[0].shares);
    }

    function setMintFundsBeneficiaries(FundsBeneficiary[] memory fundsBeneficiaries) public onlyOwner {
        if (fundsBeneficiaries.length == 1) {
            mintFundsBeneficiary = payable(fundsBeneficiaries[0].recipient);
        } else {
            address[] memory recipients = new address[](fundsBeneficiaries.length);
            uint256[] memory shares = new uint256[](fundsBeneficiaries.length);

            for (uint256 i = 0; i < fundsBeneficiaries.length; i++) {
                recipients[i] = fundsBeneficiaries[i].recipient;
                shares[i] = fundsBeneficiaries[i].shares;
            }

            mintFundsBeneficiary = payable((new RoyaltyPaymentSplitter(recipients, shares)));
        }
    }

    function setMaxWhitelistMintPerTx(uint256 _maxWhitelistMintPerTx) public onlyOwner {
        maxWhitelistMintPerTx = _maxWhitelistMintPerTx;
    }

    function setMaxPublicMintPerTx(uint256 _maxPublicMintPerTx) public onlyOwner {
        maxPublicMintPerTx = _maxPublicMintPerTx;
    }

    function setMaxWhitelistMintPerWallet(uint256 _maxWhitelistMintPerWallet) public onlyOwner {
        maxWhitelistMintPerWallet = _maxWhitelistMintPerWallet;
    }

    function setMaxPublicMintPerWallet(uint256 _maxPublicMintPerWallet) public onlyOwner {
        maxPublicMintPerWallet = _maxPublicMintPerWallet;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        if (!success) {
            revert TransferFailed(msg.sender);
        }
    }

    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        }

        uint256[] memory tokens = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);
        }

        return tokens;
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable, ERC721Pausable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
