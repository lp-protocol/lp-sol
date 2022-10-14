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

contract TheLPRenderer is Owned {
    using LibString for uint256;

    address public traitsImagePointer;
    string description =
        "AN EXPERIMENTAL APPROACH TO BOOTSTRAPPING NFT LIQUIDITY AND REWARDING HOLDERS";

    error TraitsImageAlreadySet();

    mapping(uint256 => string) traitMap;

    struct TraitInfo {
        mapping(uint256 => string) map;
    }

    //     traits = [
    //     // back
    //     _r(seeds.one, 1, 100) <= 10 ? _r(seeds.one, 1, 2) : 0,
    //     // pants
    //     _r(seeds.two, 1, 100) <= 2 ? 0 : _r(seeds.two, 1, 100) <= 50
    //         ? _r(seed, 59, 62)
    //         : _r(seed, 72, 75),
    //     // shirt
    //     _r(seeds.three, 1, 100) <= 96 ? _r(seeds.three, 76, 83) : 0,
    //     // logo
    //     _r(seeds.four, 1, 100) <= 35 ? _r(seeds.four, 50, 58) : 0,
    //     // clothing item
    //     _r(seeds.five, 1, 100) <= 25 ? _r(seeds.five, 3, 15) : 0,
    //     // gloves
    //     _r(seeds.six, 1, 100) <= 50 ? _r(seeds.six, 16, 17) : 0,
    //     //hat
    //     _r(seeds.seven, 1, 100) <= 45 ? _r(seeds.seven, 18, 39) : 0,
    //     //kit front
    //     0,
    //     // hand
    //     _r(seeds.eight + 1, 1, 100) <= 25 ? _r(seeds.eight, 63, 71) : 0
    // ];

    TraitInfo back;
    TraitInfo pants;
    TraitInfo shirt;
    TraitInfo logo;
    TraitInfo clothingItem;
    TraitInfo gloves;
    TraitInfo hat;
    TraitInfo item;
    TraitInfo special;

    constructor() Owned(msg.sender) {
        back.map[1] = "Fairy Wings";
        back.map[2] = "Jetpack";

        pants.map[59] = "Orange Pants";
        pants.map[60] = "Blue Jeans";
        pants.map[61] = "Black Pants";
        pants.map[62] = "Fun Jeans";
        pants.map[72] = "Blue Shorts";
        pants.map[73] = "Orange Shorts";
        pants.map[74] = "Black Shorts";
        pants.map[75] = "White Shorts";
    }
}
