# Margem de Importados x Dólar

Dashboard em Power BI conectado a um banco **SQL Server** e à **API PTAX do Banco Central**, para analisar como a variação do dólar afeta a margem de uma loja fictícia de produtos importados.

---

## Sobre o projeto

Uma loja que importa produtos paga seus fornecedores em **dólar**, mas vende em **real**. Quando o câmbio muda, o custo muda, e a margem muda junto, mesmo que o preço de venda continue o mesmo.

Este projeto responde a três perguntas:

- Qual é a margem bruta da loja (em R$ e em %) e como ela evolui mês a mês?
- Quanto da variação da margem vem do câmbio?
- Quais produtos e fornecedores concentram a margem?

> **Os dados são fictícios**, gerados por script. Já a cotação do dólar é real e vem da API pública do Banco Central.

## O que este projeto demonstra

- **Conexão direta Power BI ↔ SQL Server** com consulta nativa: filtros e agregações são feitos em SQL, e só o que importa é carregado.
- **Consumo de API REST pública via URL** (Web + Power Query), sem chave de acesso.
- **Modelagem em esquema estrela**, com tabelas de fatos separadas de dimensões.
- **Medidas em DAX**, incluindo um cálculo linha a linha que cruza três fontes.
- **Layout no Figma**, usado como plano de fundo do relatório.

## Ferramentas

| Ferramenta | Uso |
|---|---|
| SQL Server Express + SSMS | Banco de dados e execução dos scripts |
| Power BI Desktop | Conexão, modelagem, DAX e visuais |
| API PTAX (Banco Central) | Cotação diária do dólar |
| Figma | Layout do dashboard (1280×720) |

## Fluxo dos dados

```
SQL Server (importados_db) ──[consulta nativa em SQL]──┐
                                                       ├──> Power Query ──> Modelo estrela ──> Dashboard
API PTAX (Banco Central) ────[conector Web, JSON]──────┘
```

## Banco de dados

Banco `importados_db`, com 4 tabelas e dados de **jan/2025 a set/2026**:

| Tabela | Descrição | Linhas |
|---|---|---|
| `fornecedores` | Fornecedores e países | 5 |
| `produtos` | Catálogo (categoria, fornecedor, custo e preço base) | 12 |
| `compras` | Compras mensais por produto, com custo unitário em **USD** | 252 |
| `vendas` | Vendas por produto, com preço unitário em **R$** e canal | 1.008 |

O script em importados_db.sql cria o banco, as tabelas e gera os dados. Os preços de venda sofrem um **reajuste de 4% a cada 7 meses**, para simular a política de preços de uma loja real.

## Consultas usadas no Power BI

Em vez de carregar as tabelas inteiras, o Power BI recebe o resultado de três consultas SQL. O filtro de período está no `WHERE`, para o banco descartar as linhas **antes** de agregar e de enviar os dados.

```sql
SELECT p.id_produto, p.nome, p.categoria, f.nome AS fornecedor,
       DATEFROMPARTS(YEAR(v.data_venda), MONTH(v.data_venda), 1) AS mes,
       SUM(v.quantidade) AS unidades,
       SUM(v.quantidade * v.preco_unitario_brl) AS receita
FROM dbo.vendas v
JOIN dbo.produtos p ON v.id_produto = p.id_produto
JOIN dbo.fornecedores f ON p.id_fornecedor = f.id_fornecedor
WHERE v.data_venda >= '2025-10-01'
GROUP BY p.id_produto, p.nome, p.categoria, f.nome,
         DATEFROMPARTS(YEAR(v.data_venda), MONTH(v.data_venda), 1);
```


```sql
SELECT c.id_produto, p.nome,
       DATEFROMPARTS(YEAR(c.data_compra), MONTH(c.data_compra), 1) AS mes,
       ROUND(SUM(c.quantidade * c.custo_unitario_usd) / SUM(c.quantidade), 2) AS custo_medio_ponderado_usd
FROM dbo.compras c
JOIN dbo.produtos p ON c.id_produto = p.id_produto
WHERE c.data_compra >= '2025-10-01'
GROUP BY c.id_produto, p.nome,
         DATEFROMPARTS(YEAR(c.data_compra), MONTH(c.data_compra), 1);
```

## API do dólar

A cotação vem do serviço PTAX do Banco Central, sem cadastro nem chave. As datas usam o formato **mês-dia-ano**.

```
https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoDolarPeriodo(dataInicial=@dataInicial,dataFinalCotacao=@dataFinalCotacao)?@dataInicial='10-01-2025'&@dataFinalCotacao='09-30-2026'&$top=10000&$format=json&$select=cotacaoCompra,cotacaoVenda,dataHoraCotacao
```

No Power Query, o JSON é convertido em tabela e agrupado por mês, resultando na **média mensal da cotação de venda** (12 linhas, uma por mês). Foi usada a cotação de **venda** por ser a que se paga para comprar dólar.

## Modelo de dados

