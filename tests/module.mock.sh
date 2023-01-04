#!/bin/env bash
# First syntax
test_function1 () { echo "Test Funzione 1"; }

# Second syntax
function test_function2 { echo "Test 2"; }

# Third syntax
function test_function3 () { echo "Test 3"; }

declare test_variable1="test_values"
declare -i test_variable2="test_value2"
declare -rA test_variable3=(
	[foo]=bar
)
declare -gx test_variable4="test_value3"
declare -x test_variable5="test_value3"

function test_variable_inside_function () {
	local foo="bar";
	echo "Inner variable is: $foo. Try typing 'echo \$foo'"
}