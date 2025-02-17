use ss13;

create table employees(
	emp_id int primary key auto_increment,
    emp_name varchar(50),
    salary decimal(10,2)
);

create table company_funds(
	fund_id int primary key auto_increment,
    balance decimal(15,2)
);

create table payroll(
	payroll_id int primary key auto_increment,
    emp_id int,
    foreign key (emp_id) references employees(emp_id),
    salary decimal(10,2),
    pay_date date
);

create table transaction_log(
	log_id int primary key auto_increment,
    log_message text not null,
    log_time timestamp default current_timestamp
) engine 'MyISAM';

INSERT INTO company_funds (balance) VALUES (50000.00);

INSERT INTO employees (emp_name, salary) VALUES
('Nguyễn Văn An', 5000.00),
('Trần Thị Bốn', 40000.00),
('Lê Văn Cường', 3500.00),
('Hoàng Thị Dung', 4500.00),
('Phạm Văn Em', 3800.00);



create table bank (
    bank_id int auto_increment primary key,
    bank_name varchar(255) not null,
    status enum('ACTIVE', 'ERROR') not null default 'ACTIVE'
);
insert into bank (bank_id, bank_name, status) values 
(1, 'VietinBank', 'ACTIVE'),   
(2, 'Sacombank', 'ERROR'),    
(3, 'Agribank', 'ACTIVE');
alter table company_funds 
add column bank_id int, 
add foreign key (bank_id) references bank(bank_id);
update company_funds set bank_id = 1 where balance = 50000.00;

insert into company_funds (balance, bank_id) values (45000.00, 2);


delimiter &&
create trigger CheckBankStatus 
before insert on payroll 
for each row 
begin
    declare v_status enum('ACTIVE', 'ERROR');
    -- Lấy trạng thái ngân hàng của công ty đang sử dụng
    select status into v_status 
    from bank 
    where bank_id = (select bank_id from company_funds limit 1);
    -- Nếu ngân hàng gặp sự cố, báo lỗi và ngăn chặn giao dịch
    if v_status = 'ERROR' then
        signal sqlstate '45000' 
        set message_text = 'Bank is in ERROR status. Cannot process payroll!';
    end if;
end 
delimiter &&;
delimiter &&
create procedure TransferSalary(in p_emp_id int)
begin
    declare v_salary decimal(10,2);
    declare v_balance decimal(15,2);
    declare v_bank_status enum('ACTIVE', 'ERROR');
    declare v_exists int default 0;

    -- Bắt đầu transaction
    start transaction;
    -- Kiểm tra nhân viên có tồn tại không
    select count(*) into v_exists 
    from employees 
    where emp_id = p_emp_id;

    if v_exists = 0 then
        insert into transaction_log (log_message) 
        values (concat('Error: Employee ID ', p_emp_id, ' does not exist.'));
        rollback;
        leave;
    end if;
    -- Lấy lương của nhân viên
    select salary into v_salary 
    from employees 
    where emp_id = p_emp_id;
    -- Lấy số dư của quỹ công ty
    select balance, bank.status into v_balance, v_bank_status 
    from company_funds 
    join bank on company_funds.bank_id = bank.bank_id 
    limit 1;
    -- Kiểm tra trạng thái ngân hàng
    if v_bank_status = 'ERROR' then
        insert into transaction_log (log_message) 
        values ('Error: Bank is in ERROR status. Cannot process payroll.');
        rollback;
        leave;
    end if;
    -- Kiểm tra quỹ có đủ tiền không
    if v_balance < v_salary then
        insert into transaction_log (log_message) 
        values ('Error: Insufficient company funds. Payroll not processed.');
        rollback;
        leave;
    end if;
    -- Trừ tiền từ quỹ công ty
    update company_funds 
    set balance = balance - v_salary 
    where bank_id = (select bank_id from company_funds limit 1);
    -- Thêm vào bảng payroll
    insert into payroll (emp_id, salary, pay_date) 
    values (p_emp_id, v_salary, curdate());
    -- Cập nhật ngày trả lương trong employees
    update employees 
    set last_pay_date = curdate() 
    where emp_id = p_emp_id;
    -- Ghi log thành công
    insert into transaction_log (log_message) 
    values (concat('Success: Paid salary ', v_salary, ' to employee ID ', p_emp_id));
    -- Commit transaction
    commit;
end 
delimiter &&;
call TransferSalary(1);
select * from employees;
select * from company_funds;
select * from payroll;
select * from transaction_log;

