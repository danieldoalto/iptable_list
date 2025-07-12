#!/bin/bash

# --- Configuração ---
# Diretório onde os backups das regras do iptables serão salvos.
BACKUP_DIR="/var/log/iptables_backups"

# --- Cores ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

# --- Funções ---

# Função para verificar se os comandos necessários existem
check_dependencies() {
    local missing_deps=0
    for cmd in iptables iptables-save iptables-restore diff less mktemp stat numfmt netfilter-persistent; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${C_RED}[!] Dependência não encontrada: $cmd. Por favor, instale-a.${C_RESET}"
            missing_deps=1
        fi
    done
    if [ "$missing_deps" -eq 1 ]; then
        exit 1
    fi
}

# Função para exibir o menu principal
show_menu() {
    clear
    echo -e "${C_CYAN}=========================================${C_RESET}"
    echo -e "    ${C_BOLD}${C_YELLOW}Gerenciador de Firewall (iptables)${C_RESET}   "
    echo -e "${C_CYAN}=========================================${C_RESET}"
    echo -e "${C_GREEN}1.${C_RESET} Parar Firewall (e criar backup)"
    echo -e "${C_GREEN}2.${C_RESET} Iniciar Firewall (restaurar último backup)"
    echo -e "${C_GREEN}3.${C_RESET} Gerar Backup"
    echo -e "${C_GREEN}4.${C_RESET} Restaurar Backup Específico"
    echo -e "${C_GREEN}5.${C_RESET} Visualizar Conteúdo de Backup"
    echo -e "${C_GREEN}6.${C_RESET} Comparar Regras Atuais com Backup"
    echo -e "${C_GREEN}7.${C_RESET} Listar Backups Salvos"
    echo -e "${C_GREEN}8.${C_RESET} Gerenciamento Avançado de Backups"
    echo -e "${C_RED}9.${C_RESET} Sair"
    echo -e "${C_CYAN}-----------------------------------------${C_RESET}"
}

# Função para gerar um backup das regras atuais em um arquivo
generate_file_backup() {
    echo -e "${C_BLUE}[+] Criando backup em arquivo com data e hora...${C_RESET}"
    
    local filename="iptables_backup_$(date +%Y-%m-%d_%H-%M-%S).rules"
    local backup_path="$BACKUP_DIR/$filename"

    sudo bash -c "iptables-save > \"$backup_path\""

    if [ $? -eq 0 ]; then
        echo -e "${C_GREEN}[✓] Backup em arquivo salvo com sucesso em: $backup_path${C_RESET}"
        return 0
    else
        echo -e "${C_RED}[!] Erro: Falha ao criar o arquivo de backup. Verifique as permissões.${C_RESET}"
        return 1
    fi
}

# Função para salvar as regras de forma persistente
generate_persistent_backup() {
    read -p "$(echo -e "${C_YELLOW}[?] Isso irá sobrescrever as regras salvas para a próxima inicialização. Deseja continuar? [s/N]:${C_RESET} ")" confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        echo -e "${C_BLUE}[i] Operação cancelada.${C_RESET}"
        return 1
    fi

    echo -e "${C_BLUE}[+] Salvando regras atuais para serem persistentes...${C_RESET}"
    sudo netfilter-persistent save

    if [ $? -eq 0 ]; then
        echo -e "${C_GREEN}[✓] Regras salvas com sucesso em /etc/iptables/rules.v4 e /etc/iptables/rules.v6${C_RESET}"
        return 0
    else
        echo -e "${C_RED}[!] Erro: Falha ao salvar as regras persistentes.${C_RESET}"
        return 1
    fi
}

