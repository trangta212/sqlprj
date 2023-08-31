-- Phần khách hàng và một vài phần của đơn hàng
-- 1. Quản lý thông tin khách hàng
-- 1.1/ Tạo khách hàng mới: Thông tin của khách hàng sẽ bao gồm customer_ID,first_name,last_name,phone,points. Lưu ý customer_ID, points sẽ tự động được tạo.
-- Nếu người dùng cố tình tạo thì sẽ in ra thông báo lỗi
--Sử dụng Trigger để tạo customer_ID tự động tạo mã lưu dưới dạng "KHxxxx", người dùng không có quyền chỉnh sửa
CREATE OR REPLACE FUNCTION generate_customer_id()
    RETURNS TRIGGER AS
    $$
    DECLARE
    new_customer_id varchar(6);
    BEGIN
    SELECT 'KH' || LPAD(CAST(COALESCE(SUBSTRING(MAX(customer_ID), 3)::integer, 0) + 1 AS varchar), 4, '0')
        INTO new_customer_id
    FROM customers;
    
    NEW.customer_ID := new_customer_id;
    RETURN NEW;
    END;
    $$
    LANGUAGE plpgsql;
CREATE TRIGGER auto_generate_customer_id
    BEFORE INSERT ON customers
    FOR EACH ROW
    EXECUTE PROCEDURE generate_customer_id();
    
    --Sử dụng Trigger hệ thống chỉ cho nhập 1 số điện thoại. Nếu số điện thoại đã tồn tại thì không thể insert into thêm vào số điện thoại đó được nữa
CREATE OR REPLACE FUNCTION check_phone()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM customers WHERE phone = NEW.phone) THEN
        RAISE EXCEPTION 'Số điện thoại đã tồn tại trong hệ thống';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER checkphone_trigger
