
------------------------------------------------------------------------------------------------------------------------
-- Let’s dive deeper into the impact of introducing new products. Please pull monthly sessions to the /products page, and show how 
-- the % of those sessions clicking through another page has changed over time, along with a view of how conversion from /products 
-- to placing an order has improved.

WITH Product_Sessions AS (
    SELECT 
        website_session_id
    FROM 
        website_pageviews
    WHERE 
        pageview_url = '/products'
),
Next_Page_Sessions AS (
    SELECT 
        website_pageviews.website_session_id
    FROM 
        website_pageviews
    JOIN 
        Product_Sessions ON website_pageviews.website_session_id = Product_Sessions.website_session_id
    WHERE 
        pageview_url IN ('/cart', '/shipping', '/billing', '/thank-you-for-your-order')
)
SELECT 
    DATEPART(YEAR, wp.created_at) AS Year,
    DATEPART(MONTH, wp.created_at) AS Month,
    COUNT(DISTINCT ps.website_session_id) AS Monthly_Product_Sessions,
    COUNT(DISTINCT np.website_session_id) AS Monthly_Click_Through_Sessions,
    (COUNT(DISTINCT np.website_session_id) * 100.0 / NULLIF(COUNT(DISTINCT ps.website_session_id), 0)) AS Click_Through_Percentage
FROM 
    website_pageviews wp
JOIN 
    Product_Sessions ps ON wp.website_session_id = ps.website_session_id
LEFT JOIN 
    Next_Page_Sessions np ON wp.website_session_id = np.website_session_id
WHERE 
    wp.pageview_url = '/products'
GROUP BY 
    DATEPART(YEAR, wp.created_at), 
    DATEPART(MONTH, wp.created_at)
ORDER BY 
    Year, Month;
-----------------------------------------------------------------------------------------------------------------------------

--  Next, let’s showcase all of our efficiency improvements. I would love to show quarterly figures since we launched, for session-to
--  order conversion rate, revenue per order, and revenue per session.


                                          -- /// Revenue per session ///--
WITH RevenuePerSession AS (
    SELECT 
        DATEPART(QUARTER, ws.created_at) AS quarter,
        DATEPART(YEAR, ws.created_at) AS year,
        COUNT(DISTINCT ws.website_session_id) AS total_sessions,
        SUM(o.price_usd - ISNULL(r.refund_amount_usd, 0)) AS total_revenue
    FROM 
        website_sessions ws
    LEFT JOIN 
        orders o ON ws.website_session_id = o.website_session_id
    LEFT JOIN 
        order_items oi ON o.order_id = oi.order_id
    LEFT JOIN 
        order_item_refunds r ON oi.order_item_id = r.order_item_id

    GROUP BY 
        DATEPART(YEAR, ws.created_at), DATEPART(QUARTER, ws.created_at)
)

SELECT 
    CONCAT(year, '-Q', quarter) AS quarter,
    total_sessions,
    ROUND(total_revenue / NULLIF(total_sessions, 0), 2) AS revenue_per_session
FROM 
    RevenuePerSession
ORDER BY 
    year, quarter;


	                               -- /// Revenue per Order ///--

WITH RevenuePerOrder AS (
    SELECT 
        DATEPART(QUARTER, o.created_at) AS quarter,
        DATEPART(YEAR, o.created_at) AS year,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.price_usd - ISNULL(r.refund_amount_usd, 0)) AS total_revenue
    FROM 
        orders o
    LEFT JOIN 
        order_items oi ON o.order_id = oi.order_id
    LEFT JOIN 
        order_item_refunds r ON oi.order_item_id = r.order_item_id
   
    GROUP BY 
        DATEPART(YEAR, o.created_at), DATEPART(QUARTER, o.created_at)
)

SELECT 
    CONCAT(year, '-Q', quarter) AS quarter,
    total_orders,
    ROUND(total_revenue / NULLIF(total_orders, 0), 2) AS revenue_per_order
FROM 
    RevenuePerOrder
ORDER BY 
    year, quarter;


	                                -- /// Conversion rate ///--

WITH QuarterlyData AS (
    SELECT 
        DATEPART(QUARTER, ws.created_at) AS quarter,
        DATEPART(YEAR, ws.created_at) AS year,
        COUNT(DISTINCT ws.website_session_id) AS total_sessions,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM 
        website_sessions ws
    LEFT JOIN 
        orders o ON ws.website_session_id = o.website_session_id
    GROUP BY 
        DATEPART(YEAR, ws.created_at), DATEPART(QUARTER, ws.created_at)
)

SELECT 
    CONCAT(year, '-Q', quarter) AS quarter,
    total_sessions,
    total_orders,
    ROUND((CAST(total_orders AS FLOAT) / NULLIF(total_sessions, 0)) * 100, 2) AS conversion_rate
FROM 
    QuarterlyData
ORDER BY 
    year, quarter;
-----------------------------------------------------------------------------------------------------------------------------------------------

-- For the landing page test you analyzed previously, it would be great to show a full conversion funnel from each of 
-- the two pages to orders. You can use the same time period you analyzed last time (Jun 19 – Jul 28).

                                                   -- \\\ Conversion Funnel for Home page sessions \\\ --


