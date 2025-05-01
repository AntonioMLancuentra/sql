/* ASSIGNMENT 2 */
/* SECTION 2 */

-- COALESCE
/* 1. Our favourite manager wants a detailed long list of products, but is afraid of tables! 
We tell them, no problem! We can produce a list with all of the appropriate details. 

Using the following syntax you create our super cool and not at all needy manager a list:

SELECT 
product_name || ', ' || product_size|| ' (' || product_qty_type || ')'
FROM product

But wait! The product table has some bad data (a few NULL values). 
Find the NULLs and then using COALESCE, replace the NULL with a 
blank for the first problem, and 'unit' for the second problem. 

HINT: keep the syntax the same, but edited the correct components with the string. 
The `||` values concatenate the columns into strings. 
Edit the appropriate columns -- you're making two edits -- and the NULL rows will be fixed. 
All the other rows will remain the same.) */

SELECT 
product_name || ', ' || COALESCE(NULLIF(product_size,''), '')|| ' (' || COALESCE(NULLIF(product_size,''), 'unit') || ')' 
AS fav_manager_list_of_products
FROM product

--Windowed Functions
/* 1. Write a query that selects from the customer_purchases table and numbers each customer’s  
visits to the farmer’s market (labeling each market date with a different number). 
Each customer’s first visit is labeled 1, second visit is labeled 2, etc. 

You can either display all rows in the customer_purchases table, with the counter changing on
each new market date for each customer, or select only the unique market dates per customer 
(without purchase details) and number those visits. 
HINT: One of these approaches uses ROW_NUMBER() and one uses DENSE_RANK(). */

SELECT DISTINCT 
	c.customer_first_name||' '||c.customer_last_name AS customer_name
	,drp.market_date
	,drp.visit
FROM
	(SELECT customer_id,market_date
	,DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY market_date) as visit
	FROM customer_purchases) drp
JOIN customer c ON drp.customer_id=c.customer_id
ORDER BY customer_name;

/* 2. Reverse the numbering of the query from a part so each customer’s most recent visit is labeled 1, 
then write another query that uses this one as a subquery (or temp table) and filters the results to 
only the customer’s most recent visit. */

--if a table named "customer_visits" exists in schema temp, delete it, otherwise do NOTHING
DROP TABLE IF EXISTS temp.customer_visits;

--create a temp table (table in schema temp, which will dissapear when the connection is closed)
CREATE TEMP TABLE temp.customer_visits AS
--definition of the table
SELECT DISTINCT c.customer_first_name||' '||c.customer_last_name AS customer_name, drp.market_date,drp.visit
FROM
	(SELECT customer_id,market_date
	,DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY market_date DESC) as visit
	FROM customer_purchases) drp
JOIN customer c ON drp.customer_id=c.customer_id;
--temp table columns are customer_name, market_date, visit

--query temp table and filter
SELECT customer_name, market_date, visit
FROM customer_visits
WHERE visit = 1
ORDER BY customer_name;

/* 3. Using a COUNT() window function, include a value along with each row of the 
customer_purchases table that indicates how many different times that customer has purchased that product_id. */

SELECT product_id, vendor_id, market_date, customer_id
	,quantity, cost_to_customer_per_qty, transaction_time
	,COUNT() OVER(PARTITION BY customer_id,product_id) AS cust_purch_prod --ORDER BY not relevant, and it works without it
FROM customer_purchases
ORDER BY market_date;

-- String manipulations
/* 1. Some product names in the product table have descriptions like "Jar" or "Organic". 
These are separated from the product name with a hyphen. 
Create a column using SUBSTR (and a couple of other commands) that captures these, but is otherwise NULL. 
Remove any trailing or leading whitespaces. Don't just use a case statement for each product! 

| product_name               | description |
|----------------------------|-------------|
| Habanero Peppers - Organic | Organic     |

Hint: you might need to use INSTR(product_name,'-') to find the hyphens. INSTR will help split the column. */