BEFORE INSERT ON customers
FOR EACH ROW
EXECUTE FUNCTION check_phone();
-- Hàm tự động tính points bằng cách lấy total_price /100. Sau khi hóa đơn được cập nhật thành công hệ thống sẽ tự động cập nhập points vào khách hàng đó
CREATE OR REPLACE FUNCTION updatepoint()
RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.pay_time IS NOT NULL THEN
        UPDATE customers
        SET points = points + NEW.total_price / 100
        WHERE customer_ID = NEW.customer_ID;
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER point_trigger
AFTER UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION updatepoint();
--2 / Hiển thị thông tin của khách hàng cần tìm kiếm
-- 2.1/ Người dùng nhập số điện thoại thì hệ thống sẽ hiển thị các thông tin bao gồm customer_ID, first_name,last_name,phone, points. Nếu phone đó mà chưa
-- tồn tại thì hệ thống sẽ in ra là số điện thoại chưa tồn tại trong hệ thống
CREATE OR REPLACE FUNCTION get_customer_info(phone_number VARCHAR)
RETURNS TABLE (customer_ID VARCHAR(6), first_name VARCHAR, last_name VARCHAR, phone VARCHAR, points BIGINT) AS $$
BEGIN
    RETURN QUERY EXECUTE format('
        SELECT customer_ID, first_name, last_name, phone, points
        FROM customers
        WHERE phone = %L', phone_number);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Số điện thoại % chưa có trong hệ thống. Vui lòng nhập lại.', phone_number;
    END IF;
END;
$$ LANGUAGE plpgsql;
---> test:select customer_id, first_name, last_name ,phone  from get_customer_info('13555')
--2.2/Sửa thông tin khách hàng: Người dùng có thể thay đổi tất cả các thông tin ngoài trừ customer_ID nếu thay đổi customer_ID thì sẽ 
-- được in ra là 'Không thể sửa đổi customer_ID!'
CREATE OR REPLACE FUNCTION customer_update()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.customer_ID is distinct from OLD.customer_ID THEN
        RAISE EXCEPTION 'Không thể sửa đổi customer_ID!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER check_customer_update
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION customer_update();
--2.3/ Hiển thị tất cả khách hàng
select * from customers;
--2.4/ sắp xếp tên khách hàng theo thứ tự tên tăng dần
SELECT *
FROM customers
ORDER BY first_name ASC;
--2.5/ Tạo view cho xem  tổng hóa đơn đã mua của customers
CREATE OR REPLACE VIEW my_vieew AS
SELECT c.customer_ID, COUNT(o.order_ID), c.points AS order_counts
FROM customers c, orders o where c.customer_ID = o.customer_ID
GROUP BY c.customer_ID;
--- select * from my_vieew
----------------------------------------------------------------------------------------------------------------------
--3.1: Hiển thị toàn bộ hóa đơn
select * from orders;
--3.2.2: Xóa hóa đơn đã sẵn có
delete from orders
where order_ID=''
--3.3:Lịch sử hóa đơn
--Tìm kiếm hóa đơn muốn xem từ order_ID
 select * from orders where order_ID='$nhapvao'; -- Lệnh select không cho phép sử dụng trigger
-- Tìm kiếm hóa đơn dựa theo ngày tháng năm đặt hàng
select * from orders where date(order_time)='nam-thang-ngay'
-- Hiển thị ra ngày mà có nhiều hóa đơn nhất
SELECT order_time::date AS order_date, COUNT(*) AS total_orders
FROM orders
GROUP BY order_time::date
ORDER BY total_orders DESC
LIMIT 1;
-- Hiển thị ra giờ mà khách hàng mua nhiều nhất
SELECT EXTRACT(HOUR FROM order_time) AS hour, COUNT(*) AS total_orders
FROM orders
GROUP BY hour
ORDER BY total_orders DESC
LIMIT 1;

-- Hiển thị ra ngày có total_price cao nhất
SELECT order_time::date AS order_date, SUM(total_price) AS total_price_sum
FROM orders
GROUP BY order_time::date
ORDER BY total_price_sum DESC
LIMIT 1;
-- Hiển thị hóa đơn theo thứ tự ngày mới nhất lên đầu
SELECT *
FROM orders
ORDER BY order_time::date desc;
--- Nếu sử dụng thời gian như này nó sẽ lưu luôn thời gian hiện tại và tự sắp xếp từ cũ đến mới
CREATE TABLE orders(
    order_ID VARCHAR(6) PRIMARY KEY NOT NULL,
    customer_ID VARCHAR(6) NOT NULL,
    order_time TIMESTAMP DEFAULT current_timestamp
);
-- View để hiển thị tổng quát chung tất cả những thông tin bao gồm tên khách hàng, mã khách hàng, tên món, số lượng, giá cả, thời gian đặt hàng  
CREATE OR REPLACE VIEW infor as
select o.order_id,o.customer_ID,c.first_name,c.last_name,t.table_ID,m.food_name,os.quantity,os.price,o.pre_total,o.total_price,o.order_time,o.pay_time
from orders o, table_order t,orderlines os,customers c, menu m
 where o.order_ID=t.order_ID and o.order_ID=os.order_ID and o.customer_ID = c.customer_ID and m.food_ID=os.food_ID;
------------------QUẢN LÍ BÀN VÀ QUẢN LÍ MENU ORDER-----------------
--<I>. QUẢN LÍ BÀN
	
-- trigger trên bảng tables, user chỉ nhập table_ID, và status mặc định là E.
CREATE OR REPLACE FUNCTION check_table_status_trigger() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS NULL THEN
        NEW.status := 'E';
    ELSE
        CASE NEW.status
            WHEN 'E' THEN
                -- Trạng thái là 'E' (Empty)
                NEW.status := 'E';
            ELSE
                -- Trạng thái không hợp lệ
                RAISE EXCEPTION 'Invalid table status. Only "E" (Empty) or "U" (In Use) are allowed.';
        END CASE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_table_status_trigger
BEFORE INSERT ON tables
FOR EACH ROW
EXECUTE FUNCTION check_table_status_trigger();

------

-- Trigger BEFORE UPDATE để kiểm tra điều kiện khi update giá trị order_ID hay table_ID chưa tồn tại
CREATE OR REPLACE FUNCTION table_update()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.table_ID is distinct from OLD.table_ID  THEN
        RAISE EXCEPTION 'Không thể sửa đổi table_ID ';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER check_table_update
BEFORE UPDATE ON tables
FOR EACH ROW
EXECUTE FUNCTION table_update();


-- nhập sai table_ID -> hiện thông báo 
CREATE OR REPLACE FUNCTION check_table_existence() RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tables WHERE table_ID = OLD.table_ID) THEN
        RAISE EXCEPTION 'table with ID % does not exist.', OLD.table_ID;
    END IF;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_table_existence_trigger
