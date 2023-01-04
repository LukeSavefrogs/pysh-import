#!/bin/env bash

# Description:
#   Python-like import, which allows to include only specific functions/variables from an external script
#
# Documented on:
#   - https://docs.python.org/3/tutorial/modules.html#more-on-modules
#   - https://blog.cloudboost.io/python-import-from-as-cheatsheet-tutorial-example-beginner-help-module-function-def-5f03b02a1dbe
#
# Usage:
#   - [V] Global:
#       from module.sh import "*"
#
#   - [-] Selective:
#       from module.sh import function_name, variable_name
#
#   - [-] Namespaced (functions/variables will be available as 'MyNamespace.{name}'):
#       from module.sh import function_name as fun_alias, variable_name as var_alias
#       from module.sh import function_name, variable_name as var_alias
#       import module.sh
#       import module.sh as MyNamespace
#
function from () {
    function _realpath { echo "$(cd "$(dirname "$1" || exit 1)" || exit 1; pwd)/$(basename "$1" || exit 1)" || exit 1; }

    local module_name;
    local module_path;
    local action="${2,,}";

	module_name="$1";
	if ! module_path="$(_realpath "${module_name}")"; then
		printf "ERROR - Cannot determine module path for '%s'\n" "${module_name}";
		return 1;
	fi

    # Remove "{module_name}" and "import" from parameters
    shift 2;

    if [[ ! -f "${module_path}" ]]; then 
        printf "Argument is not a file\n" >&2;
        return 1;
    elif [[ "${action}" != "import" ]]; then
        printf "Command '%s' not supported\n" "${action}" >&2;
        return 1;
    fi;


    [[ "${PYIMPORT_DEBUG}" ]] && echo "INPUT: '$*'";

	# -------------------------------------------------------------
	#                        GENERAL IMPORT
	# -------------------------------------------------------------
    # TODO: Add declare -g to every variable defined in global scope 
    #       to make them available in the caller script (like in individual import)
    if [[ "$*" == *"*"* ]]; then
        [[ "${*//[[:blank:]]/}" != "*" ]] && {
            printf "Error - When using a global import (*) it MUST be the only imported thing from that module\n" >&2;
            return 1; 
        }

		# shellcheck disable=SC1090
		local __shell_status="";
        __shell_status="$(
            # ---------------------- Declare temporary files ----------------------
			# shellcheck disable=SC2155
            declare ____temp_declare_var_file____="$(mktemp --quiet --tmpdir=/tmp tmp.XXXXXXXXXXXXXXXXXXXXXX)";
			# shellcheck disable=SC2155
            declare ____temp_declare_fun_file____="$(mktemp --quiet --tmpdir=/tmp tmp.XXXXXXXXXXXXXXXXXXXXXX)";
        
            # Make sure to erase the temporary files whatever happens
            trap 'command rm -f "${____temp_declare_var_file____}" "${____temp_declare_fun_file____}"' EXIT;
            
            # First save shell state before source'ing
            # Unset the special '_' variable (https://askubuntu.com/questions/1198935)
            ( unset _; declare -p > "${____temp_declare_var_file____}"; )
            ( unset _; declare -f > "${____temp_declare_fun_file____}"; )
            
            # Then source the file 
            source "${module_path}";

            # Print new variables
            unset _; 
            declare -p | diff \
                        --new-line-format="%L" \
                        --old-line-format="" \
                        --unchanged-line-format="" \
                        "${____temp_declare_var_file____}" -;
            
            # Print new functions
            unset _; 
            declare -f | diff \
                        --new-line-format="%L" \
                        --old-line-format="" \
                        --unchanged-line-format="" \
                        "${____temp_declare_fun_file____}" -;
        )";

		[[ "${PYIMPORT_DEBUG}" ]] && echo "${__shell_status}"

		#shellcheck disable=SC1090
		source <(echo "${__shell_status}");

		unset __shell_status;

    	if [[ "${PYIMPORT_DEBUG}" ]]; then
			printf "Sourced variables:\n";
			declare -p | grep -P "test_[-a-zA-Z0-9_]+=" | sed 's/^/\t/';

			printf "\n";

			printf "Sourced functions:\n";
			declare -f | grep -P "test_[-a-zA-Z0-9_]+\s*[\(\{]" | sed 's/^/\t/';
		fi
        return 0;
    fi

	# -------------------------------------------------------------
	#                        SPECIFIC IMPORT
	# -------------------------------------------------------------


    IFS="," read -ra params < <(echo "$@" | sed 's/,\s*/,/g');

    local -A imported_members=();
    local -A imported_aliases=();
    local -i index=0;

    for param in "${params[@]}"; do 
        if ! grep -Eq '^ *(([a-z0-9_-]+)|([a-z0-9_-]+ +as +[a-z0-9_-]+)) *$' <<<"${param,,}"; then
            printf "ERROR - Wrong syntax near '%s'\n" "${param,,}" >&2;
            return 1
        fi;

        imported_members[${index}]="$(echo "${param}" | awk -F ' as ' '{print $1}')";
        imported_aliases[${index}]="$(echo "${param}" | awk -F ' as ' '{print $2}')";
        ((++index))
    done


    if [[ "${PYIMPORT_DEBUG}" ]]; then
		{
			echo "Indice => Membro => Alias"
			for index in "${!imported_members[@]}"; do 
				echo "${index} => ${imported_members[$index]} => ${imported_aliases[$index]}"
			done; 
		} | column -t -s '=>'
    fi
	
	return



    # Actual code
    # source <(
    (
        source "$module_path";
        
        for index in "${!imported_members[@]}"; do 
            # Add prefix
            # declare -p "${param}" 2>/dev/null | sed -re "s/declare (-[[:alnum:]-])/declare -g \1/; s/([[:alnum:]_.-]+)=/${namespace}\1=/"; 
            # Change name
            __variable_definition=$(declare -p "${imported_members[$index]}" 2>/dev/null);
            __variable_rc=$?;
            
            echo "${__variable_definition}" | sed -re "s/declare (-[[:alnum:]-])/declare -g \1/; s/${imported_members[$index]}=/${imported_aliases[$index]}=/";

            # Add prefix
            # declare -f "${param}" 2>/dev/null | sed "1s/^/${namespaces[$param]}/"; 
            # Change name
            __function_definition=$(declare -f "${param}" 2>/dev/null);
            __function_rc=$?;
            
            echo "${__function_definition}" | sed "1s/${imported_members[$index]}/${imported_aliases[$index]}/"; 
            
            
            (( __function_rc > 0 && __variable_rc > 0 )) && {
                printf "No variable/function named '%s' was found.\n" "${param}" >&2;
                return 2;
            } 
        done
    );
}


