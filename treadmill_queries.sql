CREATE DATABASE treadmill_db;


-- Create the treadmill_data table
CREATE TABLE IF NOT EXISTS treadmill_data (
    Product VARCHAR(10),
    Age INT,
    Gender VARCHAR(6),
    Education INT,
    MaritalStatus VARCHAR(12),
    Usage INT,
    Fitness INT,
    Income DECIMAL(10, 2),
    Miles DECIMAL(10, 2)
);

-- Import data from the CSV file
-- COPY treadmill_data 
-- FROM '/Users/sirguevara/dev/brightfire/brightfire_treadmill_data.csv' 
-- WITH(FORMAT CSV, HEADER);

-- Viewing the data
SELECT * FROM treadmill_data;

-- Average Age of customer per treadmill type.
SELECT product, AVG(age) average_age 
FROM treadmill_data
GROUP BY product;

-- Average fitness level associtated with each treadmill
SELECT product, AVG(fitness) average_fitness 
FROM treadmill_data
GROUP BY product;

-- Count of genders
SELECT gender, count(gender)
FROM treadmill_data td 
GROUP BY gender;

-- Gender Distribution for Each Treadmill Model
SELECT 
    Product, 
    Gender, 
    COUNT(*) AS num_customers
FROM treadmill_data
GROUP BY Product, Gender
ORDER BY product, num_customers DESC;

-- Fitness Level for Each Treadmill Model
SELECT 
    Product,
    AVG(Fitness) AS avg_fitness,
    MIN(Fitness) AS min_fitness,
    MAX(Fitness) AS max_fitness
FROM treadmill_data
GROUP BY Product
ORDER BY Product;

-- Fitness Level  Bin for each treadmill type ,using min and max is not very insitghtful 
SELECT 
    product,
    COUNT(CASE WHEN Fitness IN (1, 2) THEN 1 END) AS  poor_shape,
    COUNT(CASE WHEN Fitness = 3 THEN 1 END) AS ok_shape,
        COUNT(CASE WHEN Fitness = 3 THEN 1 END) AS ok_shape,
            COUNT(CASE WHEN Fitness = 3 THEN 1 END) AS ok_shape,
    COUNT(CASE WHEN Fitness IN (4, 5) THEN 1 END) AS excellet_shape
FROM 
    treadmill_data td 
GROUP BY 
    product ;
   
   /*
    * KP781 and KP481  has as many people in poor shape as they are in excellet shape
    *  
     no one is planning on using the treadmil once
 * KP28 customers plan on using the treadmill 4 times a week 
 * 
 */


-- Wholistic Customer Profile by Treadmill Type
-- Description for:
CREATE OR REPLACE FUNCTION get_product_stats(_col TEXT)
RETURNS TABLE (
    product TEXT,
    count BIGINT,
    avg NUMERIC,
    stddev NUMERIC,
    min NUMERIC,
    mode NUMERIC,
    max NUMERIC,
    percentile_25 NUMERIC,
    percentile_50 NUMERIC,
    percentile_75 NUMERIC
  
) AS $$
BEGIN
    RETURN QUERY EXECUTE FORMAT('
        SELECT
            Product::TEXT,
            COUNT(%I) AS count,
            AVG(%I) AS avg,
            STDDEV_SAMP(%I) AS stddev,
            MIN(%I)::NUMERIC AS min, 
            MODE() WITHIN GROUP (ORDER BY %I)::NUMERIC AS mode,
 			MAX(%I)::NUMERIC AS max, 
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY %I)::NUMERIC AS percentile_25,
            PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY %I)::NUMERIC AS percentile_50,
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY %I)::NUMERIC AS percentile_75
        FROM treadmill_data td
        GROUP BY Product::TEXT', 
        _col, _col, _col, _col, _col, _col, _col, _col, _col);
END;
$$ LANGUAGE plpgsql;

-- Age
SELECT * FROM get_product_stats('age');

