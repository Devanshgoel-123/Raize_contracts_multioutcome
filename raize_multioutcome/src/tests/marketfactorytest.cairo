use starknet::contract_address_const;
use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use snforge_std::{
    start_cheat_caller_address,
    stop_cheat_caller_address
};
use raize_multioutcome::MarketFactory::{ IMarketFactoryDispatcher,IMarketFactoryDispatcherTrait};

fn deploy_contract() -> ContractAddress {
    let contract = declare("MarketFactory").unwrap().contract_class(); //Returns a Result type containing the contract class
    // - '.unwrap()' extracts the value, panicking if there's an error
    let mut calldata= ArrayTrait::new();
    calldata.append(contract_address_const::<0x024331d29c91ba937830735afe697bd50503301ec952b7733e6187d7729e7831>().into()); //this is raw felt252 but contract needs contract address
    /// Explicitly convert ContractAddress → felt252
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn create_market() {
    let contract_address = deploy_contract();
    let dispatcher = IMarketFactoryDispatcher { contract_address };
    start_cheat_caller_address(contract_address, contract_address_const::<0x024331d29c91ba937830735afe697bd50503301ec952b7733e6187d7729e7831>());
    assert(dispatcher.get_owner() ==  contract_address_const::<0x024331d29c91ba937830735afe697bd50503301ec952b7733e6187d7729e7831>(),'Not Owner');
    dispatcher.create_multi_outcome_market(
        "Ipl 2025 winner",
        "Who will Win IPL 2025?",
        ('RCB', 'PBKS', 'MI', 'GT'),
        4,
        "trump.png",
        2018704106
    );
    stop_cheat_caller_address(contract_address);
    let market_count = dispatcher.get_multi_outcome_market_count();
    assert(market_count == 1, 'market count should be 1');
}

// should set treasury wallet 
#[test]
fn shouldSetTreasury() {
    let marketContract = deploy_contract();
    start_cheat_caller_address(marketContract, contract_address_const::<0x024331d29c91ba937830735afe697bd50503301ec952b7733e6187d7729e7831>());
    let dispatcher = IMarketFactoryDispatcher { contract_address: marketContract };
    dispatcher.set_treasury_wallet(contract_address_const::<1>());
    let treasury = dispatcher.get_treasury_wallet();
    assert(treasury == contract_address_const::<1>(), 'treasury not set!');
}




