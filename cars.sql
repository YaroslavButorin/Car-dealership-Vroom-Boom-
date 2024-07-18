--CREATE DATABASE sprint_1; 
CREATE SCHEMA IF NOT EXISTS raw_data; 

CREATE TABLE raw_data.sales (
    id SERIAL PRIMARY KEY,
    auto varchar(30),
    gasoline_consumption NUMERIC(4, 1) NULL, 
    price  NUMERIC(9, 2) NOT NULL, -- 7 основных +2 для десятичных
    date DATE  NOT NULL DEFAULT CURRENT_DATE,
    person_name varchar(100) NOT NULL,
    phone varchar(50) NOT NULL,
    discount INTEGER NOT NULL DEFAULT 0,
    brand_origin varchar(70)
);

COPY raw_data.sales FROM 'H:\cars.csv' WITH CSV HEADER NULL 'null'; 

CREATE SCHEMA IF NOT EXISTS car_shop;

-- СОЗДАНИЕ ТАБЛИЦ --

--Таблица цветов
CREATE TABLE car_shop.colors (
    id SERIAL PRIMARY KEY, -- Создаем автоинкрементный ключ
    color VARCHAR(20) NOT NULL UNIQUE -- Цвета уникальны, не могут быть пустыми
);

--Таблица стран
CREATE TABLE car_shop.country (
    id SERIAL PRIMARY KEY, -- Создаем автоинкрементный ключ
    brand_origin VARCHAR(50) NOT NULL UNIQUE -- Страны уникальны, не могут быть пустыми
);

--Таблица бренда авто
CREATE TABLE car_shop.brands (
    id SERIAL PRIMARY KEY,
    brand_name VARCHAR(50) NOT NULL UNIQUE, -- название бренда
    brand_origin INTEGER NULL, --id страны из таблицы выше
    FOREIGN KEY (brand_origin) REFERENCES car_shop.country(id)
);

-- Таблица покупателей
CREATE TABLE car_shop.persons (
    id SERIAL PRIMARY KEY,
    person_name VARCHAR(100) NOT NULL,
    phone VARCHAR(50) NOT NULL UNIQUE
);

--Таблица авто
CREATE TABLE car_shop.autos (
    id SERIAL PRIMARY KEY,
    model VARCHAR(255) NOT NULL,
    gasoline_consumption NUMERIC(4, 1) NULL, -- может быть Null для электрокаров
    brand_id INTEGER NULL, -- id бренда
    FOREIGN KEY (brand_id) REFERENCES car_shop.brands(id));

-- Таблица продаж
CREATE TABLE car_shop.car_sales (
    id SERIAL PRIMARY KEY,
    auto_id INTEGER NOT NULL,
	color INTEGER NOT NULL,
    price NUMERIC(9, 2) NOT NULL,
    sale_date DATE NOT NULL,
    discount INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    FOREIGN KEY (auto_id) REFERENCES car_shop.autos(id),
    FOREIGN KEY (person_id) REFERENCES car_shop.persons(id),
	FOREIGN KEY (color) REFERENCES car_shop.colors(id));
-- ВСТАВКА ДАННЫХ --


-- Вставка данных в таблицу colors
INSERT INTO car_shop.colors (color)
SELECT DISTINCT(TRIM(SPLIT_PART(sales.auto, ',', 2)))
FROM raw_data.sales;

-- Вставка данных в таблицу country
INSERT INTO car_shop.country (brand_origin)
SELECT DISTINCT(brand_origin)
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;

-- Вставка данных в таблицу persons
INSERT INTO car_shop.persons (person_name,phone)
SELECT DISTINCT(person_name),phone
FROM raw_data.sales;

-- Вставка данных в таблицу brands
INSERT INTO car_shop.brands (brand_name,brand_origin)
SELECT DISTINCT trim(split_part(auto, ' ', 1)) AS brand,
       (SELECT id FROM car_shop.country WHERE brand_origin = raw_data.sales.brand_origin) AS brand_country_id
