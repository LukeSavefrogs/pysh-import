#!/bin/env bash
# **********************************************************************************
#                                                                                  *
# Author/s    : Luca Salvarani                                                     *
# Created on  : 2022-03-10 01:21:28                                                *
# Description :                                                                    *
#                                                                                  *
# **********************************************************************************


# From: 
#      https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
#      https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -o errtrace      # Same as `set -E`
set -o nounset       # Same as `set -u`
# set -o errexit     # Same as `set -e`, useful ONLY for short and simple scripts


# Styling (http://web.theurbanpenguin.com/adding-color-to-your-output-from-c/)
export default="\033[0m";
export red="\033[31m";
export yellow="\033[33m";
export green="\033[32m";
export light_blue="\033[0;34m";
export magenta="\033[35m";
export underlined_red="\033[31;4m";
export bold="\033[1m";
export underlined="\033[4m";
export cyan="\033[36m";
export bold_yellow="\033[1;33m";
export bold_red="\033[1;31m";
export bold_light_blue='\033[1;94m';

export indent_1=$'\t';
export indent_2=$'\t\t';
export indent_3=$'\t\t\t';


diagnostic_info () {
	printf "Bash version:\n"
	printf "\t> ${light_blue}%s${default}\n\n" "$(LC_ALL=C bash --version | grep -m1 version)"

	printf "System Information:\n"
	printf "\t> ${light_blue}%s${default}\n\n" "$(LC_ALL=C uname -a)"

	return 0;
}

__print_command_body () {
	cont=0; 
	while read -r line; do 
		cont=$((cont+1));
		if [[ ${cont} == 1 ]]; then
			logging.info "Command body >>> ${line}"; 
			continue;
		fi
		logging.info "             >>> ${line}"; 
		cont=$((cont+1));
	done <<< "$@";
}
__print_command_rc () {
	logging.info "Return code  >>> ${__rc}";
}

# shellcheck disable=SC2120
function test_command () (
	set -o pipefail
	local __command="" __rc="" __rc_sum=0;
	if [[ -z "${1:-}" || "${1:-}" == "-" ]]; then
		__command="$(cat)";
	else
		__command="${*}";
	fi
	
	# Direct execution (SHELL)
	logging.debug "******************** Command Evaluation ********************";
	logging.debug "********************                    ********************";
	logging.debug "********************        SHELL       ********************";
	logging.debug "********************                    ********************";
	logging.debug "Test method: Directly in shell (bash -c 'commands')";
	__print_command_body "${__command}";
	eval "bash -c '$(echo "${__command}" | sed 's/'\''/'\''\\'\'''\''/g')'" | awk '{printf ("\t> %s\n", $0);}';
	__rc="$?";
	__print_command_rc "${__rc}";
	printf "\n\n";
	__rc_sum=$((__rc_sum+__rc));


	# Script execution (SCRIPT)
	logging.debug "******************** Command Evaluation ********************";
	logging.debug "********************                    ********************";
	logging.debug "********************       SCRIPT       ********************";
	logging.debug "********************                    ********************";
	logging.debug "Test method: Temporary script (bash <(commands))";
	__print_command_body "${__command}";
	eval "bash " <(echo "${__command}") | awk '{printf ("\t> %s\n", $0);}';
	__rc="$?";
	__print_command_rc "${__rc}";
	__rc_sum=$((__rc_sum+__rc));


	# Script execution (SCRIPT)
	logging.debug "******************** Command Evaluation ********************";
	logging.debug "********************                    ********************";
	logging.debug "********************       SCRIPT       ********************";
	logging.debug "********************                    ********************";
	logging.debug "Test method: Temporary script (bash <(commands))";
	__print_command_body "${__command}";
	eval "bash " <(echo "${__command}") | awk '{printf ("\t> %s\n", $0);}';
	__rc="$?";
	__print_command_rc "${__rc}";
	__rc_sum=$((__rc_sum+__rc));

	return ${__rc_sum};
)

# Logging functions
logging () {
	printf '[%(%Y-%m-%d %H:%M:%S)T] %-7s %s\n' -1 "${1}" "${2}"
}
logging.debug () {
	logging DEBUG "${@}"
}
logging.info () {
	logging INFO "${@}"
}
logging.warning () {
	logging WARNING "${@}"
}
logging.error () {
	logging ERROR "${@}"
}



diagnostic_info

test_command <<-'EOF'
	echo "{BASH_SOURCE[@]}:   ${BASH_SOURCE[@]}";
	echo "BASH_LINENO:        $BASH_LINENO";
	echo "0:                  $0";
	echo "{FUNCNAME[@]}:      ${FUNCNAME[@]}";
EOF
# test_command "[[ \$BASH_LINENO == 0 ]] && echo Is being sourced || echo Is NOT being executed"


([[ $BASH_LINENO == 0 ]])

echo $?