// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "ERC721A/ERC721A.sol";
import "solmate/utils/SSTORE2.sol";
import "solmate/auth/Owned.sol";
import "solmate/utils/LibString.sol";
import "solmate/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/Address.sol";
import "prb-math/PRBMathUD60x18.sol";
import "./Base64.sol";

interface ITheLpRenderer {
    function getJsonString(uint256 tokenId, bytes32 seed)
        external
        view
        returns (string memory);
}

contract TheLP is ERC721A, Owned, ReentrancyGuard {
    using LibString for uint256;
    using PRBMathUD60x18 for uint256;

    ITheLpRenderer renderer;

    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public MIN_PRICE;
    uint256 public constant DURATION = 33 days;
    uint256 public startTime;
    address public traitsImagePointer;
    uint256 public totalEthClaimed;
    bool public lockedIn = false;
    mapping(uint256 => uint256) private _rewardDebt;
    mapping(address => mapping(uint256 => uint256)) private _erc20RewardDebt;
    mapping(address => uint256) private _erc20TotalClaimed;
    mapping(uint256 => TokenMintInfo) public tokenMintInfo;
    struct TokenMintInfo {
        bytes32 seed;
        uint256 cost;
    }
    struct Token {
        bool exists;
        uint256 idx;
    }
    mapping(uint256 => Token) public mappingIdToIndex;
    uint256[] public tokensForSale;

    error TokenNotForSale();
    error IncorrectPayment();
    error AlreadyLocked();

    constructor(uint256 _startTime) ERC721A("The LP", "LP") Owned(msg.sender) {
        startTime = _startTime;
        // Team mint
    }

    function buy(uint256 id) public nonReentrant {
        if (!mappingIdToIndex[id].exists) {
            revert TokenNotForSale();
        }
    }

    function sell() public nonReentrant {}

    uint256 private _totalFees;

    function getFeeBalance() public view returns (uint256) {
        return _totalFees;
    }

    /**
     * @dev Public function that can be used to calculate the pending ETH payment for a given NFT ID
     */
    function calculatePendingPayment(uint256 nftId)
        public
        view
        returns (uint256)
    {
        return
            (getFeeBalance() + totalEthClaimed - _rewardDebt[nftId]).div(
                MAX_SUPPLY * 10**18
            );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return renderer.getJsonString(tokenId, tokenMintInfo[tokenId].seed);
    }

    function getEthBalance() public view returns (uint256) {
        uint256 balance = address(this).balance;
        uint256 fees = this.getFeeBalance();
        if (fees > balance) return 0;
        return balance - fees;
    }

    function getBuyPrice() public view returns (uint256) {
        uint256 a = getSellPrice();
        uint256 fee = a.mul(0.1 * 10**18);
        return a + fee;
    }

    function getSellPrice() public view returns (uint256) {
        uint256 sellPrice = getEthBalance().div(totalSupply());
        if (sellPrice < MIN_PRICE) {
            sellPrice = MIN_PRICE;
        }
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function setTraitsImage(string calldata data) external onlyOwner {
        traitsImagePointer = SSTORE2.write(bytes(data));
    }

    function getTraitsImage() public view returns (string memory) {
        return string(SSTORE2.read(traitsImagePointer));
    }

    function lockItIn() public onlyOwner {
        if (lockedIn) {
            revert AlreadyLocked();
        }
        uint256 half = address(this).balance.div(2);
        Address.sendValue(payable(owner), half);
    }

    function getCurrentMintPrice() public returns (uint256) {
        return 0;
    }

    function mint(uint256 amount) public payable nonReentrant {
        uint256 current = _nextTokenId();
        uint256 end = current + amount - 1;
        uint256 totalCost = amount * getCurrentMintPrice();
        if (msg.value >= totalCost) {
            revert IncorrectPayment();
        }
        _mint(msg.sender, amount);
        uint256 refund = msg.value - totalCost;
        if (refund > 0) {
            Address.sendValue(payable(msg.sender), refund);
        }
        for (; current <= end; current++) {
            tokenMintInfo[current] = TokenMintInfo({
                seed: keccak256(
                    abi.encodePacked(blockhash(block.number - 1), current)
                ),
                cost: getCurrentMintPrice()
            });
        }
    }
}
