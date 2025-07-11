#!/bin/bash

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variáveis de cache para armazenar os dados das chains e evitar novas pesquisas
declare -g -A chain_menu_cache
declare -g -A chain_options_cache_serialized

# Função para exibir uma animação de carregamento (spinner)
show_spinner() {
    local msg="$1"
    local spinstr='|/-\'
    while true; do
        # O \r no início move o cursor para o começo da linha
        printf "\r${YELLOW}${msg} [%c]${NC}" "${spinstr}"
        spinstr=${spinstr:1}${spinstr:0:1} # Gira a string do spinner
        sleep 0.1
    done
}

# Função para exibir título
show_title() {
    clear
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}  IPTABLES CHAIN EXPLORER       ${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

# Função para listar tabelas disponíveis
list_tables() {
    echo -e "${YELLOW}Tabelas disponíveis:${NC}"
    echo
    
    local counter=1
    declare -g -A table_options
    
    # Lista das tabelas principais
    tables=("filter" "nat" "mangle" "raw" "security")
    
    for table in "${tables[@]}"; do
        # Verifica se a tabela existe e pode ser lida
        if iptables -t "$table" -L -n >/dev/null 2>&1; then
            echo -e "  ${counter}) ${GREEN}$table${NC}"
            table_options[$counter]="$table"
            ((counter++))
        fi
    done
    
    # Adiciona a nova opção para listagem completa
    echo -e "  -------------------------"
    echo -e "  c) ${YELLOW}Listar Completo${NC}"
    echo
    
    return $((counter-1))
}

# Função para listar chains de uma tabela específica (OTIMIZADA COM CACHE E SPINNER)
list_chains() {
    local table="$1"
    
    # Verifica se os dados desta tabela já estão no cache
    if [[ -n "${chain_menu_cache[$table]}" ]]; then
        # CACHE HIT: Usa os dados guardados
        echo -e "${YELLOW}Chains disponíveis na tabela '${GREEN}$table${YELLOW}' (do cache):${NC}"
        echo
        echo -e "${chain_menu_cache[$table]}"
        
        unset chain_options
        declare -g -A chain_options
        local temp_options_array=()
        mapfile -t temp_options_array < <(echo -e "${chain_options_cache_serialized[$table]}")
        
        local i=1
        for option in "${temp_options_array[@]}"; do
            chain_options[$i]="$option"
            ((i++))
        done
        
        echo
        return $((${#chain_options[@]}))
    fi

    # CACHE MISS: Se não está no cache, faz a pesquisa e guarda os resultados
    # Inicia o spinner em background
    show_spinner "A pesquisar chains, por favor aguarde" &
    local spinner_pid=$!
    # Garante que o spinner será morto se o script for interrompido
    trap "kill $spinner_pid 2>/dev/null; exit" SIGINT SIGTERM

    local chain_data
    chain_data=$(iptables -t "$table" -L --line-numbers 2>/dev/null | awk '
        /^Chain / {
            if (chain_name != "") { print chain_name, rule_count; }
            chain_name = $2;
            rule_count = 0;
            next;
        }
        /^[0-9]/ { rule_count++; }
        END { if (chain_name != "") { print chain_name, rule_count; } }
    ')

    # Para o spinner
    kill $spinner_pid 2>/dev/null
    # Limpa a armadilha de interrupção
    trap - SIGINT SIGTERM
    # Limpa a linha do spinner
    printf "\r\033[K"

    echo -e "${YELLOW}Chains disponíveis na tabela '${GREEN}$table${YELLOW}':${NC}"
    echo
    
    local counter=1
    declare -g -A chain_options
    local menu_output=""
    local options_array=()

    while read -r chain rule_count; do
        local menu_line="  ${counter}) ${CYAN}$chain${NC} (${rule_count} regras)"
        menu_output+="${menu_line}\n"
        
        chain_options[$counter]="$chain"
        options_array+=("$chain")
        ((counter++))
    done <<< "$chain_data"

    chain_menu_cache[$table]=$menu_output
    printf -v chain_options_cache_serialized[$table] '%s\n' "${options_array[@]}"

    echo -e "$menu_output"
    echo
    return $((counter-1))
}

# Função para exibir regras de um chain específico
show_rules() {
    local table="$1"
    local chain="$2"
    local sort_option="$3"
    
    echo -e "${GREEN}Regras da tabela '${BLUE}$table${GREEN}' chain '${CYAN}$chain${GREEN}':${NC}"
    echo -e "${YELLOW}Ordenação: $sort_option${NC}"
    echo
    
    local rules_output
    rules_output=$(iptables -t "$table" -L "$chain" -n -v --line-numbers 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Erro ao acessar a tabela '$table' chain '$chain'.${NC}"
        return
    fi
    
    local rules_data
    rules_data=$(echo "$rules_output" | tail -n +3 | grep -v "^$")
    
    if [ -z "$rules_data" ]; then
        echo -e "${YELLOW}Nenhuma regra encontrada neste chain.${NC}"
        return
    fi
    
    local awk_formatter
    awk_formatter='
    BEGIN { OFS = "" }
    {
      options = "";
      for (i = 11; i <= NF; i++) {
        options = options $i " ";
      }
      printf "%-4s %7s %8s %-16s %-5s %-4s %-18s %-18s %-18s %-18s %s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, options;
    }
    '
    
    echo -e "${CYAN}"
    printf "%-4s %7s %8s %-16s %-5s %-4s %-18s %-18s %-18s %-18s %s\n" "Num" "Pkts" "Bytes" "Target" "Prot" "Opt" "In" "Out" "Source" "Destination" "Options"
    printf "%-4s %7s %8s %-16s %-5s %-4s %-18s %-18s %-18s %-18s %s\n" "---" "------" "-------" "----------------" "-----" "----" "------------------" "------------------" "------------------" "------------------" "-------"
    echo -e "${NC}"

    local processed_data
    case $sort_option in
        "ordem")
            processed_data="$rules_data"
            ;;
        "alfabetica")
            processed_data=$(echo "$rules_data" | sort -k4)
            ;;
        "pacotes")
            processed_data=$(echo "$rules_data" | sort -k2 -nr)
            ;;
    esac
    
    if [ -n "$processed_data" ]; then
        echo "$processed_data" | awk "$awk_formatter"
    fi
}

# Função para listar todas as regras (OTIMIZADA COM SPINNER)
show_all_rules() {
    show_title
    
    show_spinner "A gerar listagem completa, por favor aguarde" &
    local spinner_pid=$!
    trap "kill $spinner_pid 2>/dev/null; exit" SIGINT SIGTERM

    local temp_file
    temp_file=$(mktemp)

    # Gera todo o conteúdo em um arquivo temporário para não interferir com o spinner
    {
        echo -e "${GREEN}Listagem completa de todas as regras, agrupadas por Tabela/Chain:${NC}\n"
        local tables=("filter" "nat" "mangle" "raw" "security")
        
        for table in "${tables[@]}"; do
            if ! iptables -t "$table" -L -n >/dev/null 2>&1; then
                continue
            fi

            echo -e "${CYAN}================================================================================${NC}"
            echo -e "${CYAN}# Tabela: $table${NC}"
            echo -e "${CYAN}================================================================================${NC}\n"

            local table_output
            table_output=$(iptables -t "$table" -L -n -v --line-numbers 2>/dev/null)

            echo "$table_output" | awk -v CYAN="$CYAN" -v GREEN="$GREEN" -v BLUE="$BLUE" -v NC="$NC" '
                BEGIN {
                    header = sprintf("%-4s %7s %8s %-16s %-5s %-4s %-18s %-18s %-18s %-18s %s\n", "Num", "Pkts", "Bytes", "Target", "Prot", "Opt", "In", "Out", "Source", "Destination", "Options");
                    separator = sprintf("%-4s %7s %8s %-16s %-5s %-4s %-18s %-18s %-18s %-18s %s\n", "---", "------", "-------", "----------------", "-----", "----", "------------------", "------------------", "------------------", "------------------", "-------");
                }
                /^Chain / {
                    print "\n" GREEN "## Chain: " BLUE $2 NC;
                    print CYAN header separator NC;
                    next;
                }
                /pkts.*bytes.*target/ { next; }
                /^$/ { next; }
                {
                    options = "";
                    for (i = 11; i <= NF; i++) { options = options $i " "; }
                    printf "%-4s %7s %8s %-16s %-5s %-4s %-18s %-18s %-18s %-18s %s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, options;
                }
            '
        done
    } > "$temp_file"

    kill $spinner_pid 2>/dev/null
    trap - SIGINT SIGTERM
    printf "\r\033[K"

    # Exibe o resultado e limpa o arquivo temporário
    cat "$temp_file"
    rm "$temp_file"
}

# Função para escolher tabela
choose_table() {
    while true; do
        show_title
        list_tables
        local max_tables=$?
        
        if [ $max_tables -eq 0 ]; then
            echo -e "${RED}Nenhuma tabela do iptables encontrada ou erro ao listar.${NC}"
            exit 1
        fi
        
        read -p "Digite o número da tabela, 'c' para completo, ou 'q' para sair: " table_choice
        
        if [[ "$table_choice" == "q" || "$table_choice" == "Q" ]]; then
            echo -e "${GREEN}Saindo...${NC}"
            exit 0
        fi
        
        if [[ "$table_choice" == "c" || "$table_choice" == "C" ]]; then
            return 2
        fi
        
        if [[ "$table_choice" =~ ^[0-9]+$ ]] && [ "$table_choice" -ge 1 ] && [ "$table_choice" -le $max_tables ]; then
            selected_table="${table_options[$table_choice]}"
            return 0
        else
            echo -e "${RED}Opção inválida. Pressione Enter para tentar novamente.${NC}"
            read -r
        fi
    done
}

# Função para escolher chain
choose_chain() {
    local table="$1"
    
    while true; do
        show_title
        list_chains "$table"
        local max_chains=$?
        
        if [ $max_chains -eq 0 ]; then
            echo -e "${RED}Nenhum chain encontrado na tabela '$table'. Pressione Enter para voltar.${NC}"
            read -r
            return 1
        fi
        
        read -p "Digite o número do chain desejado (ou 'b' para voltar): " chain_choice
        
        if [[ "$chain_choice" == "b" || "$chain_choice" == "B" ]]; then
            return 1
        fi
        
        if [[ "$chain_choice" =~ ^[0-9]+$ ]] && [ "$chain_choice" -ge 1 ] && [ "$chain_choice" -le $max_chains ]; then
            selected_chain="${chain_options[$chain_choice]}"
            return 0
        else
            echo -e "${RED}Opção inválida. Pressione Enter para tentar novamente.${NC}"
            read -r
        fi
    done
}

# Função para escolher ordenação
choose_sort_option() {
    echo -e "${YELLOW}Como deseja ordenar as regras?${NC}" >&2
    echo "1) Ordem original das regras" >&2
    echo "2) Alfabeticamente (por target)" >&2
    echo "3) Por número de pacotes processados" >&2
    echo >&2
    
    while true; do
        read -p "Escolha uma opção (1-3): " sort_choice
        
        case $sort_choice in
            1) echo "ordem"; return 0 ;;
            2) echo "alfabetica"; return 0 ;;
            3) echo "pacotes"; return 0 ;;
            *) echo -e "${RED}Opção inválida. Escolha 1, 2 ou 3.${NC}" >&2 ;;
        esac
    done
}

# Função principal
main() {
    # Garante que qualquer processo de spinner seja morto ao sair
    trap "pkill -P $$ 2>/dev/null" EXIT
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Este script precisa ser executado como root (sudo).${NC}"
        exit 1
    fi
    
    while true; do
        choose_table
        local table_choice_status=$?

        if [ $table_choice_status -eq 0 ]; then
            while true; do
                if ! choose_chain "$selected_table"; then
                    break
                fi
                
                sort_option=$(choose_sort_option)
                
                show_title
                echo -e "${GREEN}Tabela: $selected_table / Chain: $selected_chain${NC}\n"
                
                show_rules "$selected_table" "$selected_chain" "$sort_option"
                
                echo
                read -p "Pressione Enter para ver outro chain, ou 'b' para voltar às tabelas: " continue_choice
                
                if [[ "$continue_choice" == "b" || "$continue_choice" == "B" ]]; then
                    break
                fi
            done
        elif [ $table_choice_status -eq 2 ]; then
            show_all_rules
            echo
            read -p "Pressione Enter para voltar ao menu principal..."
        fi
    done
}

# Executa o script
main