BEFORE DELETE ON tables
FOR EACH ROW
WHEN (OLD IS NOT NULL)
EXECUTE FUNCTION check_table_existence();

--Hiển thị trạng thái
	SELECT table_ID, status
	FROM tables;

--Tạo một view để hiển thị trạng thái của các bàn bao gồm cả thông tin của bảng
table và bảng table_order:
	CREATE VIEW table_status_view AS
	SELECT t.table_ID, d.status, taor.start_time, taor.end_time
	FROM tables t
	LEFT JOIN table_order taor ON t.table_ID = taor.table_ID;


--Xem thông tin chi tiết của các bàn theo từng hóa đơn:
	SELECT taor.desk_ID, taor.start_time, taor.end_time, o.customer_ID, o.order_time, o.pay_time, o.total_price,
       ol.food_ID, ol.quantity, ol.price
	FROM table_order taor
	JOIN orders o ON taor.order_ID = o.order_ID
	JOIN orderlines ol ON o.order_ID = ol.order_ID
	WHERE taor.table_ID = 'value..';

--Theo dõi thời gian sử dụng bàn để phân bổ:
-- Lấy thông tin chi tiết về thời gian sử dụng của mỗi bàn từ bảng table_order:

	SELECT table_ID, start_time, end_time
	FROM table_order;

--Truy vấn này trả về thông tin chi tiết về thời gian bắt đầu và kết thúc sử dụng của mỗi bàn.

-- Cập nhật các giá trị khi pay_time khác null: table_order.end_time, tables.status, customers.points    

CREATE OR REPLACE FUNCTION after_update_pay_time()
RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.pay_time IS NOT NULL THEN
        -- Cập nhật bảng table_order
        UPDATE table_order
        SET end_time = CURRENT_TIMESTAMP
        WHERE order_ID = NEW.order_ID;

        -- Cập nhật bảng tables
        UPDATE tables
        SET status = 'E'
        WHERE table_ID IN (
            SELECT table_ID
            FROM table_order
            WHERE order_ID = NEW.order_ID
        );
        -- Cập nhật points (trừ điểm)
        IF NEW.total_price > 0 THEN
            -- Cập nhật customers: points = 0
            UPDATE customers
            SET points = 0
            WHERE customer_ID = (
                SELECT customer_ID
                FROM orders
                WHERE order_ID = NEW.order_ID
            );
        ELSIF NEW.total_price = 0 THEN
            -- Cập nhật customers: points = points - pre_total
            UPDATE customers
            SET points = points - NEW.pre_total
            WHERE customer_ID = (
                SELECT customer_ID
                FROM orders
                WHERE order_ID = NEW.order_ID
            );
        END IF;
        UPDATE customers
        SET points = points + NEW.total_price / 100
        WHERE customer_ID = NEW.customer_ID;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_after_update_pay_time
AFTER UPDATE OF pay_time ON orders
FOR EACH ROW
WHEN (OLD.pay_time IS NULL AND NEW.pay_time IS NOT NULL)
EXECUTE FUNCTION after_update_pay_time();


CREATE TRIGGER tg_after_update_pay_time
AFTER UPDATE OF pay_time ON orders
FOR EACH ROW
WHEN (OLD.pay_time IS NULL AND NEW.pay_time IS NOT NULL)
EXECUTE FUNCTION after_update_pay_time();

--<II> MENU ORDER:
-- Thêm món ăn vào menu
-- Tự động

CREATE OR REPLACE FUNCTION generate_food_id()
    RETURNS TRIGGER AS
    $$
    DECLARE
    new_food_id varchar(6);
    BEGIN
    SELECT 'FO' || LPAD(CAST(COALESCE(SUBSTRING(MAX(food_ID), 3)::integer, 0) + 1 AS varchar), 4, '0')
        INTO new_food_id
    FROM menu;
    
    NEW.food_ID := new_food_id;
    RETURN NEW;
    END;
    $$
    LANGUAGE plpgsql;

    CREATE TRIGGER auto_generate_food_id
    BEFORE INSERT ON menu
    FOR EACH ROW
    EXECUTE PROCEDURE generate_food_id();

