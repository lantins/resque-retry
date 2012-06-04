#!/usr/bin/env bash

# Perform some loose sanity checking that were in the correct directory first.
if [ ! -f "Gemfile" ] || [ ! -f "resque-retry.gemspec" ]; then
	echo "  ERROR: You may only run this script from the ROOT directory of the gem.  Aborting."
	exit 1
fi

# exit if anything fails.
set -e
# echo the commands we execute
set -o verbose
# ruby versions to test.
TEST_RUBIES="ruby-1.8.7-p358,ruby-1.9.2-p320,ruby-1.9.3-p0,jruby-1.6.7.2,rbx-2.0.testing"
# install dependencies.
rvm $TEST_RUBIES do bundle
# run unit tests
rvm $TEST_RUBIES do bundle exec rake