Esquema estrela: duas tabelas de fatos (`Vendas` e `Compras`) e três tabelas auxiliares.

| Dimensão | Chave | Relaciona com |
|---|---|---|
| `dProdutos` | `id_produto` | `Vendas`, `Compras` |
| `dCalendario` | `Date` (1º dia de cada mês) | `Vendas`, `Compras`, `dDolar` |
| `dDolar` | `mes` | `dCalendario` |

Todas as relações são de **um para muitos**, com o lado "um" nas dimensões. `Vendas` e `Compras` **não** se relacionam diretamente: cada uma tem várias linhas por produto e por mês, e uma relação direta seria de muitos para muitos e geraria valores duplicados. As dimensões funcionam como o ponto de encontro entre elas, e um único segmentador filtra vendas e compras ao mesmo tempo.

Calendário mensal (DAX):

```dax
dCalendario = FILTER(CALENDAR(DATE(2025,10,1), DATE(2026,9,1)), DAY([Date]) = 1)
```

## Medidas DAX

```dax
Receita_Total = SUM(Vendas[receita])

Unidades_Totais = SUM(Vendas[unidades])

Dolar_Medio = AVERAGE(dDolar[cotacao_venda_media])

Custo R$ =
SUMX(
    SUMMARIZE(Vendas, dProdutos[id_produto], dCalendario[Date]),
    CALCULATE(SUM(Vendas[unidades]))
        * CALCULATE(AVERAGE(Compras[custo_medio_ponderado_usd]))
        * CALCULATE(AVERAGE(dDolar[cotacao_venda_media]))
)

Margem R$ = [Receita_Total] - [Custo R$]

Margem % = DIVIDE([Margem R$], [Receita_Total])
```

**Como funciona a medida `Custo R$`:** o custo de cada produto em cada mês é `unidades vendidas × custo unitário em USD × dólar do mês`, e essas três informações estão em tabelas diferentes. A medida cria uma tabela virtual com cada combinação de produto e mês (`SUMMARIZE`), percorre linha a linha (`SUMX`) e, em cada uma, usa `CALCULATE` para transformar "esse produto neste mês" em filtro, que se propaga pelas relações do modelo e devolve o valor correto de cada tabela. O resultado é somado no final. Multiplicar totais já agregados daria um resultado errado, porque cada produto tem custo diferente e o dólar muda todo mês.

## Premissas e limitações

- **Margem bruta:** `Margem R$` é a receita menos o custo da mercadoria, e `Margem %` é essa margem dividida pela receita. Frete, impostos de importação, comissões e despesas fixas **não** estão incluídos, o que explica margens mais altas do que as de uma operação real.
- **Custo do mês:** o custo de cada unidade vendida é o custo médio das compras do **mesmo mês**, sem controle de estoque (PEPS ou custo médio móvel).
- **Câmbio mensal:** o dólar é a média mensal da cotação de venda, e não a cotação do dia de cada compra.
- **Dados fictícios:** vendas, compras e preços são gerados por script, e não refletem uma empresa real.
- **Período:** o dashboard cobre out/2025 a set/2026 (12 meses).

## Resultados

Valores do período analisado (dados fictícios):

| Indicador | Valor |
|---|---|
| Receita | R$ 491,31 mil |
| Custo | R$ 172,06 mil |
| Margem bruta | R$ 319,26 mil |
| Margem bruta (%) | 64,98% |

O que o dashboard mostra:

- **Produtos de custo baixo têm as maiores margens:** Capa Anti-impacto (75,34%) e Cabo USB-C 2m (73,04%) lideram. Os demais ficam entre cerca de 63% e 68%.
- **Fornecedores:** Hong Kong Trading tem a maior margem absoluta (R$ 81 mil). A Miami Distribuidora, que fornece apenas itens baratos, tem a menor (R$ 17 mil).
- **Câmbio x margem:** o dólar variou entre cerca de R$ 5,0 e R$ 5,5 no período. Como o custo representa cerca de **35% da receita**, uma variação de 10% no dólar muda a margem em aproximadamente **3,5 pontos percentuais**, se o preço de venda ficar parado.
- **Cuidado com a leitura do gráfico:** o salto da margem em **mar/2026** não vem do câmbio. Ele coincide com o reajuste de 4% nos preços de venda, simulado nos dados. Separar o efeito do câmbio do efeito do preço é parte da análise.


## Estrutura do repositório

```
├── README.md
├── Consultas SQLServer/
│   ├── importados_db.sql
│   ├── Consulta dProdutos.sql
│   ├── Consulta Compras.sql
│   └── Consulta Vendas.sql
├── Power BI/
│   └── Projeto_importados.pbix
├── Figma/
│   └── Layout Figma.png
└── imagens/
    ├── Dashboard.png
    └── Modelo.png
```

## Autor

**Victor Nascimento**, analista de dados (Power BI, SQL, Python, Excel e n8n).

- Portfólio: [victornasct.lovable.app](https://victornasct.lovable.app/)