function ___from () {
    function _realpath { echo "$(cd "$(dirname "$1")"; pwd)/"$(basename "$1")""; }

    local module_name;
    local module_path;
    local action;
    local namespace;
    local needed_modules;
    local needed_aliases;
    local -a params;

    # https://stackoverflow.com/a/14203146/8965861
    local -a POSITIONAL=()
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
            as)
                [[ -z "${2//[[:blank:]]/}" ]] && { printf "You did not specify a namespace after the 'as' keyword.\n" >&2; return 1; }
                namespace="${2}.";
                echo "Params: $* ($#)";
                printf "Parsed: "; 
                needed_aliases=$(echo "$@" | grep -Po '(?<=as )([a-zA-Z0-9_]*(, ?)?)*');
                IFS="," read -ra _aliases <<< "${needed_aliases//[[:blank:]]/}"
                
                # past argument
                shift;
                # past value(s?)
                shift "$(echo "$needed_aliases" | awk '{print NF}')"; echo "$@"
                break;
            ;;
            *)    # unknown option
                POSITIONAL+=("$1") # save it in an array for later
                shift # past argument
            ;;
        esac
    done
    set -- "${POSITIONAL[@]}" # restore positional parameters

    
    module_name="$1";
    module_path=$(_realpath "$module_name");
    action="${2,,}";
    shift 2;

    [[ ! -f "$module_path" ]] && { printf "Argument is not a file\n" >&2; return 1; };
    [[ "$action" != "import" ]] && { printf "Command '%s' not supported\n" "$action" >&2; return 1; };

    needed_modules="$@";
    IFS="," read -ra params <<< "${needed_modules//[[:blank:]]/}";

    # TODO: Add declare -g to every variable defined in global scope 
    #       to make them available in the caller script (like in individual import)
    if [[ "${params[*]}" == "*" ]]; then
        (
            # Declare temporary files
            declare ____temp_declare_var_file____="$(mktemp --quiet --tmpdir=/tmp tmp.XXXXXXXXXXXXXXXXXXXXXX)";
            declare ____temp_declare_fun_file____="$(mktemp --quiet --tmpdir=/tmp tmp.XXXXXXXXXXXXXXXXXXXXXX)";
        
            # Make sure to erase the temporary files whatever happens
            trap 'command rm -f "${____temp_declare_var_file____}" "${____temp_declare_fun_file____}"' EXIT;
            
            # First save shell state before source'ing
            # Unset the special '_' variable (https://askubuntu.com/questions/1198935)
            ( unset _; declare -p > "${____temp_declare_var_file____}"; )
            ( unset _; declare -f > "${____temp_declare_fun_file____}"; )
            
            # Then source the file 
            source "$module_path";

            # Print new variables
            unset _; 
            declare -p | diff \
                        --new-line-format="%L" \
                        --old-line-format="" \
                        --unchanged-line-format="" \
                        "${____temp_declare_var_file____}" -;
            
            # Print new functions
            unset _; 
            declare -f | diff \
                        --new-line-format="%L" \
                        --old-line-format="" \
                        --unchanged-line-format="" \
                        "${____temp_declare_fun_file____}" -;
        )
        return 0;
    fi;

    source <(
        source "$module_path";
        
        for param in "${params[@]}"; do
            declare -p "${param}" 2>/dev/null | sed -re "s/declare (-[[:alnum:]-])/declare -g \1/; s/([[:alnum:]_.-]+)=/${namespace}\1=/"; 
            __variable_rc=$?;
            
            declare -f "${param}" 2>/dev/null | sed "1s/^/${namespace}/"; 
            __function_rc=$?;
            
            if (( __function_rc > 0 && __variable_rc > 0 )); then
                printf "No variable/function named '%s' was found.\n" "${param}" >&2;
                return 2;
            fi
        done
    );
}

