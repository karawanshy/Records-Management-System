#!/bin/bash

declare file_name

# adds a log report to the log file for each event and it's status.
add_log(){
    local file_name_prefix=$(echo "$file_name" | awk -F'.' '{print $1}')
    local log_file="${file_name_prefix}_log.csv"
    local event="$1"
    local status="$2"
    local log="$(date +"%Y/%m/%d %H:%M:%S") $event $status"

    if [ -f "$log_file" ]; then
        touch $log_file; fi

    # adding to the log file.
    echo "$log" >> "$log_file"
}

# returns a list of all records that contain the search_query as subname.
get_records_by_name() {
    local search_query="$1"
    grep -i "$search_query" "$file_name"
}

# searchs for records in the records database based on the given name and prints it.
search_record(){
    local search_query="$1"
    local records_list

    readarray -t records_list <<< "$(get_records_by_name "$search_query")"

    if ((${#records_list[@]} > 0)); then
        echo -e "\nRecords in $file_name:\n"
        for record in "${records_list[@]}"; do 
            echo "$record" 
        done
        add_log "Search" "Success"
    else
        echo -e "\nNo records found for '$search_query'\n"
        add_log "Search" "Failure"
    fi
}

# prints the available options for the given record name.
print_records_options(){
    local search_query="$1"
    local record_list_length="$2"
    local records_list=("${@:3}")
    
    echo -e "\nPlease choose an option: "
    for((i=0;i<$record_list_length;i++)); do
        echo "$((i+1))    ${records_list[$i]}"
    done

}

# adds copies to a given record.
insert_record(){
    local search_query="$1"
    local amount="$2"
    local records_list

    # getting a list of all records containing the search query.
    readarray -t records_list <<< "$(get_records_by_name "$search_query")"
    local record_list_length=${#records_list[@]}
    
    # printing the options for the user and getting his choice.
    if(($record_list_length > 0)); then
        print_records_options "$search_query" "$record_list_length" "${records_list[@]}"; fi
    # if the user entered the exact record name then there is no need to display create a new record option - won't create duplicates
    if(($record_list_length != 1)) || [ "$search_query" != "$(echo "${records_list[0]}" | awk -F',' '{print $1}')" ]; then
        echo "$(($record_list_length+1))    Create a new record by the name '$search_query'"; fi
    read -p $'\nPlease enter your choice: ' choice
        
    # getting a valid option from the user.
    while(($choice < 1 || $choice > $record_list_length + 1)); do
        read -p $'\nInvalid option! Please enter your choice: ' choice
    done
    
    # create a new record with given record name and amount.
    if(($choice == $record_list_length + 1));then
        echo "$search_query,$amount" >> "$file_name"
        echo -e "\nAdded a new record with the name: $search_query.\n"
        add_log "Insert" "Success"

    # adding to the amount of the selected record
    else
        # splitting the records info
        record_name=$(echo "${records_list[(($choice-1))]}" | awk -F',' '{print $1}')
        curr_amount=$(echo "${records_list[(($choice-1))]}" | awk -F',' '{print int($2)}')

        # adding the given amount to the original amount in the database.
        sed -i "s/$record_name,$curr_amount/$record_name,$((curr_amount+amount))/" "$file_name"

        echo -e "\nSuccessfully added $amount records to $record_name.\n"
        add_log "Insert" "Success"
    fi
}

# deletes copies from the given record
delete_record(){
    local search_query="$1"
    local amount="$2"
    local records_list

    # getting a list of all records containing the search query.
    readarray -t records_list <<< "$(get_records_by_name "$search_query")"
    local record_list_length=${#records_list[@]}

    if((record_list_length > 0)); then
    
        # printing the options for the user and getting his choice.
        print_records_options "$search_query" "$record_list_length" "${records_list[@]}"
        read -p $'\nPlease enter your choice: ' choice
        
        # getting a valid option from the user.
        while(($choice < 1 || $choice > $record_list_length)); do
            read -p $'\nInvalid option! Please enter your choice: ' choice
        done
        
        # splitting the records info
        record_name=$(echo "${records_list[(($choice-1))]}" | awk -F',' '{print $1}')
        curr_amount=$(echo "${records_list[(($choice-1))]}" | awk -F',' '{print int($2)}')

        local diff=$((curr_amount-amount))
        if (($diff < 0)); then
            echo -e "\nThere is not enough copies for the record $record_name.\n"
            add_log "Delete" "Failure"
        elif (($diff == 0)); then
            echo "Deleteing the record from database"
            sed -i "/${records_list[(($choice-1))]}/d" "$file_name"
            echo -e "\nThere is no more copies of $record_name in database, Successfully deleted the record $record_name."
            add_log "Delete" "Success"
        else
            sed -i "s/$record_name,$curr_amount/$record_name,$((curr_amount-amount))/" "$file_name"
            echo -e "\nSuccessfully deleted $amount copies from $record_name.\n"
            add_log "Delete" "Success"
        fi
    else
        echo -e "\nFound no records with the name $search_query in the database.\n"
        add_log "Delete" "Failure"
    fi
}

# updates the name of the given record.
update_record_name(){
    local search_query="$1"
    local new_name="$2"
    local records_list

    # getting a list of all records containing the given old name.
    readarray -t records_list <<< "$(get_records_by_name "$search_query")"
    local record_list_length=${#records_list[@]}
    
    if(($record_list_length > 0)); then
        # printing the options for the user and getting his choice.
        print_records_options "$search_query" "$record_list_length" "${records_list[@]}"
        read -p $'\nPlease enter your choice: ' choice
        
        # getting a valid option from the user.
        while(($choice < 1 || $choice > $record_list_length)); do
            read -p $'\nInvalid option! Please enter your choice: ' choice
        done

        # splitting the records info
        record_name=$(echo "${records_list[(($choice-1))]}" | awk -F',' '{print $1}')

        # updating to the given name.
        sed -i "s/$record_name,/$new_name,/" "$file_name"

        echo -e "\nSuccessfully updated the name of $old_name to $new_name.\n"
        add_log "UpdateName" "Success"
    else
        echo -e "\nFound no records with the name $search_query in the database.\n"
        add_log "UpdateName" "Failure"
    fi
}

# updates the amount of the given record.
update_record_amount(){
    local search_query="$1"
    local amount="$2"
    local records_list

    # getting a list of all records containing the search query.
    readarray -t records_list <<< "$(get_records_by_name "$search_query")"
    local record_list_length=${#records_list[@]}
    
    if(($record_list_length > 0)); then
        # printing the options for the user and getting his choice.
        print_records_options "$search_query" "$record_list_length" "${records_list[@]}"
        read -p $'\nPlease enter your choice: ' choice
        
        # getting a valid option from the user.
        while(($choice < 1 || $choice > $record_list_length)); do
            read -p $'\nInvalid option! Please enter your choice: ' choice
        done

        # splitting the records info
        record_name=$(echo "${records_list[(($choice-1))]}" | awk -F',' '{print $1}')

        # updating to the given amount.
        sed -i "s/$record_name,.*/$record_name,$amount/" "$file_name"

        echo -e "\nSuccessfully updated the amount of $record_name to $amount.\n"
        add_log "UpdateAmount" "Success"
    else
        echo -e "\nFound no records with the name $search_query in the database.\n"
        add_log "UpdateAmount" "Failure"
    fi
}

# prints the records database as it is.
print_all_records(){
    if [ -s $file_name ]; then
        echo -e "\nCurrent Records in $file_name:\n"
        while IFS= read -r line; do
            record_name=$(echo "$line" | awk -F',' '{print $1}')
            record_amount=$(echo "$line" | awk -F',' '{print $2}')
            echo "$record_name $record_amount"
            add_log "PrintAll" "$record_name $record_amount"
        done < "$file_name"
    else
        echo "There is no Records in $file_name"
    fi
}

# prints the records database after sorting it.
print_sorted_records(){
    if [ -s $file_name ]; then
        echo -e "\nSorted Records in $file_name:\n"
        while IFS= read -r line; do
            record_name=$(echo "$line" | awk -F',' '{print $1}')
            record_amount=$(echo "$line" | awk -F',' '{print $2}')
            echo "$record_name $record_amount"
            add_log "PrintSorted" "$record_name $record_amount"
        done < <(sort "$file_name")
    else
        echo "There is no Records in $file_name"
    fi
}

# checks if the given amount is whole and positive.
validate_record_amount(){
    local re='^[0-9]+$'
    if [[ $1 =~ $re ]]; then
        return 0
    else 
        echo "Invalid amount - the amount should be a whole and a positive number."
        return 1
    fi
}

# checks if the given record name is in the correct format.
validate_record_name(){
    local re='^[0-9a-zA-Z[:space:]]+$'
    if [[ $1 =~ $re ]]; then
        return 0
    else 
        echo "Invalid record name - name should include only numbers, letters and spaces."
        return 1
    fi
}

# checks if the given file name is in the correct format.
validate_file_name(){
    local re='^[0-9a-zA-Z]+\.csv$'
    if [[ $1 =~ $re ]]; then
        return 0
    else 
        return 1
    fi
}

# validates the input.
validate_entry(){
    file_name=$1
	if (($# != 1)); then
        echo "Invalid Input! Please enter one argument."
        exit
    elif ! validate_file_name "$file_name"; then
        echo "Invalid Input! Please enter a valid file name."
        exit
    elif ! [ -f "$file_name" ]; then
        touch $file_name
    elif ! [ -r "$file_name" ]; then
        echo "Error! File '$file_name' is not readable."
        exit
	fi
}

main(){

    validate_entry "$@"

    operations=("Insert Record" "Delete Record" "Search Record" "Update Record Name" "Update Record Amount" "Print All Records" "Print Sorted Records" "Exit")

    select case in "${operations[@]}"
        do
            case $case in
            "Insert Record") 
                read -p "Please enter the name of the record you want to add to: " record_name
                read -p "Please enter the amount of copies you want to add: " record_amount
                if validate_record_name "$record_name" && validate_record_amount "$record_amount"; then
                    insert_record "$record_name" "$record_amount"; fi
                ;;
            "Delete Record") 
                read -p "Please enter the name of the record you want to delete from: " record_name
                read -p "Please enter the amount of copies you want to delete: " record_amount
                if validate_record_name "$record_name" && validate_record_amount "$record_amount"; then
                    delete_record "$record_name" "$record_amount"; fi
                ;; 
            "Search Record")
                read -p "Please enter the frase you want to search: " frase
                search_record "$frase"
                ;;
            "Update Record Name") 
                read -p "Please enter the name of the record you want to change: " old_record_name
                read -p "Please enter the new name of the record: " new_record_name
                if validate_record_name "$old_record_name" && validate_record_name "$new_record_name"; then
                    update_record_name "$old_record_name" "$new_record_name"; fi
                ;; 
            "Update Record Amount") 
                read -p "Please enter the name of the record you want to update: " record_name
                read -p "Please enter the amount of copies you want to update to: " record_amount
                if validate_record_name "$record_name" && validate_record_amount "$record_amount"; then
                    update_record_amount "$record_name" "$record_amount"; fi
                ;;
            "Print All Records") 
                print_all_records
                ;;
            "Print Sorted Records") 
                print_sorted_records 
                ;;
            "Exit") 
                break;;
            *) 
                echo "Please choose a valid option" ;;
            esac
        done
}

main "$@"