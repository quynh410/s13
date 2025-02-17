create database ss13;
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

/*
	1. Tạo bảng transaction_log
    2. Tạo 1 procedure
		INPUT: employeeId
        process:
			1. Kiểm tra employeeId có tồn tại không?
				- Sai -> Ghi log bảng transaction_log và rollBack
                - Đúng
					2. Kiểm tra số dư của công ty (company_funds) > salary (employee -> employeeId)
						- Sai: GHi log bảng transaction_log và rollback
                        - Đúng:
							+ Trừ số dư của công ty
                            + Ghi dữ liệu ra payroll
                            + Ghi log bảng transaction_log
                            + commit
*/

delimiter &&
create procedure transferMoneyEmployee(p_emp_id int, c_fund_id int)
begin
	start transaction;
	if (select count(emp_id) from employees where emp_id = p_emp_id) = 0 or (select count(fund_id) from company_funds where fund_id = c_fund_id) then
		insert into transaction_log(log_message)
        values('Nhân viên hoặc công ty không tồn tại');
        rollback;
	else
		if (select salary from employees where emp_id = p_emp_id) > (select balance from company_funds where fund_id = c_fund_id) then
			insert into transaction_log(log_message)
			values('Số dư của công ty không đủ');
            rollback;
		else	
			update company_funds
            set balance = balance - (select salary from employees where emp_id = p_emp_id)
            where fund_id = c_fund_id;
            
            insert into payroll(emp_id, salary, pay_date)
            values(p_emp_id, (select salary from employees where emp_id = p_emp_id), now());
            
            insert into transaction_log(log_message)
			values('Chuyển tiền thành công');
            commit;
        end if;
	end if;
end &&
delimiter &&

call transferMoneyEmployee(1, 1);