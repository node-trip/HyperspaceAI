#!/bin/bash

# Функции для цветного вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
YELLOW='\033[1;33m'

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        HyperSpace Node Manager         ║${NC}"
    echo -e "${BLUE}║        Telegram: @nodetrip             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
}

create_key_file() {
    echo -e "${GREEN}Вставка приватного ключа${NC}"
    echo -e "${BLUE}Пожалуйста, вставьте ваш приватный ключ (без пробелов и переносов строк):${NC}"
    read -r private_key
    
    if [ -z "$private_key" ]; then
        echo -e "${RED}Ошибка: Приватный ключ не может быть пустым${NC}"
        return 1
    fi
    
    # Сохраняем ключ в файл
    echo "$private_key" > hyperspace.pem
    chmod 644 hyperspace.pem
    
    echo -e "${GREEN}✅ Приватный ключ успешно сохранен в файл hyperspace.pem${NC}"
    return 0
}

install_node() {
    echo -e "${GREEN}Обновление системы...${NC}"
    sudo apt update && sudo apt upgrade -y
    cd $HOME
    rm -rf $HOME/.cache/hyperspace/models/*
    sleep 5

    echo -e "${GREEN}🚀 Установка HyperSpace CLI...${NC}"
    while true; do
        curl -s https://download.hyper.space/api/install | bash | tee /root/hyperspace_install.log

        if ! grep -q "Failed to parse version from release data." /root/hyperspace_install.log; then
            echo -e "${GREEN}✅ HyperSpace CLI установлен успешно!${NC}"
            break
        else
            echo -e "${RED}❌ Установка не удалась. Повторная попытка через 5 секунд...${NC}"
            sleep 5
        fi
    done

    echo -e "${GREEN}🚀 Установка AIOS...${NC}"
    echo 'export PATH=$PATH:$HOME/.aios' >> ~/.bashrc
    export PATH=$PATH:$HOME/.aios
    source ~/.bashrc

    screen -S hyperspace -dm
    screen -S hyperspace -p 0 -X stuff $'aios-cli start\n'
    sleep 5

    echo -e "${GREEN}Создание файла приватного ключа...${NC}"
    echo -e "${YELLOW}Откроется редактор nano. Вставьте ваш приватный ключ и сохраните файл (CTRL+X, Y, Enter)${NC}"
    sleep 2
    nano hyperspace.pem

    # Создаем резервную копию ключа
    if [ -f "$HOME/hyperspace.pem" ]; then
        echo -e "${GREEN}Создаем резервную копию ключа...${NC}"
        cp $HOME/hyperspace.pem $HOME/hyperspace.pem.backup
        chmod 644 $HOME/hyperspace.pem.backup
    fi

    aios-cli hive import-keys ./hyperspace.pem

    echo -e "${GREEN}🔑 Вход в систему...${NC}"
    aios-cli hive login
    sleep 5

    echo -e "${GREEN}Загрузка модели...${NC}"
    aios-cli models add hf:second-state/Qwen1.5-1.8B-Chat-GGUF:Qwen1.5-1.8B-Chat-Q4_K_M.gguf

    echo -e "${GREEN}Подключение к системе...${NC}"
    aios-cli hive connect
    aios-cli hive select-tier 3

    echo -e "${GREEN}🔍 Проверка статуса ноды...${NC}"
    aios-cli status

    echo -e "${GREEN}✅ Установка завершена!${NC}"
}

check_logs() {
    echo -e "${GREEN}Проверка логов ноды:${NC}"
    screen -r hyperspace
}

check_points() {
    echo -e "${GREEN}Проверка баланса пойнтов:${NC}"
    export PATH=$PATH:$HOME/.aios
    
    if ! pgrep -f "aios-cli" > /dev/null; then
        echo -e "${YELLOW}Демон не запущен. Запускаем...${NC}"
        aios-cli start &
        sleep 5
    fi
    
    aios-cli hive points
}

check_status() {
    echo -e "${GREEN}Проверка статуса ноды:${NC}"
    export PATH=$PATH:$HOME/.aios
    
    if ! pgrep -f "aios-cli" > /dev/null; then
        echo -e "${YELLOW}Демон не запущен. Запускаем...${NC}"
        aios-cli start &
        sleep 5
    fi
    
    aios-cli status
}

remove_node() {
    echo -e "${RED}Удаление ноды...${NC}"
    screen -X -S hyperspace quit
    rm -rf $HOME/.aios
    rm -rf $HOME/.cache/hyperspace
    rm -f hyperspace.pem
    echo -e "${GREEN}Нода успешно удалена${NC}"
}

restart_node() {
    echo -e "${YELLOW}Перезапуск ноды...${NC}"
    
    # Останавливаем процессы и удаляем файлы демона
    echo -e "${BLUE}Останавливаем процессы и очищаем временные файлы...${NC}"
    lsof -i :50051 | grep LISTEN | awk '{print $2}' | xargs -r kill -9
    rm -rf /tmp/aios*
    rm -rf $HOME/.aios/daemon*
    screen -X -S hyperspace quit
    sleep 5
    
    # Проверка и восстановление файла ключа
    if [ ! -f "$HOME/hyperspace.pem" ] && [ -f "$HOME/hyperspace.pem.backup" ]; then
        echo -e "${YELLOW}Основной файл ключа не найден. Восстанавливаем из резервной копии...${NC}"
        cp $HOME/hyperspace.pem.backup $HOME/hyperspace.pem
        chmod 644 $HOME/hyperspace.pem
    fi
    
    # Создаём screen сессию для запуска ноды
    echo -e "${BLUE}Создаём новую сессию screen...${NC}"
    screen -S hyperspace -dm
    screen -S hyperspace -p 0 -X stuff $'export PATH=$PATH:$HOME/.aios\naios-cli start\n'
    sleep 5
    
    # Аутентификация и подключение к Hive
    echo -e "${BLUE}Аутентификация в Hive...${NC}"
    # Проверяем, существует ли файл ключа
    export PATH=$PATH:$HOME/.aios
    if [ -f "$HOME/hyperspace.pem" ]; then
        echo -e "${GREEN}Импортируем ключ...${NC}"
        aios-cli hive import-keys ./hyperspace.pem
    else
        echo -e "${RED}Файл ключа не найден.${NC}"
        echo -e "${YELLOW}Требуется ввести приватный ключ.${NC}"
        echo -e "${YELLOW}Введите ваш приватный ключ (без пробелов и переносов строк):${NC}"
        read -r private_key
        echo "$private_key" > hyperspace.pem
        chmod 644 hyperspace.pem
        cp $HOME/hyperspace.pem $HOME/hyperspace.pem.backup
        chmod 644 $HOME/hyperspace.pem.backup
        aios-cli hive import-keys ./hyperspace.pem
    fi
    
    echo -e "${BLUE}Вход в систему Hive...${NC}"
    aios-cli hive login
    sleep 5
    
    echo -e "${BLUE}Подключаемся к Hive...${NC}"
    aios-cli hive connect
    sleep 5
    
    # Выбираем тир
    echo -e "${BLUE}Выбираем тир...${NC}"
    aios-cli hive select-tier 3
    sleep 3
    
    # Проверяем статус
    echo -e "${GREEN}Проверка статуса ноды после перезапуска:${NC}"
    aios-cli status
    
    echo -e "${GREEN}✅ Нода перезапущена!${NC}"
}

setup_restart_cron() {
    echo -e "${YELLOW}Настройка автоматического перезапуска ноды${NC}"
    
    # Проверяем наличие cron
    if ! command -v crontab &> /dev/null; then
        echo -e "${RED}crontab не установлен. Устанавливаем...${NC}"
        apt-get update && apt-get install -y cron
    fi
    
    # Проверяем, запущен ли cron
    if ! systemctl is-active --quiet cron; then
        echo -e "${YELLOW}Cron не запущен. Запускаем...${NC}"
        systemctl start cron
        systemctl enable cron
    fi
    
    echo -e "${GREEN}Выберите интервал перезапуска:${NC}"
    echo "1) Каждые 12 часов"
    echo "2) Каждые 24 часа (раз в сутки)"
    echo "3) Другой интервал (ввести вручную)"
    echo "4) Отключить автоматический перезапуск"
    echo "5) Вернуться в главное меню"
    
    read -p "Ваш выбор: " cron_choice
    
    # Создаем команду перезапуска
    RESTART_CMD="lsof -i :50051 | grep LISTEN | awk '{print \$2}' | xargs -r kill -9 && rm -rf /tmp/aios* && rm -rf \$HOME/.aios/daemon* && screen -X -S hyperspace quit && sleep 5 && (if [ ! -f \"\$HOME/hyperspace.pem\" ] && [ -f \"\$HOME/hyperspace.pem.backup\" ]; then cp \$HOME/hyperspace.pem.backup \$HOME/hyperspace.pem; fi) && screen -S hyperspace -dm && screen -S hyperspace -p 0 -X stuff 'export PATH=\$PATH:\$HOME/.aios\naios-cli start\n' && sleep 5 && export PATH=\$PATH:\$HOME/.aios && aios-cli hive import-keys ./hyperspace.pem && aios-cli hive login && sleep 5 && aios-cli hive connect && sleep 5 && aios-cli status"
    SCRIPT_PATH="$HOME/hyperspace_restart.sh"
    
    # Создаем скрипт перезапуска
    echo "#!/bin/bash" > $SCRIPT_PATH
    echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.aios" >> $SCRIPT_PATH
    echo "cd $HOME" >> $SCRIPT_PATH
    echo "$RESTART_CMD" >> $SCRIPT_PATH
    chmod +x $SCRIPT_PATH
    
    case $cron_choice in
        1)
            # Каждые 12 часов (в 00:00 и 12:00)
            CRON_EXPRESSION="0 0,12 * * *"
            ;;
        2)
            # Каждые 24 часа (в 00:00)
            CRON_EXPRESSION="0 0 * * *"
            ;;
        3)
            # Ввод пользовательского cron-выражения
            echo -e "${YELLOW}Введите cron-выражение (например, '0 */6 * * *' для перезапуска каждые 6 часов):${NC}"
            read -r CRON_EXPRESSION
            ;;
        4)
            # Удаляем существующие задания cron для перезапуска
            crontab -l | grep -v "hyperspace_restart.sh" | crontab -
            echo -e "${GREEN}Автоматический перезапуск отключен.${NC}"
            return
            ;;
        5)
            # Возврат в главное меню без изменений
            echo -e "${YELLOW}Возврат в главное меню без изменений настроек перезапуска...${NC}"
            return
            ;;
        *)
            echo -e "${RED}Неверный выбор. Используем значение по умолчанию (12 часов).${NC}"
            CRON_EXPRESSION="0 0,12 * * *"
            ;;
    esac
    
    # Обновляем crontab
    (crontab -l 2>/dev/null | grep -v "hyperspace_restart.sh" ; echo "$CRON_EXPRESSION $SCRIPT_PATH > $HOME/hyperspace_restart.log 2>&1") | crontab -
    
    echo -e "${GREEN}✅ Автоматический перезапуск настроен!${NC}"
    echo -e "${YELLOW}Расписание: $CRON_EXPRESSION${NC}"
    echo -e "${YELLOW}Скрипт перезапуска: $SCRIPT_PATH${NC}"
    echo -e "${YELLOW}Лог перезапуска: $HOME/hyperspace_restart.log${NC}"
}

while true; do
    print_header
    echo -e "${GREEN}Выберите действие:${NC}"
    echo "1) Установить ноду"
    echo "2) Проверить логи"
    echo "3) Проверить пойнты"
    echo "4) Проверить статус"
    echo "5) Удалить ноду"
    echo "6) Перезапустить ноду"
    echo "7) Настроить автоперезапуск"
    echo "0) Выход"
    
    read -p "Ваш выбор: " choice

    case $choice in
        1) install_node ;;
        2) check_logs ;;
        3) check_points ;;
        4) check_status ;;
        5) remove_node ;;
        6) restart_node ;;
        7) setup_restart_cron ;;
        0) exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}" ;;
    esac

    read -p "Нажмите Enter для продолжения..."
done