FROM raw_data.sales;

-- Вставка данных в таблицу autos
INSERT INTO car_shop.autos (brand_id, model, gasoline_consumption)
SELECT DISTINCT
    (SELECT id FROM car_shop.brands WHERE brand_name = TRIM(SPLIT_PART(sales.auto, ' ', 1))) AS brand_id,
    SUBSTRING(TRIM(SPLIT_PART(sales.auto, ',', 1)) FROM LENGTH(SPLIT_PART(sales.auto, ' ', 1)) + 2) AS model,
    sales.gasoline_consumption
FROM raw_data.sales AS sales;


-- Вставка данных в таблицу car_sales
INSERT INTO car_shop.car_sales (auto_id, color, price, sale_date, discount, person_id)
SELECT 
    autos.id AS auto_id,
	colors.id,
    sales.price,
    sales.date,
    sales.discount,
    persons.id AS person_id
FROM raw_data.sales AS sales
INNER JOIN car_shop.persons AS persons 
    ON persons.person_name = sales.person_name
INNER JOIN car_shop.autos AS autos 
    ON sales.auto = CONCAT(TRIM(SPLIT_PART(sales.auto, ',', 1)), ', ', TRIM(SPLIT_PART(sales.auto, ',', 2)))
INNER JOIN car_shop.brands as brands
	ON autos.brand_id = brands.id
INNER JOIN car_shop.colors as colors
	ON colors.color = TRIM(SPLIT_PART(sales.auto, ',', 2))
WHERE sales.auto = CONCAT(brands.brand_name,' ',autos.model,', ',colors.color);


--Задание 1
SELECT 
    (COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100.0 / COUNT(*)) AS missing_gasoline_consumption_perc
FROM car_shop.autos;

--Задание 2
SELECT 
    brands.brand_name AS brand_name,
    EXTRACT(YEAR FROM sales.sale_date) AS year,
    ROUND(AVG(sales.price), 2) AS price_avg
FROM car_shop.car_sales AS sales
JOIN car_shop.autos ON sales.auto_id = autos.id
JOIN car_shop.brands ON autos.brand_id = brands.id
GROUP BY brands.brand_name, EXTRACT(YEAR FROM sales.sale_date)
ORDER BY brands.brand_name, EXTRACT(YEAR FROM sales.sale_date);

--Задание 3
SELECT EXTRACT(month from sales.sale_date) as month,EXTRACT(YEAR from sales.sale_date) as year,ROUND(AVG(sales.price), 2) AS  price_avg
FROM car_shop.car_sales as sales
WHERE EXTRACT(year FROM sales.sale_date) = 2022
GROUP BY EXTRACT(month from sales.sale_date),EXTRACT(YEAR from sales.sale_date)
ORDER BY EXTRACT(month from sales.sale_date);

--Задание 4
SELECT 
		car_shop.persons.person_name as person,
	    STRING_AGG((car_shop.brands.brand_name || ' ' || car_shop.autos.model), ', ') AS cars
FROM car_shop.car_sales as sales
JOIN car_shop.persons ON sales.person_id = persons.id
JOIN car_shop.autos ON autos.id = sales.auto_id
JOIN car_shop.brands ON autos.brand_id = car_shop.brands.id
GROUP BY car_shop.persons.person_name
ORDER BY car_shop.persons.person_name;

--Задание 5
SELECT 
    brands.brand_name AS brand_origin,
    MAX(price / (1 - discount / 100)) AS price_max,
    MIN(price / (1 - discount / 100)) AS price_min
FROM car_shop.car_sales AS sales
JOIN car_shop.autos AS autos ON sales.auto_id = autos.id
JOIN car_shop.brands AS brands ON autos.brand_id = brands.id
GROUP BY brands.brand_name;

-- Задание 6
SELECT COUNT(*)
FROM car_shop.car_sales as sales
JOIN car_shop.persons as persons ON sales.person_id = persons.id
WHERE persons.phone like '+1%'