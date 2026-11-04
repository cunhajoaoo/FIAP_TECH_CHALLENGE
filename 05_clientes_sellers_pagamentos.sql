-- =====================================================================
-- 05 - Retencao de clientes, concentracao de sellers e mix de pagamento
-- Cliente = CUSTOMER_UNIQUE_ID (CUSTOMER_ID e unico por pedido).
-- =====================================================================

WITH c AS (
    SELECT
        cu.customer_unique_id
        , COUNT(DISTINCT o.order_id) AS n
    FROM FIAP.HOMOLOG_DATA.ORDERS o
    JOIN FIAP.HOMOLOG_DATA.CUSTOMERS cu
        USING (customer_id)
    WHERE o.order_status NOT IN (
        'canceled'
        , 'unavailable'
    )
    GROUP BY 1
)

SELECT
    COUNT(*)                                        AS clientes
    , SUM(IFF(n > 1, 1, 0))                         AS recompradores
    , ROUND(
        100 * AVG(IFF(n > 1, 1, 0))
        , 2
    )                                               AS taxa_recompra
    , ROUND(
        AVG(n)
        , 3
    )                                               AS pedidos_por_cliente
FROM c;

-- 5b. Concentracao de sellers (top 10% dos sellers)
-- e % de itens vendidos por sellers de SP

WITH s AS (
    SELECT
        seller_id
        , SUM(price) AS g
    FROM FIAP.HOMOLOG_DATA.ORDER_ITEMS
    GROUP BY 1
)
, r AS (
    SELECT
        g
        , ROW_NUMBER() OVER (
            ORDER BY g DESC
        )                     AS rn
        , COUNT(*) OVER ()    AS n
        , SUM(g) OVER ()      AS t
    FROM s
)

SELECT
    MAX(n)                                                        AS sellers
    , ROUND(
        100 * SUM(IFF(rn <= n * 0.1, g, 0)) / MAX(t)
        , 1
    )                                                             AS share_top10pct
    , (
        SELECT
            ROUND(
                100 * AVG(
                    IFF(
                        se.seller_state = 'SP'
                        , 1
                        , 0
                    )
                )
                , 1
            )
        FROM FIAP.HOMOLOG_DATA.ORDER_ITEMS i
        JOIN FIAP.HOMOLOG_DATA.SELLERS se
            USING (seller_id)
    )                                                             AS pct_itens_seller_sp
FROM r;

-- 5c. Mix de pagamento

SELECT
    payment_type                                                  AS payment_type
    , COUNT(DISTINCT order_id)                                    AS pedidos
    , ROUND(
        100 * RATIO_TO_REPORT(SUM(payment_value)) OVER ()
        , 1
    )                                                             AS share_valor
    , ROUND(
        AVG(payment_installments)
        , 1
    )                                                             AS parcelas_med
FROM FIAP.HOMOLOG_DATA.PAYMENTS
GROUP BY 1
ORDER BY share_valor DESC;