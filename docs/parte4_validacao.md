# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

Objetivo da reunião: o cliente sair sabendo **o que o banco contém, o que já bate com o sistema dele, o que não bate e o que ele precisa decidir**. Todos os números abaixo vêm das consultas de `sql/04_validacao.sql`, rodadas no banco carregado a partir da planilha, e podem ser reproduzidas ao vivo.

Resumo do recorte de fevereiro/2025 (para abrir a reunião): **14 vendas, 173,220 unidades, R$ 14.093,17**; 17 linhas de pedido de compra feitas no mês e 10 notas de entrada (468 unidades).

## 1. Pontos a validar

Em ordem de reunião (cerca de 60 min). Os itens 3 e 4 concentram as decisões que dependem do cliente.

**1. O banco tem o que o cliente mandou (5 min).** Contagem por tabela: 20 fornecedores, 20 produtos, 29 pedidos, 20 entradas, 33 vendas, iguais à planilha. Confirmar que a planilha enviada é a versão final e completa, e **o que é o bloco sem cabeçalho nas colunas M:W da aba `pedido_compra`** (linhas 22 a 30). Ele não entrou no banco; se o cliente disser que o certo é esse bloco, os pedidos 19 e 20 mudam.

**2. Fechamento de fevereiro: os totais batem com o sistema do cliente? (15 min).** Confirmar, com o relatório do ERP dele, as 14 vendas (venda a venda, consulta B2), o total de 173,220 un e de R$ 14.093,17, o total por filial (filial 1: R$ 13.545,64; filial 2: R$ 547,53) e as compras/entradas do mês. É o aceite principal: **se os totais do mês baterem com o ERP, a carga está exata para vendas**.

**3. Cadastro de produtos e filiais (15 min), o principal problema de fevereiro.**
- Seis das 14 vendas de fevereiro (**R$ 3.241,24, 23,0% do mês**) são de produtos **P22 a P27, que não existem no cadastro de produtos**. Esses códigos são reais ou lançamento de teste?
- Vendas nas filiais **2 e 3**, que não têm nenhum produto cadastrado. Essas filiais existem? Falta cadastrar?
- Doze das 14 vendas de fevereiro formam seis pares com a **mesma data e o mesmo valor unitário** em produtos diferentes (P14/P22, P15/P23 ... P19/P27). Lançamento copiado ou coincidência?

**4. Compras e recebimento (15 min).**
- Onze pedidos estão sem ordem de compra (o campo veio `0`), então **não dá para ligá-los às entradas**. Nove são de fevereiro.
- Os pedidos 21 a 29 repetem data, entrega, preço e fornecedor dos pedidos 12 a 20. **São duplicidades?** Se forem, a lista de "requisitado e não recebido" (Parte 2) encolhe de 11 para 2 linhas.
- NFE19 e NFE20 citam as ordens 19 e 20, que não existem em nenhum pedido (ver bloco M:W acima).
- Em 20 de 29 pedidos a data de entrega é **anterior** à data do pedido; em 9 notas a entrada é anterior ao pedido; em 7 casos o recebido é maior que o pedido. Qual das datas é a correta?
- O campo `qtde_entregue` do pedido não coincide com a quantidade da nota em nenhum dos 18 pedidos pareados. Qual deles vale?

**5. Preços e regras de negócio (10 min).**
- Há três preços de compra (cadastro, pedido, nota) e **nenhum coincide** entre si; o preço de venda do cadastro nunca é o preço praticado (20 de 20). Qual é a fonte oficial?
- O que significa `preco_unitario` no cadastro (é diferente de `preco_venda` nos 20 produtos)?
- Quatro produtos (P1, P8, P15, P18) têm preço de venda **menor** que o de compra, e sete vendas saíram abaixo do custo de cadastro. É intencional (promoção) ou erro?
- Cinco vendas têm quantidade fracionada em unidade `UN` (ex.: 38,6 un). A unidade está errada ou o produto é fracionado?
- Todas as vendas têm horário `08:00:00`. O sistema não grava o horário ou foi preenchido com um padrão?
- O prefixo `F` nos fornecedores (`F8`) vs. número puro (`8`) nos pedidos: foram padronizados na carga como número. O cliente concorda?