# Função para exibir o submenu de backup
generate_backup() {
    while true; do
        clear
        echo -e "${C_CYAN}=========================================${C_RESET}"
        echo -e "    ${C_BOLD}${C_YELLOW}Opções de Geração de Backup${C_RESET}    "
        echo -e "${C_CYAN}=========================================${C_RESET}"
        echo -e "${C_GREEN}1.${C_RESET} Backup Persistente (netfilter-persistent)"
        echo -e "${C_GREEN}2.${C_RESET} Backup em Arquivo (método manual)"
        echo -e "${C_RED}3.${C_RESET} Voltar ao menu principal"
        echo -e "${C_CYAN}-----------------------------------------${C_RESET}"
        read -p "$(echo -e "${C_YELLOW}Escolha uma opção [1-3]:${C_RESET} ")" backup_choice

        case $backup_choice in
            1)
                generate_persistent_backup
                break
                ;;
            2)
                generate_file_backup
                break
                ;;
            3)
                break
                ;;
            *)
                echo -e "${C_RED}[!] Opção inválida. Por favor, tente novamente.${C_RESET}"
                read -p "$(echo -e "${C_YELLOW}Pressione [Enter] para continuar...${C_RESET}")"
                ;;
        esac
    done
}

# Função para parar o firewall e criar um backup com data e hora
stop_firewall() {
    read -p "$(echo -e "${C_YELLOW}[?] Tem certeza de que deseja parar o firewall e liberar todo o tráfego? [s/N]:${C_RESET} ")" confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        echo -e "${C_BLUE}[i] Operação cancelada.${C_RESET}"
        return
    fi

    # Primeiro, gera o backup em arquivo
    generate_file_backup

    # Se o backup foi bem-sucedido, continua para parar o firewall
    if [ $? -eq 0 ]; then
        echo -e "${C_BLUE}[+] Liberando todo o tráfego de rede...${C_RESET}"
        sudo iptables -P INPUT ACCEPT
        sudo iptables -P FORWARD ACCEPT
        sudo iptables -P OUTPUT ACCEPT
        sudo iptables -F
        sudo iptables -X
        echo -e "${C_GREEN}[✓] Firewall desativado temporariamente.${C_RESET}"
    else
        echo -e "${C_RED}[!] O firewall não foi parado porque o backup falhou.${C_RESET}"
    fi
}

