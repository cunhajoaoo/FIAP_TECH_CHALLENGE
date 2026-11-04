-- =====================================================================
-- 04 - Logistica e satisfacao por UF do cliente (pedidos entregues)
-- =====================================================================

WITH rv AS (
    SELECT
        order_id
        , AVG(review_score)                                  AS nota
    FROM FIAP.HOMOLOG_DATA.ORDER_REVIEWS
    GROUP BY 1
)
, it AS (
    SELECT
        order_id
        , SUM(price)                                         AS gmv
        , SUM(freight_value)                                 AS fr
    FROM FIAP.HOMOLOG_DATA.ORDER_ITEMS
    GROUP BY 1
)

SELECT
    c.customer_state                                         AS uf
    , COUNT(*)                                               AS pedidos
    , ROUND(
        100 * RATIO_TO_REPORT(SUM(gmv)) OVER ()
        , 1
    )                                                        AS share_gmv
    , ROUND(
        100 * SUM(fr) / SUM(gmv)
        , 1
    )                                                        AS frete_pct
    , ROUND(
        AVG(
            DATEDIFF(
                'day'
                , o.order_purchase_timestamp
                , o.order_delivered_customer_date
            )
        )
        , 1
    )                                                        AS lead_dias
    , ROUND(
        100 * AVG(
            IFF(
                o.order_delivered_customer_date > o.order_estimated_delivery_date
                , 1
                , 0
            )
        )
        , 1
    )                                                        AS atraso_pct
    , ROUND(
        AVG(nota)
        , 2
    )                                                        AS nota
FROM FIAP.HOMOLOG_DATA.ORDERS o
JOIN FIAP.HOMOLOG_DATA.CUSTOMERS c
    USING (customer_id)
JOIN it
    USING (order_id)
LEFT JOIN rv
    USING (order_id)
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1
ORDER BY pedidos DESC;