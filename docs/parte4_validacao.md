# Parte 4 — Validação dos dados com o cliente

## Objetivo da reunião

Vou apresentar o fechamento das vendas de fevereiro de 2025 e conferir com o responsável pela loja se os valores coincidem com o relatório comercial. Também vou mostrar os pedidos e as notas que precisam de confirmação antes de classificar uma mercadoria como pendente.

As consultas usadas na reunião estão em `sql/04_validacao.sql`. As consultas V1 e V9 analisam fevereiro. As verificações V2 a V8 examinam a base completa, pois um pedido e seu recebimento podem ocorrer em meses diferentes.

## 1. Conferência das vendas de fevereiro

Começarei pela consulta V1, comparando o resultado de cada filial com o fechamento oficial da loja.

| Filial | Linhas de venda | Quantidade registrada | Valor bruto |
| --- | ---: | ---: | ---: |
| 1 | 13 | 170,22 | R$ 13.545,64 |
| 2 | 1 | 3,00 | R$ 547,53 |
| Total da rede | 14 | 173,22 | R$ 14.093,17 |

Para demonstrar o cálculo, vou localizar o produto P14 na planilha. Em 07/02/2025, foram registradas 53 unidades a R$ 106,30 cada, totalizando R$ 5.633,90. Esse valor pode ser comparado com a consulta por produto em `sql/02_consultas.sql`.

Perguntarei ao cliente se o fechamento oficial usa vendas brutas e se o arredondamento é feito por item ou ao final da soma.

## 2. Divergências encontradas e perguntas ao cliente

| Consulta | Resultado encontrado | O que confirmar |
| --- | --- | --- |
| V2 | 13 linhas de venda sem cadastro do produto na respectiva filial. | Existe outro cadastro de produtos ou filiais que precisa ser importado? |
| V3 | 5 vendas têm quantidade fracionária e unidade marcada como `UN`. | Esses produtos podem ser vendidos em frações? A unidade está correta? |
| V4 | 20 pedidos apresentam data de entrega anterior à data do pedido. | O campo representa uma entrega realizada ou uma previsão? Qual é a data correta? |
| V5 | 11 pedidos, de número 19 a 29, têm `ordem_compra` igual a zero. | Qual é a ordem correta para localizar o recebimento de cada item? |
| V6 | As notas `NFE19` e `NFE20` ficaram sem pedido correspondente pela combinação de ordem, filial e produto. | A quais pedidos pertencem essas duas notas? |
| V7 | 18 registros apresentaram pelo menos uma divergência de quantidade ou de data na comparação entre pedido e entrada. | Qual documento registra a quantidade efetivamente recebida e em qual data? |
| V8 | 9 linhas de pedidos continham valores adicionais em colunas sem cabeçalho no Excel. | O que essas colunas representam e como devem ser utilizadas? |

Um exemplo para discutir na reunião é a ordem 1, do produto P1. Foram pedidas 96 unidades. O pedido informa 10 unidades entregues, enquanto a nota registra 77 recebidas. Vou solicitar o comprovante de recebimento para identificar qual registro precisa de ajuste.

## 3. Conferência da frequência das requisições

Na consulta V9, cada pedido distinto de um produto conta como uma requisição. Em fevereiro, o maior resultado foi de dois pedidos por produto. Por isso, nenhum produto apareceu no relatório que exige mais de dez requisições. Vou confirmar com o cliente se esse é o critério utilizado pela loja.

## 4. Encerramento

Para cada divergência, vou registrar o documento consultado, a decisão do cliente e a correção autorizada. Depois dos ajustes, as consultas serão executadas novamente e os resultados serão comparados com o fechamento oficial. Os pedidos sem ordem válida ficarão pendentes de confirmação até que seja possível identificar as notas correspondentes.
