-- =====================================================================
-- 03 - Top 10 categorias por GMV, nota e crescimento Jan-Ago 2018 vs Jan-Ago 2017
-- =====================================================================

WITH b AS (
    SELECT
        COALESCE(
            t.c2
            , p.product_category_name
            , 'sem_categoria'
        )                                                  AS cat
        , i.order_id
        , i.price
        , o.order_purchase_timestamp                       AS ts
    FROM FIAP.HOMOLOG_DATA.ORDER_ITEMS i
    JOIN FIAP.HOMOLOG_DATA.ORDERS o
        USING (order_id)
    JOIN FIAP.HOMOLOG_DATA.PRODUCTS p
        USING (product_id)
    LEFT JOIN FIAP.HOMOLOG_DATA.CATEGORY_TRANSLATION t
        ON t.c1 = p.product_category_name
    WHERE o.order_status NOT IN (
        'canceled'
        , 'unavailable'
    )
)
, rv AS (
    SELECT
        order_id
        , AVG(review_score)                                AS nota
    FROM FIAP.HOMOLOG_DATA.ORDER_REVIEWS
    GROUP BY 1
)

SELECT
    cat                                                    AS cat
    , ROUND(SUM(price))                                    AS gmv
    , ROUND(
        100 * RATIO_TO_REPORT(SUM(price)) OVER ()
        , 1
    )                                                      AS share
    , ROUND(AVG(nota), 2)                                  AS nota
    , ROUND(
        100 * (
            SUM(
                IFF(
                    ts BETWEEN '2018-01-01'
                        AND '2018-08-31 23:59:59'
                    , price
                    , 0
                )
            )
            / NULLIF(
                SUM(
                    IFF(
                        ts BETWEEN '2017-01-01'
                            AND '2017-08-31 23:59:59'
                        , price
                        , 0
                    )
                )
                , 0
            ) - 1
        )
    )                                                      AS cresc_jan_ago_pct
FROM b
LEFT JOIN rv
    USING (order_id)
GROUP BY 1
QUALIFY ROW_NUMBER() OVER (
    ORDER BY gmv DESC
) <= 10
ORDER BY gmv DESC;