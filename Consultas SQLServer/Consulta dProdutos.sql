-- =====================================================
-- Consulta carregada no Power BI: dProdutos (dimensão)
-- =====================================================
SELECT p.id_produto,
       p.nome,
       p.categoria,
       f.nome AS fornecedor
FROM dbo.produtos p
JOIN dbo.fornecedores f ON p.id_fornecedor = f.id_fornecedor;