-- Education
SELECT * FROM get_product_stats('education');

-- Usage
SELECT * FROM get_product_stats('usage');

-- Income
SELECT * FROM get_product_stats('income');

-- Fitness
SELECT * FROM get_product_stats('fitness');

-- Miles
SELECT * FROM get_product_stats('miles');

/*
 * Insights: The age range of customers spans from 18 to 65 year, with an average age of 40 years.
 * Customer education levels vary between 12 and 21 years, with an average education duration of 16 years
 * Customers intend to utilize the product anywhere from 2 to 7 times per week, with an average usage frequency of 3 times per week.
 * On average, customers have rated their fitness at 3 on a 5-point scale, reflecting a moderate level of fitness
 * The annual income of customers falls within the range of USD 30,000 to USD 104,000, with an average income of approximately USD 65,000 for the KP281,66,000 for KP481 and 67,000 for the KP781.
 * Customers' weekly running goals range from 21 to 360 miles, with an average target of 103 miles per week.
 */


-- Create a temp table with new columns andcCategorizing some values for better analysis.
CREATE TEMPORARY TABLE treadmill_data_temp AS
SELECT
    *,
    CASE
        WHEN Age BETWEEN 18 AND 25 THEN '18-25'
        WHEN Age BETWEEN 25 AND 45 THEN '26-45'
        WHEN Age BETWEEN 46 AND 59 THEN '41-59'
        ELSE '60+'
    END AS Age_Category,
    CASE
        WHEN Education <= 12 THEN 'Primary Education'
        WHEN Education BETWEEN 13 AND 15 THEN 'Secondary Education'
        ELSE 'Higher Education'
    END AS Education_Category,
    CASE
        WHEN Income <= 30000 THEN 'Lower Income'
        WHEN Income > 30000 AND Income <= 60000 THEN 'Middle Icome'
        WHEN Income > 60000 THEN 'High Income'
        ELSE 'Unknown'
    END AS Income_Category,
    CASE
        WHEN Fitness <= 3 THEN 'Poor Shape'
        WHEN Fitness > 3 THEN 'Good Shape' 
        ELSE 'Ok Shape'
    END AS Fitness_Category,
    CASE
        WHEN Miles <= 50 THEN 'Light Activity'
        WHEN Miles BETWEEN 51 AND 100 THEN 'Moderate Activity'
        WHEN Miles BETWEEN 101 AND 200 THEN 'Active Lifestyle'
        WHEN Miles > 200 THEN 'Fitness Enthusiast'
    END AS Miles_Category
FROM
    treadmill_data;

-- Calculate the total amount sold and the percentage of revenue and sales for each treadmill product based on the number of units sold and their respective prices.
WITH
product_prices AS (
    SELECT 'KP281' AS product, 1500 AS price
    UNION ALL
    SELECT 'KP481', 1750
    UNION ALL
    SELECT 'KP781', 2500
),
units_sold AS (
    SELECT
        product,
        COUNT(*) AS units_sold
    FROM
        treadmill_data_temp
    GROUP BY
        product
),
revenue_per_product AS (
    SELECT
        u.product,
        u.units_sold,
        p.price,
        u.units_sold * p.price AS total_revenue
    FROM
        units_sold u
    JOIN
        product_prices p ON u.product = p.product
),
total_revenue AS (
    SELECT
        SUM(total_revenue) AS grand_total_revenue
    FROM
        revenue_per_product
),
total_units AS (
    SELECT
        SUM(units_sold) AS grand_total_units
    FROM
        units_sold
)
SELECT
    r.product,
    r.units_sold,
    r.price,
    r.total_revenue,
    ROUND((r.units_sold * 100.0) / tu.grand_total_units, 2) AS units_percentage,
    ROUND((r.total_revenue * 100.0) / tr.grand_total_revenue, 2) AS revenue_percentage
FROM
    revenue_per_product r
CROSS JOIN
    total_revenue tr
CROSS JOIN
    total_units tu
