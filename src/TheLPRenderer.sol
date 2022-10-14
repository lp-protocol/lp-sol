// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "ERC721A/ERC721A.sol";
import "solmate/utils/SSTORE2.sol";
import "solmate/auth/Owned.sol";
import "solmate/utils/LibString.sol";
import "solmate/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/Address.sol";
import "prb-math/PRBMathUD60x18.sol";
import "./TheLPTraits.sol";
import "./Base64.sol";

contract TheLPRenderer is Owned {
    using LibString for uint256;

    TheLPTraits traitsMetadata;

    address public traitsImagePointer;
    string description =
        "AN EXPERIMENTAL APPROACH TO BOOTSTRAPPING NFT LIQUIDITY AND REWARDING HOLDERS";

    error TraitsImageAlreadySet();

    constructor(TheLPTraits _traitsMetadata) Owned(msg.sender) {
        traitsMetadata = _traitsMetadata;
    }

    function setTraitsImage(string calldata data) external onlyOwner {
        if (traitsImagePointer != address(0)) {
            revert TraitsImageAlreadySet();
        }
        traitsImagePointer = SSTORE2.write(bytes(data));
    }

    function getTraitsImage() public view returns (string memory) {
        return string(SSTORE2.read(traitsImagePointer));
    }

    function updateDescription(string memory d) public onlyOwner {
        description = d;
    }

    function _r(
        uint256 seed,
        uint256 from,
        uint256 to
    ) private pure returns (uint256) {
        return from + (seed % (to - from + 1));
    }

    function _svgStart() private view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40" height="350" width="350"><defs><image height="1120" width="120" image-rendering="pixelated" id="s" href="',
                    getTraitsImage(),
                    '" /><clipPath id="c"><rect width="40" height="40" /></clipPath></defs><g clip-path="url(#c)">'
                )
            );
    }

    struct Traits {
        uint256 back;
        uint256 pants;
        uint256 shirt;
        uint256 logo;
        uint256 clothingItem;
        uint256 gloves;
        uint256 hat;
        uint256 kitFront;
        uint256 hand;
    }

    struct Seeds {
        uint256 one;
        uint256 two;
        uint256 three;
        uint256 four;
        uint256 five;
        uint256 six;
        uint256 seven;
        uint256 eight;
        uint256 nine;
        uint256 ten;
    }

    function _getUseString(uint256 col, uint256 row)
        private
        pure
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "<use height='40' width='40' href='#s' x='-",
                    col.toString(),
                    "' y='-",
                    row.toString(),
                    "' />"
                )
            );
    }

    function getSvgDataUri(bytes32 seed) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(bytes(getSvg(seed)))
                )
            );
    }

    function _getSvgDataUri(uint256[10] memory traits)
        private
        view
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(bytes(_getSvg(traits)))
                )
            );
    }

    function getJsonString(uint256 tokenId, bytes32 seed)
        public
        view
        returns (string memory)
    {
        uint256[10] memory traits = getTraits(seed);
        return
            string(
                abi.encodePacked(
                    '{"name": "The LP #',
                    tokenId.toString(),
                    '", "description": "',
                    description,
                    '",',
                    '"image":',
                    _getSvgDataUri(traits),
                    '","attributes":[',
                    _getTraitMetadata(traits),
                    "]}"
                )
            );
    }

    function _getTraitString(
        string memory key,
        string memory value,
        bool comma
    ) private pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '{"trait_type":"',
                    key,
                    '","value":"',
                    value,
                    '"}',
                    comma ? "," : ""
                )
            );
    }

    function _getTraitMetadata(uint256[10] memory traits)
        private
        view
        returns (string memory)
    {
        string[9] memory parts;
        for (uint256 i = 0; i < traits.length; i++) {
            uint256 current = traits[i];
            if (i == 0 && current != 0) {
                parts[i] = _getTraitString(
                    "Back",
                    traitsMetadata.getBack(current),
                    true
                );
            }
            if (i == 1 && current != 0) {
                parts[i] = _getTraitString(
                    "Pants",
                    traitsMetadata.getPants(current),
                    true
                );
            }
            if (i == 2 && current != 0) {
                parts[i] = _getTraitString(
                    "Shirt",
                    traitsMetadata.getShirt(current),
                    true
                );
            }
            if (i == 3 && current != 0) {
                parts[i] = _getTraitString(
                    "Logo",
                    traitsMetadata.getLogo(current),
                    true
                );
            }
            if (i == 4 && current != 0) {
                parts[i] = _getTraitString(
                    "Clothing item",
                    traitsMetadata.getClothingItem(current),
                    true
                );
            }
            if (i == 5 && current != 0) {
                parts[i] = _getTraitString(
                    "Gloves",
                    traitsMetadata.getGloves(current),
                    true
                );
            }

            if (i == 6 && current != 0) {
                parts[i] = _getTraitString(
                    "Hat",
                    traitsMetadata.getHat(current),
                    true
                );
            }
            if (i == 8 && current != 0) {
                parts[7] = _getTraitString(
                    "Item",
                    traitsMetadata.getItem(current),
                    true
                );
            }
            if (i == 9 && current != 0) {
                parts[8] = _getTraitString(
                    "Special",
                    traitsMetadata.getSpecial(current),
                    false
                );
            }
        }

        return
            string(
                abi.encodePacked(
                    parts[0],
                    parts[1],
                    parts[2],
                    parts[3],
                    parts[4],
                    parts[5],
                    parts[6],
                    parts[7],
                    parts[8]
                )
            );
    }

    function getTraits(bytes32 _seed)
        public
        pure
        returns (uint256[10] memory traits)
    {
        uint256 seed = uint256(_seed);

        Seeds memory seeds = Seeds({
            one: uint256(uint16(seed >> 16)),
            two: uint256(uint16(seed >> 32)),
            three: uint256(uint16(seed >> 48)),
            four: uint256(uint16(seed >> 64)),
            five: uint256(uint16(seed >> 80)),
            six: uint256(uint16(seed >> 96)),
            seven: uint256(uint16(seed >> 112)),
            eight: uint256(uint16(seed >> 128)),
            nine: uint256(uint16(seed >> 144)),
            ten: uint256(uint16(seed >> 160))
        });

        traits = [
            // back
            _r(seeds.one, 1, 100) <= 10 ? _r(seeds.one, 1, 2) : 0,
            // pants
            _r(seeds.two, 1, 100) <= 2 ? 0 : _r(seeds.two, 1, 100) <= 50
                ? _r(seed, 59, 62)
                : _r(seed, 72, 75),
            // shirt
            _r(seeds.three, 1, 100) <= 96 ? _r(seeds.three, 76, 83) : 0,
            // logo
            _r(seeds.four, 1, 100) <= 35 ? _r(seeds.four, 50, 58) : 0,
            // clothing item
            _r(seeds.five, 1, 100) <= 25 ? _r(seeds.five, 3, 15) : 0,
            // gloves
            _r(seeds.six, 1, 100) <= 50 ? _r(seeds.six, 16, 17) : 0,
            //hat
            _r(seeds.seven, 1, 100) <= 45 ? _r(seeds.seven, 18, 39) : 0,
            //kit front
            0,
            // hand
            _r(seeds.eight + 1, 1, 100) <= 25 ? _r(seeds.eight, 63, 71) : 0,
            // kit
            _r(seeds.nine, 1, 100) <= 10 ? _r(seeds.nine, 1, 4) : 0
        ];

        uint256 kit = traits[9];

        if (kit != 0) {
            if (kit == 1) {
                traits[0] = 49;
                traits[7] = 40;
            }
            if (kit == 2) {
                traits[0] = 41;
                traits[7] = 42;
                traits[6] = 43;
            }
            if (kit == 3) {
                traits[7] = 45;
                traits[0] = 44;
            }
            if (kit == 4) {
                traits[0] = 46;
                traits[7] = 47;
                traits[6] = 48;
            }
        }
    }

    function getSvg(bytes32 _seed) public view returns (string memory) {
        uint256[10] memory traits = getTraits(_seed);
        return _getSvg(traits);
    }

    function _getSvg(uint256[10] memory traits)
        private
        view
        returns (string memory)
    {
        string[9] memory parts;

        for (uint256 i = 0; i < traits.length; i++) {
            uint256 tile = traits[i];
            if (tile == 0) {
                parts[i] = "";
                continue;
            }

            uint256 col = (tile % 3) * 40;
            uint256 row = (tile / 3) * 40;
            parts[i] = _getUseString(col, row);
        }

        return
            string(
                abi.encodePacked(
                    _svgStart(),
                    "<rect width='40' height='40' fill='#f8f8f8' />",
                    parts[0],
                    _getUseString(0, 0),
                    parts[1],
                    parts[2],
                    parts[3],
                    parts[4],
                    parts[5],
                    parts[6],
                    parts[7],
                    parts[8],
                    "</g></svg>"
                )
            );
    }
}
