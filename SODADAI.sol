pragma solidity 0.5.13;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "https://github.com/provable-things/ethereum-api/provableAPI.sol";
import "./SODADAO.sol";
import "./Util.sol";

contract SODADAI is usingProvable, SODADAO { using SafeMath for uint; using Util for string;

    constructor() SODADAO(ERC20Detailed(0x006b175474e89094c44da98b954eedeac495271d0f)) public {
        query = "json(https://api.hitbtc.com/api/2/public/ticker/BTCDAI).last";
        SODABTC = ERC20Detailed(0x00669498dd7f02674b22eec994dcffc34dc8cbf32c);
        decimalScaling = 1e10;
        lastRate = 90411;
    } 
    
    string private query;
    uint   private decimalScaling;
    uint   public  nextID = 1; 
    uint   public  lastRate; // APR / 365 * 1e9 
    
    mapping (bytes32 => uint) private loanQueries;
    mapping (bytes32 => uint) private liqudationQueries;
    mapping (uint    => uint) public  ratesHistory;
    mapping (uint    => Loan) public  loan;
    
    IERC20 private SODABTC;
    
    event LoanIssued   (uint indexed id);
    event LoanRejected (uint indexed id);
    event Liquidation  (uint indexed id, string cause);
    event LoanAproved  (uint indexed id, address indexed borrower, uint amount, uint collateral);
    event LoanRepayment(uint indexed id, uint interestAmount, uint repaymentAmount);
    event CollateralReplenishment(uint indexed id, uint amount);
        
    enum LoanState {Repaid, PriceRequestPending, Active, Rejected , Liquidated}
    struct Loan {
        address borrower;
        LoanState state;
        uint taken;
        uint collateral;
        uint amount;
        uint lastRate;
        uint lastRepay;
    }
    
    modifier oraclized(){
        uint o_price = provable_getPrice("URL");
        require(o_price <= msg.value);
        if(o_price != msg.value) msg.sender.transfer(msg.value - o_price);
        _;
    }
    
    function setRate(uint value) public onlyOwner {
        require(ratesHistory[now / 1 days] == 0, "today's rate is already set");
        ratesHistory[now / 1 days] = lastRate = value;
    }
    
    function borrow(address borrower, uint amount, uint collateral) public payable oraclized returns(uint loan_id) {
        require(currency.balanceOf(address(pool)) >= amount, "too large loan pool has no funds");
        require(SODABTC.balanceOf(borrower) >= collateral, "insufficient funds");
        require(SODABTC.allowance(borrower, address(this)) >= collateral, "insufficient funds. use approve");
        
        loan_id = nextID++;
        loan[loan_id] = Loan(
            borrower,
            LoanState.PriceRequestPending,
            now,
            collateral,
            amount,
            lastRate,
            0
        );
        
        loanQueries[ provable_query("URL", query) ] = loan_id;
        emit LoanIssued(loan_id);  
    }
    
    function repay(uint loan_id, uint amount) public {
        Loan storage _loan = loan[loan_id];
        uint interest = interestAmount(loan_id);
        require(amount >= interest, "the amount of payment must exceed the interest");
        currency.transferFrom(_loan.borrower, address(this), interest);
        uint repaymentAmount = amount.sub(interest);
        if(_loan.amount > repaymentAmount){
            currency.transferFrom(_loan.borrower, address(pool), repaymentAmount);
            _loan.amount -= repaymentAmount;
            _loan.lastRate = this.lastRate();
            _loan.lastRepay = now.div(1 days);
            emit LoanRepayment(loan_id, interest, repaymentAmount);
        } else {
            currency.transferFrom(_loan.borrower, address(pool), _loan.amount);
            SODABTC.transfer(_loan.borrower, _loan.collateral);
            delete loan[loan_id];
            emit LoanRepayment(loan_id, interest, _loan.amount);
        }
    }
    
    function replenishCollateral(uint loan_id, uint amount) public {
        Loan storage _loan = loan[loan_id];
        require(_loan.state == LoanState.Active, "the loan isn't active");
        SODABTC.transferFrom(_loan.borrower, address(this), amount);
        _loan.collateral = _loan.collateral.add(amount); 
        emit CollateralReplenishment(loan_id, amount);
    }
    
    function liquidate(uint loan_id) public payable {
        Loan storage _loan = loan[loan_id];
        require(_loan.state == LoanState.Active, "the loan isn't active");
        if(_loan.taken + 90 days < now)
            _liquidate(loan_id, "loan was taken more then 90 days ago");
        else
            _liquidateByPrice(loan_id);
    }
    
    function interestAmount(uint loan_id) public view returns (uint) {
        Loan memory _loan = loan[loan_id];
        uint rate = _loan.lastRate;
        uint start = _loan.lastRepay;
        uint today = now.div(1 days);
        uint sum = 0;
        for(uint i = start; i < today; i++)
            sum += rate = ratesHistory[i] > 0 ? ratesHistory[i]: rate;
        return _loan.amount.mul(sum).div(1e9);
    }
    
    function __callback(bytes32 myid, string memory result) public {
        // require(msg.sender == provable_cbAddress(), "wrong msg.sender");
        uint price = result.parseUsdPrice();
        
        if (loanQueries[myid] > 0){
            _borrow(loanQueries[myid], price);
            delete loanQueries[myid];
        } else if (liqudationQueries[myid] > 0){
            _liquidateByPrice(liqudationQueries[myid], price);
            delete liqudationQueries[myid];
        } else revert('unexpected query');
        
    }
    
    function _borrow(uint loan_id, uint price_x100) private {
        Loan storage _loan = loan[loan_id];
        require(_loan.state == LoanState.PriceRequestPending, "bad loan");
        if(_loan.collateral.mul(price_x100).mul(decimalScaling) > _loan.amount.mul(135)) {
            SODABTC.transferFrom(_loan.borrower, address(this), _loan.collateral);
            pool.send(_loan.borrower, _loan.amount);
            _loan.lastRepay = now.div(1 days);
            _loan.state = LoanState.Active;
            
            emit LoanAproved( loan_id, _loan.borrower, _loan.amount, _loan.collateral);
        } else {
            _loan.state = LoanState.Rejected;
            emit LoanRejected(loan_id);
        }
    }
    
    function _liquidateByPrice(uint loan_id) private oraclized {
        liqudationQueries[ provable_query("URL", query) ] = loan_id;
    }
    
    function _liquidateByPrice(uint loan_id, uint price_x100) private {
        Loan storage _loan = loan[loan_id];
        require(_loan.amount.mul(110) > _loan.collateral.mul(price_x100).mul(decimalScaling), "loan secured by more than 110%" );
        _liquidate(loan_id, "liquidation by price");
    }
    
    function _liquidate(uint loan_id, string memory message) private {
        Loan storage _loan = loan[loan_id];
        SODABTC.transfer(owner(), _loan.collateral);
        _loan.amount = 0;
        _loan.state = LoanState.Liquidated;
        emit Liquidation(loan_id, message);
    }
}




