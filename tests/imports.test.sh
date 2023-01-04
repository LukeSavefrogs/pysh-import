#shellcheck shell=bash
Include "src/bash_import.sh"

Describe "Module names"
	xIt "No extension"
		When run from "tests/module.mock" import "test_function1"
		The status should be success
		The error should not be defined
	End

	It "With extension"
		When run from "tests/module.mock.sh" import "test_function1"
		The status should be success
		The output should be defined
	End
End