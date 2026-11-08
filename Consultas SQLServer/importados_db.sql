-- =====================================================
-- Projeto: Margem de importados x impacto do dólar
-- Banco: importados_db (SQL Server / T-SQL)
-- Período dos dados: jan/2025 a set/2026 (fictícios)
-- =====================================================

USE master;
GO

IF DB_ID('importados_db') IS NOT NULL
BEGIN
    ALTER DATABASE importados_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE importados_db;
END
GO

CREATE DATABASE importados_db;
GO

USE importados_db;
GO

-- ---------- TABELAS ----------
CREATE TABLE fornecedores (
    id_fornecedor INT IDENTITY(1,1) PRIMARY KEY,
    nome          VARCHAR(80) NOT NULL,
    pais          VARCHAR(40) NOT NULL
);

CREATE TABLE produtos (
    id_produto     INT IDENTITY(1,1) PRIMARY KEY,
    nome           VARCHAR(80) NOT NULL,
    categoria      VARCHAR(40) NOT NULL,
    id_fornecedor  INT NOT NULL REFERENCES fornecedores(id_fornecedor),
    custo_base_usd DECIMAL(10,2) NOT NULL,
    preco_base_brl DECIMAL(10,2) NOT NULL
);

CREATE TABLE compras (
    id_compra          INT IDENTITY(1,1) PRIMARY KEY,
    id_produto         INT NOT NULL REFERENCES produtos(id_produto),
    data_compra        DATE NOT NULL,
    quantidade         INT NOT NULL,
    custo_unitario_usd DECIMAL(10,2) NOT NULL
);

CREATE TABLE vendas (
    id_venda           INT IDENTITY(1,1) PRIMARY KEY,
    id_produto         INT NOT NULL REFERENCES produtos(id_produto),
    data_venda         DATE NOT NULL,
    quantidade         INT NOT NULL,
    preco_unitario_brl DECIMAL(10,2) NOT NULL,
    canal              VARCHAR(20) NOT NULL
);
GO

-- ---------- DADOS BASE ----------
INSERT INTO fornecedores (nome, pais) VALUES
(N'Shenzhen Tech Co',      N'China'),
(N'Seoul Gadgets',         N'Coreia do Sul'),
(N'Miami Distribuidora',   N'EUA'),
(N'Hong Kong Trading',     N'China'),
(N'Taipei Components',     N'Taiwan');

INSERT INTO produtos (nome, categoria, id_fornecedor, custo_base_usd, preco_base_brl) VALUES
(N'Fone Bluetooth TWS',     N'Áudio',       1,  9.50, 129.90),
(N'Carregador Turbo 65W',   N'Acessórios',  1,  7.80, 119.90),
(N'Smartwatch Fit',         N'Wearables',   4, 22.00, 299.90),
(N'Caixa de Som Portátil',  N'Áudio',       2, 15.00, 199.90),
(N'Power Bank 20000mAh',    N'Acessórios',  1, 12.50, 179.90),
(N'Webcam Full HD',         N'Periféricos', 5, 14.00, 189.90),
(N'Mouse Gamer RGB',        N'Periféricos', 5,  8.00, 119.90),
(N'Teclado Mecânico',       N'Periféricos', 2, 25.00, 329.90),
(N'Cabo USB-C 2m',          N'Acessórios',  3,  2.20,  39.90),
(N'Capa Anti-impacto',      N'Acessórios',  3,  3.00,  59.90),
(N'Fone Over-ear',          N'Áudio',       4, 18.00, 249.90),
(N'Hub USB-C 7 em 1',       N'Acessórios',  5, 16.00, 219.90);
GO

-- ---------- COMPRAS: 1 por produto por mês (21 meses) ----------
WITH meses AS (
    SELECT 0 AS n
    UNION ALL
    SELECT n + 1 FROM meses WHERE n < 20
)
INSERT INTO compras (id_produto, data_compra, quantidade, custo_unitario_usd)
SELECT p.id_produto,
       DATEADD(MONTH, m.n, CAST('2025-01-05' AS DATE)),
       50 + ((p.id_produto * 17 + m.n * 13) % 60),
       ROUND(p.custo_base_usd * (1 + (((p.id_produto + m.n * 7) % 9) - 4) / 100.0), 2)
FROM meses m
CROSS JOIN produtos p;
GO

-- ---------- VENDAS: 4 por produto por mês ----------
WITH meses AS (
    SELECT 0 AS n
    UNION ALL
    SELECT n + 1 FROM meses WHERE n < 20
),
vezes AS (
    SELECT 1 AS k
    UNION ALL
    SELECT k + 1 FROM vezes WHERE k < 4
)
INSERT INTO vendas (id_produto, data_venda, quantidade, preco_unitario_brl, canal)
SELECT p.id_produto,
       DATEADD(DAY, v.k * 4 + p.id_produto - 1, DATEADD(MONTH, m.n, CAST('2025-01-01' AS DATE))),
       1 + ((p.id_produto * 3 + m.n + v.k * 5) % 8),
       ROUND(p.preco_base_brl * (1 + (m.n / 7) * 0.04), 2),
       CHOOSE(1 + ((p.id_produto + m.n + v.k) % 3), N'Loja', N'Online', N'Atacado')
FROM meses m
CROSS JOIN vezes v
CROSS JOIN produtos p;
GO

-- ---------- CONFERÊNCIA ----------
-- Esperado: fornecedores 5 | produtos 12 | compras 252 | vendas 1008
SELECT 'fornecedores' AS tabela, COUNT(*) AS linhas FROM fornecedores
UNION ALL SELECT 'produtos',  COUNT(*) FROM produtos
UNION ALL SELECT 'compras',   COUNT(*) FROM compras
UNION ALL SELECT 'vendas',    COUNT(*) FROM vendas;
GO
