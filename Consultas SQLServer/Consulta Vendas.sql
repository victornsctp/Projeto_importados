-- =====================================================
-- Consulta carregada no Power BI: vendas_mensal
-- =====================================================
SELECT p.id_produto,
       p.nome,
       p.categoria,
       f.nome AS fornecedor,
       DATEFROMPARTS(YEAR(v.data_venda), MONTH(v.data_venda), 1) AS mes,
       SUM(v.quantidade) AS unidades,
       SUM(v.quantidade * v.preco_unitario_brl) AS receita
FROM dbo.vendas v
JOIN dbo.produtos p ON v.id_produto = p.id_produto
JOIN dbo.fornecedores f ON p.id_fornecedor = f.id_fornecedor
WHERE v.data_venda >= '2025-10-01'
GROUP BY p.id_produto, p.nome, p.categoria, f.nome,
         DATEFROMPARTS(YEAR(v.data_venda), MONTH(v.data_venda), 1);