--Hiển thị menu order trên màn hình cho khách hàng lựa chọn 

	SELECT food_name, description, unit_price
	FROM menu;

--Tạo view để hiển thị menu order dựa trên số lần món ăn đã được đặt:

	CREATE VIEW popular_menu AS
	SELECT m.food_ID, m.food_name, m.description, m.unit_price, COUNT(ol.food_ID) 
	AS total_orders
	FROM menu m
	LEFT JOIN orderlines ol ON m.food_ID = ol.food_ID
	GROUP BY m.food_ID, m.food_name, m.description, m.unit_price
	ORDER BY total_orders DESC;

--View "popular_menu" sẽ hiển thị menu order và thêm cột "total_orders" để hiển thị số lần món ăn đã được đặt.

--Tạo trigger để tự động cập nhật thông tin món ăn nổi tiếng sau khi có đơn hàng mới:

CREATE OR REPLACE FUNCTION update_popular_menu_function() RETURNS TRIGGER AS $$
BEGIN
    UPDATE popular_menu
    SET total_orders = total_orders + 1
    WHERE food_ID = NEW.food_ID;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_popular_menu_trigger
AFTER INSERT ON orderlines
FOR EACH ROW
EXECUTE FUNCTION update_popular_menu_function();


-----------------------------------------------------
-- QUERY QUẢN LÝ HÓA ĐƠN

-- I. Chức năng tạo hóa đơn mới:
-- 1. Chức năng trên bảng orders:
--Tự động tạo mã hóa đơn order_ID, order_time khi insert into orders
    -- Chỉ cho phép user insert giá trị customer_ID
    -- Kiểm tra điều kiện câu lệnh user nhập sai customer_ID (đối với khách hàng có thẻ thành viên) -> Thông báo lỗi
CREATE OR REPLACE FUNCTION generate_order_id()
    RETURNS TRIGGER AS
    $$
    BEGIN
        -- Kiểm tra giá trị customer_ID (đối với khách hàng có thẻ thành viên)
        IF NEW.customer_ID IS NOT NULL THEN
            -- Kiểm tra sự tồn tại của customer_ID trong bảng customers
            IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_ID = NEW.customer_ID) THEN
                RAISE EXCEPTION 'Mã khách hàng customer_ID không tồn tại trong hệ thống!';
            END IF;
        END IF;

        -- Tạo new_order_id
        NEW.order_ID := (
            SELECT 'OR' || LPAD(CAST(COALESCE(SUBSTRING(MAX(order_ID), 3)::integer, 0) + 1 AS varchar), 4, '0')
            FROM orders
        );
        NEW.order_time := CURRENT_TIMESTAMP;
        RETURN NEW;
    END;
    $$
    LANGUAGE plpgsql;

CREATE TRIGGER auto_generate_order_id
    BEFORE INSERT ON orders
    FOR EACH ROW
    EXECUTE PROCEDURE generate_order_id();
    
-----------------------------------Test dữ liệu----------------------------------------
    insert into orders(customer_ID) values(null);
    -- Một số lệnh thực thi khác:
    delete from orders where customer_ID is NULL;
    drop trigger auto_generate_order_id on orders;


-- Update 
CREATE OR REPLACE FUNCTION update_orders()
    RETURNS TRIGGER AS
    $$
    BEGIN
        IF NEW.order_ID is distinct from OLD.order_ID THEN 
            RAISE EXCEPTION 'Không cập nhật mã hóa đơn!';
        END IF;
        -- Kiểm tra giá trị customer_ID (đối với khách hàng có thẻ thành viên)
        IF NEW.customer_ID IS NOT NULL THEN
            -- Kiểm tra sự tồn tại của customer_ID trong bảng customers
            IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_ID = NEW.customer_ID) THEN
                RAISE EXCEPTION 'Mã khách hàng customer_ID không tồn tại trong hệ thống!';
            END IF;
        END IF;
        RETURN NEW;
    END;
    $$
    LANGUAGE plpgsql;

CREATE TRIGGER tg_update_orders
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE PROCEDURE update_orders();

-----------------------------Test dữ liệu-----------------
    update orders set customer_ID = 'KH0003', order_ID = 'OR0002' where order_ID = 'OR0001';    -- Thông báo lỗi
    update orders set customer_ID = 'KH0001' where order_time = '23:04:20.797273';              -- Update thành công