# Função para iniciar o firewall restaurando o último backup
start_firewall() {
    read -p "$(echo -e "${C_YELLOW}[?] Tem certeza de que deseja restaurar o último backup? As regras atuais serão sobrescritas. [s/N]:${C_RESET} ")" confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        echo -e "${C_BLUE}[i] Operação cancelada.${C_RESET}"
        return
    fi

    echo -e "${C_BLUE}[+] Procurando pelo último backup...${C_RESET}"
    
    # Encontra o arquivo de backup mais recente no diretório
    # 'ls -t' lista os arquivos por data de modificação, do mais novo para o mais antigo
    # 'head -n 1' pega o primeiro da lista (o mais recente)
    local latest_backup=$(ls -t "$BACKUP_DIR"/*.rules 2>/dev/null | head -n 1)

    if [ -z "$latest_backup" ]; then
        echo -e "${C_RED}[!] Nenhum arquivo de backup encontrado em $BACKUP_DIR.${C_RESET}"
        return
    fi

    echo -e "${C_BLUE}[+] Restaurando o backup mais recente: $(basename "$latest_backup")${C_RESET}"
    sudo iptables-restore < "$latest_backup"

    if [ $? -eq 0 ]; then
        echo -e "${C_GREEN}[✓] Firewall reativado com as regras do último backup.${C_RESET}"
    else
        echo -e "${C_RED}[!] Erro: Falha ao restaurar as regras do firewall.${C_RESET}"
    fi
}

# Função para listar todos os backups existentes
list_backups() {
    echo -e "${C_BLUE}[+] Listando backups salvos em $BACKUP_DIR:${C_RESET}"
    echo -e "${C_CYAN}-----------------------------------------${C_RESET}"
    
    local backups=($BACKUP_DIR/*.rules)

    # Verifica se existem backups
    if [ ! -e "${backups[0]}" ]; then
        echo -e "${C_YELLOW}Nenhum backup encontrado.${C_RESET}"
    else
        # Itera sobre os arquivos e usa 'stat' para obter informações detalhadas
        for backup_file in "${backups[@]}"; do
            if [ -f "$backup_file" ]; then
                # Obtém informações do arquivo com stat
                local details=$(stat -c "%A %U %G %s %y" "$backup_file")
                local perms=$(echo $details | cut -d' ' -f1)
                local user=$(echo $details | cut -d' ' -f2)
                local group=$(echo $details | cut -d' ' -f3)
                local size=$(numfmt --to=iec --suffix=B --padding=5 "$(echo $details | cut -d' ' -f4)")
                local mod_date=$(echo $details | cut -d' ' -f5)
                local mod_time=$(echo $details | cut -d' ' -f6 | cut -d'.' -f1)

                # Imprime de forma formatada, similar ao ls -l
                printf "%s %s %s %s %s %s ${C_GREEN}%s${C_RESET}\n" "$perms" "$user" "$group" "$size" "$mod_date" "$mod_time" "$(basename "$backup_file")"
            fi
        done
    fi
    echo -e "${C_CYAN}-----------------------------------------${C_RESET}"
}

# Função para restaurar um backup específico escolhido pelo usuário
restore_specific_backup() {
    echo -e "${C_BLUE}[+] Listando backups disponíveis para restauração:${C_RESET}"
    
    # Cria um array com os arquivos de backup
    local backups=("$BACKUP_DIR"/*.rules)

    # Verifica se existem backups
    if [ ! -e "${backups[0]}" ]; then
        echo -e "${C_RED}[!] Nenhum arquivo de backup encontrado em $BACKUP_DIR.${C_RESET}"
        return
    fi

    # Exibe os backups numerados
    local i=1
    for backup in "${backups[@]}"; do
        echo -e "  ${C_GREEN}$i)${C_RESET} $(basename "$backup")"
        i=$((i+1))
    done
    echo -e "${C_CYAN}-----------------------------------------${C_RESET}"

    # Pede ao usuário para escolher um backup
    read -p "$(echo -e "${C_YELLOW}Digite o número do backup que deseja restaurar (ou 0 para cancelar):${C_RESET} ")" choice

    # Valida a entrada
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        echo -e "${C_RED}[!] Seleção inválida.${C_RESET}"
        return
    fi

    if [ "$choice" -eq 0 ]; then
        echo -e "${C_BLUE}[i] Operação cancelada.${C_RESET}"
        return
    fi

    # Obtém o caminho do backup escolhido
    local selected_backup="${backups[$((choice-1))]}"

    echo -e "${C_BLUE}[+] Restaurando o backup: $(basename "$selected_backup")${C_RESET}"
    sudo iptables-restore < "$selected_backup"

    if [ $? -eq 0 ]; then
        echo -e "${C_GREEN}[✓] Firewall reativado com as regras do backup selecionado.${C_RESET}"
    else
        echo -e "${C_RED}[!] Erro: Falha ao restaurar as regras do firewall.${C_RESET}"
    fi
}

# Função para visualizar o conteúdo de um arquivo de backup
view_backup_content() {
    echo -e "${C_BLUE}[+] Listando backups disponíveis para visualização:${C_RESET}"
    
    # Verifica se o diretório existe
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${C_RED}[!] Diretório de backup não existe: $BACKUP_DIR${C_RESET}"
        return
    fi

    local backups=("$BACKUP_DIR"/*.rules)

    if [ ! -e "${backups[0]}" ]; then
        echo -e "${C_RED}[!] Nenhum arquivo de backup encontrado.${C_RESET}"
        return
    fi

    local i=1
    for backup in "${backups[@]}"; do
        echo -e "  ${C_GREEN}$i)${C_RESET} $(basename "$backup")"
        i=$((i+1))
    done
    echo -e "${C_CYAN}-----------------------------------------${C_RESET}"

    read -p "$(echo -e "${C_YELLOW}Digite o número do backup que deseja visualizar (ou 0 para cancelar):${C_RESET} ")" choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        echo -e "${C_RED}[!] Seleção inválida.${C_RESET}"
        return
    fi

    if [ "$choice" -eq 0 ]; then
        echo -e "${C_BLUE}[i] Operação cancelada.${C_RESET}"
        return
    fi

    local selected_backup="${backups[$((choice-1))]}"

    echo -e "${C_BLUE}[+] Exibindo conteúdo de: $(basename "$selected_backup")${C_RESET}"
    echo -e "${C_CYAN}-----------------------------------------${C_RESET}"
    # Usar 'less' para visualização paginada com configuração para funcionamento adequado
    # -F: sai automaticamente se o conteúdo couber em uma tela
    # -R: permite cores
    # -X: não limpa a tela ao sair
    LESS="-FRX" less "$selected_backup"
    echo -e "${C_CYAN}-----------------------------------------${C_RESET}"
}

# Função para comparar as regras atuais com um backup
compare_rules_with_backup() {
    echo -e "${C_BLUE}[+] Comparando regras atuais com um backup...${C_RESET}"

    # Verifica se o diretório existe
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${C_RED}[!] Diretório de backup não existe: $BACKUP_DIR${C_RESET}"
        return
    fi

    # Salva as regras atuais em um arquivo temporário
    local current_rules_temp=$(mktemp)
    # Usando bash -c para garantir que o redirecionamento funcione com sudo
    sudo bash -c "iptables-save > \"$current_rules_temp\""

    echo -e "${C_BLUE}[+] Listando backups disponíveis para comparação:${C_RESET}"
    local backups=("$BACKUP_DIR"/*.rules)

    if [ ! -e "${backups[0]}" ]; then
        echo -e "${C_RED}[!] Nenhum arquivo de backup encontrado.${C_RESET}"
        rm "$current_rules_temp"
        return
    fi

    local i=1
    for backup in "${backups[@]}"; do
        echo -e "  ${C_GREEN}$i)${C_RESET} $(basename "$backup")"
        i=$((i+1))
    done
    echo -e "${C_CYAN}-----------------------------------------${C_RESET}"

    read -p "$(echo -e "${C_YELLOW}Digite o número do backup para comparar (ou 0 para cancelar):${C_RESET} ")" choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        echo -e "${C_RED}[!] Seleção inválida.${C_RESET}"
        rm "$current_rules_temp"
        return
    fi

    if [ "$choice" -eq 0 ]; then
        echo -e "${C_BLUE}[i] Operação cancelada.${C_RESET}"
        rm "$current_rules_temp"
        return
    fi

    local selected_backup="${backups[$((choice-1))]}"

    echo -e "${C_BLUE}[+] Diferenças entre as regras atuais e $(basename "$selected_backup"):${C_RESET}"
    echo -e "${C_YELLOW}(< representa as regras atuais, > representa as regras do backup)${C_RESET}"
    echo -e "${C_CYAN}-----------------------------------------${C_RESET}"
    # Usa 'diff' para mostrar as diferenças de forma paginada e colorida
    # Configura o less para exibição adequada
    LESS="-FRX" diff --color=always -u "$current_rules_temp" "$selected_backup" | less -R
    echo -e "${C_CYAN}-----------------------------------------${C_RESET}"

    # Remove o arquivo temporário
    rm "$current_rules_temp"
}

# Função para gerenciamento avançado de retenção de backups
manage_backup_retention() {
    while true; do
        clear
        echo -e "${C_CYAN}=========================================${C_RESET}"
        echo -e "    ${C_BOLD}${C_YELLOW}Gerenciamento Avançado de Backups${C_RESET}    "
        echo -e "${C_CYAN}=========================================${C_RESET}"
        echo -e "${C_GREEN}1.${C_RESET} Manter os últimos 'N' backups"
        echo -e "${C_GREEN}2.${C_RESET} Remover backups com mais de 'X' dias"
        echo -e "${C_RED}3.${C_RESET} Voltar ao menu principal"
        echo -e "${C_CYAN}-----------------------------------------${C_RESET}"
        read -p "$(echo -e "${C_YELLOW}Escolha uma opção [1-3]:${C_RESET} ")" retention_choice

        case $retention_choice in
            1)
                read -p "$(echo -e "${C_YELLOW}Quantos backups recentes deseja manter?${C_RESET} ")" num_to_keep
                if ! [[ "$num_to_keep" =~ ^[0-9]+$ ]] || [ "$num_to_keep" -lt 1 ]; then
                    echo -e "${C_RED}[!] Número inválido. Por favor, insira um inteiro positivo.${C_RESET}"
                else
                    echo -e "${C_BLUE}[+] Removendo todos os backups, exceto os $num_to_keep mais recentes...${C_RESET}"
                    # Verifica se existem backups antes de tentar manipular
                    if [ -n "$(ls -A "$BACKUP_DIR"/*.rules 2>/dev/null)" ]; then
                        # Lista todos os backups e remove os que excedem o número a ser mantido
                        ls -t "$BACKUP_DIR"/*.rules 2>/dev/null | tail -n +$((num_to_keep + 1)) | xargs -r sudo rm
                        echo -e "${C_GREEN}[✓] Limpeza concluída.${C_RESET}"
                    else
                        echo -e "${C_BLUE}[i] Nenhum backup encontrado para limpar.${C_RESET}"
                    fi
                fi
                read -p "$(echo -e "${C_YELLOW}Pressione [Enter] para continuar...${C_RESET}")"
                ;;
            2)
                read -p "$(echo -e "${C_YELLOW}Remover backups com mais de quantos dias?${C_RESET} ")" days_old
                if ! [[ "$days_old" =~ ^[0-9]+$ ]] || [ "$days_old" -lt 1 ]; then
                    echo -e "${C_RED}[!] Número inválido. Por favor, insira um inteiro positivo.${C_RESET}"
                else
                    echo -e "${C_BLUE}[+] Removendo backups com mais de $days_old dias...${C_RESET}"
                    # Verifica se existem arquivos no diretório antes de tentar remover
                    if [ -n "$(find "$BACKUP_DIR" -name "*.rules" -mtime +$((days_old - 1)) 2>/dev/null)" ]; then
                        # Encontra e remove arquivos .rules mais antigos que o número de dias especificado
                        find "$BACKUP_DIR" -name "*.rules" -mtime +$((days_old - 1)) -exec sudo rm {} \;
                        echo -e "${C_GREEN}[✓] Limpeza concluída.${C_RESET}"
                    else
                        echo -e "${C_BLUE}[i] Nenhum backup com mais de $days_old dias encontrado.${C_RESET}"
                    fi
                fi
                read -p "$(echo -e "${C_YELLOW}Pressione [Enter] para continuar...${C_RESET}")"
                ;;
            3)
                break
                ;;
            *)
                echo -e "${C_RED}[!] Opção inválida. Por favor, tente novamente.${C_RESET}"
                read -p "$(echo -e "${C_YELLOW}Pressione [Enter] para continuar...${C_RESET}")"
                ;;
        esac
    done
}

# --- Script Principal ---

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "${C_RED}[!] Por favor, execute este script como root ou com sudo.${C_RESET}"
  exit 1
fi

# Verifica as dependências necessárias
check_dependencies

# Cria o diretório de backup se ele não existir
sudo mkdir -p "$BACKUP_DIR"

# Garante as permissões corretas no diretório de backup
sudo chmod 700 "$BACKUP_DIR" 2>/dev/null || echo -e "${C_YELLOW}[!] Aviso: Não foi possível definir permissões no diretório de backup.${C_RESET}"

# Loop principal do menu
while true; do
    show_menu
    read -p "$(echo -e "${C_YELLOW}Escolha uma opção [1-9]:${C_RESET} ")" choice

    case $choice in
        1)
            stop_firewall
            ;;
        2)
            start_firewall
            ;;
        3)
            generate_backup
            ;;
        4)
            restore_specific_backup
            ;;
        5)
            view_backup_content
            ;;
        6)
            compare_rules_with_backup
            ;;
        7)
            list_backups
            ;;
        8)
            manage_backup_retention
            ;;
        9)
            echo -e "${C_BLUE}Saindo...${C_RESET}"
            break
            ;;
        *)
            echo -e "${C_RED}[!] Opção inválida. Por favor, tente novamente.${C_RESET}"
            ;;
    esac
    echo ""
    read -p "$(echo -e "${C_YELLOW}Pressione [Enter] para continuar...${C_RESET}")"
done
