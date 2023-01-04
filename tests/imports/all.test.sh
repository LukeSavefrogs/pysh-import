#shellcheck shell=bash
Include "src/bash_import.sh"

Describe "Module names"
	Describe "Imports"
		export PYIMPORT_DEBUG="true";

		It "should import functions"
			When run from "tests/module.mock.sh" import "*"
			The status should be success
			The output should be defined

			The function "test_function1" should be defined
			The function "test_function2" should be defined
			The function "test_function3" should be defined
			
			# The internal variable inside the function should NOT be exported
			The function "test_variable_inside_function" should be defined
			The variable "foo" should not be defined
		End

		It "should import variables"
			When run from "tests/module.mock.sh" import "*"
			The status should be success

			The variable "test_variable1" should be defined
			The variable "test_variable2" should be defined
			The variable "test_variable3" should be defined
			The variable "test_variable4" should be defined
			The variable "test_variable5" should be defined
		End
	End
End