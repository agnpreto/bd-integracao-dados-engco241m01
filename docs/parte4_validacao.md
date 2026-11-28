# Parte 4 — Roteiro de validacao com o cliente (fevereiro/2025)

**Equipe:** SELECT * FROM EU — Rick Iury Oliveira Andrade (2417667)

## Objetivo da reuniao

Validar os dados de fevereiro/2025 antes de considerar corretos os
resultados financeiros e operacionais. Separar o que a planilha informa
do que pode ser comprovado pelas notas fiscais e pelo cadastro da loja.

**Referencia inicial da auditoria do Excel:** 14 registros de venda no periodo,
173,22 unidades e R$ 14.093,1704 antes do arredondamento.
**Status:** totais confirmados por testes automatizados nos dois bancos em 19/11/2026.

## 1. Pontos a validar com o cliente

1. As cinco abas representam o mesmo periodo e as mesmas filiais?
2. Cada venda e um item/linha, e nao necessariamente uma nota inteira?
3. Produto sem cadastro pode ser vendido? O cadastro e por filial?
4. O campo ordem_compra = 0 significa pedido sem ordem ou ausencia de dado?
5. As entradas estao vinculadas aos pedidos por ordem_compra,
   item e produto_id? O cliente confirma essa composicao da chave?
6. A coluna qtde_entregue do pedido representa quantidade efetivamente
   recebida ou apenas status/previsao? Qual fonte prevalece quando diverge da NFE?
7. Existem recebimentos parciais, devolucoes ou entregas antecipadas?
8. A data_entrega e prevista ou real? Pode ser anterior a data_pedido?
9. As 99 celulas extras sem cabecalho na aba pedido_compra correspondem
   a dados historicos deslocados, duplicados, ou devem formar outras colunas?
10. A receita considera descontos, impostos, cancelamentos ou apenas
    qtde_vendida * valor_unitario?
11. A quantidade fracionaria (173,22 unidades no periodo) e valida
    para as unidades de medida informadas?
12. Qual criterio de arredondamento por item/nota/total deve ser aplicado?
13. A trigger pode criar fornecedor **provisorio** ou o cliente exige
    aprovacao de um cadastro real antes de gerar o ID?

## 2. Metodos para garantir exatidao

- Preservar a planilha original, guardando uma copia e registrando a versao.
- Validar colunas, tipos, dados obrigatorios, datas e chaves primarias.
- Contar as linhas por aba e comparar com SELECT COUNT(*) por tabela (V01).
- Confrontar os totais do periodo com o calculo item a item (V02).
- Fazer LEFT JOIN / NOT EXISTS para nao excluir vendas e pedidos sem cadastro.
- Conferir pedidos contra notas fiscais por chave composta, nao somente por
  descricao textual ou quantidade informada.
- Reconciliar diferencas com o cliente, sem sobrescrever dados de origem.
- Registrar cada decisao, responsavel, data, consulta SQL e resultado.
- Guardar query e log de importacao, separando esperado de executado.
- Executar o teste da trigger em transacao e encerrar com ROLLBACK.

## 3. Consultas preparadas

Todas no arquivo sql/04_validacao.sql:

| Consulta | O que verifica |
| --- | --- |
| V01 | Contagem exata de registros por tabela |
| V02 | Total de vendas de fevereiro/2025 com precisao decimal |
| V03 | Vendas de produtos sem cadastro na filial |
| V04 | Pedidos com ordem_compra zero |
| V05 | Pedidos sem recebimento vinculado |
| V06 | Entradas sem pedido correspondente |
| V07 | Quantidade recebida maior que a pedida |
| V08 | Entrada anterior ao pedido |
| V09 | Entrega informada antes da data do pedido |
| V10 | Divergencia entre entrega informada e NFE |
| V11 | Saldo pendente calculado divergente |
| V12 e V13 | Fornecedor referenciado sem cadastro |
| V14 e V15 | Quantidades e precos invalidos |
| V16 | Entradas registradas em fevereiro |
| V17 | Cadastro automatico de fornecedor, pendente de validacao |

## 4. Inconsistencias encontradas na planilha

As quantidades a seguir foram levantadas pela auditoria do arquivo de origem.
**Foram posteriormente confirmadas nas consultas automatizadas dos dois bancos**
para os itens explicitamente cobertos pelos testes (V03, V04, V05, V06,
V08 e V09). As demais verificacoes constam do SQL e exigem revisao humana.
Os mesmos casos podem pertencer a mais de uma categoria, portanto nao
somar os numeros como se fossem registros exclusivos.

| Tabela/origem | Problema observado | Ocorrencias de referencia | Comprovacao |
| --- | --- | ---: | --- |
| pedido_compra (Excel) | Celulas extras preenchidas sem cabecalho | 99 celulas | Conferir docs/celulas_sem_cabecalho.csv, gerado pelo importador |
| pedido_compra | ordem_compra = 0 | 11 pedidos | V04 |
| pedido_compra | Pedido sem entrada vinculada | 11 pedidos | V05 |
| entradas_mercadoria | Entrada sem pedido correspondente | 2 entradas | V06 |
| venda | Produto vendido sem cadastro na filial | 13 vendas | V03 |
| entradas_mercadoria / pedido_compra | Quantidade da NFE superior ao pedido | 7 vinculos | V07 |
| entradas_mercadoria / pedido_compra | Entrada registrada antes do pedido | 9 vinculos | V08 |
| pedido_compra | Data de entrega anterior a data do pedido | 20 pedidos | V09 |
| pedido_compra / entradas_mercadoria | Divergencia entre entrega informada e NFE | A contar no banco | V10 |
| pedido_compra | Saldo pendente divergente | A contar no banco | V11 |
| venda / pedido_compra | Quantidades ou valores invalidos | A contar no banco | V14, V15 |
| fornecedor | Cadastro e referencias inconsistentes | A contar no banco | V12, V13 |

**Interpretacao dos dados:** uma entrada sem pedido vinculado nao e automaticamente
mercadoria nao recebida; um pedido sem NFE vinculada nao prova que nunca foi
entregue. A conclusao depende do vinculo de ordem de compra e da confirmacao
do cliente. Da mesma forma, a coluna data_entrega pode representar previsao,
nao movimento efetivo, e isso deve ser validado.

## 5. Sequencia da reuniao

1. Mostrar planilha original e as contagens por aba.
2. Executar V01 e V02; confrontar totais esperados e obtidos.
3. Exibir V03-V10 para explicar o impacto das excecoes.
4. Solicitar ao cliente a interpretacao dos dados sem cabecalho.
5. Concordar com regra de vinculo e arredondamento.
6. Testar e revisar trigger e cadastro provisório do fornecedor.
7. Registrar aprovacao ou pendencias, evitando alterar dados sem rastreabilidade.

## 6. Status da validacao

- [x] Roteiro e consultas preparados.
- [x] Excecoes da planilha levantadas para investigacao.
- [x] Importacao confirmada no PostgreSQL 16 via GitHub Actions.
- [x] Importacao confirmada no MySQL 8.0 via GitHub Actions.
- [x] Consultas executadas em ambos SGBDs e resultados registrados nos logs.
- [x] Trigger testada em transacao revertida nos dois SGBDs.
- [ ] Regras de negocio confirmadas pelo cliente/professor.

Nao marcar os testes como concluidos sem provas de execucao.


**Evidencia de teste:** https://github.com/Ricklindo223/bd-integracao-dados-engco241m01/actions/runs/44586259937

Os testes nao substituem a decisao do cliente sobre dados inconsistentes
nem a confirmacao do professor sobre entrega individual.