function extract_script_content () (
    trap 'command rm -f "${____temp_declare_var_file____}" "${____temp_declare_fun_file____}"' EXIT;
    local ____temp_declare_var_file____="$(mktemp --quiet --tmpdir=/tmp tmp.XXXXXXXXXXXXXXXXXXXXXX)";
    local ____temp_declare_fun_file____="$(mktemp --quiet --tmpdir=/tmp tmp.XXXXXXXXXXXXXXXXXXXXXX)";

    local __extract_variables=false;
    local __extract_functions=false;

    local -a POSITIONAL=()
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
            -f|--functions)
                __extract_functions=true;
                shift # past argument
            ;;
            -v|--variables)
                __extract_variables=true;
                shift # past argument
            ;;
            -h|--help)
                printf "The command '%s' supports the following arguments:\n" "${FUNCNAME[0]}";
                printf "\t-h, --help,          Show this help and exit\n";
                printf "\t-v, --variables,     Extract script variables\n";
                printf "\t-f, --functions,     Extract script functions\n\n";
                printf "You can combine '-v' and '-f'"
                return 0;
            ;;
            *)    # unknown option
                POSITIONAL+=("$1") # save it in an array for later
                shift # past argument
            ;;
        esac
    done
    set -- "${POSITIONAL[@]}" # restore positional parameters

    if ! ${__extract_variables} && ! ${__extract_functions}; then
        printf "You must pass at leas one argument!\n" >&2;
        printf "Type '%s --help' to know more...\n" "${FUNCNAME[0]}" >&2;
        return 1;
    fi

    ${__extract_variables} && ( unset _; declare -p > "${____temp_declare_var_file____}"; )
    ${__extract_functions} && ( unset _; declare -f > "${____temp_declare_fun_file____}"; )

    source "$1" || return 1;

    # Extract all variables from the script
    if ${__extract_variables}; then 
        unset _; 
        declare -p | diff \
                    --new-line-format="%L" \
                    --old-line-format="" \
                    --unchanged-line-format="" \
                    "${____temp_declare_var_file____}" -;
    fi

    # Extract all functions from the script
    if ${__extract_functions}; then 
        unset _; 
        declare -f | diff \
                --new-line-format="%L" \
                --old-line-format="" \
                --unchanged-line-format="" \
                "${____temp_declare_fun_file____}" -;
    fi

    return 0;
)