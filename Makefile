.PHONY: pretty clean ChangeLog.md

all:
	@echo "ChangeLog.md - generate ChangeLog file"
	@echo "check - compile and execute test suite"
	@echo "check-fast - compile and execute test suite (skip long-running tests)"
	@echo "clean - remove built files"
	@echo "coverage - create coverage information with lcov"
	@echo "cppcheck - analyze code with cppcheck"
	@echo "doctest - compile example files and check their output"
	@echo "fuzz_testing - prepare fuzz testing of the JSON parser"
	@echo "fuzz_testing_cbor - prepare fuzz testing of the CBOR parser"
	@echo "fuzz_testing_msgpack - prepare fuzz testing of the MessagePack parser"
	@echo "json_unit - create single-file test executable"
	@echo "pedantic_clang - run Clang with maximal warning flags"
	@echo "pedantic_gcc - run GCC with maximal warning flags"
	@echo "pretty - beautify code with Artistic Style"


##########################################################################
# unit tests
##########################################################################

# build unit tests
json_unit:
	@$(MAKE) json_unit -C test

# run unit tests
check:
	$(MAKE) check -C test

check-fast:
	$(MAKE) check -C test TEST_PATTERN=""

# clean up
clean:
	rm -fr json_unit json_benchmarks fuzz fuzz-testing *.dSYM test/*.dSYM
	rm -fr benchmarks/files/numbers/*.json
	rm -fr build_coverage
	$(MAKE) clean -Cdoc
	$(MAKE) clean -Ctest
	$(MAKE) clean -Cbenchmarks


##########################################################################
# coverage
##########################################################################

coverage:
	mkdir build_coverage
	cd build_coverage ; CXX=g++-5 cmake .. -GNinja -DJSON_Coverage=ON
	cd build_coverage ; ninja
	cd build_coverage ; ctest
	cd build_coverage ; ninja lcov_html
	open build_coverage/test/html/index.html


##########################################################################
# documentation tests
##########################################################################

# compile example files and check output
doctest:
	$(MAKE) check_output -C doc


##########################################################################
# warning detector
##########################################################################

# calling Clang with all warnings, except:
# -Wno-documentation-unknown-command: code uses user-defined commands like @complexity
# -Wno-exit-time-destructors: warning in Catch code
# -Wno-keyword-macro: unit-tests use "#define private public"
# -Wno-deprecated-declarations: the library deprecated some functions
# -Wno-weak-vtables: exception class is defined inline, but has virtual method
# -Wno-range-loop-analysis: iterator_wrapper tests "for(const auto i...)"
# -Wno-float-equal: not all comparisons in the tests can be replaced by Approx
# -Wno-switch-enum -Wno-covered-switch-default: pedantic/contradicting warnings about switches
# -Wno-padded: padding is nothing to warn about
pedantic_clang:
	$(MAKE) json_unit CXXFLAGS="\
		-std=c++11 -Wno-c++98-compat -Wno-c++98-compat-pedantic \
		-Werror \
		-Weverything \
		-Wno-documentation-unknown-command \
		-Wno-exit-time-destructors \
		-Wno-keyword-macro \
		-Wno-deprecated-declarations \
		-Wno-weak-vtables \
		-Wno-range-loop-analysis \
		-Wno-float-equal \
		-Wno-switch-enum -Wno-covered-switch-default \
		-Wno-padded"

# calling GCC with most warnings
pedantic_gcc:
	$(MAKE) json_unit CXX=g++ CXXFLAGS="\
		-std=c++11 \
		-Wno-deprecated-declarations \
		-Werror \
		-Wall -Wpedantic -Wextra \
		-Walloca \
		-Warray-bounds=2 \
		-Wcast-qual -Wcast-align \
		-Wchar-subscripts \
		-Wconditionally-supported \
		-Wconversion \
		-Wdate-time \
		-Wdeprecated \
		-Wdisabled-optimization \
		-Wdouble-promotion \
		-Wduplicated-branches \
		-Wduplicated-cond \
		-Wformat-overflow=2 \
		-Wformat-signedness \
		-Wformat-truncation=2 \
		-Wformat=2 \
		-Wno-ignored-qualifiers \
		-Wimplicit-fallthrough=5 \
		-Wlogical-op \
		-Wmissing-declarations \
		-Wmissing-format-attribute \
		-Wmissing-include-dirs \
		-Wnoexcept \
		-Wnonnull \
		-Wnull-dereference \
		-Wold-style-cast \
		-Woverloaded-virtual \
		-Wparentheses \
		-Wplacement-new=2 \
		-Wredundant-decls \
		-Wreorder \
		-Wrestrict \
		-Wshadow=global \
		-Wshift-overflow=2 \
		-Wsign-conversion \
		-Wsign-promo \
		-Wsized-deallocation \
		-Wstrict-overflow=5 \
		-Wsuggest-attribute=const \
		-Wsuggest-attribute=format \
		-Wsuggest-attribute=noreturn \
		-Wsuggest-attribute=pure \
		-Wsuggest-final-methods \
		-Wsuggest-final-types \
		-Wsuggest-override \
		-Wtrigraphs \
		-Wundef \
		-Wuninitialized -Wunknown-pragmas \
		-Wunused \
		-Wunused-const-variable=2 \
		-Wunused-macros \
		-Wunused-parameter \
		-Wuseless-cast \
		-Wvariadic-macros"

##########################################################################
# fuzzing
##########################################################################

# the overall fuzz testing target
fuzz_testing:
	rm -fr fuzz-testing
	mkdir -p fuzz-testing fuzz-testing/testcases fuzz-testing/out
	$(MAKE) parse_afl_fuzzer -C test CXX=afl-clang++
	mv test/parse_afl_fuzzer fuzz-testing/fuzzer
	find test/data/json_tests -size -5k -name *json | xargs -I{} cp "{}" fuzz-testing/testcases
	@echo "Execute: afl-fuzz -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer"

fuzz_testing_cbor:
	rm -fr fuzz-testing
	mkdir -p fuzz-testing fuzz-testing/testcases fuzz-testing/out
	$(MAKE) parse_cbor_fuzzer -C test CXX=afl-clang++
	mv test/parse_cbor_fuzzer fuzz-testing/fuzzer
	find test/data -size -5k -name *.cbor | xargs -I{} cp "{}" fuzz-testing/testcases
	@echo "Execute: afl-fuzz -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer"

fuzz_testing_msgpack:
	rm -fr fuzz-testing
	mkdir -p fuzz-testing fuzz-testing/testcases fuzz-testing/out
	$(MAKE) parse_msgpack_fuzzer -C test CXX=afl-clang++
	mv test/parse_msgpack_fuzzer fuzz-testing/fuzzer
	find test/data -size -5k -name *.msgpack | xargs -I{} cp "{}" fuzz-testing/testcases
	@echo "Execute: afl-fuzz -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer"

fuzzing-start:
	afl-fuzz -S fuzzer1 -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer > /dev/null &
	afl-fuzz -S fuzzer2 -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer > /dev/null &
	afl-fuzz -S fuzzer3 -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer > /dev/null &
	afl-fuzz -S fuzzer4 -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer > /dev/null &
	afl-fuzz -S fuzzer5 -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer > /dev/null &
	afl-fuzz -S fuzzer6 -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer > /dev/null &
	afl-fuzz -S fuzzer7 -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer > /dev/null &
	afl-fuzz -M fuzzer0 -i fuzz-testing/testcases -o fuzz-testing/out fuzz-testing/fuzzer

fuzzing-stop:
	-killall fuzzer
	-killall afl-fuzz

##########################################################################
# static analyzer
##########################################################################

# call cppcheck on the main header file
cppcheck:
	cppcheck --enable=warning --inconclusive --force --std=c++11 src/json.hpp --error-exitcode=1


##########################################################################
# maintainer targets
##########################################################################

# pretty printer
pretty:
	astyle --style=allman --indent=spaces=4 --indent-modifiers \
	   --indent-switches --indent-preproc-block --indent-preproc-define \
	   --indent-col1-comments --pad-oper --pad-header --align-pointer=type \
	   --align-reference=type --add-brackets --convert-tabs --close-templates \
	   --lineend=linux --preserve-date --suffix=none --formatted \
	   src/json.hpp test/src/*.cpp \
	   benchmarks/src/benchmarks.cpp doc/examples/*.cpp


##########################################################################
# changelog
##########################################################################

NEXT_VERSION ?= "unreleased"

ChangeLog.md:
	github_changelog_generator -o ChangeLog.md --simple-list --release-url https://github.com/nlohmann/json/releases/tag/%s --future-release $(NEXT_VERSION)
	gsed -i 's|https://github.com/nlohmann/json/releases/tag/HEAD|https://github.com/nlohmann/json/tree/HEAD|' ChangeLog.md
	gsed -i '2i All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/).' ChangeLog.md