SELECT product_name
	,TRIM(
		  LTRIM(
				SUBSTR(
					   product_name,
					   NULLIF(
							  INSTR(product_name,'-') --position p of '-' in string, 0 means no '-'
							  ,0
							 ) -- if no '-', returns NULL, otherwise does nothing
					  ) -- extract string from position p onwards when p is no NULL
				,'-'
			   ) -- trims hyphen '-'
		 ) -- removes any trailing or leading whitespaces
	 AS description
FROM product;

/* 2. Filter the query to show any product_size value that contain a number with REGEXP. */

SELECT product_name
	,TRIM(LTRIM(SUBSTR(product_name,NULLIF(INSTR(product_name,'-'),0)),'-')) AS description
	, product_size 
FROM product
WHERE product_size REGEXP '[0-9]';

-- UNION
/* 1. Using a UNION, write a query that displays the market dates with the highest and lowest total sales.

HINT: There are a possibly a few ways to do this query, but if you're struggling, try the following: 
1) Create a CTE/Temp Table to find sales values grouped dates; 
2) Create another CTE/Temp table with a rank windowed function on the previous query to create 
"best day" and "worst day"; 
3) Query the second temp table twice, once for the best day, once for the worst day, 
with a UNION binding them. */

-- create Common Table Expression (CTE)
WITH market_date_sales AS 
(	SELECT market_date, SUM(quantity*cost_to_customer_per_qty) AS sales
	FROM customer_purchases
	GROUP BY market_date
)
-- retrieve day of max sales from CTE
SELECT market_date, MAX(sales) AS highest_total_sales, '' AS lowest_total_sales
FROM market_date_sales

UNION
-- retrieve day of min sales from CTE
SELECT market_date, '' AS highest_total_sales, MIN(sales) AS lowest_total_sales
FROM market_date_sales

ORDER BY market_date;


/* SECTION 3 */

-- Cross Join
/*1. Suppose every vendor in the `vendor_inventory` table had 5 of each of their products to sell to **every** 
customer on record. How much money would each vendor make per product? 
Show this by vendor_name and product name, rather than using the IDs.

HINT: Be sure you select only relevant columns and rows. 
Remember, CROSS JOIN will explode your table rows, so CROSS JOIN should likely be a subquery. 
Think a bit about the row counts: how many distinct vendors, product names are there (x)?
How many customers are there (y). 
Before your final group by you should have the product of those two queries (x*y).  */

SELECT vendor_name, product_name, SUM(quantity*original_price) AS potential_sales
FROM  -- 8 vendor_product * 26 customers brings a cartesian product of 208 combinations
	(SELECT v.vendor_name, p.product_name, 5 AS quantity, vi.original_price  -- set 5 as quantity for potential sales
	FROM  -- how many distinct vendors+product names are in inventory records (8)
		(SELECT DISTINCT vendor_id, product_id, original_price
		FROM vendor_inventory) vi
	CROSS JOIN  -- how many distinct customers are on record (26)
		(SELECT DISTINCT customer_id
		FROM customer)
	JOIN vendor v ON vi.vendor_id=v.vendor_id  -- bring vendor name
	JOIN product p ON vi.product_id=p.product_id)  -- bring product name
GROUP BY vendor_name, product_name
ORDER BY vendor_name, product_name;

-- INSERT
/*1.  Create a new table "product_units". 
This table will contain only products where the `product_qty_type = 'unit'`. 
It should use all of the columns from the product table, as well as a new column for the `CURRENT_TIMESTAMP`.  
Name the timestamp column `snapshot_timestamp`. */

CREATE TABLE product_units (
	product_units_id int(11) NOT NULL,
	product_name varchar(45) DEFAULT  NULL,
	product_size varchar(45) DEFAULT  NULL,
	product_category_id int(11) NOT NULL,
	product_qty_type varchar(4) DEFAULT  'unit' CHECK(product_qty_type='unit'),
	snapshot_timestamp datetime DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY(product_units_id,product_category_id),
	CONSTRAINT fk_product_product_category_id2 FOREIGN KEY(product_category_id) REFERENCES product_category(product_category_id)
)