---------Một số lệnh thực thi khác:
    drop trigger tg_update_orders on orders;


-- Tạo trigger after để hiển thị thành công
CREATE OR REPLACE FUNCTION after_insert_update_order() RETURNS TRIGGER AS 
$$
BEGIN
    RAISE NOTICE 'Đã thêm/ cập nhật thành công!';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_after_insert_update_order
AFTER INSERT OR UPDATE ON orders
FOR EACH ROW
EXECUTE PROCEDURE after_insert_update_order();


-- Delete order_ID: xóa thông tin trên table_order và orderlines với order_ID = old.order_ID

DELETE from orderlines_view where order_ID = 'value' and customer_ID ='value';
DELETE from orderlines_view where order_ID = 'value';
DELETE from orderlines_view where customer_ID = 'value';
--

CREATE OR REPLACE FUNCTION delete_orders()
    RETURNS TRIGGER AS
$$
DECLARE
    orderid varchar(6);
BEGIN
    IF OLD.order_ID IS NOT NULL THEN
        -- Trường hợp có order_ID
        DELETE FROM table_order WHERE order_ID = OLD.order_ID;  
        DELETE FROM orderlines_view WHERE order_ID = OLD.order_ID;
    ELSIF OLD.customer_ID IS NOT NULL THEN
        -- Trường hợp chỉ có customer_ID
        SELECT order_ID INTO orderid FROM orders WHERE customer_ID = OLD.customer_ID;
        IF orderid IS NOT NULL THEN
            DELETE FROM table_order WHERE order_ID = orderid;
            DELETE FROM orderlines_view WHERE order_ID = orderid;
        END IF;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_delete_orders
AFTER DELETE ON orders
FOR EACH ROW
EXECUTE PROCEDURE delete_orders();

-- 2. Chức năng chọn bàn/ xóa bàn và tự động cập nhật trạng thái bàn:
    -- Khi user insert bàn vào bảng table_order, hệ thống kiểm tra xem đã tồn tại order_ID trên orders, table_ID trên tables chưa
    -- Tiếp tục kiểm tra (order_ID, table_ID) tồn tại trên table_order chưa
        -- Nếu đã tồn tại -> hiển thị thông báo và return null
        -- Nếu chưa tồn tại -> insert vào table_order, sau khi insert thành công thì cập nhật trạng thái bàn 'U' 

------------Trigger cho INSERT----------
-- Trigger BEFORE
CREATE OR REPLACE FUNCTION before_insert_table_order() RETURNS TRIGGER AS 
$$
BEGIN
    -- Kiểm tra xem đã tồn tại order_ID trên bảng orders
    IF NOT EXISTS (SELECT 1 FROM orders WHERE order_ID = NEW.order_ID) THEN
        RAISE EXCEPTION 'Không tồn tại order_ID %', NEW.order_ID;
    END IF;

    -- Kiểm tra xem đã tồn tại table_ID trên bảng tables
    IF NOT EXISTS (SELECT 1 FROM tables WHERE table_ID = NEW.table_ID) THEN
        RAISE EXCEPTION 'Không tồn tại table_ID %', NEW.table_ID;
    END IF;

    IF NEW.start_time IS NOT NULL OR NEW.end_time IS NOT NULL THEN
        RAISE EXCEPTION 'Không được phép nhập thời gian start_time và end_time!';
    END IF;

    -- Kiểm tra xem (order_ID, table_ID) đã tồn tại trên bảng table_order chưa
    IF EXISTS (SELECT 1 FROM table_order WHERE order_ID = NEW.order_ID AND table_ID = NEW.table_ID) THEN
        RAISE EXCEPTION 'Đã tồn tại (%, %) trên table_order!', NEW.order_ID, NEW.table_ID;
    ELSE
        RETURN NEW; 
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_before_insert_table_order
BEFORE INSERT ON table_order
FOR EACH ROW
EXECUTE PROCEDURE before_insert_table_order();

-- Trigger AFTER
CREATE OR REPLACE FUNCTION after_insert_table_order() RETURNS TRIGGER AS 
$$
BEGIN
    UPDATE tables SET status = 'U' WHERE table_ID = NEW.table_ID;
    -- Cập nhật start_time bằng current_timestamp
    UPDATE table_order SET start_time = current_timestamp WHERE order_ID = NEW.order_ID AND table_ID = NEW.table_ID;
    RAISE NOTICE 'Đã thêm thành công!';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_after_insert_table_order
