# Scripts de Gerenciamento de Iptables

Este repositório contém dois scripts de shell para facilitar o gerenciamento e a visualização de regras do `iptables` no Linux.

## Scripts

### 1. IPTABLES CHAIN EXPLORER (`iptables_list/`)

Este é um script de shell interativo projetado para facilitar a visualização e a exploração das regras do `iptables`. Ele oferece uma interface de menu de texto (TUI) que simplifica a navegação por tabelas e chains, tornando o processo mais intuitivo do que usar os comandos brutos do `iptables`.

#### Funcionalidades

- **Navegação Interativa:** Um menu fácil de usar para selecionar tabelas e chains do `iptables`.
- **Listagem de Tabelas:** Detecta e lista automaticamente as tabelas disponíveis (`filter`, `nat`, `mangle`, `raw`, `security`).
- **Visualização de Chains:** Para cada tabela, lista as chains existentes e exibe a contagem de regras em cada uma.
- **Exibição Formatada de Regras:** Apresenta as regras de uma chain específica em um formato de tabela claro e legível.
- **Opções de Ordenação:** Permite ordenar as regras por diferentes critérios.
- **Listagem Completa:** Uma opção para exibir todas as regras de todas as tabelas e chains de uma só vez.
- **Otimização de Desempenho:** Cache e animação de carregamento para melhorar a experiência do usuário.
- **Código Colorido:** Utiliza cores para melhorar a legibilidade.

#### Como Usar

1.  Navegue até o diretório:
    ```bash
    cd iptables_list
    ```
2.  Torne o script executável:
    ```bash
    chmod +x ipt_list_chain.sh
    ```
3.  Execute com `sudo`:
    ```bash
    sudo ./ipt_list_chain.sh
    ```

---

### 2. Gerenciador de Firewall (Start/Stop) (`ipt_start_stop/`)

Este script oferece uma interface de menu para gerenciar o estado do firewall `iptables`, com foco em salvar e restaurar configurações de forma segura.

#### Funcionalidades

- **Parar/Iniciar Firewall:** Permite parar o firewall (liberando todo o tráfego) e iniciar (restaurando o último backup).
- **Backup de Regras:** Cria um backup das regras atuais do `iptables` antes de parar o firewall. Os backups são salvos em `/var/log/iptables_backups` com data e hora.
- **Restauração de Backups:**
    - Restaura o último backup automaticamente.
    - Permite escolher e restaurar um backup específico de uma lista.
- **Gerenciamento de Backups:**
    - Lista todos os backups salvos com detalhes.
    - Visualiza o conteúdo de um arquivo de backup.
    - Compara as regras atuais com um backup salvo.
    - Gerenciamento avançado para limpar backups antigos (por quantidade ou por idade).

#### Como Usar

1.  Navegue até o diretório:
    ```bash
    cd ipt_start_stop
    ```
2.  Torne o script executável:
    ```bash
    chmod +x ipt_start_stop2.sh
    ```
3.  Execute com `sudo`:
    ```bash
    sudo ./ipt_start_stop2.sh
    ```