/*2. Using `INSERT`, add a new row to the product_units table (with an updated timestamp). 
This can be any product you desire (e.g. add another record for Apple Pie). */

INSERT INTO product_units (product_units_id,product_name,product_size,product_category_id)
VALUES (1, 'Pecan Pie', '10"', 3)

-- DELETE
/* 1. Delete the older record for the whatever product you added. 

HINT: If you don't specify a WHERE clause, you are going to have a bad time.*/

-- it appears it is refering to the counterpart record in the table "product" (which is older)
-- as per the instructions  in INSERT /*2. "any product you desire", 'Pecan Pie' is not in the table "product", I cannot delete it
-- if the instructions imply to delete 'Pecan Pie' from table "product_units" (my older record of 'Pecan Pie', and the only one), that would be:
DELETE FROM product_units
WHERE product_units_id=1
-- if the instructions imply to delete (let's asume I added 'Apple Pie' to "product_units") 'Apple Pie' from table "product", that would be:
DELETE FROM product
WHERE product_id=7
-- the above statement gives an error because this PK is referenced from a PK in table "vendor_inventory".
-- theory points to delete product_id 7 from "vendor_inventory" first, and then delete it from "product".
-- if we do that, we won't be able to proceed with UPDATE /*1. , we need product_id 7 in "vendor_inventory".
-- but even trying to delete from "product" a record with product_id not existing neither in "vendor_inventory" nor in "customer_purchases", 
-- 		like product_id=10 Eggs, gives same error. Internet search points to the structure of the database, not to the chosen code (same but with id=10, Eggs)
-- because the stated above, i assume solving this error is not intended in this assignment

-- UPDATE
/* 1.We want to add the current_quantity to the product_units table. 
First, add a new column, current_quantity to the table using the following syntax.

ALTER TABLE product_units
ADD current_quantity INT;

Then, using UPDATE, change the current_quantity equal to the last quantity value from the vendor_inventory details.

HINT: This one is pretty hard. 
First, determine how to get the "last" quantity per product. 
Second, coalesce null values to 0 (if you don't have null values, figure out how to rearrange your query so you do.) 
Third, SET current_quantity = (...your select statement...), remembering that WHERE can only accommodate one column. 
Finally, make sure you have a WHERE statement to update the right row, 
	you'll need to use product_units.product_id to refer to the correct row within the product_units table. 
When you have all of these components, you can run the update statement. */

-- these instructions appear to assume that "product_units" table is not empty 
-- and that it contains one or more records with product_id that exists in table "vendor_inventory"
-- because I added 'Pecan Pie' to "product_units", I am not in that situation
-- to do this exercise I assume that: 
-- 		* I added 'Apple Pie' to "product_units"
-- 		* I have only that one record in "product_units"
-- 		* these instructions ask me to update such one record only

-- temp table "product_last" with product list and "last" quantity per product with zeros
DROP TABLE IF EXISTS temp.product_last;
CREATE TEMP TABLE temp.product_last AS
	SELECT p.product_id, p.product_name, COALESCE(vilq.quantity,0) AS last
	FROM
		(SELECT product_id,quantity
		FROM
			(SELECT market_date,quantity,product_id
				,ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY market_date DESC) AS marker
			FROM vendor_inventory)
		WHERE marker=1) vilq
	RIGHT JOIN product p ON vilq.product_id=p.product_id
	ORDER BY p.product_id;
-- I use tempt table "product_last" to update current_quantity in Apple Pie (id 7) record in "product_units"
UPDATE product_units
SET current_quantity = 
	(SELECT last
	FROM product_last
	WHERE product_id=7)
WHERE product_units_id=7

