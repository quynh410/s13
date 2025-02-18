create database ss13;
use ss13;

create table account (
    acc_id int primary key auto_increment,
    emp_id int,
    bank_id int,
    amount_added decimal(15,2),
    total_amount decimal(15,2),
    foreign key (emp_id) references employees(emp_id),
    foreign key (bank_id) references bank(bank_id)
);


delimiter &&
create procedure TransferSalaryAll()
begin
    declare done int default 0;
    declare v_emp_id int;
    declare v_salary decimal(10,2);
    declare v_total_salary decimal(15,2) default 0;
    declare v_company_balance decimal(15,2);
    declare v_bank_status enum('ACTIVE', 'ERROR');
    declare v_emp_count int default 0;
    -- Cursor để duyệt qua danh sách nhân viên
    declare cur cursor for 
        select emp_id, salary from employees;
    declare continue handler for not found set done = 1;
    -- Lấy số dư của quỹ công ty
    select balance into v_company_balance from company_funds where fund_id = 1;
    -- Lấy trạng thái ngân hàng của công ty
	select status into v_bank_status from bank where bank_id = 1;
    -- Kiểm tra nếu ngân hàng gặp lỗi
    if v_bank_status = 'ERROR' then
        insert into transaction_log (log_message)
        values ('FAILED: Bank error, transaction aborted');
        signal sqlstate '45000' set message_text = 'Error: Bank is in ERROR status';
    end if;
    -- Tính tổng lương cần trả
    select sum(salary) into v_total_salary from employees;
    -- Kiểm tra nếu quỹ công ty không đủ tiền
    if v_company_balance < v_total_salary then
        insert into transaction_log (log_message)
        values ('FAILED: Insufficient funds, transaction aborted');
        signal sqlstate '45000' set message_text = 'Error: Insufficient company funds';
    end if;
    start transaction;
    open cur;
    read_loop: loop
        fetch cur into v_emp_id, v_salary;
        if done then
            leave read_loop;
        end if;
        -- Trừ tiền từ quỹ công ty
        update company_funds set balance = balance - v_salary where fund_id = 1;
        -- Thêm bản ghi vào bảng payroll (trigger sẽ kiểm tra lỗi ngân hàng)
        insert into payroll (emp_id, salary, pay_date) values (v_emp_id, v_salary, curdate());
        -- Cập nhật tài khoản nhân viên
        update account 
        set total_amount = total_amount + v_salary, 
            amount_added = v_salary 
        where emp_id = v_emp_id;
        -- Đếm số nhân viên đã nhận lương
        set v_emp_count = v_emp_count + 1;
    end loop;
    close cur;
    commit;
    -- Ghi log tổng số nhân viên đã nhận lương
    insert into transaction_log (log_message)
    values (concat('SUCCESS: Paid salary to ', v_emp_count, ' employees'));
end 
delimiter &&;
call TransferSalaryAll();
select * from company_funds;
select * from payroll;
select * from account;
select * from transaction_log;
