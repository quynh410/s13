use ss13;
CREATE TABLE students (
    student_id INT PRIMARY KEY AUTO_INCREMENT,
    student_name VARCHAR(50)
);

CREATE TABLE courses (
    course_id INT PRIMARY KEY AUTO_INCREMENT,
    course_name VARCHAR(100),
    available_seats INT NOT NULL
);

CREATE TABLE enrollments (
    enrollment_id INT PRIMARY KEY AUTO_INCREMENT,
    student_id INT,
    course_id INT,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (course_id) REFERENCES courses(course_id)
);
INSERT INTO students (student_name) VALUES ('Nguyễn Văn An'), ('Trần Thị Ba');

INSERT INTO courses (course_name, available_seats) VALUES 
('Lập trình C', 25), 
('Cơ sở dữ liệu', 22);



create table enrollments_history (
    history_id int auto_increment primary key,
    student_id int not null,
    course_id int not null,
    action varchar(50) not null check (action in ('registered', 'failed')),
    timestamp datetime default current_timestamp,
    foreign key (student_id) references students(student_id),
    foreign key (course_id) references courses(course_id)
);




delimiter &&
create procedure register_course(
    in p_student_name varchar(50),
    in p_course_name varchar(100)
)
begin
    declare v_student_id int;
    declare v_course_id int;
    declare v_available_seats int;
    declare v_already_registered int default 0;
    -- Bắt đầu transaction
    start transaction;
    -- Lấy student_id từ tên sinh viên
    select student_id into v_student_id 
    from students 
    where student_name = p_student_name
    limit 1;
    -- Lấy course_id và số chỗ trống từ tên môn học
    select course_id, available_seats into v_course_id, v_available_seats 
    from courses 
    where course_name = p_course_name
    limit 1;
    -- Kểm tra nếu sinh viên đã đăng ký môn học này chưa
    select count(*) into v_already_registered 
    from enrollments 
    where student_id = v_student_id and course_id = v_course_id;

    if v_already_registered > 0 then
        -- Nếu đã đăng ký, rollback và thoát
        rollback;
        signal sqlstate '45000'
        set message_text = 'Student already registered for this course!';
    end if;
    -- Kiểm tra số chỗ trống
    if v_available_seats > 0 then
        -- Thêm sinh viên vào bảng enrollments
        insert into enrollments(student_id, course_id) 
        values (v_student_id, v_course_id);
        -- Giảm số chỗ trống của môn học đi 1
        update courses 
        set available_seats = available_seats - 1 
        where course_id = v_course_id;
        -- Ghi vào bảng enrollment_history với trạng thái REGISTERED
        insert into enrollments_history(student_id, course_id, action)
        values (v_student_id, v_course_id, 'registered');
        -- Commit transaction
        commit;
    else
        -- Nếu không còn chỗ trống, ghi lịch sử với trạng thái FAILED
        insert into enrollments_history(student_id, course_id, action)
        values (v_student_id, v_course_id, 'failed');
        -- Rollback transaction để đảm bảo không có thay đổi dữ liệu
        rollback;
        signal sqlstate '45000'
        set message_text = 'Course is full, registration failed!';
    end if;
end 
delimiter &&;
call register_course('John Doe', 'Database Systems');
select * from enrollments;
select * from courses;
select * from enrollments_history;