ORDER BY
    revenue_percentage DESC;

   
/* Insight
 * All three models have nearly equal contributions in terms of sales units but the KP781 which is the flaghsip product generates 44.7% more revenue than the mid-level KP481 and  64.07% than the entry level KP281  .
*/

-- Percentage Distribution of Genders Within Each Product
SELECT
    product,
    SUM(CASE WHEN gender = 'Male' THEN 1 ELSE 0 END) AS male_count,
    SUM(CASE WHEN gender = 'Female' THEN 1 ELSE 0 END) AS female_count,
    COUNT(*) AS total_count,
    ROUND((SUM(CASE WHEN gender = 'Male' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS male_percentage,
    ROUND((SUM(CASE WHEN gender = 'Female' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS female_percentage
FROM
    treadmill_data_temp
GROUP BY
    product
ORDER BY
    product;
   
-- Percentage Distribution of Maritial Status Within Each Product
SELECT
    product,
    SUM(CASE WHEN MaritalStatus = 'Single' THEN 1 ELSE 0 END) AS single_count,
    SUM(CASE WHEN MaritalStatus = 'Partnered' THEN 1 ELSE 0 END) AS partnered_count,
    COUNT(*) AS total_count,
    ROUND((SUM(CASE WHEN MaritalStatus = 'Single' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS single_percentage,
    ROUND((SUM(CASE WHEN MaritalStatus = 'Partnered' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS partnered_percentage
FROM
    treadmill_data_temp
GROUP BY
    product
ORDER BY
    product;   
 
-- Gender Distribution Across All Products 
SELECT
    gender,
    COUNT(*) AS gender_count,
    ROUND((COUNT(*) * 100.0) / (SELECT COUNT(*) FROM treadmill_data_temp), 2) AS gender_percentage
FROM
    treadmill_data_temp
GROUP BY
    gender
ORDER BY
    gender;

-- Marital Status Distribution Across All Products 
SELECT
    MaritalStatus,
    COUNT(*) AS marital_status_count,
    ROUND((COUNT(*) * 100.0) / (SELECT COUNT(*) FROM treadmill_data_temp), 2) AS marital_status_percentage
FROM
    treadmill_data_temp
GROUP BY
    MaritalStatus
ORDER BY
    MaritalStatus;

-- Age Distribution For each Product
SELECT
    t.product,
    t.Age_Category,
    COUNT(*) AS customer_count,
    ROUND((COUNT(*) * 100.0) / total.total_count, 2) AS percentage
FROM
    treadmill_data_temp t
JOIN (
    SELECT
        product,
        COUNT(*) AS total_count
    FROM
        treadmill_data_temp
    GROUP BY
        product
) total ON t.product = total.product
GROUP BY
    t.product,
    t.Age_Category,
    total.total_count
ORDER BY
    percentage DESC;
  
   
/* Interpretation:
For each treadmill model (KP281, KP481, KP781):
KP281:
Average customer age: 40 years
More males than females
Average income: $50,000
Fitness level: Moderate (3/5)
Average education: 14 years
Treadmill usage: Moderate (3/5)
KP481:
Slightly younger customers (avg age: 39)
Even gender split
Higher fitness level (avg: 3.5/5)
*
*/


-- CONDITIONAL PROBABILITY 
CREATE OR REPLACE FUNCTION conditional_probability_table(_col TEXT)
RETURNS TABLE (
	col TEXT,
	KP281_conditional FLOAT,
	KP481_conditional FLOAT,
	KP781_conditional FLOAT
)	
AS $$
BEGIN
	RETURN QUERY EXECUTE FORMAT('
		WITH _contingency_table AS (
		    SELECT 
		        %I AS col_value,
		        Product,
		        COUNT(*) AS count_by_product
		    FROM treadmill_data_temp
		    GROUP BY %I, Product
		),
		_totals AS (
		    SELECT 
		        %I AS col_value,
		        COUNT(*) AS total_count
		    FROM treadmill_data_temp
		    GROUP BY %I
		)
		SELECT 
			ct.col_value::TEXT AS col,
			ROUND(100 * SUM(CASE WHEN Product = ''KP281'' THEN ct.count_by_product::NUMERIC ELSE 0 END) / MAX(_t.total_count::NUMERIC), 2)::FLOAT AS KP281_conditional,
			ROUND(100 * SUM(CASE WHEN Product = ''KP481'' THEN ct.count_by_product::NUMERIC ELSE 0 END) / MAX(_t.total_count::NUMERIC), 2)::FLOAT AS KP481_conditional,
			ROUND(100 * SUM(CASE WHEN Product = ''KP781'' THEN ct.count_by_product::NUMERIC ELSE 0 END) / MAX(_t.total_count::NUMERIC), 2)::FLOAT AS KP781_conditional
		FROM _contingency_table ct
		JOIN _totals _t 
		    ON ct.col_value = _t.col_value
		GROUP BY ct.col_value
		ORDER BY ct.col_value;', 
		_col, _col, _col, _col);
END;
$$ LANGUAGE plpgsql;

-- Probability of purchasing the product given:
 
-- Product|Gender 
SELECT * FROM conditional_probability_table('gender');  

-- Product|Age
SELECT * FROM conditional_probability_table('age_category');

-- Product|Marital Status 
SELECT * FROM conditional_probability_table('maritalstatus');  

-- Product|Income 
SELECT * FROM conditional_probability_table('income_category');  

-- Product|Miles 
SELECT * FROM conditional_probability_table('miles_category');  

-- Product|Fitness 
SELECT * FROM conditional_probability_table('fitness_category');  

-- Product|Usage 
SELECT * FROM conditional_probability_table('usage');  

-- Product|Education 
SELECT * FROM conditional_probability_table('education_category');  


-- MARGINAL PROBABILITY 
CREATE OR REPLACE FUNCTION marginal_probability_table(_col TEXT)
RETURNS TABLE (
	col TEXT,
	KP281_marginal FLOAT,
	KP481_marginal FLOAT,
	KP781_marginal FLOAT,
	Total FLOAT
)
AS $$
BEGIN
	RETURN QUERY EXECUTE FORMAT('
		SELECT 
		    %I::TEXT AS col,
		    ROUND(100 * SUM(CASE WHEN Product = ''KP281'' THEN 1 ELSE 0 END)::NUMERIC / (SELECT COUNT(*) FROM treadmill_data_temp)::NUMERIC, 2)::FLOAT AS KP281_marginal,
		    ROUND(100 * SUM(CASE WHEN Product = ''KP481'' THEN 1 ELSE 0 END)::NUMERIC / (SELECT COUNT(*) FROM treadmill_data_temp)::NUMERIC, 2)::FLOAT AS KP481_marginal,
		    ROUND(100 * SUM(CASE WHEN Product = ''KP781'' THEN 1 ELSE 0 END)::NUMERIC / (SELECT COUNT(*) FROM treadmill_data_temp)::NUMERIC, 2)::FLOAT AS KP781_marginal,
 ROUND(100*(COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM treadmill_data_temp)::NUMERIC),2)::FLOAT AS Total
		FROM treadmill_data_temp
		GROUP BY %I
		ORDER BY %I
	', _col, _col, _col);
END;$$ 
LANGUAGE plpgsql;

-- Product|Gender 
SELECT * FROM marginal_probability_table('gender');

-- Product|Age
SELECT * FROM marginal_probability_table('age_category');

-- Product|Marital Status 
SELECT * FROM marginal_probability_table('maritalstatus');

-- Product|Income  
SELECT * FROM marginal_probability_table('income_category');

-- Product|Miles 
SELECT * FROM marginal_probability_table('miles_category');

-- Product|Fitness 
SELECT * FROM marginal_probability_table('fitness_category');

-- Product|Usage 
SELECT * FROM marginal_probability_table('usage');


