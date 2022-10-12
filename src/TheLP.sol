// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "ERC721A/ERC721A.sol";
import "solmate/utils/SSTORE2.sol";
import "solmate/auth/Owned.sol";
import "solmate/utils/LibString.sol";

contract TheLP is ERC721A, Owned {
    using LibString for uint256;

    uint256 public constant DURATION = 30 days;
    uint256 public startTime;
    address public traitsImagePointer;

    mapping(uint256 => bytes32) public tokenIdToSeed;

    constructor() ERC721A("The LP", "LP") Owned(msg.sender) {
        // Team mint
    }

    function setTraitsImage(string calldata data) external onlyOwner {
        traitsImagePointer = SSTORE2.write(bytes(data));
    }

    function getTraitsImage() public view returns (string memory) {
        return string(SSTORE2.read(traitsImagePointer));
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
                    '<svg viewBox="0 0 40 40" width="250"><defs><image height="1120" width="120" image-rendering="pixelated" id="s" href="',
                    getTraitsImage(),
                    '" /></defs>'
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

    // TODO: add non-reentrant
    function mint() public {
        tokenIdToSeed[1] = keccak256(
            abi.encodePacked(blockhash(block.number - 1), uint256(1))
        );
    }

    function getSvgDataUri(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(bytes(getSvg(tokenId)))
                )
            );
    }

    function getSvg(uint256 tokenId) public view returns (string memory) {
        uint256 seed = uint256(tokenIdToSeed[tokenId]);
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

        uint256[9] memory traits = [
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
            _r(seeds.eight + 1, 1, 100) <= 25 ? _r(seeds.eight, 63, 71) : 0
        ];

        uint256 kit = _r(seeds.nine, 1, 100) <= 10 ? _r(seeds.nine, 1, 4) : 0;

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
                    "</svg>"
                )
            );
    }
}

//   uint256 nounId = 1;
//         bytes32 k = keccak256(
//             abi.encodePacked(blockhash(block.number - 1), nounId)
//         );
library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}