WITH PageViews AS (
    SELECT 
        wp.website_session_id,
        wp.pageview_url,
        wp.created_at,
        ROW_NUMBER() OVER (PARTITION BY wp.website_session_id ORDER BY wp.created_at) AS step_number
    FROM 
        website_pageviews wp
    WHERE 
        wp.created_at BETWEEN '2012-06-19' AND '2014-07-28'
        AND wp.pageview_url IN ('/home', '/products', '/cart', '/shipping', '/billing', '/thank-you-for-your-order')
),
FunnelSteps AS (
    SELECT 
        pv.website_session_id,
        MAX(CASE WHEN pv.pageview_url = '/home' THEN 1 ELSE 0 END) AS Step_1_Home,
        MAX(CASE WHEN pv.pageview_url = '/products' THEN 1 ELSE 0 END) AS Step_2_Products,
        MAX(CASE WHEN pv.pageview_url = '/cart' THEN 1 ELSE 0 END) AS Step_3_Cart,
        MAX(CASE WHEN pv.pageview_url = '/shipping' THEN 1 ELSE 0 END) AS Step_4_Shipping,
        MAX(CASE WHEN pv.pageview_url = '/billing' THEN 1 ELSE 0 END) AS Step_5_Billing,
        MAX(CASE WHEN pv.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS Step_6_Order
    FROM 
        PageViews pv
    GROUP BY 
        pv.website_session_id
)
SELECT 
    COUNT(DISTINCT website_session_id) AS Total_Sessions,
    SUM(Step_1_Home) AS Home_Page_Visits,
    SUM(CASE WHEN Step_1_Home = 1 AND Step_2_Products = 1 THEN 1 ELSE 0 END) AS Product_Page_Visits,
    SUM(CASE WHEN Step_1_Home = 1 AND Step_2_Products = 1 AND Step_3_Cart = 1 THEN 1 ELSE 0 END) AS Cart_Page_Visits,
    SUM(CASE WHEN Step_1_Home = 1 AND Step_2_Products = 1 AND Step_3_Cart = 1 AND Step_4_Shipping = 1 THEN 1 ELSE 0 END) AS Shipping_Page_Visits,
    SUM(CASE WHEN Step_1_Home = 1 AND Step_2_Products = 1 AND Step_3_Cart = 1 AND Step_4_Shipping = 1 AND Step_5_Billing = 1 THEN 1 ELSE 0 END) AS Billing_Page_Visits,
    SUM(CASE WHEN Step_1_Home = 1 AND Step_2_Products = 1 AND Step_3_Cart = 1 AND Step_4_Shipping = 1 AND Step_5_Billing = 1 AND Step_6_Order = 1 THEN 1 ELSE 0 END) AS Order_Confirmations
FROM 
    FunnelSteps;
      


	                                           -- \\\ Conversion Funnel for Landerpage sessions \\\ --


WITH PageViews AS (
    SELECT 
        wp.website_session_id,
        wp.pageview_url,
        wp.created_at,
        ROW_NUMBER() OVER (PARTITION BY wp.website_session_id ORDER BY wp.created_at) AS step_number
    FROM 
        website_pageviews wp
    WHERE 
        wp.pageview_url IN ('/lander-1', '/products', '/cart', '/shipping', '/billing', '/thank-you-for-your-order')
),
FunnelSteps AS (
    SELECT 
        pv.website_session_id,
        MAX(CASE WHEN pv.pageview_url = '/lander-1' THEN 1 ELSE 0 END) AS Step_1_Lander1,
        MAX(CASE WHEN pv.pageview_url = '/products' THEN 1 ELSE 0 END) AS Step_2_Products,
        MAX(CASE WHEN pv.pageview_url = '/cart' THEN 1 ELSE 0 END) AS Step_3_Cart,
        MAX(CASE WHEN pv.pageview_url = '/shipping' THEN 1 ELSE 0 END) AS Step_4_Shipping,
        MAX(CASE WHEN pv.pageview_url = '/billing' THEN 1 ELSE 0 END) AS Step_5_Billing,
        MAX(CASE WHEN pv.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS Step_6_Order
    FROM 
        PageViews pv
    GROUP BY 
        pv.website_session_id
)
SELECT 
    COUNT(DISTINCT website_session_id) AS Total_Sessions,
    SUM(Step_1_Lander1) AS Lander_Page_Visits,
    SUM(CASE WHEN Step_1_Lander1 = 1 AND Step_2_Products = 1 THEN 1 ELSE 0 END) AS Product_Page_Visits,
    SUM(CASE WHEN Step_1_Lander1 = 1 AND Step_2_Products = 1 AND Step_3_Cart = 1 THEN 1 ELSE 0 END) AS Cart_Page_Visits,
    SUM(CASE WHEN Step_1_Lander1 = 1 AND Step_2_Products = 1 AND Step_3_Cart = 1 AND Step_4_Shipping = 1 THEN 1 ELSE 0 END) AS Shipping_Page_Visits,
    SUM(CASE WHEN Step_1_Lander1 = 1 AND Step_2_Products = 1 AND Step_3_Cart = 1 AND Step_4_Shipping = 1 AND Step_5_Billing = 1 THEN 1 ELSE 0 END) AS Billing_Page_Visits,
    SUM(CASE WHEN Step_1_Lander1 = 1 AND Step_2_Products = 1 AND Step_3_Cart = 1 AND Step_4_Shipping = 1 AND Step_5_Billing = 1 AND Step_6_Order = 1 THEN 1 ELSE 0 END) AS Order_Confirmations
FROM 
    FunnelSteps;