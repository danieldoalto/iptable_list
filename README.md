# IPTABLES CHAIN EXPLORER

Este é um script de shell interativo projetado para facilitar a visualização e a exploração das regras do `iptables` no Linux. Ele oferece uma interface de menu de texto (TUI) que simplifica a navegação por tabelas e chains, tornando o processo mais intuitivo do que usar os comandos brutos do `iptables`.

## Funcionalidades

- **Navegação Interativa:** Um menu fácil de usar para selecionar tabelas e chains do `iptables`.
- **Listagem de Tabelas:** Detecta e lista automaticamente as tabelas disponíveis (`filter`, `nat`, `mangle`, `raw`, `security`).
- **Visualização de Chains:** Para cada tabela, lista as chains existentes e exibe a contagem de regras em cada uma.
- **Exibição Formatada de Regras:** Apresenta as regras de uma chain específica em um formato de tabela claro e legível.
- **Opções de Ordenação:** Permite ordenar as regras por diferentes critérios:
    - Ordem original (padrão do `iptables`).
    - Ordem alfabética (pelo campo `target`).
    - Por número de pacotes processados (ordem decrescente).
- **Listagem Completa:** Uma opção para exibir todas as regras de todas as tabelas e chains de uma só vez.
- **Otimização de Desempenho:**
    - **Cache:** Armazena em cache os resultados da pesquisa de chains para acelerar a navegação e reduzir a carga no sistema.
    - **Spinner de Carregamento:** Exibe uma animação de carregamento para operações demoradas, melhorando a experiência do usuário.
- **Código Colorido:** Utiliza cores para diferenciar tabelas, chains e outras informações, melhorando a legibilidade.

## Como Usar

### Requisitos

- O script deve ser executado com privilégios de superusuário (`root` ou `sudo`), pois o comando `iptables` requer acesso elevado.

### Execução

1.  Torne o script executável (se necessário):
    ```bash
    chmod +x ipt_list_chain.sh
    ```

2.  Execute o script com `sudo`:
    ```bash
    sudo ./ipt_list_chain.sh
    ```

### Navegação

- Ao iniciar, o script apresentará uma lista das tabelas `iptables` disponíveis.
- Digite o número da tabela desejada e pressione `Enter`.
- Em seguida, será exibida uma lista de chains para a tabela selecionada. Digite o número da chain.
- Escolha uma das opções de ordenação para as regras.
- As regras serão exibidas na tela.
- Você pode usar as opções do menu para voltar (`b`), sair (`q`) ou continuar explorando.
