-- =====================================================
-- Consulta carregada no Power BI: compras_mensal
-- =====================================================
SELECT c.id_produto,
       p.nome,
       DATEFROMPARTS(YEAR(c.data_compra), MONTH(c.data_compra), 1) AS mes,
       ROUND(SUM(c.quantidade * c.custo_unitario_usd) / SUM(c.quantidade), 2) AS custo_medio_ponderado_usd
FROM dbo.compras c
JOIN dbo.produtos p ON c.id_produto = p.id_produto
WHERE c.data_compra >= '2025-10-01'
GROUP BY c.id_produto, p.nome,
         DATEFROMPARTS(YEAR(c.data_compra), MONTH(c.data_compra), 1);