**6. Decisão e aceite (5 min).** Registrar, para cada item da tabela de erros abaixo, **quem corrige** (cliente na origem ou nós no banco) e o prazo; combinar a nova carga e a revalidação.

## 2. Técnicas para garantir exatidão e precisão

Exatidão = o dado está **certo** (é o que aconteceu de verdade); precisão = está registrado com o **detalhe e a consistência** necessários (casas decimais, unidade, formato). Aqui:

1. **Reconciliação de totais (controle).** Contar linhas e somar quantidade e valor por tabela e por mês na planilha e no banco; os dois lados devem ser **idênticos**. Foi feito (quantidade 421,720; valor R$ 34.768,2152; 1071/434 em pedidos). Na reunião, o cliente compara a mesma soma com o ERP.
2. **Recálculo independente.** O total de fevereiro foi calculado por duas vias diferentes, SQL e pandas, com o mesmo resultado (14 / 173,22 / 14.093,17). Dá confiança de que não é bug de consulta.
3. **Conferência por amostragem e por inteiro.** A consulta B2 lista as 14 vendas do mês para o cliente conferir **todas** (o volume permite, 100%) e, em bases maiores, uma amostra por faixa de valor e por filial, mais todas as exceções.
4. **Regras de integridade como consultas de exceção.** Cada regra de negócio vira uma consulta que **deve devolver 0 linhas** (produto vendido tem cadastro; entrega não é anterior ao pedido; recebido não passa do pedido; toda nota tem pedido; preço de venda ≥ custo). O painel do bloco D lista todas com a contagem; depois da correção, a meta é zerar.
5. **Detecção de duplicidade e cópia.** Mesma chave natural (produto + data + preço + fornecedor) em registros diferentes (E06, E10).
6. **Tipos e arredondamento exatos.** Valores em `numeric` (não `float`) e total do mês arredondado só no final, para o cálculo não perder centavos. Datas como `date` (não texto), evitando a troca dia/mês.
7. **Rastreabilidade.** A planilha original não foi alterada; toda normalização (`F8` → 8, `0` → `NULL`, remoção de espaços) está documentada em `parte1_importacao.md`; o script informa lidas / inseridas / rejeitadas e sai com erro se algo divergir. Os erros do cliente **não foram escondidos**: ficam no banco e são mostrados por consulta.
8. **Revalidação após a correção.** Nova carga, novo painel (bloco D) e novo fechamento (bloco B), com o aceite do cliente por escrito (ata com os totais assinados).

Limite honesto: sem acesso ao ERP do cliente, **exatidão absoluta não dá para provar sozinhos**. Provamos que o banco é fiel à planilha e que a planilha tem inconsistências internas; só o cliente confirma o que é verdade no negócio.

## 3. Consultas preparadas para a reunião

As consultas ficam em `sql/04_validacao.sql`. O que cada uma mostra:

| Consulta | O que mostra | Resultado esperado |
| --- | --- | --- |
| A1 | Linhas por tabela, para comparar com a planilha | 20 / 20 / 29 / 20 / 33 |
| A2 | Vendas por mês (a base cobre janeiro a março; fevereiro é o recorte) | jan 12 · fev 14 · mar 7 vendas |
| B1 | Totais de fevereiro: nº de vendas, quantidade e R$ | 14 · 173,220 · R$ 14.093,17 |
| B2 | Cada venda de fevereiro, para o cliente conferir uma a uma com o ERP, com produto no formato `12345 - Detergente` e data `DD/MM/AAAA` | 14 linhas |
| B3 | Fevereiro por filial | filial 1: 13 vendas; filial 2: 1 venda |
| B4 | Compras do mês: pedidos feitos e notas que entraram | 17 linhas/619 un · 10 linhas/468 un |
| E01 a E19 | Uma consulta por erro, listando as linhas para o cliente ver (tabela abaixo) | contagens da tabela abaixo |
| Painel (bloco D) | Todos os erros numa tabela só, com quantidade e universo; reaplicado após a correção deve mostrar 0 | 19 linhas |

Também usadas na reunião: `sql/02_consultas.sql` (consumo por produto em fevereiro; produtos requisitados e não recebidos, estrito e ampliado) e as views `v_venda_fmt`, `v_pedido_compra_fmt` de `03_transformacoes.sql`.

