
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                              AETHOS PROTECT
    //////////////////////////////////////////////////////////////*/




    IUniswapV2Router01 uniswap;

    uint256 public timeWindow = 60; // 

    uint256 public maxSellPercentage = 5; // 
    uint256 public totalSoldInWindow; // 
    uint256 public lastSoldResetTime; // 

    uint256 public maxBuyPercentage = 5;
    uint256 public totalBoughtInWindow; 
    uint256 public lastBoughtResetTime; 




    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/




    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _uniswap,
        string memory _name,
        string memory _symbol
    ) {
        lastSoldResetTime = block.timestamp;
        uniswap = IUniswapV2Router01(_uniswap);
        name = _name;
        symbol = _symbol;
        decimals = 18;

    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        _beforeTokenTransfer(msg.sender,to,amount);
        balanceOf[msg.sender] -= amount;
        

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;

    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {

        _beforeTokenTransfer(from,to,amount);


        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/



    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }


    function _beforeTokenTransfer(address from, address to, uint256 amount) internal {
        address uniswapPair = IUniswapV2Factory(uniswap.factory()).getPair(address(this),uniswap.WETH());
        if (to == uniswapPair) {
            if(balanceOf[to] != 0){
                _updateWindow(from,to);
                _checkGlobalSellLimit(amount);
            }
        }
        if(from == uniswapPair) {
            _updateWindow(from,to);
            _checkGlobalBuyLimit(amount);
        }
    }

    function _updateWindow(address from, address to) internal {
        address uniswapPair = IUniswapV2Factory(uniswap.factory()).getPair(address(this),uniswap.WETH());
        if(to == uniswapPair){
            if (block.timestamp > lastSoldResetTime + timeWindow) {
                totalSoldInWindow = 0;
                lastSoldResetTime = block.timestamp;
            }
        }
        if(from == uniswapPair){
            if (block.timestamp > lastBoughtResetTime + timeWindow) {
                totalBoughtInWindow = 0;
                lastBoughtResetTime = block.timestamp;
            }       
        }
    }

    function _checkGlobalSellLimit(uint256 amount) internal {
        address uniswapPair = IUniswapV2Factory(uniswap.factory()).getPair(address(this),uniswap.WETH());
        IUniswapV2Pair pair = IUniswapV2Pair(uniswapPair);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        uint112 reserve = address(this) == pair.token0() ? reserve0 : reserve1;
        require(
            totalSoldInWindow + amount <= (reserve * maxSellPercentage) / 100,
            "Exceeds global sell limit"
        );
        totalSoldInWindow += amount;
    }

    function _checkGlobalBuyLimit(uint256 amount) internal {
        address uniswapPair = IUniswapV2Factory(uniswap.factory()).getPair(address(this),uniswap.WETH());
        IUniswapV2Pair pair = IUniswapV2Pair(uniswapPair);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        uint112 reserve = address(this) == pair.token0() ? reserve0 : reserve1;
        require(
            totalBoughtInWindow + amount <= (reserve * maxBuyPercentage) / 100,
            "Exceeds global buy limit"
        );
        totalBoughtInWindow += amount;
    }

}

pragma solidity >=0.5.0;
interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

pragma solidity >=0.5.0;
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}
