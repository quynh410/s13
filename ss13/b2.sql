use ss13;
create table products (
    product_id int primary key auto_increment,
    product_name varchar(50),
    stock int,
    price decimal(10,2)
);

create table orders (
    order_id int primary key auto_increment,
    product_id int,
    quantity int,
    total_price decimal(10,2),
    foreign key (product_id) references products(product_id)
);
INSERT INTO products (product_name, price, stock) VALUES
('Laptop Dell', 1500.00, 10),
('iPhone 13', 1200.00, 8),
('Samsung TV', 800.00, 5),
('AirPods Pro', 250.00, 20),
('MacBook Air', 1300.00, 7);

delimiter &&
create procedure place_order(
    in p_product_id int,
    in p_quantity int
)
begin
    declare v_stock int;
    declare v_price decimal(10,2);
    declare v_total_price decimal(10,2);
    -- lấy số lượng tồn kho và giá sản phẩm
    select stock, price into v_stock, v_price
    from products
    where product_id = p_product_id;
-- kiểm tra nếu số lượng trong kho không đủ
    if v_stock < p_quantity then
        rollback;
        signal sqlstate '45000'
        set message_text = 'không đủ hàng trong kho';
    else
        -- tính tổng giá
        set v_total_price = v_price * p_quantity;

        -- bắt đầu giao dịch
        start transaction;
        -- tạo đơn hàng
        insert into orders (product_id, quantity, total_price)
        values (p_product_id, p_quantity, v_total_price);

        -- giảm số lượng tồn kho
        update products 
        set stock = stock - p_quantity
        where product_id = p_product_id;
        -- xác nhận giao dịch
        commit;
    end if;
end 
delimiter &&;

call place_order(1, 5);
