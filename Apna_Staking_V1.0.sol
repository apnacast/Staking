// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract Staking {
    struct InvestmentPlan {
        uint256 minSpend; // in USD
        uint256 maxSpend; // in USD
        uint256 duration; // in years
        uint256 rewards; // in percentage
        uint256 startTime; // in sec (UNIX time)
        uint256 stopTime; // in sec (UNIX time)
    }

    struct Tariff {
        uint256 id;
        uint256 invested;
        uint256 depositTime;
        uint256 payAt; //in seconds
        uint256 percent;
        uint256 withdrawn;
        bool isWithdraw;
    }

    event CreateNewInvestmentPlan(
        uint256 minSpend,
        uint256 maxSpend,
        uint256 duration,
        uint256 rewards,
        uint256 startTime,
        uint256 stopTime,
        address planCreator
    );
    
    event DepositAt(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);
    event TransferOwnership(address user);
    event Received(address, uint256);
    event PriceUpdate(address, uint256);

    uint256 public totalInvested;
    uint256 public totalWithdrawal;
    address public owner;
    uint256 planId;
    uint256 price;

    IERC20 constant TOKEN = IERC20(0xd9145CCE52D386f254917e481eB44e9943F39138);
    mapping(uint256 => InvestmentPlan) public investmentPlans;
    mapping(address => uint256) public stakingId;
    mapping(address => mapping(uint256 => Tariff)) public tariff; // address -> id -> teriff

    modifier onlyOwner() {
        require(msg.sender == owner, "you are not the owner!");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        price = newPrice;
        emit PriceUpdate(msg.sender, newPrice);
    }

    function getPrice() external view onlyOwner returns (uint256) {
        return price;
    }

    function createNewInvestmentPlan(
        uint256 minSpend,
        uint256 maxSpend,
        uint256 duration,
        uint256 rewards,
        uint256 startTime,
        uint256 stopTime
    ) external onlyOwner {
        planId++;
        investmentPlans[planId] = InvestmentPlan({
            minSpend: minSpend,
            maxSpend: maxSpend,
            duration: duration,
            rewards: rewards,
            startTime: block.timestamp + startTime,
            stopTime: block.timestamp + stopTime
        });

        emit CreateNewInvestmentPlan(
            minSpend,
            maxSpend,
            duration,
            rewards,
            startTime,
            stopTime,
            msg.sender
        );
    }

    function deposit(
        uint256 tokenAmount,
        uint256 investmentPlan
    ) external returns (uint256) {
        InvestmentPlan storage plan = investmentPlans[investmentPlan];
        uint256 priceInUsd = (((tokenAmount * price) / 1 ether)) / 10000;
        stakingId[msg.sender]++;
        require(tokenAmount > 0, "amount must be greater than zero");
        require(
            TOKEN.balanceOf(msg.sender) >= tokenAmount,
            "insufficient balance"
        );
        require(
            priceInUsd >= plan.minSpend,
            "minimum requirements are not match"
        );
        require(
            priceInUsd <= plan.maxSpend,
            "check there is batter plan out there!"
        );
        require(
            block.timestamp > plan.startTime,
            "staking not started yet for this Plan, stay tuned!"
        );
        require(
            block.timestamp < plan.stopTime,
            "staking is stopped for this Plan."
        );
        totalInvested += tokenAmount;

        tariff[msg.sender][stakingId[msg.sender]] = Tariff({
            id: stakingId[msg.sender],
            invested: tokenAmount,
            depositTime: block.timestamp,
            payAt: block.timestamp +plan.duration,
            percent: plan.rewards,
            withdrawn: 0,
            isWithdraw: false
        });

        require(
            TOKEN.transferFrom(msg.sender, address(this), tokenAmount),
            "transaction faield"
        );
        emit DepositAt(msg.sender, tokenAmount);
        return (stakingId[msg.sender]);
    }

    // Principal withdraw
    function withdrawStakingTokens(uint256 id) external payable {
        Tariff storage tarrifWithdraw = tariff[msg.sender][id];
        
        require(
            tarrifWithdraw.id > 0 && tarrifWithdraw.id == id,
            "Wrong staking id."
        );
        require(
            block.timestamp >= tarrifWithdraw.payAt,
            "Time not reached"
        );
        require(!tarrifWithdraw.isWithdraw, "already paid");
        uint256 amount = tarrifWithdraw.invested +
            ((tarrifWithdraw.invested *
                tarrifWithdraw.percent) / 100);
        require(
            TOKEN.balanceOf(address(this)) >= amount,
            "currently the exchange doesnt have enough TestTokens , please retry later :=("
        );

        tarrifWithdraw.isWithdraw = true;
        tarrifWithdraw.withdrawn = amount;
        totalWithdrawal += amount;
        emit Withdraw(msg.sender, amount);
        require(
            TOKEN.transfer(msg.sender, amount),
            "transaction failed in withdraw"
        );
    }

    // Owner withdraw token
    function withdrawToken(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "not a valid address");
        require(TOKEN.transfer(to, amount), "contract withdraw fail");
    }

    // Owner withdraw BNB
    function withdrawBNB(
        address payable to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "not a valid address");
        require(amount > 0, "must be greater than zero");
        require(
            TOKEN.balanceOf(address(this)) >= amount,
            "currently the exchange doesnt have enough TestTokens"
        );
        to.transfer(amount);
    }

    // Transfer Ownership
    function transferOwnership(address to) external onlyOwner {
        require(to != address(0), "not a valid address");
        owner = to;
        emit TransferOwnership(owner);
    }

    // Receive BNB functionality
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function balanceOf(address user) external view returns (uint256) {
        return TOKEN.balanceOf(user);
    }
}