AFTER INSERT ON table_order
FOR EACH ROW
EXECUTE PROCEDURE after_insert_table_order();

-----------Test dữ liệu------------
    insert into tables(table_ID, status) values (1, 'E'), (2,'E'),(3,'E');
    insert into table_order(order_ID, table_ID) values('OR0001',2);


--------Trigger BEFORE UPDATE để kiểm tra điều kiện khi update giá trị order_ID hay table_ID chưa tồn tại
CREATE OR REPLACE FUNCTION before_update_table_order()
    RETURNS TRIGGER AS
    $$
    BEGIN
        IF NEW.order_ID IS NOT NULL THEN 
            IF NOT EXISTS (SELECT 1 FROM orders WHERE order_ID = NEW.order_ID) THEN
                RAISE EXCEPTION 'Mã hóa đơn order_ID không tồn tại trong hệ thống!';
            END IF;
        END IF;
        -- Kiểm tra giá trị customer_ID (đối với khách hàng có thẻ thành viên)
        IF NEW.table_ID IS NOT NULL THEN
            -- Kiểm tra sự tồn tại của customer_ID trong bảng customers
            IF NOT EXISTS (SELECT 1 FROM tables WHERE table_ID = NEW.table_ID) THEN
                RAISE EXCEPTION 'Bàn % không tồn tại trong hệ thống!',NEW.table_ID;
            END IF;
        END IF;
        RETURN NEW;
    END;
    $$
    LANGUAGE plpgsql;

CREATE TRIGGER tg_before_update_table_order
    BEFORE UPDATE ON table_order
    FOR EACH ROW
    EXECUTE PROCEDURE before_update_table_order();

---------------DELETE---------- 

CREATE OR REPLACE FUNCTION after_delete_table_order() RETURNS TRIGGER AS 
$$
BEGIN
    UPDATE tables SET status = 'E' WHERE table_ID = OLD.table_ID;
    RAISE NOTICE 'Đã xóa thành công!';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_after_delete_table_order
    AFTER DELETE ON table_order
    FOR EACH ROW
    EXECUTE PROCEDURE after_delete_table_order();


-- 3. Chức năng chọn món ăn/ xóa món ăn, tính toán giá trị price, pre_total, total_price

-- Hàm tính pre_total và total_price (chưa cập nhật points)
CREATE OR REPLACE FUNCTION calculate_totals(order_id_input TEXT) RETURNS VOID AS 
$$
DECLARE
    pretotal BIGINT;
    totalprice BIGINT;
    temp_points BIGINT; 
BEGIN
    SELECT COALESCE(SUM(price), 0) INTO pretotal
    FROM orderlines_view
    WHERE order_ID = order_id_input;

    -- Lưu kết quả truy vấn SELECT vào biến temp_points
    SELECT points INTO temp_points
    FROM customers
    JOIN orders USING (customer_ID)
    WHERE order_ID = order_id_input;

    totalprice := pretotal - COALESCE(temp_points, 0);

    UPDATE orders
    SET pre_total = pretotal,
        total_price = CASE WHEN totalprice >= 0 THEN totalprice ELSE 0 END
    WHERE order_ID = order_id_input;
END;
$$ LANGUAGE plpgsql;

----------------------------------
-- Tạo view
CREATE VIEW orderlines_view AS
SELECT o.order_ID, o.food_ID, m.food_name, o.quantity, m.unit_price AS unit_price, m.unit_price * o.quantity AS price
FROM orderlines o
JOIN menu m ON o.food_ID = m.food_ID;

