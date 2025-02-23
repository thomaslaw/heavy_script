#!/bin/bash

# shellcheck disable=SC2120
start_app_prompt() {
    local app_names=("$@") # Get all arguments as an array

    # If the first argument is "ALL", populate the app_names array with all apps
    if [[ ${app_names[0]} == "ALL" ]]; then
        mapfile -t app_names < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')
    fi

    # If no arguments are provided, prompt for app selection
    if [[ ${#app_names[@]} -eq 0 ]]; then
        prompt_app_selection "STOPPED" "start"
        app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
        app_names=("$app_name")
    fi

    for app_name in "${app_names[@]}"; do
        # Query chosen replica count for the application
        replica_count=$(pull_replicas "$app_name")

        if [[ $replica_count == "0" ]]; then
            echo -e "${blue}$app_name${red} cannot be started${reset}"
            echo -e "${yellow}Replica count is 0${reset}"
            echo -e "${yellow}This could be due to:${reset}"
            echo -e "${yellow}1. The application does not accept a replica count (external services, cert-manager etc)${reset}"
            echo -e "${yellow}2. The application is set to 0 replicas in its configuration${reset}"
            echo -e "${yellow}If you believe this to be a mistake, please submit a bug report on the github.${reset}"
            exit
        fi

        if [[ $replica_count == "null" ]]; then
            echo -e "${blue}$app_name${red} cannot be started${reset}"
            echo -e "${yellow}Replica count is null${reset}"
            echo -e "${yellow}Looks like you found an application HS cannot handle${reset}"
            echo -e "${yellow}Please submit a bug report on the github.${reset}"
            exit
        fi

        echo -e "Starting ${blue}$app_name${reset}..."

        # Check if all cli commands were successful
        if start_app "$app_name" "$replica_count"; then
            echo -e "${blue}$app_name ${green}Started${reset}"
            echo -e "${green}Replica count set to ${blue}$replica_count${reset}\n"
        else
            echo -e "${red}Failed to start ${blue}$app_name${reset}\n"
        fi
    done

    # If app names were provided as arguments, we're done
    if [[ ${#app_names[@]} -gt 0 ]]; then
        return
    fi

    # If not, offer the user a chance to start another app
    while true; do
        read -rt 120 -p "Would you like to start another application? (y/n): " choice || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
        case "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" in
            "yes"|"y")
                start_app_prompt
                break
                ;;
            "no"|"n"|"")
                break
                ;;
            *)
                echo "Invalid choice, please enter 'y' or 'n'"
        esac
    done
}