## Erros encontrados nos dados

"Universo" = quantas linhas poderiam ter o problema. Os ids E01 a E19 são consultas de `sql/04_validacao.sql`; E20 a E22 são da planilha (não existem no banco, pois a carga os normalizou ou ignorou).

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| venda | E01 Venda de produto sem cadastro em `produtos_filial` (P21 a P28; vendas 21 a 33). Em fevereiro: 6 vendas, R$ 3.241,24 | 13 de 33 | `04_validacao.sql` E01 |
| venda | E02 Venda em filial sem cadastro (filiais 2 e 3; vendas 27, 28, 32, 33) | 4 de 33 | E02 |
| venda | E03 Quantidade fracionada em unidade `UN` (vendas 4, 8, 12, 16, 26) | 5 de 33 | E03 |
| venda | E04 Preço da venda diferente do `preco_venda` do cadastro | 20 de 20 comparáveis | E04 |
| venda | E05 Vendida abaixo do custo de cadastro | 7 de 20 comparáveis | E05 |
| venda | E06 Mesma data e mesmo valor unitário em produtos diferentes (vendas 13/21 ... 19/27): suspeita de linha copiada | 7 pares | E06 |
| venda | E07 Horário `08:00:00` em todas as vendas (horário não real) | 33 de 33 | E07 |
| pedido_compra | E08 Data de entrega anterior à data do pedido | 20 de 29 | E08 |
| pedido_compra | E09 Sem `ordem_compra` (era `0`; pedidos 19 a 29): impede ligar à entrada | 11 de 29 | E09 |
| pedido_compra | E10 Possíveis requisições duplicadas (pedidos 12..20 x 21..29: mesmo produto, fornecedor, datas e preço) | 9 pares | E10 |
| pedido_compra | E11 `qtde_entregue` diferente da quantidade recebida na nota | 18 de 18 pareados | E11 |
| pedido_compra | E12 Fornecedor do pedido diferente do fornecedor do cadastro do produto | 22 de 29 | E12 |
| pedido_compra | E13 Preço de compra do pedido diferente do cadastro | 29 de 29 | E13 |
| entradas_mercadoria | E14 Nota com `ordem_compra` que não existe em nenhum pedido (NFE19, NFE20) | 2 de 20 | E14 |
| entradas_mercadoria | E15 Recebido maior que o pedido | 7 de 18 pareados | E15 |
| entradas_mercadoria | E16 Data da nota anterior à data do pedido | 9 de 18 pareados | E16 |
| entradas_mercadoria | E17 Custo da nota diferente do preço do pedido | 18 de 18 pareados | E17 |
| produtos_filial | E18 Preço de venda menor que o de compra (P1, P8, P15, P18) | 4 de 20 | E18 |
| produtos_filial | E19 `preco_unitario` diferente de `preco_venda` (campo sem definição) | 20 de 20 | E19 |
| pedido_compra (planilha) | E20 Bloco de dados fora do layout nas colunas M:W, linhas 22 a 30, sem `pedido_id` nem `fornecedor_id`; P19 e P20 divergem do bloco principal | 9 linhas | Aviso de `python scripts/importar.py` ("AVISO aba 'pedido_compra'"), ou abrir `base_teste.xlsx`, aba `pedido_compra`, M22:W30 |
| fornecedor / produtos_filial (planilha) | E21 Id do fornecedor com prefixo `F` (texto `F8`) em 40 valores, mas numérico em `pedido_compra.fornecedor_id`: três tabelas com formatos diferentes para o mesmo dado | 40 valores em texto (`F8`) contra 29 numéricos | `parte1_importacao.md` (normalização); na planilha: abas `fornecedor` col. A, `produtos_filial` col. H e `pedido_compra` col. L |
| venda (planilha) | E22 Aba `venda` com formato de exibição de data `m/d/aaaa`, diferente das demais (`aaaa-mm-dd`). O valor é uma data real, então a carga não foi afetada, mas no Excel em português há risco de dia e mês trocados (ex.: venda 2, 2 de março) | 33 datas | Conferir amostra com o cliente; no banco: `SELECT venda_id, data_emissao FROM venda ORDER BY 1` |

Erros de estrutura (DDL e script) estão em `parte1_importacao.md`.
