use ss13;
create table accounts(
	account_id int primary key auto_increment,
    account_name varchar(50),
    balance decimal(10,2)
);
drop table accounts;
INSERT INTO accounts (account_name, balance) 
VALUES 
('Nguyễn Văn An', 1000.00),
('Trần Thị Bảy', 500.00);

delimiter &&
create procedure transferfunds(
    in from_account int,
    in to_account int,
    in amount decimal(10,2)
)
begin
    declare insufficient_funds boolean default false;
    declare exit handler for sqlexception
    begin
        rollback;
        signal sqlstate '45000' set message_text = 'transaction failed. rolled back.';
    end;
    start transaction;
    -- kiể tra số dư tài khoản gửi
    if (select balance from accounts where account_id = from_account) < amount then
        set insufficient_funds = true;
    end if;
    -- nếu số dư không đủ, rollback và dừng giao dịch
    if insufficient_funds then
        rollback;
        signal sqlstate '45000' set message_text = 'insufficient funds';
    else
        -- trừ tiền từ tài khoản gửi
        update accounts 
        set balance = balance - amount 
        where account_id = from_account;
        
        -- cộng tiền vào tài khoản nhận
        update accounts 
        set balance = balance + amount 
        where account_id = to_account;
        
        commit;
    end if;
end 
delimiter &&;
CALL TransferFunds(1, 2, 200.00);

