// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "ERC721A/extensions/ERC721AQueryable.sol";
import "solmate/utils/SSTORE2.sol";
import "solmate/auth/Owned.sol";
import "solmate/utils/LibString.sol";
import "solmate/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/Address.sol";
import "prb-math/PRBMathUD60x18.sol";
import "./Base64.sol";
import "./TheLPRenderer.sol";

// import "forge-std/console2.sol";

contract TheLP is ERC721AQueryable, Owned, ReentrancyGuard {
  using LibString for uint256;
  using PRBMathUD60x18 for uint256;

  TheLPRenderer renderer;

  event PaymentReceived(address from, uint256 amount);
  event PaymentReleased(address to, uint256 amount);

  uint256 public constant MAX_SUPPLY = 10_000;
  uint256 public constant MAX_PUB_SALE = 8_000;
  uint256 public constant MAX_TEAM = 1_000;
  uint256 public constant MAX_LP = 1_000;
  bool public gameOver;
  uint256 public MIN_PRICE = 0.0333 ether;
  uint256 public MAX_PRICE = 3.33 ether;
  uint256 public minBuyPrice = 0.001 ether;
  uint256 public constant DURATION = 34 days;
  uint256 public buyFee = 0.1 * 10**18;
  uint256 public feeSplit = 2 * 10**18;
  uint256 public DISCOUNT_RATE =
    uint256(MAX_PRICE - MIN_PRICE).div((DURATION - 1 days) * 10**18);
  uint256 public startTime;
  uint256 public endTime;
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

  error TokenNotForSale();
  error IncorrectPayment();
  error AlreadyLocked();
  error NotGameOver();
  error AlreadyGameOver();
  error LockedIn();
  error CannotRedeem();
  error InvalidTokenId(uint256 tokenId);
  error NotOwner(uint256 tokenId);

  bytes32 teamMintBlockHash;
  bytes32 lpMintBlockHash;

  constructor(
    uint256 _startTime,
    TheLPRenderer _renderer,
    uint256 minPrice,
    uint256 maxPrice,
    address teamMintWallet
  ) ERC721A("The LP", "LP") Owned(msg.sender) {
    startTime = _startTime;
    endTime = startTime + DURATION;
    renderer = _renderer;
    MIN_PRICE = minPrice;
    MAX_PRICE = maxPrice;
    DISCOUNT_RATE = uint256(MAX_PRICE - MIN_PRICE).div(
      (DURATION - 1 days) * 10**18
    );

    _mintERC2309(teamMintWallet, MAX_TEAM);

    teamMintBlockHash = blockhash(block.number - 1);
  }

  function getEthBalance() external view returns (uint256) {
    return _getEthBalance(0);
  }

  function _getEthBalance(uint256 minus) private view returns (uint256) {
    uint256 balance = address(this).balance - minus;
    uint256 fees = getFeeBalance();
    if (fees > balance) return 0;
    return balance - fees;
  }

  function updateMinBuyPrice(uint256 price) public onlyOwner {
    minBuyPrice = price;
  }

  function updateFeeSplit(uint256 newSplit) public onlyOwner {
    feeSplit = newSplit;
  }

  function updateFee(uint256 newFee) public onlyOwner {
    buyFee = newFee;
  }

  function getBuyPrice() external view returns (uint256, uint256) {
    return _getBuyPrice(0);
  }

  function _getBuyPrice(uint256 minus) private view returns (uint256, uint256) {
    uint256 a = _getSellPrice(minus);
    if (a < minBuyPrice) {
      a = minBuyPrice;
    }
    uint256 fee = a.mul(0.1 * 10**18);
    return (a + fee, fee);
  }

  function getSellPrice() external view returns (uint256) {
    return _getSellPrice(0);
  }

  function _getSellPrice(uint256 minus) private view returns (uint256) {
    uint256 sellPrice = _getEthBalance(minus).div(
      (totalSupply() - balanceOf(address(this))) * 10**18
    );
    return sellPrice;
  }

  function buy(uint256 id) public payable nonReentrant {
    if (ownerOf(id) != address(this)) {
      revert NotOwner(id);
    }
    (uint256 cost, uint256 fee) = _getBuyPrice(msg.value);
    if (msg.value < cost) {
      revert IncorrectPayment();
    }

    _totalFees += fee.div(feeSplit);

    // Approve sender to move this token
    // ERC721a doesn't abstract transfer functionality by default
    _tokenApprovals[id].value = msg.sender;
    transferFrom(address(this), msg.sender, id);

    uint256 refund = msg.value - cost;
    if (refund > 0) {
      Address.sendValue(payable(msg.sender), refund);
    }
  }

  error ApprovalRequired(uint256 tokenId);

  function sell(uint256 tokenId) public payable nonReentrant {
    if (ownerOf(tokenId) != msg.sender) {
      revert NotOwner(tokenId);
    }
    // if (
    //   getApproved(tokenId) != address(this) &&
    //   !isApprovedForAll(msg.sender, address(this))
    // ) {
    //   revert ApprovalRequired(tokenId);
    // }
    uint256 sellPrice = _getSellPrice(msg.value);
    transferFrom(msg.sender, address(this), tokenId);
    Address.sendValue(payable(msg.sender), sellPrice);
  }

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

  error NotLockedIn();

  function _claim(uint256 nftId) private {
    if (!lockedIn) {
      revert NotLockedIn();
    }
    uint256 payment = calculatePendingPayment(nftId);
    require(payment > 0, "Nothing to claim");
    uint256 preBalance = address(this).balance;
    _rewardDebt[nftId] += preBalance;
    totalEthClaimed += payment;
    address ownerAddr = ownerOf(nftId);
    Address.sendValue(payable(ownerAddr), payment);
    emit PaymentReleased(ownerAddr, payment);
  }

  function claim(uint256 nftId) public nonReentrant {
    _claim(nftId);
  }

  function claimMany(uint256[] memory nftIds) public nonReentrant {
    for (uint256 i = 0; i < nftIds.length; i++) {
      _claim(nftIds[i]);
    }
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721A, IERC721A)
    returns (string memory)
  {
    bytes32 seed;
    // 1 - 1000
    if (tokenId <= MAX_TEAM) {
      assert(tokenId >= 1 && tokenId <= 1000);
      seed = keccak256(abi.encodePacked(teamMintBlockHash, tokenId));
      // 9001 - 10000
    } else if (tokenId >= MAX_PUB_SALE + MAX_TEAM + 1) {
      assert(tokenId >= 9001 && tokenId <= 10000);
      seed = keccak256(abi.encodePacked(lpMintBlockHash, tokenId));
    } else {
      // 1001 - 9000
      assert(tokenId >= 1001 && tokenId <= 9000);
      seed = tokenMintInfo[tokenId].seed;
    }
    return renderer.getJsonUri(tokenId, seed);
  }

  function _startTokenId() internal view virtual override returns (uint256) {
    return 1;
  }

  function isGameOver() public view returns (bool) {
    return block.timestamp >= endTime && _totalMinted() < MAX_SUPPLY;
  }

  function _redeem(uint256 tokenId) private {
    if (tokenMintInfo[tokenId].cost == 0) {
      revert InvalidTokenId(tokenId);
    }
    if (ownerOf(tokenId) != msg.sender) {
      revert NotOwner(tokenId);
    }
    Address.sendValue(payable(msg.sender), tokenMintInfo[tokenId].cost);
    tokenMintInfo[tokenId].cost = 0;
  }

  function redeem(uint256[] memory tokenIds) public nonReentrant {
    if (!isGameOver()) {
      revert NotGameOver();
    }

    for (uint256 i = 0; i < tokenIds.length; i++) {
      _redeem(tokenIds[i]);
    }
  }

  function _lockItIn() private {
    if (lockedIn) {
      revert AlreadyLocked();
    }
    uint256 half = address(this).balance.div(2 * 10**18);
    Address.sendValue(payable(owner), half);
    lpMintBlockHash = blockhash(block.number - 1);
    _mintERC2309(address(this), MAX_LP);
    lockedIn = true;
  }

  function getCurrentMintPrice() public view returns (uint256) {
    if (block.timestamp < startTime) {
      revert NotStarted();
    }
    uint256 timeElapsed = block.timestamp - startTime;
    uint256 discount = DISCOUNT_RATE * timeElapsed;
    if (discount > MAX_PRICE) return MIN_PRICE;
    return MAX_PRICE - discount;
  }

  error AuctionEnded();
  error NotStarted();
  error AmountRequired();
  error SoldOut();

  function mint(uint256 amount) public payable nonReentrant {
    if (block.timestamp >= endTime) {
      revert AuctionEnded();
    }
    if (block.timestamp < startTime) {
      revert NotStarted();
    }
    if (amount <= 0) {
      revert AmountRequired();
    }
    uint256 totalMinted = _totalMinted();
    uint256 totalAfterMint = totalMinted + amount;
    if (totalAfterMint > MAX_PUB_SALE + MAX_TEAM) {
      revert SoldOut();
    }
    uint256 mintPrice = getCurrentMintPrice();
    uint256 totalCost = amount * mintPrice;
    if (msg.value < totalCost) {
      revert IncorrectPayment();
    }
    uint256 current = _nextTokenId();
    uint256 end = current + amount - 1;

    for (; current <= end; current++) {
      tokenMintInfo[current] = TokenMintInfo({
        seed: keccak256(abi.encodePacked(blockhash(block.number - 1), current)),
        cost: mintPrice
      });
    }
    uint256 refund = msg.value - totalCost;
    if (refund > 0) {
      Address.sendValue(payable(msg.sender), refund);
    }
    _mint(msg.sender, amount);
    if (totalAfterMint == MAX_PUB_SALE + MAX_TEAM) {
      _lockItIn();
    }
  }

  receive() external payable virtual {
    emit PaymentReceived(msg.sender, msg.value);
  }
}