-- Tạo INSTEAD OF INSERT OR UPDATE trigger
CREATE OR REPLACE FUNCTION check_insert_update_orderlines() RETURNS TRIGGER AS 
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM orders WHERE order_ID = NEW.order_ID) THEN
        RAISE EXCEPTION 'Order_ID không tồn tại';
    ELSIF NOT EXISTS (SELECT 1 FROM menu WHERE food_ID = NEW.food_ID) THEN
        RAISE EXCEPTION 'Food_ID không tồn tại';
    ELSE
        IF EXISTS (SELECT 1 FROM orderlines WHERE order_ID = NEW.order_ID AND food_ID = NEW.food_ID) THEN
            UPDATE orderlines SET quantity = NEW.quantity, price = (SELECT unit_price * NEW.quantity FROM menu WHERE food_ID = NEW.food_ID) WHERE order_ID = NEW.order_ID AND food_ID = NEW.food_ID;
        ELSE
            INSERT INTO orderlines (order_ID, food_ID, quantity, price) VALUES (NEW.order_ID, NEW.food_ID, NEW.quantity, (SELECT unit_price * NEW.quantity FROM menu WHERE food_ID = NEW.food_ID));
        END IF;
        PERFORM calculate_totals(NEW.order_ID);
        RAISE NOTICE 'Thành công!';
    END IF;
    RETURN NULL;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '%', SQLERRM;
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_check_insert_update_orderlines
INSTEAD OF INSERT OR UPDATE ON orderlines_view
FOR EACH ROW
EXECUTE PROCEDURE check_insert_update_orderlines();

-----------------------------------------
-- DELETE trên orderlines_view: 
DELETE from orderlines_view where order_ID = 'value' and food_ID ='value';
DELETE from orderlines_view where order_ID = 'value';
DELETE from orderlines_view where food_ID ='value';

------------
CREATE OR REPLACE FUNCTION after_delete_orderlines_view()
    RETURNS TRIGGER AS
$$
DECLARE
    orderid varchar(6);
BEGIN
    IF OLD.order_ID IS NOT NULL AND OLD.food_ID IS NOT NULL THEN
        -- Trường hợp cả order_ID và food_ID đều có
        DELETE FROM orderlines WHERE order_ID = OLD.order_ID AND food_ID = OLD.food_ID;
        PERFORM calculate_totals(OLD.order_ID);
    ELSIF OLD.order_ID IS NOT NULL THEN
        -- Trường hợp chỉ có order_ID
        DELETE FROM orderlines WHERE order_ID = OLD.order_ID;
        PERFORM calculate_totals(OLD.order_ID);
    ELSIF OLD.food_ID IS NOT NULL THEN
        -- Trường hợp chỉ có food_ID
        FOR orderid IN (SELECT DISTINCT order_ID FROM orderlines WHERE food_ID = OLD.food_ID) LOOP
            DELETE FROM orderlines WHERE order_ID = order_id;
            PERFORM calculate_totals(orderid);
        END LOOP;
    END IF;
    RAISE NOTICE 'Đã xóa thành công!';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_after_delete_orderlines_view
INSTEAD OF DELETE ON orderlines_view
FOR EACH ROW
EXECUTE PROCEDURE after_delete_orderlines_view();


----------------------------------
CREATE OR REPLACE FUNCTION check_insert_update_orderlines() RETURNS TRIGGER AS 
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM orders WHERE order_ID = NEW.order_ID) THEN
        RAISE EXCEPTION 'Order_ID không tồn tại';
    ELSIF NOT EXISTS (SELECT 1 FROM menu WHERE food_ID = NEW.food_ID) THEN
        RAISE EXCEPTION 'Food_ID không tồn tại';
    ELSE
        IF EXISTS (SELECT 1 FROM orderlines WHERE order_ID = NEW.order_ID AND food_ID = NEW.food_ID) THEN
            UPDATE orderlines SET quantity = NEW.quantity, price = (SELECT unit_price * NEW.quantity FROM menu WHERE food_ID = NEW.food_ID) WHERE order_ID = NEW.order_ID AND food_ID = NEW.food_ID;
        ELSE
            INSERT INTO orderlines (order_ID, food_ID, quantity, price) VALUES (NEW.order_ID, NEW.food_ID, NEW.quantity, (SELECT unit_price * NEW.quantity FROM menu WHERE food_ID = NEW.food_ID));
            UPDATE popular_menu
                SET total_orders = total_orders + 1
                WHERE food_ID = NEW.food_ID;
        END IF;
        PERFORM calculate_totals(NEW.order_ID);
        RAISE NOTICE 'Thành công!';
    END IF;
    RETURN NULL;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '%', SQLERRM;
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_check_insert_update_orderlines
INSTEAD OF INSERT OR UPDATE ON orderlines_view
FOR EACH ROW
EXECUTE PROCEDURE check_insert_update_orderlines();