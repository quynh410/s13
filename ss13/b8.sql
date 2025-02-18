create database ss13;
use ss13;


create table student_status (
    student_id int primary key,
    status enum('active', 'graduated', 'suspended') not null,
    foreign key (student_id) references students(student_id)
);

delimiter &&

create procedure enroll_student(
    in p_student_name varchar(50),
    in p_course_name varchar(100)
)
begin
    declare v_student_id int;
    declare v_course_id int;
    declare v_available_seats int;
    declare v_student_status enum('active', 'graduated', 'suspended');

    -- Bắt đầu transaction
    start transaction;

    -- Kiểm tra sinh viên có tồn tại không
    select student_id into v_student_id from students where student_name = p_student_name;
    if v_student_id is null then
        insert into enrollments_history (student_id, course_id, action)
        values (null, null, 'failed: student does not exist');
        rollback;
        signal sqlstate '45000' set message_text = 'Error: Student does not exist';
    end if;

    -- Kiểm tra môn học có tồn tại không
    select course_id, available_seats into v_course_id, v_available_seats from courses where course_name = p_course_name;
    if v_course_id is null then
        insert into enrollments_history (student_id, course_id, action)
        values (v_student_id, null, 'failed: course does not exist');
        rollback;
        signal sqlstate '45000' set message_text = 'Error: Course does not exist';
    end if;

    -- Kiểm tra sinh viên đã đăng ký môn học này chưa
    if exists (select 1 from enrollments where student_id = v_student_id and course_id = v_course_id) then
        insert into enrollments_history (student_id, course_id, action)
        values (v_student_id, v_course_id, 'failed: already enrolled');
        rollback;
        signal sqlstate '45000' set message_text = 'Error: Already enrolled';
    end if;

    -- Kiểm tra trạng thái của sinh viên
    select status into v_student_status from student_status where student_id = v_student_id;
    if v_student_status in ('graduated', 'suspended') then
        insert into enrollments_history (student_id, course_id, action)
        values (v_student_id, v_course_id, 'failed: student not eligible');
        rollback;
        signal sqlstate '45000' set message_text = 'Error: Student not eligible';
    end if;

    -- Kiểm tra môn học còn chỗ trống không
    if v_available_seats > 0 then
        -- Thêm sinh viên vào bảng enrollments
        insert into enrollments (student_id, course_id) values (v_student_id, v_course_id);

        -- Giảm số chỗ trống của môn học đi 1
        update courses set available_seats = available_seats - 1 where course_id = v_course_id;

        -- Ghi lại lịch sử đăng ký
        insert into enrollments_history (student_id, course_id, action)
        values (v_student_id, v_course_id, 'registered');

        -- Commit transaction
        commit;
    else
        insert into enrollments_history (student_id, course_id, action)
        values (v_student_id, v_course_id, 'failed: no available seats');
        rollback;
        signal sqlstate '45000' set message_text = 'Error: No available seats';
    end if;
end 
delimiter &&;

call enroll_student('Nguyễn Văn An', 'Lập trình C');
call enroll_student('Trần Thị Ba', 'Cơ sở dữ liệu');

select * from enrollments;
select * from courses;
select * from enrollments_history;
