pragma solidity 0.5.13;
library Util {
    function parseUsdPrice(string memory s) pure public returns (uint result) {
        bytes memory b = bytes(s);
        result = 0;
        uint dotted = 2;
        uint stop = b.length;
        for (uint i = 0; i < stop; i++) {
            if(b[i] == ".") {
                if(b.length - i > 3){
                    stop = i + 3;
                    dotted = 0;
                } else
                    dotted -= b.length - i-1;
            }
            else {
                uint c = uint(uint8(b[i]));
                if (c >= 48 && c <= 57) {
                    result = result * 10 + (c - 48);
                }
            }
        }
        result *= 10**dotted;
    }
    function concat(string memory _a, string memory _b, string memory _c) public pure returns (string memory){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        string memory abcde = new string(_ba.length + _bb.length + _bc.length);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
        for (uint i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
        for (uint i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
        return string(babcde);
    }
    function concat(string memory _a, string memory _b) public pure returns (string memory) {
        return concat(_a, _b, "");
    }
}

