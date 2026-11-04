-- =====================================================================
-- 01 - KPIs mensais (comercial, logistica, satisfacao)
-- =====================================================================

WITH it AS (
    SELECT
        order_id
        , SUM(price)         AS gmv
        , SUM(freight_value) AS frete
    FROM FIAP.HOMOLOG_DATA.ORDER_ITEMS
    GROUP BY 1
)
, rv AS (
    SELECT
        order_id
        , AVG(review_score) AS nota
    FROM FIAP.HOMOLOG_DATA.ORDER_REVIEWS
    GROUP BY 1
)

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE                              AS mes
    , COUNT(*)                                                                         AS pedidos
    , COUNT(DISTINCT c.customer_unique_id)                                             AS clientes
    , ROUND(SUM(it.gmv))                                                               AS gmv
    , ROUND(SUM(it.gmv) / COUNT(*), 1)                                                 AS ticket
    , ROUND(100 * SUM(it.frete) / SUM(it.gmv), 1)                                      AS frete_pct
    , ROUND(AVG(DATEDIFF('day', o.order_purchase_timestamp, o.order_delivered_customer_date)), 1) AS lead_dias
    , ROUND(
        100 * AVG(
            IFF(
                o.order_delivered_customer_date > o.order_estimated_delivery_date
                , 1
                , 0
            )
        )
        , 1
    )                                                                                  AS atraso_pct
    , ROUND(AVG(rv.nota), 2)                                                           AS nota
FROM FIAP.HOMOLOG_DATA.ORDERS o
JOIN FIAP.HOMOLOG_DATA.CUSTOMERS c
    USING (customer_id)
JOIN it
    USING (order_id)
LEFT JOIN rv
    USING (order_id)
WHERE o.order_status NOT IN (
    'canceled'
    , 'unavailable'
)
GROUP BY 1
ORDER BY 1;