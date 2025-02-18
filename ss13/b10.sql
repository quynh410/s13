create database ss13;
use ss13;

CREATE TABLE course_fees (

    course_id INT PRIMARY KEY,

    fee DECIMAL(10,2) NOT NULL,

    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE

);

CREATE TABLE student_wallets (

    student_id INT PRIMARY KEY,

    balance DECIMAL(10,2) NOT NULL DEFAULT 0,

    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE

);
INSERT INTO course_fees (course_id, fee) VALUES

(1, 100.00), -- Lập trình C: 100$

(2, 150.00); -- Cơ sở dữ liệu: 150$

 

INSERT INTO student_wallets (student_id, balance) VALUES

(1, 200.00), -- Nguyễn Văn An có 200$

(2, 50.00);  -- Trần Thị Ba chỉ có 50$




delimiter &&

create procedure enroll_student(
    in p_student_name varchar(50),
    in p_course_name varchar(100)
)
begin
    declare v_student_id int;
    declare v_course_id int;
    declare v_balance decimal(10,2);
    declare v_fee decimal(10,2);
    declare v_available_seats int;
    
    -- bắt đầu transaction
    start transaction;

    -- kiểm tra sinh viên có tồn tại không
    select student_id into v_student_id from students where student_name = p_student_name;
    if v_student_id is null then
        insert into enrollments_history (student_id, course_id, action)
        values (null, null, 'failed: student does not exist');
        rollback;
        signal sqlstate '45000' set message_text = 'error: student does not exist';
    end if;

    -- kiểm tra môn học có tồn tại không
    select course_id, available_seats into v_course_id, v_available_seats from courses where course_name = p_course_name;
    if v_course_id is null then
        insert into enrollments_history (student_id, course_id, action)
        values (v_student_id, null, 'failed: course does not exist');
        rollback;
        signal sqlstate '45000' set message_text = 'error: course does not exist';
    end if;

    -- kiểm tra sinh viên đã đăng ký môn học này chưa
    if exists (select 1 from enrollments where student_id = v_student_id and course_id = v_course_id) then
        insert into enrollments_history (student_id, course_id, action)
        values (v_student_id, v_course_id, 'failed: already enrolled');
        rollback;
        signal sqlstate '45000' set message_text = 'error: already enrolled';
    end if;

    -- kiểm tra số lượng chỗ trống
    if v_available_seats <= 0 then
        insert into enrollments_history (student_id, course_id, action)
        values (v_student_id, v_course_id, 'failed: no available seats');
        rollback;
        signal sqlstate '45000' set message_text = 'error: no available seats';
    end if;

    -- kiểm tra số dư tài khoản của sinh viên
    select balance into v_balance from student_wallets where student_id = v_student_id;
    select fee into v_fee from course_fees where course_id = v_course_id;

    if v_balance < v_fee then
        insert into enrollments_history (student_id, course_id, action)
        values (v_student_id, v_course_id, 'failed: insufficient balance');
        rollback;
        signal sqlstate '45000' set message_text = 'error: insufficient balance';
    end if;

    -- thực hiện đăng ký môn học
    insert into enrollments (student_id, course_id) values (v_student_id, v_course_id);

    -- trừ tiền học phí từ ví sinh viên
    update student_wallets set balance = balance - v_fee where student_id = v_student_id;

    -- giảm số lượng chỗ trống của môn học
    update courses set available_seats = available_seats - 1 where course_id = v_course_id;

    -- ghi vào lịch sử đăng ký
    insert into enrollments_history (student_id, course_id, action)
    values (v_student_id, v_course_id, 'registered');

    -- commit transaction
    commit;
end 

delimiter &&;
call enroll_student('nguyễn văn an', 'lập trình c');
select * from student_wallets;
