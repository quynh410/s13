use ss13;
CREATE TABLE company_funds (
    fund_id INT PRIMARY KEY AUTO_INCREMENT,
    balance DECIMAL(15,2) NOT NULL -- Số dư quỹ công ty
);

CREATE TABLE employees (
    emp_id INT PRIMARY KEY AUTO_INCREMENT,
    emp_name VARCHAR(50) NOT NULL,   -- Tên nhân viên
    salary DECIMAL(10,2) NOT NULL    -- Lương nhân viên
);

CREATE TABLE payroll (
    payroll_id INT PRIMARY KEY AUTO_INCREMENT,
    emp_id INT,                      -- ID nhân viên (FK)
    salary DECIMAL(10,2) NOT NULL,   -- Lương được nhận
    pay_date DATE NOT NULL,          -- Ngày nhận lương
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id)
);


INSERT INTO company_funds (balance) VALUES (50000.00);

INSERT INTO employees (emp_name, salary) VALUES
('Nguyễn Văn An', 5000.00),
('Trần Thị Bốn', 4000.00),
('Lê Văn Cường', 3500.00),
('Hoàng Thị Dung', 4500.00),
('Phạm Văn Em', 3800.00);

delimiter &&

create procedure transfer_salary(
    in p_emp_id int
)
begin
    declare v_salary decimal(10,2);
    declare v_balance decimal(15,2);
    declare v_bank_status int default 1; -- giả lập trạng thái hệ thống ngân hàng (1: hoạt động, 0: lỗi)
    -- lấy lương nhân viên
    select salary into v_salary 
    from employees 
    where emp_id = p_emp_id;
    -- lấy số dư quỹ công ty
    select balance into v_balance 
    from company_funds 
    limit 1;
    -- kiểm tra nếu quỹ không đủ trả lương
    if v_balance < v_salary then
        rollback;
        signal sqlstate '45000'
        set message_text = 'quỹ công ty không đủ để trả lương';
    else
        -- bắt đầu giao dịch
        start transaction;
        -- trừ lương của nhân viên khỏi quỹ công ty
        update company_funds 
        set balance = balance - v_salary
        limit 1;
        -- thêm bản ghi vào bảng payroll
        insert into payroll (emp_id, salary, pay_date) 
        values (p_emp_id, v_salary, curdate());
        -- kiểm tra trạng thái hệ thống ngân hàng
        if v_bank_status = 0 then
            rollback;
            signal sqlstate '45000'
            set message_text = 'hệ thống ngân hàng gặp lỗi, giao dịch bị hủy';
        else
            -- xác nhận giao dịch
            commit;
        end if;
    end if;
end 
delimiter &&;
call transfer_salary(1);

